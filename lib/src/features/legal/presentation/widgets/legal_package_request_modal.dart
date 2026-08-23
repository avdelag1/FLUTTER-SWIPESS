import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/legal/domain/legal_service_package.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/legal_providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cap `LegalPackageRequestModal`.
Future<void> showLegalPackageRequestModal(
  BuildContext context, {
  required LegalServicePackage pkg,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LegalPackageRequestSheet(pkg: pkg),
  );
}

class _LegalPackageRequestSheet extends ConsumerStatefulWidget {
  const _LegalPackageRequestSheet({required this.pkg});
  final LegalServicePackage pkg;

  @override
  ConsumerState<_LegalPackageRequestSheet> createState() =>
      _LegalPackageRequestSheetState();
}

class _LegalPackageRequestSheetState
    extends ConsumerState<_LegalPackageRequestSheet> {
  final _situation = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  String _contact = 'phone';
  late String _type;
  bool _loading = false;
  bool _success = false;
  String? _error;

  bool get _isDocument => widget.pkg.id.startsWith('contract-');

  @override
  void initState() {
    super.initState();
    _type = _isDocument ? 'custom_quote' : 'request';
    final user = Supabase.instance.client.auth.currentUser;
    _email.text = user?.email ?? '';
    if (user != null) {
      ref
          .read(legalRepositoryProvider)
          .fetchProfilePrefill(user.id, user.email)
          .then((p) {
            if (!mounted) return;
            setState(() {
              if (p.fullName.isNotEmpty) _name.text = p.fullName;
              if (p.email.isNotEmpty) _email.text = p.email;
              if (p.phone.isNotEmpty) _phone.text = p.phone;
            });
          });
    }
  }

  @override
  void dispose() {
    _situation.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _error = 'Sign in to request legal help.');
      return;
    }
    if (_situation.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      setState(() => _error = 'Situation and phone are required.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(legalRepositoryProvider)
          .submitPackageRequest(
            userId: user.id,
            packageId: widget.pkg.id,
            packageName: widget.pkg.name,
            packageCategory: widget.pkg.category,
            quotedPrice: widget.pkg.price,
            situation: _situation.text.trim(),
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            preferredContact: _contact,
            requestType: _type,
          );
      AppHaptics.medium();
      if (mounted) setState(() => _success = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not submit request. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF121218),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        child: SingleChildScrollView(child: _success ? _done() : _form()),
      ),
    );
  }

  Widget _done() {
    return Column(
      children: [
        const SizedBox(height: 12),
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF34D399),
          size: 56,
        ),
        const SizedBox(height: 16),
        Text(
          'REQUEST SENT',
          style: AppTheme.displayItalic.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 8),
        Text(
          'A provider will confirm scope, jurisdiction and a quote before any engagement.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Text(
              'DONE',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.pkg.name.toUpperCase(),
          style: AppTheme.displayItalic.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 4),
        Text(
          widget.pkg.description ?? 'Confirm the details for this request.',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _chip('Request', _type == 'request', () {
              if (_isDocument) return;
              setState(() => _type = 'request');
            }),
            const SizedBox(width: 8),
            _chip(
              'Custom quote',
              _type == 'custom_quote',
              () => setState(() => _type = 'custom_quote'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _field(_situation, 'Your situation *', maxLines: 4),
        const SizedBox(height: 10),
        _field(_name, 'Full name'),
        const SizedBox(height: 10),
        _field(_email, 'Email', email: true),
        const SizedBox(height: 10),
        _field(_phone, 'Phone *', phone: true),
        const SizedBox(height: 14),
        Text(
          'PREFERRED CONTACT',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final opt in const [
              ('phone', 'Phone Call'),
              ('whatsapp', 'WhatsApp'),
              ('email', 'Email'),
            ])
              _chip(
                opt.$2,
                _contact == opt.$1,
                () => setState(() => _contact = opt.$1),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF87171)),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'SUBMIT REQUEST',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool on, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: on ? Colors.black : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint, {
    int maxLines = 1,
    bool email = false,
    bool phone = false,
  }) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: email
          ? TextInputType.emailAddress
          : phone
          ? TextInputType.phone
          : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white),
        filled: true,
        fillColor: const Color(0xFF1A1A22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
