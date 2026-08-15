import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/legal/domain/digital_contract.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/contracts_provider.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/contract_sign_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContractsScreen extends ConsumerWidget {
  const ContractsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(contractsProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: AmbientPageBackground(
        fill: true,
        child: async.when(
          loading: () => Center(
            child: CircularProgressIndicator(
              color: MatteSurface.ink(context),
              strokeWidth: 2,
            ),
          ),
          error: (e, _) => Center(
            child: TextButton(
              onPressed: () => ref.read(contractsProvider.notifier).refresh(),
              child: const Text('Could not load contracts — retry'),
            ),
          ),
          data: (contracts) {
            return ListView(
              padding: EdgeInsets.fromLTRB(24, top + 24, 24, 140),
              children: [
                Align(alignment: Alignment.centerLeft, child: CapBackButton()),
                SizedBox(height: 24),
                Text(
                  'CONTRACTS',
                  style: AppTheme.displayItalic.copyWith(fontSize: 32),
                ),
                SizedBox(height: 8),
                Text(
                  'Create contracts and sign with your finger.',
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.muted(context),
                  ),
                ),
                SizedBox(height: 24),
                BrandPrimaryButton(
                  label: 'New contract',
                  icon: Icons.edit_document,
                  onPressed: () => _pickTemplate(context, ref),
                ),
                SizedBox(height: 28),
                if (contracts.isEmpty)
                  Text(
                    'No contracts yet. Start from a template, then sign it here.',
                    style: GoogleFonts.plusJakartaSans(
                      color: MatteSurface.muted(context),
                    ),
                  )
                else
                  for (final contract in contracts) ...[
                    _ContractTile(
                      contract: contract,
                      needsSign:
                          userId != null && contract.needsSignature(userId),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ContractSignScreen(contract: contract),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickTemplate(BuildContext context, WidgetRef ref) async {
    final template = await showModalBottomSheet<ContractTemplate>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TEMPLATES',
                style: AppTheme.displayItalic.copyWith(fontSize: 20),
              ),
              SizedBox(height: 12),
              for (final item in contractTemplates)
                ListTile(
                  title: Text(
                    item.name,
                    style: TextStyle(
                      color: MatteSurface.ink(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    item.description,
                    style: TextStyle(color: MatteSurface.muted(context)),
                  ),
                  onTap: () => Navigator.pop(context, item),
                ),
            ],
          ),
        );
      },
    );
    if (template == null) return;
    try {
      final created = await ref
          .read(contractsProvider.notifier)
          .create(template);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ContractSignScreen(contract: created),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create contract: $e')),
        );
      }
    }
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
    return GestureDetector(
      onTap: () {
        AppHaptics.medium();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: MatteSurface.ink(context), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.description_rounded, color: MatteSurface.ink(context)),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contract.title,
                    style: TextStyle(
                      color: MatteSurface.ink(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    contract.statusLabel,
                    style: TextStyle(
                      color: needsSign ? AppTheme.brandPrimary : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              needsSign ? Icons.draw_rounded : Icons.chevron_right_rounded,
              color: MatteSurface.muted(context),
            ),
          ],
        ),
      ),
    );
  }
}
