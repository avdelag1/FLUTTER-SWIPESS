import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class AppReviewGuideOverlay extends StatelessWidget {
  const AppReviewGuideOverlay({
    super.key,
    required this.onClose,
    required this.onTokens,
    required this.onEventPurchase,
  });

  final VoidCallback onClose;
  final VoidCallback onTokens;
  final VoidCallback onEventPurchase;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final compact = media.size.height < 700 || media.size.width < 365;

    return Material(
      color: const Color(0xF9000000),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: EdgeInsets.all(compact ? 17 : 22),
                decoration: BoxDecoration(
                  color: const Color(0xFF101014),
                  borderRadius: BorderRadius.circular(compact ? 24 : 30),
                  border: Border.all(color: const Color(0xFF30303A)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 42,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: compact ? 38 : 44,
                          height: compact ? 38 : 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C23),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.fact_check_rounded,
                            color: Color(0xFFFFC247),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'APP REVIEW TEST GUIDE',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: compact ? 16 : 19,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.35,
                                ),
                              ),
                              Text(
                                'Prepared reviewer account · no waiting required',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.brandPrimary,
                                  fontSize: compact ? 9 : 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close guide',
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white,
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 12 : 16),
                    Text(
                      'Both iOS purchase paths are ready to test with native App Store / StoreKit purchase sheets.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFD7D7DE),
                        fontSize: compact ? 11 : 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: compact ? 12 : 16),
                    _ReviewPath(
                      number: '1',
                      icon: Icons.bolt_rounded,
                      title: 'TEST DIRECT REQUEST TOKENS',
                      detail: 'Tokens are purchased from the Profile Hub. Tap below to go to your profile, then tap the Tokens icon to open the purchase sheet.',
                      buttonLabel: 'GO TO PROFILE HUB',
                      onTap: onTokens,
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 9 : 12),
                    _ReviewPath(
                      number: '2',
                      icon: Icons.event_available_rounded,
                      title: 'TEST EVENT PROMOTION IAP',
                      detail: '“SWIPESS App Review 622” is Approved. Tap below to open Events, scroll to the "Put Your Night on the Feed" banner, and tap Request Promotion.',
                      buttonLabel: 'OPEN EVENTS FEED',
                      onTap: onEventPurchase,
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 10 : 14),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 11 : 14,
                        vertical: compact ? 9 : 11,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF17171D),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFF30303A)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            color: Color(0xFF77D9A8),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'The event demo is intentionally hidden from the public feed. A sandbox purchase verifies the transaction without publishing reviewer test content.',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFB8B8C2),
                                fontSize: compact ? 9.2 : 10.5,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewPath extends StatelessWidget {
  const _ReviewPath({
    required this.number,
    required this.icon,
    required this.title,
    required this.detail,
    required this.buttonLabel,
    required this.onTap,
    required this.compact,
  });

  final String number;
  final IconData icon;
  final String title;
  final String detail;
  final String buttonLabel;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 15),
      decoration: BoxDecoration(
        color: const Color(0xFF17171D),
        borderRadius: BorderRadius.circular(compact ? 18 : 21),
        border: Border.all(color: const Color(0xFF30303A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 31 : 35,
                height: compact ? 31 : 35,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF2D6F),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  number,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: Colors.white, size: compact ? 17 : 19),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: compact ? 10.2 : 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      maxLines: compact ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFB8B8C2),
                        fontSize: compact ? 9.2 : 10.2,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 9 : 12),
          SizedBox(
            height: compact ? 39 : 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF2D6F), Color(0xFFFF4458)],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: compact ? 10 : 11,
                    letterSpacing: .3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
