#include "objectbox_sync_flutter_libs_plugin.h"

namespace objectbox_sync_flutter_libs {

// static
void ObjectboxSyncFlutterLibsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  // Not using method channels, so not registering one.
  (void)registrar;
}

}  // namespace objectbox_sync_flutter_libs
