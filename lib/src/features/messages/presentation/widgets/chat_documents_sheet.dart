import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/features/documents/domain/legal_document.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/legal/domain/digital_contract.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/contracts_provider.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/document_attachment.dart';
import 'package:flutter_swipes/src/features/messages/presentation/providers/messages_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/quests_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `MessageDocumentsPanel` — vault / this chat / signed + send into thread.
Future<void> showChatDocumentsSheet(
  BuildContext context, {
  required String conversationId,
  required String otherUserName,
  required String otherUserId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ChatDocumentsSheet(
      conversationId: conversationId,
      otherUserName: otherUserName,
      otherUserId: otherUserId,
    ),
  );
}

class _ChatDocumentsSheet extends ConsumerStatefulWidget {
  const _ChatDocumentsSheet({
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserId,
  });

  final String conversationId;
  final String otherUserName;
  final String otherUserId;

  @override
  ConsumerState<_ChatDocumentsSheet> createState() =>
      _ChatDocumentsSheetState();
}

class _ChatDocumentsSheetState extends ConsumerState<_ChatDocumentsSheet> {
  /// Cap tabs: vault | thread | completed
  String _tab = 'vault';
  bool _sending = false;

  static const _rose = Color(0xFFF43F5E);

  bool _isSigned(DigitalContract c) =>
      c.status == 'signed' ||
      c.status == 'completed' ||
      c.status == 'fully_signed';

  bool _isDraft(DigitalContract c) =>
      c.status == 'draft' || c.templateType != null;

  Future<void> _sendContract(DigitalContract contract) async {
    if (_sending) return;
    setState(() => _sending = true);
    AppHaptics.medium();
    try {
      await ref
          .read(messageRepositoryProvider)
          .sendDocumentMessage(
            conversationId: widget.conversationId,
            attachment: DocumentAttachment(
              type: 'digital_contract',
              id: contract.id,
              title: contract.title,
              status: contract.status,
              templateType: contract.templateType,
            ),
          );
      ref.invalidate(conversationMessagesProvider(widget.conversationId));
      ref.read(dailyQuestsProvider.notifier).increment('message');
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendFile(LegalDocument doc) async {
    if (_sending) return;
    setState(() => _sending = true);
    AppHaptics.medium();
    try {
      await ref
          .read(messageRepositoryProvider)
          .sendDocumentMessage(
            conversationId: widget.conversationId,
            attachment: DocumentAttachment(
              type: 'vault_file',
              id: doc.id,
              title: doc.fileName,
              status: 'uploaded',
              fileName: doc.fileName,
            ),
          );
      ref.invalidate(conversationMessagesProvider(widget.conversationId));
      ref.read(dailyQuestsProvider.notifier).increment('message');
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _exportPdf(DigitalContract contract) async {
    AppHaptics.light();
    final body = contract.content?.trim();
    if (body == null || body.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No content to export')));
      return;
    }
    await Clipboard.setData(ClipboardData(text: '${contract.title}\n\n$body'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied — save outside Swipess for any business'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contractsAsync = ref.watch(contractsProvider);
    final docsAsync = ref.watch(documentsProvider);
    final messagesAsync = ref.watch(
      conversationMessagesProvider(widget.conversationId),
    );
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final hairline = MatteSurface.hairline(context);
    final isLight = MatteSurface.isLight(context);
    final height = MediaQuery.sizeOf(context).height * 0.82;

    final contracts = contractsAsync.asData?.value ?? const <DigitalContract>[];
    final files = docsAsync.asData?.value ?? const <LegalDocument>[];
    final messages = messagesAsync.asData?.value ?? const [];

    final withParty = contracts.where((c) {
      return c.clientId == widget.otherUserId ||
          c.ownerId == widget.otherUserId;
    }).toList();

    final signed = contracts.where(_isSigned).toList();

    // Cap `extractThreadDocuments` — read structured attachments, not text sniffing.
    final threadContractIds = <String>{
      for (final m in messages)
        if (m.isDocument)
          for (final att in m.attachments)
            if (att.isContract) att.id,
    };

    List<DigitalContract> listForTab() {
      if (_tab == 'vault') return contracts;
      if (_tab == 'thread') {
        return withParty
            .where((c) => threadContractIds.contains(c.id))
            .toList();
      }
      return signed;
    }

    final list = listForTab();
    final loading = contractsAsync.isLoading;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF4F4F6) : const Color(0xFF121214),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: hairline)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ink.withAlpha(40),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DOCUMENTS',
                        style: GoogleFonts.plusJakartaSans(
                          color: _rose,
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                          letterSpacing: 2.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SEND TO ${widget.otherUserName.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.displayItalic.copyWith(
                          fontSize: 18,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: isLight
                        ? Colors.white
                        : const Color(0xFF1C1C22),
                    side: BorderSide(color: hairline),
                  ),
                  icon: Icon(Icons.close_rounded, color: ink.withAlpha(200)),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _TabPill(
                  icon: Icons.folder_open_rounded,
                  label: 'MY VAULT',
                  selected: _tab == 'vault',
                  onTap: () => setState(() => _tab = 'vault'),
                ),
                const SizedBox(width: 8),
                _TabPill(
                  icon: Icons.receipt_long_rounded,
                  label: 'THIS CHAT',
                  selected: _tab == 'thread',
                  onTap: () => setState(() => _tab = 'thread'),
                ),
                const SizedBox(width: 8),
                _TabPill(
                  icon: Icons.draw_rounded,
                  label: 'SIGNED',
                  selected: _tab == 'completed',
                  onTap: () => setState(() => _tab = 'completed'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.brandPrimary,
                      strokeWidth: 2,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      if (_tab == 'vault')
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                          child: Text(
                            'Pick a lease or template from your vault — drafts, pre-filled leases, or ones already with ${widget.otherUserName}.',
                            style: GoogleFonts.plusJakartaSans(
                              color: muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      if (list.isEmpty && _tab != 'vault')
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Column(
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 40,
                                color: ink.withAlpha(40),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _tab == 'completed'
                                    ? 'NO SIGNED LEASES YET'
                                    : 'NOTHING SHARED IN THIS CHAT YET',
                                style: GoogleFonts.plusJakartaSans(
                                  color: muted,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      for (final c in list) ...[
                        _ContractRow(
                          contract: c,
                          showSend: _tab == 'vault',
                          sending: _sending,
                          isDraft: _isDraft(c),
                          isSigned: _isSigned(c),
                          onSend: () => _sendContract(c),
                          onExport: () => _exportPdf(c),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (_tab == 'vault' && files.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                          child: Text(
                            'UPLOADED FILES',
                            style: GoogleFonts.plusJakartaSans(
                              color: muted,
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                        for (final f in files.take(8)) ...[
                          _FileRow(doc: f, onShare: () => _sendFile(f)),
                          const SizedBox(height: 8),
                        ],
                      ],
                      if (_tab == 'vault' && list.isEmpty && !loading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Column(
                            children: [
                              Text(
                                'NO LEASES IN YOUR VAULT YET',
                                style: GoogleFonts.plusJakartaSans(
                                  color: muted,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  context.push(AppPaths.clientContracts);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFFB7185),
                                  side: BorderSide(color: _rose.withAlpha(90)),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text(
                                  'BUILD A LEASE',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
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
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [Color(0xFFFF4D00), Color(0xFFEB4898)])
              : null,
          color: selected ? null : MatteSurface.cardFill(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : MatteSurface.hairline(context),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: selected ? Colors.white : muted,
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

class _ContractRow extends StatelessWidget {
  const _ContractRow({
    required this.contract,
    required this.showSend,
    required this.sending,
    required this.isDraft,
    required this.isSigned,
    required this.onSend,
    required this.onExport,
  });

  final DigitalContract contract;
  final bool showSend;
  final bool sending;
  final bool isDraft;
  final bool isSigned;
  final VoidCallback onSend;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final hairline = MatteSurface.hairline(context);
    final isLight = MatteSurface.isLight(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withAlpha(200) : const Color(0xFF141418),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF43F5E).withAlpha(28),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFFFB7185),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contract.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFF43F5E).withAlpha(80),
                    ),
                    color: const Color(0xFFF43F5E).withAlpha(24),
                  ),
                  child: Text(
                    isDraft ? 'READY TO SEND' : contract.statusLabel,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFFB7185),
                      fontWeight: FontWeight.w900,
                      fontSize: 8,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              if (showSend)
                GestureDetector(
                  onTap: sending ? null : onSend,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'SEND',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isSigned) ...[
                if (showSend) const SizedBox(height: 6),
                GestureDetector(
                  onTap: onExport,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: hairline),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.download_rounded,
                          size: 12,
                          color: ink.withAlpha(160),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PDF',
                          style: GoogleFonts.plusJakartaSans(
                            color: ink.withAlpha(160),
                            fontWeight: FontWeight.w900,
                            fontSize: 8,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  _FileRow({required this.doc, required this.onShare});

  final LegalDocument doc;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final hairline = MatteSurface.hairline(context);
    final isLight = MatteSurface.isLight(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withAlpha(200) : const Color(0xFF141418),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hairline),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            color: Color(0xFF38BDF8),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              doc.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: ink,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          GestureDetector(
            onTap: onShare,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: hairline),
              ),
              alignment: Alignment.center,
              child: Text(
                'SHARE',
                style: GoogleFonts.plusJakartaSans(
                  color: ink.withAlpha(180),
                  fontWeight: FontWeight.w900,
                  fontSize: 8,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
