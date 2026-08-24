package io.objectbox.objectbox_sync_flutter_libs

import android.content.Context
import android.content.pm.PackageManager
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
 * Provides Android-specific platform methods for ObjectBox Sync via [MethodChannel]:
 *
 * -  `createMeshNetwork`: creates a [NearbyMeshNetwork] instance for Mesh Sync and returns its
 *    [NearbyMeshNetwork.getNativeHandle].
 *
 *    Requires a `serviceId` (`String`) argument for the mesh network.
 *
 *    Optionally, a `requestPermissions` (`Boolean`, defaults to `true`) argument to prevent
 *    requesting any missing permissions using the [MeshSyncPermissions] helper.
 *
 *    If permissions were requested and any were granted invokes the `onMeshSyncPermissionsGranted`
 *    platform method.
 *
 *    If the service ID is null or empty, returns an error result with code
 *    `OBX_MESH_INVALID_SERVICE_ID`.
 *
 *    If creating the mesh instance throws, returns an error result with code
 *    `OBX_MESH_CREATE_FAILED`.
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
            Log.w(LOG_TAG,
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
      Log.w(LOG_TAG, "Failed to load ObjectBox library: ${e.message}")
      // Ignore
    }
    try {
      val network = NearbyMeshNetwork(applicationContext, serviceId)
      // Note: there is no need to keep a reference to the Java network instance,
      // the Java object is referenced by the native object represented by the handle.
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
  }

  private companion object {
    const val LOG_TAG = "ObjectBoxSyncFlutterLibsPlugin"
  }
}
