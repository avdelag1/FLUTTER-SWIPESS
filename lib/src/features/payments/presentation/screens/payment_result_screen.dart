import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/subscriptions/domain/subscription_tier.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Payment result with entitlement-aware confirmation. It never promises a
/// benefit the backend has not granted: live subscription/token providers are
/// the source of truth shown to the user.
class PaymentResultScreen extends ConsumerWidget {
  const PaymentResultScreen({super.key, required this.success, this.message});

  final bool success;
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider).value;
    final balance = ref.watch(directRequestBalanceProvider).value?.available;
    final tier = subscription?.tier ?? SubscriptionTier.free;
    final paid = tier != SubscriptionTier.free;
    final included = paid ? tier.initialTokens : null;

    return NeoNaiveScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
              const Spacer(),
              Icon(
                success ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: success
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
                size: 82,
              ),
              const SizedBox(height: 22),
              Text(
                success ? 'PREMIUM ACTIVATED' : 'PAYMENT CANCELLED',
                textAlign: TextAlign.center,
                style: AppTheme.displayItalic.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 12),
              Text(
                message ??
                    (success
                        ? 'Your verified benefits are live now.'
                        : 'No charge was completed. You can retry anytime from Premium.'),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (success && paid) ...[
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171B22),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Benefit(
                        text: included == null
                            ? 'Direct Requests included'
                            : '$included Direct Requests included with this plan',
                      ),
                      if (balance != null)
                        _Benefit(text: '$balance Direct Requests available now'),
                      const _Benefit(text: 'AI + AI Listing Creator'),
                      const _Benefit(text: 'Legal access & lawyer tools'),
                      const _Benefit(text: 'Events discovery & access'),
                      _Benefit(
                        text: tier == SubscriptionTier.premium
                            ? 'Maximum listing capacity & Premium visibility'
                            : 'Up to ${tier.maxListings} active listings',
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              BrandPrimaryButton(
                label: success ? 'Back to Swipess' : 'Try again later',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
