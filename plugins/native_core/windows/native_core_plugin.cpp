#include "native_core_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <chrono>
#include <map>
#include <memory>
#include <thread>

namespace native_core {

namespace {

// Custom message used to hop from the hook thread to the platform thread.
constexpr UINT kKeyEventMessage = WM_APP + 0x4B;

// Shared hook state. The plugin is a single-instance singleton per process,
// so file-scope statics are safe here.
HHOOK g_keyboard_hook = nullptr;
std::thread g_hook_thread;
std::atomic<DWORD> g_hook_thread_id{0};
std::atomic<bool> g_hook_running{false};
HWND g_target_hwnd = nullptr;

// Track pressed state per VK code: WH_KEYBOARD_LL's KBDLLHOOKSTRUCT carries no
// repeat info, so OS auto-repeat appears as key-down on an already-down key.
std::map<DWORD, bool> g_down_keys;

LRESULT CALLBACK KeyboardHookProc(int n_code, WPARAM w_param, LPARAM l_param) {
  if (n_code >= 0 && g_hook_running.load()) {
    const auto *info = reinterpret_cast<KBDLLHOOKSTRUCT *>(l_param);
    // Ignore injected events (other tools, our own synths) to avoid loops.
    if (!(info->flags & LLKHF_INJECTED)) {
      const bool down = w_param == WM_KEYDOWN || w_param == WM_SYSKEYDOWN;
      const bool up = w_param == WM_KEYUP || w_param == WM_SYSKEYUP;
      if (down || up) {
        bool repeat = false;
        if (down) {
          auto it = g_down_keys.find(info->vkCode);
          repeat = it != g_down_keys.end() && it->second;
          g_down_keys[info->vkCode] = true;
        } else {
          g_down_keys[info->vkCode] = false;
        }
        const LPARAM l_param_msg = (down ? 1 : 0) | (repeat ? 2 : 0);
        PostMessage(g_target_hwnd, kKeyEventMessage,
                    static_cast<WPARAM>(info->vkCode), l_param_msg);
      }
    }
  }
  return CallNextHookEx(nullptr, n_code, w_param, l_param);
}

DWORD WINAPI HookThreadProc(LPVOID) {
  g_keyboard_hook =
      SetWindowsHookEx(WH_KEYBOARD_LL, KeyboardHookProc, GetModuleHandle(nullptr), 0);
  if (g_keyboard_hook == nullptr) {
    g_hook_running.store(false);
    return 1;
  }
  // The low-level hook requires a message loop on its installing thread.
  MSG msg;
  while (GetMessage(&msg, nullptr, 0, 0) > 0) {
    TranslateMessage(&msg);
    DispatchMessage(&msg);
  }
  UnhookWindowsHookEx(g_keyboard_hook);
  g_keyboard_hook = nullptr;
  return 0;
}

int64_t NowEpochMs() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::system_clock::now().time_since_epoch())
      .count();
}

}  // namespace

// static
void NativeCorePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<NativeCorePlugin>(registrar);

  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "native_core/method",
          &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

NativeCorePlugin::NativeCorePlugin(flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar) {
  g_target_hwnd = registrar->GetView()->GetNativeWindow();
  window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
      [this](HWND hwnd, UINT message, WPARAM w_param, LPARAM l_param) {
        return HandleWindowProc(hwnd, message, w_param, l_param);
      });

  event_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar_->messenger(), "native_core/keyhook",
          &flutter::StandardMethodCodec::GetInstance());
  event_channel_->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [this](const flutter::EncodableValue *arguments,
                 std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> &&events)
              -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
            event_sink_ = std::move(events);
            return nullptr;
          },
          [this](const flutter::EncodableValue *arguments)
              -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
            event_sink_ = nullptr;
            return nullptr;
          }));
}

NativeCorePlugin::~NativeCorePlugin() {
  StopHook();
  if (window_proc_id_ >= 0) {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
  }
}

void NativeCorePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string &method = method_call.method_name();
  if (method.compare("isPermissionGranted") == 0) {
    // Low-level keyboard hooks need no elevation on Windows.
    result->Success(flutter::EncodableValue(true));
  } else if (method.compare("openPermissionSettings") == 0) {
    result->Success(flutter::EncodableValue(false));
  } else if (method.compare("startKeyHook") == 0) {
    StartHook();
    result->Success(flutter::EncodableValue(g_hook_running.load()));
  } else if (method.compare("stopKeyHook") == 0) {
    StopHook();
    result->Success(flutter::EncodableValue(true));
  } else {
    result->NotImplemented();
  }
}

void NativeCorePlugin::StartHook() {
  if (g_hook_running.load()) return;
  g_down_keys.clear();
  g_hook_running.store(true);
  g_hook_thread = std::thread(HookThreadProc, nullptr);
  g_hook_thread_id.store(GetThreadId(g_hook_thread.native_handle()));
  // Give the hook a moment; a failure unsets the flag from the hook thread.
  Sleep(50);
}

void NativeCorePlugin::StopHook() {
  if (!g_hook_running.exchange(false)) return;
  if (g_hook_thread.joinable()) {
    PostThreadMessage(g_hook_thread_id.load(), WM_QUIT, 0, 0);
    g_hook_thread.join();
  }
}

std::optional<LRESULT> NativeCorePlugin::HandleWindowProc(HWND hwnd, UINT message,
                                                          WPARAM w_param, LPARAM l_param) {
  if (message == kKeyEventMessage && event_sink_) {
    const int64_t code = static_cast<int64_t>(w_param);
    const bool down = (l_param & 1) != 0;
    const bool repeat = (l_param & 2) != 0;
    flutter::EncodableMap event{
        {"code", flutter::EncodableValue(code)},
        {"down", flutter::EncodableValue(down)},
        {"repeat", flutter::EncodableValue(repeat)},
        {"ts", flutter::EncodableValue(NowEpochMs())},
    };
    event_sink_->Success(flutter::EncodableValue(event));
    return 0;
  }
  return std::nullopt;
}

}  // namespace native_core
