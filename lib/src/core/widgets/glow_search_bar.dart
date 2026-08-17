import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlowSearchBar extends StatefulWidget {
  const GlowSearchBar({super.key, this.hint = 'Search Swipess', this.onTap, this.controller, this.onChanged});
  final String hint; final VoidCallback? onTap; final TextEditingController? controller; final ValueChanged<String>? onChanged;
  @override State<GlowSearchBar> createState() => _GlowSearchBarState();
}

class _GlowSearchBarState extends State<GlowSearchBar> {
  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ink = isLight ? const Color(0xFF101014) : Colors.white;
    final muted = ink.withAlpha(150);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(borderRadius: BorderRadius.circular(999), child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: isLight ? Colors.white.withAlpha(178) : Colors.black.withAlpha(34),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF60A5FA).withAlpha(isLight ? 160 : 180), width: 1.05),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF60A5FA).withAlpha(isLight ? 22 : 16),
                  blurRadius: 10,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Row(children: [
              const SizedBox(width: 17),
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF60A5FA), size: 20),
              const SizedBox(width: 10),
              Expanded(child: IgnorePointer(
                ignoring: widget.onTap != null && widget.onChanged == null,
                child: TextField(
                  controller: widget.controller,
                  enabled: widget.onTap == null || widget.onChanged != null,
                  onChanged: widget.onChanged,
                  style: GoogleFonts.plusJakartaSans(color: ink, fontWeight: FontWeight.w600, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: GoogleFonts.plusJakartaSans(color: ink.withAlpha(130), fontWeight: FontWeight.w500, fontSize: 15),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    fillColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              )),
            ]),
          ),
        )),
      ),
      const SizedBox(height: 5),
      Row(children: [
        const Icon(Icons.auto_awesome_rounded, color: Color(0xFF60A5FA), size: 11), const SizedBox(width: 4),
        Flexible(child: Text('Powered by Gemini · AI may make mistakes.', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(color: muted, fontWeight: FontWeight.w600, fontSize: 10.5, letterSpacing: .15))),
      ]),
      const SizedBox(height: 7),
      Row(children: [
        Expanded(child: _outerPill(Icons.location_on_rounded, 'Tulum', ink, isLight)), const SizedBox(width: 7),
        Expanded(child: _outerPill(Icons.calendar_month_rounded, 'Dates', ink, isLight)), const SizedBox(width: 7),
        Expanded(child: _outerPill(Icons.person_rounded, '1 guest', ink, isLight)),
      ]),
    ]);
  }

  Widget _outerPill(IconData icon, String label, Color ink, bool isLight) {
    return ClipRRect(borderRadius: BorderRadius.circular(999), child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      child: Container(
        height: 33,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isLight ? Colors.white.withAlpha(145) : Colors.white.withAlpha(11),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isLight ? Colors.black.withAlpha(22) : Colors.white.withAlpha(38), width: .6),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: ink.withAlpha(240), size: 13), const SizedBox(width: 5),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(color: ink, fontWeight: FontWeight.w700, fontSize: 11.5))),
        ]),
      ),
    ));
  }
}
