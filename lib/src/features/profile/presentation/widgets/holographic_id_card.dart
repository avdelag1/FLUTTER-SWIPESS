import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/profile/domain/vap_card_themes.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact profile preview of the same Pearl VAP / Local ID opened from nav.
///
/// This intentionally has no automatic shimmer, glow sweep or animated tilt.
/// The full card remains available when the preview is tapped by its parent.
class HolographicIDCard extends StatelessWidget {
  const HolographicIDCard({
    super.key,
    required this.name,
    required this.idNumber,
    this.avatarUrl,
    required this.occupation,
    required this.location,
    required this.years,
    required this.bio,
  });

  final String name;
  final String idNumber;
  final String? avatarUrl;
  final String occupation;
  final String location;
  final String years;
  final String bio;

  @override
  Widget build(BuildContext context) {
    final theme = VapCardTheme.themes.first;
    final cleanName = name.trim().isEmpty ? 'SWIPESS MEMBER' : name.trim();
    final initials = cleanName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradient,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.tagBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: theme.badge,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'SWIPESS LOCAL ID',
                  style: GoogleFonts.plusJakartaSans(
                    color: theme.badge,
                    fontWeight: FontWeight.w900,
                    fontSize: 9.5,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: theme.tagBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: theme.tagBorder),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.textSecondary,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 78,
                  height: 98,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: theme.tagBg,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: theme.tagBorder),
                  ),
                  child: avatarUrl != null && avatarUrl!.trim().isNotEmpty
                      ? Image.network(
                          avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _Initials(
                            initials: initials,
                            color: theme.textPrimary,
                          ),
                        )
                      : _Initials(initials: initials, color: theme.textPrimary),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cleanName.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: theme.textPrimary,
                          fontSize: 20,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.5,
                        ),
                      ),
                      if (occupation.trim().isNotEmpty) ...[
                        SizedBox(height: 7),
                        Text(
                          occupation.trim().toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: theme.accent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .8,
                          ),
                        ),
                      ],
                      SizedBox(height: 9),
                      _InfoLine(
                        icon: Icons.location_on_outlined,
                        text: location.trim().isEmpty
                            ? 'Location not set'
                            : location,
                        color: theme.textSecondary,
                      ),
                      if (years.trim().isNotEmpty) ...[
                        SizedBox(height: 5),
                        _InfoLine(
                          icon: Icons.timelapse_rounded,
                          text: years,
                          color: theme.textSecondary,
                        ),
                      ],
                      SizedBox(height: 7),
                      Text(
                        'ID ${idNumber.toUpperCase()}',
                        style: GoogleFonts.robotoMono(
                          color: theme.textTertiary,
                          fontSize: 9,
                          letterSpacing: .6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (bio.trim().isNotEmpty) ...[
              SizedBox(height: 13),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: theme.tagBg,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: theme.tagBorder),
                ),
                child: Text(
                  bio.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: theme.textSecondary,
                    fontSize: 10.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  color: theme.textTertiary,
                  size: 14,
                ),
                SizedBox(width: 5),
                Text(
                  'TAP TO OPEN FULL VAP ID + DOCUMENTS',
                  style: GoogleFonts.plusJakartaSans(
                    color: theme.textTertiary,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .55,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.color});

  final String initials;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 13),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
