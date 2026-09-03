import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/content/app_copy_provider.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/admin/data/admin_repository.dart';
import 'package:flutter_swipes/src/features/admin/presentation/widgets/admin_shell.dart';
import 'package:google_fonts/google_fonts.dart';

/// Admin controls for the user-facing words that need to change without an
/// app-store release. More copy keys can be added here as they become dynamic.
class AdminAppCopyScreen extends ConsumerStatefulWidget {
  const AdminAppCopyScreen({super.key});

  @override
  ConsumerState<AdminAppCopyScreen> createState() => _AdminAppCopyScreenState();
}

class _AdminAppCopyScreenState extends ConsumerState<AdminAppCopyScreen> {
  final _dashboardAiPrompts = TextEditingController();
  var _edited = false;
  var _saving = false;

  @override
  void dispose() {
    _dashboardAiPrompts.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _dashboardAiPrompts.text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(12)
        .join('\n');
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one AI field prompt.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setAppCopy(key: 'dashboard_ai_prompts', value: value);
      ref.invalidate(dashboardAiPromptsProvider);
      if (!mounted) return;
      setState(() => _edited = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dashboard AI text updated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the text. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final foreground = isLight ? const Color(0xFF111318) : Colors.white;
    final promptsAsync = ref.watch(dashboardAiPromptsProvider);
    final prompts = promptsAsync.value ?? defaultDashboardAiPrompts;
    if (!_edited && !_dashboardAiPrompts.text.isNotEmpty) {
      _dashboardAiPrompts.text = prompts.join('\n');
    }

    return AdminShell(
      title: 'App text',
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Text(
            'Dashboard AI field',
            style: GoogleFonts.plusJakartaSans(
              color: foreground,
              fontWeight: FontWeight.w900,
              fontSize: 21,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Edit the rotating words inside the blue AI field. Put one prompt on each line. Changes show to signed-in users without a new app build.',
            style: GoogleFonts.plusJakartaSans(
              color: foreground.withAlpha(165),
              height: 1.4,
              fontSize: 12.5,
            ),
          ),
          SizedBox(height: 18),
          TextField(
            controller: _dashboardAiPrompts,
            minLines: 4,
            maxLines: 8,
            onChanged: (_) {
              if (!_edited) setState(() => _edited = true);
            },
            style: GoogleFonts.plusJakartaSans(color: foreground),
            decoration: InputDecoration(
              hintText: 'What are you looking for?',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: foreground.withAlpha(100),
              ),
              filled: true,
              fillColor: isLight ? Colors.white : const Color(0xFF121822),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: foreground.withAlpha(38)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: foreground.withAlpha(38)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: AppTheme.brandPrimary,
                  width: 1.4,
                ),
              ),
            ),
          ),
          SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.save_rounded),
              label: Text(
                _saving ? 'Saving…' : 'Save dashboard AI text',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
