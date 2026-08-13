import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/documents/domain/legal_document.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';
import 'package:flutter_swipes/src/features/profile/domain/vap_card_themes.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/doc_type_specimen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Full-bleed Cap PEARL card — photo, vault specimens, real validation QR.
class ThemedVapCard extends StatelessWidget {
  const ThemedVapCard({
    super.key,
    required this.theme,
    required this.data,
    required this.idNumber,
    required this.validationUrl,
    required this.docsAsync,
    required this.onPreview,
  });

  final VapCardTheme theme;
  final VapIdCard data;
  final String idNumber;
  final String validationUrl;
  final AsyncValue<List<LegalDocument>> docsAsync;
  final ValueChanged<LegalDocument> onPreview;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(36),
          topRight: Radius.circular(40),
          bottomLeft: Radius.circular(38),
          bottomRight: Radius.circular(34),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: t.gradient,
        ),
        border: Border.all(color: t.tagBorder, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(90),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(36),
          topRight: Radius.circular(40),
          bottomLeft: Radius.circular(38),
          bottomRight: Radius.circular(34),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IdentityHeader(theme: t, data: data, idNumber: idNumber),
                    if (data.bio?.isNotEmpty == true) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: t.tagBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: t.tagBorder),
                        ),
                        child: Text(
                          data.bio!,
                          style: GoogleFonts.plusJakartaSans(
                            color: t.textSecondary,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    if (data.languages.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(Icons.translate_rounded, size: 16, color: t.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data.languages.join(' · ').toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                color: t.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (data.interests.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in data.interests.take(8))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: t.tagBg,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: t.tagBorder),
                              ),
                              child: Text(
                                tag.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  color: t.tagText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    _AuthorizedVault(
                      theme: t,
                      docsAsync: docsAsync,
                      onPreview: onPreview,
                    ),
                  ],
                ),
              ),
            ),
            _QrFooter(
              theme: t,
              validationUrl: validationUrl,
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({
    required this.theme,
    required this.data,
    required this.idNumber,
  });

  final VapCardTheme theme;
  final VapIdCard data;
  final String idNumber;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final photoW = (constraints.maxWidth * 0.40).clamp(132.0, 168.0);
        final photoH = photoW * (200 / 160);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: photoW,
              height: photoH,
              decoration: BoxDecoration(
                color: t.tagBg,
                border: Border.all(color: t.tagBorder),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(28),
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(26),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: data.avatarUrl != null
                  ? Image.network(
                      data.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _Initials(data: data, theme: t),
                    )
                  : _Initials(data: data, theme: t),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_user_rounded, size: 20, color: t.badge),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'AUTHORIZED RESIDENT',
                            style: GoogleFonts.plusJakartaSans(
                              color: t.badge,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data.displayName.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: t.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -1,
                        height: 0.95,
                      ),
                    ),
                    if (data.occupation?.isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      Text(
                        data.occupation!.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: t.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 15, color: t.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            data.locationLabel.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: t.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'TXID: $idNumber',
                      style: GoogleFonts.robotoMono(
                        color: t.textTertiary,
                        fontSize: 11,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.data, required this.theme});
  final VapIdCard data;
  final VapCardTheme theme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: theme.tagBg,
      child: Center(
        child: Text(
          data.displayName.isNotEmpty ? data.displayName[0].toUpperCase() : '?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 52,
            fontWeight: FontWeight.w900,
            color: theme.accent,
          ),
        ),
      ),
    );
  }
}

class _AuthorizedVault extends StatelessWidget {
  const _AuthorizedVault({
    required this.theme,
    required this.docsAsync,
    required this.onPreview,
  });

  final VapCardTheme theme;
  final AsyncValue<List<LegalDocument>> docsAsync;
  final ValueChanged<LegalDocument> onPreview;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: t.tagBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.tagBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AUTHORIZED VAULT',
                      style: GoogleFonts.plusJakartaSans(
                        color: t.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.4,
                      ),
                    ),
                    Text(
                      'Verification documents',
                      style: GoogleFonts.plusJakartaSans(
                        color: t.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              docsAsync.maybeWhen(
                data: (items) {
                  final verified =
                      items.where((d) => d.status == 'verified').length;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: t.isDark
                          ? Colors.white.withAlpha(28)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$verified✓',
                      style: GoogleFonts.plusJakartaSans(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          docsAsync.when(
            loading: () => LinearProgressIndicator(color: t.accent, minHeight: 2),
            error: (_, _) => Text(
              'Could not load vault docs',
              style: GoogleFonts.plusJakartaSans(
                color: t.textSecondary,
                fontSize: 12,
              ),
            ),
            data: (items) {
              return Column(
                children: [
                  for (final entry in vapVaultDocTypes) ...[
                    _VaultDocRow(
                      theme: t,
                      typeKey: entry.$1,
                      label: entry.$2,
                      doc: items
                          .where((d) => d.documentType == entry.$1)
                          .firstOrNull,
                      onPreview: onPreview,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VaultDocRow extends StatelessWidget {
  const _VaultDocRow({
    required this.theme,
    required this.typeKey,
    required this.label,
    required this.doc,
    required this.onPreview,
  });

  final VapCardTheme theme;
  final String typeKey;
  final String label;
  final LegalDocument? doc;
  final ValueChanged<LegalDocument> onPreview;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final hasFile = doc != null && doc!.fileName.isNotEmpty;
    final verified = doc?.status == 'verified';
    final pending = doc?.status == 'pending';

    return Opacity(
      opacity: hasFile ? 1 : 0.72,
      child: Material(
        color: t.isDark ? Colors.white.withAlpha(22) : Colors.white.withAlpha(200),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: hasFile ? () => onPreview(doc!) : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              children: [
                _VaultThumb(theme: t, typeKey: typeKey, doc: doc),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: t.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasFile
                            ? 'Tap for authorized preview'
                            : 'Not uploaded',
                        style: GoogleFonts.plusJakartaSans(
                          color: t.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  verified
                      ? Icons.check_circle_rounded
                      : pending
                          ? Icons.schedule_rounded
                          : Icons.description_outlined,
                  size: 18,
                  color: verified
                      ? const Color(0xFF16A34A)
                      : pending
                          ? t.textSecondary
                          : t.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VaultThumb extends ConsumerWidget {
  const _VaultThumb({
    required this.theme,
    required this.typeKey,
    required this.doc,
  });

  final VapCardTheme theme;
  final String typeKey;
  final LegalDocument? doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = theme;
    final urlAsync = (doc != null && doc!.isImage && doc!.filePath.isNotEmpty)
        ? ref.watch(documentSignedUrlProvider(doc!.filePath))
        : null;

    return Container(
      width: 56,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.tagBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DocTypeSpecimen(documentType: typeKey),
          if (urlAsync != null)
            urlAsync.maybeWhen(
              data: (url) {
                if (url == null) return const SizedBox.shrink();
                return ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Transform.scale(
                    scale: 1.08,
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _QrFooter extends StatelessWidget {
  const _QrFooter({required this.theme, required this.validationUrl});

  final VapCardTheme theme;
  final String validationUrl;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.tagBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SWIPESS',
                  style: GoogleFonts.plusJakartaSans(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.8,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'VIRTUAL ID CARD',
                  style: GoogleFonts.plusJakartaSans(
                    color: t.textTertiary,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'SCAN TO VALIDATE',
                  style: GoogleFonts.plusJakartaSans(
                    color: t.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: QrImageView(
              data: validationUrl,
              version: QrVersions.auto,
              size: 104,
              gapless: true,
              padding: EdgeInsets.zero,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
              errorCorrectionLevel: QrErrorCorrectLevel.H,
            ),
          ),
        ],
      ),
    );
  }
}
