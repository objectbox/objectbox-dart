#include "objectbox_flutter_libs_plugin.h"

namespace objectbox_flutter_libs {

// static
void ObjectboxFlutterLibsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  // Not using method channels, so not registering one.
  (void)registrar;
}

}  // namespace objectbox_flutter_libs
