plugins {
    // =========================================================
    // ANDROID APPLICATION
    // =========================================================

    id("com.android.application")

    // =========================================================
    // KOTLIN ANDROID
    //
    // Required because MainActivity is written in Kotlin:
    //
    // android/app/src/main/kotlin/
    // com/smartcity/smartcity_infrastructure/MainActivity.kt
    // =========================================================

    id("org.jetbrains.kotlin.android")

    // =========================================================
    // FLUTTER
    //
    // Keep the Flutter Gradle plugin after Android and Kotlin.
    // =========================================================

    id("dev.flutter.flutter-gradle-plugin")
}

// ============================================================
// ANDROID CONFIGURATION
// ============================================================

android {
    // =========================================================
    // PACKAGE / NAMESPACE
    //
    // Must match:
    //
    // MainActivity.kt:
    // package com.smartcity.smartcity_infrastructure
    //
    // AndroidManifest.xml:
    // android:name=".MainActivity"
    // =========================================================

    namespace =
        "com.smartcity.smartcity_infrastructure"

    // =========================================================
    // SDK CONFIGURATION
    // =========================================================

    compileSdk =
        flutter.compileSdkVersion

    ndkVersion =
        flutter.ndkVersion

    // =========================================================
    // JAVA COMPATIBILITY
    // =========================================================

    compileOptions {
        sourceCompatibility =
            JavaVersion.VERSION_17

        targetCompatibility =
            JavaVersion.VERSION_17
    }

    // =========================================================
    // DEFAULT APPLICATION CONFIGURATION
    // =========================================================

    defaultConfig {
        // =====================================================
        // APPLICATION ID
        //
        // This is the actual Android package identifier used
        // when installing and launching SmartCity.
        // =====================================================

        applicationId =
            "com.smartcity.smartcity_infrastructure"

        // =====================================================
        // ANDROID SDK LEVELS
        // =====================================================

        minSdk =
            flutter.minSdkVersion

        targetSdk =
            flutter.targetSdkVersion

        // =====================================================
        // FLUTTER VERSION INFORMATION
        //
        // Read automatically from pubspec.yaml.
        // =====================================================

        versionCode =
            flutter.versionCode

        versionName =
            flutter.versionName
    }

    // =========================================================
    // BUILD TYPES
    // =========================================================

    buildTypes {
        release {
            // =================================================
            // TEMPORARY RELEASE SIGNING
            //
            // Uses the debug signing configuration so release
            // builds can still be tested during development.
            //
            // For actual production/Play Store deployment,
            // replace this with a dedicated release keystore.
            // =================================================

            signingConfig =
                signingConfigs.getByName(
                    "debug"
                )
        }
    }
}

// ============================================================
// KOTLIN CONFIGURATION
//
// Keep Kotlin and Java targeting the same JVM version.
// ============================================================

kotlin {
    compilerOptions {
        jvmTarget =
            org.jetbrains.kotlin.gradle.dsl
                .JvmTarget.JVM_17
    }
}

// ============================================================
// FLUTTER PROJECT ROOT
//
// android/app is two directories below the Flutter project root.
// ============================================================

flutter {
    source =
        "../.."
}