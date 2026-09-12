import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")

    // Flutter plugin hamesha last me
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "online.nride.driver"

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
        applicationId = "online.nride.driver"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            keyPassword = keyProperties["keyPassword"] as String
            storeFile = file(keyProperties["storeFile"] as String)
            storePassword = keyProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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

// The Navigation SDK ships its OWN copy of the Google Maps SDK inside
// navigation-*.aar — the same com.google.android.gms.maps.* classes that
// play-services-maps provides. google_maps_flutter_android pulls the latter
// transitively, so with both on the classpath every one of those classes is
// defined twice and the build fails at mergeDexDebug with several hundred
// "Duplicate class" errors.
//
// Excluding play-services-maps is Google's own documented resolution, not a
// workaround: the Navigation SDK is meant to be the single source of the Maps
// classes when it is present. google_maps_flutter keeps working unchanged —
// the in-app maps on the home and ride screens still resolve the identical
// classes, just out of the navigation AAR instead.
//
// Scoped with configurations.all rather than to `implementation` alone so it
// also covers the runtime and test classpaths, which resolve separately and
// would otherwise reintroduce the duplicate at packaging time.
configurations.all {
    exclude(group = "com.google.android.gms", module = "play-services-maps")
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

    // ✅ SplashScreen compat — lets us force-dismiss the mandatory
    // Android 12+ Starting Window the instant Flutter's first frame is ready.
    implementation("androidx.core:core-splashscreen:1.0.1")

    // ✅ Desugaring Required
    // The _nio variant, not the plain one. The Google Navigation SDK uses
    // java.nio.file APIs that only the nio flavour of desugar_jdk_libs
    // backports; with the plain artifact the build fails to resolve them on
    // any minSdk below 34. It is a superset of the standard artifact, so
    // flutter_local_notifications (the original reason desugaring is on here)
    // is unaffected by the swap.
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs_nio:2.1.4"
    )
}

// ✅ Google Services
apply(plugin = "com.google.gms.google-services")