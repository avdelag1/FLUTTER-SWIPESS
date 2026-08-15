import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/config/app_config.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_cta_button.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';
import 'package:flutter_swipes/src/core/widgets/starfield_background.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/auth/data/auth_repository.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/core/providers/app_notification_provider.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final String mode;
  const AuthScreen({super.key, this.mode = 'login'});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  /// Native iOS has no Google client id in this binary — hide the button
  /// rather than let reviewers tap a dead Google login (2.1).
  bool get _showGoogleSignIn {
    if (kIsWeb) return true;
    if (defaultTargetPlatform != TargetPlatform.iOS) return true;
    return AppConfig.googleIosClientId.trim().isNotEmpty ||
        AppConfig.googleServerClientId.trim().isNotEmpty;
  }

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
    bool success;
    if (_isLogin) {
      success = await notifier.login(email, password);
    } else {
      success = await notifier.signup(
        email,
        password,
        name: _nameController.text.trim(),
      );
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const StarfieldBackground(),
          SafeArea(
            child: Stack(
              children: [
                // Back button
                Positioned(
                  top: 16,
                  left: 16,
                  child: GestureDetector(
                    onTap: () {
                      AppHaptics.light();
                      context.pop();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                // Content
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 48),
                          const Center(
                            child: SwipessLogo(
                              width: 380,
                              variant: SwipessLogoVariant.hero,
                              color: AppTheme.mexicanRed,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            _isLogin ? 'Welcome back' : 'Create an account',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          if (!_isLogin) ...[
                            _buildInput(
                              controller: _nameController,
                              hint: 'Full Name',
                              icon: Icons.person_outline_rounded,
                            ),
                            const SizedBox(height: 16),
                          ],

                          _buildInput(
                            controller: _emailController,
                            hint: 'Email Address',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),

                          _buildInput(
                            controller: _passwordController,
                            hint: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            isPassword: true,
                            onTogglePassword: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (_isLogin)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged: (val) => setState(
                                          () => _rememberMe = val ?? false,
                                        ),
                                        fillColor:
                                            WidgetStateProperty.resolveWith(
                                              (states) =>
                                                  states.contains(
                                                    WidgetState.selected,
                                                  )
                                                  ? AppTheme.brandPrimary
                                                  : Colors.transparent,
                                            ),
                                        side: BorderSide(
                                          color: Colors.white.withAlpha(128),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Remember me',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final email = _emailController.text.trim();
                                    if (email.isEmpty) {
                                      ref
                                          .read(
                                            appNotificationsProvider.notifier,
                                          )
                                          .error(
                                            'Missing Email',
                                            'Enter your email first',
                                          );
                                      return;
                                    }
                                    final success = await ref
                                        .read(authControllerProvider.notifier)
                                        .resetPassword(email);
                                    if (!mounted) return;
                                    if (success) {
                                      ref
                                          .read(
                                            appNotificationsProvider.notifier,
                                          )
                                          .success(
                                            'Reset Link Sent',
                                            'Open it to set a new password',
                                          );
                                    } else {
                                      final state = ref.read(
                                        authControllerProvider,
                                      );
                                      ref
                                          .read(
                                            appNotificationsProvider.notifier,
                                          )
                                          .error(
                                            'Reset Failed',
                                            state.error?.toString() ??
                                                'Could not send reset link',
                                          );
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 32),

                          SwipessCtaButton(
                            label: _isLogin ? 'LOG IN' : 'CREATE AN ACCOUNT',
                            icon: Icons.auto_awesome_rounded,
                            tone: SwipessCtaTone.mexican,
                            loading: _isLoading,
                            onPressed: _isLoading ? null : _handleSubmit,
                          ),
                          const SizedBox(height: 16),
                          SwipessCtaButton(
                            label: _isLogin ? 'CREATE AN ACCOUNT' : 'LOG IN',
                            tone: SwipessCtaTone.ghost,
                            onPressed: () {
                              AppHaptics.light();
                              setState(() {
                                _isLogin = !_isLogin;
                                _passwordController.clear();
                              });
                            },
                          ),

                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(color: Colors.transparent),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Text(
                                  'or',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(128),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(color: Colors.transparent),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Social buttons
                          _buildSocialButton(
                            icon: Icons.apple_rounded,
                            label: 'CONTINUE WITH APPLE',
                            onTap: _isLoading
                                ? () {}
                                : () => _handleOAuth(OAuthProvider.apple),
                          ),
                          if (_showGoogleSignIn) ...[
                            const SizedBox(height: 16),
                            _buildSocialButton(
                              icon: Icons.g_mobiledata_rounded,
                              label: 'CONTINUE WITH GOOGLE',
                              onTap: _isLoading
                                  ? () {}
                                  : () => _handleOAuth(OAuthProvider.google),
                            ),
                          ],
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
  }) {
    return GlassTextField(
      controller: controller,
      hint: hint,
      icon: icon,
      obscureText: obscureText,
      onToggleObscure: isPassword ? onTogglePassword : null,
      keyboardType: keyboardType,
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SwipessCtaButton(
      label: label,
      icon: icon,
      tone: SwipessCtaTone.white,
      onPressed: onTap,
    );
  }
}
