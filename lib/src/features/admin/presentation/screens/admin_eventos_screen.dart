import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/admin/data/admin_repository.dart';
import 'package:flutter_swipes/src/features/admin/domain/admin_models.dart';
import 'package:flutter_swipes/src/features/admin/presentation/providers/admin_provider.dart';
import 'package:flutter_swipes/src/features/admin/presentation/widgets/admin_shell.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// Cap `AdminEventos` — events list, publish toggle, promo submissions.
class AdminEventosScreen extends ConsumerStatefulWidget {
  const AdminEventosScreen({super.key});

  @override
  ConsumerState<AdminEventosScreen> createState() => _AdminEventosScreenState();
}

class _AdminEventosScreenState extends ConsumerState<AdminEventosScreen> {
  bool _subs = false;
  bool _formOpen = false;
  var _draft = const AdminEventDraft();

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(adminEventsProvider);
    final submissions = ref.watch(adminSubmissionsProvider);
    return AdminShell(
      title: t(ref, 'flutter.adminEvents', 'Admin Events'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(
            children: [
              _tab('Events', !_subs, () => setState(() => _subs = false)),
              const SizedBox(width: 8),
              _tab(
                t(ref, 'flutter.submissions', 'Submissions'),
                _subs,
                () => setState(() => _subs = true),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => setState(() => _formOpen = !_formOpen),
                icon: const Icon(Icons.add, size: 16),
                label: Text(t(ref, 'actions.create', 'Create')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                ),
              ),
            ],
          ),
          if (_formOpen) ...[
            const SizedBox(height: 12),
            _EventForm(
              draft: _draft,
              onChanged: (d) => setState(() => _draft = d),
              onSave: () async {
                await ref.read(adminRepositoryProvider).upsertEvent(_draft);
                setState(() {
                  _formOpen = false;
                  _draft = const AdminEventDraft();
                });
                ref.invalidate(adminEventsProvider);
              },
            ),
          ],
          const SizedBox(height: 16),
          if (_subs)
            submissions.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Could not load ($e)'),
              data: (rows) {
                if (rows.isEmpty) {
                  return Text(
                    'No submissions',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                  );
                }
                return Column(
                  children: [
                    for (final s in rows)
                      _SubCard(
                        sub: s,
                        onApprove: () async {
                          await ref
                              .read(adminRepositoryProvider)
                              .approveSubmission(s);
                          ref.invalidate(adminSubmissionsProvider);
                          ref.invalidate(adminEventsProvider);
                        },
                        onReject: () async {
                          await ref
                              .read(adminRepositoryProvider)
                              .rejectSubmission(s);
                          ref.invalidate(adminSubmissionsProvider);
                        },
                      ),
                  ],
                );
              },
            )
          else
            events.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => TextButton(
                onPressed: () => ref.invalidate(adminEventsProvider),
                child: Text('Could not load events — retry ($e)'),
              ),
              data: (rows) => Column(
                children: [
                  for (final e in rows)
                    _EventTile(
                      event: e,
                      onToggle: () async {
                        await ref
                            .read(adminRepositoryProvider)
                            .togglePublished(e.id, e.isPublished);
                        ref.invalidate(adminEventsProvider);
                      },
                      onDelete: () async {
                        await ref.read(adminRepositoryProvider).deleteEvent(e.id);
                        ref.invalidate(adminEventsProvider);
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tab(String label, bool on, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.white.withAlpha(14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: on ? Colors.black : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.onToggle,
    required this.onDelete,
  });
  final AdminEventRow event;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: event.imageUrl != null
                  ? Image.network(event.imageUrl!, fit: BoxFit.cover)
                  : const ColoredBox(color: Color(0xFF16161C)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${event.category} · ${event.location ?? '—'}',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onToggle,
            icon: Icon(
              event.isPublished ? Icons.visibility : Icons.visibility_off,
              color: event.isPublished ? const Color(0xFF10B981) : Colors.white38,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
          ),
        ],
      ),
    );
  }
}

class _SubCard extends StatelessWidget {
  const _SubCard({
    required this.sub,
    required this.onApprove,
    required this.onReject,
  });
  final PromoSubmission sub;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sub.title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${sub.status} · ${sub.location ?? ''}',
            style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
          ),
          if (sub.status == 'pending')
            Row(
              children: [
                TextButton(onPressed: onApprove, child: const Text('Approve')),
                TextButton(onPressed: onReject, child: const Text('Reject')),
              ],
            ),
        ],
      ),
    );
  }
}

class _EventForm extends StatelessWidget {
  const _EventForm({
    required this.draft,
    required this.onChanged,
    required this.onSave,
  });
  final AdminEventDraft draft;
  final ValueChanged<AdminEventDraft> onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Title'),
            onChanged: (v) => onChanged(
              AdminEventDraft(
                title: v,
                description: draft.description,
                category: draft.category,
                imageUrl: draft.imageUrl,
                location: draft.location,
                organizerWhatsapp: draft.organizerWhatsapp,
                isPublished: draft.isPublished,
                isApproved: draft.isApproved,
              ),
            ),
          ),
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Location'),
            onChanged: (v) => onChanged(
              AdminEventDraft(
                title: draft.title,
                description: draft.description,
                category: draft.category,
                imageUrl: draft.imageUrl,
                location: v,
                organizerWhatsapp: draft.organizerWhatsapp,
                isPublished: draft.isPublished,
                isApproved: draft.isApproved,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  final file = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                  );
                  if (file == null || !context.mounted) return;
                  final url = await ProviderScope.containerOf(context)
                      .read(adminRepositoryProvider)
                      .uploadEventImage(file);
                  onChanged(
                    AdminEventDraft(
                      title: draft.title,
                      description: draft.description,
                      category: draft.category,
                      imageUrl: url,
                      location: draft.location,
                      organizerWhatsapp: draft.organizerWhatsapp,
                      isPublished: draft.isPublished,
                      isApproved: draft.isApproved,
                    ),
                  );
                },
                icon: const Icon(Icons.image_outlined),
                label: const Text('Image'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: draft.title.trim().isEmpty ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
