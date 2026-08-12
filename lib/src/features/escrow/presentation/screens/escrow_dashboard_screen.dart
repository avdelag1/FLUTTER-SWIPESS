import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/escrow/domain/escrow_deposit.dart';
import 'package:flutter_swipes/src/features/escrow/presentation/providers/escrow_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EscrowDashboardScreen extends ConsumerWidget {
  const EscrowDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(escrowProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.read(escrowProvider.notifier).refresh(),
            child: const Text('Could not load escrow — retry'),
          ),
        ),
        data: (deposits) {
          return ListView(
            padding: EdgeInsets.fromLTRB(20, top + 12, 20, 40),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  ),
                  Text('ESCROW VAULT', style: AppTheme.displayItalic.copyWith(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Track and manage security deposits from contracts.',
                style: GoogleFonts.plusJakartaSans(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              if (deposits.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Column(
                    children: [
                      Icon(Icons.shield_outlined, size: 56, color: Colors.white.withAlpha(60)),
                      const SizedBox(height: 12),
                      Text(
                        'No deposits yet',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Escrow deposits appear when created through contracts.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                for (final deposit in deposits) ...[
                  _DepositCard(
                    deposit: deposit,
                    isOwner: deposit.ownerId == userId,
                    onHeld: () => ref
                        .read(escrowProvider.notifier)
                        .updateStatus(deposit.id, 'held'),
                    onRelease: () => ref
                        .read(escrowProvider.notifier)
                        .updateStatus(deposit.id, 'released'),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _DepositCard extends StatelessWidget {
  const _DepositCard({
    required this.deposit,
    required this.isOwner,
    required this.onHeld,
    required this.onRelease,
  });

  final EscrowDeposit deposit;
  final bool isOwner;
  final VoidCallback onHeld;
  final VoidCallback onRelease;

  Color get _color {
    switch (deposit.status) {
      case 'held':
        return const Color(0xFF4DABF7);
      case 'released':
        return const Color(0xFFFC567E);
      case 'disputed':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFFBBF24);
    }
  }

  IconData get _icon {
    switch (deposit.status) {
      case 'held':
        return Icons.shield_rounded;
      case 'released':
        return Icons.check_circle_rounded;
      case 'disputed':
        return Icons.warning_amber_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _color.withAlpha(40),
                child: Icon(_icon, color: _color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deposit.amountLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      deposit.status.toUpperCase(),
                      style: TextStyle(
                        color: _color,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat.MMMd().format(deposit.createdAt.toLocal()),
                style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Created → Held → Released',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isOwner && deposit.status == 'pending') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onHeld,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Confirm deposit held'),
              ),
            ),
          ],
          if (isOwner && deposit.status == 'held') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRelease,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withAlpha(50)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Release deposit'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
