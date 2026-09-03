import 'package:flutter_swipes/src/features/ai/presentation/widgets/ai_disclosure.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_providers.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/screens/paywall_screen.dart';
import 'package:google_fonts/google_fonts.dart';

/// Magic AI Profile — included with the 3-month welcome period and Premium.
/// Direct Requests are marketplace connection credits and are never consumed by
/// AI generation.
Future<void> showMagicAiProfileSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _MagicAiProfileSheet(),
  );
}

class _MagicAiProfileSheet extends ConsumerStatefulWidget {
  const _MagicAiProfileSheet();

  @override
  ConsumerState<_MagicAiProfileSheet> createState() =>
      _MagicAiProfileSheetState();
}

class _MagicAiProfileSheetState extends ConsumerState<_MagicAiProfileSheet> {
  final _narrative = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _narrative.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_busy) return;
    final text = _narrative.text.trim();
    if (text.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tell us a bit more about yourself')),
      );
      return;
    }

    setState(() => _busy = true);
    AppHaptics.medium();

    try {
      // Use the same authoritative subscription/trial calculation as the rest
      // of the app. Never spend a Direct Request to use Premium AI.
      final cached = ref.read(subscriptionProvider).value;
      final access =
          cached ??
          await ref.read(subscriptionRepositoryProvider).fetchCurrent();
      if (!access.effectiveTier.canUseAI) {
        if (!mounted) return;
        setState(() => _busy = false);
        showPaywall(context, featureName: 'SWIPESS AI');
        return;
      }

      final ai = ref.read(aiEdgeRepositoryProvider);
      final draft = await ai.extractProfile(narrative: text);
      var bio = draft['bio']?.toString().trim();
      if (bio == null || bio.isEmpty) {
        bio = await ai.enhanceText(text: text, type: 'profile') ?? text;
      }
      final name = draft['name']?.toString().trim();
      final city = draft['city']?.toString().trim();
      final existing = ref.read(currentProfileProvider).value;
      final displayName = (name != null && name.isNotEmpty)
          ? name
          : (existing?.displayName ?? 'Swipess User');

      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            displayName: displayName,
            bio: bio,
            city: (city != null && city.isNotEmpty) ? city : existing?.city,
          );
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Magic AI Profile applied')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not generate profile: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E2A3A), Color(0xFF09090B)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'MAGIC AI PROFILE',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.6,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Included during your 3-month welcome access and with Premium. Describe yourself and Google Gemini drafts your bio.',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 14),
            GlassTextField(
              controller: _narrative,
              hint: 'e.g. Digital nomad in Tulum, love oceanfront stays…',
              icon: Icons.auto_awesome_rounded,
              maxLines: 4,
              height: 120,
            ),
            SizedBox(height: 12),
            const AiDisclosure(isLight: false),
            SizedBox(height: 16),
            GestureDetector(
              onTap: _busy ? null : _run,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: _busy
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
                        ),
                  color: _busy ? Colors.white24 : null,
                  boxShadow: _busy
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x59E11D48),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                ),
                child: Center(
                  child: _busy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'GENERATE PROFILE',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
