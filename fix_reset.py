with open('lib/src/features/auth/presentation/screens/reset_password_screen.dart', 'r') as f:
    content = f.read()

content = content.replace("import 'package:supabase_flutter/supabase_flutter.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:flutter_swipes/src/features/auth/presentation/providers/auth_controller.dart';\nimport 'package:flutter_swipes/src/core/providers/app_notification_provider.dart';")
content = content.replace("class ResetPasswordScreen extends StatefulWidget", "class ResetPasswordScreen extends ConsumerStatefulWidget")
content = content.replace("State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();", "ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();")
content = content.replace("class _ResetPasswordScreenState extends State<ResetPasswordScreen>", "class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen>")

new_submit = """
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
    
    final success = await ref.read(authControllerProvider.notifier).updatePassword(_password.text);
    if (!mounted) return;
    
    if (success) {
      ref.read(appNotificationsProvider.notifier).success('Password Updated', 'Your password has been changed');
      context.go('/welcome');
    } else {
      final state = ref.read(authControllerProvider);
      setState(() => _error = state.error?.toString() ?? 'Update failed');
    }
    
    if (mounted) setState(() => _busy = false);
  }
"""

import re
content = re.sub(r'Future<void> _submit\(\) async \{.*?(?=\n  @override\n  Widget build)', new_submit.strip(), content, flags=re.DOTALL)

with open('lib/src/features/auth/presentation/screens/reset_password_screen.dart', 'w') as f:
    f.write(content)
