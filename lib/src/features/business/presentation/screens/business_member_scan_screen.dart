import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/business/domain/business_visit.dart';
import 'package:flutter_swipes/src/features/business/presentation/providers/business_workspace_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BusinessMemberScanScreen extends ConsumerStatefulWidget {
  const BusinessMemberScanScreen({super.key});

  @override
  ConsumerState<BusinessMemberScanScreen> createState() =>
      _BusinessMemberScanScreenState();
}

class _BusinessMemberScanScreenState
    extends ConsumerState<BusinessMemberScanScreen> {
  late final MobileScannerController _scanner;
  final _manual = TextEditingController();
  final _total = TextEditingController();
  final _description = TextEditingController();

  BusinessVisit? _visit;
  bool _processing = false;
  bool _saving = false;
  String? _error;
  double _discount = 0;

  @override
  void initState() {
    super.initState();
    _scanner = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _scanner.dispose();
    _manual.dispose();
    _total.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _scan(String payload) async {
    final clean = payload.trim();
    if (clean.isEmpty || _processing || _visit != null) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      await _scanner.stop();
      final visit = await ref
          .read(businessWorkspaceRepositoryProvider)
          .scanMember(clean);
      if (!mounted) return;
      final preferred = visit.premiumActive
          ? visit.discountTiers.firstWhere(
              (value) => value >= 15,
              orElse: () => visit.discountTiers.last,
            )
          : 0.0;
      setState(() {
        _visit = visit;
        _discount = preferred;
        _processing = false;
      });
      ref.invalidate(businessWorkspaceProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = _friendlyError(error);
      });
      await _scanner.start();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing || _visit != null) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _scan(value);
        return;
      }
    }
  }

  Future<void> _saveTransaction() async {
    final visit = _visit;
    final total = double.tryParse(_total.text.trim());
    if (visit == null || total == null || total <= 0 || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(businessWorkspaceRepositoryProvider)
          .recordTransaction(
            scanId: visit.scanId,
            totalAmount: total,
            discountPercentage: _discount,
            description: _description.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved · customer pays ${_money(result.customerPays)} · commission ${_money(result.commissionAmount)}',
          ),
        ),
      );
      ref.invalidate(businessWorkspaceProvider);
      await _resetForNext();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendPromo() async {
    final visit = _visit;
    if (visit == null || _discount <= 0 || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final code = await ref
          .read(businessWorkspaceRepositoryProvider)
          .sendPromo(
            userId: visit.userId,
            discountPercentage: _discount,
            title: 'Come back soon',
            message:
                '${visit.name}, enjoy ${_percent(_discount)} off on your next visit.',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            code == null
                ? 'Promo sent to ${visit.name}.'
                : 'Promo $code sent to ${visit.name}.',
          ),
        ),
      );
      ref.invalidate(businessWorkspaceProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetForNext() async {
    _manual.clear();
    _total.clear();
    _description.clear();
    if (mounted) {
      setState(() {
        _visit = null;
        _discount = 0;
        _error = null;
        _processing = false;
      });
    }
    await _scanner.start();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ink = isLight ? const Color(0xFF111318) : Colors.white;
    final muted = isLight
        ? const Color(0xFF626A75)
        : Colors.white.withAlpha(165);

    return Scaffold(
      backgroundColor: AppTheme.canvasFor(isLight: isLight),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BUSINESS VALIDATION',
                          style: GoogleFonts.plusJakartaSans(
                            color: muted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                          ),
                        ),
                        Text(
                          'Scan SWIPESS Local ID',
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.qr_code_scanner_rounded),
                ],
              ),
            ),
            Expanded(
              child: _visit == null
                  ? _scannerBody(isLight: isLight, ink: ink, muted: muted)
                  : _visitBody(
                      visit: _visit!,
                      isLight: isLight,
                      ink: ink,
                      muted: muted,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scannerBody({
    required bool isLight,
    required Color ink,
    required Color muted,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: _scanner, onDetect: _onDetect),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withAlpha(150),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
                if (_processing)
                  ColoredBox(
                    color: Colors.black.withAlpha(150),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Text(
                    'Point the camera at the QR on the member’s SWIPESS Local ID.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      shadows: const [Shadow(blurRadius: 8)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: muted.withAlpha(60))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR ENTER QR / UUID',
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(child: Divider(color: muted.withAlpha(60))),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _manual,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: _scan,
          decoration: InputDecoration(
            hintText: 'Paste SWIPESS QR link or member UUID',
            suffixIcon: IconButton(
              tooltip: 'Validate',
              onPressed: _processing ? null : () => _scan(_manual.text),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _visitBody({
    required BusinessVisit visit,
    required bool isLight,
    required Color ink,
    required Color muted,
  }) {
    final tiers = visit.discountTiers;
    final total = double.tryParse(_total.text.trim()) ?? 0;
    final discountAmount = total * _discount / 100;
    final customerPays = total - discountAmount;
    final commission = customerPays * visit.commissionRate / 100;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isLight ? Colors.white : AppTheme.dashGlassStrong,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isLight
                  ? Colors.black.withAlpha(18)
                  : Colors.white.withAlpha(28),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: ink.withAlpha(20),
                backgroundImage: visit.avatarUrl == null
                    ? null
                    : NetworkImage(visit.avatarUrl!),
                child: visit.avatarUrl == null
                    ? Text(
                        visit.name.isEmpty ? 'S' : visit.name[0].toUpperCase(),
                        style: TextStyle(
                          color: ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            visit.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: ink,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (visit.verified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF36D17C),
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [visit.occupation, visit.city, visit.country]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join(' · '),
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    if (visit.premiumActive) ...[
                      const SizedBox(height: 6),
                      Text(
                        visit.premiumName ?? visit.premiumTier ?? 'Premium',
                        style: const TextStyle(
                          color: Color(0xFFFF4D00),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Visits',
                value: '${visit.visitsTotal}',
                isLight: isLight,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                label: 'Spent',
                value: _money(visit.grossSpendTotal),
                isLight: isLight,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                label: 'Saved',
                value: _money(visit.discountSavedTotal),
                isLight: isLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'TRANSACTION',
          style: GoogleFonts.plusJakartaSans(
            color: muted,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _total,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Receipt total',
            prefixText: r'$ ',
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<double>(
          initialValue: tiers.contains(_discount) ? _discount : 0,
          decoration: const InputDecoration(labelText: 'Member discount'),
          items: [
            for (final tier in tiers)
              DropdownMenuItem(value: tier, child: Text(_percent(tier))),
          ],
          onChanged: _saving
              ? null
              : (value) => setState(() => _discount = value ?? 0),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _description,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Order description (optional)',
          ),
        ),
        if (total > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.black.withAlpha(5)
                  : Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _previewRow('Discount', '-${_money(discountAmount)}', muted),
                _previewRow('Customer pays', _money(customerPays), ink),
                _previewRow('SWIPESS commission', _money(commission), muted),
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: total > 0 && !_saving ? _saveTransaction : null,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.receipt_long_rounded),
          label: const Text('SAVE TRANSACTION'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _discount > 0 && !_saving ? _sendPromo : null,
          icon: const Icon(Icons.card_giftcard_rounded),
          label: Text(
            _discount > 0
                ? 'SEND ${_percent(_discount)} RETURN PROMO'
                : 'SELECT A DISCOUNT TO SEND PROMO',
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _saving ? null : _resetForNext,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('SCAN NEXT MEMBER'),
        ),
      ],
    );
  }

  static Widget _previewRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: color))),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  static String _money(double value) =>
      NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(value);

  static String _percent(double value) {
    final text = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return '$text%';
  }

  static String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('Invalid SWIPESS Local ID QR')) {
      return 'That QR is not a SWIPESS Local ID.';
    }
    if (text.contains('member not found') || text.contains('unavailable')) {
      return 'This SWIPESS member could not be validated.';
    }
    if (text.contains('Discount is not enabled')) {
      return 'That discount is not enabled for this business.';
    }
    if (text.contains('Active business workspace required')) {
      return 'Your Business workspace is not active.';
    }
    return 'Could not complete this Business action. Try again.';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.isLight,
  });

  final String label;
  final String value;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : AppTheme.dashGlassStrong,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLight ? Colors.black.withAlpha(16) : Colors.white.withAlpha(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
