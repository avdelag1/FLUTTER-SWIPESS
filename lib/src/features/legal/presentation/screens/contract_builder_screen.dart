import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/legal/data/repositories/contract_repository.dart';
import 'package:flutter_swipes/src/features/legal/domain/contract_templates.dart';
import 'package:flutter_swipes/src/features/legal/domain/digital_contract.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/contracts_provider.dart';
import 'package:flutter_swipes/src/features/legal/presentation/screens/contract_sign_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Swipess Sign document workspace.
/// Drafts are editable. A successful save is required before the send sheet can
/// open. Sending locks the exact server version and signatures are checked
/// against its SHA-256 fingerprint by the backend.
class ContractBuilderScreen extends ConsumerStatefulWidget {
  const ContractBuilderScreen({super.key, required this.contract});

  final DigitalContract contract;

  @override
  ConsumerState<ContractBuilderScreen> createState() =>
      _ContractBuilderScreenState();
}

class _ContractBuilderScreenState extends ConsumerState<ContractBuilderScreen> {
  late DigitalContract _contract;
  late final TextEditingController _title;
  late final TextEditingController _content;
  final Map<String, TextEditingController> _quickFill = {};
  ContractTemplate? _template;
  bool _saving = false;
  bool _polishing = false;
  bool _cancelling = false;
  bool _quickFillOpen = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contract = widget.contract;
    _title = TextEditingController(text: _contract.title);
    _content = TextEditingController(text: _contract.content ?? '');
    _template = _findTemplate(_contract.templateType);
    final saved = _contract.metadata['quick_fill'];
    for (final field in _template?.fields ?? const <ContractTemplateField>[]) {
      _quickFill[field.key] = TextEditingController(
        text: saved is Map ? saved[field.key]?.toString() ?? '' : '',
      );
    }
    _quickFillOpen = _contract.isDraft && _quickFill.isNotEmpty;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    for (final c in _quickFill.values) {
      c.dispose();
    }
    super.dispose();
  }

  ContractTemplate? _findTemplate(String? id) {
    if (id == null) return null;
    for (final t in contractTemplates) {
      if (t.id == id) return t;
    }
    return null;
  }

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;
  bool get _editable => _userId != null && _contract.canEdit(_userId!);
  bool get _needsSignature =>
      _userId != null && _contract.needsSignature(_userId!);
  bool get _isOwner => _userId != null && _contract.isOwner(_userId!);

  Map<String, String> get _quickValues => {
    for (final e in _quickFill.entries) e.key: e.value.text.trim(),
  };

  Map<String, dynamic> get _metadata => {
    ..._contract.metadata,
    if (_template != null) 'template_category': _template!.category,
    'quick_fill': _quickValues,
  };

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final hairline = MatteSurface.hairline(context);
    final card = MatteSurface.cardFill(context);
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: AmbientPageBackground(
        fill: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, top + 14, 20, 110),
          children: [
            Row(
              children: [
                const CapBackButton(),
                const Spacer(),
                _StatusPill(contract: _contract),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'SWIPESS SIGN',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.brandPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _editable ? 'BUILD YOUR\nDOCUMENT' : 'REVIEW &\nSIGN',
              style: AppTheme.displayItalic.copyWith(
                color: ink,
                fontSize: 36,
                height: 0.95,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _editable
                  ? 'Fill, edit and AI-polish this draft. Swipess saves it before you can send it for signature.'
                  : 'This version is locked. Review the exact wording, signatures and audit history.',
              style: GoogleFonts.plusJakartaSans(
                color: muted,
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _TrustStrip(contract: _contract),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBox(message: _error!),
            ],
            if (_editable && _quickFill.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: hairline),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.bolt_rounded,
                        color: AppTheme.brandPrimary,
                      ),
                      title: Text(
                        'QUICK FILL',
                        style: GoogleFonts.plusJakartaSans(
                          color: ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      subtitle: Text(
                        'Fill the important facts once.',
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                      trailing: Icon(
                        _quickFillOpen
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: muted,
                      ),
                      onTap: () =>
                          setState(() => _quickFillOpen = !_quickFillOpen),
                    ),
                    if (_quickFillOpen)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Column(
                          children: [
                            for (final field in _template!.fields) ...[
                              _QuickFillField(
                                field: field,
                                controller: _quickFill[field.key]!,
                              ),
                              const SizedBox(height: 9),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _applyQuickFill,
                                style: FilledButton.styleFrom(
                                  backgroundColor: ink,
                                  foregroundColor: MatteSurface.isLight(context)
                                      ? Colors.white
                                      : Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.auto_fix_high_rounded),
                                label: const Text('APPLY TO DOCUMENT'),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            TextField(
              controller: _title,
              readOnly: !_editable,
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
              decoration: _inputDecoration(
                context,
                label: 'DOCUMENT TITLE',
                hint: 'Agreement title',
              ),
            ),
            const SizedBox(height: 10),
            _EditorToolbar(
              editable: _editable,
              polishing: _polishing,
              onPolish: _polish,
              onCopy: _copy,
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: hairline),
              ),
              child: TextField(
                controller: _content,
                readOnly: !_editable,
                minLines: 22,
                maxLines: null,
                style: GoogleFonts.sourceSerif4(
                  color: ink,
                  fontSize: 15,
                  height: 1.55,
                ),
                decoration: const InputDecoration(
                  hintText: 'Document terms…',
                  contentPadding: EdgeInsets.all(18),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Drafting templates and AI tools are not a substitute for jurisdiction-specific legal advice. Some transactions may require a lawyer, witness, notary or government filing.',
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.faint(context),
                fontSize: 9.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            if (_editable) ...[
              BrandPrimaryButton(
                label: _saving ? 'Saving…' : 'Save draft',
                icon: Icons.save_rounded,
                loading: _saving,
                onPressed: _saving ? null : () => _saveDraft(),
              ),
              const SizedBox(height: 9),
              BrandPrimaryButton(
                label: 'Send for signature',
                icon: Icons.send_rounded,
                backgroundColor: ink,
                foregroundColor:
                    MatteSurface.isLight(context) ? Colors.white : Colors.black,
                onPressed: _saving ? null : _sendForSignature,
              ),
            ] else ...[
              if (_needsSignature)
                BrandPrimaryButton(
                  label: 'Review & sign',
                  icon: Icons.draw_rounded,
                  onPressed: _openSignature,
                ),
              if (_needsSignature) const SizedBox(height: 9),
              if (_contract.isLocked)
                BrandPrimaryButton(
                  label: 'Duplicate to edit',
                  icon: Icons.content_copy_rounded,
                  backgroundColor: ink,
                  foregroundColor:
                      MatteSurface.isLight(context) ? Colors.white : Colors.black,
                  onPressed: _duplicate,
                ),
              if (_isOwner && !_contract.isCompleted && !_contract.isCancelled) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _cancelling ? null : _cancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(_cancelling ? 'Cancelling…' : 'Cancel document'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B64),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 28),
            Text(
              'AUDIT TRAIL',
              style: GoogleFonts.plusJakartaSans(
                color: muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            _AuditTrail(contractId: _contract.id),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    required String hint,
  }) {
    final hairline = MatteSurface.hairline(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: MatteSurface.muted(context)),
      hintStyle: TextStyle(color: MatteSurface.faint(context)),
      filled: true,
      fillColor: MatteSurface.cardFill(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: AppTheme.brandPrimary,
          width: 1.5,
        ),
      ),
    );
  }

  void _applyQuickFill() {
    if (_template == null) return;
    final missing = _template!.fields
        .where(
          (f) => f.required && (_quickFill[f.key]?.text.trim().isEmpty ?? true),
        )
        .map((f) => f.label)
        .toList();
    if (missing.isNotEmpty) {
      setState(() => _error = 'Complete: ${missing.join(', ')}');
      return;
    }
    setState(() {
      _content.text = _template!.applyValues(_quickValues);
      _error = null;
    });
    AppHaptics.success();
  }

  Future<bool> _saveDraft({bool notify = true}) async {
    if (!_editable || _saving) return false;
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty || content.length < 20) {
      setState(
        () => _error = 'Add a title and complete the document before saving.',
      );
      return false;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await ref.read(contractRepositoryProvider).saveDraft(
            contractId: _contract.id,
            title: title,
            content: content,
            metadata: _metadata,
          );
      if (!mounted) return false;
      setState(() => _contract = saved);
      await ref.read(contractsProvider.notifier).refresh();
      if (!mounted) return false;
      if (notify) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft saved securely')),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendForSignature() async {
    final saved = await _saveDraft(notify: false);
    if (!saved || !mounted || !_contract.isDraft) return;
    final sent = await showModalBottomSheet<DigitalContract>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SendForSignatureSheet(contract: _contract),
    );
    if (sent == null || !mounted) return;
    setState(() {
      _contract = sent;
      _error = null;
    });
    await ref.read(contractsProvider.notifier).refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sent to ${sent.counterpartyLabel ?? 'the other party'} for signature',
        ),
      ),
    );
  }

  Future<void> _polish() async {
    if (!_editable || _polishing) return;
    final text = _content.text.trim();
    if (text.length < 20) {
      setState(() => _error = 'Add more text before using AI Polish.');
      return;
    }
    setState(() {
      _polishing = true;
      _error = null;
    });
    try {
      final improved = await ref.read(aiEdgeRepositoryProvider).enhanceText(
            text: text,
            type: 'legal',
          );
      if (!mounted) return;
      if (improved == null || improved.trim().isEmpty) {
        setState(() => _error = 'AI Polish is temporarily unavailable.');
      } else {
        setState(() => _content.text = improved.trim());
        AppHaptics.success();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _polishing = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(text: '${_title.text.trim()}\n\n${_content.text.trim()}'),
    );
    if (!mounted) return;
    AppHaptics.light();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document copied')),
    );
  }

  Future<void> _openSignature() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContractSignScreen(contract: _contract),
      ),
    );
    if (!mounted) return;
    try {
      final fresh = await ref.read(contractRepositoryProvider).fetchById(
            _contract.id,
          );
      if (!mounted) return;
      setState(() => _contract = fresh);
      await ref.read(contractsProvider.notifier).refresh();
    } catch (_) {}
  }

  Future<void> _duplicate() async {
    try {
      final copy = await ref.read(contractsProvider.notifier).duplicate(_contract);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ContractBuilderScreen(contract: copy)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      final cancelled = await ref.read(contractRepositoryProvider).cancel(
            _contract.id,
          );
      if (!mounted) return;
      setState(() => _contract = cancelled);
      await ref.read(contractsProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30).withAlpha(18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF3B30).withAlpha(90)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFFF6B64),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _QuickFillField extends StatelessWidget {
  const _QuickFillField({required this.field, required this.controller});
  final ContractTemplateField field;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final hairline = MatteSurface.hairline(context);
    return TextField(
      controller: controller,
      maxLines: field.kind == ContractFieldKind.multiline ? 3 : 1,
      keyboardType: switch (field.kind) {
        ContractFieldKind.number =>
          const TextInputType.numberWithOptions(decimal: true),
        ContractFieldKind.date => TextInputType.datetime,
        ContractFieldKind.multiline => TextInputType.multiline,
        ContractFieldKind.text => TextInputType.text,
      },
      style: TextStyle(color: MatteSurface.ink(context), fontSize: 13),
      decoration: InputDecoration(
        labelText: '${field.label}${field.required ? ' *' : ''}',
        hintText: field.placeholder,
        labelStyle: TextStyle(color: MatteSurface.muted(context)),
        hintStyle: TextStyle(color: MatteSurface.faint(context)),
        filled: true,
        fillColor: MatteSurface.cardFill(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: hairline),
        ),
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.editable,
    required this.polishing,
    required this.onPolish,
    required this.onCopy,
  });
  final bool editable;
  final bool polishing;
  final VoidCallback onPolish;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final hairline = MatteSurface.hairline(context);
    Widget action(IconData icon, String label, VoidCallback onTap) {
      return OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: hairline),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (editable)
          action(
            Icons.auto_awesome_rounded,
            polishing ? 'POLISHING…' : 'AI POLISH',
            onPolish,
          ),
        action(Icons.copy_all_rounded, 'COPY', onCopy),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.contract});
  final DigitalContract contract;

  @override
  Widget build(BuildContext context) {
    final color = contract.isCompleted
        ? const Color(0xFF22C55E)
        : contract.isCancelled
        ? const Color(0xFFFF6B64)
        : contract.isDraft
        ? AppTheme.brandPrimary
        : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        contract.compactStatusLabel,
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip({required this.contract});
  final DigitalContract contract;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final items = <(IconData, String)>[
      (
        contract.isLocked ? Icons.lock_rounded : Icons.edit_outlined,
        contract.isLocked ? 'LOCKED VERSION' : 'EDITABLE DRAFT',
      ),
      (Icons.history_rounded, 'AUDIT TRAIL'),
      (Icons.fingerprint_rounded, 'SHA-256'),
    ];
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: MatteSurface.cardFill(context),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: MatteSurface.hairline(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.$1, size: 13, color: ink),
                const SizedBox(width: 5),
                Text(
                  item.$2,
                  style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SendForSignatureSheet extends ConsumerStatefulWidget {
  const _SendForSignatureSheet({required this.contract});
  final DigitalContract contract;

  @override
  ConsumerState<_SendForSignatureSheet> createState() =>
      _SendForSignatureSheetState();
}

class _SendForSignatureSheetState
    extends ConsumerState<_SendForSignatureSheet> {
  final _query = TextEditingController();
  List<ContractPartyMatch> _matches = const [];
  bool _searching = false;
  String? _sendingId;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final hairline = MatteSurface.hairline(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
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
            Text(
              'SEND FOR SIGNATURE',
              style: AppTheme.displayItalic.copyWith(color: ink, fontSize: 26),
            ),
            const SizedBox(height: 6),
            Text(
              'Find the other Swipess user by exact email, @username or full name. Sending locks this saved version.',
              style: GoogleFonts.plusJakartaSans(
                color: muted,
                fontSize: 11,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _query,
              autofocus: true,
              onSubmitted: (_) => _search(),
              style: TextStyle(color: ink),
              decoration: InputDecoration(
                hintText: 'Email, @username or full name',
                hintStyle: TextStyle(color: MatteSurface.faint(context)),
                filled: true,
                fillColor: MatteSurface.cardFill(context),
                suffixIcon: IconButton(
                  onPressed: _searching ? null : _search,
                  icon: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search_rounded),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide(color: hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide(color: hairline),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 9),
              _ErrorBox(message: _error!),
            ],
            if (_matches.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final match in _matches)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: MatteSurface.cardFill(context),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: hairline),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.brandPrimary.withAlpha(28),
                      child: Text(
                        match.displayName.isEmpty
                            ? 'S'
                            : match.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.brandPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Text(
                      match.displayName,
                      style: TextStyle(color: ink, fontWeight: FontWeight.w900),
                    ),
                    subtitle: match.username == null
                        ? null
                        : Text('@${match.username}', style: TextStyle(color: muted)),
                    trailing: _sendingId == match.userId
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    onTap: _sendingId == null ? () => _send(match) : null,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _matches = const [];
      _error = null;
    });
    try {
      final matches = await ref.read(contractRepositoryProvider).resolveCounterparty(q);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        if (matches.isEmpty) {
          _error = 'No active Swipess user matched that exact search.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _send(ContractPartyMatch match) async {
    setState(() {
      _sendingId = match.userId;
      _error = null;
    });
    try {
      final sent = await ref.read(contractRepositoryProvider).sendForSignature(
            contractId: widget.contract.id,
            clientId: match.userId,
          );
      if (!mounted) return;
      AppHaptics.success();
      Navigator.pop(context, sent);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _sendingId = null);
    }
  }
}

class _AuditTrail extends ConsumerWidget {
  const _AuditTrail({required this.contractId});
  final String contractId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final hairline = MatteSurface.hairline(context);
    return FutureBuilder<List<ContractEvent>>(
      future: ref.read(contractRepositoryProvider).fetchEvents(contractId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final events = snapshot.data ?? const <ContractEvent>[];
        if (events.isEmpty) {
          return Text(
            'History appears here as the document is edited, sent and signed.',
            style: TextStyle(color: muted, fontSize: 11),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: MatteSurface.cardFill(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: hairline),
          ),
          child: Column(
            children: [
              for (var i = 0; i < events.length; i++) ...[
                ListTile(
                  dense: true,
                  leading: Icon(
                    events[i].eventType == 'signed'
                        ? Icons.verified_rounded
                        : events[i].eventType == 'sent'
                        ? Icons.send_rounded
                        : events[i].eventType == 'cancelled'
                        ? Icons.cancel_outlined
                        : Icons.history_rounded,
                    color: events[i].eventType == 'signed'
                        ? const Color(0xFF22C55E)
                        : ink,
                    size: 19,
                  ),
                  title: Text(
                    events[i].label,
                    style: TextStyle(color: ink, fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    events[i].createdAt.toLocal().toString().split('.').first,
                    style: TextStyle(color: muted, fontSize: 10),
                  ),
                ),
                if (i != events.length - 1)
                  Divider(height: 1, indent: 52, color: hairline),
              ],
            ],
          ),
        );
      },
    );
  }
}
