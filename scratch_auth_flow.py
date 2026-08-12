import os

PROJECT_ROOT = "/Users/alejandrovillarreal/Documents/FUTTER SWIPESS"

app_router_path = os.path.join(PROJECT_ROOT, "lib/src/core/routing/app_router.dart")
gate_path = os.path.join(PROJECT_ROOT, "lib/src/features/auth/presentation/screens/access_code_gate_screen.dart")
welcome_path = os.path.join(PROJECT_ROOT, "lib/src/features/auth/presentation/screens/welcome_screen.dart")
auth_path = os.path.join(PROJECT_ROOT, "lib/src/features/auth/presentation/screens/auth_screen.dart")
login_path = os.path.join(PROJECT_ROOT, "lib/src/features/auth/presentation/screens/login_screen.dart")

gate_content = """import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

class AccessCodeGateScreen extends ConsumerStatefulWidget {
  const AccessCodeGateScreen({super.key});

  @override
  ConsumerState<AccessCodeGateScreen> createState() => _AccessCodeGateScreenState();
}

class _AccessCodeGateScreenState extends ConsumerState<AccessCodeGateScreen> {
  final _codeController = TextEditingController();
  bool _revealed = false;
  String? _error;
  bool _verifying = false;
  bool _showRequest = false;
  bool _submitted = false;
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  void _handleSubmit() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter access code');
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() {
      _error = null;
      _verifying = true;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '') == 'URDBEST') {
        HapticFeedback.lightImpact();
        context.go('/welcome');
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _error = 'Invalid access code';
          _verifying = false;
        });
      }
    });
  }

  void _handleRequest() {
    if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty) return;
    setState(() => _submitted = true);
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 900;
              if (isDesktop) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 64.0),
                        child: _buildAdBlock(isDesktop),
                      ),
                    ),
                    _buildGateCard(),
                  ],
                );
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAdBlock(isDesktop),
                  const SizedBox(height: 48),
                  _buildGateCard(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAdBlock(bool isDesktop) {
    return Column(
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          'SWIPESS',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: isDesktop ? 64 : 48,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'The exclusive ecosystem for visionaries.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: isDesktop ? 42 : 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Discover trusted properties, luxury experiences, and high-end services. All one swipe away. Join the private network today.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: Colors.white.withAlpha(200),
            fontSize: isDesktop ? 18 : 16,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(40)),
              ),
              alignment: Alignment.center,
              child: const Text('Download on the App Store', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildGateCard() {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withAlpha(25), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(100), blurRadius: 40, offset: const Offset(0, 20)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.lock_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter Access Code',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'Authorized access only',
                  style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 32),
                _buildCodeInput(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
                const SizedBox(height: 16),
                _buildSubmitButton(),
                const SizedBox(height: 24),
                Divider(color: Colors.white.withAlpha(25), height: 1),
                const SizedBox(height: 16),
                _buildRequestAccessToggle(),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showRequest ? _buildRequestForm() : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeInput() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(76)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(Icons.lock_outline_rounded, color: Colors.white.withAlpha(180), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _codeController,
              obscureText: !_revealed,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 2),
              decoration: InputDecoration(
                hintText: 'ENTER ACCESS CODE',
                hintStyle: TextStyle(color: Colors.white.withAlpha(115), fontWeight: FontWeight.w600, letterSpacing: 0),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),
          IconButton(
            icon: Icon(_revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            color: Colors.white.withAlpha(180),
            iconSize: 20,
            onPressed: () => setState(() => _revealed = !_revealed),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _verifying ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          elevation: 8,
          shadowColor: Colors.black.withAlpha(100),
        ),
        child: _verifying
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Enter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }

  Widget _buildRequestAccessToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showRequest = !_showRequest),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(25)),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: Colors.white.withAlpha(25), shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _showRequest ? 'Hide request form' : "Don't have a code? Request one",
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(
              _showRequest ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withAlpha(180),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestForm() {
    if (_submitted) {
      return Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(50),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(12)),
          ),
          child: Column(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: Colors.greenAccent.withAlpha(50), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.greenAccent),
              ),
              const SizedBox(height: 12),
              const Text('Request sent successfully!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('We will reach out to you soon.', style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(12)),
        ),
        child: Column(
          children: [
            const Text('Request Access', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('We will review and send your code within 24h', style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12)),
            const SizedBox(height: 16),
            _buildInput(_nameController, 'Your full name *'),
            const SizedBox(height: 12),
            _buildInput(_emailController, 'Email address *', isEmail: true),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _handleRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Submit Request', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, {bool isEmail = false}) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(76)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
"""

welcome_content = """import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Wordmark
                    const Text(
                      'SWIPESS',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 64),
                    
                    // Buttons
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          context.push('/auth?mode=login');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(color: Colors.white.withAlpha(230), width: 2),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login_rounded, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'SIGN IN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          context.push('/auth?mode=signup');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'CREATE ACCOUNT',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'or swipe logo to enter →',
                      style: TextStyle(
                        color: Colors.white.withAlpha(150),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Terms of Service',
                      style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12),
                    ),
                  ),
                  Text(
                    '•',
                    style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Privacy Policy',
                      style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
"""

auth_content = """import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

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

  void _handleSubmit() {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    
    // Simulate network request
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.go('/dashboard');
    });
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
"""

app_router_content = """import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/access_code_gate_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/welcome_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/auth_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/dashboard_shell.dart';
import 'package:flutter_swipes/src/features/events/presentation/screens/event_detail_screen.dart';
import 'package:flutter_swipes/src/features/messages/presentation/screens/chat_room_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/access',
    routes: [
      GoRoute(
        path: '/access',
        builder: (context, state) => const AccessCodeGateScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'] ?? 'login';
          return AuthScreen(mode: mode);
        },
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardShell(),
      ),
      GoRoute(
        path: '/events/:id',
        builder: (context, state) {
          final eventId = state.pathParameters['id']!;
          return EventDetailScreen(eventId: eventId);
        },
      ),
      GoRoute(
        path: '/messages/:id',
        builder: (context, state) {
          final roomId = state.pathParameters['id']!;
          return ChatRoomScreen(roomId: roomId);
        },
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return AppRouter.router;
});
"""

# Write files
with open(gate_path, "w") as f:
    f.write(gate_content)

with open(welcome_path, "w") as f:
    f.write(welcome_content)
    
with open(auth_path, "w") as f:
    f.write(auth_content)
    
with open(app_router_path, "w") as f:
    f.write(app_router_content)

# Delete old login_screen.dart if it exists
if os.path.exists(login_path):
    os.remove(login_path)

print("Auth refactor complete.")
