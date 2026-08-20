
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

Future<BitmapDescriptor> getCustomIcon(String path, int width) async {
  final ImageConfiguration config = ImageConfiguration(
    size: Size(width.toDouble(), width.toDouble()),
  );

  // Was BitmapDescriptor.fromAssetImage(), deprecated in favor of
  // BitmapDescriptor.asset() — and not just a lint nag: on newer
  // google_maps_flutter_android builds this deprecated path can produce a
  // descriptor the native Pigeon-based MapsApi fails to decode, throwing
  // "PlatformException: Failed to decode image. The provided image must
  // be a Bitmap." the moment a marker using it is added to the map.
  // Explicit width/height keeps the on-screen size identical to before.
  return BitmapDescriptor.asset(
    config,
    path,
    width: width.toDouble(),
    height: width.toDouble(),
  );
}






/////=================================  customer loader ==========================================



// class PremiumBlurLoader extends StatelessWidget {
//   const PremiumBlurLoader({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       canPop: false,
//       child: Material(
//         type: MaterialType.transparency,
//         child: IgnorePointer(
//           ignoring: false,
//           child: BackdropFilter(
//             filter: ImageFilter.blur(
//               sigmaX: 4,
//               sigmaY: 4,
//             ),
//             child: Container(
//               width: double.infinity,
//               height: double.infinity,
//               color: Colors.black.withOpacity(0.15),
//               alignment: Alignment.center,
//               child: Container(
//                 width: 130,
//                 height: 130,
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(24),
//                   boxShadow: const [
//                     BoxShadow(
//                       blurRadius: 20,
//                       spreadRadius: 2,
//                       color: Colors.black12,
//                     ),
//                   ],
//                 ),
//                 child: const Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     SpinKitThreeBounce(
//                       color: Colors.blue,
//                       size: 28,
//                     ),
//                     SizedBox(height: 12),
//                     Text(
//                       "Loading...",
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

class PremiumBlurLoader extends StatelessWidget {
  const PremiumBlurLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Was canPop: true, paired with a Cancel button below that called
      // Navigator.pop() directly — that only ever closed *this dialog*, not
      // the request it's covering (accept-ride, complete-ride, save-info, …
      // used across ~23 call sites). Tapping it made the loader vanish while
      // the real network call kept running with no more feedback at all —
      // the driver would see nothing happen, then the actual result (an
      // accepted ride, a saved record) would land moments later unannounced.
      // This loader is meant to be a true "please wait", matching the
      // barrierDismissible: false most call sites already use around it.
      canPop: false,
      child: Material(
        type: MaterialType.transparency,
        // Was IgnorePointer -> BackdropFilter(ImageFilter.blur(...)) ->
        // Container. A full-screen Gaussian blur forces a save-layer plus a
        // blur pass over everything behind it, redone every single frame the
        // dialog is up. Used in 23 places across the app, that's real,
        // avoidable jank on mid/low-end Android hardware, and it's exactly
        // the kind of cost that makes a "brief loading moment" (e.g. the
        // accept-ride dialog) feel sluggish to even appear rather than
        // snappy. A flat semi-transparent scrim gives the same dimmed-
        // background look for a fraction of the GPU cost.
        child: IgnorePointer(
          ignoring: false,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withValues(alpha: 0.35),
            alignment: Alignment.center,
            child: Container(
              width: 150,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 20,
                    spreadRadius: 2,
                    color: Colors.black12,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SpinKitThreeBounce(
                    color: Color(0xFF123EBC),
                    size: 28,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Loading...",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
