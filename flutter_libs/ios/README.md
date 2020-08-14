Contents of this folder is based on `flutter create --template=plugin`.
It was reduced to the minimum that works for library inclusion by client apps.

Notably, the package depends on `ObjectBox.framework` from ObjectBox Swift distribution, downloading
a released `ObjectBox-framework-X.Y.Z.zip` archive. 

## Current limitations/TODOs
There's currently an [issue](https://github.com/flutter/flutter/issues/45778) with Flutter tooling and/or its integration 
with Cocoapods. In short, an "http" source in the podspec doesn't work - the file has to be available locally.
 
To circumvent this, we're currently including the extracted `ObjectBox.framework` for iOS in the package when publishing 
to pub.dev. Therefore, you need to run ./ios/download-framework.sh before publishing the package.
This has the benefit of a "no-setup" iOS support for the ObjectBox users - it works out of the box.
Also notably, we're only including the bare minimum from the ObjectBox Swift release which means smaller final app size.    
 
Note for contributors: you need to run the above-mentioned script as well to be able to test ObjectBox on iOS.
