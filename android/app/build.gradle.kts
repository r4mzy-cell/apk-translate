plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.translateid"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.translateid"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // Native libraries land here
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // ML Kit Text Recognition v2 (Latin: EN/ID)
    implementation("com.google.mlkit:text-recognition:16.0.1")
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
    implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
    // ONNX Runtime Android for translation (AAR with native libs)
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.22.0")
    // Coroutines for suspend native calls
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    // Provides Task<T>.await() for ML Kit
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")
    // SplashScreen API (Theme.SplashScreen, windowSplashScreenBackground, etc.)
    implementation("androidx.core:core-splashscreen:1.0.1")
    // Material Components themes (Theme.MaterialComponents.*)
    implementation("com.google.android.material:material:1.12.0")
}

flutter {
    source = "../.."
}
