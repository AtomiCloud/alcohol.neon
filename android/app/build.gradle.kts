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
    // suffix + app name. prod (raichu) keeps the clean base id. Build with e.g.
    // `flutter build appbundle --flavor pichu`.
    flavorDimensions += "landscape"
    productFlavors {
        create("pichu") {
            dimension = "landscape"
            applicationIdSuffix = ".pichu"
            manifestPlaceholders["appName"] = "LazyTax Dev"
        }
        create("pikachu") {
            dimension = "landscape"
            applicationIdSuffix = ".pikachu"
            manifestPlaceholders["appName"] = "LazyTax Stage"
        }
        create("raichu") {
            dimension = "landscape"
            manifestPlaceholders["appName"] = "LazyTax"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
