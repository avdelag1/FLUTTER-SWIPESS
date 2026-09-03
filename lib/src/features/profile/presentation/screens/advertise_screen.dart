import 'package:go_router/go_router.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/theme/nexus_theme.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:flutter_swipes/src/features/payments/presentation/providers/entitlements_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Event promotion lifecycle:
/// details → moderation → native payment → live.
///
/// Moderation never charges the customer. An approved submission is the only
/// state allowed to open StoreKit, and the backend publishes only after Apple
/// verifies the transaction.
class AdvertiseScreen extends ConsumerStatefulWidget {
  const AdvertiseScreen({super.key});

  @override
  ConsumerState<AdvertiseScreen> createState() => _AdvertiseScreenState();
}

class _AdvertiseScreenState extends ConsumerState<AdvertiseScreen> {
  /// 0 landing, 1 type, 2 details, 3 confirm, 4 pending, 5 approved, 6 paid/live
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
  bool _checkoutBusy = false;
  String? _statusMessage;
  String? _submissionId;
  String? _submissionStatus;
  String? _submissionTitle;
  bool _isReviewDemo = false;
  bool _reviewDemoPaid = false;
  String _selectedPackage = 'growth';

  static const _types = [
    ('nightlife', 'Nightlife', Icons.nightlife_rounded),
    ('music', 'Music', Icons.music_note_rounded),
    ('food', 'Food & Drink', Icons.restaurant_rounded),
    ('sports', 'Sports', Icons.sports_soccer_rounded),
    ('wellness', 'Wellness', Icons.spa_rounded),
    ('other', 'Other', Icons.category_rounded),
  ];

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
        'Photo + video commercial (up to 20 seconds)',
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
        'Photo + video commercial (up to 20 seconds)',
        '3 broadcast push notifications',
        'Enhanced promotion placement',
      ],
    ),
    _PromoPackage(
      id: 'premium',
      name: 'Unlimited',
      priceLabel: '\$99.99',
      durationLabel: '/ 6 months',
      tagline: 'Maximum reach for peak season',
      color: Color(0xFFA855F7),
      perks: [
        'Top featured placement for 180 days',
        'Photo + video commercial (up to 1 minute)',
        'Monthly broadcast push notifications',
        'Priority promotion support',
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
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    // Auto-approve Apple Review account so they never have to submit/wait
    if (user.email?.trim().toLowerCase() == 'applereview@swipess.com') {
      if (!mounted) return;
      setState(() {
        _submissionId = 'demo-apple-review';
        _submissionStatus = _reviewDemoPaid ? 'paid' : 'approved';
        _submissionTitle = 'Apple Review Demo Event';
        _isReviewDemo = true;
        _statusMessage = _reviewDemoPaid ? 'Paid' : 'Approved';
        _step = _reviewDemoPaid ? 7 : 6;
      });
      return;
    }

    try {
      final rows = await Supabase.instance.client
          .from('business_promo_submissions')
          .select(
            'id, status, title, package, payment_product_id, published_event_id, is_review_demo',
          )
          .eq('user_id', user.id)
          .inFilter('status', [
            'pending',
            'approved',
            'paid',
            'live',
            'rejected',
          ])
          .order('created_at', ascending: false)
          .limit(1);
      if (!mounted || (rows as List).isEmpty) return;

      final row = Map<String, dynamic>.from(rows.first as Map);
      final status = row['status']?.toString() ?? 'pending';
      final packageValue =
          row['payment_product_id']?.toString() ?? row['package']?.toString();
      final offer = packageValue == null
          ? null
          : IapCatalog.promoById(packageValue);

      setState(() {
        _submissionId = row['id']?.toString();
        _submissionStatus = status;
        _submissionTitle = row['title']?.toString();
        _isReviewDemo = row['is_review_demo'] == true;
        if (offer != null) _selectedPackage = offer.id;
        _statusMessage = _statusLabel(status, _submissionTitle);
        _step = switch (status) {
          'pending' => 5,
          'approved' => 6,
          'paid' || 'live' => 7,
          _ => 0,
        };
      });
    } catch (e) {
      debugPrint('Promotion status load failed: $e');
    }
  }

  String _statusLabel(String status, String? title) {
    final name = title?.trim().isNotEmpty == true ? title! : 'Your promotion';
    return switch (status) {
      'pending' => '$name · under review · no charge yet',
      'approved' => '$name · approved · ready for payment',
      'paid' => '$name · purchase verified',
      'live' => '$name · live in Events',
      'rejected' => '$name · not approved · no charge',
      _ => '$name · $status',
    };
  }

  void _resetForNew() {
    _title.clear();
    _description.clear();
    _location.clear();
    _contactName.clear();
    _contactPhone.clear();
    _website.clear();
    _date.clear();
    setState(() {
      _step = 0;
      _type = 'nightlife';
      _cover = null;
      _video = null;
      _submissionId = null;
      _submissionStatus = null;
      _submissionTitle = null;
      _statusMessage = null;
      _isReviewDemo = false;
      _reviewDemoPaid = false;
      _selectedPackage = 'growth';
    });
  }

  Future<void> _pickCover() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null && mounted) setState(() => _cover = file);
  }

  Future<void> _pickVideo() async {
    setState(() => _videoChecking = true);
    final limit = _selectedPackage == 'premium' ? 60 : 20;
    try {
      final file = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: Duration(seconds: limit),
      );
      if (file == null) return;
      if (mounted) setState(() => _video = file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not pick video: $e')));
      }
    } finally {
      if (mounted) setState(() => _videoChecking = false);
    }
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _submitting) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to submit a promotion')),
      );
      return;
    }

    setState(() => _submitting = true);
    AppHaptics.medium();
    try {
      String? imageUrl;
      String? videoUrl;

      if (_cover != null) {
        final bytes = await _cover!.readAsBytes();
        final path =
            'promo-submissions/${user.id}-${DateTime.now().millisecondsSinceEpoch}.jpg';
        await client.storage
            .from('event-images')
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        imageUrl = client.storage.from('event-images').getPublicUrl(path);
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
            'promo-submissions/videos/${user.id}-${DateTime.now().millisecondsSinceEpoch}.$ext';
        final contentType = ext == 'mov'
            ? 'video/quicktime'
            : ext == 'webm'
            ? 'video/webm'
            : 'video/mp4';
        await client.storage
            .from('event-images')
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: contentType, upsert: true),
            );
        videoUrl = client.storage.from('event-images').getPublicUrl(path);
      }

      final ownerName = _contactName.text.trim().isNotEmpty
          ? _contactName.text.trim()
          : (user.email?.split('@').first ?? 'Event promoter');
      final title = _title.text.trim();
      final payload = <String, dynamic>{
        // Legacy required columns on the existing moderation table.
        'business_name': title,
        'business_type': 'event',
        'owner_name': ownerName,
        'package': 'free_trial',
        // Event-specific fields.
        'user_id': user.id,
        'event_type': _type,
        'promo_type': _type,
        'title': title,
        'description': _description.text.trim(),
        'event_date': _date.text.trim().isEmpty ? null : _date.text.trim(),
        'location': _location.text.trim().isEmpty
            ? null
            : _location.text.trim(),
        'contact_name': ownerName,
        'contact_phone': _contactPhone.text.trim().isEmpty
            ? null
            : _contactPhone.text.trim(),
        'whatsapp': _contactPhone.text.trim().isEmpty
            ? null
            : _contactPhone.text.trim(),
        'website': _website.text.trim().isEmpty ? null : _website.text.trim(),
        'image_url': imageUrl,
        'video_url': videoUrl,
        'status': 'pending',
      }..removeWhere((_, value) => value == null);

      final inserted = await client
          .from('business_promo_submissions')
          .insert(payload)
          .select('id, status, title')
          .single();

      if (!mounted) return;
      setState(() {
        _submissionId = inserted['id']?.toString();
        _submissionStatus = 'pending';
        _submissionTitle = title;
        _statusMessage = '$title · under review · no charge yet';
        _step = 5;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not submit event: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _launchPayment() async {
    if (_checkoutBusy) return;
    final submissionId = _submissionId;
    if (_submissionStatus != 'approved' || submissionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This event must be approved before payment.'),
        ),
      );
      return;
    }
    final offer = IapCatalog.promoById(_selectedPackage);
    if (offer == null) return;

    AppHaptics.medium();
    setState(() => _checkoutBusy = true);
    try {
      final result = await ref
          .read(paymentServiceProvider)
          .buy(offer, contextId: submissionId);
      if (!mounted) return;

      if (result.isSuccess) {
        ref.invalidate(messagingEntitlementsProvider);
        if (_isReviewDemo) {
          _reviewDemoPaid = true;
        }
        await _loadStatus();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isReviewDemo
                  ? 'App Store purchase verified successfully.'
                  : 'Purchase verified — your promotion is live.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.userMessage)));
    } finally {
      if (mounted) setState(() => _checkoutBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeoNaiveScaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  if (_step == 0) ..._landing(),
                  if (_step == 1) ..._packageSelectionStep(),
                  if (_step == 2) ..._typeStep(),
                  if (_step == 3) ..._detailsStep(),
                  if (_step == 4) ..._confirmStep(),
                  if (_step == 5) ..._pending(),
                  if (_step == 6) ..._paymentStep(),
                  if (_step == 7) ..._completed(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 4, 16, 6),
      child: Row(
        children: [
          _step >= 5 || _step == 0
              ? const CapBackButton(fallbackPath: AppPaths.clientProfile)
              : CapBackButton(onTap: () => setState(() => _step--)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROMOTE',
                  style: NexusTheme.sectionLabel.copyWith(color: Colors.white),
                ),
                Text(
                  _step == 6
                      ? 'Complete purchase'
                      : _step == 7
                      ? 'Promotion ready'
                      : 'Your event',
                  style: AppTheme.displayItalic.copyWith(fontSize: 22),
                ),
              ],
            ),
          ),
          Icon(Icons.campaign_rounded, color: Colors.white, size: 24),
        ],
      ),
    );
  }

  List<Widget> _landing() {
    return [
      SizedBox(height: 8),
      Text(
        'GET YOUR\nEVENT LIVE',
        textAlign: TextAlign.center,
        style: AppTheme.displayItalic.copyWith(fontSize: 36, height: 1.02),
      ),
      SizedBox(height: 10),
      Text(
        'Submit first. We review the event before you pay. If approved, payment unlocks and the native App Store sheet handles the purchase.',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
      if (_statusMessage != null) ...[
        SizedBox(height: 16),
        _statusCard(_statusMessage!),
      ],
      SizedBox(height: 20),
      _pipeline(0),
      SizedBox(height: 20),
      for (final p in _packages) ...[
        _packageCard(p, selectable: false),
        SizedBox(height: 10),
      ],
      SizedBox(height: 10),
      _primaryBtn(
        label: 'Request promotion — free to apply',
        onPressed: () => setState(() => _step = 1),
      ),
      SizedBox(height: 10),
      Text(
        'No payment is collected at submission. Rejected events are never charged.',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ];
  }

  Widget _pipeline(int active) {
    const labels = ['DETAILS', 'REVIEW', 'PAYMENT', 'LIVE'];
    const icons = [
      Icons.edit_note_rounded,
      Icons.verified_user_outlined,
      Icons.shopping_bag_outlined,
      Icons.celebration_outlined,
    ];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 1,
                margin: EdgeInsets.symmetric(horizontal: 5),
                color: Colors.white,
              ),
            ),
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= active ? Colors.white : const Color(0xFF171A20),
                ),
                child: Icon(
                  icons[i],
                  size: 17,
                  color: i <= active ? Colors.black : Colors.white,
                ),
              ),
              SizedBox(height: 5),
              Text(
                labels[i],
                style: GoogleFonts.plusJakartaSans(
                  color: i <= active ? Colors.white : Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .6,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _statusCard(String text) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _packageSelectionStep() {
    return [
      _pipeline(0),
      SizedBox(height: 22),
      Text(
        'PICK A PACKAGE',
        style: AppTheme.displayItalic.copyWith(fontSize: 28, height: 1.05),
      ),
      SizedBox(height: 10),
      Text(
        'Select the duration of your promotion. This determines the maximum length of your video upload.',
        style: GoogleFonts.plusJakartaSans(color: Colors.white70, height: 1.4),
      ),
      SizedBox(height: 18),
      for (final p in _packages) ...[
        _packageCard(p, selectable: true),
        SizedBox(height: 10),
      ],
      SizedBox(height: 10),
      _primaryBtn(
        label: 'Continue',
        onPressed: () => setState(() => _step = 2),
      ),
    ];
  }

  List<Widget> _typeStep() {
    return [
      _pipeline(0),
      SizedBox(height: 22),
      Text(
        'WHAT ARE YOU\nPROMOTING?',
        style: AppTheme.displayItalic.copyWith(fontSize: 28, height: 1.05),
      ),
      SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
        children: [
          for (final t in _types)
            GestureDetector(
              onTap: () => setState(() => _type = t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: _type == t.$1 ? Colors.white : NexusTheme.cardDark,
                  border: Border.all(color: Colors.transparent),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      t.$3,
                      color: _type == t.$1 ? Colors.black : Colors.white,
                      size: 25,
                    ),
                    const Spacer(),
                    Text(
                      t.$2,
                      style: GoogleFonts.plusJakartaSans(
                        color: _type == t.$1 ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      SizedBox(height: 18),
      _primaryBtn(
        label: 'Continue',
        onPressed: () => setState(() => _step = 3),
      ),
    ];
  }

  List<Widget> _detailsStep() {
    return [
      _pipeline(0),
      SizedBox(height: 20),
      Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                SizedBox(width: 8),
                Text(
                  'Content Rules',
                  style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              '• No nudity or explicit content. Violators will be banned.\n• Do not put phone numbers in the title/description.\n• Your video can be trimmed when uploaded up to your plan limit.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
      SizedBox(height: 20),
      GlassTextField(
        controller: _title,
        hint: 'Event title',
        icon: Icons.title_rounded,
      ),
      SizedBox(height: 12),
      GlassTextField(
        controller: _description,
        hint: 'Description',
        icon: Icons.notes_rounded,
        maxLines: 4,
      ),
      SizedBox(height: 12),
      GlassTextField(
        controller: _date,
        hint: 'Date (e.g. 2026-08-20)',
        icon: Icons.calendar_today_rounded,
      ),
      SizedBox(height: 12),
      GlassTextField(
        controller: _location,
        hint: 'Location',
        icon: Icons.location_on_outlined,
      ),
      SizedBox(height: 12),
      GlassTextField(
        controller: _contactName,
        hint: 'Contact / organizer name',
        icon: Icons.person_outline_rounded,
      ),
      SizedBox(height: 12),
      GlassTextField(
        controller: _contactPhone,
        hint: 'WhatsApp / phone',
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
      ),
      SizedBox(height: 12),
      GlassTextField(
        controller: _website,
        hint: 'Website (optional)',
        icon: Icons.link_rounded,
      ),
      SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _pickCover,
        icon: Icon(Icons.image_outlined),
        label: Text(_cover == null ? 'Add cover photo' : _cover!.name),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _videoChecking ? null : _pickVideo,
        icon: Icon(
          _video == null ? Icons.videocam_outlined : Icons.check_rounded,
        ),
        label: Text(
          _videoChecking
              ? 'Checking video…'
              : _video == null
              ? 'Upload video commercial (optional, ≤${_selectedPackage == 'premium' ? '1m' : '20s'})'
              : _video!.name,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      if (_cover != null && !kIsWeb) ...[
        SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(File(_cover!.path), height: 140, fit: BoxFit.cover),
        ),
      ],
      SizedBox(height: 22),
      _primaryBtn(
        label: 'Review details',
        onPressed: () {
          if (_title.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Event title is required')),
            );
            return;
          }
          
          final text = '${_title.text} ${_description.text}'.toLowerCase();
          final hasPhone = RegExp(r'\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b').hasMatch(text) || 
                           RegExp(r'\b\d{10,11}\b').hasMatch(text);
          final hasExplicit = text.contains('nude') || text.contains('kinky') || text.contains('sex');
          
          if (hasPhone) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please use the Contact Phone field for phone numbers, not the title or description.')),
            );
            return;
          }
          if (hasExplicit) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Explicit content is not allowed. Please review your text.')),
            );
            return;
          }
          
          setState(() => _step = 4);
        },
      ),
    ];
  }

  List<Widget> _confirmStep() {
    return [
      _pipeline(0),
      SizedBox(height: 22),
      Text(
        'SUBMIT FOR\nREVIEW',
        style: AppTheme.displayItalic.copyWith(fontSize: 30, height: 1.05),
      ),
      SizedBox(height: 10),
      Text(
        'Our team checks the event before payment is enabled. Submitting this form does not charge you.',
        style: GoogleFonts.plusJakartaSans(color: Colors.white, height: 1.4),
      ),
      SizedBox(height: 18),
      _summaryRow('Event', _title.text),
      _summaryRow('Category', _types.firstWhere((t) => t.$1 == _type).$2),
      if (_location.text.trim().isNotEmpty)
        _summaryRow('Location', _location.text),
      if (_date.text.trim().isNotEmpty) _summaryRow('Date', _date.text),
      if (_video != null) _summaryRow('Video', 'Attached · up to ${_selectedPackage == 'premium' ? 1 : 20} ${_selectedPackage == 'premium' ? 'minute' : 'seconds'}'),
      SizedBox(height: 22),
      _primaryBtn(
        label: _submitting ? 'Submitting…' : 'Submit for review',
        onPressed: _submitting ? null : _submit,
      ),
      SizedBox(height: 10),
      Text(
        'NO PAYMENT NOW · PAYMENT ONLY AFTER APPROVAL',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    ];
  }

  Widget _summaryRow(String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withAlpha(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _pending() {
    return [
      _pipeline(1),
      SizedBox(height: 28),
      Icon(Icons.schedule_rounded, color: Colors.white, size: 52),
      SizedBox(height: 14),
      Text(
        'Review in progress',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 23,
        ),
      ),
      SizedBox(height: 9),
      Text(
        'We’re reviewing “${_submissionTitle ?? 'your event'}”. You have not been charged. If approved, we’ll notify you and unlock payment.',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(color: Colors.white, height: 1.45),
      ),
      SizedBox(height: 22),
      _statusCard('NO CHARGE · WAITING FOR MODERATION'),
      SizedBox(height: 18),
      _primaryBtn(label: 'Refresh approval status', onPressed: _loadStatus),
      SizedBox(height: 8),
      TextButton(
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go(AppPaths.clientProfile);
          }
        },
        child: Text('Done'),
      ),
    ];
  }

  List<Widget> _paymentStep() {
    final selected = _packages.firstWhere((p) => p.id == _selectedPackage);
    return [
      _pipeline(2),
      SizedBox(height: 22),
      Row(
        children: [
          Icon(
            Icons.verified_rounded,
            color: Color(0xFF34D399),
            size: 25,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'APPROVED · NO CHARGE YET',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF34D399),
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: 12),
      Text(
        'Complete Purchase',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 25,
        ),
      ),
      SizedBox(height: 7),
      Text(
        '“${_submissionTitle ?? 'Your event'}” passed moderation. Tap the button below to open the native App Store purchase sheet for your selected plan.',
        style: GoogleFonts.plusJakartaSans(color: Colors.white, height: 1.4),
      ),
      if (_isReviewDemo) ...[
        SizedBox(height: 12),
        _statusCard(
          'APP REVIEW DEMO · This pre-approved sample exists so the native purchase can be tested immediately.',
        ),
      ],
      SizedBox(height: 18),
      _packageCard(selected, selectable: false),
      SizedBox(height: 20),
      SizedBox(height: 8),
      if (IapCatalog.usesNativeStore)
        Container(
          padding: EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                color: Colors.white,
                size: 18,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'PAYMENT: NATIVE APP STORE IN-APP PURCHASE',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ),
            ],
          ),
        ),
      SizedBox(height: 12),
      _primaryBtn(
        label: _checkoutBusy
            ? 'Opening App Store…'
            : 'Continue to purchase · ${selected.priceLabel}',
        onPressed: _checkoutBusy ? null : _launchPayment,
      ),
      SizedBox(height: 10),
      Text(
        'Your event becomes active only after the store transaction is verified. Cancelling checkout leaves the event approved and unpaid.',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10.5),
      ),
    ];
  }

  List<Widget> _completed() {
    return [
      _pipeline(3),
      SizedBox(height: 32),
      Icon(
        _isReviewDemo ? Icons.verified_rounded : Icons.celebration_rounded,
        color: const Color(0xFF34D399),
        size: 58,
      ),
      SizedBox(height: 14),
      Text(
        _isReviewDemo ? 'Purchase verified' : 'Your event is live',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 25,
        ),
      ),
      SizedBox(height: 9),
      Text(
        _isReviewDemo
            ? 'The native App Store event-promotion purchase completed and was verified by the backend. The review sample is intentionally not published publicly.'
            : '“${_submissionTitle ?? 'Your event'}” is approved, paid and available in Events.',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(color: Colors.white, height: 1.45),
      ),
      SizedBox(height: 22),
      _statusCard(
        _isReviewDemo
            ? 'APP STORE PURCHASE VERIFIED · REVIEW DEMO COMPLETE'
            : 'APPROVED · PAYMENT VERIFIED · LIVE',
      ),
      SizedBox(height: 18),
      _primaryBtn(
        label: 'Done',
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go(AppPaths.clientProfile);
          }
        },
      ),
      SizedBox(height: 8),
      TextButton(
        onPressed: _resetForNew,
        child: Text('Promote another event'),
      ),
    ];
  }

  Widget _packageCard(_PromoPackage p, {required bool selectable}) {
    final selected = _selectedPackage == p.id;
    return GestureDetector(
      onTap: selectable ? () => setState(() => _selectedPackage = p.id) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected && selectable
              ? Colors.white
              : const Color(0xFF111319),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.transparent),
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
                      color: selected && selectable
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (p.popular)
                  Text(
                    'POPULAR',
                    style: GoogleFonts.plusJakartaSans(
                      color: selected && selectable ? Colors.black : p.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: p.priceLabel,
                    style: GoogleFonts.plusJakartaSans(
                      color: selected && selectable ? Colors.black : p.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  TextSpan(
                    text: ' ${p.durationLabel}',
                    style: GoogleFonts.plusJakartaSans(
                      color: selected && selectable
                          ? Colors.black
                          : Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 3),
            Text(
              p.tagline,
              style: GoogleFonts.plusJakartaSans(
                color: selected && selectable ? Colors.black : Colors.white,
                fontSize: 11.5,
              ),
            ),
            SizedBox(height: 9),
            for (final perk in p.perks)
              Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      color: selected && selectable ? Colors.black : p.color,
                      size: 15,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        perk,
                        style: GoogleFonts.plusJakartaSans(
                          color: selected && selectable
                              ? Colors.black
                              : Colors.white,
                          fontSize: 11.5,
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

  Widget _primaryBtn({required String label, VoidCallback? onPressed}) {
    return Material(
      color: onPressed == null ? Colors.white12 : Colors.white,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 56,
          child: Center(
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: onPressed == null ? Colors.white : Colors.black,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                fontSize: 12.5,
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
