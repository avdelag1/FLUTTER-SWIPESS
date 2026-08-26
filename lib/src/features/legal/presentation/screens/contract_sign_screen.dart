import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/legal/data/contract_export_service.dart';
import 'package:flutter_swipes/src/features/legal/data/repositories/contract_repository.dart';
import 'package:flutter_swipes/src/features/legal/data/saved_signature_store.dart';
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
  bool _exporting = false;
  bool _useSavedSignature = false;
  bool _saveForNextTime = true;
  String? _savedSignature;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contract = widget.contract;
    _pad = SignatureController(
      penStrokeWidth: 4,
      penColor: const Color(0xFF1E3A8A), // Deep ink blue
      exportBackgroundColor: const Color(0x00000000),
    );
    _pad.addListener(_onPadChanged);
    _refresh();
    _loadSavedSignature();
  }

  void _onPadChanged() {
    if (!mounted) return;
    setState(() {
      if (_pad.isNotEmpty) _useSavedSignature = false;
    });
  }

  @override
  void dispose() {
    _pad.removeListener(_onPadChanged);
    _pad.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSignature() async {
    final saved = await SavedSignatureStore.load();
    if (!mounted) return;
    setState(() {
      _savedSignature = saved;
      _useSavedSignature = saved != null;
    });
  }

  Future<void> _refresh() async {
    try {
      final fresh = await ref
          .read(contractRepositoryProvider)
          .fetchById(_contract.id);
      if (mounted) setState(() => _contract = fresh);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final hairline = MatteSurface.hairline(context);
    final top = MediaQuery.paddingOf(context).top;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final needsSignature = userId != null && _contract.needsSignature(userId);
    final canSign =
        _reviewed &&
        !_signing &&
        ((_useSavedSignature && _savedSignature != null) || _pad.isNotEmpty);

    return Scaffold(
      body: AmbientPageBackground(
        fill: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, top + 14, 20, 60),
          children: [
            Row(
              children: [
                const CapBackButton(),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _contract.isCompleted
                        ? const Color(0xFF22C55E).withAlpha(24)
                        : MatteSurface.cardFill(context),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: hairline),
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
              'SWIPESS SIGN',
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
                const Icon(
                  Icons.lock_rounded,
                  size: 15,
                  color: AppTheme.brandPrimary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'This exact version is locked. The server verifies the document fingerprint again when a signature is submitted.',
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
                border: Border.all(color: hairline),
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exporting ? null : () => _export('pdf'),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
                    label: const Text('PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exporting ? null : () => _export('word'),
                    icon: const Icon(Icons.description_rounded, size: 17),
                    label: const Text('WORD'),
                  ),
                ),
              ],
            ),
            if (_contract.documentHash != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MatteSurface.cardFill(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: hairline),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.fingerprint_rounded,
                      color: AppTheme.brandPrimary,
                    ),
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
                onChanged: (value) =>
                    setState(() => _reviewed = value ?? false),
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
              const SizedBox(height: 10),
              if (_savedSignature != null) ...[
                Text(
                  'SAVED SIGNATURE',
                  style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 9),
                GestureDetector(
                  onTap: () => setState(() => _useSavedSignature = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _useSavedSignature
                          ? AppTheme.brandAccent.withAlpha(18)
                          : MatteSurface.cardFill(context),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _useSavedSignature
                            ? AppTheme.brandAccent
                            : hairline,
                        width: _useSavedSignature ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 105,
                          width: double.infinity,
                          child: Image.memory(
                            _decodeSignature(_savedSignature!),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                'Saved signature',
                                style: TextStyle(color: muted),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _useSavedSignature
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: _useSavedSignature
                                  ? AppTheme.brandAccent
                                  : muted,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _useSavedSignature
                                    ? 'READY TO USE'
                                    : 'USE SAVED SIGNATURE',
                                style: GoogleFonts.plusJakartaSans(
                                  color: ink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _forgetSavedSignature,
                              child: const Text('Forget'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: hairline)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'OR DRAW A NEW ONE',
                        style: GoogleFonts.plusJakartaSans(
                          color: muted,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: hairline)),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'SIGNATURE PAD',
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 10),
              FingerSignaturePad(
                controller: _pad,
                onClear: () => setState(() {}),
              ),
              if (_pad.isNotEmpty)
                CheckboxListTile(
                  value: _saveForNextTime,
                  onChanged: (value) =>
                      setState(() => _saveForNextTime = value ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppTheme.brandAccent,
                  title: Text(
                    'Save this signature on this device for next time',
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
              const SizedBox(height: 12),
              BrandPrimaryButton(
                label: _signing ? 'Signing…' : 'Sign this version',
                icon: Icons.verified_user_rounded,
                loading: _signing,
                onPressed: canSign ? _sign : null,
              ),
              const SizedBox(height: 8),
              Text(
                'A saved signature is only a convenience on this device. Swipess still records a new contract signature event each time you sign.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: muted.withAlpha(145),
                  fontSize: 9,
                  height: 1.4,
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _contract.isCompleted
                      ? const Color(0xFF22C55E).withAlpha(18)
                      : MatteSurface.cardFill(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: hairline),
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

  Uint8List _decodeSignature(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    final payload = comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl;
    return base64Decode(payload);
  }

  String _shortHash(String hash) {
    if (hash.length <= 28) return hash;
    return '${hash.substring(0, 14)}…${hash.substring(hash.length - 14)}';
  }

  Future<void> _export(String format) async {
    final content = _contract.content?.trim() ?? '';
    if (content.isEmpty || _exporting) return;
    setState(() => _exporting = true);
    try {
      if (format == 'pdf') {
        await ContractExportService.sharePdf(
          title: _contract.title,
          content: content,
        );
      } else {
        await ContractExportService.shareWord(
          title: _contract.title,
          content: content,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export document: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _forgetSavedSignature() async {
    await SavedSignatureStore.clear();
    if (!mounted) return;
    setState(() {
      _savedSignature = null;
      _useSavedSignature = false;
    });
  }

  Future<String> _capturePadSignature() async {
    final image = await _pad.toImage();
    if (image == null) throw Exception('Draw your signature first');
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw Exception('Could not capture signature');
    return 'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}';
  }

  Future<void> _sign() async {
    setState(() {
      _signing = true;
      _error = null;
    });
    try {
      String dataUrl;
      if (_useSavedSignature && _savedSignature != null) {
        dataUrl = _savedSignature!;
      } else {
        dataUrl = await _capturePadSignature();
        if (_saveForNextTime) {
          await SavedSignatureStore.save(dataUrl);
          if (mounted) setState(() => _savedSignature = dataUrl);
        }
      }

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
