import Cocoa
import FlutterMacOS
import native_core
import screen_retriever_macos
import shared_preferences_foundation
import window_manager

/// The settings window, whose Flutter engine only exists while it is open.
///
/// Melody Keeeys lives in the menu bar; everything that runs all the time
/// (key hook, audio, menu, tray panel, hotkeys) is native (MelodyHost). A
/// Flutter engine costs ~100 MB resident (Dart VM, Skia, fonts, GPU
/// surfaces) whether or not anything is on screen, so it is created when the
/// settings window opens and shut down when it closes. The NSWindow itself
/// is kept and reused, so its frame survives between openings.
final class SettingsWindowHost {
  private var window: NSWindow?
  private var controller: FlutterViewController?
  private var shown = false

  func open() {
    if let window, controller != nil {
      // Still booting: Dart shows the window after its first frame.
      guard shown else { return }
      NSApp.activate(ignoringOtherApps: true)
      window.makeKeyAndOrderFront(nil)
      return
    }
    let window = self.window ?? makeWindow()
    self.window = window
    let controller = FlutterViewController()
    let frame = window.frame
    window.contentViewController = controller
    window.setFrame(frame, display: false)
    registerPlugins(controller)
    self.controller = controller
    shown = false
  }

  func markShown() {
    shown = true
  }

  func close() {
    guard let window, let controller else { return }
    window.orderOut(nil)
    window.contentViewController = nil
    window.contentView = NSView()
    controller.engine.shutDownEngine()
    self.controller = nil
    shown = false
  }

  private func makeWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1020, height: 700),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: true)
    window.isReleasedWhenClosed = false
    window.title = "Melody Keeeys · 旋律键音"
    window.center()
    return window
  }

  /// Only what the settings UI uses. desktop_multi_window (the Flutter HUD,
  /// replaced by the native tray panel here) and hotkey_manager (hotkeys are
  /// native) stay unregistered so nothing double-registers or pins the
  /// engine. Add new macOS plugins here, not via RegisterGeneratedPlugins.
  private func registerPlugins(_ registry: FlutterPluginRegistry) {
    NativeCorePlugin.register(with: registry.registrar(forPlugin: "NativeCorePlugin"))
    ScreenRetrieverMacosPlugin.register(
      with: registry.registrar(forPlugin: "ScreenRetrieverMacosPlugin"))
    SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
    WindowManagerPlugin.register(with: registry.registrar(forPlugin: "WindowManagerPlugin"))
  }
}
