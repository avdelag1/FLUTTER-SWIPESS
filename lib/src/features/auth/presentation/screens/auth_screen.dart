import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
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
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  bool get _passwordLongEnough => _passwordController.text.length >= 8;
  bool get _passwordsMatch =>
      _confirmPasswordController.text.isNotEmpty &&
      _passwordController.text == _confirmPasswordController.text;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.mode != 'signup';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
      return;
    }

    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      final notice = _noticeForAuthError(
        state.error.toString(),
        isLogin: true,
        provider: provider,
      );
      ref
          .read(appNotificationsProvider.notifier)
          .error(notice.title, notice.message);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty) {
      _notifyError('Email Needed', 'Enter the email for this account.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _notifyError(
        'Check Your Email',
        'That email address does not look complete.',
      );
      return;
    }
    if (password.isEmpty) {
      _notifyError('Password Needed', 'Enter your password to continue.');
      return;
    }
    if (!_isLogin && password.length < 8) {
      _notifyError(
        'Password Not Ready',
        'Use at least 8 characters before creating the account.',
      );
      return;
    }
    if (!_isLogin && confirmPassword.isEmpty) {
      _notifyError(
        'Confirm Your Password',
        'Type your password one more time to make sure it is correct.',
      );
      return;
    }
    if (!_isLogin && password != confirmPassword) {
      _notifyError(
        'Passwords Do Not Match',
        'The two passwords are different. Re-enter them and try again.',
      );
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
      return;
    }

    final state = ref.read(authControllerProvider);
    final rawError =
        state.error?.toString() ?? 'We could not complete that request.';

    if (_requiresEmailConfirmation(rawError)) {
      if (mounted) setState(() => _isLoading = false);
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => EmailConfirmationScreen(email: email),
        ),
      );
      return;
    }

    final notice = _noticeForAuthError(rawError, isLogin: _isLogin);
    ref
        .read(appNotificationsProvider.notifier)
        .error(notice.title, notice.message);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _notifyError(
        'Email Needed',
        'Enter your email first so we know where to send the reset link.',
      );
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _notifyError('Check Your Email', 'Enter a valid email address first.');
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(email);
    if (!mounted) return;

    if (success) {
      ref
          .read(appNotificationsProvider.notifier)
          .success(
            'Reset Link Sent',
            'Check your inbox and open the secure link to set a new password.',
          );
      return;
    }

    final state = ref.read(authControllerProvider);
    final notice = _noticeForAuthError(
      state.error?.toString() ?? 'Could not send the reset link.',
      isLogin: true,
    );
    ref
        .read(appNotificationsProvider.notifier)
        .error('Reset Failed', notice.message);
  }

  void _toggleMode() {
    AppHaptics.light();
    setState(() {
      _isLogin = !_isLogin;
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  void _notifyError(String title, String message) {
    ref.read(appNotificationsProvider.notifier).error(title, message);
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
                      onTap: () => NavBack.popOrGo(
                        context,
                        fallbackPath: AppPaths.welcome,
                      ),
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
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 54, 24, 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: SwipessLogo(
                              width: 196,
                              variant: SwipessLogoVariant.transparent,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _isLogin ? 'Welcome back' : 'Create your account',
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
                                ? 'Sign in and keep swiping.'
                                : 'One account. Everything Swipess.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withAlpha(140),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (!_isLogin) ...[
                            _buildInput(
                              controller: _nameController,
                              hint: 'Full Name',
                              icon: Icons.person_outline_rounded,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 12),
                          ],
                          _buildInput(
                            controller: _emailController,
                            hint: 'Email Address',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          _buildInput(
                            controller: _passwordController,
                            hint: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            isPassword: true,
                            textInputAction: _isLogin
                                ? TextInputAction.done
                                : TextInputAction.next,
                            onChanged: (_) {
                              if (!_isLogin) setState(() {});
                            },
                            onSubmitted: (_) {
                              if (!_isLoading && _isLogin) _handleSubmit();
                            },
                            onTogglePassword: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          if (!_isLogin) ...[
                            const SizedBox(height: 12),
                            _buildInput(
                              controller: _confirmPasswordController,
                              hint: 'Confirm Password',
                              icon: Icons.lock_reset_rounded,
                              obscureText: _obscurePassword,
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) {
                                if (!_isLoading) _handleSubmit();
                              },
                              onTogglePassword: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _PasswordRequirement(
                              ready: _passwordLongEnough,
                              label: '8+ characters',
                            ),
                            const SizedBox(height: 6),
                            _PasswordRequirement(
                              ready: _passwordsMatch,
                              label: 'Passwords match',
                            ),
                          ],
                          if (_isLogin) ...[
                            const SizedBox(height: 12),
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
                                      (states) =>
                                          states.contains(WidgetState.selected)
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
                                  onPressed: _isLoading ? null : _resetPassword,
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
                          const SizedBox(height: 22),
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
                                  color: Colors.white.withAlpha(90),
                                  width: 1.1,
                                ),
                                shape: const StadiumBorder(),
                                backgroundColor: Colors.white.withAlpha(7),
                              ),
                              child: Text(
                                _isLogin
                                    ? 'CREATE AN ACCOUNT'
                                    : 'I ALREADY HAVE AN ACCOUNT',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withAlpha(32),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Text(
                                  'or continue with',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(110),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withAlpha(32),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _ProviderButton(
                            label: 'Continue with Apple',
                            icon: const Icon(
                              Icons.apple_rounded,
                              color: Colors.black,
                              size: 24,
                            ),
                            onPressed: _isLoading
                                ? null
                                : () => _handleOAuth(OAuthProvider.apple),
                          ),
                          const SizedBox(height: 10),
                          _ProviderButton(
                            label: 'Continue with Google',
                            icon: const _GoogleGMark(),
                            onPressed: _isLoading
                                ? null
                                : () => _handleOAuth(OAuthProvider.google),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'By continuing, you agree to Swipess Terms and Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withAlpha(85),
                              fontSize: 10.5,
                              height: 1.35,
                            ),
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
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
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
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      height: 54,
    );
  }
}

class EmailConfirmationScreen extends ConsumerWidget {
  const EmailConfirmationScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          const StarfieldBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Column(
                    children: [
                      const SwipessLogo(
                        width: 180,
                        variant: SwipessLogoVariant.transparent,
                      ),
                      const SizedBox(height: 30),
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.brandPrimary,
                              Color(0xFFFF4F8B),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.brandPrimary.withAlpha(80),
                              blurRadius: 34,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mark_email_read_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Check your inbox',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your Swipess account was created. Tap the confirmation link in your email, then come back and sign in.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withAlpha(165),
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (email.trim().isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withAlpha(48),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.alternate_email_rounded,
                                size: 16,
                                color: Colors.white.withAlpha(150),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _maskedEmail(email),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withAlpha(35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lightbulb_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No email yet? Check Spam or Promotions. The confirmation message can take a moment to arrive.',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(150),
                                  height: 1.4,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: () {
                            AppHaptics.medium();
                            context.go('${AppPaths.auth}?mode=login');
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.brandPrimary,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text(
                            'GO TO SIGN IN',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => context.go(AppPaths.welcome),
                        child: Text(
                          'Back to welcome',
                          style: TextStyle(
                            color: Colors.white.withAlpha(150),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordRequirement extends StatelessWidget {
  const _PasswordRequirement({required this.ready, required this.label});

  final bool ready;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = ready
        ? const Color(0xFF67E8A5)
        : Colors.white.withAlpha(105);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Icon(
              ready ? Icons.check_circle_rounded : Icons.circle_outlined,
              key: ValueKey(ready),
              color: color,
              size: 15,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: const Color(0xFF1F1F1F),
          backgroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withAlpha(180),
          disabledForegroundColor: Colors.black54,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: StadiumBorder(
            side: BorderSide(
              color: Colors.black.withAlpha(28),
              width: 1,
            ),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(width: 24, height: 24, child: icon),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleGMark extends StatelessWidget {
  const _GoogleGMark();

  static const _svg = '''
<svg width="48" height="48" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">
  <path fill="#FFC107" d="M43.611 20H42V20H24v8h11.303C33.65 32.657 29.223 36 24 36c-6.627 0-12-5.373-12-12s5.373-12 12-12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 12.955 4 4 12.955 4 24s8.955 20 20 20 20-8.955 20-20c0-1.341-.138-2.65-.389-4z"/>
  <path fill="#FF3D00" d="M6.306 14.691l6.571 4.819C14.655 15.108 18.961 12 24 12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4c-7.682 0-14.344 4.337-17.694 10.691z"/>
  <path fill="#4CAF50" d="M24 44c5.166 0 9.86-1.977 13.409-5.192l-6.19-5.238C29.211 35.091 26.715 36 24 36c-5.202 0-9.616-3.317-11.283-7.946l-6.522 5.025C9.505 39.556 16.227 44 24 44z"/>
  <path fill="#1976D2" d="M43.611 20H42V20H24v8h11.303c-.793 2.237-2.231 4.166-4.087 5.571l6.19 5.238C36.971 39.205 44 34 44 24c0-1.341-.138-2.65-.389-4z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(_svg, width: 22, height: 22);
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

class _AuthNotice {
  const _AuthNotice(this.title, this.message);

  final String title;
  final String message;
}

bool _requiresEmailConfirmation(String raw) {
  final text = raw.toLowerCase();
  return text.contains('check your email to confirm') ||
      text.contains('email not confirmed') ||
      text.contains('email_not_confirmed');
}

_AuthNotice _noticeForAuthError(
  String raw, {
  required bool isLogin,
  OAuthProvider? provider,
}) {
  final text = raw
      .replaceAll('Exception: ', '')
      .replaceAll('AuthException(message: ', '')
      .replaceAll(RegExp(r', statusCode:.*$'), '')
      .trim();
  final lower = text.toLowerCase();

  if (lower.contains('invalid login credentials') ||
      lower.contains('invalid_credentials') ||
      lower.contains('wrong password')) {
    return const _AuthNotice(
      'Could Not Sign In',
      'The email or password is incorrect. Check both and try again.',
    );
  }
  if (lower.contains('user already registered') ||
      lower.contains('already registered') ||
      lower.contains('already exists')) {
    return const _AuthNotice(
      'Account Already Exists',
      'That email already has a Swipess account. Sign in instead.',
    );
  }
  if (lower.contains('password') &&
      (lower.contains('weak') ||
          lower.contains('least') ||
          lower.contains('short'))) {
    return const _AuthNotice(
      'Password Not Ready',
      'Use a stronger password with at least 8 characters.',
    );
  }
  if (lower.contains('rate limit') ||
      lower.contains('too many requests') ||
      lower.contains('over_email_send_rate_limit')) {
    return const _AuthNotice(
      'Too Many Attempts',
      'Give it a moment, then try again.',
    );
  }
  if (lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('connection')) {
    return const _AuthNotice(
      'Connection Problem',
      'Check your internet connection and try again.',
    );
  }
  if (lower.contains('popup') || lower.contains('pop-up')) {
    return _AuthNotice(
      'Allow the Sign-In Window',
      text.isEmpty
          ? 'Allow pop-ups for Swipess and try again.'
          : text,
    );
  }
  if (lower.contains('provider') &&
      (lower.contains('disabled') || lower.contains('not enabled'))) {
    final label = provider == OAuthProvider.apple
        ? 'Apple'
        : provider == OAuthProvider.google
        ? 'Google'
        : 'This provider';
    return _AuthNotice(
      '$label Sign-In Unavailable',
      '$label sign-in is not available right now. Use email and password instead.',
    );
  }
  if (lower.contains('banned') ||
      lower.contains('disabled') ||
      lower.contains('unavailable')) {
    return const _AuthNotice(
      'Account Unavailable',
      'This account cannot sign in right now. Contact support if you need help.',
    );
  }

  return _AuthNotice(
    isLogin ? 'Could Not Sign In' : 'Could Not Create Account',
    text.isEmpty ? 'Something went wrong. Try again.' : text,
  );
}

String _maskedEmail(String email) {
  final trimmed = email.trim();
  final at = trimmed.indexOf('@');
  if (at <= 1) return trimmed;
  final local = trimmed.substring(0, at);
  final domain = trimmed.substring(at);
  final visible = local.length <= 2 ? 1 : 2;
  final hidden = List<String>.filled(local.length - visible, '•').join();
  return '${local.substring(0, visible)}$hidden$domain';
}
