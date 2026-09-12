import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The OEM skins that gate overlays behind a permission of their own, on top
/// of Android's standard "Display over other apps".
///
/// Only skins with a *distinct action the driver has to take* get an entry.
/// Samsung, Motorola, Nokia, Pixel and the rest are [OemFamily.stock] not
/// because they're identical internally, but because on them enabling the one
/// AOSP toggle is genuinely sufficient — and inventing extra steps for a
/// driver who has already finished is its own bug.
enum OemFamily {
  /// Xiaomi, Redmi, Poco running MIUI or HyperOS. The worst offender: its
  /// extra permission is *separately stored*, so `canDrawOverlays()` returns
  /// true while the overlay is still refused.
  xiaomi,

  /// Oppo (ColorOS) and Realme (Realme UI) — same security-centre lineage,
  /// same "Floating windows" toggle, same startup manager.
  oppoRealme,

  /// Vivo and iQOO (Funtouch OS, OriginOS).
  vivo,

  /// Huawei and Honor (EMUI, HarmonyOS).
  huawei,

  /// Everything else, including Samsung and Pixel, where the standard
  /// permission is the whole story.
  stock,
}

/// What a driver on this device still has to do, beyond the AOSP toggle,
/// before an overlay will appear.
class OemOverlayGuidance {
  const OemOverlayGuidance({
    required this.family,
    required this.brandLabel,
    required this.extraPermissionName,
    required this.steps,
    required this.needsAutoStart,
  });

  final OemFamily family;

  /// How to name the phone to its owner — "Xiaomi/Redmi", not "xiaomi".
  final String brandLabel;

  /// The vendor's own wording for the extra toggle, verbatim where known.
  /// Drivers are looking at a settings screen while reading this, so
  /// paraphrasing it actively hurts.
  final String? extraPermissionName;

  /// Ordered, human instructions. Empty on [OemFamily.stock].
  final List<String> steps;

  /// Whether this skin also needs the app allowed in an autostart/background
  /// manager for the overlay's service to survive being backgrounded.
  final bool needsAutoStart;

  bool get hasExtraSteps => steps.isNotEmpty;
}

/// Bridges to [OverlaySupport] on the native side: whether an overlay can
/// *actually* be shown on this device, and where to send the driver if not.
///
/// This exists because the plugin-level check the app used before
/// (`FlutterOverlayWindow.isPermissionGranted()`, which is
/// `Settings.canDrawOverlays()`) reports on the AOSP app-op only, and on a
/// large slice of this app's real fleet that op is not what decides whether a
/// window attaches. See OverlaySupport.probeOverlay for the mechanics.
class OemOverlaySupport {
  OemOverlaySupport._();

  static const MethodChannel _channel = MethodChannel(
    'online.nride.driver/overlay_support',
  );

  /// Cached for the process lifetime — [Build] properties cannot change while
  /// the app is running, and the onboarding path reads this on every launch.
  static OemOverlayGuidance? _cachedGuidance;

  /// Whether the native channel is reachable at all.
  ///
  /// False on iOS, and false in the overlay engine's own isolate (which never
  /// gets this channel registered — only the main engine does, see
  /// MainActivity.configureFlutterEngine). Every method below degrades to a
  /// safe default rather than throwing there, because
  /// `showIncomingRideRequest` is called from the FCM background isolate.
  static bool get _supported => defaultTargetPlatform == TargetPlatform.android;

  /// Android's own `Settings.canDrawOverlays()`. Kept available separately
  /// from [overlayActuallyWorks] so the two can be compared — a true here
  /// with a false there is precisely the MIUI case, and worth logging as
  /// such rather than reporting as a generic denial.
  static Future<bool> canDrawOverlays() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('[OemOverlay] canDrawOverlays failed: $e');
      return false;
    }
  }

  /// Tries to attach a real (1x1, invisible, untouchable) overlay window and
  /// tears it down again, returning whether Android let it.
  ///
  /// The one check worth trusting. Returns false when the channel is
  /// unavailable, which is deliberately the pessimistic direction: a caller
  /// that can't verify should fall back to the notification path rather than
  /// promise a bubble it may not be able to show.
  /// Returns true (a window attached), false (Android refused it), or **null
  /// when the probe could not run at all**.
  ///
  /// That third case is not pedantry, it was a real outage. The native
  /// channel is registered in MainActivity.configureFlutterEngine, so it
  /// exists only on the app's *main* engine — not in the FCM background
  /// isolate, which is a separate engine and is exactly where an incoming
  /// ride push is handled. This used to collapse MissingPluginException into
  /// `false`, so every ride-request push concluded "overlays don't work
  /// here" and fell through to the notification. The overlay card therefore
  /// never appeared from a push on ANY device, including ones where overlays
  /// work perfectly — reported as "the overlay is still not coming".
  ///
  /// Callers must treat null as "unknown, fall back to the app-op", never as
  /// a denial. See NavOverlayService.canActuallyShowOverlay.
  static Future<bool?> overlayActuallyWorks() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('probeOverlay');
    } on MissingPluginException {
      // No channel on this engine — cannot verify, must not deny.
      debugPrint(
        '[OemOverlay] probe unavailable on this isolate (no native channel) '
        '— deferring to the standard permission check.',
      );
      return null;
    } catch (e) {
      debugPrint('[OemOverlay] probeOverlay failed: $e');
      return null;
    }
  }

  /// Logs both readings side by side. Called from the permission onboarding
  /// so a driver support ticket ("I turned it on and there's still no
  /// button") has the one line that distinguishes the two causes.
  static Future<void> logOverlayDiagnosis() async {
    if (!_supported) return;
    final aosp = await canDrawOverlays();
    final real = await overlayActuallyWorks();
    final guidance = await guidance_();
    // `real == false` only — a null probe means "couldn't check", which is
    // not evidence of a vendor gate and must not be reported as one.
    if (aosp && real == false) {
      debugPrint(
        '[OemOverlay] DIAGNOSIS: Android reports the overlay permission as '
        'GRANTED but a real overlay window was REJECTED. This is the '
        '${guidance.brandLabel} vendor gate — '
        '"${guidance.extraPermissionName ?? "an additional vendor permission"}" '
        'is still off. The bubble will not appear; the return notification is '
        'the working path.',
      );
    } else {
      debugPrint(
        '[OemOverlay] DIAGNOSIS: canDrawOverlays=$aosp probeAttached=$real '
        'brand=${guidance.brandLabel} family=${guidance.family.name}',
      );
    }
  }

  /// Reads [Build.MANUFACTURER] and the skin version markers natively, and
  /// maps them to the instructions for this phone.
  ///
  /// Named with a trailing underscore only to keep the getter-like call site
  /// readable next to the `guidance` field on the returned object.
  static Future<OemOverlayGuidance> guidance_() async {
    final cached = _cachedGuidance;
    if (cached != null) return cached;

    Map<String, dynamic> info = const <String, dynamic>{};
    if (_supported) {
      try {
        final raw = await _channel.invokeMapMethod<String, dynamic>('oemInfo');
        if (raw != null) info = raw;
      } on MissingPluginException {
        // Falls through to the stock guidance below.
      } catch (e) {
        debugPrint('[OemOverlay] oemInfo failed: $e');
      }
    }

    final guidance = _classify(info);
    _cachedGuidance = guidance;
    return guidance;
  }

  /// Maps build properties to a family.
  ///
  /// Checks the skin markers (ro.miui.ui.version.name and friends) *as well
  /// as* the manufacturer, not instead of it: the marker is the more accurate
  /// signal — a Xiaomi phone flashed with a stock ROM has no MIUI permission
  /// to grant, and sending its driver hunting for one wastes their time — but
  /// the reflection that reads it is hidden API and allowed to fail, so the
  /// manufacturer remains the fallback.
  static OemOverlayGuidance _classify(Map<String, dynamic> info) {
    String prop(String key) =>
        (info[key] as String?)?.trim().toLowerCase() ?? '';

    final manufacturer = prop('manufacturer');
    final brand = prop('brand');
    final vendor = '$manufacturer $brand';

    final hasMiui = prop('miuiVersion').isNotEmpty;
    final hasColorOs = prop('colorOsVersion').isNotEmpty;
    final hasRealmeUi = prop('realmeOsVersion').isNotEmpty;
    final hasFuntouch = prop('vivoOsVersion').isNotEmpty;
    final hasEmui = prop('emuiVersion').isNotEmpty;

    bool vendorIs(List<String> names) =>
        names.any((name) => vendor.contains(name));

    if (hasMiui || vendorIs(const ['xiaomi', 'redmi', 'poco'])) {
      return const OemOverlayGuidance(
        family: OemFamily.xiaomi,
        brandLabel: 'Xiaomi / Redmi / Poco',
        extraPermissionName: 'Display pop-up windows while running in the background',
        steps: <String>[
          'Open Settings > Apps > Manage apps > Nride driver.',
          'Tap "Other permissions".',
          'Turn ON "Display pop-up windows while running in the background".',
          'Also turn ON "Display pop-up windows" if it is listed separately.',
          'Go back to Settings > Apps > Permissions > Autostart and enable Nride driver.',
        ],
        needsAutoStart: true,
      );
    }

    if (hasColorOs ||
        hasRealmeUi ||
        vendorIs(const ['oppo', 'realme', 'oplus'])) {
      return const OemOverlayGuidance(
        family: OemFamily.oppoRealme,
        brandLabel: 'Oppo / Realme',
        extraPermissionName: 'Floating windows',
        steps: <String>[
          'Open Settings > Apps > App management > Nride driver.',
          'Turn ON "Display over other apps" (sometimes "Floating windows").',
          'Go back and open Settings > Apps > Auto-launch (or Startup manager).',
          'Enable Nride driver so it can run while you navigate.',
        ],
        needsAutoStart: true,
      );
    }

    if (hasFuntouch || vendorIs(const ['vivo', 'iqoo'])) {
      return const OemOverlayGuidance(
        family: OemFamily.vivo,
        brandLabel: 'Vivo / iQOO',
        extraPermissionName: 'Display over other apps',
        steps: <String>[
          'Open Settings > Apps > Special app access > Display over other apps.',
          'Turn it ON for Nride driver.',
          'Open the iManager app > App manager > Permission manager.',
          'Allow "Background high power consumption" and autostart for Nride driver.',
        ],
        needsAutoStart: true,
      );
    }

    if (hasEmui || vendorIs(const ['huawei', 'honor'])) {
      return const OemOverlayGuidance(
        family: OemFamily.huawei,
        brandLabel: 'Huawei / Honor',
        extraPermissionName: 'Display over other apps',
        steps: <String>[
          'Open Settings > Apps > Nride driver > Display over other apps and turn it ON.',
          'Open Phone Manager > App launch.',
          'Switch Nride driver to Manage manually and enable all three options.',
        ],
        needsAutoStart: true,
      );
    }

    return const OemOverlayGuidance(
      family: OemFamily.stock,
      brandLabel: 'Android',
      extraPermissionName: null,
      steps: <String>[],
      needsAutoStart: false,
    );
  }

  /// Opens the most specific "display over other apps" screen this device
  /// has — the vendor's own where one exists, since that is where the extra
  /// toggle lives, and AOSP's otherwise.
  ///
  /// Returns the identifier of whatever opened (for logs), or null if no
  /// screen could be opened at all, in which case the caller should fall back
  /// to showing [OemOverlayGuidance.steps] as plain text for the driver to
  /// follow by hand.
  static Future<String?> openOverlaySettings() async {
    if (!_supported) return null;
    try {
      final opened = await _channel.invokeMethod<String>('openOverlaySettings');
      debugPrint('[OemOverlay] opened overlay settings: $opened');
      return opened;
    } catch (e) {
      debugPrint('[OemOverlay] openOverlaySettings failed: $e');
      return null;
    }
  }

  /// Opens the skin's autostart / background-launch manager. Null when this
  /// device has none, which is the normal case on stock Android — there is no
  /// such screen because there is no such restriction.
  static Future<String?> openAutoStartSettings() async {
    if (!_supported) return null;
    try {
      final opened = await _channel.invokeMethod<String>(
        'openAutoStartSettings',
      );
      debugPrint('[OemOverlay] opened autostart settings: $opened');
      return opened;
    } catch (e) {
      debugPrint('[OemOverlay] openAutoStartSettings failed: $e');
      return null;
    }
  }

  // ------------------------------------------------- battery optimisation

  /// Whether this app is already exempt from battery optimisation.
  ///
  /// Returns true when unknown. This gates whether to *ask* the driver for
  /// something, and pestering a driver who has already granted it (or whose
  /// platform has no such concept) is worse than missing one who hasn't.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_supported) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
    } catch (e) {
      debugPrint('[OemOverlay] battery-optimisation check failed: $e');
      return true;
    }
  }

  /// Shows the system dialog asking to exempt this app from battery
  /// optimisation — one tap, no Settings hunt.
  ///
  /// Worth asking for even on devices where the bubble works: an OEM battery
  /// manager that kills the overlay's foreground service mid-ride removes the
  /// bubble that was already on screen, which is indistinguishable to the
  /// driver from the permission never having worked.
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!_supported) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'requestIgnoreBatteryOptimizations',
          ) ??
          false;
    } catch (e) {
      debugPrint('[OemOverlay] battery-optimisation request failed: $e');
      return false;
    }
  }

  // -------------------------------------------------- full-screen intents

  /// Whether a full-screen-intent notification will take over the screen
  /// rather than degrading to a heads-up banner.
  ///
  /// True below Android 14. On 14+ this is revoked by default for apps that
  /// are not primarily calling/alarm apps. A false is not a failure — see
  /// NavOverlayService.showIncomingRideNotification, which posts either way.
  static Future<bool> canUseFullScreenIntent() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('canUseFullScreenIntent') ??
          false;
    } on MissingPluginException {
      // The FCM background isolate has no channel; assume the weaker
      // behaviour and post a heads-up notification, which needs no permission.
      return false;
    } catch (e) {
      debugPrint('[OemOverlay] canUseFullScreenIntent failed: $e');
      return false;
    }
  }

  /// Opens Android 14+'s per-app full-screen-intent setting. False below 14,
  /// where the screen does not exist.
  static Future<bool> openFullScreenIntentSettings() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'openFullScreenIntentSettings',
          ) ??
          false;
    } catch (e) {
      debugPrint('[OemOverlay] openFullScreenIntentSettings failed: $e');
      return false;
    }
  }
}
