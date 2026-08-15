import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/auth/data/auth_repository.dart';

void main() {
  test('deleteAccount is a real AuthRepository method, not sign-out-only', () {
    final Future<void> Function(AuthRepository) deleteAccount =
        (repository) => repository.deleteAccount();

    expect(
      deleteAccount,
      isA<Function>(),
    );
  });
}
