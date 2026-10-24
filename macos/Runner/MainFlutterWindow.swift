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
  private var bootedAt = Date.distantPast
  private var revealTimer: Timer?

  func open() {
    if let window, controller != nil {
      if shown {
        bringFront(window)
        return
      }
      // Dart has not reported its first frame. Give it a moment, then show
      // the window anyway; an engine stuck for long is torn down and rebuilt
      // so a failed boot can never lock the settings window out for good.
      if Date().timeIntervalSince(bootedAt) < 4 {
        reveal()
        return
      }
      NSLog("[MelodyKeeeys] settings engine never reported ready; restarting it")
      teardownEngine()
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
    bootedAt = Date()
    // Dart orders the window front after its first frame (no blank flash).
    // If that call never comes, show it from here after a short wait.
    revealTimer?.invalidate()
    revealTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
      guard let self, !self.shown, self.controller != nil else { return }
      NSLog("[MelodyKeeeys] settings window shown by fallback timer (no ready signal from Dart)")
      self.reveal()
    }
  }

  func markShown() {
    shown = true
    revealTimer?.invalidate()
    revealTimer = nil
    if let window { bringFront(window) }
  }

  func close() {
    guard let window, controller != nil else { return }
    window.orderOut(nil)
    teardownEngine()
    // Back to a menu-bar-only app: no Dock icon, no Cmd-Tab entry.
    NSApp.setActivationPolicy(.accessory)
  }

  private func reveal() {
    shown = true
    revealTimer?.invalidate()
    revealTimer = nil
    if let window { bringFront(window) }
  }

  /// LSUIElement apps are not allowed to take focus reliably on recent
  /// macOS, so the window could open behind other apps. While settings are
  /// open the app is a regular app (Dock icon, Cmd-Tab), which lets it come
  /// to the front; close() drops back to accessory.
  private func bringFront(_ window: NSWindow) {
    NSApp.setActivationPolicy(.regular)
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()
  }

  private func teardownEngine() {
    revealTimer?.invalidate()
    revealTimer = nil
    guard let window, let controller else { return }
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
