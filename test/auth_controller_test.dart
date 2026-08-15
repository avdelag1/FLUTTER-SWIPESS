import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_controller.dart';
import 'package:flutter_swipes/src/features/auth/data/auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class FakeAuthResponse extends Fake implements AuthResponse {}

void main() {
  setUpAll(() {
    registerFallbackValue(OAuthProvider.google);
  });

  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  }

  test('login success', () async {
    when(() => mockRepo.signInWithEmailPassword('test@example.com', 'password'))
        .thenAnswer((_) async => FakeAuthResponse());

    final container = makeContainer();
    final controller = container.read(authControllerProvider.notifier);

    await controller.login('test@example.com', 'password');
    verify(() => mockRepo.signInWithEmailPassword('test@example.com', 'password')).called(1);
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('login failure', () async {
    when(() => mockRepo.signInWithEmailPassword('test@example.com', 'password'))
        .thenThrow(Exception('Invalid login'));

    final container = makeContainer();
    final controller = container.read(authControllerProvider.notifier);

    await controller.login('test@example.com', 'password');
    expect(container.read(authControllerProvider).hasError, isTrue);
  });

  test('sign-up success', () async {
    when(() => mockRepo.signUpWithEmailPassword('test@example.com', 'password', name: any(named: 'name')))
        .thenAnswer((_) async => FakeAuthResponse());

    final container = makeContainer();
    final controller = container.read(authControllerProvider.notifier);

    await controller.signup('test@example.com', 'password');
    verify(() => mockRepo.signUpWithEmailPassword('test@example.com', 'password', name: any(named: 'name'))).called(1);
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('forgot-password success', () async {
    when(() => mockRepo.resetPassword('test@example.com'))
        .thenAnswer((_) async {});

    final container = makeContainer();
    final controller = container.read(authControllerProvider.notifier);

    await controller.resetPassword('test@example.com');
    verify(() => mockRepo.resetPassword('test@example.com')).called(1);
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('OAuth success', () async {
    when(() => mockRepo.signInWithOAuth(any()))
        .thenAnswer((_) async => true);

    final container = makeContainer();
    final controller = container.read(authControllerProvider.notifier);

    await controller.loginWithOAuth(OAuthProvider.google);
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('OAuth cancellation', () async {
    when(() => mockRepo.signInWithOAuth(any()))
        .thenAnswer((_) async => false);

    final container = makeContainer();
    final controller = container.read(authControllerProvider.notifier);

    await controller.loginWithOAuth(OAuthProvider.apple);
    // Cancellation should not be an error
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('OAuth failure', () async {
    when(() => mockRepo.signInWithOAuth(any()))
        .thenThrow(Exception('OAuth Failed'));

    final container = makeContainer();
    final controller = container.read(authControllerProvider.notifier);

    await controller.loginWithOAuth(OAuthProvider.google);
    expect(container.read(authControllerProvider).hasError, isTrue);
  });

  test('reset-password success', () async {
    when(() => mockRepo.updatePassword('new_password'))
        .thenAnswer((_) async {});

    final container = makeContainer();
    final controller = container.read(authControllerProvider.notifier);

    await controller.updatePassword('new_password');
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('reset-password failure', () async {
    when(() => mockRepo.updatePassword('new_password'))
        .thenThrow(Exception('Update failed'));

    final container = makeContainer();
    final controller = container.read(authControllerProvider.notifier);

    await controller.updatePassword('new_password');
    expect(container.read(authControllerProvider).hasError, isTrue);
  });
}
