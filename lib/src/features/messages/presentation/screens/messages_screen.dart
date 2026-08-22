import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/providers/messages_provider.dart';
import 'package:flutter_swipes/src/features/messages/presentation/screens/chat_screen.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/messages_documents_library.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/message_activation_packages.dart';
import 'package:google_fonts/google_fonts.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  String _activeFilter = 'all'; // all, unread, archived
  String _activeSection = 'chats'; // chats, documents
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(conversationsProvider);

    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final well = MatteSurface.well(context);
    final isLight = MatteSurface.isLight(context);

    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: Stack(
        children: [
          // Soft brand ambient (Cap inbox glow)
          Positioned(
            top: -50,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.brandPrimary.withAlpha(isLight ? 18 : 28),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Row(
                    children: [
                      const CapBackButton(),
                      const Spacer(),
                      _buildSectionToggle(),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Color(0xFFEB4898),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFEB4898).withAlpha(70),
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.chat_bubble_rounded,
                          color: MatteSurface.ink(context),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MESSAGES',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFEB4898),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'INBOX',
                              style: AppTheme.displayItalic.copyWith(
                                fontSize: 40,
                                height: 0.95,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GestureDetector(
                    onTap: () {
                      AppHaptics.medium();
                      showMessageActivationPackages(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.brandPrimary.withAlpha(40),
                            const Color(0xFFFBBF24).withAlpha(24),
                          ],
                        ),
                        border: Border.all(color: Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFFFBBF24),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Get Direct Requests for priority',
                              style: GoogleFonts.plusJakartaSans(
                                color: ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            'VIEW',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.brandPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (_activeSection == 'chats') ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildFilters(),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: ink, fontWeight: FontWeight.bold),
                      onChanged: (v) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search conversations...',
                        hintStyle: TextStyle(color: muted.withAlpha(160)),
                        prefixIcon: Icon(Icons.search, color: muted),
                        filled: true,
                        fillColor: well,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: async.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.brandPrimary,
                        ),
                      ),
                      error: (e, _) => Center(
                        child: Text(
                          'Error: $e',
                          style: TextStyle(color: muted),
                        ),
                      ),
                      data: (items) {
                        final q = _searchController.text.trim().toLowerCase();
                        var filtered = items.where((c) {
                          if (q.isNotEmpty && !c.name.toLowerCase().contains(q))
                            return false;
                          if (_activeFilter == 'unread' && c.unreadCount == 0)
                            return false;
                          if (_activeFilter == 'archived' && !c.archived) {
                            return false;
                          }
                          if (_activeFilter != 'archived' && c.archived) {
                            return false;
                          }
                          return true;
                        }).toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.message_rounded,
                                  size: 64,
                                  color: ink.withAlpha(40),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'NO MESSAGES YET',
                                  style: AppTheme.displayItalic.copyWith(
                                    fontSize: 24,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final conversation = filtered[index];
                            return GestureDetector(
                              onLongPress: conversation.archived
                                  ? null
                                  : () {
                                      AppHaptics.medium();
                                      ref
                                          .read(conversationsProvider.notifier)
                                          .archive(conversation.id);
                                    },
                              child: _ChatTile(conversation: conversation),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ] else ...[
                  const Expanded(child: MessagesDocumentsLibrary()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TogglePill(
          label: 'CHATS',
          icon: Icons.inbox_rounded,
          isActive: _activeSection == 'chats',
          onTap: () {
            AppHaptics.light();
            setState(() => _activeSection = 'chats');
          },
        ),
        const SizedBox(width: 8),
        _TogglePill(
          label: 'DOCUMENTS',
          icon: Icons.folder_special_rounded,
          isActive: _activeSection == 'documents',
          onTap: () {
            AppHaptics.light();
            setState(() => _activeSection = 'documents');
          },
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'INBOX',
            icon: Icons.inbox_rounded,
            isActive: _activeFilter == 'all',
            onTap: () {
              AppHaptics.light();
              setState(() => _activeFilter = 'all');
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'PRIORITY',
            icon: Icons.auto_awesome_rounded,
            isActive: _activeFilter == 'unread',
            onTap: () {
              AppHaptics.light();
              setState(() => _activeFilter = 'unread');
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'ARCHIVE',
            icon: Icons.archive_outlined,
            isActive: _activeFilter == 'archived',
            onTap: () {
              AppHaptics.light();
              setState(() => _activeFilter = 'archived');
            },
          ),
        ],
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final muted = MatteSurface.muted(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(colors: [Color(0xFFFF4D00), Color(0xFFEB4898)])
              : null,
          color: isActive ? null : MatteSurface.cardFill(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive
                ? Colors.white.withAlpha(50)
                : MatteSurface.hairline(context),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFFEB4898).withAlpha(90),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: isActive ? Colors.white : const Color(0xFFEB4898),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isActive ? Colors.white : muted,
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final muted = MatteSurface.muted(context);
    final isLight = MatteSurface.isLight(context);
    final rose = Color(0xFFF43F5E);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? (isLight ? Color(0xFFFFF1F2) : rose.withAlpha(40))
              : MatteSurface.cardFill(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive
                ? rose.withAlpha(isLight ? 100 : 80)
                : MatteSurface.hairline(context),
          ),
          boxShadow: isActive && !isLight
              ? [BoxShadow(color: rose.withAlpha(50), blurRadius: 12)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: isActive ? rose : const Color(0xFFEB4898),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isActive ? rose : muted,
                fontWeight: FontWeight.w900,
                fontSize: 9,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  _ChatTile({required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    final hairline = MatteSurface.hairline(context);
    return GestureDetector(
      onTap: () {
        AppHaptics.medium();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(conversation: conversation),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MatteSurface.cardFill(context),
              border: Border.all(color: hairline),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: conversation.avatarUrl != null
                      ? NetworkImage(conversation.avatarUrl!)
                      : null,
                  child: conversation.avatarUrl == null
                      ? Text(
                          conversation.name[0].toUpperCase(),
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              conversation.name,
                              style: TextStyle(
                                color: ink,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            conversation.timestamp,
                            style: TextStyle(
                              color: muted,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        conversation.lastMessage,
                        style: TextStyle(
                          color: conversation.unreadCount > 0 ? ink : muted,
                          fontWeight: conversation.unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (conversation.unreadCount > 0) ...[
                  SizedBox(width: 12),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${conversation.unreadCount}',
                      style: TextStyle(
                        color: MatteSurface.ink(context),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}