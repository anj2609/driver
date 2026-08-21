import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// The UI for the floating "return to app" bubble — this is what actually
/// runs inside the overlay's own separate Flutter engine (see `overlayMain()`
/// in main.dart), not inside the main app's widget tree. It cannot reach
/// anything from the main isolate (no GetX controllers, no Navigator) — its
/// entire job is: sit on screen over Google Maps, and when tapped, bring
/// this app's own Activity back to the foreground and close itself.
///
/// Kept to a bare MaterialApp → Material → the circle, with transparency set
/// explicitly at every level. A Scaffold here paints its own opaque surface
/// across the whole overlay window, which showed up as a black screen rather
/// than a small floating circle.
class NavReturnBubble extends StatelessWidget {
  const NavReturnBubble({super.key});

  /// Handled natively in MainActivity.kt, deliberately, rather than through a
  /// plugin like android_intent_plus.
  ///
  /// flutter_overlay_window builds this overlay's engine without ever calling
  /// GeneratedPluginRegistrant on it, so *no* app plugin exists in this
  /// isolate — every plugin call from here fails with MissingPluginException.
  /// That is why the earlier android_intent_plus version of this button did
  /// nothing at all when tapped. MainActivity registers this one channel
  /// directly on the overlay engine, so it is genuinely present at the other
  /// end. Keep the name in sync with OVERLAY_RETURN_CHANNEL there.
  static const MethodChannel _returnChannel =
      MethodChannel('online.nride.driver/overlay_return');

  Future<void> _returnToApp() async {
    try {
      await _returnChannel.invokeMethod<bool>('openApp');
    } catch (e) {
      debugPrint('[NavReturnBubble] could not reopen the app: $e');
      // Deliberately falls through to closing the overlay below: if the app
      // can't be raised from here the bubble is useless, and leaving it
      // stuck on screen with no way to dismiss it is worse than removing it.
    }

    // The bubble's job ends the moment the driver has asked to go back to
    // the app — leaving it up means it would just be sitting on top of the
    // app's own UI. It is re-shown the next time a ride starts, so this
    // isn't the last time it can ever appear.
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint('[NavReturnBubble] could not close the overlay: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // The app-level colour the OS composites against; without this the
      // window behind the circle is painted opaque.
      color: Colors.transparent,
      home: Material(
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: _returnToApp,
            child: Container(
              width: 62,
              height: 62,
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
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
