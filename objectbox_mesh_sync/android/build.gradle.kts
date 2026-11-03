group = "io.objectbox.objectbox_mesh_sync"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.3.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.0.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "io.objectbox.objectbox_mesh_sync"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Mesh Sync permissions helper (MeshSyncPermissions); pulls in the Google Play services Nearby
    // dependency (used by NearbyMeshNetwork) and adds permissions to the manifest. As
    // apps are expected to declare the permissions they need explicitly, they are removed in the
    // AndroidManifest.xml of this project.
    implementation("io.objectbox:objectbox-meshsync-android:6.0.0-beta2")
    // Compile against the ObjectBox Android database library (Sync variant), which contains the
    // NearbyMeshNetwork class. At runtime, it is provided by the objectbox_sync_flutter_libs plugin
    // (or replaced by the Admin variant by apps using Admin), so only compileOnly; keep the version
    // the same as there.
    compileOnly("io.objectbox:objectbox-sync-android-db:6.0.0-beta2")
}
