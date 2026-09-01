import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'claim-account flow requires a password and waits for email confirmation',
    () {
      final screen = File(
        'lib/src/features/profile/presentation/screens/claim_account_email_screen.dart',
      ).readAsStringSync();
      final repository = File('lib/src/features/auth/data/auth_repository.dart')
          .readAsStringSync();

      expect(screen, contains('Claim your Swipess account.'));
      expect(screen, contains('Current account password'));
      expect(screen, contains('We sent a secure confirmation'));
      expect(repository, contains('requestEmailChange'));
      expect(repository, contains('currentPassword: currentPassword'));
      expect(repository, contains('email: normalizedEmail'));
    },
  );
}
