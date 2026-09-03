import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/native/privacy_screen.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/screens/document_vault_screen.dart';
import 'package:flutter_swipes/src/features/documents/presentation/widgets/document_preview_dialog.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';
import 'package:flutter_swipes/src/features/profile/domain/vap_card_themes.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_id_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/themed_vap_card.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/vap_id_photo_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showVapIdModal(BuildContext context) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'VAP ID',
    barrierColor: Colors.black54,
    pageBuilder: (context, anim1, anim2) {
      return FadeTransition(opacity: anim1, child: const VapIdScreen());
    },
  );
}

class VapIdScreen extends ConsumerStatefulWidget {
  const VapIdScreen({super.key, this.initialEdit = false});

  final bool initialEdit;

  @override
  ConsumerState<VapIdScreen> createState() => _VapIdScreenState();
}

class _VapIdScreenState extends ConsumerState<VapIdScreen> {
  bool _handledEditRequest = false;
  bool _editing = false;
  bool _saving = false;
  bool _seeded = false;

  final _name = TextEditingController();
  final _occupation = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController();
  final _bio = TextEditingController();
  final _years = TextEditingController();

  @override
  void initState() {
    super.initState();
    PrivacyScreen.enable();
  }

  @override
  void dispose() {
    PrivacyScreen.disable();
    _name.dispose();
    _occupation.dispose();
    _city.dispose();
    _country.dispose();
    _bio.dispose();
    _years.dispose();
    super.dispose();
  }

  void _seedEditors(VapIdCard card) {
    if (_seeded) return;
    _seeded = true;
    _name.text = card.name ?? '';
    _occupation.text = card.occupation ?? '';
    _city.text = card.city ?? '';
    _country.text = card.country ?? '';
    _bio.text = card.bio ?? '';
    _years.text = card.yearsInCity?.toString() ?? '';
  }

  void _startEdit(VapIdCard card) {
    _seeded = false;
    _seedEditors(card);
    if (!_editing) setState(() => _editing = true);
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _seeded = false;
    });
  }

  Future<void> _saveEdit(VapIdCard card) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final latest = ref.read(vapIdProvider).value ?? card;
      await ref
          .read(vapIdProvider.notifier)
          .save(
            latest.copyWith(
              name: _name.text.trim(),
              occupation: _occupation.text.trim(),
              city: _city.text.trim(),
              country: _country.text.trim(),
              bio: _bio.text.trim(),
              yearsInCity: int.tryParse(_years.text),
            ),
          );
      if (!mounted) return;
      setState(() {
        _editing = false;
        _seeded = false;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vapIdProvider);
    final docs = ref.watch(documentsProvider);
    final userId = ref.watch(currentUserProvider)?.id ?? 'resident';
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF08090D),
      body: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: ColoredBox(
          color: const Color(0xFF08090D),
          child: async.when(
            loading: () => Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            error: (e, _) => Center(
              child: TextButton(
                onPressed: () => ref.read(vapIdProvider.notifier).refresh(),
                child: Text(
                  t(ref, 'flutter.vapRetry', 'Could not load PEARL — retry'),
                ),
              ),
            ),
            data: (card) {
              final data = card ?? VapIdCard(userId: userId);
              final slice = userId.length >= 8
                  ? userId.substring(0, 8)
                  : userId;
              final idNumber = 'NX-${slice.toUpperCase()}';
              final validationUrl = 'https://swipess.com/vap-validate/$userId';

              final editRequested =
                  widget.initialEdit ||
                  GoRouterState.of(context).uri.queryParameters['edit'] == '1';
              if (editRequested && !_handledEditRequest) {
                _handledEditRequest = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _startEdit(data);
                });
              }

              if (_editing) {
                _seedEditors(data);
                return _buildEditor(context, data, top: top, bottom: bottom);
              }

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, top + 16, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'PEARL',
                            textAlign: TextAlign.left,
                            maxLines: 1,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.6,
                            ),
                          ),
                        ),
                        _PearlRoundBtn(
                          icon: Icons.folder_copy_outlined,
                          tooltip: 'Documents',
                          onTap: () => _openDocuments(context),
                        ),
                        SizedBox(width: 6),
                        _PearlRoundBtn(
                          icon: Icons.edit_outlined,
                          tooltip: 'Edit Virtual ID',
                          onTap: () => _startEdit(data),
                        ),
                        SizedBox(width: 6),
                        _PearlRoundBtn(
                          icon: Icons.close_rounded,
                          tooltip: 'Close',
                          onTap: () => NavBack.popOrGo(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(0, 0, 0, bottom),
                      child: ThemedVapCard(
                        theme: VapCardTheme.themes.first,
                        data: data,
                        idNumber: idNumber,
                        validationUrl: validationUrl,
                        docsAsync: docs,
                        onPreview: (doc) =>
                            showDocumentPreviewDialog(context, doc),
                        onManageDocuments: () => _openDocuments(context),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(
    BuildContext context,
    VapIdCard card, {
    required double top,
    required double bottom,
  }) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, top + 12, 20, bottom + 32),
        children: [
          Row(
            children: [
              _PearlRoundBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: 'Back to card',
                onTap: _cancelEdit,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PEARL / VIRTUAL ID',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.7,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'EDIT YOUR ID',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              _PearlRoundBtn(
                icon: Icons.folder_copy_outlined,
                tooltip: 'Documents',
                onTap: () => _openDocuments(context),
              ),
            ],
          ),
          SizedBox(height: 22),
          Text(
            'IDENTITY PHOTO',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 8),
          VapIdPhotoPicker(card: card),
          SizedBox(height: 22),
          Text(
            'CARD INFORMATION',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 10),
          GlassTextField(
            controller: _name,
            hint: 'Name',
            icon: Icons.person_rounded,
          ),
          SizedBox(height: 10),
          GlassTextField(
            controller: _occupation,
            hint: 'Occupation',
            icon: Icons.work_rounded,
          ),
          SizedBox(height: 10),
          GlassTextField(
            controller: _city,
            hint: 'City',
            icon: Icons.location_city_rounded,
          ),
          SizedBox(height: 10),
          GlassTextField(
            controller: _country,
            hint: 'Country',
            icon: Icons.public_rounded,
          ),
          SizedBox(height: 10),
          GlassTextField(
            controller: _years,
            hint: 'Years in city',
            keyboardType: TextInputType.number,
            icon: Icons.timelapse_rounded,
          ),
          SizedBox(height: 10),
          GlassTextField(
            controller: _bio,
            hint: 'Bio',
            icon: Icons.notes_rounded,
            maxLines: 3,
          ),
          SizedBox(height: 18),
          BrandPrimaryButton(
            label: _saving
                ? t(ref, 'flutter.saving', 'SAVING…')
                : t(ref, 'flutter.vapSave', 'SAVE CARD'),
            loading: _saving,
            onPressed: _saving ? null : () => _saveEdit(card),
          ),
          SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _openDocuments(context),
              icon: Icon(Icons.upload_file_rounded),
              label: Text('UPLOAD / MANAGE DOCUMENTS'),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Your Virtual ID photo is separate from your normal profile photo. Uploaded verification documents remain private.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDocuments(BuildContext context) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    await rootNavigator.push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const DocumentVaultScreen(),
      ),
    );
    if (mounted) {
      await ref.read(documentsProvider.notifier).refresh();
    }
  }
}

class _PearlRoundBtn extends StatelessWidget {
  const _PearlRoundBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(child: Icon(icon, size: 18, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
