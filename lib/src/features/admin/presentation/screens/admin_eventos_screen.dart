import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/utils/event_connect.dart';
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
  String? _editingId;
  var _draft = const AdminEventDraft();

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(adminEventsProvider);
    final submissions = ref.watch(adminSubmissionsProvider);
    return AdminShell(
      title: t(ref, 'flutter.adminEvents', 'Admin Events'),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(
            children: [
              _tab('Events', !_subs, () => setState(() => _subs = false)),
              SizedBox(width: 8),
              _tab(
                t(ref, 'flutter.submissions', 'Submissions'),
                _subs,
                () => setState(() => _subs = true),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => setState(() {
                  _formOpen = !_formOpen;
                  if (_formOpen) {
                    _editingId = null;
                    _draft = const AdminEventDraft();
                  }
                }),
                icon: Icon(Icons.add, size: 16),
                label: Text(t(ref, 'actions.create', 'Create')),
              ),
            ],
          ),
          if (_formOpen) ...[
            SizedBox(height: 12),
            _EventForm(
              key: ValueKey(_editingId ?? 'create'),
              draft: _draft,
              editing: _editingId != null,
              onSave: (d) async {
                await ref
                    .read(adminRepositoryProvider)
                    .upsertEvent(d, editingId: _editingId);
                setState(() {
                  _formOpen = false;
                  _editingId = null;
                  _draft = const AdminEventDraft();
                });
                ref.invalidate(adminEventsProvider);
              },
            ),
          ],
          SizedBox(height: 16),
          if (_subs)
            submissions.when(
              loading: () => Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Could not load ($e)'),
              data: (rows) {
                if (rows.isEmpty) {
                  return Text(
                    'No submissions',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white),
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
              loading: () => Center(child: CircularProgressIndicator()),
              error: (e, _) => TextButton(
                onPressed: () => ref.invalidate(adminEventsProvider),
                child: Text('Could not load events — retry ($e)'),
              ),
              data: (rows) => Column(
                children: [
                  for (final e in rows)
                    _EventTile(
                      event: e,
                      onEdit: () => setState(() {
                        _editingId = e.id;
                        _draft = AdminEventDraft.fromRow(e);
                        _formOpen = true;
                        _subs = false;
                      }),
                      onToggle: () async {
                        await ref
                            .read(adminRepositoryProvider)
                            .togglePublished(e.id, e.isPublished);
                        ref.invalidate(adminEventsProvider);
                      },
                      onDelete: () async {
                        await ref
                            .read(adminRepositoryProvider)
                            .deleteEvent(e.id);
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
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final AdminEventRow event;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final wa = EventConnect.hasWhatsApp(event.organizerWhatsapp);
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 1.5),
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
          SizedBox(width: 10),
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
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
                Text(
                  wa
                      ? 'WhatsApp ${event.organizerWhatsapp}'
                      : 'No WhatsApp number yet',
                  style: GoogleFonts.plusJakartaSans(
                    color: wa ? const Color(0xFF25D366) : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: Icon(Icons.edit_outlined, color: Colors.white),
          ),
          IconButton(
            onPressed: onToggle,
            icon: Icon(
              event.isPublished ? Icons.visibility : Icons.visibility_off,
              color: event.isPublished ? const Color(0xFF10B981) : Colors.white,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
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
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent,
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
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          if (sub.status == 'pending')
            Row(
              children: [
                TextButton(onPressed: onApprove, child: Text('Approve')),
                TextButton(onPressed: onReject, child: Text('Reject')),
              ],
            ),
        ],
      ),
    );
  }
}

class _EventForm extends StatefulWidget {
  const _EventForm({
    super.key,
    required this.draft,
    required this.onSave,
    this.editing = false,
  });
  final AdminEventDraft draft;
  final ValueChanged<AdminEventDraft> onSave;
  final bool editing;

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _organizerName;
  late final TextEditingController _whatsapp;
  late final TextEditingController _instagram;
  late final TextEditingController _website;
  late final TextEditingController _facebook;
  late String _imageUrl;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _title = TextEditingController(text: d.title);
    _location = TextEditingController(text: d.location);
    _organizerName = TextEditingController(text: d.organizerName);
    _whatsapp = TextEditingController(text: d.organizerWhatsapp);
    _instagram = TextEditingController(text: d.organizerInstagram);
    _website = TextEditingController(text: d.organizerWebsite);
    _facebook = TextEditingController(text: d.organizerFacebook);
    _imageUrl = d.imageUrl;
    _title.addListener(_refresh);
    _whatsapp.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _organizerName.dispose();
    _whatsapp.dispose();
    _instagram.dispose();
    _website.dispose();
    _facebook.dispose();
    super.dispose();
  }

  AdminEventDraft _current() {
    return AdminEventDraft(
      title: _title.text,
      description: widget.draft.description,
      category: widget.draft.category,
      imageUrl: _imageUrl,
      location: _location.text,
      organizerName: _organizerName.text,
      organizerWhatsapp: _whatsapp.text,
      organizerInstagram: _instagram.text,
      organizerWebsite: _website.text,
      organizerFacebook: _facebook.text,
      isPublished: widget.draft.isPublished,
      isApproved: widget.draft.isApproved,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wa = EventConnect.whatsAppUri(_whatsapp.text);
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.editing ? 'EDIT EVENT HOST' : 'NEW EVENT HOST',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.4,
            ),
          ),
          SizedBox(height: 10),
          _field('Title', _title),
          _field('Location', _location),
          _field('Promoter / organizer name', _organizerName),
          _field(
            'WhatsApp phone (with country code)',
            _whatsapp,
            keyboard: TextInputType.phone,
          ),
          if (wa != null)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Opens as ${wa.toString()}',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF25D366),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Add a full number with country code. The app builds the WhatsApp link.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          _field('Instagram @handle or URL', _instagram),
          _field('Website', _website, keyboard: TextInputType.url),
          _field('Facebook page or URL', _facebook),
          SizedBox(height: 8),
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
                  setState(() => _imageUrl = url);
                },
                icon: Icon(Icons.image_outlined),
                label: Text(_imageUrl.isEmpty ? 'Image' : 'Image set'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _title.text.trim().isEmpty
                    ? null
                    : () => widget.onSave(_current()),
                child: Text(widget.editing ? 'Update' : 'Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(
    String hint,
    TextEditingController controller, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: Colors.white),
        keyboardType: keyboard,
        decoration: InputDecoration(hintText: hint),
      ),
    );
  }
}
