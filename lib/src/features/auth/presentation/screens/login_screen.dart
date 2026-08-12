import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  bool _googleLoading = false;
  bool _appleLoading = false;
  String _error = '';
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      if (_isSignUp) {
        await Supabase.instance.client.auth.signUp(email: email, password: password);
      } else {
        await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
      HapticFeedback.mediumImpact();
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
      HapticFeedback.mediumImpact();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _googleLoading = true; _error = ''; });
    try {
      const webClientId = '576100661898-0r2oln9bbfu9p3bbqvvsn0j8l3ks4qks.apps.googleusercontent.com';
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
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Google sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() { _appleLoading = true; _error = ''; });
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'co.swipess.app',
          redirectUri: Uri.parse('https://vplgtcguxujxwrgguxqq.supabase.co/auth/v1/callback'),
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
        setState(() => _error = 'Apple sign-in failed. Try again.');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Apple sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => _appleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background orbs
          Positioned(top: -100, right: -80,
            child: _buildOrb(AppTheme.brandPrimary.withAlpha(50), 300)),
          Positioned(bottom: -80, left: -60,
            child: _buildOrb(AppTheme.brandAccent.withAlpha(40), 260)),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildGlassCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            boxShadow: [BoxShadow(color: AppTheme.brandPrimary.withAlpha(80), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.swipe_rounded, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 18),
        Text(
          _isSignUp ? 'Create Account' : 'Welcome Back',
          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1),
        ),
        const SizedBox(height: 6),
        Text(
          _isSignUp ? 'Join the exclusive network' : 'Sign in to continue',
          style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildGlassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(13),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withAlpha(25), width: 1),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              // Social Sign-Ins
              _buildAppleButton(),
              const SizedBox(height: 12),
              _buildGoogleButton(),
              const SizedBox(height: 20),

              // Divider
              Row(children: [
                Expanded(child: Divider(color: Colors.white.withAlpha(40), thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text('or', style: TextStyle(color: Colors.white.withAlpha(114), fontSize: 13)),
                ),
                Expanded(child: Divider(color: Colors.white.withAlpha(40), thickness: 1)),
              ]),
              const SizedBox(height: 20),

              // Email / Password
              _buildInputField(_emailCtrl, 'Email address', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildInputField(_passwordCtrl, 'Password', Icons.lock_outline_rounded, obscure: _obscurePassword, onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword)),
              const SizedBox(height: 10),

              // Error
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _error.isNotEmpty
                    ? Padding(
                        key: ValueKey(_error),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(_error, style: const TextStyle(color: Color(0xFFFC8181), fontSize: 13), textAlign: TextAlign.center),
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),

              // Sign In / Sign Up Button
              _buildMainButton(),
              const SizedBox(height: 16),

              // Toggle sign in / sign up
              GestureDetector(
                onTap: () => setState(() { _isSignUp = !_isSignUp; _error = ''; }),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                        style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 13),
                      ),
                      TextSpan(
                        text: _isSignUp ? 'Sign In' : 'Sign Up',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppleButton() {
    return _SocialButton(
      onTap: _appleLoading ? null : _signInWithApple,
      loading: _appleLoading,
      icon: Icons.apple_rounded,
      label: _isSignUp ? 'Sign up with Apple' : 'Continue with Apple',
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    );
  }

  Widget _buildGoogleButton() {
    return _SocialButton(
      onTap: _googleLoading ? null : _signInWithGoogle,
      loading: _googleLoading,
      icon: Icons.g_mobiledata_rounded,
      label: _isSignUp ? 'Sign up with Google' : 'Continue with Google',
      backgroundColor: Colors.white.withAlpha(20),
      foregroundColor: Colors.white,
      borderColor: Colors.white.withAlpha(50),
    );
  }

  Widget _buildInputField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(51), width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(icon, color: Colors.white.withAlpha(153), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctrl,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: Colors.white.withAlpha(114), fontSize: 14),
              ),
              onSubmitted: (_) => _signInWithEmail(),
            ),
          ),
          if (onToggleObscure != null)
            IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: Colors.white.withAlpha(153), size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(color: AppTheme.brandPrimary.withAlpha(80), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: ElevatedButton(
          onPressed: _loading ? null : _signInWithEmail,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(
                  _isSignUp ? 'Create Account' : 'Sign In',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}

// ─── Social Sign-In Button ───────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;

  const _SocialButton({
    required this.onTap,
    required this.loading,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: BorderSide(color: borderColor ?? Colors.transparent, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: foregroundColor))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: foregroundColor),
                  const SizedBox(width: 10),
                  Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: foregroundColor)),
                ],
              ),
      ),
    );
  }
}
