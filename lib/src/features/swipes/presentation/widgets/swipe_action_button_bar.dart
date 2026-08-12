import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.undo_rounded,
            color: const Color(0xFF22C55E), // Green
            size: 42,
            iconSize: 22,
            onTap: onUndo,
            disabled: disabled || onUndo == null,
          ),
          _ActionButton(
            icon: Icons.close_rounded,
            color: const Color(0xFFEF4444), // Red
            size: 60,
            iconSize: 32,
            onTap: onDislike,
            disabled: disabled,
          ),
          _ActionButton(
            icon: Icons.chat_bubble_rounded,
            color: const Color(0xFF3B82F6), // Blue
            size: 42,
            iconSize: 20,
            onTap: onMessage,
            disabled: disabled || onMessage == null,
          ),
          _ActionButton(
            icon: Icons.favorite_rounded,
            color: const Color(0xFFFF5722), // Fire Orange
            size: 60,
            iconSize: 32,
            onTap: onLike,
            disabled: disabled,
          ),
          _ActionButton(
            icon: Icons.remove_red_eye_rounded,
            color: const Color(0xFF06B6D4), // Cyan
            size: 42,
            iconSize: 22,
            onTap: onInsights,
            disabled: disabled || onInsights == null,
          ),
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

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.iconSize,
    this.onTap,
    this.disabled = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.disabled) return;
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.disabled) return;
    _controller.reverse();
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (widget.disabled) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withAlpha(widget.disabled ? 25 : 38),
            boxShadow: widget.disabled
                ? null
                : [
                    BoxShadow(
                      color: widget.color.withAlpha(89),
                      blurRadius: widget.size / 2.5,
                      spreadRadius: 2,
                    ),
                  ],
            border: Border.all(
              color: widget.color.withAlpha(widget.disabled ? 51 : 127),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: widget.color.withAlpha(widget.disabled ? 127 : 255),
            ),
          ),
        ),
      ),
    );
  }
}
