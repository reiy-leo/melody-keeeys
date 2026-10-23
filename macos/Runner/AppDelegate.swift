import Cocoa
import FlutterMacOS
import native_core

@main
class AppDelegate: FlutterAppDelegate {
  private let settingsWindow = SettingsWindowHost()
  private var launched = false

  override func awakeFromNib() {
    super.awakeFromNib()
    NotificationCenter.default.addObserver(
      forName: NSApplication.didFinishLaunchingNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.launch()
    }
  }

  private func launch() {
    guard !launched else { return }
    launched = true
    let host = MelodyHost.shared
    host.openSettings = { [weak self] in self?.settingsWindow.open() }
    host.closeSettings = { [weak self] in self?.settingsWindow.close() }
    host.settingsShown = { [weak self] in self?.settingsWindow.markShown() }
    host.start()
  }

  // Menu-bar app: closing the settings window must never end the process.
  // Quit only from the menu-bar menu.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
