package io.objectbox.objectbox_sync_flutter_libs

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
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
  private var activity: Activity? = null

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
        if (requestPermissions) requestMeshPermissionsIfMissing()
        createMeshNetwork(serviceId, result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  private fun requestMeshPermissionsIfMissing() {
    val missingPermissions = missingRuntimeMeshPermissions()
    if (missingPermissions.isEmpty()) return

    val currentActivity = activity
    if (currentActivity == null) {
      Log.w(
          "ObjectBoxSyncFlutterLibsPlugin",
          "Android Mesh Sync runtime permissions are missing, but no Activity is attached")
      return
    }

    currentActivity.requestPermissions(
        missingPermissions.toTypedArray(), meshPermissionsRequestCode)
  }

  private fun missingRuntimeMeshPermissions(): List<String> {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return emptyList()

    return runtimeMeshPermissions()
        .filter { applicationContext.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
  }

  private fun runtimeMeshPermissions(): List<String> {
    val permissions = mutableListOf(
        Manifest.permission.ACCESS_COARSE_LOCATION,
        Manifest.permission.ACCESS_FINE_LOCATION)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      permissions += Manifest.permission.BLUETOOTH_ADVERTISE
      permissions += Manifest.permission.BLUETOOTH_CONNECT
      permissions += Manifest.permission.BLUETOOTH_SCAN
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      permissions += Manifest.permission.NEARBY_WIFI_DEVICES
    }
    return permissions
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

  private companion object {
    const val meshPermissionsRequestCode = 0x0B09
  }
}
