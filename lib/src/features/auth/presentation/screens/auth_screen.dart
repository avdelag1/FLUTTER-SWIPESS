import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/auth/data/auth_repository.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final String mode;
  const AuthScreen({super.key, required this.mode});

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

  Future<void> _handleSubmit() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    
    final repo = ref.read(authRepositoryProvider);
    try {
      if (_isLogin) {
        await repo.signInWithEmailPassword(_emailController.text, _passwordController.text);
      } else {
        await repo.signUpWithEmailPassword(_emailController.text, _passwordController.text);
      }
      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Back button
            Positioned(
              top: 16,
              left: 16,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(38),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(64)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
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
                      const SizedBox(height: 64),
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
                        onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
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
                                    onChanged: (val) => setState(() => _rememberMe = val ?? false),
                                    fillColor: WidgetStateProperty.resolveWith((states) => 
                                      states.contains(WidgetState.selected) ? AppTheme.brandPrimary : Colors.transparent
                                    ),
                                    side: BorderSide(color: Colors.white.withAlpha(128)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('Remember me', style: TextStyle(color: Colors.white, fontSize: 14)),
                              ],
                            ),
                            TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Forgot password?', style: TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                          ],
                        ),
                      
                      const SizedBox(height: 32),
                      
                      // Primary action button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isLogin ? AppTheme.brandPrimary : AppTheme.dashWell,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                                  _isLogin ? 'LOG IN' : 'CREATE AN ACCOUNT',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Toggle mode button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _isLogin = !_isLogin;
                              _passwordController.clear();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isLogin ? AppTheme.dashWell : AppTheme.brandPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            elevation: 0,
                          ),
                          child: Text(
                            _isLogin ? 'CREATE AN ACCOUNT' : 'LOG IN',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.white.withAlpha(50))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('or', style: TextStyle(color: Colors.white.withAlpha(128))),
                          ),
                          Expanded(child: Divider(color: Colors.white.withAlpha(50))),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      // Social buttons
                      _buildSocialButton(
                        icon: Icons.apple_rounded,
                        label: 'CONTINUE WITH APPLE',
                        onTap: () {},
                      ),
                      const SizedBox(height: 16),
                      _buildSocialButton(
                        icon: Icons.g_mobiledata_rounded, // Placeholder for Google icon
                        label: 'CONTINUE WITH GOOGLE',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(76)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(icon, color: Colors.white.withAlpha(180), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.white.withAlpha(153), fontSize: 16, fontWeight: FontWeight.w500),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (isPassword) ...[
            IconButton(
              icon: Icon(obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              color: Colors.white.withAlpha(180),
              iconSize: 20,
              onPressed: onTogglePassword,
            ),
            const SizedBox(width: 4),
          ] else ...[
            const SizedBox(width: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: const BorderSide(color: Colors.transparent),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
