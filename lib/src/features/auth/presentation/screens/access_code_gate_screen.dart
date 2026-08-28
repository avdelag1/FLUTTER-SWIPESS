import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/data/access_code_repository.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

import 'dart:ui';

import 'package:google_fonts/google_fonts.dart';

class AccessCodeGateScreen extends ConsumerStatefulWidget {
  const AccessCodeGateScreen({super.key});

  @override
  ConsumerState<AccessCodeGateScreen> createState() =>
      _AccessCodeGateScreenState();
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
  final _whatsappController = TextEditingController();
  final _messageController = TextEditingController();
  bool _requesting = false;
  String? _requestError;

  Future<void> _handleSubmit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter access code');
      try {
        AppHaptics.heavy();
      } catch (_) {}
      return;
    }
    setState(() {
      _error = null;
      _verifying = true;
    });

    final role = await ref.read(accessCodeRepositoryProvider).validate(code);
    if (!mounted) return;
    if (role != null) {
      try {
        await ref.read(accessGrantedProvider.notifier).grant(role: role);
        try {
          AppHaptics.light();
        } catch (_) {}
        if (!mounted) return;
        context.go(AppPaths.welcome);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _error = 'Could not save access. Try again.';
          _verifying = false;
        });
      }
      return;
    }

    try {
      AppHaptics.heavy();
    } catch (_) {}
    setState(() {
      _error = 'Invalid access code';
      _verifying = false;
    });
  }

  Future<void> _handleRequest() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _requesting = true;
      _requestError = null;
    });
    try {
      await ref
          .read(accessCodeRepositoryProvider)
          .requestAccess(
            name: _nameController.text,
            email: _emailController.text,
            whatsapp: _whatsappController.text,
            message: _messageController.text,
          );
      AppHaptics.light();
      if (mounted) setState(() => _submitted = true);
    } catch (_) {
      if (mounted) {
        setState(() => _requestError = 'Could not send request. Try again.');
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _messageController.dispose();
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
      crossAxisAlignment: isDesktop
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        SwipessLogo(
          height: isDesktop ? 56 : 48,
          variant: SwipessLogoVariant.transparent,
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
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _buildStoreButton(Icons.apple, 'App Store'),
            _buildStoreButton(Icons.android, 'Google Play'),
          ],
        ),
      ],
    );
  }

  Widget _buildStoreButton(IconData icon, String storeName) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(150),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coming soon',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withAlpha(160),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                storeName,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGateCard() {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: const Color(0xFF15171C).withAlpha(kIsWeb ? 255 : 180),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withAlpha(20), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(180),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
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
        Text(
          'Enter Access Code',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Authorized access only',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withAlpha(160),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 32),
        _buildCodeInput(),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
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
    return TextField(
      controller: _codeController,
      obscureText: !_revealed,
      textCapitalization: TextCapitalization.characters,
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
      decoration: InputDecoration(
        hintText: 'ENTER ACCESS CODE',
        hintStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white.withAlpha(115),
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        filled: true,
        fillColor: Colors.white.withAlpha(15),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: Colors.white.withAlpha(180),
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _revealed
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
          ),
          color: Colors.white.withAlpha(180),
          iconSize: 20,
          onPressed: () => setState(() => _revealed = !_revealed),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: Colors.white.withAlpha(30), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: Colors.white.withAlpha(30), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Colors.white, width: 1),
        ),
      ),
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      onSubmitted: (_) => _handleSubmit(),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _verifying ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFFFF4D00),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          elevation: 12,
          shadowColor: const Color(0xFFFF4D00).withAlpha(100),
        ),
        child: _verifying
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Enter',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
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
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(20), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _showRequest
                    ? 'Hide request form'
                    : "Don't have a code? Request one",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              _showRequest
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withAlpha(50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Request sent successfully!',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'We will reach out to you soon.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withAlpha(150),
                  fontSize: 14,
                ),
              ),
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
          color: Colors.black.withAlpha(80),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(20), width: 1),
        ),
        child: Column(
          children: [
            Text(
              'Request Access',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'We will review and send your code within 24h',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white.withAlpha(150),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            _buildInput(_nameController, 'Your full name *'),
            const SizedBox(height: 12),
            _buildInput(_emailController, 'Email address *', isEmail: true),
            const SizedBox(height: 12),
            _buildInput(_whatsappController, 'WhatsApp (optional)'),
            const SizedBox(height: 12),
            _buildInput(_messageController, 'Message (optional)'),
            if (_requestError != null) ...[
              const SizedBox(height: 10),
              Text(
                _requestError!,
                style: const TextStyle(color: Color(0xFFF87171), fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _requesting ? null : _handleRequest,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFFFF4D00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _requesting ? 'Sending…' : 'Submit Request',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String hint, {
    bool isEmail = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white.withAlpha(150),
          fontSize: 14,
        ),
        filled: true,
        fillColor: Colors.white.withAlpha(15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withAlpha(30), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withAlpha(30), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 1),
        ),
      ),
    );
  }
}
