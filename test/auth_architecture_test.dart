import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Auth presentation screens do not use Supabase.instance or SnackBar', () {
    final authScreensDir = Directory(
      'lib/src/features/auth/presentation/screens',
    );
    if (!authScreensDir.existsSync()) return;

    final files = authScreensDir.listSync(recursive: true).whereType<File>();

    for (final file in files) {
      if (!file.path.endsWith('.dart')) continue;

      final content = file.readAsStringSync();

      expect(
        content.contains('Supabase.instance'),
        isFalse,
        reason:
            'File ${file.path} contains direct Supabase.instance usage. Use authControllerProvider instead.',
      );

      expect(
        content.contains('SnackBar('),
        isFalse,
        reason:
            'File ${file.path} contains direct SnackBar usage. Use appNotificationsProvider instead.',
      );
    }
  });
}
