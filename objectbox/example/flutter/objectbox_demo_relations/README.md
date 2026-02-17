# ObjectBox example Flutter app using relations

This is a task-list example app that shows how to use ObjectBox in Flutter. 

<img src="screenshot-app.png" height="540"/>

See how to:
- write and annotate classes to create a data model ([model.dart](lib/model.dart))
- define a relation between Entities ([model.dart](lib/model.dart)) and use it ([objectbox.dart](lib/objectbox.dart))
- create a Store ([main.dart](lib/main.dart), [objectbox.dart](lib/objectbox.dart))
- create Boxes and put and delete Objects there ([objectbox.dart](lib/objectbox.dart))
- query for Objects ([objectbox.dart](lib/objectbox.dart) and [tasklist_elements.dart](lib/tasklist_elements.dart))
- add ObjectBox Admin for debug builds ([objectbox.dart](lib/objectbox.dart), [build.gradle](android/app/build.gradle))

## ObjectBox Admin for Android

To use [ObjectBox Admin](https://docs.objectbox.io/data-browser) for debug builds, add the following
to `android/app/build.gradle` (Groovy DSL) or `android/app/build.gradle.kts` (Kotlin DSL):

**Groovy DSL** (`build.gradle`):

```groovy
configurations {
    debugImplementation {
        exclude group: 'io.objectbox', module: 'objectbox-android'
    }
}

dependencies {
    debugImplementation("io.objectbox:objectbox-android-objectbrowser:5.1.0")
}
```

**Kotlin DSL** (`build.gradle.kts`):

```kotlin
configurations {
    named("debugImplementation") {
        exclude(group = "io.objectbox", module = "objectbox-android")
    }
}

dependencies {
    debugImplementation("io.objectbox:objectbox-android-objectbrowser:5.1.0")
}
```

Note: when the objectbox package updates, check if the Android library version above needs to be
updated as well.

## Docs
- [Getting started with ObjectBox](https://docs.objectbox.io/getting-started)
- [How to use ObjectBox Relations](https://docs.objectbox.io/relations)
- [ObjectBox Admin](https://docs.objectbox.io/data-browser)
