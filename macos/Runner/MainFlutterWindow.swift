import Cocoa
import FlutterMacOS

private let storyWindowContentSize = NSSize(width: 640, height: 360)

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.contentMinSize = storyWindowContentSize
    self.setContentSize(storyWindowContentSize)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
