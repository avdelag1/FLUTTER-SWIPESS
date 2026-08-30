import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/admin/presentation/widgets/admin_shell.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';

class AdminAmbassadorsScreen extends ConsumerStatefulWidget {
  const AdminAmbassadorsScreen({super.key});

  @override
  ConsumerState<AdminAmbassadorsScreen> createState() => _AdminAmbassadorsScreenState();
}

class _AdminAmbassadorsScreenState extends ConsumerState<AdminAmbassadorsScreen> {
  bool _loading = true;
  String? _myCode;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    
    try {
      final codeRes = await Supabase.instance.client
          .from('ambassador_codes')
          .select('code, commission_rate')
          .eq('user_id', user.id)
          .maybeSingle();
      
      if (codeRes != null) {
        _myCode = codeRes['code'] as String;
      }

      final statsRes = await Supabase.instance.client
          .rpc('rpc_get_ambassador_stats', params: {'p_user_id': user.id});
      
      _stats = Map<String, dynamic>.from(statsRes as Map);
    } catch (e) {
      debugPrint('Error loading ambassador stats: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateCode() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _loading = true);
    final baseCode = user.email?.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '') ?? 'promo';
    final code = '${baseCode}_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    try {
      await Supabase.instance.client.from('ambassador_codes').insert({
        'user_id': user.id,
        'code': code,
      });
      await _loadData();
    } catch (e) {
      debugPrint('Error generating code: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copyLink() {
    if (_myCode == null) return;
    final link = 'https://swipess.com/join?ref=$_myCode';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied link: $link'),
        backgroundColor: AppTheme.brandPrimary,
      ),
    );
  }

  Widget _metricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF13151A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Ambassador program',
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.brandPrimary))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              children: [
                Text(
                  'YOUR AFFILIATE LINK',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.brandPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                if (_myCode == null) ...[
                  Text(
                    'You don\'t have a referral code yet. Generate one to start earning commissions when your invites make purchases.',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _generateCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'GENERATE LINK',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ] else ...[
                  GestureDetector(
                    onTap: _copyLink,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.brandPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.brandPrimary.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'swipess.com/join?ref=$_myCode',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.copy_rounded, color: AppTheme.brandPrimary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to copy and share on social media. You earn 20% commission on all purchases made by users who sign up with this link.',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'LIVE PERFORMANCE',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _metricCard(
                    'TOTAL SIGNUPS',
                    '${_stats?['total_signups'] ?? 0}',
                    Colors.white,
                  ),
                  const SizedBox(height: 16),
                  _metricCard(
                    'TOTAL REVENUE',
                    '\$${(_stats?['total_revenue_usd'] ?? 0.0).toStringAsFixed(2)}',
                    Colors.white,
                  ),
                  const SizedBox(height: 16),
                  _metricCard(
                    'PENDING PAYOUT',
                    '\$${(_stats?['unpaid_commission_usd'] ?? 0.0).toStringAsFixed(2)}',
                    const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 16),
                  _metricCard(
                    'TOTAL PAID',
                    '\$${(_stats?['paid_commission_usd'] ?? 0.0).toStringAsFixed(2)}',
                    AppTheme.brandPrimary,
                  ),
                ],
              ],
            ),
    );
  }
}
