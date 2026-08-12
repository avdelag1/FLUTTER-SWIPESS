import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cap AdvertisePage — landing → form steps → success (IAP gated later).
class AdvertiseScreen extends ConsumerStatefulWidget {
  const AdvertiseScreen({super.key});

  @override
  ConsumerState<AdvertiseScreen> createState() => _AdvertiseScreenState();
}

class _AdvertiseScreenState extends ConsumerState<AdvertiseScreen> {
  int _step = 0; // 0 landing, 1 type, 2 details, 3 confirm, 4 success
  String _type = 'nightlife';
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  final _website = TextEditingController();
  final _date = TextEditingController();
  XFile? _cover;
  bool _submitting = false;
  String? _statusMessage;

  static const _types = [
    ('nightlife', 'Nightlife'),
    ('music', 'Music'),
    ('food', 'Food & Drink'),
    ('sports', 'Sports'),
    ('wellness', 'Wellness'),
    ('other', 'Other'),
  ];

  static const _packages = [
    ('starter', 'Starter', '1 event push', '\$49'),
    ('growth', 'Growth', '3 events + boost', '\$129'),
    ('premium', 'Premium', 'Unlimited month', '\$299'),
  ];

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    _website.dispose();
    _date.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('business_promo_submissions')
          .select('status, title')
          .eq('user_id', userId)
          .inFilter('status', ['approved', 'pending'])
          .order('created_at', ascending: false)
          .limit(1);
      if (!mounted) return;
      if ((rows as List).isNotEmpty) {
        final row = Map<String, dynamic>.from(rows.first as Map);
        setState(() {
          _statusMessage =
              'Latest: ${row['title'] ?? 'Promo'} · ${row['status']}';
        });
      }
    } catch (_) {}
  }

  Future<void> _pickCover() async {
    final file =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _cover = file);
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _submitting) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to submit a promo')),
      );
      return;
    }
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    try {
      String? imageUrl;
      if (_cover != null) {
        final bytes = await _cover!.readAsBytes();
        final path =
            '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage
            .from('event-images')
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        imageUrl = Supabase.instance.client.storage
            .from('event-images')
            .getPublicUrl(path);
      }

      final payload = <String, dynamic>{
        'user_id': userId,
        'event_type': _type,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'event_date': _date.text.trim().isEmpty ? null : _date.text.trim(),
        'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
        'contact_name': _contactName.text.trim().isEmpty
            ? null
            : _contactName.text.trim(),
        'contact_phone': _contactPhone.text.trim().isEmpty
            ? null
            : _contactPhone.text.trim(),
        'website':
            _website.text.trim().isEmpty ? null : _website.text.trim(),
        'image_url': imageUrl,
        'status': 'pending',
      }..removeWhere((_, v) => v == null);

      // Cap columns first; fall back to older promo_type shape.
      try {
        await Supabase.instance.client
            .from('business_promo_submissions')
            .insert(payload);
      } catch (_) {
        await Supabase.instance.client.from('business_promo_submissions').insert({
          'user_id': userId,
          'title': _title.text.trim(),
          'description': _description.text.trim(),
          'promo_type': _type,
          'status': 'pending',
          'image_url': ?imageUrl,
        });
      }

      if (!mounted) return;
      setState(() {
        _step = 4;
        _statusMessage = 'Submitted for review';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_step == 0 || _step == 4) {
                        Navigator.pop(context);
                      } else {
                        setState(() => _step = _step - 1);
                      }
                    },
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      _step == 0
                          ? 'ADVERTISE'
                          : _step == 4
                              ? 'SUBMITTED'
                              : 'PROMOTE EVENT',
                      textAlign: TextAlign.center,
                      style: AppTheme.displayItalic.copyWith(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  if (_statusMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.brandPrimary.withAlpha(30),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppTheme.brandPrimary.withAlpha(80)),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_step == 0) ..._landing(),
                  if (_step == 1) ..._typeStep(),
                  if (_step == 2) ..._detailsStep(),
                  if (_step == 3) ..._confirmStep(),
                  if (_step == 4) ..._success(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _landing() {
    return [
      Text(
        'PUT YOUR EVENT ON THE STORIES FEED',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 22,
          height: 1.15,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Submit for review. After approval, pick a package (IAP keys later) and go live.',
        style: GoogleFonts.plusJakartaSans(color: Colors.white54),
      ),
      const SizedBox(height: 22),
      for (final p in _packages) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.$2,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900)),
                    Text(p.$3,
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Text(p.$4,
                  style: const TextStyle(
                      color: AppTheme.brandPrimary,
                      fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      FilledButton(
        onPressed: () => setState(() => _step = 1),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.brandPrimary,
          minimumSize: const Size.fromHeight(54),
        ),
        child: Text(
          'START SUBMISSION',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
      ),
    ];
  }

  List<Widget> _typeStep() {
    return [
      Text('EVENT TYPE',
          style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in _types)
            ChoiceChip(
              label: Text(t.$2),
              selected: _type == t.$1,
              onSelected: (_) => setState(() => _type = t.$1),
              selectedColor: AppTheme.brandPrimary,
              labelStyle: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800),
              backgroundColor: Colors.white.withAlpha(12),
              side: BorderSide(color: Colors.white.withAlpha(30)),
            ),
        ],
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => setState(() => _step = 2),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.brandPrimary,
          minimumSize: const Size.fromHeight(54),
        ),
        child: const Text('Continue'),
      ),
    ];
  }

  List<Widget> _detailsStep() {
    return [
      GlassTextField(
          controller: _title, hint: 'Event title', icon: Icons.title_rounded),
      const SizedBox(height: 12),
      GlassTextField(
        controller: _description,
        hint: 'Description',
        icon: Icons.notes_rounded,
        maxLines: 4,
      ),
      const SizedBox(height: 12),
      GlassTextField(
          controller: _date,
          hint: 'Date (e.g. 2026-08-20)',
          icon: Icons.calendar_today_rounded),
      const SizedBox(height: 12),
      GlassTextField(
          controller: _location,
          hint: 'Location',
          icon: Icons.location_on_outlined),
      const SizedBox(height: 12),
      GlassTextField(
          controller: _contactName,
          hint: 'Contact name',
          icon: Icons.person_outline_rounded),
      const SizedBox(height: 12),
      GlassTextField(
          controller: _contactPhone,
          hint: 'WhatsApp / phone',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone),
      const SizedBox(height: 12),
      GlassTextField(
          controller: _website,
          hint: 'Website (optional)',
          icon: Icons.link_rounded),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _pickCover,
        icon: const Icon(Icons.image_outlined),
        label: Text(_cover == null ? 'Add cover photo' : _cover!.name),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white38),
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () {
          if (_title.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Title required')),
            );
            return;
          }
          setState(() => _step = 3);
        },
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.brandPrimary,
          minimumSize: const Size.fromHeight(54),
        ),
        child: const Text('Review'),
      ),
    ];
  }

  List<Widget> _confirmStep() {
    return [
      Text('CONFIRM',
          style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2)),
      const SizedBox(height: 12),
      Text(_title.text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
      const SizedBox(height: 6),
      Text(_types.firstWhere((t) => t.$1 == _type).$2,
          style: GoogleFonts.plusJakartaSans(color: AppTheme.brandPrimary)),
      const SizedBox(height: 10),
      Text(_description.text,
          style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _submitting ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.brandPrimary,
          minimumSize: const Size.fromHeight(54),
        ),
        child: Text(_submitting ? 'Submitting…' : 'SUBMIT FOR REVIEW'),
      ),
    ];
  }

  List<Widget> _success() {
    return [
      const Icon(Icons.check_circle_rounded,
          color: Color(0xFF34D399), size: 64),
      const SizedBox(height: 16),
      Text(
        'Submitted. We’ll notify you when it’s approved — then packages unlock with RevenueCat keys.',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(color: Colors.white70),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.brandPrimary,
          minimumSize: const Size.fromHeight(54),
        ),
        child: const Text('Done'),
      ),
    ];
  }
}
