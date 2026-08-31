import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/pulsing_verified_badge.dart';
import 'package:flutter_swipes/src/features/profile/data/repositories/vap_id_repository.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class VapValidateScreen extends ConsumerStatefulWidget {
  const VapValidateScreen({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<VapValidateScreen> createState() => _VapValidateScreenState();
}

class _VapValidateScreenState extends ConsumerState<VapValidateScreen> {
  late final TextEditingController _id;
  late final MobileScannerController _scannerController;

  VapIdCard? _data;
  bool _loading = false;
  bool _lookedUp = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _id = TextEditingController(text: widget.userId ?? '');
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
    if (widget.userId != null && widget.userId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookup());
    }
  }

  @override
  void dispose() {
    _id.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    var id = _id.text.trim();
    if (id.isEmpty) return;

    if (id.startsWith('https://swipess.com/vap-validate/')) {
      id = id.replaceAll('https://swipess.com/vap-validate/', '');
    }
    if (id.toUpperCase().startsWith('NX-')) id = id.substring(3);

    setState(() {
      _loading = true;
      _lookedUp = true;
      _error = null;
    });

    try {
      final row = await ref.read(vapIdRepositoryProvider).lookupResident(id);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _data = row;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not verify this ID.';
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_loading || _lookedUp) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;
      _id.text = value;
      _lookup();
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _data != null;
    return Scaffold(
      body: AmbientPageBackground(
        fill: true,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                child: Row(
                  children: [
                    const CapBackButton(),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'VALIDATE ID',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!_lookedUp && !_loading)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(
                            controller: _scannerController,
                            onDetect: _onDetect,
                          ),
                          CustomPaint(painter: _ScannerOverlayPainter()),
                          Positioned(
                            bottom: 24,
                            left: 24,
                            right: 24,
                            child: Text(
                              'Scan a Swipess Virtual ID QR',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withAlpha(200),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                flex: _lookedUp || _loading ? 1 : 0,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                  children: [
                    if (!_lookedUp && !_loading) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(height: 1, color: Colors.white24),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR ENTER ID MANUALLY',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(height: 1, color: Colors.white24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _id,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Virtual ID (e.g. NX-ABC123)',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withAlpha(10),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.white24,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.white24,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _lookup(),
                      ),
                      const SizedBox(height: 16),
                      BrandPrimaryButton(
                        label: 'Verify ID',
                        onPressed: _lookup,
                      ),
                    ],
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.white24,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else if (_error != null)
                      NeoNaiveCard(
                        inkStamp: true,
                        child: Column(
                          children: [
                            const PulsingVerifiedBadge(valid: false),
                            const SizedBox(height: 20),
                            Text(
                              'Could not verify this ID.',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            BrandPrimaryButton(
                              label: 'Try again',
                              onPressed: () {
                                setState(() {
                                  _lookedUp = false;
                                  _error = null;
                                  _id.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      )
                    else if (_lookedUp && valid) ...[
                      _ValidCard(data: _data!),
                      const SizedBox(height: 24),
                      BrandPrimaryButton(
                        label: 'Scan Another',
                        onPressed: () {
                          setState(() {
                            _lookedUp = false;
                            _data = null;
                            _id.clear();
                          });
                        },
                      ),
                    ] else if (_lookedUp) ...[
                      const _InvalidCard(),
                      const SizedBox(height: 24),
                      BrandPrimaryButton(
                        label: 'Scan Another',
                        onPressed: () {
                          setState(() {
                            _lookedUp = false;
                            _id.clear();
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withAlpha(120)
      ..style = PaintingStyle.fill;
    final cutoutWidth = size.width * 0.7;
    final cutoutHeight = size.width * 0.7;
    final cutoutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cutoutWidth,
      height: cutoutHeight,
    );
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cutoutRect, const Radius.circular(24)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    final cornerPaint = Paint()
      ..color = const Color(0xFFFF4D00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const cornerLength = 32.0;
    canvas.drawLine(
      Offset(cutoutRect.left, cutoutRect.top + cornerLength),
      Offset(cutoutRect.left, cutoutRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cutoutRect.left, cutoutRect.top),
      Offset(cutoutRect.left + cornerLength, cutoutRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cutoutRect.right - cornerLength, cutoutRect.top),
      Offset(cutoutRect.right, cutoutRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cutoutRect.right, cutoutRect.top),
      Offset(cutoutRect.right, cutoutRect.top + cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cutoutRect.left, cutoutRect.bottom - cornerLength),
      Offset(cutoutRect.left, cutoutRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cutoutRect.left, cutoutRect.bottom),
      Offset(cutoutRect.left + cornerLength, cutoutRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cutoutRect.right - cornerLength, cutoutRect.bottom),
      Offset(cutoutRect.right, cutoutRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cutoutRect.right, cutoutRect.bottom),
      Offset(cutoutRect.right, cutoutRect.bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ValidCard extends StatelessWidget {
  const _ValidCard({required this.data});
  final VapIdCard data;

  @override
  Widget build(BuildContext context) {
    final since = data.createdAt != null
        ? DateFormat.yMMMM().format(data.createdAt!)
        : 'Unknown';
    return NeoNaiveCard(
      inkStamp: true,
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
      child: Column(
        children: [
          const PulsingVerifiedBadge(),
          const SizedBox(height: 22),
          Text(
            'Valid Local Resident',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This Swipess Virtual ID is active.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(102),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(label: 'Name', value: data.displayName),
                if (data.occupation?.isNotEmpty == true)
                  _Field(label: 'Occupation', value: data.occupation!),
                if (data.locationLabel.isNotEmpty)
                  _Field(label: 'Location', value: data.locationLabel),
                _Field(label: 'Member Since', value: since),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Discounts at participating locations apply. ID provided by Swipess.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvalidCard extends StatelessWidget {
  const _InvalidCard();

  @override
  Widget build(BuildContext context) {
    return NeoNaiveCard(
      inkStamp: true,
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
      child: Column(
        children: [
          const PulsingVerifiedBadge(valid: false),
          const SizedBox(height: 22),
          Text(
            'Invalid ID',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This Swipess Virtual ID is not recognized or has expired.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
