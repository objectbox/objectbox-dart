import Cocoa
import FlutterMacOS

public class ObjectboxFlutterLibsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
      // Not using method channels, so not registering one.
      // Note: if ever implementing this, may have to add workaround for https://github.com/flutter/flutter/issues/67624
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result(nil)
  }
}
