plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // IMPORTANT: Change this namespace to match your own domain.
    // Google Play will REJECT any app with "com.example" in the package name.
    namespace = "com.aliimran.zenfocus"
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
        // Your unique Application ID for Google Play Store.
        // This MUST be unique across the entire Play Store.
        // Format: com.yourcompany.appname
        applicationId = "com.aliimran.zenfocus"
        // minSdk 21 ensures compatibility with audioplayers plugin
        // and covers 99%+ of active Android devices.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Before publishing to Play Store, create a proper
            // signing key with: keytool -genkey -v -keystore ~/upload-keystore.jks
            // Then configure signingConfigs.create("release") with your keystore.
            // See: https://docs.flutter.dev/deployment/android#sign-the-app
            signingConfig = signingConfigs.getByName("debug")

            // Enable code shrinking and obfuscation for release builds.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
