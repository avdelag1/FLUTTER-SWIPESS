import 'package:flutter/material.dart';

import 'package:flutter_swipes/src/features/map/domain/map_presence_status.dart';

/// Circular Instagram-style map marker for Flutter overlay maps (web/PWA).
class MapPhotoPin extends StatelessWidget {
  const MapPhotoPin({
    super.key,
    required this.imageUrl,
    required this.ringColor,
    required this.fallbackIcon,
    this.selected = false,
    this.size = 48,
    this.extraCount = 0,
    this.statusKey,
    this.onTap,
  });

  final String? imageUrl;
  final Color ringColor;
  final IconData fallbackIcon;
  final bool selected;
  final double size;
  final int extraCount;
  final String? statusKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final inner = size - (selected ? 8 : 6);

    Widget photo;
    if (url != null && url.isNotEmpty) {
      photo = ClipOval(
        child: Image.network(
          url,
          width: inner,
          height: inner,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(inner),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _fallback(inner);
          },
        ),
      );
    } else {
      photo = _fallback(inner);
    }

    final status = MapPresenceStatus.resolve(statusKey);

    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.14 : 1,
              duration: const Duration(milliseconds: 140),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: size,
                    height: size,
                    padding: EdgeInsets.all(selected ? 3 : 2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? ringColor : Colors.white,
                      border: Border.all(
                        color: selected ? ringColor : Colors.white,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ringColor.withAlpha(selected ? 120 : 64),
                          blurRadius: selected ? 16 : 10,
                          spreadRadius: selected ? 1 : 0,
                        ),
                        const BoxShadow(color: Colors.black26, blurRadius: 7),
                      ],
                    ),
                    child: photo,
                  ),
                  if (status != null)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: ringColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(status.icon, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            if (extraCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xE6111318),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '+$extraCount more',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fallback(double inner) => Container(
    width: inner,
    height: inner,
    decoration: BoxDecoration(
      color: ringColor.withAlpha(36),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Icon(fallbackIcon, color: ringColor, size: inner * 0.48),
  );
}
