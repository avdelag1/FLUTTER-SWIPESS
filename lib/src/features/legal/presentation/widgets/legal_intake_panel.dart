import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/legal/data/legal_repository.dart';
import 'package:flutter_swipes/src/features/legal/domain/legal_intake.dart';
import 'package:flutter_swipes/src/features/legal/domain/legal_service_package.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/legal_providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showLegalIntakeSheet(
  BuildContext context, {
  LegalServicePackage? pkg,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LegalIntakeSheet(pkg: pkg),
  );
}

class LegalIntakeList extends ConsumerWidget {
  const LegalIntakeList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myLegalIntakesProvider);
    final intakes = async.value ?? const <LegalIntake>[];
    if (intakes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR REQUESTS',
          style: SwipessTokens.kickerUppercase(
            color: MatteSurface.ink(context).withAlpha(140),
          ),
        ),
        const SizedBox(height: 12),
        for (final intake in intakes) ...[
          _IntakeCard(intake: intake),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _IntakeCard extends ConsumerWidget {
  const _IntakeCard({required this.intake});
  final LegalIntake intake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final repo = ref.read(legalRepositoryProvider);

    Future<void> refresh() => ref.refresh(myLegalIntakesProvider.future);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2029),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(42), width: 1.15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            intake.headline.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            intake.statusLabel,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.brandPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          if (intake.quotedPrice != null) ...[
            const SizedBox(height: 4),
            Text(
              '\$${intake.quotedPrice!.toStringAsFixed(0)}',
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
          if ((intake.lawyerNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              intake.lawyerNotes!,
              style: GoogleFonts.plusJakartaSans(
                color: muted,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          if ((intake.declineReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              intake.declineReason!,
              style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 13),
            ),
          ],
          if (intake.consultAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Consult: ${_fmt(intake.consultAt!)}',
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (intake.canPay && intake.quotedPrice != null)
                _PillButton(
                  label: 'Pay with PayPal',
                  filled: true,
                  onTap: () async {
                    AppHaptics.medium();
                    final uri = LegalRepository.paypalCheckout(
                      itemName: intake.headline,
                      amount: intake.quotedPrice!,
                    );
                    try {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {}
                  },
                ),
              if (intake.canPay)
                _PillButton(
                  label: 'I paid',
                  onTap: () async {
                    try {
                      await repo.confirmPayment(intake.id);
                      AppHaptics.medium();
                      await refresh();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not confirm payment yet.'),
                          ),
                        );
                      }
                    }
                  },
                ),
              if (intake.canJoinCall)
                _PillButton(
                  label: 'Join consult',
                  filled: true,
                  onTap: () async {
                    final user = ref.read(currentUserProvider);
                    final name = user?.email ?? 'Client';
                    final room = LegalRepository.consultRoom(intake.id);
                    final uri = Uri.parse(LegalRepository.jitsiUrl(room, name));
                    AppHaptics.medium();
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              if (intake.canCancel)
                _PillButton(
                  label: 'Cancel',
                  onTap: () async {
                    await repo.cancelIntake(intake.id);
                    await refresh();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final am = local.hour >= 12 ? 'PM' : 'AM';
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day}  $h:$m $am';
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.white : const Color(0xFF222833),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(42)),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: filled ? Colors.black : Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalIntakeSheet extends ConsumerStatefulWidget {
  const _LegalIntakeSheet({this.pkg});
  final LegalServicePackage? pkg;

  @override
  ConsumerState<_LegalIntakeSheet> createState() => _LegalIntakeSheetState();
}

class _LegalIntakeSheetState extends ConsumerState<_LegalIntakeSheet> {
  final _situation = TextEditingController();
  final _city = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  late String _category;
  bool _loading = false;
  bool _success = false;
  String? _error;

  static const _cats = [
    ('rental', 'Rental'),
    ('house_sale', 'Property sale'),
    ('eviction', 'Eviction'),
    ('dispute', 'Dispute'),
    ('divorce', 'Family'),
    ('nda', 'NDA'),
    ('business', 'Business'),
    ('estate', 'Estate'),
  ];

  @override
  void initState() {
    super.initState();
    _category = widget.pkg?.category ?? 'rental';
    final user = ref.read(currentUserProvider);
    _email.text = user?.email ?? '';
    if (user != null) {
      ref
          .read(legalRepositoryProvider)
          .fetchProfilePrefill(user.id, user.email)
          .then((p) {
            if (!mounted) return;
            setState(() {
              if (p.fullName.isNotEmpty) _name.text = p.fullName;
              if (p.email.isNotEmpty) _email.text = p.email;
              if (p.phone.isNotEmpty) _phone.text = p.phone;
            });
          });
    }
  }

  @override
  void dispose() {
    _situation.dispose();
    _city.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(currentUserProvider) == null) {
      setState(() => _error = 'Sign in to request a lawyer.');
      return;
    }
    if (_situation.text.trim().length < 12) {
      setState(
        () => _error = 'Tell the lawyer what happened, in a few sentences.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(legalRepositoryProvider)
          .submitIntake(
            packageId: widget.pkg?.id,
            packageName: widget.pkg?.name,
            packageCategory: _category,
            quotedPrice: widget.pkg?.price,
            situation: _situation.text.trim(),
            city: _city.text.trim(),
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
          );
      AppHaptics.medium();
      ref.invalidate(myLegalIntakesProvider);
      if (mounted) setState(() => _success = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send the request. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final ink = MatteSurface.ink(context);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF141820),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: _success
              ? Column(
                  children: [
                    const SizedBox(height: 12),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Request sent',
                      style: GoogleFonts.plusJakartaSans(
                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A lawyer will review this first. If they can take it, you will see a price here — pay only after they accept. No live ringing.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: MatteSurface.muted(context),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Need a lawyer',
                      style: GoogleFonts.plusJakartaSans(
                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Describe the situation. A lawyer reviews it, then sends a yes and a price. You pay only if you accept.',
                      style: GoogleFonts.plusJakartaSans(
                        color: MatteSurface.muted(context),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in _cats)
                          ChoiceChip(
                            label: Text(c.$2),
                            selected: _category == c.$1,
                            onSelected: (_) => setState(() => _category = c.$1),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _situation,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: _field('What happened?'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _city,
                      style: const TextStyle(color: Colors.white),
                      decoration: _field('City'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _name,
                      style: const TextStyle(color: Colors.white),
                      decoration: _field('Your name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phone,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      decoration: _field('Phone'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFF87171)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        child: Text(_loading ? 'Sending…' : 'Send to lawyers'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  InputDecoration _field(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white),
      filled: true,
      fillColor: const Color(0xFF10141B),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withAlpha(42)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.brandPrimary),
      ),
    );
  }
}
