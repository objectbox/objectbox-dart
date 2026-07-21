#include "include/objectbox_flutter_libs/objectbox_flutter_libs_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "objectbox_flutter_libs_plugin.h"

void ObjectboxFlutterLibsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  objectbox_flutter_libs::ObjectboxFlutterLibsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
