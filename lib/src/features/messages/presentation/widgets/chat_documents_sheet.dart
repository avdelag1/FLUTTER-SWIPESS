import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/documents/domain/legal_document.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/legal/data/repositories/contract_repository.dart';
import 'package:flutter_swipes/src/features/legal/domain/digital_contract.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/contracts_provider.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/document_attachment.dart';
import 'package:flutter_swipes/src/features/messages/presentation/providers/messages_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/quests_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Secure document picker for a conversation.
///
/// A digital contract is never attached to a chat unless the other user is
/// already a contract party or a draft is first assigned to them through the
/// audited send-for-signature RPC. This keeps chat sharing and contract RLS in
/// sync instead of leaking an attachment the recipient cannot open.
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
  String _tab = 'vault'; // vault | thread | signed
  String? _sendingId;
  String? _error;

  bool _isSigned(DigitalContract c) => c.isCompleted;

  Future<void> _sendContract(DigitalContract contract) async {
    if (_sendingId != null) return;
    setState(() {
      _sendingId = contract.id;
      _error = null;
    });
    AppHaptics.medium();

    try {
      DigitalContract shared = contract;
      final alreadyParty =
          contract.clientId == widget.otherUserId ||
          contract.ownerId == widget.otherUserId;

      if (!alreadyParty) {
        if (!contract.isDraft) {
          throw Exception(
            'This document is already assigned or signed. Duplicate it in Swipess Sign before sending it to another person.',
          );
        }
        shared = await ref
            .read(contractRepositoryProvider)
            .sendForSignature(
              contractId: contract.id,
              clientId: widget.otherUserId,
            );
        await ref.read(contractsProvider.notifier).refresh();
      }

      await ref
          .read(messageRepositoryProvider)
          .sendDocumentMessage(
            conversationId: widget.conversationId,
            attachment: DocumentAttachment(
              type: 'digital_contract',
              id: shared.id,
              title: shared.title,
              status: shared.status,
              templateType: shared.templateType,
            ),
          );
      ref.invalidate(conversationMessagesProvider(widget.conversationId));
      ref.read(dailyQuestsProvider.notifier).increment('message');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shared.isCompleted
                ? 'Signed document shared in this chat'
                : 'Document sent to ${widget.otherUserName} for signature',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _sendingId = null);
    }
  }

  Future<void> _sendFile(LegalDocument doc) async {
    if (_sendingId != null) return;
    setState(() {
      _sendingId = doc.id;
      _error = null;
    });
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
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _sendingId = null);
    }
  }

  Future<void> _copyContract(DigitalContract contract) async {
    final body = contract.content?.trim();
    if (body == null || body.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: '${contract.title}\n\n$body'));
    if (!mounted) return;
    AppHaptics.light();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Document text copied')));
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
    final height = MediaQuery.sizeOf(context).height * 0.84;

    final contracts = contractsAsync.asData?.value ?? const <DigitalContract>[];
    final files = docsAsync.asData?.value ?? const <LegalDocument>[];
    final messages = messagesAsync.asData?.value ?? const [];

    final threadContractIds = <String>{
      for (final m in messages)
        if (m.isDocument)
          for (final att in m.attachments)
            if (att.isContract) att.id,
    };
    final withParty = contracts
        .where(
          (c) =>
              c.clientId == widget.otherUserId ||
              c.ownerId == widget.otherUserId,
        )
        .toList();
    final signed = contracts.where(_isSigned).toList();

    List<DigitalContract> listForTab() {
      switch (_tab) {
        case 'thread':
          return withParty
              .where((c) => threadContractIds.contains(c.id))
              .toList();
        case 'signed':
          return signed;
        default:
          return contracts;
      }
    }

    final list = listForTab();

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF5F5F7) : const Color(0xFF111113),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: hairline)),
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
            padding: const EdgeInsets.fromLTRB(20, 14, 10, 10),
            child: Row(
              children: [
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
                        'SHARE WITH ${widget.otherUserName.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.displayItalic.copyWith(
                          color: ink,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: ink),
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
                  icon: Icons.forum_outlined,
                  label: 'THIS CHAT',
                  selected: _tab == 'thread',
                  onTap: () => setState(() => _tab = 'thread'),
                ),
                const SizedBox(width: 8),
                _TabPill(
                  icon: Icons.verified_rounded,
                  label: 'SIGNED',
                  selected: _tab == 'signed',
                  onTap: () => setState(() => _tab = 'signed'),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withAlpha(18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFF3B30).withAlpha(90),
                  ),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFF6B64),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: contractsAsync.isLoading
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
                            'Drafts are securely assigned to ${widget.otherUserName} before they are attached. Already-assigned documents cannot be silently reassigned.',
                            style: GoogleFonts.plusJakartaSans(
                              color: muted,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      if (list.isEmpty)
                        _EmptyState(
                          label: _tab == 'signed'
                              ? 'NO SIGNED DOCUMENTS YET'
                              : _tab == 'thread'
                              ? 'NO DOCUMENTS IN THIS CHAT YET'
                              : 'NO DOCUMENTS IN YOUR VAULT',
                          showCreate: _tab == 'vault',
                          onCreate: () {
                            Navigator.pop(context);
                            context.push(AppPaths.clientContracts);
                          },
                        ),
                      for (final contract in list) ...[
                        _ContractRow(
                          contract: contract,
                          sending: _sendingId == contract.id,
                          otherUserId: widget.otherUserId,
                          onSend: () => _sendContract(contract),
                          onCopy: () => _copyContract(contract),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (_tab == 'vault' && files.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
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
                        for (final file in files.take(10)) ...[
                          _FileRow(
                            doc: file,
                            sending: _sendingId == file.id,
                            onShare: () => _sendFile(file),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.brandPrimary
              : MatteSurface.cardFill(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppTheme.brandPrimary
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
                letterSpacing: 1.2,
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
    required this.sending,
    required this.otherUserId,
    required this.onSend,
    required this.onCopy,
  });

  final DigitalContract contract;
  final bool sending;
  final String otherUserId;
  final VoidCallback onSend;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final hairline = MatteSurface.hairline(context);
    final alreadyParty =
        contract.clientId == otherUserId || contract.ownerId == otherUserId;
    final canShare = alreadyParty || contract.isDraft;
    final statusColor = contract.isCompleted
        ? const Color(0xFF22C55E)
        : contract.isDraft
        ? AppTheme.brandPrimary
        : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withAlpha(24),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              contract.isCompleted
                  ? Icons.verified_rounded
                  : Icons.description_rounded,
              color: statusColor,
              size: 21,
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
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alreadyParty
                      ? contract.compactStatusLabel
                      : contract.isDraft
                      ? 'ASSIGN & SEND'
                      : 'ASSIGNED ELSEWHERE',
                  style: GoogleFonts.plusJakartaSans(
                    color: canShare ? statusColor : muted,
                    fontWeight: FontWeight.w900,
                    fontSize: 8,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy document text',
            onPressed: onCopy,
            icon: Icon(Icons.copy_rounded, size: 18, color: muted),
          ),
          FilledButton.icon(
            onPressed: canShare && !sending ? onSend : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.brandPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: sending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 14),
            label: const Text(
              'SEND',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.doc,
    required this.sending,
    required this.onShare,
  });

  final LegalDocument doc;
  final bool sending;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final hairline = MatteSurface.hairline(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MatteSurface.cardFill(context),
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
          TextButton.icon(
            onPressed: sending ? null : onShare,
            icon: sending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 14),
            label: const Text('SHARE'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.label,
    required this.showCreate,
    required this.onCreate,
  });

  final String label;
  final bool showCreate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final muted = MatteSurface.muted(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.description_outlined,
            size: 42,
            color: muted.withAlpha(60),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 1.3,
            ),
          ),
          if (showCreate) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('CREATE DOCUMENT'),
            ),
          ],
        ],
      ),
    );
  }
}
