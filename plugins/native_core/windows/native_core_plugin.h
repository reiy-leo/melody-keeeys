#ifndef FLUTTER_PLUGIN_NATIVE_CORE_PLUGIN_H_
#define FLUTTER_PLUGIN_NATIVE_CORE_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace native_core {

class NativeCorePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  NativeCorePlugin(flutter::PluginRegistrarWindows *registrar);
  virtual ~NativeCorePlugin();

  // Disallow copy and assign.
  NativeCorePlugin(const NativeCorePlugin&) = delete;
  NativeCorePlugin& operator=(const NativeCorePlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  // Raw keycode events are posted from the hook thread to the view window and
  // picked up by this delegate, which forwards them to the event sink on the
  // platform thread.
  std::optional<LRESULT> HandleWindowProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam);

  void StartHook();
  void StopHook();

  flutter::PluginRegistrarWindows *registrar_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  int window_proc_id_ = -1;
};

}  // namespace native_core

#endif  // FLUTTER_PLUGIN_NATIVE_CORE_PLUGIN_H_
