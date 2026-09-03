import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/native/incoming_share_service.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/routing/app_router.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/add/data/listing_draft_repository.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/profile_camera_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IncomingShareBootstrap extends ConsumerStatefulWidget {
  const IncomingShareBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IncomingShareBootstrap> createState() =>
      _IncomingShareBootstrapState();
}

class _IncomingShareBootstrapState
    extends ConsumerState<IncomingShareBootstrap> {
  StreamSubscription<List<IncomingSharedMedia>>? _subscription;
  List<IncomingSharedMedia>? _queued;
  bool _presenting = false;

  @override
  void initState() {
    super.initState();
    final service = IncomingShareService.instance;
    _subscription = service.events.listen(_enqueue);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = await service.takeInitial();
      if (mounted && initial.isNotEmpty) _enqueue(initial);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _enqueue(List<IncomingSharedMedia> media) {
    if (!mounted || media.isEmpty) return;
    final usable = media
        .where((item) => item.isImage || item.isVideo)
        .take(32)
        .toList(growable: false);
    if (usable.isEmpty) return;
    if (_presenting) {
      _queued = usable;
      return;
    }
    unawaited(_present(usable));
  }

  Future<BuildContext?> _navigatorContext() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final context = rootNavigatorKey.currentContext;
      if (context != null) return context;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return null;
    }
    return null;
  }

  Future<void> _present(List<IncomingSharedMedia> media) async {
    if (_presenting || !mounted) return;
    _presenting = true;
    try {
      final navContext = await _navigatorContext();
      if (!mounted || navContext == null) return;

      final hasImage = media.any((item) => item.isImage);
      final hasVideo = media.any((item) => item.isVideo);
      final choice = await showModalBottomSheet<String>(
        context: navContext,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          final isLight = Theme.of(context).brightness == Brightness.light;
          final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
          final muted = ink.withAlpha(150);
          return SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              decoration: BoxDecoration(
                color: isLight ? Colors.white : const Color(0xFF17171C),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isLight
                      ? Colors.black.withAlpha(18)
                      : Colors.white.withAlpha(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: muted.withAlpha(70),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'USE IN SWIPESS',
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${media.length} shared ${media.length == 1 ? 'item' : 'items'} ready${hasVideo ? ' · video included' : ''}.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ShareChoice(
                    icon: Icons.add_business_rounded,
                    title: 'Create listing',
                    subtitle:
                        'Open the AI listing creator with this media already loaded.',
                    onTap: () => Navigator.of(context).pop('listing'),
                  ),
                  if (hasImage) ...[
                    const SizedBox(height: 8),
                    _ShareChoice(
                      icon: Icons.account_circle_rounded,
                      title: 'Use as profile photo',
                      subtitle:
                          'Review the selected photo, then save it to your profile.',
                      onTap: () => Navigator.of(context).pop('profile'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );

      if (!mounted || choice == null) return;
      if (Supabase.instance.client.auth.currentUser == null) {
        ScaffoldMessenger.of(navContext).showSnackBar(
          const SnackBar(
            content: Text('Sign in to use shared media in Swipess.'),
          ),
        );
        return;
      }

      if (choice == 'listing') {
        await _openListing(media);
      } else if (choice == 'profile') {
        final image = media.where((item) => item.isImage).firstOrNull;
        if (image != null) await _openProfilePhoto(image.file);
      }
    } finally {
      _presenting = false;
      final queued = _queued;
      _queued = null;
      if (mounted && queued != null && queued.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _enqueue(queued));
      }
    }
  }

  Future<void> _openListing(List<IncomingSharedMedia> media) async {
    final repository = ref.read(listingDraftRepositoryProvider);
    SavedListingDraft? existing;
    try {
      existing = await repository.load('ai-new');
    } catch (_) {}

    final incomingPhotos = media
        .where((item) => item.isImage)
        .map((item) => item.file)
        .toList(growable: false);
    final incomingVideo = media.where((item) => item.isVideo).firstOrNull?.file;
    final mergedPhotos = <XFile>[
      ...incomingPhotos,
      ...?existing?.photos,
    ].take(30).toList(growable: false);
    final payload = Map<String, dynamic>.from(
      existing?.payload ?? const <String, dynamic>{},
    );
    payload.putIfAbsent('video_audio_enabled', () => true);

    await repository.save(
      draftKey: 'ai-new',
      kind: existing?.kind ?? 'ai',
      category: existing?.category ?? 'property',
      step: existing?.step ?? 0,
      payload: payload,
      sourceListingId: existing?.sourceListingId,
      photos: mergedPhotos,
      video: incomingVideo ?? existing?.video,
      documents: existing?.documents ?? const <XFile>[],
      backgroundMusic: existing?.backgroundMusic,
    );

    if (!mounted) return;
    final router = ref.read(appRouterProvider);
    _removeShareQuery(router);
    router.push(AppPaths.ownerListingsNew);
  }

  Future<void> _openProfilePhoto(XFile image) async {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push<String>(
      MaterialPageRoute(
        builder: (_) => ProfileCameraScreen(
          mode: ProfileCameraMode.selfie,
          initialFile: image,
        ),
      ),
    );
    if (!mounted) return;
    ref.invalidate(currentProfileProvider);
    final router = ref.read(appRouterProvider);
    _removeShareQuery(router);
  }

  void _removeShareQuery(GoRouter router) {
    if (!kIsWeb) return;
    final uri = router.routeInformationProvider.value.uri;
    if (!uri.queryParameters.containsKey('share_session')) return;
    final query = Map<String, String>.from(uri.queryParameters)
      ..remove('share_session');
    router.replace(
      uri.replace(queryParameters: query.isEmpty ? null : query).toString(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ShareChoice extends StatelessWidget {
  const _ShareChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    return Material(
      color: isLight ? const Color(0xFFF6F6F8) : const Color(0xFF222228),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppTheme.brandPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: ink.withAlpha(145),
                        fontSize: 10.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ink.withAlpha(120)),
            ],
          ),
        ),
      ),
    );
  }
}
