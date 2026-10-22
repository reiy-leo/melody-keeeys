import Cocoa
import FlutterMacOS
import desktop_multi_window
import window_manager

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Sub-windows (tray HUD) run on their own engines: without this, plugins
    // like window_manager/tray_manager are missing there and every channel
    // call throws MissingPluginException.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
    }

    super.awakeFromNib()
  }

  // Keep the settings window hidden at launch (the xib would otherwise order
  // it front before Dart runs); main() decides whether to show it.
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
