import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/core/widgets/starfield_background.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_controller.dart';
import 'package:flutter_swipes/src/core/providers/app_notification_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cap ResetPassword — recovery-session password update with strength UI.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _showConfirm = false;
  bool _busy = false;
  String? _error;

  bool get _isAdminRecovery =>
      GoRouterState.of(context).uri.queryParameters['portal'] == 'admin';

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  ({bool length, bool lower, bool upper, bool number, int score, String label})
  get _strength {
    final p = _password.text;
    final length = p.length >= 8;
    final lower = RegExp(r'[a-z]').hasMatch(p);
    final upper = RegExp(r'[A-Z]').hasMatch(p);
    final number = RegExp(r'[0-9]').hasMatch(p);
    final score = [length, lower, upper, number].where((v) => v).length;
    final label = score <= 1
        ? 'Weak'
        : score == 2
        ? 'Fair'
        : score == 3
        ? 'Good'
        : 'Strong';
    return (
      length: length,
      lower: lower,
      upper: upper,
      number: number,
      score: score,
      label: label,
    );
  }

  Future<void> _submit() async {
    final s = _strength;
    if (s.score < 3) {
      setState(() => _error = 'Use a stronger password');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    AppHaptics.medium();

    final returnToAdmin = _isAdminRecovery;
    final success = await ref
        .read(authControllerProvider.notifier)
        .updatePassword(_password.text);
    if (!mounted) return;

    if (success) {
      ref
          .read(appNotificationsProvider.notifier)
          .success(
            'Password Updated',
            returnToAdmin
                ? 'Your Admin password is ready. Returning to Admin sign in.'
                : 'Your password has been changed',
          );

      if (returnToAdmin) {
        final opened = await launchUrl(
          Uri.parse('https://admin.swipess.com/admin-auth'),
          webOnlyWindowName: '_self',
        );
        if (opened) return;
      }
      if (mounted) context.go('/welcome');
    } else {
      final state = ref.read(authControllerProvider);
      setState(() => _error = state.error?.toString() ?? 'Update failed');
    }

    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _strength;
    final adminRecovery = _isAdminRecovery;
    final color = s.score <= 1
        ? const Color(0xFFEF4444)
        : s.score == 2
        ? const Color(0xFFF97316)
        : s.score == 3
        ? const Color(0xFFEAB308)
        : const Color(0xFF10B981);

    return Scaffold(
      body: Stack(
        children: [
          const StarfieldBackground(),
          SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 40),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.go('/welcome'),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Center(
                  child: SwipessLogo(
                    height: 36,
                    variant: SwipessLogoVariant.outline,
                  ),
                ),
                SizedBox(height: 24),
                NeoNaiveCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adminRecovery ? 'SET ADMIN PASSWORD' : 'RESET PASSWORD',
                        style: AppTheme.displayItalic.copyWith(fontSize: 28),
                      ),
                      SizedBox(height: 8),
                      Text(
                        adminRecovery
                            ? 'Create a secure password for this Admin identity. You can then sign in to Admin with email + password even when Google or Apple is unavailable.'
                            : 'Choose a strong new password for your Swipess account.',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white),
                      ),
                      SizedBox(height: 28),
                      GlassTextField(
                        controller: _password,
                        hint: 'New password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: !_show,
                        onToggleObscure: () => setState(() => _show = !_show),
                        onChanged: (_) => setState(() {}),
                      ),
                      SizedBox(height: 12),
                      GlassTextField(
                        controller: _confirm,
                        hint: 'Confirm password',
                        icon: Icons.lock_rounded,
                        obscureText: !_showConfirm,
                        onToggleObscure: () =>
                            setState(() => _showConfirm = !_showConfirm),
                        onChanged: (_) => setState(() {}),
                      ),
                      SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: s.score / 4,
                          minHeight: 6,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        s.label.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 12),
                      for (final row in [
                        (s.length, 'At least 8 characters'),
                        (s.lower, 'Lowercase letter'),
                        (s.upper, 'Uppercase letter'),
                        (s.number, 'Number'),
                      ])
                        Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                row.$1
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                size: 16,
                                color: row.$1
                                    ? const Color(0xFF10B981)
                                    : Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                row.$2,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_error != null) ...[
                        SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: Color(0xFFF87171)),
                        ),
                      ],
                      SizedBox(height: 24),
                      BrandPrimaryButton(
                        label: _busy
                            ? 'Updating…'
                            : adminRecovery
                            ? 'Set Admin password'
                            : 'Update password',
                        loading: _busy,
                        onPressed: _busy ? null : _submit,
                      ),
                    ],
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
