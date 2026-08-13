package online.nride.driver

import android.os.Build
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Guarded to API 31+ deliberately. This block exists only to
        // force-dismiss the *Android 12+* mandatory Starting Window, so it has
        // nothing to do below 31 — and below 31 it was fatal.
        //
        // androidx.core:core-splashscreen picks its implementation off
        // SDK_INT: API 31+ gets Impl31, which wraps the platform SplashScreen;
        // everything below gets the compat Impl, which builds its own
        // SplashScreenViewProvider by inflating the library's bundled layout.
        // That layout sizes its icon from ?attr/splashScreenIconSize — an
        // attribute only Theme.SplashScreen defines. LaunchTheme here descends
        // from @android:style/Theme.Light.NoTitleBar, so the attribute never
        // resolved, TypedArray.getLayoutDimension threw InflateException inside
        // setOnExitAnimationListener, and *every* launch on Android 11 and
        // below died with "Nride driver keeps stopping" before Flutter started.
        // Using the library correctly would mean re-parenting LaunchTheme onto
        // Theme.SplashScreen, but that fights both flutter_native_splash (which
        // regenerates these styles) and Flutter's own NormalTheme handoff for
        // no gain on the versions that don't need it.
        val splashScreen =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) installSplashScreen() else null

        super.onCreate(savedInstanceState)

        // Skip the default exit fade/scale animation entirely — remove the
        // splash the instant the system is ready to transition off it.
        splashScreen?.setOnExitAnimationListener { splashScreenView ->
            splashScreenView.remove()
        }
    }
}
