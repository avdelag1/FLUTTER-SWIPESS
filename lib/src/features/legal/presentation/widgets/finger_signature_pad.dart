import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class FingerSignaturePad extends StatefulWidget {
  const FingerSignaturePad({
    super.key,
    required this.controller,
    this.onClear,
  });

  final SignatureController controller;
  final VoidCallback? onClear;

  @override
  State<FingerSignaturePad> createState() => _FingerSignaturePadState();
}

class _FingerSignaturePadState extends State<FingerSignaturePad> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0x33FC567E)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandAccent.withAlpha(40),
                blurRadius: 28,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Signature(
                controller: widget.controller,
              ),
              if (!widget.controller.isNotEmpty)
                IgnorePointer(
                  child: Center(
                    child: Text(
                      'Sign with your finger',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white38,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            widget.controller.clear();
            widget.onClear?.call();
            setState(() {});
          },
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
          label: const Text('Clear signature', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}
