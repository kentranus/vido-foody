plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must come after Android & Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vido.pos.dual"
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // applicationId — change this if you want to install side-by-side
        // with another Vido build on the same device.
        applicationId = "com.vido.pos.dual"
        minSdk = 21       // Android 5.0+ (Presentation API requires 17, but we use 21 baseline)
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        getByName("release") {
            // Debug signing so a "flutter build apk --release" still installs
            // without configuring a keystore. Replace before publishing.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

// Auto-include any JARs dropped into android/app/libs/ — this is where
// POSLink_VX.XX.jar from PAX Technology should be placed to enable real
// card payments. The plugin runs in mock mode until a JAR is present.
dependencies {
    implementation(fileTree("libs") { include("*.jar") })
}
