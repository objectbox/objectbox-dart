#ifndef FLUTTER_PLUGIN_OBJECTBOX_SYNC_FLUTTER_LIBS_PLUGIN_H_
#define FLUTTER_PLUGIN_OBJECTBOX_SYNC_FLUTTER_LIBS_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

namespace objectbox_sync_flutter_libs {

class ObjectboxSyncFlutterLibsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  // Disallow copy and assign.
  ObjectboxSyncFlutterLibsPlugin(const ObjectboxSyncFlutterLibsPlugin&) = delete;
  ObjectboxSyncFlutterLibsPlugin& operator=(const ObjectboxSyncFlutterLibsPlugin&) = delete;
};

}  // namespace objectbox_sync_flutter_libs

#endif  // FLUTTER_PLUGIN_OBJECTBOX_SYNC_FLUTTER_LIBS_PLUGIN_H_
