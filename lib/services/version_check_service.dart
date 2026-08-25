import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:myridedriverapp/config/utils/apis/api_client.dart';
import 'package:myridedriverapp/config/utils/constants.dart';

/// Parsed `data` block from GET /app/version?platform=android&version=X.
/// CONFIRMED live shape — see ApiConstants.appVersionCheck.
class AppVersionCheckResult {
  final String currentVersion;
  final String latestVersion;
  final String minimumVersion;
  final bool updateAvailable;
  final bool forceUpdate;
  final String storeUrl;

  /// The message living inside `data`, not the outer envelope's
  /// "App version checked successfully." — that one just confirms the
  /// request itself worked, it's never something to show the driver.
  final String message;

  const AppVersionCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.minimumVersion,
    required this.updateAvailable,
    required this.forceUpdate,
    required this.storeUrl,
    required this.message,
  });

  factory AppVersionCheckResult.fromJson(Map<String, dynamic> data) {
    return AppVersionCheckResult(
      currentVersion: data['current_version']?.toString() ?? '',
      latestVersion: data['latest_version']?.toString() ?? '',
      minimumVersion: data['minimum_version']?.toString() ?? '',
      updateAvailable: data['update_available'] == true,
      forceUpdate: data['force_update'] == true,
      storeUrl: data['store_url']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
    );
  }

  /// Whether the app must be blocked outright rather than just offered an
  /// optional update. True if the backend says so directly (`force_update`)
  /// *or* if the installed version is actually below `minimum_version`,
  /// compared locally as a safety net — a backend response that forgets to
  /// set force_update, or a minimum_version bump that isn't paired with it,
  /// must not be able to leave a genuinely-too-old build running unblocked.
  /// Either signal alone is enough to block; this never lets a "false" from
  /// the local comparison override a backend force_update of true.
  bool get mustBlock =>
      forceUpdate || _isBelowMinimum(currentVersion, minimumVersion);

  static bool _isBelowMinimum(String current, String minimum) {
    if (minimum.trim().isEmpty || current.trim().isEmpty) return false;
    final c = _versionParts(current);
    final m = _versionParts(minimum);
    final len = c.length > m.length ? c.length : m.length;
    for (var i = 0; i < len; i++) {
      final cv = i < c.length ? c[i] : 0;
      final mv = i < m.length ? m[i] : 0;
      if (cv != mv) return cv < mv;
    }
    return false;
  }

  static List<int> _versionParts(String v) =>
      v.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
}

/// Checks whether a newer build is available on the Play Store, and shows
/// the update prompt this app doesn't otherwise have.
///
/// Deliberately fails silently (returns null) on any error — a network
/// hiccup or a backend outage on this one endpoint must never be able to
/// strand a driver on the splash screen or block them from opening an app
/// that is otherwise perfectly capable of launching. This is a courtesy
/// check, not a gate the app's own availability depends on.
class VersionCheckService {
  VersionCheckService._();

  static Future<AppVersionCheckResult?> check() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final response = await Get.find<ApiClient>()
          .getApi(
            '${ApiConstants.appVersionCheck}'
            '?platform=android&version=${packageInfo.version}',
          )
          .timeout(const Duration(seconds: 8));

      final body = response.body;
      if (body is! Map || body['data'] is! Map) return null;

      return AppVersionCheckResult.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
    } catch (e) {
      debugPrint('[VersionCheck] failed: $e');
      return null;
    }
  }

  /// Shows the update prompt appropriate to [result].
  ///
  /// [AppVersionCheckResult.mustBlock] blocks the app entirely: no dismiss,
  /// no close button, PopScope intercepts the system back gesture, and the
  /// only action is opening the Play Store. It also keeps checking on its
  /// own from there — see [_ForceUpdateGate] — so updating and coming back
  /// to the app is what actually restores access, not a specific button in
  /// here. An optional update (mustBlock false) is a normal dismissible
  /// dialog — the driver can keep using this version if they choose to.
  static Future<void> showUpdateDialog(
    BuildContext context,
    AppVersionCheckResult result,
  ) {
    if (result.mustBlock) {
      return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _ForceUpdateGate(initialResult: result),
      );
    }

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Update Available",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            result.message.isNotEmpty
                ? result.message
                : "A new version of Nride driver is available.",
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Later"),
            ),
            TextButton(
              onPressed: () => _openStore(result.storeUrl),
              child: const Text("Update Now"),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _openStore(String storeUrl) async {
    if (storeUrl.isEmpty) return;
    final uri = Uri.tryParse(storeUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[VersionCheck] could not open store URL: $e');
    }
  }
}

/// The forced-update dialog's body. Not a plain AlertDialog — it observes
/// app lifecycle so it can re-check on its own, which is what makes
/// "update in the Play Store, then come back" actually restore access
/// without the driver having to force-kill and relaunch the app: every
/// resume (returning from the Play Store after installing is exactly a
/// resume) re-runs [VersionCheckService.check] and pops itself the moment
/// the fresh result no longer requires blocking.
class _ForceUpdateGate extends StatefulWidget {
  final AppVersionCheckResult initialResult;
  const _ForceUpdateGate({required this.initialResult});

  @override
  State<_ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<_ForceUpdateGate>
    with WidgetsBindingObserver {
  late AppVersionCheckResult _result;
  bool _rechecking = false;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheck();
  }

  Future<void> _recheck() async {
    // Guards against overlapping calls (a driver bouncing rapidly between
    // this app and the store) rather than against ever running twice —
    // each genuine resume should still get its own check.
    if (_rechecking || !mounted) return;
    _rechecking = true;
    try {
      final fresh = await VersionCheckService.check();
      if (!mounted) return;
      // A failed re-check (network hiccup) leaves the gate exactly as it
      // was — never silently unblocks on a null result, and never
      // discards a still-good _result either.
      if (fresh == null) return;
      if (!fresh.mustBlock) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _result = fresh);
    } finally {
      _rechecking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          "Update Required",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          _result.message.isNotEmpty
              ? _result.message
              : "A new version of Nride driver is available.",
          textAlign: TextAlign.center,
        ),
        actions: [
          // Nowhere else for the driver to go but the store — no "Later"
          // here, that's the whole point of a forced update.
          TextButton(
            onPressed: () => VersionCheckService._openStore(_result.storeUrl),
            child: const Text("Update Now"),
          ),
        ],
      ),
    );
  }
}
