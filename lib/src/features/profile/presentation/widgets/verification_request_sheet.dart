import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/documents/data/repositories/document_repository.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `VerificationRequestFlow` — owner deed / fideicomiso / license.
Future<void> showVerificationRequestSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF121218),
    builder: (_) => const _VerificationSheet(),
  );
}

class _VerificationSheet extends ConsumerStatefulWidget {
  const _VerificationSheet();

  @override
  ConsumerState<_VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends ConsumerState<_VerificationSheet> {
  String? _type;
  bool _uploading = false;
  String? _error;
  bool _done = false;

  static const _types = [
    ('ownership_deed', 'Escritura (Ownership Deed)'),
    ('fideicomiso', 'Fideicomiso Certificate'),
    ('rental_license', 'Rental License'),
  ];

  Future<void> _pick() async {
    final type = _type;
    if (type == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await ref
          .read(documentRepositoryProvider)
          .upload(
            fileName: file.name,
            bytes: bytes,
            documentType: type,
            mimeType: file.extension == 'pdf'
                ? 'application/pdf'
                : 'image/jpeg',
          );
      await ref
          .read(documentRepositoryProvider)
          .submitOwnerVerification(documentType: type, filePath: file.name);
      AppHaptics.medium();
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Upload failed. Try a file under 10MB.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OWNER VERIFICATION',
            style: AppTheme.displayItalic.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 8),
          Text(
            _done
                ? 'Submitted. Status is pending review.'
                : 'Upload a deed, fideicomiso, or rental license.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          if (!_done) ...[
            const SizedBox(height: 16),
            for (final t in _types)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _type = t.$1),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _type == t.$1
                            ? AppTheme.brandPrimary
                            : Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _type == t.$1
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: _type == t.$1
                              ? AppTheme.brandPrimary
                              : Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.$2,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Color(0xFFF87171))),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _uploading || _type == null ? null : _pick,
                child: Text(_uploading ? 'Uploading…' : 'UPLOAD DOCUMENT'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
