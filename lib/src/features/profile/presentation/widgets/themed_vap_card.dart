import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/documents/domain/legal_document.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';
import 'package:flutter_swipes/src/features/profile/domain/vap_card_themes.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ThemedVapCard extends StatelessWidget {
  const ThemedVapCard({
    super.key,
    required this.theme,
    required this.data,
    required this.idNumber,
    required this.validationUrl,
    required this.docsAsync,
    required this.onPreview,
    required this.onManageDocuments,
  });

  final VapCardTheme theme;
  final VapIdCard data;
  final String idNumber;
  final String validationUrl;
  final AsyncValue<List<LegalDocument>> docsAsync;
  final ValueChanged<LegalDocument> onPreview;
  final VoidCallback onManageDocuments;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: t.gradient,
        ),
        borderRadius: BorderRadius.circular(28),
        border: t.isDark ? null : Border.all(color: t.tagBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(75),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SelectionContainer.disabled(
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            decoration: TextDecoration.none,
            decorationColor: Colors.transparent,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IdentitySection(
                  theme: t,
                  data: data,
                  idNumber: idNumber,
                  validationUrl: validationUrl,
                ),
                const SizedBox(height: 18),
                Divider(color: t.tagBorder, height: 1),
                const SizedBox(height: 18),
                _DocumentsSection(
                  theme: t,
                  docsAsync: docsAsync,
                  onPreview: onPreview,
                  onManageDocuments: onManageDocuments,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({
    required this.theme,
    required this.data,
    required this.idNumber,
    required this.validationUrl,
  });

  final VapCardTheme theme;
  final VapIdCard data;
  final String idNumber;
  final String validationUrl;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final memberSince = data.createdAt?.year.toString() ?? '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.verified_user_outlined, color: t.badge, size: 17),
            const SizedBox(width: 6),
            Text(
              'SWIPESS LOCAL ID',
              style: GoogleFonts.plusJakartaSans(
                color: t.badge,
                fontWeight: FontWeight.w900,
                fontSize: 9.5,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 112,
              height: 142,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: t.tagBg,
                borderRadius: BorderRadius.circular(20),
                border: t.isDark ? null : Border.all(color: t.tagBorder),
              ),
              child: data.displayPhotoUrl != null
                  ? Image.network(
                      data.displayPhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _Initials(data: data, theme: t),
                    )
                  : _Initials(data: data, theme: t),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.displayName.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      height: .98,
                      letterSpacing: -.7,
                    ),
                  ),
                  if (data.occupation?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 7),
                    Text(
                      data.occupation!.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: t.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _MiniLine(
                    icon: Icons.location_on_outlined,
                    text: data.locationLabel,
                    color: t.textSecondary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ID $idNumber',
                    style: GoogleFonts.robotoMono(
                      color: t.textTertiary,
                      fontSize: 9.5,
                      letterSpacing: .8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: t.tagBg,
            borderRadius: BorderRadius.circular(18),
            border: t.isDark ? null : Border.all(color: t.tagBorder),
          ),
          child: Wrap(
            runSpacing: 12,
            spacing: 10,
            children: [
              _Field(
                label: 'NATIONALITY',
                value: data.nationality ?? data.country ?? '—',
                theme: t,
              ),
              _Field(
                label: 'AGE',
                value: data.age?.toString() ?? '—',
                theme: t,
              ),
              _Field(label: 'CITY', value: data.city ?? '—', theme: t),
              _Field(label: 'COUNTRY', value: data.country ?? '—', theme: t),
              _Field(
                label: 'LOCAL SINCE',
                value: data.yearsInCity == null
                    ? '—'
                    : '${data.yearsInCity} years',
                theme: t,
              ),
              _Field(label: 'MEMBER SINCE', value: memberSince, theme: t),
            ],
          ),
        ),
        if (data.bio?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(
            data.bio!,
            style: GoogleFonts.plusJakartaSans(
              color: t.textSecondary,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SCAN TO VALIDATE',
                    style: GoogleFonts.plusJakartaSans(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 9.5,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Identity first · approved documents below',
                    style: GoogleFonts.plusJakartaSans(
                      color: t.textTertiary,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: QrImageView(data: validationUrl, padding: EdgeInsets.zero),
            ),
          ],
        ),
      ],
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({
    required this.theme,
    required this.docsAsync,
    required this.onPreview,
    required this.onManageDocuments,
  });

  final VapCardTheme theme;
  final AsyncValue<List<LegalDocument>> docsAsync;
  final ValueChanged<LegalDocument> onPreview;
  final VoidCallback onManageDocuments;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final docs = (docsAsync.value ?? const <LegalDocument>[])
        .where((doc) => doc.status.toLowerCase() == 'approved')
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'DOCUMENTS',
                style: GoogleFonts.plusJakartaSans(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -.2,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onManageDocuments,
              icon: Icon(Icons.add_rounded, color: t.accent, size: 17),
              label: Text(
                'MANAGE',
                style: GoogleFonts.plusJakartaSans(
                  color: t.accent,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
            ),
          ],
        ),
        Text(
          'Tap an empty row to upload · tap an uploaded file to preview',
          style: GoogleFonts.plusJakartaSans(
            color: t.textTertiary,
            fontSize: 10.5,
          ),
        ),
        const SizedBox(height: 12),
        if (docsAsync.isLoading && docsAsync.value == null)
          LinearProgressIndicator(color: t.accent, minHeight: 2)
        else
          for (final entry in vapVaultDocTypes) ...[
            _DocumentRow(
              theme: t,
              label: entry.$2,
              doc: docs.where((d) => d.documentType == entry.$1).firstOrNull,
              onPreview: onPreview,
              onManageDocuments: onManageDocuments,
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.theme,
    required this.label,
    required this.doc,
    required this.onPreview,
    required this.onManageDocuments,
  });

  final VapCardTheme theme;
  final String label;
  final LegalDocument? doc;
  final ValueChanged<LegalDocument> onPreview;
  final VoidCallback onManageDocuments;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final uploaded = doc != null && doc!.fileName.isNotEmpty;
    return Material(
      color: t.isDark
          ? Colors.white.withAlpha(18)
          : Colors.white.withAlpha(210),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: uploaded ? () => onPreview(doc!) : onManageDocuments,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              _DocThumb(theme: t, doc: doc),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        letterSpacing: .5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      uploaded ? 'Tap to preview' : 'Tap to upload',
                      style: GoogleFonts.plusJakartaSans(
                        color: t.textTertiary,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                uploaded
                    ? Icons.open_in_new_rounded
                    : Icons.upload_file_rounded,
                color: uploaded ? t.accent : t.textTertiary,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocThumb extends ConsumerWidget {
  const _DocThumb({required this.theme, required this.doc});

  final VapCardTheme theme;
  final LegalDocument? doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = theme;
    final urlAsync = (doc != null && doc!.isImage && doc!.filePath.isNotEmpty)
        ? ref.watch(documentSignedUrlProvider(doc!.filePath))
        : null;
    return Container(
      width: 42,
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.tagBg,
        border: t.isDark ? null : Border.all(color: t.tagBorder),
      ),
      child: urlAsync == null
          ? Icon(Icons.description_outlined, color: t.textTertiary, size: 17)
          : urlAsync.when(
              data: (url) => url == null || url.isEmpty
                  ? Icon(
                      Icons.description_outlined,
                      color: t.textTertiary,
                      size: 17,
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.description_outlined,
                        color: t.textTertiary,
                        size: 17,
                      ),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
              error: (_, _) => Icon(
                Icons.description_outlined,
                color: t.textTertiary,
                size: 17,
              ),
            ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.data, required this.theme});

  final VapIdCard data;
  final VapCardTheme theme;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: theme.tagBg,
    child: Center(
      child: Text(
        data.displayName.isNotEmpty ? data.displayName[0].toUpperCase() : '?',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 44,
          fontWeight: FontWeight.w900,
          color: theme.accent,
        ),
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, required this.theme});

  final String label;
  final String value;
  final VapCardTheme theme;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 132,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: theme.textTertiary,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: theme.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _MiniLine extends StatelessWidget {
  const _MiniLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 13),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}
