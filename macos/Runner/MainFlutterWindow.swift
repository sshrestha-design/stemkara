import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.delegate = self
    self.minSize = NSSize(width: 800, height: 500)
    self.title = "Stemkara"

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    sender.orderOut(nil)
    return false
  }
}
