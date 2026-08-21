import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// The UI for the floating "return to app" bubble — this is what actually
/// runs inside the overlay's own separate Flutter engine (see `overlayMain()`
/// in main.dart), not inside the main app's widget tree. It cannot reach
/// anything from the main isolate (no GetX controllers, no Navigator) — its
/// entire job is: sit on screen over Google Maps, and when tapped, bring
/// this app's own Activity back to the foreground and close itself.
///
/// Deliberately tiny and self-contained (single file, no external state) —
/// a genuinely different runtime context than the rest of the app, and
/// pulling in unrelated app dependencies here would be misleading about
/// what's actually available to it.
class NavReturnBubble extends StatelessWidget {
  const NavReturnBubble({super.key});

  Future<void> _returnToApp() async {
    // Re-launches this app's own launcher Activity. FLAG_ACTIVITY_NEW_TASK
    // is required to start an Activity from outside of one (the overlay has
    // none); FLAG_ACTIVITY_REORDER_TO_FRONT brings the app's existing task
    // back to front with its state intact instead of spawning a fresh one
    // on top of it — the driver should land back exactly where "Start Ride"
    // left them, not on a second instance of the app.
    final intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      category: 'android.intent.category.LAUNCHER',
      package: 'online.nride.driver',
      flags: const [
        Flag.FLAG_ACTIVITY_NEW_TASK,
        Flag.FLAG_ACTIVITY_REORDER_TO_FRONT,
      ],
    );
    await intent.launch();
    // The bubble's job ends the moment the driver has asked to go back to
    // the app — leaving it up means it would just be sitting on top of the
    // app's own UI. NavOverlayService.startNavigation() re-shows it the next
    // time the driver switches back out to Google Maps, so this isn't the
    // last time it can ever appear.
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Transparent scaffold so only the circle itself is visible — the
      // overlay window's own background is otherwise opaque black, which
      // would show as an ugly square around the bubble.
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: GestureDetector(
            onTap: _returnToApp,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0B225F),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_car_filled_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
