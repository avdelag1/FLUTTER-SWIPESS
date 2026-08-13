import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/profile/domain/vap_card_themes.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `native/HolographicIDCard` — profile preview of the PEARL vault.
/// Colors follow [theme] (the same theme picked on the nav-bar VAP ID card),
/// and the gloss layer only reacts to drag/tilt — no auto-looping shimmer.
class HolographicIDCard extends StatefulWidget {
  final VapCardTheme theme;
  final String name;
  final String idNumber;
  final String? avatarUrl;
  final String occupation;
  final String location;
  final String years;
  final String bio;

  const HolographicIDCard({
    super.key,
    required this.theme,
    required this.name,
    required this.idNumber,
    this.avatarUrl,
    required this.occupation,
    required this.location,
    required this.years,
    required this.bio,
  });

  @override
  State<HolographicIDCard> createState() => _HolographicIDCardState();
}

class _HolographicIDCardState extends State<HolographicIDCard> {
  Offset _tilt = Offset.zero;

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _tilt += details.delta * 0.005;
      _tilt = Offset(_tilt.dx.clamp(-0.2, 0.2), _tilt.dy.clamp(-0.2, 0.2));
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _tilt = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final initials = widget.name
        .split(' ')
        .map((n) => n.isNotEmpty ? n[0] : '')
        .take(2)
        .join('')
        .toUpperCase();
    // Shimmer only appears while tilted — no auto-repeat, matches Cap's
    // hover/drag-driven gloss instead of a constantly spinning brightness.
    final tiltStrength = (_tilt.dx.abs() + _tilt.dy.abs()).clamp(0.0, 0.4);

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: TweenAnimationBuilder(
        tween: Tween<Offset>(begin: Offset.zero, end: _tilt),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        builder: (context, Offset tilt, child) {
          return Transform(
            alignment: FractionalOffset.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(-tilt.dy)
              ..rotateY(tilt.dx),
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: t.gradient,
            ),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: t.tagBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(t.isDark ? 90 : 40),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.03,
                    child: GridPaper(
                      color: t.textPrimary,
                      interval: 16,
                      divisions: 1,
                      subdivisions: 1,
                    ),
                  ),
                ),
                if (tiltStrength > 0.01)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: (tiltStrength / 0.4).clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(-1 + _tilt.dx * 4, -1),
                              end: Alignment(1 + _tilt.dx * 4, 1),
                              colors: [
                                Colors.transparent,
                                (t.isDark ? Colors.white : Colors.black)
                                    .withAlpha(30),
                                Colors.transparent,
                              ],
                              stops: const [0.35, 0.5, 0.65],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.public,
                                      size: 12, color: t.accent),
                                  const SizedBox(width: 8),
                                  Text(
                                    'SWIPESS GLOBAL REGISTRY',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: t.accent,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'RESIDENT ID',
                                style: GoogleFonts.plusJakartaSans(
                                  color: t.textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: -1,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: t.tagBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: t.tagBorder),
                            ),
                            child: Center(
                              child: Icon(Icons.verified_user_rounded,
                                  color: t.badge, size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: t.tagBg,
                              border: Border.all(color: t.tagBorder, width: 2),
                              image: widget.avatarUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(widget.avatarUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: widget.avatarUrl == null
                                ? Center(
                                    child: Text(
                                      initials,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: t.accent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.name.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: t.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  widget.idNumber,
                                  style: GoogleFonts.robotoMono(
                                    color: t.accent,
                                    fontSize: 9,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withAlpha(30),
                              border: Border.all(
                                  color: const Color(0xFF22C55E)
                                      .withAlpha(60)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ACTIVE',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF22C55E),
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: t.tagBg,
                              border: Border.all(color: t.tagBorder),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'VERIFIED',
                              style: GoogleFonts.plusJakartaSans(
                                color: t.accent,
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildDetail(t, Icons.work_rounded, widget.occupation),
                          const SizedBox(width: 16),
                          _buildDetail(
                              t, Icons.location_on_rounded, widget.location),
                          const SizedBox(width: 16),
                          _buildDetail(
                              t, Icons.access_time_rounded, widget.years),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: t.textSecondary,
                          fontSize: 10,
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(VapCardTheme t, IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: t.accent),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            color: t.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
