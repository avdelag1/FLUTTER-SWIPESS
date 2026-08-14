import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';

class SwipeActionButtonBar extends StatelessWidget {
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback? onUndo;
  final VoidCallback? onMessage;
  final VoidCallback? onInsights;
  final bool disabled;

  const SwipeActionButtonBar({
    super.key,
    required this.onLike,
    required this.onDislike,
    this.onUndo,
    this.onMessage,
    this.onInsights,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(icon: Icons.undo_rounded, color: const Color(0xFF22C55E), size: 48, iconSize: 22, onTap: onUndo, disabled: disabled),
          _ActionButton(icon: Icons.close_rounded, color: const Color(0xFFEF4444), size: 68, iconSize: 34, onTap: onDislike, disabled: disabled),
          _ActionButton(icon: Icons.chat_bubble_rounded, color: const Color(0xFF3B82F6), size: 48, iconSize: 20, onTap: onMessage, disabled: disabled),
          _ActionButton(icon: Icons.local_fire_department_rounded, color: const Color(0xFFFF5722), size: 68, iconSize: 34, onTap: onLike, disabled: disabled),
          _ActionButton(icon: Icons.remove_red_eye_rounded, color: const Color(0xFF06B6D4), size: 48, iconSize: 22, onTap: onInsights, disabled: disabled),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;
  final bool disabled;

  const _ActionButton({required this.icon, required this.color, required this.size, required this.iconSize, this.onTap, this.disabled = false});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(_) => _controller.forward();
  void _handleTapUp(_) { _controller.reverse(); if (widget.onTap != null) { AppHaptics.light(); widget.onTap!(); } }
  void _handleTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.9).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withAlpha(50),
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha(100),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: widget.color.withAlpha(150), width: 1.5),
          ),
          child: Center(
            child: Icon(widget.icon, size: widget.iconSize, color: widget.color),
          ),
        ),
      ),
    );
  }
}
