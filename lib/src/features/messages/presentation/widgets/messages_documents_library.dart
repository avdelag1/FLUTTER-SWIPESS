import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/features/legal/domain/digital_contract.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/contracts_provider.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/contract_sign_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

/// Cap `MessagesDocumentsLibrary` — Business vault inside Inbox Documents tab.
class MessagesDocumentsLibrary extends ConsumerStatefulWidget {
  const MessagesDocumentsLibrary({super.key});

  @override
  ConsumerState<MessagesDocumentsLibrary> createState() =>
      _MessagesDocumentsLibraryState();
}

class _MessagesDocumentsLibraryState
    extends ConsumerState<MessagesDocumentsLibrary> {
  String _filter = 'all'; // all | signed | drafts

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
        final signedCount =
            contracts.where((c) => _isSigned(c.status)).length;
        final filtered = contracts.where((c) {
          if (_filter == 'signed') return _isSigned(c.status);
          if (_filter == 'drafts') {
            return c.status == 'draft' || c.templateType != null;
          }
          return true;
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isLight
                    ? Colors.white.withAlpha(200)
                    : const Color(0xFF141418),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF43F5E).withAlpha(40),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.folder_special_rounded,
                          color: Color(0xFFFB7185),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BUSINESS VAULT',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFFB7185),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'YOUR LEASES & DOCUMENTS',
                              style: AppTheme.displayItalic.copyWith(
                                fontSize: 20,
                                height: 1.05,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Completed leases, templates, and vault files. Export or open — send straight from any chat.',
                              style: GoogleFonts.plusJakartaSans(
                                color: muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            AppHaptics.medium();
                            context.push(AppPaths.clientContracts);
                          },
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'NEW LEASE FROM TEMPLATE',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                    label: 'SIGNED ($signedCount)',
                    selected: _filter == 'signed',
                    onTap: () => setState(() => _filter = 'signed'),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'TEMPLATES',
                    selected: _filter == 'drafts',
                    onTap: () => setState(() => _filter = 'drafts'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.description_outlined,
                        size: 48, color: ink.withAlpha(40)),
                    const SizedBox(height: 14),
                    Text(
                      _filter == 'signed'
                          ? 'NO SIGNED LEASES YET'
                          : 'NO DOCUMENTS IN VAULT',
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final c in filtered) ...[
                _VaultCard(contract: c),
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }

  bool _isSigned(String status) =>
      status == 'signed' || status == 'completed' || status == 'fully_signed';
}

class _FilterPill extends StatelessWidget {
  _FilterPill({
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
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
                )
              : null,
          color: selected ? null : MatteSurface.cardFill(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : MatteSurface.hairline(context),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: selected ? Colors.white : muted,
            fontWeight: FontWeight.w900,
            fontSize: 9,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _VaultCard extends StatelessWidget {
  _VaultCard({required this.contract});
  final DigitalContract contract;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final hairline = MatteSurface.hairline(context);
    final isLight = MatteSurface.isLight(context);
    final label = contract.statusLabel;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withAlpha(180) : const Color(0xFF141418),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF43F5E).withAlpha(28),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Color(0xFFFB7185), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contract.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFFF43F5E).withAlpha(80),
                        ),
                        color: const Color(0xFFF43F5E).withAlpha(24),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFFB7185),
                          fontWeight: FontWeight.w900,
                          fontSize: 8,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  label: 'SHARE',
                  icon: Icons.ios_share_rounded,
                  onTap: () {
                    AppHaptics.light();
                    final body = contract.content?.trim();
                    SharePlus.instance.share(
                      ShareParams(
                        text: (body == null || body.isEmpty)
                            ? contract.title
                            : '${contract.title}\n\n$body',
                        subject: contract.title,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  label: 'OPEN',
                  icon: Icons.open_in_new_rounded,
                  accent: true,
                  onTap: () {
                    AppHaptics.medium();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ContractSignScreen(contract: contract),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (muted.a > 0) const SizedBox(height: 0),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: accent
              ? Color(0xFFF43F5E).withAlpha(36)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent
                ? Color(0xFFF43F5E).withAlpha(90)
                : MatteSurface.hairline(context),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: accent ? const Color(0xFFFB7185) : ink.withAlpha(180),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: accent ? const Color(0xFFFB7185) : ink.withAlpha(180),
                fontWeight: FontWeight.w900,
                fontSize: 9,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
