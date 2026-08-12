import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Capacitor AdvertisePage — submit a business promo for review.
class AdvertiseScreen extends ConsumerStatefulWidget {
  const AdvertiseScreen({super.key});

  @override
  ConsumerState<AdvertiseScreen> createState() => _AdvertiseScreenState();
}

class _AdvertiseScreenState extends ConsumerState<AdvertiseScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _contact = TextEditingController();
  String _type = 'event';
  bool _submitting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _contact.dispose();
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
    try {
      await Supabase.instance.client.from('business_promo_submissions').insert({
        'user_id': userId,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'contact_email': _contact.text.trim(),
        'promo_type': _type,
        'status': 'pending',
      });
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Submitted for review';
        _title.clear();
        _description.clear();
        _contact.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promo submitted for review')),
      );
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withAlpha(40)),
                    ),
                    child: const Center(
                      child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('ADVERTISE', style: AppTheme.displayItalic.copyWith(fontSize: 22)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Promote an event or business on Swipess. Submissions go to review before checkout packages unlock.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary.withAlpha(40),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.brandPrimary.withAlpha(80)),
                ),
                child: Text(_statusMessage!, style: const TextStyle(color: Colors.white)),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                for (final type in const ['event', 'business', 'listing'])
                  ChoiceChip(
                    label: Text(type.toUpperCase()),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                    selectedColor: AppTheme.brandPrimary,
                    backgroundColor: Colors.white.withAlpha(14),
                    labelStyle: TextStyle(
                      color: _type == type ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                    side: BorderSide(color: Colors.white.withAlpha(30)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            GlassTextField(controller: _title, hint: 'Title', icon: Icons.campaign_rounded),
            const SizedBox(height: 10),
            GlassTextField(
              controller: _description,
              hint: 'Describe the promo',
              icon: Icons.notes_rounded,
            ),
            const SizedBox(height: 10),
            GlassTextField(
              controller: _contact,
              hint: 'Contact email',
              keyboardType: TextInputType.emailAddress,
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(_submitting ? 'Submitting…' : 'Submit for review'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Paid placement packages need RevenueCat / App Store keys — leave those for the final keys list.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
