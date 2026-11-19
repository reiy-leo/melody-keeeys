#include "flutter_window.h"

#include <optional>

#include <dwmapi.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <map>

#include "flutter/generated_plugin_registrant.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"

namespace {

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif
constexpr DWORD kDwmCornerRound = 2;  // DWMWCP_ROUND

// The frameless HUD loses its top corners to window_manager's WM_NCCALCSIZE
// handling on Windows 11; ask DWM to round all four (no-op on Windows 10).
void RoundCorners(HWND hwnd) {
  DWORD pref = kDwmCornerRound;
  ::DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &pref,
                          sizeof(pref));
}

// Bring the HUD to the foreground so clicking anywhere else deactivates it
// (and the Dart side hides it on blur). A plain SetForegroundWindow from a
// background process is refused, so borrow the foreground thread's input
// state for the call.
void ForceForeground(HWND hwnd) {
  HWND fg = ::GetForegroundWindow();
  if (fg == hwnd) return;
  DWORD fg_thread = fg ? ::GetWindowThreadProcessId(fg, nullptr) : 0;
  DWORD self_thread = ::GetCurrentThreadId();
  bool attached = fg_thread != 0 && fg_thread != self_thread &&
                  ::AttachThreadInput(self_thread, fg_thread, TRUE);
  ::BringWindowToTop(hwnd);
  ::SetForegroundWindow(hwnd);
  ::SetFocus(hwnd);
  if (attached) ::AttachThreadInput(self_thread, fg_thread, FALSE);
}

// One 'melody/hud_window' channel per sub-window engine. HUD engines are
// never torn down on Windows, so these live for the process.
std::map<void*, std::unique_ptr<flutter::MethodChannel<>>> g_hud_channels;

void AttachHudChannel(flutter::FlutterViewController* controller) {
  HWND root = ::GetAncestor(controller->view()->GetNativeWindow(), GA_ROOT);
  RoundCorners(root);
  auto channel = std::make_unique<flutter::MethodChannel<>>(
      controller->engine()->messenger(), "melody/hud_window",
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [root](const flutter::MethodCall<>& call,
             std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() == "activate") {
          ForceForeground(root);
          result->Success();
        } else {
          // 'dispose' stays unimplemented here: closing a sub-window that
          // window_manager is attached to has crashed on Windows before.
          result->NotImplemented();
        }
      });
  g_hud_channels[controller] = std::move(channel);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  // Each desktop_multi_window sub-window (the tray HUD) runs its own engine,
  // which gets no plugins unless registered here. Without this the HUD's
  // window_manager calls throw and the panel never shows.
  DesktopMultiWindowSetWindowCreatedCallback([](void* controller) {
    auto* view_controller =
        reinterpret_cast<flutter::FlutterViewController*>(controller);
    RegisterPlugins(view_controller->engine());
    AttachHudChannel(view_controller);
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Menu-bar app: the window stays hidden until Dart calls
  // windowManager.show() (settings opened from the tray, or first-run
  // permission prompt).
  flutter_controller_->engine()->SetNextFrameCallback([&]() {});

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
