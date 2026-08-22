import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/legal/data/repositories/contract_repository.dart';
import 'package:flutter_swipes/src/features/legal/domain/digital_contract.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/contracts_provider.dart';
import 'package:flutter_swipes/src/features/legal/presentation/widgets/finger_signature_pad.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContractSignScreen extends ConsumerStatefulWidget {
  const ContractSignScreen({super.key, required this.contract});

  final DigitalContract contract;

  @override
  ConsumerState<ContractSignScreen> createState() => _ContractSignScreenState();
}

class _ContractSignScreenState extends ConsumerState<ContractSignScreen> {
  late final SignatureController _pad;
  late DigitalContract _contract;
  bool _reviewed = false;
  bool _signing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contract = widget.contract;
    _pad = SignatureController(
      penStrokeWidth: 3,
      penColor: const Color(0xFFEB4898),
      exportBackgroundColor: const Color(0x00000000),
    );
    _pad.addListener(() => setState(() {}));
    _refresh();
  }

  @override
  void dispose() {
    _pad.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final fresh = await ref.read(contractRepositoryProvider).fetchById(_contract.id);
      if (mounted) setState(() => _contract = fresh);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final top = MediaQuery.paddingOf(context).top;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final needsSignature = userId != null && _contract.needsSignature(userId);

    return Scaffold(
      body: AmbientPageBackground(
        fill: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, top + 14, 20, 50),
          children: [
            Row(
              children: [
                const CapBackButton(),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withAlpha(
                      _contract.isCompleted ? 24 : 0,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: MatteSurface.hairline(context)),
                  ),
                  child: Text(
                    _contract.compactStatusLabel,
                    style: GoogleFonts.plusJakartaSans(
                      color: _contract.isCompleted
                          ? const Color(0xFF22C55E)
                          : muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'SECURE SIGNATURE',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.brandPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _contract.title.toUpperCase(),
              style: AppTheme.displayItalic.copyWith(
                color: ink,
                fontSize: 30,
                height: 0.95,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.lock_rounded, size: 15, color: AppTheme.brandPrimary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'This exact document version is locked for signature. The server verifies its SHA-256 hash again when you sign.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 10,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: MatteSurface.cardFill(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: MatteSurface.hairline(context)),
              ),
              child: SelectableText(
                _contract.content?.trim().isNotEmpty == true
                    ? _contract.content!
                    : 'No document content is available.',
                style: GoogleFonts.sourceSerif4(
                  color: ink,
                  height: 1.55,
                  fontSize: 15,
                ),
              ),
            ),
            if (_contract.documentHash != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MatteSurface.cardFill(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: MatteSurface.hairline(context)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fingerprint_rounded, color: AppTheme.brandPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DOCUMENT FINGERPRINT · V${_contract.version}',
                            style: GoogleFonts.plusJakartaSans(
                              color: muted,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _shortHash(_contract.documentHash!),
                            style: GoogleFonts.robotoMono(
                              color: ink,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            if (needsSignature) ...[
              CheckboxListTile(
                value: _reviewed,
                onChanged: (value) => setState(() => _reviewed = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: AppTheme.brandPrimary,
                title: Text(
                  'I reviewed this document and intend to sign this exact version.',
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'DRAW YOUR SIGNATURE',
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 10),
              FingerSignaturePad(controller: _pad),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _pad.isEmpty ? null : _pad.clear,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Clear'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFF6B64),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              BrandPrimaryButton(
                label: _signing ? 'Signing…' : 'Sign this version',
                icon: Icons.verified_user_rounded,
                loading: _signing,
                onPressed: !_reviewed || !_pad.isNotEmpty || _signing ? null : _sign,
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _contract.isCompleted
                      ? const Color(0xFF22C55E).withAlpha(18)
                      : MatteSurface.cardFill(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: MatteSurface.hairline(context)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _contract.isCompleted
                          ? Icons.verified_rounded
                          : Icons.schedule_rounded,
                      color: _contract.isCompleted
                          ? const Color(0xFF22C55E)
                          : AppTheme.brandPrimary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _contract.isCompleted
                            ? 'Both parties have signed. This document is complete and retained in the Swipess audit trail.'
                            : 'Your signature is already recorded. The document is waiting for the other party.',
                        style: GoogleFonts.plusJakartaSans(
                          color: ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _shortHash(String hash) {
    if (hash.length <= 28) return hash;
    return '${hash.substring(0, 14)}…${hash.substring(hash.length - 14)}';
  }

  Future<void> _sign() async {
    setState(() {
      _signing = true;
      _error = null;
    });
    try {
      final image = await _pad.toImage();
      if (image == null) throw Exception('Draw your signature first');
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception('Could not capture signature');
      final dataUrl =
          'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}';
      final signed = await ref
          .read(contractRepositoryProvider)
          .sign(contract: _contract, signatureData: dataUrl);
      await ref.read(contractsProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => _contract = signed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            signed.isCompleted
                ? 'Document fully signed'
                : 'Signature recorded securely',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }
}
