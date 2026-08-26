import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The Play upload keystore lives outside version control. Release builds are
// deliberately left unsigned when the upload key is unavailable; they must
// never silently fall back to the debug signing key.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.swipess.app"

    // Google Play requires new apps and updates to target Android 16 / API 36
    // from August 31, 2026. Pin both values so a local Flutter SDK default cannot
    // accidentally produce a store build below the policy floor.
    compileSdk = 36

    compileOptions {
        // flutter_local_notifications schedules with java.time, which needs the
        // desugared JDK library on the minSdk this app supports.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Matches the shipped Capacitor app so this build installs as an update.
        applicationId = "com.swipess.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Used by the App Links intent filters in AndroidManifest.xml.
        manifestPlaceholders["appLinkHost"] = "www.swipess.com"
        manifestPlaceholders["appLinkHostAlt"] = "swipess.com"
        manifestPlaceholders["appLinkHostApp"] = "swipess.app"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // A production upload must use the real Play upload key. When the
            // key is absent the release stays unsigned, which is safe for CI and
            // impossible to mistake for a valid Play upload artifact.
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
            // Shrinking is left to the Flutter Gradle plugin, which pairs
            // minify and resource shrinking. Setting either here desyncs them
            // and fails configuration; use `--no-shrink` to opt out instead.
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
