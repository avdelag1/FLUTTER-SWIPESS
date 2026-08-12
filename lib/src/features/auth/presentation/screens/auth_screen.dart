import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/core/widgets/legal_sheet.dart';
import 'package:flutter_swipes/src/core/widgets/starfield_background.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Capacitor `AuthView` — email/password + Apple/Google, wired to real Supabase.
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
      ref.read(authIntentProvider) == AuthIntent.login && !_forgot;

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
    final isLogin = _isLogin;

    if (_forgot) {
      if (email.isEmpty || !email.contains('@')) {
        errors['email'] = 'Enter a valid email address';
      }
      setState(() => _errors = errors);
      if (errors.isNotEmpty) return;
      setState(() => _loading = true);
      try {
        await Supabase.instance.client.auth.resetPasswordForEmail(email);
        if (!mounted) return;
        setState(() {
          _loading = false;
          _forgot = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset link sent')),
        );
      } on AuthException catch (e) {
        setState(() {
          _loading = false;
          _errors = {'email': e.message};
        });
      } catch (_) {
        setState(() {
          _loading = false;
          _errors = {'email': 'Could not send reset link'};
        });
      }
      return;
    }

    if (!isLogin && name.isEmpty) errors['name'] = 'Name is required';
    if (email.isEmpty) {
      errors['email'] = 'Email is required';
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      errors['email'] = 'Enter a valid email address';
    }
    if (password.isEmpty) {
      errors['password'] = 'Password is required';
    } else if (!isLogin &&
        (password.length < 8 ||
            !RegExp('[a-z]').hasMatch(password) ||
            !RegExp('[A-Z]').hasMatch(password) ||
            !RegExp('[0-9]').hasMatch(password))) {
      errors['password'] = 'Use 8+ characters with upper, lower & a number';
    }
    if (!isLogin) {
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
    try {
      if (isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: name.isEmpty ? null : {'full_name': name},
        );
      }
      HapticFeedback.lightImpact();
    } on AuthException catch (e) {
      setState(() => _errors = {'email': e.message});
      HapticFeedback.mediumImpact();
    } catch (_) {
      setState(() => _errors = {'email': 'Something went wrong. Try again.'});
      HapticFeedback.mediumImpact();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!_requireAgreement()) return;
    setState(() {
      _loading = true;
      _errors = {};
    });
    try {
      const webClientId =
          '576100661898-0r2oln9bbfu9p3bbqvvsn0j8l3ks4qks.apps.googleusercontent.com';
      await GoogleSignIn.instance.initialize(serverClientId: webClientId);
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw Exception('No ID token');
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      HapticFeedback.lightImpact();
    } on AuthException catch (e) {
      setState(() => _errors = {'email': e.message});
    } catch (_) {
      setState(() => _errors = {'email': 'Google sign-in failed. Try again.'});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithApple() async {
    if (!_requireAgreement()) return;
    setState(() {
      _loading = true;
      _errors = {};
    });
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'co.swipess.app',
          redirectUri: Uri.parse(
            'https://vplgtcguxujxwrgguxqq.supabase.co/auth/v1/callback',
          ),
        ),
      );
      final idToken = credential.identityToken;
      if (idToken == null) throw Exception('No identity token');
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );
      HapticFeedback.lightImpact();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        setState(() => _errors = {'email': 'Apple sign-in failed. Try again.'});
      }
    } on AuthException catch (e) {
      setState(() => _errors = {'email': e.message});
    } catch (_) {
      setState(() => _errors = {'email': 'Apple sign-in failed. Try again.'});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authIntentProvider);
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
                    child: Center(
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
                            if (!isLogin && !_forgot) ...[
                              GlassTextField(
                                controller: _nameController,
                                hint: 'Your Name',
                                icon: Icons.person_outline,
                                errorText: _errors['name'],
                                onChanged: (_) =>
                                    setState(() => _errors.remove('name')),
                              ),
                              const SizedBox(height: 12),
                            ],
                            GlassTextField(
                              controller: _emailController,
                              hint: 'Email',
                              icon: Icons.mail_outline,
                              keyboardType: TextInputType.emailAddress,
                              errorText: _errors['email'],
                              onChanged: (_) =>
                                  setState(() => _errors.remove('email')),
                            ),
                            if (!_forgot) ...[
                              const SizedBox(height: 12),
                              GlassTextField(
                                controller: _passwordController,
                                hint: 'Password',
                                icon: Icons.lock_outline,
                                obscureText: !_showPassword,
                                onToggleObscure: () => setState(
                                  () => _showPassword = !_showPassword,
                                ),
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
                                      expand: false,
                                      onChanged: (v) =>
                                          setState(() => _rememberMe = v),
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
                                      onPressed: () =>
                                          setState(() => _forgot = true),
                                      child: Text(
                                        'Forgot your password?',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xB3FFFFFF),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
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
                                            onAgree: () => setState(
                                              () => _agreedTerms = true,
                                            ),
                                          ),
                                          child: Text(
                                            'Terms of Use (EULA)',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                              decoration:
                                                  TextDecoration.underline,
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
                                            onAgree: () => setState(
                                              () => _agreedTerms = true,
                                            ),
                                          ),
                                          child: Text(
                                            'Privacy Policy',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_errors['agree'] != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _errors['agree']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xE6EF4444),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
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
                                          ? 'Log In'
                                          : 'Create Account',
                              loading: _loading,
                              onPressed: _loading ? null : _submit,
                            ),
                            if (!_forgot) ...[
                              const SizedBox(height: 12),
                              BrandGhostButton(
                                label: isLogin
                                    ? 'Create An Account'
                                    : 'Back to Sign In',
                                onPressed: () {
                                  ref.read(authIntentProvider.notifier).set(
                                        isLogin
                                            ? AuthIntent.signup
                                            : AuthIntent.login,
                                      );
                                  setState(() => _errors = {});
                                },
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Divider(color: Color(0x26FFFFFF)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      'or',
                                      style: AppTheme.kicker.copyWith(
                                        color: const Color(0x99FFFFFF),
                                        letterSpacing: 4,
                                        fontStyle: FontStyle.normal,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    child: Divider(color: Color(0x26FFFFFF)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SocialAuthButton(
                                label: 'Continue with Apple',
                                leading: const Icon(
                                  Icons.apple,
                                  color: Colors.black,
                                  size: 20,
                                ),
                                onPressed: _loading ? null : _signInWithApple,
                              ),
                              const SizedBox(height: 10),
                              SocialAuthButton(
                                label: 'Continue with Google',
                                leading: const _GoogleMark(),
                                onPressed: _loading ? null : _signInWithGoogle,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _FooterLink(
                        label: 'Privacy',
                        onTap: () =>
                            showLegalSheet(context, doc: LegalDoc.privacy),
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
                        onTap: () =>
                            showLegalSheet(context, doc: LegalDoc.terms),
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
