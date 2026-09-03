import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/legal/domain/contract_templates.dart';
import 'package:flutter_swipes/src/features/legal/domain/legal_service_package.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/contracts_provider.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/legal_providers.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/contract_builder_screen.dart';
import 'package:flutter_swipes/src/features/legal/presentation/widgets/legal_intake_panel.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Legal is a service/document hub, never a swipe-discovery category.
///
/// The first actions are lawyer connection, followed immediately by ready-made
/// lease templates. A template tap creates a draft and opens the full Swipess
/// Sign editor directly; users do not have to hunt through another screen.
class LawyerServicesScreen extends ConsumerStatefulWidget {
  const LawyerServicesScreen({super.key});

  @override
  ConsumerState<LawyerServicesScreen> createState() =>
      _LawyerServicesScreenState();
}

class _LawyerServicesScreenState extends ConsumerState<LawyerServicesScreen> {
  String _category = 'all';
  String? _creatingTemplateId;

  static const _order = [
    'house_sale',
    'rental',
    'eviction',
    'dispute',
    'business',
    'nda',
    'estate',
    'divorce',
  ];

  static const _meta = <String, (String, IconData)>{
    'house_sale': ('Property', Icons.apartment_rounded),
    'rental': ('Rentals', Icons.home_rounded),
    'eviction': ('Eviction', Icons.gavel_rounded),
    'divorce': ('Family', Icons.favorite_border_rounded),
    'nda': ('NDA', Icons.lock_outline_rounded),
    'business': ('Business', Icons.work_outline_rounded),
    'dispute': ('Disputes', Icons.scale_rounded),
    'estate': ('Estate', Icons.account_balance_rounded),
  };

  static const _fallback = [
    LegalServicePackage(
      id: 'preview-lease-review',
      name: 'Residential Lease Review',
      category: 'rental',
      price: 149,
      durationDays: 3,
      description: 'Review rent, deposit, cancellation, house rules, obligations and risk clauses.',
    ),
    LegalServicePackage(
      id: 'preview-lease-draft',
      name: 'Custom Lease Draft',
      category: 'rental',
      price: 249,
      durationDays: 5,
      description: 'Lawyer-assisted residential or furnished lease adapted to the facts you provide.',
    ),
    LegalServicePackage(
      id: 'preview-deposit',
      name: 'Deposit / Rent Dispute',
      category: 'dispute',
      price: 129,
      durationDays: 3,
      description: 'Review a security-deposit, rent, fee or landlord/tenant dispute and next-step options.',
    ),
    LegalServicePackage(
      id: 'preview-eviction',
      name: 'Eviction Consultation',
      category: 'eviction',
      price: 199,
      durationDays: 3,
      description: 'Initial review of notices, non-payment, breach, timelines and local process.',
    ),
    LegalServicePackage(
      id: 'preview-sale',
      name: 'Property Purchase / Sale Review',
      category: 'house_sale',
      price: 299,
      durationDays: 7,
      description: 'Contract, title-document and closing-risk review for a property purchase or sale.',
    ),
    LegalServicePackage(
      id: 'preview-nda',
      name: 'NDA & Confidentiality Review',
      category: 'nda',
      price: 89,
      durationDays: 2,
      description:
          'Review or adapt confidentiality terms for two people or businesses.',
    ),
    LegalServicePackage(
      id: 'preview-business',
      name: 'Business Agreement Review',
      category: 'business',
      price: 199,
      durationDays: 4,
      description: 'Review a service, contractor, partnership or basic commercial agreement.',
    ),
    LegalServicePackage(
      id: 'preview-estate',
      name: 'Estate Planning Consultation',
      category: 'estate',
      price: 249,
      durationDays: 7,
      description: 'Initial estate-planning consultation and document checklist for your situation.',
    ),
  ];

  List<ContractTemplate> get _leaseTemplates {
    final leases = contractTemplates
        .where((template) => template.category.toLowerCase() == 'lease')
        .toList(growable: false);
    if (leases.length <= 8) return leases;
    return leases.take(8).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(legalServicePackagesProvider);
    final packages = async.value ?? const <LegalServicePackage>[];
    final live = packages.isEmpty ? _fallback : packages;
    final present = live.map((p) => p.category).toSet();
    final user = ref.watch(currentUserProvider);
    final isLight = MatteSurface.isLight(context);
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final hairline = MatteSurface.hairline(context);
    final top = MediaQuery.paddingOf(context).top;

    final cats = [
      ('all', 'ALL', Icons.grid_view_rounded),
      for (final id in _order)
        if (present.contains(id))
          (
            id,
            (_meta[id]?.$1 ?? id).toUpperCase(),
            _meta[id]?.$2 ?? Icons.scale_rounded,
          ),
    ];
    final visible = _category == 'all'
        ? live
        : live.where((p) => p.category == _category).toList();

    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, top + 12, 20, 120),
        children: [
          Row(
            children: [
              const CapBackButton(),
              SizedBox(width: 12),
              Text(
                'LEGAL',
                style: SwipessTokens.kickerUppercase(color: ink.withAlpha(170)),
              ),
            ],
          ),
          SizedBox(height: 22),
          Text(
            'LEGAL HELP.\nCREATE. EDIT. SIGN.',
            style: SwipessTokens.displayItalic(color: ink, fontSize: 30),
          ),
          SizedBox(height: 9),
          Text(
            'Connect with legal support, request a service, or open a ready-made document and edit it like a dedicated document app.',
            style: SwipessTokens.bodyClean(color: muted, fontSize: 13),
          ),
          SizedBox(height: 24),

          _SectionLabel('CONNECT TO A LAWYER', ink: ink),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ConnectCard(
                  icon: Icons.videocam_rounded,
                  title: 'VIDEO CALL',
                  subtitle: 'Live lawyer connection',
                  accent: const Color(0xFF6366F1),
                  onTap: () => _showUnavailable('Video Call'),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _ConnectCard(
                  icon: Icons.chat_rounded,
                  title: 'WHATSAPP',
                  subtitle: 'Legal support chat',
                  accent: const Color(0xFF25D366),
                  onTap: () => _showUnavailable('WhatsApp'),
                ),
              ),
            ],
          ),
          SizedBox(height: 22),

          // This is intentionally directly below WhatsApp/Video Call.
          _SectionLabel('CREATE A LEASE', ink: ink),
          SizedBox(height: 5),
          Text(
            'Choose an example. It opens as a real editable draft — Quick Fill, full text editing, AI Polish, PDF/Word export, sharing and e-sign are available inside.',
            style: SwipessTokens.bodyClean(color: muted, fontSize: 11.5),
          ),
          SizedBox(height: 12),
          SizedBox(
            height: 164,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _leaseTemplates.length,
              separatorBuilder: (_, __) => SizedBox(width: 10),
              itemBuilder: (context, index) {
                final template = _leaseTemplates[index];
                return _LeaseTemplateCard(
                  template: template,
                  loading: _creatingTemplateId == template.id,
                  onTap: () => _openLease(template),
                );
              },
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: user == null
                      ? null
                      : () => context.push(AppPaths.clientContracts),
                  icon: Icon(Icons.library_books_rounded, size: 18),
                  label: Text('ALL DOCUMENTS'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    side: BorderSide(color: hairline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 9),
              Expanded(
                child: FilledButton.icon(
                  onPressed: user == null
                      ? null
                      : () => context.push(AppPaths.clientContracts),
                  icon: Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text('CREATE WITH AI'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEB4898),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .6,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 30),

          _SectionLabel('LEGAL SERVICES · PREVIEW PRICES', ink: ink),
          SizedBox(height: 5),
          Text(
            'Request now. The lawyer network is not live yet, so requests can remain pending until an independent lawyer becomes available.',
            style: SwipessTokens.bodyClean(color: muted, fontSize: 11.5),
          ),
          SizedBox(height: 11),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: cats.length,
              separatorBuilder: (_, __) => SizedBox(width: 8),
              itemBuilder: (context, index) {
                final c = cats[index];
                final selected = _category == c.$1;
                return GestureDetector(
                  onTap: () {
                    AppHaptics.selection();
                    setState(() => _category = c.$1);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? ink
                          : (isLight
                                ? Colors.black.withAlpha(8)
                                : Colors.white.withAlpha(10)),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected ? Colors.transparent : hairline,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          c.$3,
                          size: 14,
                          color: selected
                              ? (isLight ? Colors.white : Colors.black)
                              : ink.withAlpha(170),
                        ),
                        SizedBox(width: 6),
                        Text(
                          c.$2,
                          style: GoogleFonts.plusJakartaSans(
                            color: selected
                                ? (isLight ? Colors.white : Colors.black)
                                : ink.withAlpha(180),
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                            letterSpacing: .7,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16),
          for (final pkg in visible) ...[
            _LegalServiceCard(
              package: pkg,
              onRequest: () {
                AppHaptics.medium();
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sign in to request legal help.'),
                    ),
                  );
                  return;
                }
                showLegalIntakeSheet(context, pkg: pkg);
              },
            ),
            SizedBox(height: 10),
          ],
          SizedBox(height: 12),
          const LegalIntakeList(),
        ],
      ),
    );
  }

  Future<void> _openLease(ContractTemplate template) async {
    if (_creatingTemplateId != null) return;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to create a document.')),
      );
      return;
    }

    AppHaptics.medium();
    setState(() => _creatingTemplateId = template.id);
    try {
      final created = await ref
          .read(contractsProvider.notifier)
          .create(template);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ContractBuilderScreen(contract: created),
        ),
      );
      if (mounted) await ref.read(contractsProvider.notifier).refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open this lease: $error')),
      );
    } finally {
      if (mounted) setState(() => _creatingTemplateId = null);
    }
  }

  Future<void> _showUnavailable(String channel) async {
    AppHaptics.medium();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final ink = MatteSurface.ink(sheetContext);
        final muted = MatteSurface.muted(sheetContext);
        return SafeArea(
          child: Container(
            margin: EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: EdgeInsets.fromLTRB(20, 14, 20, 22),
            decoration: BoxDecoration(
              color: MatteSurface.canvas(sheetContext),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: MatteSurface.hairline(sheetContext)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withAlpha(50),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                SizedBox(height: 20),
                Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFF6366F1),
                  size: 34,
                ),
                SizedBox(height: 12),
                Text(
                  '$channel',
                  textAlign: TextAlign.center,
                  style: SwipessTokens.displayItalic(color: ink, fontSize: 22),
                ),
                SizedBox(height: 8),
                Text(
                  'There is no live lawyer network connected yet. Your Legal service requests and Swipess Sign documents still work; this connection channel will activate when lawyers are available.',
                  textAlign: TextAlign.center,
                  style: SwipessTokens.bodyClean(color: muted, fontSize: 12),
                ),
                SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text('GOT IT'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.ink});
  final String label;
  final Color ink;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: SwipessTokens.kickerUppercase(color: ink.withAlpha(145)),
  );
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        height: 116,
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MatteSurface.cardFill(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: MatteSurface.hairline(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(28),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 19),
                ),
                const Spacer(),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: muted,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaseTemplateCard extends StatelessWidget {
  const _LeaseTemplateCard({
    required this.template,
    required this.loading,
    required this.onTap,
  });

  final ContractTemplate template;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return SizedBox(
      width: 218,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: loading ? null : onTap,
        child: Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MatteSurface.cardFill(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: MatteSurface.hairline(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit_document,
                    color: Color(0xFFEB4898),
                    size: 20,
                  ),
                  const Spacer(),
                  Text(
                    'EDITABLE',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFEB4898),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 11),
              Text(
                template.name.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: ink,
                  fontSize: 13,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Expanded(
                child: Text(
                  template.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    fontSize: 9.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    loading ? 'OPENING…' : 'OPEN & EDIT',
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                  const Spacer(),
                  if (loading)
                    SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    )
                  else
                    Icon(Icons.arrow_forward_rounded, color: ink, size: 17),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalServiceCard extends StatelessWidget {
  const _LegalServiceCard({required this.package, required this.onRequest});

  final LegalServicePackage package;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  package.name.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '~${package.durationDays}D',
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 7),
          Text(
            package.description ?? '',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: Text(
                  '\$${package.price.toInt()} USD · PREVIEW',
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              FilledButton(
                onPressed: onRequest,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text('REQUEST'),
              ),
            ],
          ),
          SizedBox(height: 5),
          Text(
            'Final scope and fee are confirmed by the independent lawyer.',
            style: GoogleFonts.plusJakartaSans(
              color: muted.withAlpha(160),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
