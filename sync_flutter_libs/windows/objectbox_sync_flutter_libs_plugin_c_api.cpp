#include "include/objectbox_sync_flutter_libs/objectbox_sync_flutter_libs_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "objectbox_sync_flutter_libs_plugin.h"

void ObjectboxSyncFlutterLibsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  objectbox_sync_flutter_libs::ObjectboxSyncFlutterLibsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
