import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/session/session_controller.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/core/widgets/legal_sheet.dart';
import 'package:flutter_swipes/src/core/widgets/starfield_background.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor `AuthView` — email/password plus Apple & Google options.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showPassword = false;
  bool _rememberMe = false;
  bool _agreed18 = false;
  bool _agreedTerms = false;
  bool _forgot = false;
  bool _loading = false;
  Map<String, String> _errors = {};

  bool get _isLogin =>
      ref.read(sessionProvider).authIntent == AuthIntent.login && !_forgot;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _requireAgreement() {
    if (_isLogin) return true;
    if (_agreed18 && _agreedTerms) return true;
    setState(() {
      _errors = {
        ..._errors,
        'agree':
            'Please confirm you are 18+ and agree to the Terms of Use (EULA) & Privacy Policy',
      };
    });
    HapticFeedback.heavyImpact();
    return false;
  }

  Future<void> _submit() async {
    final errors = <String, String>{};
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (_forgot) {
      if (email.isEmpty || !email.contains('@')) {
        errors['email'] = 'Enter a valid email address';
      }
      setState(() => _errors = errors);
      if (errors.isNotEmpty) return;
      setState(() => _loading = true);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _loading = false;
        _forgot = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset link sent')),
      );
      return;
    }

    if (!_isLogin && name.isEmpty) errors['name'] = 'Name is required';
    if (email.isEmpty) {
      errors['email'] = 'Email is required';
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      errors['email'] = 'Enter a valid email address';
    }
    if (password.isEmpty) {
      errors['password'] = 'Password is required';
    } else if (!_isLogin &&
        (password.length < 8 ||
            !RegExp('[a-z]').hasMatch(password) ||
            !RegExp('[A-Z]').hasMatch(password) ||
            !RegExp('[0-9]').hasMatch(password))) {
      errors['password'] = 'Use 8+ characters with upper, lower & a number';
    }
    if (!_isLogin) {
      if (_confirmController.text.isEmpty) {
        errors['confirm'] = 'Please confirm your password';
      } else if (_confirmController.text != password) {
        errors['confirm'] = 'Passwords do not match';
      }
      if (!_agreed18 || !_agreedTerms) {
        errors['agree'] =
            'Please confirm you are 18+ and agree to the Terms of Use (EULA) & Privacy Policy';
      }
    }

    setState(() => _errors = errors);
    if (errors.isNotEmpty) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    ref.read(sessionProvider.notifier).signInDemo(name: name);
    context.go('/dashboard');
  }

  Future<void> _social() async {
    if (!_requireAgreement()) return;
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    ref.read(sessionProvider.notifier).signInDemo();
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionProvider);
    final isLogin = _isLogin;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const StarfieldBackground(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GlassIconCircle(
                              icon: Icons.arrow_back,
                              onPressed: () {
                                if (_forgot) {
                                  setState(() => _forgot = false);
                                } else {
                                  context.go('/welcome');
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          const SwipessLogo(height: 40),
                          const SizedBox(height: 28),
                          if (_forgot)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                'SECURITY PROTOCOL — RESET',
                                style: AppTheme.kicker.copyWith(
                                  color: const Color(0x80FFFFFF),
                                ),
                              ),
                            ),
                          if (!isLogin && !_forgot) ...[
                            GlassTextField(
                              controller: _nameController,
                              hint: 'Your Name',
                              icon: Icons.person_outline,
                              errorText: _errors['name'],
                              onChanged: (_) => setState(() => _errors.remove('name')),
                            ),
                            const SizedBox(height: 12),
                          ],
                          GlassTextField(
                            controller: _emailController,
                            hint: 'Email',
                            icon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                            errorText: _errors['email'],
                            onChanged: (_) => setState(() => _errors.remove('email')),
                          ),
                          if (!_forgot) ...[
                            const SizedBox(height: 12),
                            GlassTextField(
                              controller: _passwordController,
                              hint: 'Password',
                              icon: Icons.lock_outline,
                              obscureText: !_showPassword,
                              onToggleObscure: () =>
                                  setState(() => _showPassword = !_showPassword),
                              errorText: _errors['password'],
                              onChanged: (_) =>
                                  setState(() => _errors.remove('password')),
                            ),
                          ],
                          if (!isLogin && !_forgot) ...[
                            const SizedBox(height: 12),
                            GlassTextField(
                              controller: _confirmController,
                              hint: 'Confirm Password',
                              icon: Icons.lock_outline,
                              obscureText: !_showPassword,
                              errorText: _errors['confirm'],
                              onChanged: (_) =>
                                  setState(() => _errors.remove('confirm')),
                            ),
                          ],
                          if (isLogin && !_forgot)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(
                                children: [
                                  AgreeCheckbox(
                                    value: _rememberMe,
                                    onChanged: (v) => setState(() => _rememberMe = v),
                                    child: Text(
                                      'REMEMBER ME',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xB3FFFFFF),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () => setState(() => _forgot = true),
                                    child: Text(
                                      'FORGOT ACCESS CODE?',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xB3FFFFFF),
                                        fontWeight: FontWeight.w800,
                                        fontStyle: FontStyle.italic,
                                        fontSize: 10,
                                        letterSpacing: 1.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!isLogin && !_forgot) ...[
                            const SizedBox(height: 14),
                            AgreeCheckbox(
                              value: _agreed18,
                              onChanged: (v) {
                                setState(() {
                                  _agreed18 = v;
                                  _errors.remove('agree');
                                });
                              },
                              child: Text(
                                'I confirm I am 18 or older',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xBFFFFFFF),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            AgreeCheckbox(
                              value: _agreedTerms,
                              onChanged: (v) {
                                setState(() {
                                  _agreedTerms = v;
                                  _errors.remove('agree');
                                });
                              },
                              child: Text.rich(
                                TextSpan(
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xBFFFFFFF),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                  children: [
                                    const TextSpan(text: 'I agree to the '),
                                    WidgetSpan(
                                      child: GestureDetector(
                                        onTap: () => showLegalSheet(
                                          context,
                                          doc: LegalDoc.terms,
                                          onAgree: () => setState(() => _agreedTerms = true),
                                        ),
                                        child: Text(
                                          'Terms of Use (EULA)',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const TextSpan(text: ' & '),
                                    WidgetSpan(
                                      child: GestureDetector(
                                        onTap: () => showLegalSheet(
                                          context,
                                          doc: LegalDoc.privacy,
                                          onAgree: () => setState(() => _agreedTerms = true),
                                        ),
                                        child: Text(
                                          'Privacy Policy',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const TextSpan(text: '.'),
                                  ],
                                ),
                              ),
                            ),
                            if (_errors['agree'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _errors['agree']!.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xE6EF4444),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 18),
                          BrandPrimaryButton(
                            label: _loading
                                ? 'Processing...'
                                : _forgot
                                    ? 'Send Reset Link'
                                    : isLogin
                                        ? 'Sign In'
                                        : 'Create Account',
                            icon: Icons.auto_awesome,
                            loading: _loading,
                            onPressed: _loading ? null : _submit,
                          ),
                          if (!_forgot) ...[
                            const SizedBox(height: 12),
                            BrandGhostButton(
                              label: isLogin ? 'Create Account' : 'Back to Sign In',
                              onPressed: () {
                                ref.read(sessionProvider.notifier).openAuth(
                                      isLogin ? AuthIntent.signup : AuthIntent.login,
                                    );
                                setState(() => _errors = {});
                              },
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Expanded(child: Divider(color: Color(0x26FFFFFF))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'OR',
                                    style: AppTheme.kicker.copyWith(
                                      color: const Color(0x99FFFFFF),
                                      letterSpacing: 4,
                                    ),
                                  ),
                                ),
                                const Expanded(child: Divider(color: Color(0x26FFFFFF))),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SocialAuthButton(
                              label: isLogin ? 'Sign in with Apple' : 'Sign up with Apple',
                              leading: const Icon(Icons.apple, color: Colors.black, size: 20),
                              onPressed: _loading ? null : _social,
                            ),
                            const SizedBox(height: 10),
                            SocialAuthButton(
                              label: isLogin
                                  ? 'Continue with Google'
                                  : 'Sign up with Google',
                              leading: const _GoogleMark(),
                              onPressed: _loading ? null : _social,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _FooterLink(
                            label: 'Privacy',
                            onTap: () => showLegalSheet(context, doc: LegalDoc.privacy),
                          ),
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: const BoxDecoration(
                              color: Color(0x4DFFFFFF),
                              shape: BoxShape.circle,
                            ),
                          ),
                          _FooterLink(
                            label: 'Terms',
                            onTap: () => showLegalSheet(context, doc: LegalDoc.terms),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '© 2026 SWIPESS',
                        style: AppTheme.kicker.copyWith(
                          color: const Color(0x4DFFFFFF),
                          fontSize: 8,
                          letterSpacing: 3.6,
                        ),
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

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label.toUpperCase(),
        style: AppTheme.kicker.copyWith(fontSize: 9, letterSpacing: 2.8),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              Color(0xFFEA4335),
              Color(0xFFFBBC05),
              Color(0xFF34A853),
              Color(0xFF4285F4),
              Color(0xFFEA4335),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(3),
          child: DecoratedBox(
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
