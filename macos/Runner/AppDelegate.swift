import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Menu-bar app: closing (or hiding) the settings window, or the HUD
  // sub-window going away, must never end the process. Quit only from the
  // tray menu.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
