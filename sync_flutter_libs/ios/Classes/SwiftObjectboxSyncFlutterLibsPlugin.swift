import Flutter
import UIKit

public class SwiftObjectboxSyncFlutterLibsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "objectbox_sync_flutter_libs", binaryMessenger: registrar.messenger())
    let instance = SwiftObjectboxSyncFlutterLibsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result("iOS " + UIDevice.current.systemVersion)
  }
}
