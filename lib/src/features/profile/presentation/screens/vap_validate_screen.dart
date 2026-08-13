import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/pulsing_verified_badge.dart';
import 'package:flutter_swipes/src/features/profile/data/repositories/vap_id_repository.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Cap `VapValidate` — pulsing verified badge + resident details.
class VapValidateScreen extends ConsumerStatefulWidget {
  const VapValidateScreen({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<VapValidateScreen> createState() => _VapValidateScreenState();
}

class _VapValidateScreenState extends ConsumerState<VapValidateScreen> {
  late final TextEditingController _id;
  VapIdCard? _data;
  bool _loading = false;
  bool _lookedUp = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _id = TextEditingController(text: widget.userId ?? '');
    if (widget.userId != null && widget.userId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookup());
    }
  }

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    var id = _id.text.trim();
    if (id.toUpperCase().startsWith('NX-')) {
      id = id.substring(3);
    }
    if (id.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
      _lookedUp = true;
    });
    try {
      final row = await ref.read(vapIdRepositoryProvider).lookupResident(id);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _data = row;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not verify this ID.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _data != null;
    return Scaffold(
      body: AmbientPageBackground(
        fill: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.chevron_left_rounded,
                          color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.verified_user_rounded,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'SWIPESS RESIDENT PORTAL',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 16),
            TextField(
              controller: _id,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'User id…',
                hintStyle: TextStyle(color: Colors.transparent),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white, width: 1),
                ),
              ),
            ),
            const SizedBox(height: 28),
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
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      BrandPrimaryButton(label: 'Try again', onPressed: _lookup),
                    ],
                  ),
                )
              else if (_lookedUp && valid)
                _ValidCard(data: _data!)
              else if (_lookedUp)
                const _InvalidCard(),
            ],
          ),
        ),
      ),
    );
  }
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
            'This Virtual Residency ID is active.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white54),
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
              color: Colors.white38,
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
            'This Virtual Residency ID is not recognized or has expired.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(color: Colors.white54),
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
              color: Colors.white38,
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
