import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/documents/domain/legal_document.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/doc_type_specimen.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `DocumentPreviewDialog` — blurred authorized preview, never the full file.
Future<void> showDocumentPreviewDialog(
  BuildContext context,
  LegalDocument doc,
) {
  AppHaptics.light();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Authorized preview',
    barrierColor: Colors.black.withAlpha(184),
    pageBuilder: (context, _, _) {
      return DocumentPreviewDialog(doc: doc);
    },
  );
}

class DocumentPreviewDialog extends ConsumerWidget {
  const DocumentPreviewDialog({super.key, required this.doc});

  final LegalDocument doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(documentSignedUrlProvider(doc.filePath));
    final verified = doc.status == 'verified';
    final pending = doc.status == 'pending';
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, bottom + 16),
            child: GestureDetector(
              onTap: () {},
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 440),
                    decoration: BoxDecoration(
                      color: const Color(0xF20C0C12),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(20, 18, 12, 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF6366F1),
                                Color(0xFF8B5CF6),
                                Color(0xFFEC4899),
                              ],
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.verified_user_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'AUTHORIZED PREVIEW',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      doc.typeLabel.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    Text(
                                      doc.fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, 20, 20, 22),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: AspectRatio(
                                  aspectRatio: 4 / 3,
                                  child: ColoredBox(
                                    color: Colors.black.withAlpha(102),
                                    child: urlAsync.when(
                                      loading: () => Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF8B5CF6),
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      error: (_, _) => _SecureFileFallback(
                                        type: doc.documentType,
                                      ),
                                      data: (url) {
                                        if (doc.isImage && url != null) {
                                          return _BlurredImagePreview(
                                            url: url,
                                            type: doc.documentType,
                                          );
                                        }
                                        return _SecureFileFallback(
                                          type: doc.documentType,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 14),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      verified
                                          ? Icons.check_circle_rounded
                                          : pending
                                          ? Icons.schedule_rounded
                                          : Icons.description_outlined,
                                      size: 18,
                                      color: verified
                                          ? const Color(0xFF34D399)
                                          : pending
                                          ? const Color(0xFFFBBF24)
                                          : Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      verified
                                          ? 'VERIFIED'
                                          : pending
                                          ? 'PENDING REVIEW'
                                          : doc.status.toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (doc.createdAt != null)
                                      Text(
                                        '${doc.createdAt!.month}/${doc.createdAt!.day}/${doc.createdAt!.year}',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
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
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlurredImagePreview extends StatelessWidget {
  const _BlurredImagePreview({required this.url, required this.type});
  final String url;
  final String type;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Transform.scale(
            scale: 1.08,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => DocTypeSpecimen(documentType: type),
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x33000000), Color(0xCC000000)],
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, color: Color(0xFF8B5CF6), size: 32),
              SizedBox(height: 8),
              Text(
                'VERIFICATION PREVIEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              SizedBox(height: 6),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Blurred for privacy. Full document is reviewed by Swipess verification only.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SecureFileFallback extends StatelessWidget {
  const _SecureFileFallback({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: EdgeInsets.all(28),
          child: DocTypeSpecimen(documentType: type),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0x268B5CF6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x408B5CF6)),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 32,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'SECURE DOCUMENT ON FILE',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(height: 6),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'PDF and sensitive files are never shown in full on the card.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
