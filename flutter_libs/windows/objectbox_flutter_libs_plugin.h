#ifndef FLUTTER_PLUGIN_OBJECTBOX_FLUTTER_LIBS_PLUGIN_H_
#define FLUTTER_PLUGIN_OBJECTBOX_FLUTTER_LIBS_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

namespace objectbox_flutter_libs {

class ObjectboxFlutterLibsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  // Disallow copy and assign.
  ObjectboxFlutterLibsPlugin(const ObjectboxFlutterLibsPlugin&) = delete;
  ObjectboxFlutterLibsPlugin& operator=(const ObjectboxFlutterLibsPlugin&) = delete;
};

}  // namespace objectbox_flutter_libs

#endif  // FLUTTER_PLUGIN_OBJECTBOX_FLUTTER_LIBS_PLUGIN_H_
