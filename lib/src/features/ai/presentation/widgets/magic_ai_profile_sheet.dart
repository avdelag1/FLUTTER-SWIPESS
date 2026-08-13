import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_providers.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap Magic AI Profile — `ai-profile-extract` then save core fields.
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
    HapticFeedback.mediumImpact();
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
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            displayName: displayName,
            bio: bio,
            city: (city != null && city.isNotEmpty)
                ? city
                : existing?.city,
          );
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Magic AI Profile applied')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
      );
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
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
            const SizedBox(height: 16),
            Text(
              'MAGIC AI PROFILE',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Describe yourself — Swipess Edge AI drafts your bio (and name/city when found).',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            GlassTextField(
              controller: _narrative,
              hint: 'e.g. Digital nomad in Tulum, love oceanfront stays…',
              icon: Icons.auto_awesome_rounded,
              maxLines: 4,
              height: 120,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _run,
              style: FilledButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                _busy ? 'GENERATING…' : 'GENERATE & SAVE',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
