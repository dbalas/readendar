import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is driven by android/key.properties (git-ignored, never
// committed). Create it alongside the keystore when you set up Play signing:
//
//   storePassword=...
//   keyPassword=...
//   keyAlias=upload
//   storeFile=/absolute/path/to/upload-keystore.jks
//
// When the file is absent (local dev, CI without secrets) we fall back to the
// debug keystore so `flutter run --release` and `flutter build` still work.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.readendar.readendar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.readendar.readendar"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Real upload key when android/key.properties is present; otherwise
            // the debug key so local/CI release builds still succeed.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Size optimization: R8 code shrinking/obfuscation + resource
            // shrinking. Keep rules for Flutter + reflection-using plugins
            // live in proguard-rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            // Extract native (.so) debug symbols into the bundle's
            // BUNDLE-METADATA instead of shipping them inside the delivered
            // libs. Keeps the user download small while still letting Play
            // symbolicate native crashes. Also satisfies Flutter's release
            // build check that debug symbols were stripped from native libs.
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
    }
}

// Keep the Android and Kotlin bytecode targets aligned. Flutter currently
// supplies the compatible Kotlin toolchain while third-party plugins finish
// migrating to AGP 9's built-in Kotlin support.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Fail loud when an actual release build starts without release signing — a
// silently debug-signed "release" AAB/APK must never leave a machine by
// accident. Deliberate debug-signed release builds (CI smoke tests) opt in
// with -PallowDebugSigning=true. Checked per-task, not at configuration time,
// so debug builds on machines without key.properties keep working.
tasks.configureEach {
    if ((name == "assembleRelease" || name == "bundleRelease") &&
        !hasReleaseSigning &&
        project.findProperty("allowDebugSigning") != "true"
    ) {
        doFirst {
            throw GradleException(
                "Release build without android/key.properties (would be debug-signed). " +
                    "Provide the keystore or pass -PallowDebugSigning=true on purpose.",
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Periodic home-screen widget refresh (ReadendarWidgetWorker); supplements
    // the system-driven updatePeriodMillis + reactive onUpdate self-fetch.
    implementation("androidx.work:work-runtime-ktx:2.11.2")
    implementation("com.google.android.play:app-update:2.1.0")
}
