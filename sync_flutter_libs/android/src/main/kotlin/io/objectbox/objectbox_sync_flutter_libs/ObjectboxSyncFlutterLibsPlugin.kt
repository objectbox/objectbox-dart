package io.objectbox.objectbox_sync_flutter_libs

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import io.objectbox.meshsync.android.MeshSyncPermissions
import io.objectbox.meshsync.android.internal.NearbyMeshNetwork

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/**
 * Implements Android-specific functionality for ObjectBox Sync via MethodChannel:
 * - Loading the ObjectBox JNI library on Android 6.
 * - Creating a mesh network for Mesh Sync.
 */
class ObjectboxSyncFlutterLibsPlugin: FlutterPlugin, MethodCallHandler, ActivityAware,
  PluginRegistry.RequestPermissionsResultListener {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel: MethodChannel
  private lateinit var applicationContext: Context
  private var activityBinding: ActivityPluginBinding? = null
  private var meshSyncPermissions: MeshSyncPermissions? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = flutterPluginBinding.applicationContext
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
          val permissions = meshSyncPermissions
          if (permissions == null) {
            Log.w(logTag,
                "Mesh Sync runtime permissions may be missing, but no Activity is attached to request them")
          } else {
            permissions.requestIfMissing()
          }
        }

        // Create and return the network without waiting for a permissions grant; once permissions
        // are granted, the Dart side is notified (see onRequestPermissionsResult) so it can retry
        // the mesh networks.
        createMeshNetwork(serviceId, result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityBinding = binding
    meshSyncPermissions = MeshSyncPermissions(binding.activity)
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivity() {
    activityBinding?.removeRequestPermissionsResultListener(this)
    activityBinding = null
    meshSyncPermissions = null
  }

  override fun onRequestPermissionsResult(
      requestCode: Int,
      permissions: Array<out String>,
      grantResults: IntArray
  ): Boolean {
    if (requestCode != MeshSyncPermissions.PERMISSIONS_REQUEST_CODE) return false

    // The mesh instance only exists on the Dart side, so instead of calling
    // MeshSyncPermissions.notifyMeshIfPermissionsGranted() notify the Dart side to let it call
    // MeshSync.retryNetworks() once a sync client (and with it the mesh) exists.
    if (grantResults.any { it == PackageManager.PERMISSION_GRANTED }) {
      channel.invokeMethod("onMeshSyncPermissionsGranted", null)
    }
    return true
  }

  private fun createMeshNetwork(serviceId: String, result: Result) {
    try {
      loadObjectBoxLibrary()
    } catch (e: Throwable) {
      Log.w(logTag, "Failed to load ObjectBox library: ${e.message}")
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

  private companion object {
    const val logTag = "ObjectBoxSyncFlutterLibsPlugin"
  }
}
