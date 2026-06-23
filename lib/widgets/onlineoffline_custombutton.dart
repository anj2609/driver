import 'dart:async';
import 'package:flutter/material.dart';

class OnlineToggleButton extends StatefulWidget {
  final bool isOnline;
  final VoidCallback onTap;

  const OnlineToggleButton({
    super.key,
    required this.isOnline,
    required this.onTap,
  });

  @override
  State<OnlineToggleButton> createState() => _OnlineToggleButtonState();
}

class _OnlineToggleButtonState extends State<OnlineToggleButton> {
  bool _isCooldown = false;

  void _handleTap() {
    if (_isCooldown) return;
    setState(() => _isCooldown = true);
    widget.onTap();
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCooldown = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: _isCooldown ? null : _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          height: 60,
          width: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isOnline
                  ? [Colors.green, Colors.green]
                  : [Colors.red, Colors.red],
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: (widget.isOnline ? Colors.green : Colors.red)
                    .withValues(alpha: _isCooldown ? 0.2 : 0.5),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Opacity(
            opacity: _isCooldown ? 0.6 : 1.0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: Text(
                    widget.isOnline ? "Online" : "Offline",
                    key: ValueKey(widget.isOnline),
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
                  alignment: widget.isOnline
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
                      widget.isOnline
                          ? Icons.power_settings_new
                          : Icons.double_arrow,
                      color: Colors.blue,
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
