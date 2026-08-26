import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

abstract final class ContractExportService {
  static Future<void> sharePdf({
    required String title,
    required String content,
  }) async {
    final bytes = _buildPdf(title: title, content: content);
    await SharePlus.instance.share(
      ShareParams(
        subject: title,
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: '${_safeName(title)}.pdf',
          ),
        ],
      ),
    );
  }

  static Future<void> shareWord({
    required String title,
    required String content,
  }) async {
    final html =
        '''<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>${_html(title)}</title>
<style>
body{font-family:Georgia,serif;font-size:12pt;line-height:1.55;margin:48px;color:#111}
h1{font-family:Arial,sans-serif;font-size:20pt;margin-bottom:24px}
.document{white-space:pre-wrap}
</style>
</head>
<body>
<h1>${_html(title)}</h1>
<div class="document">${_html(content)}</div>
</body>
</html>''';
    await SharePlus.instance.share(
      ShareParams(
        subject: title,
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(html)),
            mimeType: 'application/msword',
            name: '${_safeName(title)}.doc',
          ),
        ],
      ),
    );
  }

  /// Builds a small standards-compatible PDF without adding another native
  /// dependency to the release build. It uses Helvetica and paginates plain
  /// legal text, which keeps export reliable on web, iOS and Android.
  static Uint8List _buildPdf({required String title, required String content}) {
    final normalizedTitle = _pdfText(title);
    final wrapped = <String>[
      normalizedTitle,
      '',
      ..._wrap(_pdfText(content), 92),
    ];
    const linesPerPage = 48;
    final pages = <List<String>>[];
    for (var i = 0; i < wrapped.length; i += linesPerPage) {
      final end = (i + linesPerPage < wrapped.length)
          ? i + linesPerPage
          : wrapped.length;
      pages.add(wrapped.sublist(i, end));
    }
    if (pages.isEmpty) pages.add(const ['']);

    final pageCount = pages.length;
    final fontObjectId = 3 + pageCount * 2;
    final objectCount = fontObjectId;
    final objects = <int, String>{};

    objects[1] = '<< /Type /Catalog /Pages 2 0 R >>';
    final kids = [for (var i = 0; i < pageCount; i++) '${3 + i * 2} 0 R']
        .join(' ');
    objects[2] = '<< /Type /Pages /Kids [$kids] /Count $pageCount >>';

    for (var i = 0; i < pageCount; i++) {
      final pageId = 3 + i * 2;
      final contentId = pageId + 1;
      final stream = _pageStream(pages[i], isFirstPage: i == 0);
      objects[pageId] =
          '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 $fontObjectId 0 R >> >> /Contents $contentId 0 R >>';
      objects[contentId] =
          '<< /Length ${ascii.encode(stream).length} >>\nstream\n$stream\nendstream';
    }
    objects[fontObjectId] =
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>';

    final out = StringBuffer('%PDF-1.4\n');
    final offsets = List<int>.filled(objectCount + 1, 0);
    for (var id = 1; id <= objectCount; id++) {
      offsets[id] = ascii.encode(out.toString()).length;
      out.write('$id 0 obj\n${objects[id]}\nendobj\n');
    }
    final xrefOffset = ascii.encode(out.toString()).length;
    out.write('xref\n0 ${objectCount + 1}\n');
    out.write('0000000000 65535 f \n');
    for (var id = 1; id <= objectCount; id++) {
      out.write('${offsets[id].toString().padLeft(10, '0')} 00000 n \n');
    }
    out.write(
      'trailer\n<< /Size ${objectCount + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF',
    );
    return Uint8List.fromList(ascii.encode(out.toString()));
  }

  static String _pageStream(List<String> lines, {required bool isFirstPage}) {
    final b = StringBuffer();
    b.write('BT\n/F1 ${isFirstPage ? 12 : 10.5} Tf\n50 748 Td\n');
    b.write('${isFirstPage ? 17 : 14} TL\n');
    for (final line in lines) {
      b.write('(${_pdfEscape(line)}) Tj\nT*\n');
    }
    b.write('ET');
    return b.toString();
  }

  static List<String> _wrap(String input, int max) {
    final result = <String>[];
    for (final paragraph in input.replaceAll('\r', '').split('\n')) {
      if (paragraph.isEmpty) {
        result.add('');
        continue;
      }
      var current = '';
      for (final word in paragraph.split(RegExp(r'\s+'))) {
        if (word.isEmpty) continue;
        if (current.isEmpty) {
          current = word;
        } else if (current.length + 1 + word.length <= max) {
          current = '$current $word';
        } else {
          result.add(current);
          current = word;
        }
      }
      if (current.isNotEmpty) result.add(current);
    }
    return result;
  }

  static String _pdfEscape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('(', '\\(')
      .replaceAll(')', '\\)');

  static String _pdfText(String value) {
    final replacements = <String, String>{
      '—': '-',
      '–': '-',
      '’': "'",
      '“': '"',
      '”': '"',
      '…': '...',
      '•': '-',
    };
    var result = value;
    replacements.forEach((key, val) => result = result.replaceAll(key, val));
    return result.runes
        .map(
          (r) => r >= 32 && r <= 126 || r == 10 ? String.fromCharCode(r) : '?',
        )
        .join();
  }

  static String _safeName(String title) {
    final cleaned = title
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'Swipess_Document' : cleaned;
  }

  static String _html(String value) => const HtmlEscape().convert(value);
}
