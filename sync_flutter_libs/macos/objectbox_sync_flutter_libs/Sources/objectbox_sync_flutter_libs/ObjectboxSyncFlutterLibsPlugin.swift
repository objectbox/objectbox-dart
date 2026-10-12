import Cocoa
import FlutterMacOS
#if canImport(ObjectBoxMeshSync)
import ObjectBox
import ObjectBoxMeshSync
#endif

/// Provides platform methods for ObjectBox Sync on macOS via a method channel (the analog of the Kotlin
/// `ObjectboxSyncFlutterLibsPlugin` on Android):
///
/// - `createMeshNetwork`: creates a Google Nearby Connections mesh network for Mesh Sync (using the
///   `ObjectBoxMeshSync` add-on of the ObjectBox Swift Package) and returns the address of its `OBX_mesh_network`
///   handle as an `Int`, which the Dart side registers with its mesh options (via `obx_mesh_opt_network()`).
///
///   Requires a `serviceId` (`String`) argument: the mesh ID, which doubles as the Nearby service ID.
///
///   A `requestPermissions` (`Boolean`) argument is accepted for parity with Android, but ignored: there is
///   nothing to request upfront on Apple platforms, the system prompts for Local Network and Bluetooth access on
///   first use (and the mesh retries starting its radios by itself). So unlike on Android, the plugin never calls
///   the `onMeshSyncPermissionsGranted` platform method.
///
///   If the service ID is missing or empty, returns an error result with code `OBX_MESH_INVALID_SERVICE_ID`.
///
///   If creating the network throws, returns an error result with code `OBX_MESH_CREATE_FAILED`.
///
///   Returns a not-implemented result if the add-on is not part of the build: it requires the Swift Package
///   Manager integration of Flutter (the CocoaPods integration does not include it) and Xcode 16.3 or newer.
public class ObjectboxSyncFlutterLibsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "objectbox_sync_flutter_libs", binaryMessenger: registrar.messenger)
    let instance = ObjectboxSyncFlutterLibsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "createMeshNetwork":
      createMeshNetwork(call, result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  #if canImport(ObjectBoxMeshSync)
  /// The networks created so far, by handle address. Keeps them alive: the Dart side registers a network with its
  /// mesh options only once a sync client is created (long after `createMeshNetwork` returned), and deallocating
  /// the `MeshNetwork` wrapper before that would free the handle. The mesh sync core stops the transport when the
  /// sync client is closed; only the small wrapper objects stay around (for the process lifetime).
  private var networks = [Int: MeshNetwork]()

  private func createMeshNetwork(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    guard let serviceId = arguments?["serviceId"] as? String, !serviceId.isEmpty else {
      result(
        FlutterError(
          code: "OBX_MESH_INVALID_SERVICE_ID", message: "serviceId must not be empty", details: nil))
      return
    }
    do {
      // The Swift config only serves to create a network with the Nearby transport wired up (like the Swift API
      // does for its users): the mesh config itself lives on the Dart side.
      let config = try AppleMeshSync.createConfig(meshId: serviceId)
      guard let network = config.networks.first, let cNetwork = network.cNetwork else {
        result(
          FlutterError(code: "OBX_MESH_CREATE_FAILED", message: "No mesh network was created", details: nil))
        return
      }
      let handle = Int(bitPattern: cNetwork)
      networks[handle] = network
      result(handle)
    } catch {
      result(FlutterError(code: "OBX_MESH_CREATE_FAILED", message: "\(error)", details: nil))
    }
  }
  #else
  private func createMeshNetwork(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    // Built without the ObjectBoxMeshSync add-on (e.g. via CocoaPods or with Swift tools before 6.1)
    result(FlutterMethodNotImplemented)
  }
  #endif
}
