package io.objectbox.objectbox_flutter_libs

import android.os.Build
import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** ObjectboxFlutterLibsPlugin */
class ObjectboxFlutterLibsPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "objectbox_flutter_libs")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "loadObjectBoxLibrary") {
      // Loading the JNI library through Dart is broken on Android 6 (and maybe earlier).
      // Try to fix by loading it first via Java API, then again in Dart.
      if (Build.VERSION.SDK_INT > Build.VERSION_CODES.M) {
        result.success(null);
        return
      }
      try {
        System.loadLibrary("objectbox-jni")
        println("[ObjectBox] Loaded JNI library via workaround.")
        result.success(null)
      } catch (e: Throwable) {
        result.error("OBX_SO_LOAD_FAILED", e.message, null)
      }
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
