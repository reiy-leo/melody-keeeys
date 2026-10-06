import Carbon.HIToolbox
import Cocoa
import FlutterMacOS
import ApplicationServices

// Referencing ae_version pulls audio_engine.o into the Runner binary so the
// ae_* symbols stay available for dart:ffi (dlsym) at runtime.
@_silgen_name("ae_version")
private func _ae_version() -> UnsafePointer<CChar>?

/// Global keyboard hook (CGEventTap, listen-only) exposed to Dart through
/// MethodChannel "native_core/method" + EventChannel "native_core/keyhook".
public class NativeCorePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var methodChannel: FlutterMethodChannel?
  private var eventSink: FlutterEventSink?

  private var tap: CFMachPort?
  private var tapSource: CFRunLoopSource?
  private var hookThread: Thread?

  private static var instance: NativeCorePlugin?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = NativeCorePlugin()
    instance.methodChannel = FlutterMethodChannel(
      name: "native_core/method", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(instance, channel: instance.methodChannel!)
    let eventChannel = FlutterEventChannel(
      name: "native_core/keyhook", binaryMessenger: registrar.messenger)
    eventChannel.setStreamHandler(instance)
    NativeCorePlugin.instance = instance
  }

  // MARK: - FlutterStreamHandler

  public func onListen(withArguments arguments: Any?,
                       eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  // MARK: - FlutterPlugin

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isPermissionGranted":
      result(AXIsProcessTrusted())
    case "engineVersion":
      if let v = _ae_version() {
        result(String(cString: v))
      } else {
        result(FlutterError(code: "engine_missing", message: "ae_version not linked", details: nil))
      }
    case "openPermissionSettings":
      if let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
        NSWorkspace.shared.open(url)
        result(true)
      } else {
        result(false)
      }
    case "startKeyHook":
      if tap != nil {
        result(true)
      } else if startTap() {
        result(true)
      } else {
        result(FlutterError(code: "hook_failed",
                            message: "CGEventTap create failed (accessibility not granted?)",
                            details: nil))
      }
    case "stopKeyHook":
      stopTap()
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Event tap

  private func startTap() -> Bool {
    let eventMask: CGEventMask =
      (1 << CGEventType.keyDown.rawValue)
      | (1 << CGEventType.keyUp.rawValue)
      | (1 << CGEventType.flagsChanged.rawValue)

    let refcon = Unmanaged<NativeCorePlugin>.passUnretained(self).toOpaque()
    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .listenOnly,
      eventsOfInterest: eventMask,
      callback: { proxy, type, event, refcon in
        NativeCorePlugin.tapCallback(proxy, type, event, refcon)
      },
      userInfo: refcon) else {
      return false
    }

    self.tap = tap
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    self.tapSource = source

    let thread = Thread { [weak self] in
      guard let self, let source = self.tapSource else { return }
      CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
      CGEvent.tapEnable(tap: self.tap!, enable: true)
      CFRunLoopRun()
    }
    thread.name = "native_core.eventtap"
    thread.start()
    hookThread = thread
    return true
  }

  private func stopTap() {
    if let tap = tap {
      CGEvent.tapEnable(tap: tap, enable: false)
      if let source = tapSource {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        CFRunLoopSourceInvalidate(source)
      }
      CFMachPortInvalidate(tap)
    }
    tap = nil
    tapSource = nil
    hookThread = nil
  }

  private static func tapCallback(_ proxy: CGEventTapProxy, _ type: CGEventType,
                                  _ event: CGEvent, _ refcon: UnsafeMutableRawPointer?)
      -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let plugin = Unmanaged<NativeCorePlugin>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap = plugin.tap { CGEvent.tapEnable(tap: tap, enable: true) }
      return Unmanaged.passUnretained(event)
    }

    let code = event.getIntegerValueField(.keyboardEventKeycode)
    var isDown = type == .keyDown
    var isRepeat = false

    if type == .flagsChanged {
      // Modifier keys emit flagsChanged, not keyDown/up: derive state from flags.
      let flags = event.flags
      let mask = modifierMask(for: code)
      isDown = !mask.isEmpty && flags.intersection(mask) == mask
    } else {
      isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) == 1
    }

    plugin.emit(code: code, down: isDown, isRepeat: isRepeat)
    return Unmanaged.passUnretained(event)
  }

  private static func modifierMask(for keycode: Int64) -> CGEventFlags {
    switch keycode {
    case Int64(kVK_Shift), Int64(kVK_RightShift):
      return .maskShift
    case Int64(kVK_Command), Int64(kVK_RightCommand):
      return .maskCommand
    case Int64(kVK_Option), Int64(kVK_RightOption):
      return .maskAlternate
    case Int64(kVK_Control), Int64(kVK_RightControl):
      return .maskControl
    case Int64(kVK_CapsLock):
      return .maskAlphaShift
    case Int64(kVK_Function):
      return .maskSecondaryFn
    default:
      return []
    }
  }

  private func emit(code: Int64, down: Bool, isRepeat: Bool) {
    let sink = eventSink
    guard sink != nil else { return }
    let ts = Int64(Date().timeIntervalSince1970 * 1000)
    DispatchQueue.main.async {
      sink?([
        "code": code,
        "down": down,
        "repeat": isRepeat,
        "ts": ts,
      ] as [String: Any])
    }
  }
}
