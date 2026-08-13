import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/documents/domain/legal_document.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/messages/presentation/providers/messages_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/quests_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `MessageDocumentsPanel` — vault files into this chat.
Future<void> showChatDocumentsSheet(
  BuildContext context, {
  required String conversationId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ChatDocumentsSheet(conversationId: conversationId),
  );
}

class _ChatDocumentsSheet extends ConsumerWidget {
  const _ChatDocumentsSheet({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(documentsProvider);
    final height = MediaQuery.sizeOf(context).height * 0.62;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFF121214),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                Text(
                  'DOCUMENTS',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
              error: (e, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(documentsProvider),
                  child: const Text('Could not load vault — retry'),
                ),
              ),
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Your vault is empty. Add files in Documents.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    return _DocRow(
                      doc: doc,
                      onSend: () async {
                        HapticFeedback.mediumImpact();
                        await ref.read(messageRepositoryProvider).sendMessage(
                              conversationId: conversationId,
                              text: 'Shared document: ${doc.fileName}',
                            );
                        ref.invalidate(
                          conversationMessagesProvider(conversationId),
                        );
                        ref.read(dailyQuestsProvider.notifier).increment('message');
                        if (context.mounted) Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.onSend});

  final LegalDocument doc;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined,
              color: Color(0xFFEB4898), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${doc.typeLabel} · ${doc.sizeLabel}',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSend,
            child: Text(
              'SEND',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.brandPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
