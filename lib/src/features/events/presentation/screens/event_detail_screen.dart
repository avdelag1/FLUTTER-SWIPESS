import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/event_connect.dart';
import 'package:flutter_swipes/src/features/events/data/event_engagement_tracker.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/presentation/providers/events_provider.dart';
import 'package:flutter_swipes/src/features/events/presentation/widgets/event_connect_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Capacitor EventoDetail — gallery, favorite, share, WhatsApp, calendar.
class EventDetailScreen extends ConsumerStatefulWidget {
  final Event event;
  final List<Event> siblings;

  const EventDetailScreen({
    super.key,
    required this.event,
    this.siblings = const [],
  });

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  late final PageController _pages;
  int _index = 0;
  bool? _favoritedOverride;
  bool _busyFavorite = false;

  Event get event => widget.event;

  @override
  void initState() {
    super.initState();
    _pages = PageController();
    unawaited(
      EventEngagementTracker.track(
        event,
        'impression',
        source: 'event_detail',
        oncePerSession: true,
      ),
    );
    unawaited(
      EventEngagementTracker.track(
        event,
        'tap_detail',
        source: 'event_detail',
        oncePerSession: true,
      ),
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  List<String> get _media {
    final out = <String>[];
    final video = event.videoUrl?.trim();
    if (video != null && video.isNotEmpty) out.add(video);
    for (final url in event.gallery) {
      if (url.trim().isEmpty || out.contains(url)) continue;
      out.add(url);
    }
    return out.isEmpty ? const [''] : out;
  }

  bool _isVideo(String url) {
    final l = url.toLowerCase();
    return l.contains('.mp4') ||
        l.contains('.webm') ||
        l.contains('.mov') ||
        l.contains('/videos/');
  }

  Future<void> _toggleFavorite() async {
    if (_busyFavorite) return;
    final current =
        _favoritedOverride ??
        (ref.read(eventFavoriteProvider(event.id)).value ?? false);
    setState(() {
      _busyFavorite = true;
      _favoritedOverride = !current;
    });
    AppHaptics.medium();
    try {
      await ref
          .read(eventRepositoryProvider)
          .setFavorited(event.id, favorited: !current);
      ref.invalidate(eventFavoriteProvider(event.id));
      if (!current) {
        unawaited(
          EventEngagementTracker.track(
            event,
            'tap_like',
            source: 'event_detail',
          ),
        );
      }
    } catch (_) {
      setState(() => _favoritedOverride = current);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sign in to save events')));
      }
    } finally {
      if (mounted) setState(() => _busyFavorite = false);
    }
  }

  Future<void> _share() async {
    AppHaptics.light();
    unawaited(
      EventEngagementTracker.track(
        event,
        'tap_share',
        source: 'event_detail',
        metadata: const <String, dynamic>{'method': 'copy_link'},
      ),
    );
    final text = 'Check out ${event.title} on Swipess! ${event.shareUrl}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Event link copied')));
  }

  Future<void> _addToCalendar() async {
    AppHaptics.light();
    unawaited(
      EventEngagementTracker.track(
        event,
        'tap_calendar',
        source: 'event_detail',
      ),
    );
    final start =
        event.eventDate ?? DateTime.now().add(const Duration(days: 1));
    final end = event.eventEndDate ?? start.add(const Duration(hours: 2));
    String fmt(DateTime d) =>
        DateFormat("yyyyMMdd'T'HHmmss'Z'").format(d.toUtc());
    final uri = Uri.parse(
      'https://calendar.google.com/calendar/render'
      '?action=TEMPLATE'
      '&text=${Uri.encodeComponent(event.title)}'
      '&dates=${fmt(start)}/${fmt(end)}'
      '&details=${Uri.encodeComponent(event.description ?? '')}'
      '&location=${Uri.encodeComponent([event.location, event.locationDetail].whereType<String>().where((s) => s.isNotEmpty).join(' — '))}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _whatsApp() async {
    if (!event.hasWhatsApp) return;
    AppHaptics.heavy();
    unawaited(
      EventEngagementTracker.track(
        event,
        'tap_whatsapp',
        source: 'event_detail_primary_cta',
        metadata: const <String, dynamic>{'channel': 'whatsapp'},
      ),
    );
    await EventConnect.open(
      EventConnect.whatsAppUri(
        event.organizerWhatsapp,
        message: 'Hola, vi tu evento "${event.title}" en Swipess 🔥',
      ),
    );
  }

  void _goSibling(String? id) {
    if (id == null) return;
    final next = widget.siblings.where((e) => e.id == id).firstOrNull;
    if (next == null || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            EventDetailScreen(event: next, siblings: widget.siblings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favAsync = ref.watch(eventFavoriteProvider(event.id));
    final favorited = _favoritedOverride ?? favAsync.value ?? false;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final gallery = _media;

    final idx = widget.siblings.indexWhere((e) => e.id == event.id);
    final prevId = idx > 0 ? widget.siblings[idx - 1].id : null;
    final nextId = idx >= 0 && idx < widget.siblings.length - 1
        ? widget.siblings[idx + 1].id
        : null;

    final dateLabel = event.eventDate == null
        ? 'TBA'
        : DateFormat('EEEE, MMMM d').format(event.eventDate!.toLocal());
    final timeLabel = event.eventDate == null
        ? ''
        : [
            DateFormat('h:mm a').format(event.eventDate!.toLocal()),
            if (event.eventEndDate != null)
              DateFormat('h:mm a').format(event.eventEndDate!.toLocal()),
          ].join(' — ');

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Hero gallery
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.58,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PageView.builder(
                        controller: _pages,
                        itemCount: gallery.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) {
                          final url = gallery[i];
                          if (url.isEmpty) {
                            return const ColoredBox(
                              color: Color(0xFF16161C),
                              child: Center(
                                child: Icon(
                                  Icons.celebration_rounded,
                                  color: Colors.white24,
                                  size: 64,
                                ),
                              ),
                            );
                          }
                          if (_isVideo(url)) {
                            return _EventVideo(url: url);
                          }
                          return Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const ColoredBox(color: Color(0xFF16161C)),
                          );
                        },
                      ),
                      const IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x99000000),
                                Color(0x00000000),
                                Color(0xE6000000),
                              ],
                              stops: [0, 0.45, 1],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: top + 12,
                        left: 16,
                        right: 16,
                        child: Row(
                          children: [
                            _GlassBtn(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            _GlassBtn(
                              icon: favorited
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: favorited
                                  ? const Color(0xFFF43F5E)
                                  : Colors.white,
                              onTap: _toggleFavorite,
                            ),
                            const SizedBox(width: 8),
                            _GlassBtn(icon: Icons.share_rounded, onTap: _share),
                          ],
                        ),
                      ),
                      if (gallery.length > 1)
                        Positioned(
                          bottom: 48,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (
                                var i = 0;
                                i < gallery.length.clamp(0, 8);
                                i++
                              )
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: i == _index ? 22 : 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i == _index
                                        ? Colors.white
                                        : Colors.white38,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Positioned(
                        left: 20,
                        bottom: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(120),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            event.category.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (widget.siblings.length > 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        _SiblingChip(
                          label: 'Prev',
                          icon: Icons.chevron_left_rounded,
                          enabled: prevId != null,
                          onTap: () => _goSibling(prevId),
                        ),
                        const Spacer(),
                        _SiblingChip(
                          label: 'More events',
                          highlighted: true,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        _SiblingChip(
                          label: 'Next',
                          icon: Icons.chevron_right_rounded,
                          trailing: true,
                          enabled: nextId != null,
                          onTap: () => _goSibling(nextId),
                        ),
                      ],
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(22, 22, 22, bottom + 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          height: 0.95,
                          letterSpacing: -1.2,
                        ),
                      ),
                      if (event.promoText?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withAlpha(30),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withAlpha(80),
                            ),
                          ),
                          child: Text(
                            event.promoText!.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFFBBF24),
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _InfoRow(
                        icon: Icons.calendar_today_rounded,
                        iconColor: const Color(0xFF6366F1),
                        eyebrow: 'When & Time',
                        title: dateLabel,
                        subtitle: timeLabel.isEmpty ? null : timeLabel,
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.location_on_rounded,
                        iconColor: const Color(0xFFF43F5E),
                        eyebrow: 'The Location',
                        title: event.location ?? 'TBA',
                        subtitle:
                            event.locationDetail ?? 'Verified destination',
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Text(
                            'THE EXPERIENCE',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white38,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 2.2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(height: 1, color: Colors.white12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        event.description ??
                            'Join us for an unforgettable experience in the heart of the Riviera Maya.',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.55,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14141A),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ADMISSION PASS',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white38,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      letterSpacing: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    event.isFree
                                        ? 'FREE ENTRY'
                                        : (event.priceText ?? 'PREMIUM')
                                              .toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontStyle: FontStyle.italic,
                                      fontSize: 28,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'VERIFIED BOOKING REQUIRED',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.brandPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      letterSpacing: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.verified_user_rounded,
                                color: Color(0xFFFB7185),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (event.organizerName?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.white12),
                              bottom: BorderSide(color: Colors.white12),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundImage: event.organizerPhotoUrl != null
                                    ? NetworkImage(event.organizerPhotoUrl!)
                                    : null,
                                child: event.organizerPhotoUrl == null
                                    ? const Icon(
                                        Icons.person_rounded,
                                        color: Colors.white54,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ELITE ORGANIZER',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white38,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 9,
                                        letterSpacing: 1.6,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      event.organizerName!.toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontStyle: FontStyle.italic,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  'VERIFIED HOST',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFF43F5E),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (event.hasConnectLinks) ...[
                        const SizedBox(height: 28),
                        EventConnectBar(
                          event: event,
                          message:
                              'Hola, vi tu evento "${event.title}" en Swipess 🔥',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Sticky footer CTAs
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 28, 20, bottom + 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xF2000000)],
                ),
              ),
              child: Row(
                children: [
                  if (event.hasWhatsApp)
                    Expanded(
                      child: GestureDetector(
                        onTap: _whatsApp,
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF25D366).withAlpha(90),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.chat_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'WHATSAPP',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.6,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: GestureDetector(
                        onTap: _share,
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'SHARE EVENT',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  _FooterSquare(
                    icon: Icons.calendar_month_rounded,
                    onTap: _addToCalendar,
                  ),
                  const SizedBox(width: 10),
                  _FooterSquare(icon: Icons.ios_share_rounded, onTap: _share),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  const _GlassBtn({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(90),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _FooterSquare extends StatelessWidget {
  const _FooterSquare({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFF14141A),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _SiblingChip extends StatelessWidget {
  const _SiblingChip({
    required this.label,
    required this.onTap,
    this.icon,
    this.enabled = true,
    this.highlighted = false,
    this.trailing = false,
  });
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool enabled;
  final bool highlighted;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: highlighted
                ? AppTheme.brandPrimary.withAlpha(30)
                : Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: highlighted
                  ? AppTheme.brandPrimary.withAlpha(90)
                  : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null && !trailing) ...[
                Icon(icon, size: 16, color: Colors.white70),
                const SizedBox(width: 2),
              ],
              Text(
                label.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: highlighted ? AppTheme.brandPrimary : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
              if (icon != null && trailing) ...[
                const SizedBox(width: 2),
                Icon(icon, size: 16, color: Colors.white70),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });
  final IconData icon;
  final Color iconColor;
  final String eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(28),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white38,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventVideo extends StatefulWidget {
  const _EventVideo({required this.url});
  final String url;

  @override
  State<_EventVideo> createState() => _EventVideoState();
}

class _EventVideoState extends State<_EventVideo> {
  VideoPlayerController? _player;

  @override
  void initState() {
    super.initState();
    final next = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _player = next;
    next
        .initialize()
        .then((_) {
          if (!mounted || !identical(_player, next)) return;
          next
            ..setLooping(true)
            ..setVolume(0)
            ..play();
          setState(() {});
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    if (player == null || !player.value.isInitialized) {
      return const ColoredBox(color: Color(0xFF16161C));
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: player.value.size.width,
        height: player.value.size.height,
        child: VideoPlayer(player),
      ),
    );
  }
}
