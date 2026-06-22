import 'package:flutter/material.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/dimensions.dart';

class OnlineToggleButton extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onTap;

  const OnlineToggleButton({
    super.key,
    required this.isOnline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          height: 60,
          width: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,

              /// ✅ FIXED COLOR LOGIC
              colors: isOnline
                  ? [Colors.green, Colors.green] // ONLINE = GREEN
                  : [Colors.red, Colors.red], // OFFLINE = RED
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: isOnline ? Colors.green : Colors.red,
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              /// ✅ TEXT FIX
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Text(
                 isOnline ? "Go Online" : "Go Offline",
                  key: ValueKey(isOnline),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              AnimatedAlign(
                duration: const Duration(milliseconds: 400),
                alignment: isOnline
                    ? Alignment
                          .centerRight // ✅ FIXED
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  height: 40,
                  width: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOnline ? Icons.power_settings_new : Icons.double_arrow,
                    color: Colors.blue,
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
