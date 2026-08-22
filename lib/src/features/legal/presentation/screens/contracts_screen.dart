import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/legal/domain/contract_templates.dart';
import 'package:flutter_swipes/src/features/legal/domain/digital_contract.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/contracts_provider.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/contract_builder_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContractsScreen extends ConsumerStatefulWidget {
  const ContractsScreen({super.key});

  @override
  ConsumerState<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends ConsumerState<ContractsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(contractsProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final top = MediaQuery.paddingOf(context).top;
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);

    return Scaffold(
      body: AmbientPageBackground(
        fill: true,
        child: async.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: ink, strokeWidth: 2),
          ),
          error: (e, _) => Center(
            child: TextButton(
              onPressed: () => ref.read(contractsProvider.notifier).refresh(),
              child: const Text('Could not load documents — retry'),
            ),
          ),
          data: (contracts) {
            final filtered = contracts.where((c) {
              return switch (_filter) {
                'drafts' => c.isDraft,
                'waiting' => !c.isDraft && !c.isCompleted && !c.isCancelled,
                'signed' => c.isCompleted,
                _ => true,
              };
            }).toList();
            final waitingCount = contracts
                .where((c) => !c.isDraft && !c.isCompleted && !c.isCancelled)
                .length;
            final signedCount = contracts.where((c) => c.isCompleted).length;

            return RefreshIndicator(
              onRefresh: () => ref.read(contractsProvider.notifier).refresh(),
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, top + 14, 20, 130),
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: CapBackButton(),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'SWIPESS SIGN',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.brandPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'DOCUMENTS &\nE-SIGN',
                    style: AppTheme.displayItalic.copyWith(
                      color: ink,
                      fontSize: 38,
                      height: 0.95,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Choose a template or tell AI what you need. Edit it, send it to another Swipess user, sign the locked version, and keep the audit history in one vault.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          value: '${contracts.length}',
                          label: 'DOCUMENTS',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          value: '$waitingCount',
                          label: 'WAITING',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          value: '$signedCount',
                          label: 'SIGNED',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  BrandPrimaryButton(
                    label: 'Create with AI',
                    icon: Icons.auto_awesome_rounded,
                    onPressed: _createWithAi,
                  ),
                  const SizedBox(height: 10),
                  BrandPrimaryButton(
                    label: 'Choose a template',
                    icon: Icons.library_books_rounded,
                    backgroundColor: ink,
                    foregroundColor:
                        MatteSurface.isLight(context) ? Colors.white : Colors.black,
                    onPressed: () => _pickTemplate(context),
                  ),
                  const SizedBox(height: 22),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'ALL',
                          selected: _filter == 'all',
                          onTap: () => setState(() => _filter = 'all'),
                        ),
                        _FilterChip(
                          label: 'DRAFTS',
                          selected: _filter == 'drafts',
                          onTap: () => setState(() => _filter = 'drafts'),
                        ),
                        _FilterChip(
                          label: 'WAITING',
                          selected: _filter == 'waiting',
                          onTap: () => setState(() => _filter = 'waiting'),
                        ),
                        _FilterChip(
                          label: 'SIGNED',
                          selected: _filter == 'signed',
                          onTap: () => setState(() => _filter = 'signed'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (filtered.isEmpty)
                    _EmptyVault(onCreate: () => _pickTemplate(context))
                  else
                    for (final contract in filtered) ...[
                      _ContractTile(
                        contract: contract,
                        needsSign:
                            userId != null && contract.needsSignature(userId),
                        onTap: () => _openContract(contract),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openContract(DigitalContract contract) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContractBuilderScreen(contract: contract),
      ),
    );
    if (mounted) await ref.read(contractsProvider.notifier).refresh();
  }

  Future<void> _createWithAi() async {
    final template = await showModalBottomSheet<ContractTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AiDraftSheet(),
    );
    if (template == null || !mounted) return;
    try {
      final created = await ref.read(contractsProvider.notifier).create(template);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ContractBuilderScreen(contract: created),
        ),
      );
      if (mounted) await ref.read(contractsProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create AI draft: $e')),
        );
      }
    }
  }

  Future<void> _pickTemplate(BuildContext context) async {
    final template = await showModalBottomSheet<ContractTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TemplateLibrarySheet(),
    );
    if (template == null) return;
    try {
      final created = await ref.read(contractsProvider.notifier).create(template);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ContractBuilderScreen(contract: created),
        ),
      );
      if (mounted) await ref.read(contractsProvider.notifier).refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create document: $e')),
        );
      }
    }
  }
}

class _AiDraftSheet extends ConsumerStatefulWidget {
  const _AiDraftSheet();

  @override
  ConsumerState<_AiDraftSheet> createState() => _AiDraftSheetState();
}

class _AiDraftSheetState extends ConsumerState<_AiDraftSheet> {
  final _title = TextEditingController();
  final _prompt = TextEditingController();
  bool _generating = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final hairline = MatteSurface.hairline(context);
    final isLight = MatteSurface.isLight(context);
    return Container(
      padding: EdgeInsets.fromLTRB(18, 12, 18, bottom + 28),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF5F5F7) : const Color(0xFF111113),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: muted.withAlpha(60),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.brandPrimary,
                ),
                const SizedBox(width: 9),
                Text(
                  'CREATE WITH AI',
                  style: AppTheme.displayItalic.copyWith(color: ink, fontSize: 26),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Describe the agreement in normal words. AI creates an editable draft and leaves placeholders instead of inventing missing legal facts.',
              style: GoogleFonts.plusJakartaSans(
                color: muted,
                fontSize: 11,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              style: TextStyle(color: ink),
              decoration: InputDecoration(
                labelText: 'Document title (optional)',
                hintText: 'e.g. Villa rental agreement',
                labelStyle: TextStyle(color: muted),
                hintStyle: TextStyle(color: MatteSurface.faint(context)),
                filled: true,
                fillColor: MatteSurface.cardFill(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: hairline),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _prompt,
              minLines: 5,
              maxLines: 8,
              autofocus: true,
              style: TextStyle(color: ink),
              decoration: InputDecoration(
                labelText: 'Tell Swipess what you need',
                hintText:
                    'Example: I need a 6-month furnished apartment rental agreement in Tulum between an owner and tenant, USD 2,000 monthly, one-month deposit, no smoking, pets allowed…',
                labelStyle: TextStyle(color: muted),
                hintStyle: TextStyle(color: MatteSurface.faint(context)),
                filled: true,
                fillColor: MatteSurface.cardFill(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: hairline),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFFF6B64),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 16),
            BrandPrimaryButton(
              label: _generating ? 'Creating draft…' : 'Generate editable draft',
              icon: Icons.auto_awesome_rounded,
              loading: _generating,
              onPressed: _generating ? null : _generate,
            ),
            const SizedBox(height: 10),
            Text(
              'AI drafting is a convenience tool. Review local legal requirements before signing.',
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.faint(context),
                fontSize: 9,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate() async {
    final prompt = _prompt.text.trim();
    if (prompt.length < 20) {
      setState(() => _error = 'Describe the agreement with a little more detail.');
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final generated = await ref.read(aiEdgeRepositoryProvider).enhanceText(
            text: prompt,
            type: 'legal_draft',
          );
      if (!mounted) return;
      if (generated == null || generated.trim().length < 80) {
        setState(() => _error = 'AI could not create a usable draft. Try again.');
        return;
      }
      final typedTitle = _title.text.trim();
      final fallbackTitle = _guessTitle(prompt);
      final template = ContractTemplate(
        id: 'ai-custom-${DateTime.now().millisecondsSinceEpoch}',
        name: typedTitle.isEmpty ? fallbackTitle : typedTitle,
        description: 'AI-assisted editable draft created in Swipess Sign.',
        category: 'custom',
        forRole: 'both',
        content: generated.trim(),
      );
      Navigator.pop(context, template);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _guessTitle(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('nda') || lower.contains('confidential')) {
      return 'Confidentiality Agreement';
    }
    if (lower.contains('yacht') || lower.contains('charter')) {
      return 'Yacht Charter Agreement';
    }
    if (lower.contains('service') || lower.contains('worker')) {
      return 'Service Agreement';
    }
    if (lower.contains('sale') || lower.contains('purchase')) {
      return 'Purchase Agreement';
    }
    if (lower.contains('rent') || lower.contains('lease')) {
      return 'Rental Agreement';
    }
    return 'Custom Agreement';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.displayItalic.copyWith(color: ink, fontSize: 24),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: MatteSurface.muted(context),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final inverse = MatteSurface.isLight(context) ? Colors.white : Colors.black;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? ink : MatteSurface.cardFill(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: MatteSurface.hairline(context)),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: selected ? inverse : MatteSurface.muted(context),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyVault extends StatelessWidget {
  const _EmptyVault({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final muted = MatteSurface.muted(context);
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.description_outlined,
            size: 42,
            color: muted.withAlpha(100),
          ),
          const SizedBox(height: 12),
          Text(
            'YOUR DOCUMENT VAULT IS EMPTY',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onCreate, child: const Text('Choose a template')),
        ],
      ),
    );
  }
}

class _ContractTile extends StatelessWidget {
  const _ContractTile({
    required this.contract,
    required this.needsSign,
    required this.onTap,
  });

  final DigitalContract contract;
  final bool needsSign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final statusColor = contract.isCompleted
        ? const Color(0xFF22C55E)
        : contract.isDraft
        ? AppTheme.brandPrimary
        : contract.isCancelled
        ? const Color(0xFFFF6B64)
        : const Color(0xFFF59E0B);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: MatteSurface.cardFill(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: MatteSurface.hairline(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withAlpha(22),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                needsSign ? Icons.draw_rounded : Icons.description_rounded,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 14),
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
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        contract.compactStatusLabel,
                        style: GoogleFonts.plusJakartaSans(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (contract.counterpartyLabel != null) ...[
                        Text('  ·  ', style: TextStyle(color: muted)),
                        Flexible(
                          child: Text(
                            contract.counterpartyLabel!,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: muted),
          ],
        ),
      ),
    );
  }
}

class _TemplateLibrarySheet extends StatefulWidget {
  const _TemplateLibrarySheet();

  @override
  State<_TemplateLibrarySheet> createState() => _TemplateLibrarySheetState();
}

class _TemplateLibrarySheetState extends State<_TemplateLibrarySheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.86;
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final isLight = MatteSurface.isLight(context);
    final visible = contractTemplates.where((t) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return t.name.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q);
    }).toList();
    final categories = <String, List<ContractTemplate>>{};
    for (final item in visible) {
      categories.putIfAbsent(item.category, () => []).add(item);
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF5F5F7) : const Color(0xFF111113),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: MatteSurface.hairline(context))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: muted.withAlpha(60),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TEMPLATE LIBRARY',
                  style: AppTheme.displayItalic.copyWith(color: ink, fontSize: 26),
                ),
                const SizedBox(height: 5),
                Text(
                  'Start with a Swipess document, then customize it before sending.',
                  style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 11),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  style: TextStyle(color: ink),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Search lease, yacht, NDA, service…',
                    hintStyle: TextStyle(color: MatteSurface.faint(context)),
                    filled: true,
                    fillColor: MatteSurface.cardFill(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: MatteSurface.hairline(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: MatteSurface.hairline(context)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                for (final entry in categories.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                    child: Text(
                      entry.key.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                  for (final item in entry.value)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: MatteSurface.cardFill(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: MatteSurface.hairline(context)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: const Icon(
                          Icons.description_rounded,
                          color: AppTheme.brandPrimary,
                        ),
                        title: Text(
                          item.name,
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: muted,
                            fontSize: 10,
                            height: 1.35,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_rounded),
                        onTap: () => Navigator.pop(context, item),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
