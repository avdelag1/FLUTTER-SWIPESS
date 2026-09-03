import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Apple-review-only shortcut for the event promotion IAP products.
///
/// The reviewer must not hunt through Events or wait for moderation. This sheet
/// resolves the real pre-approved review submission UUID, shows all three promo
/// products immediately, and opens StoreKit directly from the selected product.
class AppReviewEventPurchaseSheet extends ConsumerStatefulWidget {
  const AppReviewEventPurchaseSheet({super.key});

  @override
  ConsumerState<AppReviewEventPurchaseSheet> createState() =>
      _AppReviewEventPurchaseSheetState();
}

class _AppReviewEventPurchaseSheetState
    extends ConsumerState<AppReviewEventPurchaseSheet> {
  String? _submissionId;
  String? _buyingId;
  String? _message;
  bool _loading = true;
  bool _purchaseVerified = false;

  @override
  void initState() {
    super.initState();
    _loadReviewSubmission();
  }

  Future<void> _loadReviewSubmission() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null ||
        user.email?.trim().toLowerCase() != 'applereview@swipess.com') {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'This shortcut is available only to the prepared App Review account.';
      });
      return;
    }

    try {
      final rows = await client
          .from('business_promo_submissions')
          .select('id, status, title')
          .eq('user_id', user.id)
          .eq('is_review_demo', true)
          .order('created_at', ascending: false)
          .limit(1);

      final list = rows as List;
      if (list.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _message = 'The prepared App Review promotion could not be found.';
        });
        return;
      }

      final row = Map<String, dynamic>.from(list.first as Map);
      final status = row['status']?.toString();
      if (status != 'approved') {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _message = 'The prepared App Review promotion is not ready for purchase.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _submissionId = row['id']?.toString();
        _loading = false;
        _message = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Could not load the prepared purchase: $error';
      });
    }
  }

  Future<void> _buy(IapOffer offer) async {
    if (_buyingId != null) return;
    final submissionId = _submissionId;
    if (submissionId == null || submissionId.isEmpty) {
      setState(() => _message = 'The prepared App Review purchase is not ready yet.');
      return;
    }

    if (!IapCatalog.usesNativeStore) {
      setState(() {
        _message =
            'The three products are ready. Open this same reviewer account in the iOS review build to launch the native App Store purchase sheet.';
      });
      return;
    }

    setState(() {
      _buyingId = offer.id;
      _message = null;
      _purchaseVerified = false;
    });

    try {
      final result = await ref
          .read(paymentServiceProvider)
          .buy(offer, contextId: submissionId);
      if (!mounted) return;

      setState(() {
        if (result.isSuccess) {
          _purchaseVerified = true;
          _message = 'App Store purchase verified successfully.';
        } else {
          _message = result.userMessage;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Purchase could not be completed: $error');
    } finally {
      if (mounted) setState(() => _buyingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.92;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: Color(0xFF0D0D11),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EVENT PROMOTION PURCHASES',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.25,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Prepared App Review demo · no Events navigation · no moderation wait',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFFF416D),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2C2C34)),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: EdgeInsets.fromLTRB(18, 18, 18, 28),
                        children: [
                          Text(
                            'Choose any package below. On iPhone/iPad, the button immediately opens Apple’s native App Store in-app purchase sheet.',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFD8D8DF),
                              fontSize: 12.5,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 16),
                          for (final offer in IapCatalog.eventPromos) ...[
                            _ReviewPromoCard(
                              offer: offer,
                              buying: _buyingId == offer.id,
                              enabled: _submissionId != null && _buyingId == null,
                              onBuy: () => _buy(offer),
                            ),
                            SizedBox(height: 12),
                          ],
                          if (_message != null) ...[
                            SizedBox(height: 2),
                            Container(
                              padding: EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: _purchaseVerified
                                    ? const Color(0xFF0F2A20)
                                    : const Color(0xFF21161A),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _purchaseVerified
                                      ? const Color(0xFF2D9C69)
                                      : const Color(0xFF5A2A37),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _purchaseVerified
                                        ? Icons.verified_rounded
                                        : Icons.info_outline_rounded,
                                    color: _purchaseVerified
                                        ? const Color(0xFF5EE2A0)
                                        : const Color(0xFFFF7B9A),
                                    size: 19,
                                  ),
                                  SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      _message!,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 11,
                                        height: 1.35,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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

class _ReviewPromoCard extends StatelessWidget {
  const _ReviewPromoCard({
    required this.offer,
    required this.buying,
    required this.enabled,
    required this.onBuy,
  });

  final IapOffer offer;
  final bool buying;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final nativeIos =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF17171D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: offer.popular
              ? const Color(0xFFFF416D)
              : const Color(0xFF33333D),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  offer.name.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (offer.popular)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF416D),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'POPULAR',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: offer.priceLabel,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: ' ${offer.durationLabel ?? ''}',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFB8B8C2),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (offer.description != null) ...[
            SizedBox(height: 4),
            Text(
              offer.description!,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFB8B8C2),
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: enabled ? onBuy : null,
              icon: buying
                  ? SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.apple, size: 21),
              label: Text(
                buying
                    ? 'OPENING APP STORE…'
                    : nativeIos
                    ? 'BUY WITH APPLE · ${offer.priceLabel}'
                    : 'APPLE IAP · ${offer.priceLabel}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .15,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFF3A3A40),
                disabledForegroundColor: const Color(0xFFB8B8C2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          SizedBox(height: 7),
          Center(
            child: Text(
              nativeIos
                  ? 'Native StoreKit purchase sheet'
                  : 'Native StoreKit opens in the iOS review build',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF8F8F99),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
