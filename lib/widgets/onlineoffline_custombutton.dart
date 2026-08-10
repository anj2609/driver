import 'package:flutter/material.dart';

class OnlineToggleButton extends StatelessWidget {
  final bool isOnline;

  /// Drives the disabled/loading look off the *actual* in-flight request
  /// (HomeController.isLoading) rather than a fixed cosmetic timer. A fixed
  /// timer (the old approach) re-enables the button before a slow request
  /// has actually finished, so a tap during that window gets silently
  /// swallowed by the controller's isLoading guard with zero visual
  /// feedback — which reads to the driver as "the toggle doesn't respond",
  /// while the earlier tap's toast/state-change lands late and looks
  /// disconnected from whatever they were doing by then.
  final bool isLoading;
  final VoidCallback onTap;

  const OnlineToggleButton({
    super.key,
    required this.isOnline,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          height: 60,
          width: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isOnline
                  ? [Colors.green, Colors.green]
                  : [Colors.red, Colors.red],
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: (isOnline ? Colors.green : Colors.red)
                    .withValues(alpha: isLoading ? 0.2 : 0.5),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Opacity(
            opacity: isLoading ? 0.6 : 1.0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: isLoading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          isOnline ? "Online" : "Offline",
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
                      ? Alignment.centerRight
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
                      color: const Color(0xFF123EBC),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
