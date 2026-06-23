import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/dimensions.dart';
import 'package:myridedriverapp/config/utils/style.dart';


class RegistrationSuccessScreen extends StatefulWidget {
  const RegistrationSuccessScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationSuccessScreen> createState() =>
      _RegistrationSuccessScreenState();
}

class _RegistrationSuccessScreenState extends State<RegistrationSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(); // Continuous animation
    _navigateAfterDelay();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 4));
    // Navigate directly to the document status screen with "pending" status.
    // Previously used Get.offAll() + Get.dialog() which left the route stack
    // in an unstable state and caused crashes when "Check Status" was tapped.
    Get.offAllNamed(
      RouteHelper.getEditVehicleDocumentScreen(),
      arguments: {"status": "pending"},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorResources.appgroundcolor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: WavyPainter(_controller.value),
                    child: SizedBox(
                      height: 130,
                      width: 130,
                      child: Center(
                        child: Icon(
                          Icons.check,
                          color: ColorResources.appColor,
                          size: 55,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              Text(
                "Registration Successful!",
                style: PoppinsExtrabold.copyWith(
                  color: ColorResources.blackcolor11,
                  fontSize: Dimensions.hight15,
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "You're all set—start earning from doing ride shares!",
                  textAlign: TextAlign.center,
                  style: PoppinsSemiBold.copyWith(
                    color: ColorResources.TextColorForGrey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WavyPainter extends CustomPainter {
  final double animationValue;

  WavyPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ColorResources.appColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final path = Path();

    double radius = size.width / 2 - 10;
    Offset center = Offset(size.width / 2, size.height / 2);

    int waveCount = 12;
    double waveHeight = 6;

    for (int i = 0; i <= 360; i++) {
      double angle = (i * pi) / 180;
      double wave =
          sin((angle * waveCount) + (animationValue * 2 * pi)) * waveHeight;
      double x = center.dx + (radius + wave) * cos(angle);
      double y = center.dy + (radius + wave) * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
