import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cap `AdvertisePage` — promote event: landing → type → details (+video) → confirm → pending/approved.
class AdvertiseScreen extends ConsumerStatefulWidget {
  const AdvertiseScreen({super.key});

  @override
  ConsumerState<AdvertiseScreen> createState() => _AdvertiseScreenState();
}

class _AdvertiseScreenState extends ConsumerState<AdvertiseScreen> {
  /// 0 landing, 1 type, 2 details, 3 confirm, 4 success, 5 approved packages
  int _step = 0;
  String _type = 'nightlife';
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  final _website = TextEditingController();
  final _date = TextEditingController();
  XFile? _cover;
  XFile? _video;
  bool _submitting = false;
  bool _videoChecking = false;
  String? _statusMessage;
  String? _submissionStatus; // pending | approved
  String? _submissionTitle;
  String _selectedPackage = 'growth';

  static const _types = [
    ('nightlife', 'Nightlife', Icons.nightlife_rounded),
    ('music', 'Music', Icons.music_note_rounded),
    ('food', 'Food & Drink', Icons.restaurant_rounded),
    ('sports', 'Sports', Icons.sports_soccer_rounded),
    ('wellness', 'Wellness', Icons.spa_rounded),
    ('other', 'Other', Icons.category_rounded),
  ];

  /// Cap PACKAGES — Starter / Growth / Wave.
  static const _packages = [
    _PromoPackage(
      id: 'starter',
      name: 'Starter',
      priceLabel: '\$4.99',
      durationLabel: '/ week',
      tagline: 'Try it for a week — no commitment',
      color: Color(0xFF14B8A6),
      perks: [
        'Shown to property owners, renters & digital nomads',
        'Photo + video commercial (up to 1 minute)',
        'Standard feed placement',
        'Direct WhatsApp connection',
      ],
    ),
    _PromoPackage(
      id: 'growth',
      name: 'Growth',
      priceLabel: '\$49.99',
      durationLabel: '/ 3 months',
      tagline: 'Best value — 3 months of organic reach',
      color: Color(0xFF6366F1),
      popular: true,
      perks: [
        'Top featured placement for 90 days',
        'Photo + video commercial (up to 1 minute)',
        '3 Broadcast push notifications',
        "Enhanced profile with Verified badge",
      ],
    ),
    _PromoPackage(
      id: 'premium',
      name: 'Wave',
      priceLabel: '\$99.99',
      durationLabel: '/ 6 months',
      tagline: 'Maximum reach for peak season',
      color: Color(0xFFA855F7),
      perks: [
        'Top featured placement for 180 days',
        'Photo + video commercial (up to 1 minute)',
        'Monthly broadcast push notifications',
        'Dedicated account manager & VIP support',
      ],
    ),
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
      if (!mounted || (rows as List).isEmpty) return;
      final row = Map<String, dynamic>.from(rows.first as Map);
      final status = row['status'] as String? ?? 'pending';
      setState(() {
        _submissionStatus = status;
        _submissionTitle = row['title'] as String?;
        _statusMessage = 'Latest: ${row['title'] ?? 'Promo'} · $status';
        if (status == 'approved') _step = 5;
      });
    } catch (_) {}
  }

  Future<void> _pickCover() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _cover = file);
  }

  Future<void> _pickVideo() async {
    setState(() => _videoChecking = true);
    try {
      final file = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );
      if (file == null) return;
      setState(() => _video = file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video ready — up to 1 min commercial')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick video: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _videoChecking = false);
    }
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
      String? videoUrl;

      if (_cover != null) {
        final bytes = await _cover!.readAsBytes();
        final path =
            'promo-submissions/$userId-${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage.from('event-images').uploadBinary(
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

      if (_video != null) {
        final bytes = await _video!.readAsBytes();
        final name = _video!.name.toLowerCase();
        final ext = name.endsWith('.mov')
            ? 'mov'
            : name.endsWith('.webm')
                ? 'webm'
                : 'mp4';
        final path =
            'promo-submissions/videos/$userId-${DateTime.now().millisecondsSinceEpoch}.$ext';
        final contentType = ext == 'mov'
            ? 'video/quicktime'
            : ext == 'webm'
                ? 'video/webm'
                : 'video/mp4';
        await Supabase.instance.client.storage.from('event-images').uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: contentType, upsert: true),
            );
        videoUrl = Supabase.instance.client.storage
            .from('event-images')
            .getPublicUrl(path);
      }

      final payload = <String, dynamic>{
        'user_id': userId,
        'event_type': _type,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'event_date': _date.text.trim().isEmpty ? null : _date.text.trim(),
        'location':
            _location.text.trim().isEmpty ? null : _location.text.trim(),
        'contact_name': _contactName.text.trim().isEmpty
            ? null
            : _contactName.text.trim(),
        'contact_phone': _contactPhone.text.trim().isEmpty
            ? null
            : _contactPhone.text.trim(),
        'website': _website.text.trim().isEmpty ? null : _website.text.trim(),
        'image_url': imageUrl,
        'video_url': videoUrl,
        'status': 'pending',
      }..removeWhere((_, v) => v == null);

      try {
        await Supabase.instance.client
            .from('business_promo_submissions')
            .insert(payload);
      } catch (e) {
        // Cap fallback if video_url column missing.
        final msg = e.toString();
        if (msg.contains('video_url') || msg.contains('42703')) {
          payload.remove('video_url');
          if (videoUrl != null) {
            payload['description'] =
                '${_description.text.trim()}\n\n[Video commercial]: $videoUrl';
          }
          await Supabase.instance.client
              .from('business_promo_submissions')
              .insert(payload);
        } else {
          await Supabase.instance.client
              .from('business_promo_submissions')
              .insert({
            'user_id': userId,
            'title': _title.text.trim(),
            'description': _description.text.trim(),
            'promo_type': _type,
            'status': 'pending',
            if (imageUrl != null) 'image_url': imageUrl,
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _step = 4;
        _submissionStatus = 'pending';
        _submissionTitle = _title.text.trim();
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

  Future<void> _launchPayment() async {
    HapticFeedback.mediumImpact();
    final payments = ref.read(paymentServiceProvider);
    final result = await payments.presentPaywall();
    if (!mounted) return;
    final ok = result == PaywallResult.purchased ||
        result == PaywallResult.restored;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Purchase complete — your promo will go live shortly.'
              : 'Open RevenueCat offerings for promo products, or restore purchases.',
        ),
      ),
    );
  }

  Future<void> _restore() async {
    HapticFeedback.lightImpact();
    final ok = await ref.read(paymentServiceProvider).restorePurchases();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Purchases restored' : 'No previous purchases found',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = switch (_step) {
      0 => 0.0,
      1 => 0.33,
      2 => 0.66,
      3 => 1.0,
      _ => 1.0,
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_step == 0 || _step >= 4) {
                        Navigator.pop(context);
                      } else {
                        setState(() => _step = _step - 1);
                      }
                    },
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Promote Your Event',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        if (_step >= 1 && _step <= 3)
                          Text(
                            'Step $_step of 3',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.withAlpha(50),
                          Colors.purple.withAlpha(50),
                        ],
                      ),
                      border: Border.all(color: Colors.orange.withAlpha(80)),
                    ),
                    child: const Icon(Icons.campaign_rounded,
                        color: Color(0xFFFB923C), size: 18),
                  ),
                ],
              ),
            ),
            if (_step >= 1 && _step <= 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFFF97316),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  if (_statusMessage != null && _step == 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(28),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orange.withAlpha(60)),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  if (_step == 0) ..._landing(),
                  if (_step == 1) ..._typeStep(),
                  if (_step == 2) ..._detailsStep(),
                  if (_step == 3) ..._confirmStep(),
                  if (_step == 4) ..._pending(),
                  if (_step == 5) ..._approvedPackages(),
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
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(35),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.orange.withAlpha(90)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.movie_creation_outlined,
                  color: Color(0xFFFB923C), size: 16),
              const SizedBox(width: 8),
              Text(
                'PHOTO + VIDEO · MAX 1 MIN',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFFB923C),
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Get your event ',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 36,
                height: 1.05,
                letterSpacing: -1.2,
              ),
            ),
            TextSpan(
              text: 'on Swipess',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 36,
                fontStyle: FontStyle.italic,
                height: 1.05,
                letterSpacing: -1.2,
                foreground: Paint()
                  ..shader = const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFF38BDF8)],
                  ).createShader(const Rect.fromLTWH(0, 0, 220, 50)),
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        'Reach 15k+ seekers with full-screen cards — including video commercials up to 1 minute.',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white54,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 10),
      TextButton.icon(
        onPressed: _restore,
        icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.white38),
        label: Text(
          'RESTORE PURCHASES',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white38,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 1.6,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'HOW PROMOTION WORKS',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white30,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 2,
        ),
      ),
      const SizedBox(height: 10),
      for (final s in const [
        ('01', 'Tell us about your night', 'Category, venue, WhatsApp — add a cover photo'),
        ('02', 'Upload a video commercial', 'Optional MP4/MOV up to 60 seconds'),
        ('03', 'We review in under 24h', 'No charge until approved — then pick a plan'),
      ])
        _howRow(s.$1, s.$2, s.$3),
      const SizedBox(height: 16),
      for (final p in _packages) ...[
        _packageCard(p, selectable: false),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 8),
      _primaryBtn(
        label: 'Request promotion — free to apply',
        onPressed: () => setState(() => _step = 1),
      ),
      const SizedBox(height: 10),
      Text(
        'Photo + video (max 1 min) · Pay only after approval · From \$4.99 USD',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white30,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ];
  }

  Widget _howRow(String n, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Text(
            n,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFFB923C),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontWeight: FontWeight.w900)),
                Text(desc,
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _packageCard(_PromoPackage p, {required bool selectable}) {
    final selected = _selectedPackage == p.id;
    return GestureDetector(
      onTap: selectable
          ? () => setState(() => _selectedPackage = p.id)
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected && selectable
                ? p.color
                : (p.popular ? p.color.withAlpha(120) : Colors.white24),
            width: selected && selectable ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (p.popular)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.color.withAlpha(50),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'POPULAR',
                      style: GoogleFonts.plusJakartaSans(
                        color: p.color,
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: p.priceLabel,
                    style: GoogleFonts.plusJakartaSans(
                      color: p.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  TextSpan(
                    text: ' ${p.durationLabel}',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(p.tagline,
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 10),
            for (final perk in p.perks)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_rounded, color: p.color, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        perk,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _typeStep() {
    return [
      Text(
        'What are you\npromoting?',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 28,
          height: 1.05,
          letterSpacing: -0.8,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Choose the category that fits your business',
        style: GoogleFonts.plusJakartaSans(color: Colors.white54),
      ),
      const SizedBox(height: 18),
      for (final t in _types) ...[
        GestureDetector(
          onTap: () => setState(() => _type = t.$1),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _type == t.$1
                  ? AppTheme.brandPrimary.withAlpha(40)
                  : Colors.white.withAlpha(12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _type == t.$1
                    ? AppTheme.brandPrimary
                    : Colors.white24,
              ),
            ),
            child: Row(
              children: [
                Icon(t.$3, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  t.$2,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (_type == t.$1)
                  const Icon(Icons.check_circle, color: AppTheme.brandPrimary),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      _primaryBtn(label: 'Continue', onPressed: () => setState(() => _step = 2)),
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
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _videoChecking ? null : _pickVideo,
        icon: Icon(_video == null ? Icons.videocam_outlined : Icons.check_rounded),
        label: Text(
          _videoChecking
              ? 'Checking video…'
              : _video == null
                  ? 'Upload video commercial (optional, ≤1 min)'
                  : _video!.name,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white38),
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      if (_cover != null && !kIsWeb) ...[
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(File(_cover!.path), height: 140, fit: BoxFit.cover),
        ),
      ],
      const SizedBox(height: 24),
      _primaryBtn(
        label: 'Review',
        onPressed: () {
          if (_title.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Title required')),
            );
            return;
          }
          setState(() => _step = 3);
        },
      ),
    ];
  }

  List<Widget> _confirmStep() {
    return [
      Text(
        'Ready to submit?',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 24,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Our team will verify your details. Once approved, you can choose your package and pay to launch.',
        style: GoogleFonts.plusJakartaSans(color: Colors.white54),
      ),
      const SizedBox(height: 16),
      Text(_title.text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
      const SizedBox(height: 6),
      Text(_types.firstWhere((t) => t.$1 == _type).$2,
          style: GoogleFonts.plusJakartaSans(color: AppTheme.brandPrimary)),
      const SizedBox(height: 10),
      Text(_description.text,
          style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
      if (_video != null) ...[
        const SizedBox(height: 10),
        Text(
          'Video: Attached (≤1 min)',
          style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF34D399), fontWeight: FontWeight.w800),
        ),
      ],
      const SizedBox(height: 24),
      _primaryBtn(
        label: _submitting ? 'Submitting…' : 'Submit & Get Promoted',
        onPressed: _submitting ? null : _submit,
      ),
      const SizedBox(height: 10),
      Text(
        'By submitting, you agree to our terms. No payment until approved.',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(color: Colors.white30, fontSize: 11),
      ),
    ];
  }

  List<Widget> _pending() {
    return [
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(20),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.orange.withAlpha(50)),
        ),
        child: Column(
          children: [
            const Icon(Icons.schedule_rounded,
                color: Color(0xFFFB923C), size: 56),
            const SizedBox(height: 16),
            Text(
              'Review in Progress',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We\'re reviewing "${_submissionTitle ?? 'your event'}". You\'ll be notified as soon as it\'s ready to launch!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white60),
            ),
            const SizedBox(height: 12),
            Text(
              'ESTIMATED: < 24H',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFFB923C),
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _primaryBtn(label: 'Done', onPressed: () => Navigator.pop(context)),
      TextButton(
        onPressed: () async {
          await _loadStatus();
          if (_submissionStatus == 'approved' && mounted) {
            setState(() => _step = 5);
          }
        },
        child: const Text('Refresh status'),
      ),
    ];
  }

  List<Widget> _approvedPackages() {
    return [
      Text(
        'Approved — pick a plan',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 24,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Your brand promotion for "${_submissionTitle ?? 'your event'}" is approved. Ready to launch?',
        style: GoogleFonts.plusJakartaSans(color: Colors.white54),
      ),
      const SizedBox(height: 18),
      for (final p in _packages) ...[
        _packageCard(p, selectable: true),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 8),
      _primaryBtn(label: 'Launch with selected plan', onPressed: _launchPayment),
      TextButton(onPressed: _restore, child: const Text('Restore Purchases')),
    ];
  }

  Widget _primaryBtn({required String label, VoidCallback? onPressed}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: onPressed == null
            ? null
            : const LinearGradient(
                colors: [Color(0xFFFF4D00), Color(0xFFEA580C)],
              ),
        color: onPressed == null ? Colors.white24 : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 56,
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PromoPackage {
  const _PromoPackage({
    required this.id,
    required this.name,
    required this.priceLabel,
    required this.durationLabel,
    required this.tagline,
    required this.color,
    required this.perks,
    this.popular = false,
  });

  final String id;
  final String name;
  final String priceLabel;
  final String durationLabel;
  final String tagline;
  final Color color;
  final List<String> perks;
  final bool popular;
}
