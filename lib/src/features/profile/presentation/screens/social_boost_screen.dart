import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/social/data/social_distribution_service.dart';
import 'package:google_fonts/google_fonts.dart';

class SocialBoostScreen extends ConsumerStatefulWidget {
  const SocialBoostScreen({super.key});

  @override
  ConsumerState<SocialBoostScreen> createState() => _SocialBoostScreenState();
}

class _SocialBoostScreenState extends ConsumerState<SocialBoostScreen> {
  bool _saving = false;

  static const _providers = <_SocialProvider>[
    _SocialProvider(
      'instagram',
      'Instagram',
      Icons.camera_alt_rounded,
      Color(0xFFE1306C),
    ),
    _SocialProvider(
      'facebook',
      'Facebook',
      Icons.facebook_rounded,
      Color(0xFF1877F2),
    ),
    _SocialProvider(
      'tiktok',
      'TikTok',
      Icons.music_note_rounded,
      Color(0xFF25F4EE),
    ),
    _SocialProvider(
      'youtube',
      'YouTube',
      Icons.play_circle_fill_rounded,
      Color(0xFFFF0033),
    ),
  ];

  Future<void> _connect(String provider) async {
    AppHaptics.medium();
    try {
      await ref.read(socialDistributionServiceProvider).connect(provider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _disconnect(String provider) async {
    AppHaptics.medium();
    await ref.read(socialDistributionServiceProvider).disconnect(provider);
    ref.invalidate(socialDistributionStateProvider);
  }

  Future<void> _savePrefs(
    SocialDistributionState current, {
    bool? autoPublish,
    Set<String>? providers,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(socialDistributionServiceProvider)
          .savePreferences(
            autoPublish: autoPublish ?? current.autoPublish,
            providers: providers ?? current.providers,
          );
      ref.invalidate(socialDistributionStateProvider);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(socialDistributionStateProvider);
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);

    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: AmbientPageBackground(
        fill: true,
        child: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load Social Boost\n$error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ink),
                ),
              ),
            ),
            data: (state) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(socialDistributionStateProvider);
                await ref.read(socialDistributionStateProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 42),
                children: [
                  Row(
                    children: [
                      const CapBackButton(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SOCIAL BOOST',
                              style: GoogleFonts.plusJakartaSans(
                                color: ink,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Post once. Prepare it for discovery everywhere.',
                              style: GoogleFonts.plusJakartaSans(
                                color: muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: MatteSurface.well(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: MatteSurface.hairline(context)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF34A853).withAlpha(28),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.travel_explore_rounded,
                            color: Color(0xFF34A853),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GOOGLE DISCOVERY',
                                style: GoogleFonts.plusJakartaSans(
                                  color: ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Always on for public Swipess pages. Listings, profiles and events are exposed through crawler-friendly previews and the Swipess sitemap.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: muted,
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const _StatusPill(text: 'ORGANIC · NO AD BUDGET'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: MatteSurface.well(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MatteSurface.hairline(context)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AUTO SHARE NEW LISTINGS',
                                style: GoogleFonts.plusJakartaSans(
                                  color: ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Only connected networks selected below. You can turn this off anytime.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: muted,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: state.autoPublish,
                          onChanged: _saving
                              ? null
                              : (value) =>
                                    _savePrefs(state, autoPublish: value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final provider in _providers) ...[
                    _ProviderCard(
                      provider: provider,
                      connection: state.connectionFor(provider.id),
                      enabled: state.providers.contains(provider.id),
                      saving: _saving,
                      onConnect: () => _connect(provider.id),
                      onDisconnect: () => _disconnect(provider.id),
                      onEnabledChanged: (enabled) {
                        final next = Set<String>.of(state.providers);
                        if (enabled) {
                          next.add(provider.id);
                        } else {
                          next.remove(provider.id);
                        }
                        _savePrefs(state, providers: next);
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'Direct posting depends on each network approving the Swipess developer app and the user authorizing that network. Until a network is approved/configured, your normal device Share action still works.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 10.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.connection,
    required this.enabled,
    required this.saving,
    required this.onConnect,
    required this.onDisconnect,
    required this.onEnabledChanged,
  });

  final _SocialProvider provider;
  final SocialConnection? connection;
  final bool enabled;
  final bool saving;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final connected = connection != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MatteSurface.well(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: provider.color.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(provider.icon, color: provider.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.label,
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  connected ? connection!.accountName : 'Not connected',
                  style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (connected) ...[
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Auto publish',
                        style: GoogleFonts.plusJakartaSans(
                          color: muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 28,
                        child: Switch.adaptive(
                          value: enabled,
                          onChanged: saving ? null : onEnabledChanged,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: connected ? onDisconnect : onConnect,
            child: Text(
              connected ? 'DISCONNECT' : 'CONNECT',
              style: GoogleFonts.plusJakartaSans(
                color: connected ? muted : provider.color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF34A853).withAlpha(25),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        color: const Color(0xFF34A853),
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: .6,
      ),
    ),
  );
}

class _SocialProvider {
  const _SocialProvider(this.id, this.label, this.icon, this.color);
  final String id;
  final String label;
  final IconData icon;
  final Color color;
}
