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
  final double height;
  final int maxLines;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    final multi = maxLines > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: multi ? null : height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.inputFill,
              borderRadius: BorderRadius.circular(multi ? 16 : 999),
              border: Border.all(
                color: hasError ? const Color(0xFFF87171) : Colors.white,
                width: 1.5,
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
                    child: Icon(icon, size: 18, color: const Color(0xB3FFFFFF)),
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
                    textCapitalization: textCapitalization,
                    autocorrect: false,
                    onChanged: onChanged,
                    maxLines: maxLines,
                    minLines: multi ? maxLines : 1,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: obscureText ? 2 : 0.2,
                    ),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: const Color(0x99FFFFFF),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
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
                      color: const Color(0xB3FFFFFF),
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
              color: value ? AppTheme.brandPrimary : const Color(0x0FFFFFFF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? AppTheme.brandPrimary : const Color(0x73FFFFFF),
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
