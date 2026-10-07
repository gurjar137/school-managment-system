import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    let defaultWidth: CGFloat = 1280
    let defaultHeight: CGFloat = 800
    let minWidth: CGFloat = 1024
    let minHeight: CGFloat = 680

    var windowFrame = self.frame
    windowFrame.size = NSSize(width: defaultWidth, height: defaultHeight)
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: minWidth, height: minHeight)
    self.center()
    self.title = "School Management OS"

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
