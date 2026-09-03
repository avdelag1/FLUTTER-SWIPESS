import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:signature/signature.dart';

class FingerSignaturePad extends StatefulWidget {
  const FingerSignaturePad({super.key, required this.controller, this.onClear});

  final SignatureController controller;
  final VoidCallback? onClear;

  @override
  State<FingerSignaturePad> createState() => _FingerSignaturePadState();
}

class _FingerSignaturePadState extends State<FingerSignaturePad> {
  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Column(
      children: [
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            color: MatteSurface.isLight(context)
                ? Colors.white
                : const Color(0xFF0A0A0C),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: MatteSurface.hairline(context)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Signature(controller: widget.controller),
              if (!widget.controller.isNotEmpty)
                IgnorePointer(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.draw_rounded, color: muted, size: 30),
                        SizedBox(height: 10),
                        Text(
                          'SIGN WITH YOUR FINGER',
                          style: GoogleFonts.plusJakartaSans(
                            color: muted,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 1.4,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Use the full area above',
                          style: GoogleFonts.plusJakartaSans(
                            color: muted.withAlpha(150),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: widget.controller.isEmpty
                ? null
                : () {
                    widget.controller.clear();
                    widget.onClear?.call();
                    setState(() {});
                  },
            icon: Icon(Icons.refresh_rounded, color: muted, size: 16),
            label: Text(
              'Clear',
              style: GoogleFonts.plusJakartaSans(
                color: ink.withAlpha(180),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
