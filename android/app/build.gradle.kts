import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "cloud.atomi.alcohol_neon"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (desugars java.time APIs).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "cloud.atomi.alcohol_neon"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Per-landscape flavors (bundle-id-as-marker): each gets its own applicationId
    // suffix + app name — including prod (raichu), so all three install side-by-side
    // and prod has a distinct id. Build with e.g. `flutter build appbundle --flavor pichu`.
    flavorDimensions += "landscape"
    productFlavors {
        create("pichu") {
            dimension = "landscape"
            applicationIdSuffix = ".pichu"
            manifestPlaceholders["appName"] = "LazyTax (Pichu)"
            manifestPlaceholders["logtoRedirectScheme"] = "cloud.atomi.alcohol.neon.pichu"
        }
        create("pikachu") {
            dimension = "landscape"
            applicationIdSuffix = ".pikachu"
            manifestPlaceholders["appName"] = "LazyTax (Pikachu)"
            manifestPlaceholders["logtoRedirectScheme"] = "cloud.atomi.alcohol.neon.pikachu"
        }
        create("raichu") {
            dimension = "landscape"
            applicationIdSuffix = ".raichu"
            manifestPlaceholders["appName"] = "LazyTax"
            manifestPlaceholders["logtoRedirectScheme"] = "cloud.atomi.alcohol.neon.raichu"
        }
    }

    // Release signing — use a real upload keystore when one is available. Codemagic
    // sets CM_KEYSTORE_* env vars when the workflow declares `android_signing`;
    // locally you can drop an `android/key.properties`. Falls back to the debug key
    // when neither is present, so `flutter run --release` and local APKs still work.
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }
    val cmKeystorePath: String? = System.getenv("CM_KEYSTORE_PATH")
    val hasReleaseSigning = cmKeystorePath != null || keystorePropertiesFile.exists()

    signingConfigs {
        create("release") {
            if (cmKeystorePath != null) {
                storeFile = file(cmKeystorePath)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
            } else if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // No keystore configured (local dev) — debug-sign so builds still run.
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
