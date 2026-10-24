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
      // Dart has not reported its first frame yet (it is still booting).
      // An engine stuck for 10 s+ is torn down and rebuilt, so a failed boot
      // can never lock the settings window out for good.
      if Date().timeIntervalSince(bootedAt) < 10 {
        reveal()
        return
      }
      NSLog("[MelodyKeeeys] settings engine never reported ready; restarting it")
      teardownEngine()
    }
    let window = self.window ?? makeWindow()
    self.window = window
    applyTheme(window)
    let controller = FlutterViewController()
    // Paint the window in the app's own surface color while Dart boots
    // (1-3 s on older Macs) instead of a black or empty frame.
    controller.backgroundColor = window.backgroundColor
    let frame = window.frame
    window.contentViewController = controller
    window.setFrame(frame, display: false)
    registerPlugins(controller)
    self.controller = controller
    shown = false
    bootedAt = Date()
    // Show the window at once so the click gets instant feedback; Flutter
    // fills it in when its first frame is ready.
    reveal()
  }

  /// Light / dark / system, from the saved settings, with the matching
  /// surface color (app_colors.dart surface: light 0xFBFAFE, dark 0x12111A).
  private func applyTheme(_ window: NSWindow) {
    switch MelodyHost.shared.uiThemeIndex {
    case 0: window.appearance = NSAppearance(named: .aqua)
    case 1: window.appearance = NSAppearance(named: .darkAqua)
    default: window.appearance = nil
    }
    window.backgroundColor = NSColor(name: nil) { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(red: 0x12 / 255, green: 0x11 / 255, blue: 0x1A / 255, alpha: 1)
        : NSColor(red: 0xFB / 255, green: 0xFA / 255, blue: 0xFE / 255, alpha: 1)
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
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: true)
    window.isReleasedWhenClosed = false
    window.title = "Melody Keeeys · 旋律键音"
    // Same chrome Dart applies (TitleBarStyle.hidden), set up front so the
    // title bar doesn't flash in and out while the engine boots.
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
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
