package online.nride.driver

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import flutter.overlay.window.flutter_overlay_window.OverlayService

class MainActivity : FlutterActivity() {

    companion object {
        /** Must match flutter_overlay_window's own OverlayConstants.CACHED_TAG. */
        private const val OVERLAY_ENGINE_ID = "myCachedEngine"

        /** Dart entrypoint the overlay's engine runs — see overlayMain() in main.dart. */
        private const val OVERLAY_ENTRYPOINT = "overlayMain"

        /** Channel the floating bubble uses to ask for the app to be reopened. */
        // The overlay's return channel now lives with the rest of the overlay
        // engine's setup, in OverlayEngineSupport.

        /// How long after the Activity is configured the overlay engine is
        /// built. Long enough to be clear of the first frame, short enough that
        /// the engine is warm well before any ride push realistically arrives.
        private const val OVERLAY_ENGINE_WARMUP_DELAY_MS = 1200L
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

    /// Takes the ride-request overlay down the instant this app is on screen.
    ///
    /// The Dart side does this too (HomeController's resume handler calls
    /// NavOverlayService.dismissOverlay), but not instantly enough on the case
    /// that matters most: the overlay exists precisely when the app is NOT
    /// running, so opening it from the card is a cold start — several seconds
    /// of splash and Flutter boot before any Dart lifecycle callback can fire,
    /// all of it with the card still sitting over the launching app.
    ///
    /// onResume needs none of that. Stopping OverlayService is exactly what the
    /// plugin's own closeOverlay does, so this is the same teardown, just
    /// reached without waiting for an engine. The Dart path still runs after
    /// and is what silences the ringtone, since only the overlay engine can
    /// dispose the card's State.
    override fun onResume() {
        super.onResume()
        try {
            stopService(Intent(this, OverlayService::class.java))
        } catch (e: Exception) {
            Log.w("MainActivity", "could not stop the overlay on resume", e)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Warmed AFTER the first frame, never during startup.
        //
        // ensureOverlayEngine() builds a second Flutter engine, and
        // createAndRunEngine() loads the app bundle and starts a whole Dart
        // isolate. It used to run right here, synchronously, before super and
        // therefore before Flutter had drawn anything — so every launch blocked
        // the main thread on it and the driver watched a white screen. On the
        // launch that matters most, the cold start that follows tapping Accept
        // on a ride card, that wait is long enough to read as a crash, and long
        // enough for Android to consider posting an ANR.
        //
        // It used to have to run before super, because super registers
        // flutter_overlay_window and that plugin's onAttachedToActivity built
        // and cached an overlay engine of its own — winning the race and
        // leaving our openApp channel wired to an engine nobody used. That
        // eager creation is gone (see the NRIDE PATCH in
        // FlutterOverlayWindowPlugin), so nothing competes for the cache any
        // more and the ordering constraint is gone with it.
        //
        // Deferred rather than dropped: a cold overlay engine makes the first
        // ride card slower to appear, and OverlayService would have to build
        // one inside its own startForeground budget. A second after launch is
        // far earlier than any realistic push, and costs the driver nothing.
        Handler(Looper.getMainLooper()).postDelayed({
            if (!isFinishing && !isDestroyed) ensureOverlayEngine()
        }, OVERLAY_ENGINE_WARMUP_DELAY_MS)

        // Wired onto the MAIN engine, not the overlay one: its callers are the
        // home screen's permission onboarding and NavOverlayService, both of
        // which run in the app's own isolate. The Activity is passed as a
        // provider rather than captured so that a Settings screen opened
        // minutes later still launches from a live Activity if there is one —
        // see OverlaySupport.start.
        OverlaySupport.register(
            flutterEngine.dartExecutor.binaryMessenger,
            applicationContext,
        ) { if (isFinishing || isDestroyed) null else this }
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

        // One shared configuration, deliberately — see OverlayEngineSupport.
        //
        // This used to be spelled out inline here, which meant it applied only
        // to an engine THIS class built. OverlayService builds one too whenever
        // the cache holds no live engine, and that is the app-was-killed path —
        // exactly when the ride card matters — so the overlay ran there with no
        // plugins and, worse, no `openApp` channel: Accept closed the card and
        // did nothing else.
        OverlayEngineSupport.configure(engine, appContext)

        cache.put(OVERLAY_ENGINE_ID, engine)
    }

    // bringAppToFront moved to OverlayEngineSupport, so the overlay behaves the
    // same whichever class built the engine it is running in.
}
