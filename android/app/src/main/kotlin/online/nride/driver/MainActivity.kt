package online.nride.driver

import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        /** Must match flutter_overlay_window's own OverlayConstants.CACHED_TAG. */
        private const val OVERLAY_ENGINE_ID = "myCachedEngine"

        /** Dart entrypoint the overlay's engine runs — see overlayMain() in main.dart. */
        private const val OVERLAY_ENTRYPOINT = "overlayMain"

        /** Channel the floating bubble uses to ask for the app to be reopened. */
        private const val OVERLAY_RETURN_CHANNEL = "online.nride.driver/overlay_return"
    }

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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Before super, which is what triggers plugin registration — and with
        // it flutter_overlay_window's onAttachedToActivity, the thing that
        // would otherwise create the overlay engine itself. Seeding the cache
        // first means it finds ours already there and leaves it alone.
        ensureOverlayEngine()
        super.configureFlutterEngine(flutterEngine)
    }

    /**
     * Creates the floating bubble's Flutter engine ourselves, and gives it a
     * method channel it can use to bring this app back to the foreground.
     *
     * The bubble runs in a *separate* Flutter engine from the rest of the app.
     * flutter_overlay_window builds that engine with
     * `FlutterEngineGroup.createAndRunEngine()` and never calls
     * `GeneratedPluginRegistrant.registerWith()` on it — so that engine has no
     * app plugins in it at all. Every plugin method call the bubble made
     * therefore failed with MissingPluginException, which is why tapping it
     * did nothing whatsoever: there was no android_intent_plus on the other
     * end of the channel to answer.
     *
     * Rather than registering the app's whole plugin set into a second engine
     * (Firebase, Maps, Razorpay and the rest, all for one button), this wires
     * up the single call the bubble actually needs. The engine is cached under
     * flutter_overlay_window's own key so the plugin adopts this one instead
     * of building its own plugin-less replacement.
     */
    private fun ensureOverlayEngine() {
        val cache = FlutterEngineCache.getInstance()
        if (cache.get(OVERLAY_ENGINE_ID) != null) return

        // Held rather than using the Activity: this engine is cached
        // statically and outlives any single MainActivity instance, so a
        // handler capturing `this` would leak a destroyed Activity — and the
        // bubble is tapped precisely when no Activity is in the foreground.
        val appContext = applicationContext

        val engine = FlutterEngineGroup(appContext).createAndRunEngine(
            appContext,
            DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                OVERLAY_ENTRYPOINT,
            ),
        )

        MethodChannel(engine.dartExecutor.binaryMessenger, OVERLAY_RETURN_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "openApp") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val launchIntent =
                    appContext.packageManager.getLaunchIntentForPackage(appContext.packageName)
                if (launchIntent == null) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                // NEW_TASK because this starts from a Service context with no
                // Activity of its own; REORDER_TO_FRONT so the driver lands
                // back on the ride screen they left, with its state intact,
                // rather than on a fresh second copy of the app stacked on it.
                launchIntent.addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
                )
                appContext.startActivity(launchIntent)
                result.success(true)
            }

        cache.put(OVERLAY_ENGINE_ID, engine)
    }
}
