import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.height = 56,
    this.maxLines = 1,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final double height;
  final int maxLines;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    final multi = maxLines > 1;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    final muted = isLight
        ? const Color(0xFF65656F)
        : const Color(0xB3FFFFFF);
    final hintInk = isLight
        ? const Color(0xFF767680)
        : const Color(0x99FFFFFF);
    final fill = isLight
        ? const Color(0xFFF6F6F8)
        : AppTheme.inputFill;
    final idleBorder = isLight
        ? Colors.black.withAlpha(32)
        : Colors.white.withAlpha(92);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: multi ? null : height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(multi ? 16 : 999),
              border: Border.all(
                color: hasError ? const Color(0xFFF87171) : idleBorder,
                width: 1.15,
              ),
            ),
            child: Row(
              crossAxisAlignment: multi
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  SizedBox(width: 16, height: multi ? 52 : null),
                  Padding(
                    padding: EdgeInsets.only(top: multi ? 16 : 0),
                    child: Icon(icon, size: 18, color: muted),
                  ),
                ],
                Expanded(
                  child: TextField(
                    controller: controller,
                    obscureText: obscureText,
                    autofocus: autofocus,
                    keyboardType: multi
                        ? TextInputType.multiline
                        : keyboardType,
                    textInputAction: multi
                        ? TextInputAction.newline
                        : textInputAction,
                    textCapitalization: textCapitalization,
                    autocorrect: false,
                    onChanged: onChanged,
                    onSubmitted: multi ? null : onSubmitted,
                    maxLines: maxLines,
                    minLines: multi ? maxLines : 1,
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: obscureText ? 2 : 0.2,
                    ),
                    cursorColor: isLight ? AppTheme.brandAccent2 : Colors.white,
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: hintInk,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                if (onToggleObscure != null)
                  IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: muted,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xE6EF4444),
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class AgreeCheckbox extends StatelessWidget {
  const AgreeCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.child,
    this.expand = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final idleFill = isLight
        ? Colors.black.withAlpha(8)
        : const Color(0x0FFFFFFF);
    final idleBorder = isLight
        ? Colors.black.withAlpha(90)
        : const Color(0x73FFFFFF);

    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? AppTheme.brandPrimary : idleFill,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? AppTheme.brandPrimary : idleBorder,
                width: 2,
              ),
            ),
            child: value
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          if (expand) Expanded(child: child) else child,
        ],
      ),
    );
  }
}
