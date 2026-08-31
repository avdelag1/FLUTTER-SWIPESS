import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client lib does not embed privileged access codes', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue);

    const forbidden = [
      'ADMIN2026',
      'BUSINESS1010',
      'LAW2027',
    ];

    final hits = <String>[];
    for (final file in lib.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final content = file.readAsStringSync();
      for (final code in forbidden) {
        if (content.contains(code)) {
          hits.add('${file.path}: $code');
        }
      }
    }

    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
