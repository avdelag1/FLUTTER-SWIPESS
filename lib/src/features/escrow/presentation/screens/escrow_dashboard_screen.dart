import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
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

    return NeoNaiveScaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
        foregroundColor: Colors.white,
        icon: Icon(Icons.add_rounded),
        label: Text('New deposit'),
      ),
      body: async.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: MatteSurface.ink(context), strokeWidth: 2),
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
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: MatteSurface.ink(context)),
                  ),
                  Text('ESCROW VAULT',
                      style: AppTheme.displayItalic.copyWith(fontSize: 22)),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Track and manage security deposits from contracts.',
                style: GoogleFonts.plusJakartaSans(color: MatteSurface.muted(context)),
              ),
              const SizedBox(height: 20),
              _EscrowMetrics(deposits: deposits),
              const SizedBox(height: 20),
              if (deposits.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Column(
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 56, color: Colors.transparent),
                      SizedBox(height: 12),
                      Text(
                        'No deposits yet',
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.muted(context),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Create a deposit or wait for one from a contract.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                            color: MatteSurface.faint(context), fontSize: 13),
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
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'I am the owner holding the deposit',
                            style: GoogleFonts.plusJakartaSans(
                              color: MatteSurface.ink(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        CupertinoSwitch(
                          value: asOwner,
                          activeTrackColor: AppTheme.brandPrimary,
                          onChanged: (v) => setModal(() => asOwner = v),
                        ),
                      ],
                    ),
                    if (contracts.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text(
                        'LINK CONTRACT (OPTIONAL)',
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.muted(context),
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
                          NeoNaiveChip(
                            label: 'None',
                            selected: selectedContract == null,
                            onSelected: () =>
                                setModal(() => selectedContract = null),
                            selectedColor: AppTheme.brandPrimary,
                          ),
                          for (final c in contracts.take(6))
                            NeoNaiveChip(
                              label: c.title,
                              selected: selectedContract?.id == c.id,
                              onSelected: () => setModal(() {
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
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    BrandPrimaryButton(
                      label: submitting ? 'Creating…' : 'Create deposit',
                      loading: submitting,
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

class _EscrowMetrics extends StatelessWidget {
  const _EscrowMetrics({required this.deposits});
  final List<EscrowDeposit> deposits;

  @override
  Widget build(BuildContext context) {
    double sum(String status) => deposits
        .where((d) => d.status == status)
        .fold(0, (a, d) => a + d.amount);
    final held = sum('held');
    final released = sum('released');
    final pending = deposits.where((d) => d.status == 'pending').length;
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'HELD',
            value: '\$${held.toStringAsFixed(0)}',
            color: const Color(0xFF4DABF7),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: 'RELEASED',
            value: '\$${released.toStringAsFixed(0)}',
            color: const Color(0xFFFB7185),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: 'PENDING',
            value: '$pending',
            color: const Color(0xFFFBBF24),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withAlpha(70)),
        boxShadow: [
          BoxShadow(color: color.withAlpha(28), blurRadius: 18),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.ink(context),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
        ],
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
        return const Color(0xFFFB7185);
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
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MatteSurface.ink(context), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                child: Icon(_icon, color: _color, size: 18),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deposit.amountLabel,
                      style: TextStyle(
                        color: MatteSurface.ink(context),
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
                    color: MatteSurface.muted(context), fontSize: 12),
              ),
            ],
          ),
          if (deposit.notes != null && deposit.notes!.isNotEmpty) ...[
            SizedBox(height: 10),
            Text(
              deposit.notes!,
              style: GoogleFonts.plusJakartaSans(
                  color: MatteSurface.muted(context), fontSize: 12),
            ),
          ],
          SizedBox(height: 14),
          Text(
            'Created → Held → Released',
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.muted(context),
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
