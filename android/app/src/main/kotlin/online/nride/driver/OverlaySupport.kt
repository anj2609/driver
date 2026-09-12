package online.nride.driver

import android.app.Activity
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The native half of "can this device actually show our overlay, and if not,
 * where do we send the driver to fix it".
 *
 * Everything here exists because `Settings.canDrawOverlays()` — the only
 * check available from Dart — is not a reliable answer on the phones this
 * app's drivers actually use. See [probeOverlay] for the specifics.
 *
 * Deliberately not a full FlutterPlugin: it has no lifecycle of its own and
 * needs nothing but a Context and (for launching Settings) the Activity, so
 * MainActivity wires it directly in configureFlutterEngine.
 */
object OverlaySupport {

    const val CHANNEL = "online.nride.driver/overlay_support"

    private const val TAG = "NrideOverlaySupport"

    /**
     * Attaches the channel to [engine]'s messenger. [activityProvider] is read
     * lazily on each call rather than captured, because the Activity that was
     * current when the engine was configured may already be destroyed by the
     * time the driver taps a "fix this" button.
     */
    fun register(
        messenger: io.flutter.plugin.common.BinaryMessenger,
        appContext: Context,
        activityProvider: () -> Activity?,
    ) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            handle(call, result, appContext, activityProvider)
        }
    }

    private fun handle(
        call: MethodCall,
        result: MethodChannel.Result,
        appContext: Context,
        activityProvider: () -> Activity?,
    ) {
        try {
            when (call.method) {
                "oemInfo" -> result.success(oemInfo())
                "canDrawOverlays" -> result.success(canDrawOverlays(appContext))
                "probeOverlay" -> result.success(probeOverlay(appContext))
                "openOverlaySettings" ->
                    result.success(openOverlaySettings(appContext, activityProvider()))
                "openAutoStartSettings" ->
                    result.success(openAutoStartSettings(appContext, activityProvider()))
                "isIgnoringBatteryOptimizations" ->
                    result.success(isIgnoringBatteryOptimizations(appContext))
                "requestIgnoreBatteryOptimizations" ->
                    result.success(requestIgnoreBatteryOptimizations(appContext, activityProvider()))
                "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent(appContext))
                "openFullScreenIntentSettings" ->
                    result.success(openFullScreenIntentSettings(appContext, activityProvider()))
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            // Every method here is diagnostic or opens a Settings screen.
            // None of them is worth crashing the app over, and a thrown
            // PlatformException on the Dart side would surface as a failure
            // in whatever ride flow happened to be asking.
            Log.e(TAG, "${call.method} failed", e)
            result.success(null)
        }
    }

    // ---------------------------------------------------------------- OEM id

    /**
     * Manufacturer/brand plus the MIUI and ColorOS build markers, which are
     * the only way to tell an OEM skin apart from stock on the same hardware
     * vendor (a Xiaomi device running a custom ROM has no MIUI extra
     * permission to grant, and telling its driver to go looking for one is
     * worse than saying nothing).
     */
    private fun oemInfo(): Map<String, Any?> = mapOf(
        "manufacturer" to Build.MANUFACTURER,
        "brand" to Build.BRAND,
        "model" to Build.MODEL,
        "sdkInt" to Build.VERSION.SDK_INT,
        "miuiVersion" to systemProperty("ro.miui.ui.version.name"),
        "colorOsVersion" to systemProperty("ro.build.version.opporom"),
        "realmeOsVersion" to systemProperty("ro.build.version.realmeui"),
        "vivoOsVersion" to systemProperty("ro.vivo.os.version"),
        "emuiVersion" to systemProperty("ro.build.version.emui"),
    )

    /**
     * Reads a build property via `android.os.SystemProperties`, which is
     * hidden API — hence the reflection. Returns null rather than throwing on
     * any device where the reflection is blocked (it is greylisted, not
     * blocklisted, so this works, but it must not be *depended* on).
     */
    private fun systemProperty(key: String): String? {
        return try {
            @Suppress("PrivateApi")
            val clazz = Class.forName("android.os.SystemProperties")
            val get = clazz.getMethod("get", String::class.java)
            (get.invoke(null, key) as? String)?.takeIf { it.isNotBlank() }
        } catch (e: Throwable) {
            null
        }
    }

    // ------------------------------------------------------------- the probe

    private fun canDrawOverlays(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            // Below API 23 the permission is granted at install time from the
            // manifest declaration alone.
            true
        }
    }

    /**
     * Actually tries to add an overlay window, then removes it again — rather
     * than asking Android whether it thinks we're allowed to.
     *
     * This is the fix for the single worst failure mode this feature had.
     * `Settings.canDrawOverlays()` reports on the standard AOSP
     * SYSTEM_ALERT_WINDOW app-op, and several OEM skins gate overlays behind a
     * *second*, vendor-private permission that op knows nothing about:
     *
     *  - MIUI / HyperOS (Xiaomi, Redmi, Poco): "Display pop-up windows while
     *    running in the background", under Settings > Apps > Permissions >
     *    Other permissions. Separate toggle, separate storage.
     *  - ColorOS / Realme UI: "Floating windows" in App management.
     *  - Funtouch OS / OriginOS (Vivo): its own floating-window allowance.
     *
     * On those devices a driver who has dutifully enabled "Display over other
     * apps" gets `canDrawOverlays() == true`, `showOverlay()` throwing
     * nothing at all, and no bubble — the most expensive kind of bug, because
     * every observable signal says it worked.
     *
     * `WindowManager.addView` is the call that the vendor gate actually
     * rejects, with a BadTokenException ("permission denied for window type
     * 2038"). So the only trustworthy check is to make that exact call. A 1x1,
     * fully transparent, non-touchable, non-focusable window is invisible to
     * the driver and is torn down in the same frame.
     *
     * Honest about its limits: MIUI's gate is specifically about popping up
     * *from the background*, so a probe run while this app is in the
     * foreground can still pass on a device that will refuse the real bubble
     * later. It converts a guaranteed-silent failure into a usually-caught
     * one, which is why [OemOverlaySupport] on the Dart side also shows the
     * vendor-specific instructions for known skins regardless of the probe's
     * verdict, rather than trusting a `true` to mean "nothing more to do".
     */
    private fun probeOverlay(context: Context): Boolean {
        if (!canDrawOverlays(context)) return false

        val windowManager =
            context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
                ?: return false

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            // TYPE_PHONE is the pre-Oreo equivalent, and is the type Android
            // 8+ actively refuses — hence the version split rather than one
            // constant. Same split flutter_overlay_window itself makes.
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            1,
            1,
            type,
            // NOT_FOCUSABLE keeps it out of the input path entirely (no
            // stolen keyboard, no dismissed IME); NOT_TOUCHABLE and
            // NOT_TOUCH_MODAL together mean the one pixel it occupies still
            // passes every touch through to whatever is behind it, so even
            // in the window between add and remove it cannot eat a tap the
            // driver meant for the app.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
        }

        val probe = View(context)
        return try {
            windowManager.addView(probe, params)
            // removeViewImmediate, not removeView: the latter is asynchronous,
            // so a probe that returned before the removal was processed would
            // leave a stray (if invisible) window attached for a frame or
            // two, and repeated probes would stack them.
            try {
                windowManager.removeViewImmediate(probe)
            } catch (e: Exception) {
                Log.w(TAG, "probe window added but not removed cleanly", e)
            }
            Log.d(TAG, "overlay probe accepted — a real overlay can attach")
            true
        } catch (e: Exception) {
            // WindowManager.BadTokenException is the vendor-denial case;
            // SecurityException and others are treated the same way, because
            // the actionable conclusion is identical: do not promise a bubble.
            Log.w(TAG, "overlay probe REJECTED (${e.javaClass.simpleName}): ${e.message}")
            false
        }
    }

    // ------------------------------------------------- vendor Settings pages

    /**
     * Component chains for each skin's own floating-window screen, most
     * specific first. Ordered by how precisely they land: an app-specific
     * permission editor beats a device-wide list the driver then has to
     * search for this app in.
     */
    private val overlaySettingsCandidates: List<ComponentName> = listOf(
        // MIUI / HyperOS — permission editor, pre-filtered to one app when
        // handed extra_pkgname (added in openOverlaySettings below).
        ComponentName(
            "com.miui.securitycenter",
            "com.miui.permcenter.permissions.PermissionsEditorActivity",
        ),
        ComponentName(
            "com.miui.securitycenter",
            "com.miui.permcenter.permissions.AppPermissionsEditorActivity",
        ),
        // ColorOS (Oppo) / Realme UI.
        ComponentName(
            "com.coloros.safecenter",
            "com.coloros.safecenter.permission.floatwindow.FloatWindowListActivity",
        ),
        ComponentName(
            "com.coloros.safecenter",
            "com.coloros.safecenter.sysfloatwindow.FloatWindowListActivity",
        ),
        ComponentName(
            "com.oppo.safe",
            "com.oppo.safe.permission.floatwindow.FloatWindowListActivity",
        ),
        // Funtouch OS / OriginOS (Vivo).
        ComponentName(
            "com.iqoo.secure",
            "com.iqoo.secure.ui.phoneoptimize.FloatWindowManager",
        ),
        ComponentName(
            "com.vivo.permissionmanager",
            "com.vivo.permissionmanager.activity.SoftPermissionDetailActivity",
        ),
        // EMUI / HarmonyOS (Huawei, Honor).
        ComponentName(
            "com.huawei.systemmanager",
            "com.huawei.systemmanager.addviewmonitor.AddViewMonitorActivity",
        ),
        ComponentName(
            "com.huawei.systemmanager",
            "com.huawei.systemmanager.permission.ui.MainActivity",
        ),
    )

    /** Autostart / background-launch managers, same ordering rationale. */
    private val autoStartSettingsCandidates: List<ComponentName> = listOf(
        ComponentName(
            "com.miui.securitycenter",
            "com.miui.permcenter.autostart.AutoStartManagementActivity",
        ),
        ComponentName(
            "com.coloros.safecenter",
            "com.coloros.safecenter.startupapp.StartupAppListActivity",
        ),
        ComponentName(
            "com.coloros.safecenter",
            "com.coloros.safecenter.permission.startup.StartupAppListActivity",
        ),
        ComponentName(
            "com.oppo.safe",
            "com.oppo.safe.permission.startup.StartupAppListActivity",
        ),
        ComponentName(
            "com.iqoo.secure",
            "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
        ),
        ComponentName(
            "com.vivo.permissionmanager",
            "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
        ),
        ComponentName(
            "com.huawei.systemmanager",
            "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
        ),
        ComponentName(
            "com.huawei.systemmanager",
            "com.huawei.systemmanager.optimize.process.ProtectActivity",
        ),
        ComponentName(
            "com.samsung.android.lool",
            "com.samsung.android.sm.ui.battery.BatteryActivity",
        ),
    )

    /**
     * Opens the best available "let this app draw over other apps" screen,
     * preferring the vendor's own (which is where the *extra* toggle lives)
     * and falling back to AOSP's.
     *
     * Returns the string id of whatever was opened, or null if nothing could
     * be — the Dart side uses that to decide whether to tell the driver to
     * navigate by hand.
     *
     * Note the fallback is not a lesser outcome on a stock device: there,
     * ACTION_MANAGE_OVERLAY_PERMISSION *is* the correct and only screen.
     */
    private fun openOverlaySettings(appContext: Context, activity: Activity?): String? {
        for (component in overlaySettingsCandidates) {
            val intent = Intent().apply {
                this.component = component
                // MIUI's permission editor filters to a single app when given
                // this; the others ignore it harmlessly.
                putExtra("extra_pkgname", appContext.packageName)
                putExtra("package_name", appContext.packageName)
                data = Uri.fromParts("package", appContext.packageName, null)
            }
            if (start(intent, appContext, activity)) {
                return component.flattenToShortString()
            }
        }

        // AOSP. Guarded on API 23 because the screen simply does not exist
        // below it — there, the permission came from the manifest and there is
        // nothing for the driver to toggle.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.fromParts("package", appContext.packageName, null),
            )
            if (start(intent, appContext, activity)) return "aosp:manage_overlay_permission"

            // Without the package URI as a last resort: some skins reject the
            // targeted form and accept the device-wide list.
            if (start(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION), appContext, activity)) {
                return "aosp:manage_overlay_permission_list"
            }
        }

        // Absolute floor — this app's own details page always exists, and the
        // toggle is reachable from it on every skin, just with more taps.
        val details = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", appContext.packageName, null),
        )
        return if (start(details, appContext, activity)) "aosp:app_details" else null
    }

    private fun openAutoStartSettings(appContext: Context, activity: Activity?): String? {
        for (component in autoStartSettingsCandidates) {
            val intent = Intent().apply {
                this.component = component
                putExtra("extra_pkgname", appContext.packageName)
                putExtra("package_name", appContext.packageName)
            }
            if (start(intent, appContext, activity)) return component.flattenToShortString()
        }
        return null
    }

    // ------------------------------------------------- battery optimisation

    /**
     * Whether this app is exempt from Doze/App Standby.
     *
     * Matters for the bubble and for the overlay's foreground service: an OEM
     * battery manager that kills the service takes the bubble with it
     * mid-ride, which looks exactly like the permission never having been
     * granted.
     */
    private fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val powerManager =
            context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    /**
     * Shows the system's own "allow this app to run in the background?"
     * dialog via ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS.
     *
     * Uses the targeted dialog rather than
     * ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS (the device-wide list)
     * because the dialog is a single tap and cannot be got lost in. It does
     * require REQUEST_IGNORE_BATTERY_OPTIMIZATIONS in the manifest, and Play
     * Console requires that permission's use to be justified on submission —
     * continuous location tracking during a live ride is the documented
     * acceptable case.
     *
     * Returns false (and opens the list instead, if it can) rather than
     * throwing when the dialog is unavailable, which some skins do.
     */
    private fun requestIgnoreBatteryOptimizations(
        appContext: Context,
        activity: Activity?,
    ): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        if (isIgnoringBatteryOptimizations(appContext)) return true

        @Suppress("BatteryLife") // Justified above; declared in Play Console.
        val intent = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.fromParts("package", appContext.packageName, null),
        )
        if (start(intent, appContext, activity)) return true

        return start(
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            appContext,
            activity,
        )
    }

    // ------------------------------------------------ full-screen intents

    /**
     * Whether a full-screen-intent notification will actually take over the
     * screen, as opposed to quietly degrading to a heads-up banner.
     *
     * Android 14 (API 34) stopped granting USE_FULL_SCREEN_INTENT at install
     * time to everything that asked. It is now pre-granted only to apps whose
     * core function is calling or alarms; everything else starts revoked and
     * has to send the driver to ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT.
     *
     * A revoked permission is NOT a failure for us — the notification still
     * posts, still makes noise, and still opens the app when tapped. It just
     * doesn't cover the screen. So this is used to decide whether to bother
     * asking, never to decide whether to post.
     */
    private fun canUseFullScreenIntent(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // API 33 and below: granted from the manifest declaration alone.
            return true
        }
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return false
        return notificationManager.canUseFullScreenIntent()
    }

    private fun openFullScreenIntentSettings(
        appContext: Context,
        activity: Activity?,
    ): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return false
        val intent = Intent(
            Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
            Uri.fromParts("package", appContext.packageName, null),
        )
        return start(intent, appContext, activity)
    }

    // ---------------------------------------------------------------- launch

    /**
     * Starts [intent], preferring the Activity so the Settings screen lands on
     * top of this app's task and Back returns here.
     *
     * Every call is in a try/catch and every failure is a plain false, because
     * this is entirely a best-effort probe of what the OEM happens to ship:
     * a component in the candidate lists above may not exist (wrong skin
     * version), may not be exported (SecurityException), or may be
     * deliberately blocked. Resolving with PackageManager first was tried and
     * dropped — Android 11+ package visibility makes resolveActivity return
     * null for packages this app cannot see, including ones whose activities
     * it can nonetheless start, so it produced false negatives on exactly the
     * devices this is for.
     */
    private fun start(intent: Intent, appContext: Context, activity: Activity?): Boolean {
        return try {
            if (activity != null && !activity.isFinishing) {
                activity.startActivity(intent)
            } else {
                // NEW_TASK is mandatory from a non-Activity context, and
                // Android throws rather than warns if it is missing.
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                appContext.startActivity(intent)
            }
            true
        } catch (e: Exception) {
            Log.d(TAG, "cannot start ${intent.component ?: intent.action}: ${e.javaClass.simpleName}")
            false
        }
    }
}
