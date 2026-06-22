import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

Future<BitmapDescriptor> getCustomIcon(String path, int width) async {
  final ImageConfiguration config = ImageConfiguration(
    size: Size(width.toDouble(), width.toDouble()),
  );

  return await BitmapDescriptor.fromAssetImage(config, path);
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
      canPop: true,
      child: Material(
        type: MaterialType.transparency,
        child: IgnorePointer(
          ignoring: false,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 4,
              sigmaY: 4,
            ),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.15),
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
                      color: Colors.blue,
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
                    const SizedBox(height: 12),

                    /// Cancel / Back Button
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // OR Get.back();
                      },
                      child:  Text("Cancel", style: TextStyle(color: Colors.red),),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}