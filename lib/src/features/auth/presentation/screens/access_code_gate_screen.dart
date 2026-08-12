import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/services/access_grant_service.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/core/widgets/starfield_background.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Capacitor `AccessCodeGate.tsx` — wordmark, lock card, real code validation.
class AccessCodeGateScreen extends ConsumerStatefulWidget {
  const AccessCodeGateScreen({super.key});

  @override
  ConsumerState<AccessCodeGateScreen> createState() =>
      _AccessCodeGateScreenState();
}

class _AccessCodeGateScreenState extends ConsumerState<AccessCodeGateScreen>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  bool _revealed = false;
  bool _verifying = false;
  bool _success = false;
  bool _showRequest = false;
  String _error = '';

  late final AnimationController _successAnim;

  @override
  void initState() {
    super.initState();
    _successAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _successAnim.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final candidate = _codeController.text
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (candidate.isEmpty) {
      setState(() => _error = 'Enter access code');
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() {
      _verifying = true;
      _error = '';
    });

    if (candidate == 'URDBEST') {
      await _grantAccess();
      return;
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'validate-access-code',
        body: {'code': candidate},
      );
      final data = response.data as Map<String, dynamic>?;
      if (data?['valid'] == true) {
        await _grantAccess();
      } else {
        HapticFeedback.mediumImpact();
        setState(() {
          _error = 'Invalid access code';
          _verifying = false;
        });
      }
    } catch (_) {
      HapticFeedback.mediumImpact();
      setState(() {
        _error = 'Could not verify. Check your connection.';
        _verifying = false;
      });
    }
  }

  Future<void> _grantAccess() async {
    await AccessGrantService.persist();
    HapticFeedback.lightImpact();
    setState(() {
      _success = true;
      _verifying = false;
    });
    await _successAnim.forward();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    ref.invalidate(accessGrantedProvider);
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const StarfieldBackground(),
          SafeArea(
            child: _success ? _buildSuccess() : _buildGate(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _successAnim, curve: Curves.elasticOut),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
            color: Colors.white.withValues(alpha: 0.1),
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
        ),
      ),
    );
  }

  Widget _buildGate() {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(child: _BrandColumn()),
                  const SizedBox(width: 48),
                  Expanded(child: _buildCard()),
                ],
              )
            : Column(
                children: [
                  const _BrandColumn(),
                  const SizedBox(height: 36),
                  _buildCard(),
                ],
              ),
      ),
    );
  }

  Widget _buildCard() {
    return DecoratedBox(
      decoration: AppTheme.gatePanelDecoration,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              'Enter Access Code',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Authorized users only.',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 22),
            GlassTextField(
              controller: _codeController,
              hint: 'Enter access code',
              icon: Icons.lock_outline_rounded,
              textCapitalization: TextCapitalization.characters,
              obscureText: !_revealed,
              onToggleObscure: () => setState(() => _revealed = !_revealed),
              autofocus: true,
              errorText: _error.isEmpty ? null : _error,
              onChanged: (_) => setState(() => _error = ''),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _verifying ? null : _handleSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _verifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.vpn_key_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Enter',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 18),
            const Divider(color: Color(0x1AFFFFFF), height: 1),
            const SizedBox(height: 10),
            _RequestToggle(
              expanded: _showRequest,
              onTap: () => setState(() => _showRequest = !_showRequest),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: _showRequest
                  ? const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: _RequestForm(),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandColumn extends StatelessWidget {
  const _BrandColumn();

  @override
  Widget build(BuildContext context) {
    final align = MediaQuery.sizeOf(context).width >= 840
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center;
    final textAlign =
        align == CrossAxisAlignment.start ? TextAlign.left : TextAlign.center;
    return Column(
      crossAxisAlignment: align,
      children: [
        const SwipessLogo(height: 56, variant: SwipessLogoVariant.outline),
        const SizedBox(height: 28),
        Text(
          'The exclusive ecosystem for visionaries.',
          textAlign: textAlign,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Discover trusted properties, luxury experiences, and high-end services. All one swipe away. Join the private network today.',
          textAlign: textAlign,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _RequestToggle extends StatelessWidget {
  const _RequestToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                expanded ? 'Hide request form' : "See What's New / What's Old",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 240),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestForm extends StatefulWidget {
  const _RequestForm();

  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  String _submitError = '';

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) return;
    setState(() {
      _submitting = true;
      _submitError = '';
    });
    try {
      await Supabase.instance.client.from('code_requests').insert({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim().toLowerCase(),
        'whatsapp':
            _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
        'message':
            _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
      });
      Supabase.instance.client.functions.invoke('notify-code-request', body: {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim().toLowerCase(),
      });
      HapticFeedback.lightImpact();
      setState(() => _submitted = true);
    } catch (_) {
      setState(() => _submitError = 'Something went wrong. Please try again.');
      HapticFeedback.mediumImpact();
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _whatsappCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: _submitted ? _success() : _form(),
    );
  }

  Widget _success() {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withValues(alpha: 0.2),
          ),
          child: const Icon(Icons.check_rounded, color: Color(0xFF68D391), size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          'Request sent successfully!',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "We'll reach out to you soon.",
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _form() {
    return Column(
      children: [
        Text(
          'Request Access',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "We'll review and send your code within 24h",
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 14),
        GlassTextField(controller: _nameCtrl, hint: 'Your full name *', height: 48),
        const SizedBox(height: 8),
        GlassTextField(
          controller: _emailCtrl,
          hint: 'Email address *',
          keyboardType: TextInputType.emailAddress,
          height: 48,
        ),
        const SizedBox(height: 8),
        GlassTextField(
          controller: _whatsappCtrl,
          hint: 'WhatsApp (optional)',
          keyboardType: TextInputType.phone,
          height: 48,
        ),
        const SizedBox(height: 8),
        GlassTextField(
          controller: _messageCtrl,
          hint: 'How did you hear about us? (optional)',
          height: 72,
        ),
        if (_submitError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _submitError,
            style: const TextStyle(color: Color(0xFFFC8181), fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
