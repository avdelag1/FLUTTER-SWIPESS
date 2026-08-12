import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/features/legal/data/repositories/contract_repository.dart';
import 'package:flutter_swipes/src/features/legal/domain/digital_contract.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/contracts_provider.dart';
import 'package:flutter_swipes/src/features/legal/presentation/widgets/finger_signature_pad.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:signature/signature.dart';

class ContractSignScreen extends ConsumerStatefulWidget {
  const ContractSignScreen({super.key, required this.contract});

  final DigitalContract contract;

  @override
  ConsumerState<ContractSignScreen> createState() => _ContractSignScreenState();
}

class _ContractSignScreenState extends ConsumerState<ContractSignScreen> {
  late final SignatureController _pad;
  bool _signing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pad = SignatureController(
      penStrokeWidth: 3,
      penColor: const Color(0xFFEB4898),
      exportBackgroundColor: const Color(0x00000000),
    );
    _pad.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contract = widget.contract;
    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      appBar: AppBar(
        title: Text(contract.title, style: AppTheme.displayItalic.copyWith(fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withAlpha(25)),
            ),
            child: Text(
              contract.content?.trim().isNotEmpty == true
                  ? contract.content!
                  : 'Review this contract, then sign with your finger.',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white.withAlpha(220),
                height: 1.5,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('YOUR SIGNATURE', style: AppTheme.displayItalic.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          FingerSignaturePad(controller: _pad),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Color(0xFFF87171))),
          ],
          const SizedBox(height: 16),
          BrandPrimaryButton(
            label: _signing ? 'Signing...' : 'Sign contract',
            loading: _signing,
            onPressed: !_pad.isNotEmpty || _signing ? null : _sign,
          ),
        ],
      ),
    );
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
      await ref.read(contractRepositoryProvider).sign(
            contract: widget.contract,
            signatureData: dataUrl,
          );
      await ref.read(contractsProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signature saved')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }
}
