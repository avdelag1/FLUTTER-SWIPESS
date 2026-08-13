import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

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

  Future<void> _handleSubmit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter access code');
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}
      return;
    }
    setState(() {
      _error = null;
      _verifying = true;
    });

    final normalized =
        code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (normalized == 'URDBEST') {
      try {
        await ref.read(accessGrantedProvider.notifier).grant();
        try {
          HapticFeedback.lightImpact();
        } catch (_) {}
        if (!mounted) return;
        context.go(AppPaths.welcome);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = 'Could not save access. Try again.';
          _verifying = false;
        });
      }
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
    setState(() {
      _error = 'Invalid access code';
      _verifying = false;
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
      body: Stack(
        children: [
          Center(
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
        ],
      ),
    );
  }

  Widget _buildAdBlock(bool isDesktop) {
    return Column(
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SwipessLogo(
          height: isDesktop ? 56 : 48,
          variant: SwipessLogoVariant.outline,
        ),
        const SizedBox(height: 24),
        Text(
          'The exclusive ecosystem for visionaries.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: isDesktop ? 42 : 28,
            fontWeight: FontWeight.w800,
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
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 1.5),
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
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.transparent, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(100), blurRadius: 40, offset: const Offset(0, 20)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        // BackdropFilter + WebGL loss freezes Chrome; skip blur on web.
        child: kIsWeb
            ? Padding(
                padding: const EdgeInsets.all(32.0),
                child: _buildGateCardBody(),
              )
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: _buildGateCardBody(),
                ),
              ),
      ),
    );
  }

  Widget _buildGateCardBody() {
    return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
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
                Divider(color: Colors.transparent, height: 1),
                const SizedBox(height: 16),
                _buildRequestAccessToggle(),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showRequest ? _buildRequestForm() : const SizedBox.shrink(),
                ),
              ],
    );
  }

  Widget _buildCodeInput() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
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
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: Colors.transparent, shape: BoxShape.circle),
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
            border: Border.all(color: Colors.white, width: 1.5),
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
          border: Border.all(color: Colors.white, width: 1.5),
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
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.5),
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
