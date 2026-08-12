import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Capacitor VapValidate — public-ish PEARL / resident verification lookup.
class VapValidateScreen extends ConsumerStatefulWidget {
  const VapValidateScreen({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<VapValidateScreen> createState() => _VapValidateScreenState();
}

class _VapValidateScreenState extends ConsumerState<VapValidateScreen> {
  late final TextEditingController _id;
  Map<String, dynamic>? _data;
  bool _loading = false;
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
    final id = _id.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final client = Supabase.instance.client;
      final row = await client
          .from('client_profiles')
          .select(
            'name, vap_city, city, country, vap_occupation, occupation, vap_nationality, created_at',
          )
          .eq('user_id', id)
          .maybeSingle();
      if (!mounted) return;
      if (row == null) {
        setState(() {
          _loading = false;
          _error = 'No authorized resident found for this TXID.';
        });
        return;
      }
      setState(() {
        _loading = false;
        _data = row;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not validate: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    'PEARL VALIDATE',
                    style: AppTheme.displayItalic.copyWith(fontSize: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Enter a resident user id / TXID to verify Authorized Resident status.',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _id,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'User id…',
                hintStyle: TextStyle(color: Colors.white.withAlpha(90)),
                filled: true,
                fillColor: Colors.white.withAlpha(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _lookup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _loading ? 'Validating…' : 'Validate resident',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF87171))),
            ],
            if (_data != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFAFAF9), Color(0xFFE7E5E4)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_rounded,
                            color: Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        Text(
                          'AUTHORIZED RESIDENT',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF525252),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ((_data!['name'] as String?) ?? 'Resident').toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        _data!['vap_occupation'] ?? _data!['occupation'],
                        _data!['vap_city'] ?? _data!['city'],
                        _data!['country'],
                      ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0x99000000),
                        fontWeight: FontWeight.w700,
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
}
