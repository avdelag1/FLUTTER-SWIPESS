import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/core/services/access_grant_service.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/login_screen.dart';

class AccessCodeGateScreen extends ConsumerStatefulWidget {
  const AccessCodeGateScreen({super.key});

  @override
  ConsumerState<AccessCodeGateScreen> createState() => _AccessCodeGateScreenState();
}

class _AccessCodeGateScreenState extends ConsumerState<AccessCodeGateScreen>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();

  bool _revealed = false;
  bool _verifying = false;
  bool _success = false;
  bool _showRequest = false;
  String _error = '';

  late AnimationController _successAnimController;
  late Animation<double> _successScaleAnim;

  @override
  void initState() {
    super.initState();
    _successAnimController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _successScaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _successAnimController, curve: Curves.elasticOut),
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    _successAnimController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final candidate = _codeController.text.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (candidate.isEmpty) {
      setState(() => _error = 'Enter access code');
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() { _verifying = true; _error = ''; });

    // Check hardcoded master key first (matches web app's URDBEST)
    if (candidate == 'URDBEST') {
      await _grantAccess();
      return;
    }

    // Verify via Supabase Edge Function
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
        setState(() { _error = 'Invalid access code'; _verifying = false; });
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
    setState(() { _success = true; _verifying = false; });
    await _successAnimController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated Background Orbs
          _buildBackgroundOrbs(),

          // Main Content
          SafeArea(
            child: _success ? _buildSuccessView() : _buildGateView(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundOrbs() {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -80,
          child: _Orb(color: AppTheme.brandPrimary.withAlpha(60), size: 300),
        ),
        Positioned(
          bottom: -100,
          left: -60,
          child: _Orb(color: AppTheme.brandAccent.withAlpha(50), size: 280),
        ),
        Positioned(
          top: 200,
          left: -40,
          child: _Orb(color: AppTheme.brandPrimary2.withAlpha(30), size: 200),
        ),
        // Glass blur overlay
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Container(color: Colors.transparent),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: ScaleTransition(
        scale: _successScaleAnim,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(128), width: 2),
            color: Colors.white.withAlpha(25),
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
        ),
      ),
    );
  }

  Widget _buildGateView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Logo / Brand
          _buildBrandHeader(),
          const SizedBox(height: 48),
          // Glass Card
          _buildGlassCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        // Brand gradient icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandPrimary.withAlpha(80),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.swipe_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 20),
        const Text(
          'Swipess',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The exclusive ecosystem for visionaries.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withAlpha(179),
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(13),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withAlpha(25), width: 1),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              // Lock Icon + Title
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withAlpha(20),
                ),
                child: Icon(Icons.lock_rounded, color: Colors.white.withAlpha(220), size: 22),
              ),
              const SizedBox(height: 14),
              const Text(
                'Enter Access Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Authorized access only',
                style: TextStyle(
                  color: Colors.white.withAlpha(165),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 24),

              // Code Input
              _buildCodeInput(),
              const SizedBox(height: 10),

              // Error message
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _error.isNotEmpty
                    ? Padding(
                        key: ValueKey(_error),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error,
                          style: const TextStyle(color: Color(0xFFFC8181), fontSize: 13, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('no-error')),
              ),

              // Enter Button
              _buildEnterButton(),

              const SizedBox(height: 20),
              Divider(color: Colors.white.withAlpha(25), thickness: 1),
              const SizedBox(height: 8),

              // Request Access toggle
              _buildRequestToggle(),

              // Request form
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _showRequest ? _buildRequestForm() : const SizedBox.shrink(),
              ),
            ],
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(76), width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(Icons.lock_outline_rounded, color: Colors.white.withAlpha(178), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _codeController,
              focusNode: _focusNode,
              obscureText: !_revealed,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'ACCESS CODE',
                hintStyle: TextStyle(
                  color: Colors.white.withAlpha(114),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              onSubmitted: (_) => _handleSubmit(),
              onChanged: (_) => setState(() => _error = ''),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _revealed = !_revealed),
            icon: Icon(
              _revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: Colors.white.withAlpha(178),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _verifying ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.white.withAlpha(178),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _verifying
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Enter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }

  Widget _buildRequestToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showRequest = !_showRequest),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(20), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(20),
              ),
              child: const Icon(Icons.message_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _showRequest ? 'Hide request form' : "Don't have a code? Request one",
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            AnimatedRotation(
              turns: _showRequest ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withAlpha(178), size: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestForm() {
    return _RequestForm(key: const ValueKey('request-form'));
  }
}

// ─── Request Form ─────────────────────────────────────────────────────────────

class _RequestForm extends StatefulWidget {
  const _RequestForm({super.key});

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
    setState(() { _submitting = true; _submitError = ''; });
    try {
      await Supabase.instance.client.from('code_requests').insert({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim().toLowerCase(),
        'whatsapp': _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
        'message': _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
      });
      // Fire notification in background
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
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _whatsappCtrl.dispose(); _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(51),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(13), width: 1),
      ),
      child: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.green.withAlpha(50)),
          child: const Icon(Icons.check_rounded, color: Color(0xFF68D391), size: 24),
        ),
        const SizedBox(height: 12),
        const Text('Request sent successfully!', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text("We'll reach out to you soon.", style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 13)),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Request Access', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text("We'll review and send your code within 24h", style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 11)),
        const SizedBox(height: 14),
        _RequestField(controller: _nameCtrl, hint: 'Your full name *'),
        const SizedBox(height: 8),
        _RequestField(controller: _emailCtrl, hint: 'Email address *', keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 8),
        _RequestField(controller: _whatsappCtrl, hint: 'WhatsApp (optional)', keyboardType: TextInputType.phone),
        const SizedBox(height: 8),
        _RequestField(controller: _messageCtrl, hint: 'How did you hear about us? (optional)', maxLines: 2),
        if (_submitError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_submitError, style: const TextStyle(color: Color(0xFFFC8181), fontSize: 12), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Submit Request', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _RequestField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final int maxLines;

  const _RequestField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(76), width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withAlpha(153), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

// ─── Animated Background Orb ──────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
