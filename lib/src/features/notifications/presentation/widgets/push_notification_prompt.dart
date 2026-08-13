import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cap `PushNotificationPrompt` — soft ask after login (design lane).
class PushNotificationPrompt extends StatefulWidget {
  const PushNotificationPrompt({super.key, required this.enabled});

  final bool enabled;

  static const prefsKey = 'notification_prompt_dismissed_v2';
  static const cooldownMs = 14 * 24 * 60 * 60 * 1000;

  @override
  State<PushNotificationPrompt> createState() => _PushNotificationPromptState();
}

class _PushNotificationPromptState extends State<PushNotificationPrompt> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _maybeShow();
  }

  @override
  void didUpdateWidget(covariant PushNotificationPrompt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) _maybeShow();
  }

  Future<void> _maybeShow() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(PushNotificationPrompt.prefsKey);
    if (raw != null) {
      final ts = DateTime.tryParse(raw);
      if (ts != null &&
          DateTime.now().difference(ts).inMilliseconds <
              PushNotificationPrompt.cooldownMs) {
        return;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 4500));
    if (!mounted) return;
    // Wait until guided tour is done so prompts don't stack.
    final tourDone =
        prefs.getBool('guidedTourCompleted') ?? false;
    if (!tourDone) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      final again = prefs.getBool('guidedTourCompleted') ?? false;
      if (!again) return;
    }
    setState(() => _open = true);
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PushNotificationPrompt.prefsKey,
      DateTime.now().toIso8601String(),
    );
    if (!mounted) return;
    setState(() => _open = false);
  }

  Future<void> _enable() async {
    HapticFeedback.mediumImpact();
    // Bases: wire flutter_local_notifications / FCM subscribe.
    await _dismiss();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Phone notifications will activate when push is wired (bases).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) return const SizedBox.shrink();

    return Material(
      color: Colors.black.withAlpha(160),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0D),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withAlpha(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.brandPrimary.withAlpha(28),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: AppTheme.brandPrimary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Get alerts on your phone',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Allow notifications so matches, messages, and promos pop up even when the app is closed.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white60,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: const [
                        _BenefitRow(
                          icon: Icons.chat_bubble_rounded,
                          color: Color(0xFF3B82F6),
                          label: 'New messages',
                        ),
                        SizedBox(height: 8),
                        _BenefitRow(
                          icon: Icons.local_fire_department_rounded,
                          color: Color(0xFFF97316),
                          label: 'Likes & matches',
                        ),
                        SizedBox(height: 8),
                        _BenefitRow(
                          icon: Icons.workspace_premium_rounded,
                          color: Color(0xFFFBBF24),
                          label: 'Partner promos & updates',
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _enable,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.brandPrimary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Text(
                              'Enable phone notifications',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _dismiss,
                          child: Text(
                            'Not now',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white54,
                              fontWeight: FontWeight.w700,
                            ),
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
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(55)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
