import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/escrow/domain/escrow_deposit.dart';
import 'package:flutter_swipes/src/features/escrow/presentation/providers/escrow_provider.dart';
import 'package:flutter_swipes/src/features/legal/domain/digital_contract.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/contracts_provider.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
        backgroundColor: AppTheme.brandPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New deposit'),
      ),
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
            padding: EdgeInsets.fromLTRB(20, top + 12, 20, 100),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
                  ),
                  Text('ESCROW VAULT',
                      style: AppTheme.displayItalic.copyWith(fontSize: 22)),
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
                      Icon(Icons.shield_outlined,
                          size: 56, color: Colors.white.withAlpha(60)),
                      const SizedBox(height: 12),
                      Text(
                        'No deposits yet',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Create a deposit or wait for one from a contract.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38, fontSize: 13),
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
                    onDispute: () => ref
                        .read(escrowProvider.notifier)
                        .updateStatus(deposit.id, 'disputed'),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController();
    final counterparty = TextEditingController();
    final notes = TextEditingController();
    DigitalContract? selectedContract;
    var asOwner = true;
    var submitting = false;

    final contracts =
        ref.read(contractsProvider).value ?? const <DigitalContract>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.dashElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NEW DEPOSIT',
                        style: AppTheme.displayItalic.copyWith(fontSize: 18)),
                    const SizedBox(height: 14),
                    GlassTextField(
                      controller: amount,
                      hint: 'Amount (USD)',
                      icon: Icons.attach_money_rounded,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: counterparty,
                      hint: 'Counterparty user ID',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: notes,
                      hint: 'Notes (optional)',
                      icon: Icons.notes_rounded,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'I am the owner holding the deposit',
                        style:
                            GoogleFonts.plusJakartaSans(color: Colors.white),
                      ),
                      value: asOwner,
                      activeTrackColor: AppTheme.brandPrimary,
                      onChanged: (v) => setModal(() => asOwner = v),
                    ),
                    if (contracts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'LINK CONTRACT (OPTIONAL)',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('None'),
                            selected: selectedContract == null,
                            onSelected: (_) =>
                                setModal(() => selectedContract = null),
                            selectedColor: AppTheme.brandPrimary,
                            backgroundColor: Colors.white.withAlpha(12),
                            labelStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                            side: BorderSide(color: Colors.white.withAlpha(30)),
                          ),
                          for (final c in contracts.take(6))
                            ChoiceChip(
                              label: Text(
                                c.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                              selected: selectedContract?.id == c.id,
                              onSelected: (_) => setModal(() {
                                selectedContract = c;
                                final me = Supabase
                                    .instance.client.auth.currentUser?.id;
                                if (me != null) {
                                  final other = c.ownerId == me
                                      ? c.clientId
                                      : c.ownerId;
                                  if (other != null &&
                                      counterparty.text.trim().isEmpty) {
                                    counterparty.text = other;
                                  }
                                }
                              }),
                              selectedColor: AppTheme.brandPrimary,
                              backgroundColor: Colors.white.withAlpha(12),
                              labelStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11),
                              side: BorderSide(
                                  color: Colors.white.withAlpha(30)),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final parsed =
                                    double.tryParse(amount.text.trim());
                                final other = counterparty.text.trim();
                                if (parsed == null ||
                                    parsed <= 0 ||
                                    other.isEmpty) {
                                  return;
                                }
                                setModal(() => submitting = true);
                                try {
                                  await ref
                                      .read(escrowProvider.notifier)
                                      .createDeposit(
                                        amount: parsed,
                                        counterpartyId: other,
                                        contractId: selectedContract?.id,
                                        notes: notes.text.trim().isEmpty
                                            ? null
                                            : notes.text.trim(),
                                        asOwner: asOwner,
                                      );
                                  if (context.mounted) Navigator.pop(context);
                                } catch (e) {
                                  setModal(() => submitting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              e.toString().replaceFirst(
                                                  'Exception: ', ''))),
                                    );
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.brandPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                            submitting ? 'Creating…' : 'Create deposit'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DepositCard extends StatelessWidget {
  const _DepositCard({
    required this.deposit,
    required this.isOwner,
    required this.onHeld,
    required this.onRelease,
    required this.onDispute,
  });

  final EscrowDeposit deposit;
  final bool isOwner;
  final VoidCallback onHeld;
  final VoidCallback onRelease;
  final VoidCallback onDispute;

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
                style: TextStyle(
                    color: Colors.white.withAlpha(120), fontSize: 12),
              ),
            ],
          ),
          if (deposit.notes != null && deposit.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              deposit.notes!,
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54, fontSize: 12),
            ),
          ],
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Confirm deposit held'),
              ),
            ),
          ],
          if (deposit.status == 'held') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (isOwner)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRelease,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withAlpha(50)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                      ),
                      child: const Text('Release'),
                    ),
                  ),
                if (isOwner) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDispute,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Dispute'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
