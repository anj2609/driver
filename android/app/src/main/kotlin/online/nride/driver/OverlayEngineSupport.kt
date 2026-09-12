package online.nride.driver

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Everything the overlay's Flutter engine needs in order to be useful, in one
 * place that BOTH creators of that engine call.
 *
 * There are two, and that is the whole reason this exists. MainActivity builds
 * the overlay engine at app startup; OverlayService builds one itself whenever
 * it finds no live engine in the cache — which is precisely the app-was-killed
 * case the ride-request overlay exists for. The service's engine used to be
 * configured with nothing at all, so in exactly the situation that matters the
 * overlay ran in a crippled engine:
 *
 *  - no `openApp` channel, so the card's Accept could not bring the app
 *    forward. The driver tapped Accept, the card closed, and nothing else
 *    happened — reported as "the accept button in the overlay is not
 *    functional", and it was not: the button ran, the channel it called simply
 *    was not there.
 *  - no shared_preferences, so the Accept could not even be written down for
 *    the app to pick up later.
 *  - no audioplayers, so the card was silent.
 *
 * Configuring from one function means the overlay behaves identically whoever
 * built the engine it is running in. Anything added here is added to both.
 */
object OverlayEngineSupport {

    /** Channel the overlay's Dart side uses to reopen the app and to log. */
    private const val OVERLAY_RETURN_CHANNEL = "online.nride.driver/overlay_return"

    /**
     * Registers the plugins and the channel the overlay's Dart side calls.
     *
     * [context] must be an application context: the engine is cached
     * statically and outlives any single Activity, and the card is tapped
     * precisely when no Activity is in the foreground.
     *
     * Safe to call more than once on the same engine — the plugin registry
     * ignores a duplicate registration, and re-setting the channel handler
     * simply replaces it.
     */
    @JvmStatic
    fun configure(engine: FlutterEngine, context: Context) {
        val appContext = context.applicationContext

        // Only the two plugins the overlay genuinely uses, never
        // GeneratedPluginRegistrant.
        //
        // Registering the whole set was tried and reverted: it also
        // re-registers flutter_overlay_window's OWN plugin onto this engine,
        // and that plugin keeps a single static holder (WindowSetup.messenger)
        // which its onAttachedToEngine overwrites to whichever engine
        // registered last. Doing that here makes the overlay engine "last", and
        // the service's reply channel — which sends back through that exact
        // static — starts replying to itself instead of to the app.
        registerPlugin(engine, "xyz.luan.audioplayers.AudioplayersPlugin")
        registerPlugin(
            engine,
            "io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin",
        )

        MethodChannel(engine.dartExecutor.binaryMessenger, OVERLAY_RETURN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // The overlay engine's own Dart print/debugPrint output
                    // never reaches logcat — only the main isolate's is
                    // mirrored there by the tooling — which made every failure
                    // inside that isolate invisible. Routing its logs back
                    // through native is the only way to see them.
                    "log" -> {
                        Log.d("NrideOverlayDart", call.arguments?.toString() ?: "null")
                        result.success(null)
                    }
                    "openApp" -> result.success(bringAppToFront(appContext))
                    else -> result.notImplemented()
                }
            }

        Log.d("NrideOverlay", "overlay engine configured")
    }

    /**
     * Adds a plugin by class name.
     *
     * Reflection rather than a direct constructor call so that this same
     * function can be invoked from the vendored flutter_overlay_window module,
     * which does not have the other plugin modules on its compile classpath.
     * A missing plugin is survivable — the overlay still works, just without
     * whatever that plugin provided — so it is logged rather than thrown.
     */
    private fun registerPlugin(engine: FlutterEngine, className: String) {
        try {
            val plugin = Class.forName(className).getDeclaredConstructor().newInstance()
            engine.plugins.add(plugin as io.flutter.embedding.engine.plugins.FlutterPlugin)
            Log.d("NrideOverlay", "registered $className on the overlay engine")
        } catch (t: Throwable) {
            Log.e("NrideOverlay", "could not register $className on the overlay engine", t)
        }
    }

    /**
     * Brings this app's existing task back to the foreground, whatever app is
     * currently in front.
     *
     * This used to be a single `startActivity(launchIntent)` with
     * `FLAG_ACTIVITY_NEW_TASK or FLAG_ACTIVITY_REORDER_TO_FRONT`, which worked
     * over some navigation apps and silently did nothing over others. Two
     * reasons, both of which this avoids:
     *
     *  - REORDER_TO_FRONT reorders an activity *within* its task. It is not a
     *    "bring my task to the front" flag, and from a Service context with no
     *    Activity of its own there is frequently no such reordering to
     *    perform — so the call succeeded and nothing visibly happened.
     *  - MainActivity declares `android:taskAffinity=""` in the manifest. Task
     *    matching for FLAG_ACTIVITY_NEW_TASK is done by affinity, so with an
     *    empty one, whether the launch found the app's existing task or was
     *    treated as an unrelated new launch varied by OEM and by which app
     *    happened to own the foreground task at the time. That variance is
     *    exactly the "works in one maps app, not another" symptom.
     *
     * [ActivityManager.AppTask.moveToFront] is the API built for this precise
     * job: it targets the app's own task directly, so it depends on neither
     * affinity matching nor on who is in front. The launcher-style intent is
     * kept only as a fallback for the case where no task exists any more (the
     * app was fully swiped away), where a fresh launch genuinely is the right
     * behaviour.
     *
     * Both paths are background activity starts, which Android 10+ restricts —
     * but an app holding SYSTEM_ALERT_WINDOW is explicitly exempt, and this is
     * only ever reached from an overlay that is on screen.
     */
    @JvmStatic
    fun bringAppToFront(context: Context): Boolean {
        val appContext = context.applicationContext
        try {
            val activityManager =
                appContext.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            val ownTask = activityManager?.appTasks?.firstOrNull { task ->
                task.taskInfo?.baseIntent?.component?.packageName == appContext.packageName
            }
            if (ownTask != null) {
                ownTask.moveToFront()
                Log.d("NrideOverlay", "brought the existing task to the front")
                return true
            }
        } catch (e: Exception) {
            // Falls through to the relaunch below — a card that can't reach
            // the task must still try the one other route it has.
            Log.w("NrideOverlay", "moveToFront failed, falling back to a launch", e)
        }

        val launchIntent =
            appContext.packageManager.getLaunchIntentForPackage(appContext.packageName)
        if (launchIntent == null) {
            Log.e("NrideOverlay", "no launch intent for this package — cannot reopen")
            return false
        }

        launchIntent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED,
        )

        return try {
            appContext.startActivity(launchIntent)
            Log.d("NrideOverlay", "relaunched the app from the overlay")
            true
        } catch (e: Exception) {
            Log.e("NrideOverlay", "could not relaunch the app from the overlay", e)
            false
        }
    }
}
