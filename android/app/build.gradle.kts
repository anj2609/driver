plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")

    // Flutter plugin hamesha last me
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.myrideinfinitidriver"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {

        // ✅ Java 17 Support
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // ✅ Required for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.myrideinfinitidriver"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {

            // Temporary debug signing
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// ✅ Kotlin JVM 17
kotlin {
    compilerOptions {
        jvmTarget.set(
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        )
    }
}

flutter {
    source = "../.."
}

dependencies {

    // ✅ Firebase BOM
    implementation(
        platform(
            "com.google.firebase:firebase-bom:34.11.0"
        )
    )

    // ✅ Firebase
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-messaging")

    // ✅ OkHttp
    implementation("com.squareup.okhttp3:okhttp:4.11.0")

    // ✅ Desugaring Required
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )
}

// ✅ Google Services
apply(plugin = "com.google.gms.google-services")