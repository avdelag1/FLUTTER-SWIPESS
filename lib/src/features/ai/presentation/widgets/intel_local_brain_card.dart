import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_detail_screen.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/listing_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Compact business-card result for admin-curated Local Brain knowledge.
///
/// When the entry is linked to Swipess it opens the native profile/listing.
/// Otherwise the card remains useful through WhatsApp, phone, email and social
/// contact actions without pretending the contact is a registered user.
class IntelLocalBrainCard extends StatelessWidget {
  const IntelLocalBrainCard({super.key, required this.data});

  final Map<String, dynamic> data;

  static const _blue = Color(0xFFFF4D78);

  String _text(String key) => data[key]?.toString().trim() ?? '';

  String get _profileId => _text('swipess_profile_user_id');
  String get _listingId => _text('swipess_listing_id');
  bool get _insideSwipess => _profileId.isNotEmpty || _listingId.isNotEmpty;

  Future<void> _openExternal(Uri? uri) async {
    if (uri == null) return;
    AppHaptics.selection();
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Uri? _webUri(String raw, {String? base}) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return Uri.tryParse(value);
    }
    if (base != null) {
      final handle = value
          .replaceAll('@', '')
          .replaceFirst(RegExp(r'^www\.', caseSensitive: false), '')
          .split('?')
          .first
          .replaceAll(RegExp(r'^/+|/+$'), '');
      if (handle.isEmpty) return null;
      return Uri.tryParse('$base$handle');
    }
    return Uri.tryParse('https://$value');
  }

  Uri? _whatsAppUri() {
    final raw = _text('whatsapp').isNotEmpty ? _text('whatsapp') : _text('phone');
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return null;
    final name = _text('name');
    final message = Uri.encodeComponent(
      'Hi${name.isNotEmpty ? ' $name' : ''}, I found you through Swipess.',
    );
    return Uri.parse('https://wa.me/$digits?text=$message');
  }

  Uri? _phoneUri() {
    final phone = _text('phone');
    if (phone.isEmpty) return null;
    return Uri.tryParse('tel:${phone.replaceAll(' ', '')}');
  }

  Uri? _emailUri() {
    final email = _text('email');
    if (email.isEmpty) return null;
    return Uri(scheme: 'mailto', path: email);
  }

  void _openInsideSwipess(BuildContext context) {
    AppHaptics.selection();
    if (_listingId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ListingDetailScreen(listingId: _listingId),
        ),
      );
      return;
    }
    if (_profileId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileDetailScreen(userId: _profileId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _text('name').isEmpty ? 'Local recommendation' : _text('name');
    final category = _text('category');
    final description = _text('recommendation_note').isNotEmpty
        ? _text('recommendation_note')
        : _text('description');
    final neighborhood = _text('neighborhood');
    final city = _text('city');
    final place = [neighborhood, city].where((x) => x.isNotEmpty).join(', ');
    final image = _text('card_image_url').isNotEmpty
        ? _text('card_image_url')
        : _text('photo_url');
    final verified = data['is_verified'] == true;
    final featured = data['is_featured'] == true;
    final distanceRaw = data['distance_km'];
    final distance = distanceRaw is num ? distanceRaw.toDouble() : double.tryParse('$distanceRaw');

    final actions = <_ContactAction>[
      if (_whatsAppUri() != null)
        _ContactAction('WhatsApp', Icons.chat_rounded, () => _openExternal(_whatsAppUri())),
      if (_phoneUri() != null)
        _ContactAction('Call', Icons.call_rounded, () => _openExternal(_phoneUri())),
      if (_text('instagram').isNotEmpty)
        _ContactAction(
          'Instagram',
          Icons.camera_alt_outlined,
          () => _openExternal(_webUri(_text('instagram'), base: 'https://www.instagram.com/')),
        ),
      if (_text('website').isNotEmpty)
        _ContactAction('Website', Icons.language_rounded, () => _openExternal(_webUri(_text('website')))),
      if (_emailUri() != null)
        _ContactAction('Email', Icons.mail_outline_rounded, () => _openExternal(_emailUri())),
      if (_text('facebook').isNotEmpty)
        _ContactAction('Facebook', Icons.facebook_rounded, () => _openExternal(_webUri(_text('facebook'), base: 'https://www.facebook.com/'))),
      if (_text('tiktok').isNotEmpty)
        _ContactAction('TikTok', Icons.music_note_rounded, () => _openExternal(_webUri(_text('tiktok'), base: 'https://www.tiktok.com/@'))),
      if (_text('youtube').isNotEmpty)
        _ContactAction('YouTube', Icons.play_circle_outline_rounded, () => _openExternal(_webUri(_text('youtube'), base: 'https://www.youtube.com/@'))),
      if (_text('x_url').isNotEmpty)
        _ContactAction('X', Icons.alternate_email_rounded, () => _openExternal(_webUri(_text('x_url'), base: 'https://x.com/'))),
      if (_text('telegram').isNotEmpty)
        _ContactAction('Telegram', Icons.send_rounded, () => _openExternal(_webUri(_text('telegram'), base: 'https://t.me/'))),
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _blue.withAlpha(35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(16),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _insideSwipess ? () => _openInsideSwipess(context) : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    color: _blue.withAlpha(18),
                  ),
                  child: image.isNotEmpty
                      ? Image.network(
                          image,
                          fit: BoxFit.cover,
                          cacheWidth: 220,
                          errorBuilder: (_, _, _) => const Icon(Icons.person_pin_circle_rounded, color: _blue),
                        )
                      : const Icon(Icons.person_pin_circle_rounded, color: _blue, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (verified)
                            const Padding(
                              padding: EdgeInsets.only(left: 5),
                              child: Icon(Icons.verified_rounded, size: 17, color: _blue),
                            ),
                        ],
                      ),
                      if (category.isNotEmpty)
                        Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: _blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (place.isNotEmpty || distance != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            [
                              if (place.isNotEmpty) place,
                              if (distance != null) '${distance.toStringAsFixed(distance < 10 ? 1 : 0)} km away',
                            ].join(' · '),
                            style: GoogleFonts.plusJakartaSans(
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(145),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (featured || _insideSwipess)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (featured) const _MiniBadge(label: 'SWIPESS PICK', icon: Icons.star_rounded),
                  if (_insideSwipess) const _MiniBadge(label: 'ON SWIPESS', icon: Icons.link_rounded),
                ],
              ),
            ),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(205),
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (_insideSwipess)
            Padding(
              padding: const EdgeInsets.only(top: 11),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openInsideSwipess(context),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(
                    _listingId.isNotEmpty ? 'View listing in Swipess' : 'View profile in Swipess',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final action in actions)
                    _ContactChip(action: action),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 11, color: _blue),
                const SizedBox(width: 4),
                Text(
                  'CURATED LOCAL BRAIN',
                  style: GoogleFonts.plusJakartaSans(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF2563EB)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF2563EB),
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactAction {
  const _ContactAction(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({required this.action});

  final _ContactAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withAlpha(18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 14, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 5),
            Text(
              action.label,
              style: GoogleFonts.plusJakartaSans(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
