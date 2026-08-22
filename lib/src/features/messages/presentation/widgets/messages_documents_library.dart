import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/legal/domain/digital_contract.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/contracts_provider.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/contract_builder_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

/// Document vault surfaced in the Inbox Documents tab.
/// Secure in-app sending is handled from an individual conversation, where the
/// recipient is first made a contract party before the attachment is sent.
class MessagesDocumentsLibrary extends ConsumerStatefulWidget {
  const MessagesDocumentsLibrary({super.key});

  @override
  ConsumerState<MessagesDocumentsLibrary> createState() =>
      _MessagesDocumentsLibraryState();
}

class _MessagesDocumentsLibraryState
    extends ConsumerState<MessagesDocumentsLibrary> {
  String _filter = 'all'; // all | signed | drafts | waiting

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(contractsProvider);
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final hairline = MatteSurface.hairline(context);
    final isLight = MatteSurface.isLight(context);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: AppTheme.brandPrimary,
          strokeWidth: 2,
        ),
      ),
      error: (e, _) => Center(
        child: TextButton(
          onPressed: () => ref.read(contractsProvider.notifier).refresh(),
          child: Text('Could not load vault — retry', style: TextStyle(color: muted)),
        ),
      ),
      data: (contracts) {
        final signedCount = contracts.where((c) => c.isCompleted).length;
        final waitingCount = contracts
            .where((c) => !c.isDraft && !c.isCompleted && !c.isCancelled)
            .length;
        final filtered = contracts.where((c) {
          return switch (_filter) {
            'signed' => c.isCompleted,
            'drafts' => c.isDraft,
            'waiting' => !c.isDraft && !c.isCompleted && !c.isCancelled,
            _ => true,
          };
        }).toList();

        return RefreshIndicator(
          onRefresh: () => ref.read(contractsProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: MatteSurface.cardFill(context),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: AppTheme.brandPrimary.withAlpha(30),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.folder_special_rounded,
                            color: AppTheme.brandPrimary,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SWIPESS SIGN',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.brandPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'DOCUMENT VAULT',
                                style: AppTheme.displayItalic.copyWith(
                                  color: ink,
                                  fontSize: 21,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Draft, sent and fully signed documents in one place. Open any item to edit, review, duplicate, sign or inspect its audit trail.',
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 11,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () {
                          AppHaptics.medium();
                          context.push(AppPaths.clientContracts);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.brandPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          'CREATE DOCUMENT',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterPill(
                      label: 'ALL',
                      selected: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'DRAFTS',
                      selected: _filter == 'drafts',
                      onTap: () => setState(() => _filter = 'drafts'),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'WAITING ($waitingCount)',
                      selected: _filter == 'waiting',
                      onTap: () => setState(() => _filter = 'waiting'),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'SIGNED ($signedCount)',
                      selected: _filter == 'signed',
                      onTap: () => setState(() => _filter = 'signed'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 44),
                  child: Column(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 46,
                        color: ink.withAlpha(45),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'NO DOCUMENTS IN THIS VIEW',
                        style: GoogleFonts.plusJakartaSans(
                          color: muted,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final contract in filtered) ...[
                  _VaultCard(contract: contract),
                  const SizedBox(height: 10),
                ],
              if (isLight) const SizedBox(height: 0),
            ],
          ),
        );
      },
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = MatteSurface.muted(context);
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brandPrimary : MatteSurface.cardFill(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppTheme.brandPrimary
                : MatteSurface.hairline(context),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: selected ? Colors.white : muted,
            fontWeight: FontWeight.w900,
            fontSize: 9,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _VaultCard extends StatelessWidget {
  const _VaultCard({required this.contract});

  final DigitalContract contract;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final hairline = MatteSurface.hairline(context);
    final statusColor = contract.isCompleted
        ? const Color(0xFF22C55E)
        : contract.isDraft
        ? AppTheme.brandPrimary
        : contract.isCancelled
        ? const Color(0xFFFF6B64)
        : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  contract.isCompleted
                      ? Icons.verified_rounded
                      : Icons.description_rounded,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contract.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      contract.compactStatusLabel,
                      style: GoogleFonts.plusJakartaSans(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 8,
                        letterSpacing: 1,
                      ),
                    ),
                    if (contract.counterpartyLabel != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        contract.counterpartyLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareCopy(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ink,
                    side: BorderSide(color: hairline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.ios_share_rounded, size: 15),
                  label: const Text('EXPORT COPY'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    AppHaptics.medium();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ContractBuilderScreen(contract: contract),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: const Text('OPEN'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _shareCopy(BuildContext context) async {
    AppHaptics.light();
    final body = contract.content?.trim();
    if (body == null || body.isEmpty) {
      await Clipboard.setData(ClipboardData(text: contract.title));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document title copied')),
        );
      }
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        text: '${contract.title}\n\n$body',
        subject: contract.title,
      ),
    );
  }
}
