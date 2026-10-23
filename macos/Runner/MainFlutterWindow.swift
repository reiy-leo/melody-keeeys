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
      // Lets the idle HUD close its own window. Closing (not hiding) drops
      // desktop_multi_window's reference, so the window, its
      // FlutterViewController and the HUD's whole engine are released.
      // window_manager can't do this: close() is performClose, a no-op on a
      // frameless window, and destroy() terminates the app.
      let channel = FlutterMethodChannel(
        name: "melody/hud_window",
        binaryMessenger: controller.engine.binaryMessenger)
      channel.setMethodCallHandler { [weak controller] call, result in
        guard call.method == "dispose" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(nil)
        // Reply first; tear the engine down on the next runloop turn.
        DispatchQueue.main.async { controller?.view.window?.close() }
      }
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
