plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin must come after Android + Kotlin
    id("dev.flutter.flutter-gradle-plugin")


    // Firebase
    id("com.google.gms.google-services")
}


android {
    namespace = "com.mappaterminal.app.mappaterminal1"
    compileSdk = flutter.compileSdkVersion


    // --- NDK required by MapLibre ---
    ndkVersion = "28.1.13356709"


    defaultConfig {
        applicationId = "com.mappaterminal.app.mappaterminal1"


        // 🔹 Make sure minSdk is at least 21 (MapLibre needs this)
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion


        versionCode = flutter.versionCode
        versionName = flutter.versionName


        // 🔹 Needed for Firebase + MapLibre (large method count)
        multiDexEnabled = true
    }


    compileOptions {
        // ✅ Force Java 11 (fixes obsolete source/target 8 warnings)
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }


    kotlinOptions {
        jvmTarget = "11"
    }


    buildTypes {
        release {
            // TODO: Replace with your own signing config for production
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}


dependencies {
    // 🔹 Multidex support
    implementation("androidx.multidex:multidex:2.0.1")
}


flutter {
    source = "../.."
}

