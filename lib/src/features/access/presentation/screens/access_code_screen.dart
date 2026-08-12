import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/session/session_controller.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/core/widgets/starfield_background.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_logo.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor `AccessCodeGate` — private network entry.
class AccessCodeScreen extends ConsumerStatefulWidget {
  const AccessCodeScreen({super.key});

  @override
  ConsumerState<AccessCodeScreen> createState() => _AccessCodeScreenState();
}

class _AccessCodeScreenState extends ConsumerState<AccessCodeScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _messageController = TextEditingController();

  bool _revealed = false;
  bool _verifying = false;
  bool _success = false;
  bool _showRequest = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;
  String? _submitError;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final candidate = _codeController.text.trim();
    if (candidate.isEmpty) {
      setState(() => _error = 'Enter access code');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;

    final normalized = candidate.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    // Design preview: same local override as Capacitor. Real validation is a bases task.
    if (normalized != 'URDBEST') {
      setState(() {
        _verifying = false;
        _error = 'Invalid access code';
      });
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _verifying = false;
      _success = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    ref.read(sessionProvider.notifier).grantAccess();
    context.go('/welcome');
  }

  Future<void> _submitRequest() async {
    if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitted = true;
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const StarfieldBackground(),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: _success
                  ? const _SuccessBurst(key: ValueKey('success'))
                  : _buildGate(key: const ValueKey('gate')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGate({Key? key}) {
    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final panel = _AccessPanel(
          codeController: _codeController,
          nameController: _nameController,
          emailController: _emailController,
          whatsappController: _whatsappController,
          messageController: _messageController,
          revealed: _revealed,
          verifying: _verifying,
          showRequest: _showRequest,
          submitting: _submitting,
          submitted: _submitted,
          error: _error,
          submitError: _submitError,
          onToggleReveal: () => setState(() => _revealed = !_revealed),
          onCodeChanged: (_) => setState(() => _error = null),
          onVerify: _verify,
          onToggleRequest: () => setState(() => _showRequest = !_showRequest),
          onSubmitRequest: _submitRequest,
        );

        if (wide) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Row(
                  children: [
                    const Expanded(child: _AccessHero(alignStart: true)),
                    const SizedBox(width: 48),
                    Expanded(child: panel),
                  ],
                ),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
          child: Column(
            children: [
              const _AccessHero(alignStart: false),
              const SizedBox(height: 32),
              panel,
            ],
          ),
        );
      },
    );
  }
}

class _AccessHero extends StatelessWidget {
  const _AccessHero({required this.alignStart});

  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    final align = alignStart ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = alignStart ? TextAlign.left : TextAlign.center;
    return Column(
      crossAxisAlignment: align,
      children: [
        const SwipessLogo(height: 72, variant: SwipessLogoVariant.outline),
        const SizedBox(height: 28),
        Text(
          'The exclusive ecosystem for visionaries.',
          textAlign: textAlign,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 32,
            height: 1.15,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Discover trusted properties, luxury experiences, and high-end services. All one swipe away. Join the private network today.',
          textAlign: textAlign,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xD9FFFFFF),
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _AccessPanel extends StatelessWidget {
  const _AccessPanel({
    required this.codeController,
    required this.nameController,
    required this.emailController,
    required this.whatsappController,
    required this.messageController,
    required this.revealed,
    required this.verifying,
    required this.showRequest,
    required this.submitting,
    required this.submitted,
    required this.error,
    required this.submitError,
    required this.onToggleReveal,
    required this.onCodeChanged,
    required this.onVerify,
    required this.onToggleRequest,
    required this.onSubmitRequest,
  });

  final TextEditingController codeController;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController whatsappController;
  final TextEditingController messageController;
  final bool revealed;
  final bool verifying;
  final bool showRequest;
  final bool submitting;
  final bool submitted;
  final String? error;
  final String? submitError;
  final VoidCallback onToggleReveal;
  final ValueChanged<String> onCodeChanged;
  final VoidCallback onVerify;
  final VoidCallback onToggleRequest;
  final VoidCallback onSubmitRequest;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppTheme.gatePanelDecoration,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.lock_outline, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'Enter Access Code',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Authorized access only',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xA6FFFFFF),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 22),
            GlassTextField(
              controller: codeController,
              hint: 'Enter access code',
              icon: Icons.lock_outline,
              obscureText: !revealed,
              onToggleObscure: onToggleReveal,
              textCapitalization: TextCapitalization.characters,
              errorText: error,
              onChanged: onCodeChanged,
              autofocus: true,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: verifying ? null : onVerify,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: verifying ? Colors.black45 : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      verifying ? 'Verifying...' : 'Enter',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(color: Color(0x1AFFFFFF), height: 1),
            ),
            _RequestToggle(
              expanded: showRequest,
              onTap: onToggleRequest,
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: _RequestForm(
                nameController: nameController,
                emailController: emailController,
                whatsappController: whatsappController,
                messageController: messageController,
                submitting: submitting,
                submitted: submitted,
                submitError: submitError,
                onSubmit: onSubmitRequest,
              ),
              crossFadeState:
                  showRequest ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 240),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestToggle extends StatelessWidget {
  const _RequestToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x0DFFFFFF),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0x1AFFFFFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  expanded ? 'Hide request form' : "Don't have a code? Request one",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(Icons.keyboard_arrow_down, color: Color(0xB3FFFFFF)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestForm extends StatelessWidget {
  const _RequestForm({
    required this.nameController,
    required this.emailController,
    required this.whatsappController,
    required this.messageController,
    required this.submitting,
    required this.submitted,
    required this.submitError,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController whatsappController;
  final TextEditingController messageController;
  final bool submitting;
  final bool submitted;
  final String? submitError;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x33000000),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x0DFFFFFF)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: submitted
              ? Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0x3334D399),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Color(0xFF34D399)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Request sent successfully!',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "We'll reach out to you soon.",
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0x99FFFFFF),
                        fontSize: 13,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Text(
                      'Request Access',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "We'll review and send your code within 24h",
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0x99FFFFFF),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassTextField(
                      controller: nameController,
                      hint: 'Your full name *',
                      height: 48,
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: emailController,
                      hint: 'Email address *',
                      keyboardType: TextInputType.emailAddress,
                      height: 48,
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: whatsappController,
                      hint: 'WhatsApp (optional)',
                      keyboardType: TextInputType.phone,
                      height: 48,
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: messageController,
                      hint: 'How did you hear about us? (optional)',
                      height: 72,
                    ),
                    if (submitError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        submitError!,
                        style: const TextStyle(color: Color(0xFFF87171), fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: submitting ? null : onSubmit,
                        child: submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Submit Request',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SuccessBurst extends StatelessWidget {
  const _SuccessBurst({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x1AFFFFFF),
          border: Border.fromBorderSide(BorderSide(color: Color(0x80FFFFFF), width: 2)),
        ),
        child: SizedBox(
          width: 80,
          height: 80,
          child: Icon(Icons.check, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
