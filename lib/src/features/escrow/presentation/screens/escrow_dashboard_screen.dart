import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
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

    return NeoNaiveScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESCROW VAULT',
                  style: AppTheme.displayItalic.copyWith(fontSize: 24),
                ),
                SizedBox(height: 5),
                Text(
                  'Track security deposits connected to your Swipess contracts.',
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.muted(context),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _showCreateSheet(context, ref),
                    icon: Icon(Icons.add_rounded, size: 19),
                    label: Text('New deposit'),
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: MatteSurface.ink(context),
                      strokeWidth: 2,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Loading deposits…',
                      style: GoogleFonts.plusJakartaSans(
                        color: MatteSurface.muted(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        color: MatteSurface.muted(context),
                        size: 34,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Could not load escrow deposits.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: MatteSurface.ink(context),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(escrowProvider.notifier).refresh(),
                        icon: Icon(Icons.refresh_rounded),
                        label: Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (deposits) => RefreshIndicator(
                color: AppTheme.brandPrimary,
                onRefresh: () => ref.read(escrowProvider.notifier).refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 36),
                  children: [
                    _EscrowMetrics(deposits: deposits),
                    SizedBox(height: 18),
                    if (deposits.isEmpty)
                      const _EmptyEscrow()
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
                        SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ),
          ),
        ],
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
    String? formError;

    final contracts =
        ref.read(contractsProvider).value ?? const <DigitalContract>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModal) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEW DEPOSIT',
                    style: AppTheme.displayItalic.copyWith(fontSize: 20),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Link it to a contract when possible so both people see the same record.',
                    style: GoogleFonts.plusJakartaSans(
                      color: MatteSurface.muted(context),
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 16),
                  GlassTextField(
                    controller: amount,
                    hint: 'Amount (USD)',
                    icon: Icons.attach_money_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  SizedBox(height: 10),
                  GlassTextField(
                    controller: counterparty,
                    hint: 'Other Swipess user ID',
                    icon: Icons.person_outline_rounded,
                  ),
                  SizedBox(height: 10),
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
                            fontSize: 12,
                          ),
                        ),
                      ),
                      CupertinoSwitch(
                        value: asOwner,
                        activeTrackColor: AppTheme.brandPrimary,
                        onChanged: (value) =>
                            setModal(() => asOwner = value),
                      ),
                    ],
                  ),
                  if (contracts.isNotEmpty) ...[
                    SizedBox(height: 14),
                    Text(
                      'LINK CONTRACT',
                      style: GoogleFonts.plusJakartaSans(
                        color: MatteSurface.muted(context),
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text('None'),
                          selected: selectedContract == null,
                          onSelected: (_) =>
                              setModal(() => selectedContract = null),
                        ),
                        for (final contract in contracts.take(8))
                          ChoiceChip(
                            label: Text(contract.title),
                            selected: selectedContract?.id == contract.id,
                            onSelected: (_) {
                              setModal(() => selectedContract = contract);
                              final me = Supabase
                                  .instance
                                  .client
                                  .auth
                                  .currentUser
                                  ?.id;
                              if (me == null) return;
                              final other = contract.ownerId == me
                                  ? contract.clientId
                                  : contract.ownerId;
                              if (other != null &&
                                  counterparty.text.trim().isEmpty) {
                                counterparty.text = other;
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                  if (formError != null) ...[
                    SizedBox(height: 12),
                    Text(
                      formError!,
                      style: TextStyle(
                        color: Color(0xFFF87171),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  SizedBox(height: 18),
                  BrandPrimaryButton(
                    label: submitting ? 'Creating…' : 'Create deposit',
                    loading: submitting,
                    onPressed: submitting
                        ? null
                        : () async {
                            final parsed = double.tryParse(amount.text.trim());
                            final other = counterparty.text.trim();
                            if (parsed == null || parsed <= 0) {
                              setModal(() => formError = 'Enter a valid amount.');
                              return;
                            }
                            if (other.isEmpty) {
                              setModal(
                                () => formError =
                                    'Choose a contract or enter the other Swipess user ID.',
                              );
                              return;
                            }
                            setModal(() {
                              submitting = true;
                              formError = null;
                            });
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
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            } catch (error) {
                              if (!sheetContext.mounted) return;
                              setModal(() {
                                submitting = false;
                                formError = error
                                    .toString()
                                    .replaceFirst('Exception: ', '');
                              });
                            }
                          },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    amount.dispose();
    counterparty.dispose();
    notes.dispose();
  }
}

class _EmptyEscrow extends StatelessWidget {
  const _EmptyEscrow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.shield_outlined,
            size: 46,
            color: MatteSurface.muted(context),
          ),
          SizedBox(height: 12),
          Text(
            'No deposits yet',
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.ink(context),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Create one above or link it to an existing contract.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.muted(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EscrowMetrics extends StatelessWidget {
  const _EscrowMetrics({required this.deposits});
  final List<EscrowDeposit> deposits;

  @override
  Widget build(BuildContext context) {
    double sum(String status) => deposits
        .where((deposit) => deposit.status == status)
        .fold(0, (total, deposit) => total + deposit.amount);
    final held = sum('held');
    final released = sum('released');
    final pending = deposits.where((d) => d.status == 'pending').length;

    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'HELD',
            value: '\$${held.toStringAsFixed(0)}',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'RELEASED',
            value: '\$${released.toStringAsFixed(0)}',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _MetricTile(label: 'PENDING', value: '$pending'),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.muted(context),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.ink(context),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
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

  Color get _statusColor {
    switch (deposit.status) {
      case 'held':
        return const Color(0xFF4DABF7);
      case 'released':
        return const Color(0xFF34D399);
      case 'disputed':
        return const Color(0xFFF87171);
      default:
        return const Color(0xFFFBBF24);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  deposit.amountLabel,
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.ink(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  deposit.status.toUpperCase(),
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 5),
          Text(
            DateFormat.yMMMd().add_jm().format(deposit.createdAt.toLocal()),
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.muted(context),
              fontSize: 11,
            ),
          ),
          if ((deposit.notes ?? '').trim().isNotEmpty) ...[
            SizedBox(height: 10),
            Text(
              deposit.notes!,
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.muted(context),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          if (isOwner && deposit.status == 'pending') ...[
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onHeld,
                child: Text('Confirm deposit held'),
              ),
            ),
          ],
          if (deposit.status == 'held') ...[
            SizedBox(height: 12),
            Row(
              children: [
                if (isOwner) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRelease,
                      child: Text('Release'),
                    ),
                  ),
                  SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDispute,
                    child: Text('Dispute'),
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
