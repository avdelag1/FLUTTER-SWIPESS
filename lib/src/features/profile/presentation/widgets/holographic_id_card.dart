import 'dart:math';
import 'package:flutter/material.dart';

class HolographicIDCard extends StatefulWidget {
  final String name;
  final String idNumber;
  final String? avatarUrl;
  final String occupation;
  final String location;
  final String years;
  final String bio;

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

  @override
  State<HolographicIDCard> createState() => _HolographicIDCardState();
}

class _HolographicIDCardState extends State<HolographicIDCard>
    with SingleTickerProviderStateMixin {
  Offset _tilt = Offset.zero;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _tilt += details.delta * 0.005;
      _tilt = Offset(_tilt.dx.clamp(-0.2, 0.2), _tilt.dy.clamp(-0.2, 0.2));
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _tilt = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.name
        .split(' ')
        .map((n) => n.isNotEmpty ? n[0] : '')
        .take(2)
        .join('')
        .toUpperCase();

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
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateX(-tilt.dy)
              ..rotateY(tilt.dx),
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1A),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.transparent, width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D00).withAlpha(25),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Stack(
              children: [
                // Micro-circuit background pattern (simulated with GridPaper)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.03,
                    child: GridPaper(
                      color: Colors.white,
                      interval: 16,
                      divisions: 1,
                      subdivisions: 1,
                    ),
                  ),
                ),

                // Shimmer Overlay
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
                            colors: [
                              Colors.transparent,
                              Colors.white.withAlpha(12),
                              Colors.white.withAlpha(50),
                              Colors.white.withAlpha(12),
                              Colors.transparent,
                            ],
                            transform: GradientRotation(
                              _shimmerController.value * 2 * pi,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Card Content
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.public,
                                    size: 12,
                                    color: const Color(
                                      0xFFFF4D00,
                                    ).withAlpha(150),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'SWIPESS GLOBAL REGISTRY',
                                    style: TextStyle(
                                      color: const Color(
                                        0xFFFF4D00,
                                      ).withAlpha(150),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'RESIDENT ID',
                                style: TextStyle(
                                  color: Colors.white,
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
                              color: const Color(0xFFFF4D00).withAlpha(25),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFF4D00).withAlpha(50),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.verified_user_rounded,
                                color: Color(0xFFFF4D00),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Identity Row
                      Row(
                        children: [
                          // Avatar
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF4D00).withAlpha(50),
                              border: Border.all(
                                color: const Color(0xFFFF4D00).withAlpha(75),
                                width: 2,
                              ),
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
                                      style: const TextStyle(
                                        color: Color(0xFFFF4D00),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          // Name & ID
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                                ),
                                Text(
                                  widget.idNumber,
                                  style: TextStyle(
                                    color: const Color(
                                      0xFFFF4D00,
                                    ).withAlpha(150),
                                    fontSize: 9,
                                    fontFamily: 'monospace',
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Badges
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              border: Border.all(color: Colors.transparent),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D00).withAlpha(25),
                              border: Border.all(
                                color: const Color(0xFFFF4D00).withAlpha(50),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'VERIFIED',
                              style: TextStyle(
                                color: Color(0xFFFF4D00),
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Details Row
                      Row(
                        children: [
                          _buildDetail(Icons.work_rounded, widget.occupation),
                          const SizedBox(width: 16),
                          _buildDetail(
                            Icons.location_on_rounded,
                            widget.location,
                          ),
                          const SizedBox(width: 16),
                          _buildDetail(Icons.access_time_rounded, widget.years),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Bio
                      Text(
                        widget.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withAlpha(127),
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

  Widget _buildDetail(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: const Color(0xFFFF4D00).withAlpha(150)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
