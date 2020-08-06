#import "ObjectboxPlugin.h"
#if __has_include(<objectbox/objectbox-Swift.h>)
#import <objectbox/objectbox-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "objectbox-Swift.h"
#endif

@implementation ObjectboxPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftObjectboxPlugin registerWithRegistrar:registrar];
}
@end
