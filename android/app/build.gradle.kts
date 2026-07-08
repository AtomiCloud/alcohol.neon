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
        // LPSM application id (cloud.atomi.<landscape>.<platform>.<service>) — identical
        // to the iOS bundle id. Once flavors are declared Android always requires
        // --flavor, so this base id is never shipped; it maps to the local `lapras`
        // landscape purely for consistency with iOS's flavorless configs, and each
        // flavor overrides it with its own landscape below.
        applicationId = "cloud.atomi.lapras.alcohol.neon.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Per-landscape flavors (bundle-id-as-marker): each sets its full LPSM
    // applicationId (cloud.atomi.<landscape>.alcohol.neon.app — identical to iOS) + app
    // name — including prod (raichu), so all three install side-by-side and prod has
    // a distinct id. The Logto redirect scheme is the applicationId itself. Build
    // with e.g. `flutter build appbundle --flavor pichu`.
    flavorDimensions += "landscape"
    productFlavors {
        create("pichu") {
            dimension = "landscape"
            applicationId = "cloud.atomi.pichu.alcohol.neon.app"
            manifestPlaceholders["appName"] = "LazyTax (Pichu)"
            manifestPlaceholders["logtoRedirectScheme"] = "cloud.atomi.pichu.alcohol.neon.app"
        }
        create("pikachu") {
            dimension = "landscape"
            applicationId = "cloud.atomi.pikachu.alcohol.neon.app"
            manifestPlaceholders["appName"] = "LazyTax (Pikachu)"
            manifestPlaceholders["logtoRedirectScheme"] = "cloud.atomi.pikachu.alcohol.neon.app"
        }
        create("raichu") {
            dimension = "landscape"
            applicationId = "cloud.atomi.raichu.alcohol.neon.app"
            manifestPlaceholders["appName"] = "LazyTax"
            manifestPlaceholders["logtoRedirectScheme"] = "cloud.atomi.raichu.alcohol.neon.app"
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
            // Copy PNGs into the bundle verbatim: scripts/ci/stamp-android.sh swaps
            // launcher icons per landscape by matching repo bytes 1:1 (crunching
            // would make the AAB bytes diverge from the repo files). The launcher
            // art is a few KB — the size win from crunching is noise.
            isCrunchPngs = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
