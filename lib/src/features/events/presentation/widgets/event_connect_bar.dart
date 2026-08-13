import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/event_connect.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap event host contacts — WhatsApp, Instagram, website, Facebook.
class EventConnectBar extends StatelessWidget {
  const EventConnectBar({
    super.key,
    required this.event,
    this.message,
  });

  final Event event;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final items = <_Chip>[
      if (event.hasWhatsApp)
        _Chip(
          label: 'WhatsApp',
          icon: Icons.chat_rounded,
          color: const Color(0xFF25D366),
          filled: true,
          onTap: () => EventConnect.open(
            EventConnect.whatsAppUri(event.organizerWhatsapp, message: message),
          ),
        ),
      if (EventConnect.instagramUri(event.organizerInstagram) != null)
        _Chip(
          label: 'Instagram',
          icon: Icons.camera_alt_rounded,
          color: const Color(0xFFE1306C),
          onTap: () => EventConnect.open(
            EventConnect.instagramUri(event.organizerInstagram),
          ),
        ),
      if (EventConnect.websiteUri(event.organizerWebsite) != null)
        _Chip(
          label: 'Website',
          icon: Icons.language_rounded,
          color: const Color(0xFF38BDF8),
          onTap: () => EventConnect.open(
            EventConnect.websiteUri(event.organizerWebsite),
          ),
        ),
      if (EventConnect.facebookUri(event.organizerFacebook) != null)
        _Chip(
          label: 'Facebook',
          icon: Icons.public_rounded,
          color: const Color(0xFF1877F2),
          onTap: () => EventConnect.open(
            EventConnect.facebookUri(event.organizerFacebook),
          ),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONNECT WITH HOST',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white38,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: filled ? color : color.withAlpha(28),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withAlpha(180), width: 1.4),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: color.withAlpha(90),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: filled ? Colors.white : color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
