#import "ObjectboxFlutterLibsPlugin.h"
#if __has_include(<objectbox_flutter_libs/objectbox_flutter_libs-Swift.h>)
#import <objectbox_flutter_libs/objectbox_flutter_libs-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "objectbox_flutter_libs-Swift.h"
#endif

@implementation ObjectboxFlutterLibsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftObjectboxFlutterLibsPlugin registerWithRegistrar:registrar];
}
@end
