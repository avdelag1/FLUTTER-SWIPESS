import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';
import 'package:flutter_swipes/src/core/widgets/starfield_background.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_controller.dart';
import 'package:flutter_swipes/src/core/providers/app_notification_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final String mode;
  const AuthScreen({super.key, this.mode = 'login'});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late bool _isLogin;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.mode != 'signup';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleOAuth(OAuthProvider provider) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    AppHaptics.medium();

    final success = await ref
        .read(authControllerProvider.notifier)
        .loginWithOAuth(provider);
    if (!mounted) return;

    if (success) {
      context.go(AppPaths.clientDashboard);
    } else {
      final state = ref.read(authControllerProvider);
      if (state.hasError) {
        ref
            .read(appNotificationsProvider.notifier)
            .error('Sign In Failed', state.error.toString());
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ref
          .read(appNotificationsProvider.notifier)
          .error('Missing Information', 'Enter your email and password');
      return;
    }

    setState(() => _isLoading = true);
    AppHaptics.medium();

    final notifier = ref.read(authControllerProvider.notifier);
    final success = _isLogin
        ? await notifier.login(email, password)
        : await notifier.signup(
            email,
            password,
            name: _nameController.text.trim(),
          );

    if (!mounted) return;
    if (success) {
      context.go(AppPaths.clientDashboard);
    } else {
      final state = ref.read(authControllerProvider);
      if (state.hasError) {
        ref
            .read(appNotificationsProvider.notifier)
            .error('Authentication Failed', state.error.toString());
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ref
          .read(appNotificationsProvider.notifier)
          .error('Missing Email', 'Enter your email first');
      return;
    }
    final success = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(email);
    if (!mounted) return;
    if (success) {
      ref
          .read(appNotificationsProvider.notifier)
          .success('Reset Link Sent', 'Open it to set a new password');
    } else {
      final state = ref.read(authControllerProvider);
      ref
          .read(appNotificationsProvider.notifier)
          .error(
            'Reset Failed',
            state.error?.toString() ?? 'Could not send reset link',
          );
    }
  }

  void _toggleMode() {
    AppHaptics.light();
    setState(() {
      _isLogin = !_isLogin;
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const StarfieldBackground(),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 12,
                  left: 16,
                  child: Semantics(
                    button: true,
                    label: 'Back',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        AppHaptics.light();
                        context.pop();
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(8),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withAlpha(145),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 58, 24, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: SwipessLogo(
                              width: 220,
                              variant: SwipessLogoVariant.transparent,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _isLogin ? 'Welcome back' : 'Create an account',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isLogin
                                ? 'Sign in to continue.'
                                : 'Create your Swipess account.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withAlpha(135),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (!_isLogin) ...[
                            _buildInput(
                              controller: _nameController,
                              hint: 'Full Name',
                              icon: Icons.person_outline_rounded,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),
                          ],
                          _buildInput(
                            controller: _emailController,
                            hint: 'Email Address',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _buildInput(
                            controller: _passwordController,
                            hint: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!_isLoading) _handleSubmit();
                            },
                            onTogglePassword: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          if (_isLogin) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (val) => setState(
                                      () => _rememberMe = val ?? false,
                                    ),
                                    fillColor: WidgetStateProperty.resolveWith(
                                      (states) => states.contains(
                                        WidgetState.selected,
                                      )
                                          ? AppTheme.brandPrimary
                                          : Colors.transparent,
                                    ),
                                    side: BorderSide(
                                      color: Colors.white.withAlpha(105),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Remember me',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _resetPassword,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 24),
                          _PrimaryAuthButton(
                            label: _isLogin ? 'LOG IN' : 'CREATE ACCOUNT',
                            loading: _isLoading,
                            onPressed: _isLoading ? null : _handleSubmit,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : _toggleMode,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withAlpha(210),
                                  width: 1.4,
                                ),
                                shape: const StadiumBorder(),
                                backgroundColor: Colors.white.withAlpha(24),
                                disabledForegroundColor: Colors.white54,
                              ),
                              child: Text(
                                _isLogin ? 'CREATE AN ACCOUNT' : 'SIGN IN',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withAlpha(45),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  'or',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(145),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withAlpha(45),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _buildSocialButton(
                            icon: Icons.apple_rounded,
                            label: 'CONTINUE WITH APPLE',
                            onTap: _isLoading
                                ? null
                                : () => _handleOAuth(OAuthProvider.apple),
                          ),
                          const SizedBox(height: 12),
                          _buildSocialButton(
                            icon: Icons.g_mobiledata_rounded,
                            label: 'CONTINUE WITH GOOGLE',
                            onTap: _isLoading
                                ? null
                                : () => _handleOAuth(OAuthProvider.google),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    bool isPassword = false,
    VoidCallback? onTogglePassword,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return GlassTextField(
      controller: controller,
      hint: hint,
      icon: icon,
      obscureText: obscureText,
      onToggleObscure: isPassword ? onTogglePassword : null,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      height: 54,
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withAlpha(180),
          disabledForegroundColor: Colors.black54,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryAuthButton extends StatelessWidget {
  const _PrimaryAuthButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.brandPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.brandPrimary.withAlpha(100),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }
}
