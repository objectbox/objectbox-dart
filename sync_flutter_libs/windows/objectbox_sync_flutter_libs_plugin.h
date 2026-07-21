#ifndef FLUTTER_PLUGIN_OBJECTBOX_SYNC_FLUTTER_LIBS_PLUGIN_H_
#define FLUTTER_PLUGIN_OBJECTBOX_SYNC_FLUTTER_LIBS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace objectbox_sync_flutter_libs {

class ObjectboxSyncFlutterLibsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  ObjectboxSyncFlutterLibsPlugin();

  virtual ~ObjectboxSyncFlutterLibsPlugin();

  // Disallow copy and assign.
  ObjectboxSyncFlutterLibsPlugin(const ObjectboxSyncFlutterLibsPlugin&) = delete;
  ObjectboxSyncFlutterLibsPlugin& operator=(const ObjectboxSyncFlutterLibsPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace objectbox_sync_flutter_libs

#endif  // FLUTTER_PLUGIN_OBJECTBOX_SYNC_FLUTTER_LIBS_PLUGIN_H_
