import ApplicationServices
import Cocoa
import FlutterMacOS

/// Per-engine bridge for the settings window. The always-on work (key hook,
/// audio, menu bar, hotkeys) lives in MelodyHost, which outlives every
/// Flutter engine; this plugin only answers permission queries and hands the
/// engine's messenger to the host ("melody/host", "launch_at_startup").
public class NativeCorePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = NativeCorePlugin()
    let channel = FlutterMethodChannel(
      name: "native_core/method", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(instance, channel: channel)
    MelodyHost.shared.attach(messenger: registrar.messenger)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isPermissionGranted":
      result(AXIsProcessTrusted())
    case "permissionDetail":
      result([
        "accessibility": AXIsProcessTrusted(),
        "inputMonitoring": CGPreflightListenEventAccess(),
      ])
    case "requestInputMonitoring":
      // Shows the system prompt (once per TCC record) and registers the app
      // in 系统设置 → 隐私与安全性 → 输入监控.
      result(CGRequestListenEventAccess())
    case "engineVersion":
      if let v = _aeVersion() {
        result(String(cString: v))
      } else {
        result(FlutterError(code: "engine_missing", message: "ae_version not linked", details: nil))
      }
    case "openPermissionSettings":
      let which = (call.arguments as? String) ?? "accessibility"
      let anchor = which == "inputMonitoring" ? "Privacy_ListenEvent" : "Privacy_Accessibility"
      if let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
        NSWorkspace.shared.open(url)
        result(true)
      } else {
        result(false)
      }
    case "startKeyHook":
      if MelodyHost.shared.startHook() {
        result(true)
      } else {
        result(FlutterError(code: "hook_failed",
                            message: "accessibility not granted or CGEventTap create failed",
                            details: nil))
      }
    case "stopKeyHook":
      // The hook belongs to the host and keeps running without a window.
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
