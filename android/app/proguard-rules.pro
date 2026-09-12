# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Gson / JSON models
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# Razorpay
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Google Maps
-keep class com.google.maps.** { *; }

# App models (prevent stripping data classes used with JSON)
-keep class online.nride.driver.** { *; }

# Play Core (Flutter deferred components — classes not bundled in AAB)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# Google Navigation SDK
#
# play-services-maps is excluded from this build so the Navigation SDK can be
# the single provider of the com.google.android.gms.maps.* classes (see
# app/build.gradle.kts — with both present every one of those classes is
# defined twice and the build fails at dex merge). The Navigation SDK's
# bundled copy is missing exactly one class that android-maps-utils
# references, MapsApiSettings, so R8 fails the build on the dangling
# reference.
#
# Suppressed rather than satisfied because the only caller is
# AttributionIdInitializer, whose androidx.startup registration is removed in
# AndroidManifest.xml — so the reference is unreachable at runtime and the
# warning is R8 correctly reporting code that can no longer execute. Removing
# only that one manifest entry is what makes this dontwarn safe; if the
# initializer is ever restored, this rule stops being safe with it.
-dontwarn com.google.android.gms.maps.MapsApiSettings

# Overlay engine configuration, reached only by reflection.
#
# OverlayService (in the vendored flutter_overlay_window) builds its own
# Flutter engine whenever the cache holds no live one — the app-was-killed
# path, i.e. exactly when the ride-request card matters — and hands it to
# OverlayEngineSupport.configure() to be set up the same way MainActivity sets
# up the engine IT builds. That call is reflective, because the dependency has
# to point from the plugin module back to the app module and a compile-time
# reference would be a cycle.
#
# R8 sees no caller and is therefore free to rename or remove this class. It
# would do so only in release, so without this rule the overlay's Accept button
# works in every debug build and silently does nothing in the shipped one:
# the card closes, the app never comes forward, and the ride is lost.
-keep class online.nride.driver.OverlayEngineSupport { *; }
