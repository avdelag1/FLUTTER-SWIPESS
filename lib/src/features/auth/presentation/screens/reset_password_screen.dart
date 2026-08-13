import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cap ResetPassword — recovery-session password update with strength UI.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _showConfirm = false;
  bool _busy = false;
  String? _error;

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
    final score =
        [length, lower, upper, number].where((v) => v).length;
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
    HapticFeedback.mediumImpact();
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _password.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
      context.go('/welcome');
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _strength;
    final color = s.score <= 1
        ? const Color(0xFFEF4444)
        : s.score == 2
            ? const Color(0xFFF97316)
            : s.score == 3
                ? const Color(0xFFEAB308)
                : const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => context.go('/welcome'),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: SwipessLogo(
                height: 36,
                variant: SwipessLogoVariant.outline,
              ),
            ),
            const SizedBox(height: 24),
            Text('RESET PASSWORD',
                style: AppTheme.displayItalic.copyWith(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              'Choose a strong new password for your Swipess account.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white54),
            ),
            const SizedBox(height: 28),
            GlassTextField(
              controller: _password,
              hint: 'New password',
              icon: Icons.lock_outline_rounded,
              obscureText: !_show,
              onToggleObscure: () => setState(() => _show = !_show),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            GlassTextField(
              controller: _confirm,
              hint: 'Confirm password',
              icon: Icons.lock_rounded,
              obscureText: !_showConfirm,
              onToggleObscure: () =>
                  setState(() => _showConfirm = !_showConfirm),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: s.score / 4,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            for (final row in [
              (s.length, 'At least 8 characters'),
              (s.lower, 'Lowercase letter'),
              (s.upper, 'Uppercase letter'),
              (s.number, 'Number'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      row.$1 ? Icons.check_circle : Icons.circle_outlined,
                      size: 16,
                      color: row.$1
                          ? const Color(0xFF10B981)
                          : Colors.white38,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      row.$2,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: Color(0xFFF87171))),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                ),
                child: Text(
                  _busy ? 'Updating…' : 'UPDATE PASSWORD',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
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
