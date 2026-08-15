import re

with open('lib/src/features/auth/presentation/screens/auth_screen.dart', 'r') as f:
    content = f.read()

# Add AppNotificationsProvider import
if 'app_notification_provider.dart' not in content:
    content = content.replace(
        "import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';",
        "import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';\nimport 'package:flutter_swipes/src/core/providers/app_notification_provider.dart';\nimport 'package:flutter_swipes/src/features/auth/presentation/providers/auth_controller.dart';"
    )

# Replace _handleOAuth
new_handleOAuth = """
  Future<void> _handleOAuth(OAuthProvider provider) async {
    setState(() => _isLoading = true);
    AppHaptics.medium();
    
    final success = await ref.read(authControllerProvider.notifier).loginWithOAuth(provider);
    if (!mounted) return;
    
    if (success) {
      context.go(AppPaths.clientDashboard);
    } else {
      final state = ref.read(authControllerProvider);
      if (state.hasError) {
        ref.read(appNotificationsProvider.notifier).error('Sign In Failed', state.error.toString());
      }
    }
    
    if (mounted) setState(() => _isLoading = false);
  }
"""
content = re.sub(r'Future<void> _handleOAuth\(OAuthProvider provider\) async \{.*?(?=\n  Future<void> _handleSubmit)', new_handleOAuth.strip(), content, flags=re.DOTALL)

# Replace _handleSubmit
new_handleSubmit = """
  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ref.read(appNotificationsProvider.notifier).error('Missing Information', 'Enter your email and password');
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
        ref.read(appNotificationsProvider.notifier).error('Authentication Failed', state.error.toString());
      }
    }
    
    if (mounted) setState(() => _isLoading = false);
  }
"""
content = re.sub(r'Future<void> _handleSubmit\(\) async \{.*?(?=\n  @override\n  Widget build)', new_handleSubmit.strip(), content, flags=re.DOTALL)

# Replace forgot password SnackBar
content = content.replace(
"""                                final messenger = ScaffoldMessenger.of(context);
                                if (email.isEmpty) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Enter your email first'),
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  await ref
                                      .read(authRepositoryProvider)
                                      .resetPassword(email);
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Reset link sent — open it to set a new password',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('$e')),
                                  );
                                }""",
"""                                if (email.isEmpty) {
                                  ref.read(appNotificationsProvider.notifier).error('Missing Email', 'Enter your email first');
                                  return;
                                }
                                final success = await ref.read(authControllerProvider.notifier).resetPassword(email);
                                if (!mounted) return;
                                if (success) {
                                  ref.read(appNotificationsProvider.notifier).success('Reset Link Sent', 'Open it to set a new password');
                                } else {
                                  final state = ref.read(authControllerProvider);
                                  ref.read(appNotificationsProvider.notifier).error('Reset Failed', state.error?.toString() ?? 'Could not send reset link');
                                }"""
)

with open('lib/src/features/auth/presentation/screens/auth_screen.dart', 'w') as f:
    f.write(content)
