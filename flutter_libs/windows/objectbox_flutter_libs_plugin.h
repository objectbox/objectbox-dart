#ifndef FLUTTER_PLUGIN_OBJECTBOX_FLUTTER_LIBS_PLUGIN_H_
#define FLUTTER_PLUGIN_OBJECTBOX_FLUTTER_LIBS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace objectbox_flutter_libs {

class ObjectboxFlutterLibsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  ObjectboxFlutterLibsPlugin();

  virtual ~ObjectboxFlutterLibsPlugin();

  // Disallow copy and assign.
  ObjectboxFlutterLibsPlugin(const ObjectboxFlutterLibsPlugin&) = delete;
  ObjectboxFlutterLibsPlugin& operator=(const ObjectboxFlutterLibsPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace objectbox_flutter_libs

#endif  // FLUTTER_PLUGIN_OBJECTBOX_FLUTTER_LIBS_PLUGIN_H_
