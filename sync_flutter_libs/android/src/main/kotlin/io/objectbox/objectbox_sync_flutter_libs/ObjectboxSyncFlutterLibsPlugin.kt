package io.objectbox.objectbox_sync_flutter_libs

import android.content.Context
import android.os.Build
import android.util.Log
import io.objectbox.android.internal.meshsync.NearbyMeshNetwork

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Implements Android-specific functionality for ObjectBox Sync via MethodChannel:
 * - Loading the ObjectBox JNI library on Android 6.
 * - Creating a mesh network for Mesh Sync.
 */
// TODO Rename to ObjectboxSyncFlutterPlugin?
class ObjectboxSyncFlutterLibsPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel: MethodChannel
  private lateinit var applicationContext: Context
  private lateinit var meshSyncPermissions: MeshSyncPermissions

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = flutterPluginBinding.applicationContext
    meshSyncPermissions = MeshSyncPermissions(applicationContext)
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "objectbox_sync_flutter_libs")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "loadObjectBoxLibrary" -> {
        // Loading the JNI library through Dart is broken on Android 6 (and maybe earlier).
        // Try to fix by loading it first via Java API, then again in Dart.
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.M) {
          result.success(null)
          return
        }
        try {
          loadObjectBoxLibrary()
          result.success(null)
        } catch (e: Throwable) {
          result.error("OBX_SO_LOAD_FAILED", e.message, null)
        }
      }
      "createMeshNetwork" -> {
        val serviceId = call.argument<String>("serviceId")
        if (serviceId.isNullOrEmpty()) {
          result.error("OBX_MESH_INVALID_SERVICE_ID", "serviceId must not be empty", null)
          return
        }
        val requestPermissions = call.argument<Boolean>("requestPermissions") ?: true
        if (requestPermissions) {
          // TODO Do not wait for permission request to finish;
          //      instead notify only the network (requires core changes) about permission change
          meshSyncPermissions.requestIfMissing {
            createMeshNetwork(serviceId, result)
          }
        } else {
          createMeshNetwork(serviceId, result)
        }
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    meshSyncPermissions.onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    meshSyncPermissions.onDetachedFromActivity()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    meshSyncPermissions.onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivity() {
    meshSyncPermissions.onDetachedFromActivity()
  }

  private fun createMeshNetwork(serviceId: String, result: Result) {
    try {
      loadObjectBoxLibrary()
    } catch (e: Throwable) {
      Log.w("ObjectBoxSyncFlutterLibsPlugin", "Failed to load ObjectBox library: ${e.message}")
      // Ignore
    }
    try {
      val network = NearbyMeshNetwork(applicationContext, serviceId)
      // Note: we do not need to keep a reference to the (Java) network:
      //       the Java object is referenced by the native object represented by the handle.
      result.success(network.nativeHandle)
    } catch (e: Throwable) {
      result.error("OBX_MESH_CREATE_FAILED", e.message, null)
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  private fun loadObjectBoxLibrary() {
    System.loadLibrary("objectbox-jni")
    println("[ObjectBox] Loaded JNI library.")
  }
}
