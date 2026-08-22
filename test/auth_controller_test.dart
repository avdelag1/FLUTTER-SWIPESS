import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_controller.dart';
import 'package:flutter_swipes/src/features/auth/data/auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockAuthResponse extends Mock implements AuthResponse {}

class TestCurrentUserNotifier extends CurrentUserNotifier {
  @override
  User? build() => null;

  @override
  void apply(User? user) {
    state = user;
  }

  @override
  void clear() {
    state = null;
  }
}

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
        currentUserProvider.overrideWith(TestCurrentUserNotifier.new),
      ],
    );
  }

  MockAuthResponse successResponse() {
    final response = MockAuthResponse();
    when(() => response.user).thenReturn(null);
    return response;
  }

  test('login success', () async {
    final response = successResponse();
    when(() => mockRepo.signInWithEmailPassword('test@example.com', 'password'))
        .thenAnswer((_) async => response);

    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);

    expect(await controller.login('test@example.com', 'password'), isTrue);
    verify(() => mockRepo.signInWithEmailPassword('test@example.com', 'password')).called(1);
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('login failure', () async {
    when(() => mockRepo.signInWithEmailPassword('test@example.com', 'password'))
        .thenThrow(Exception('Invalid login'));

    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);

    expect(await controller.login('test@example.com', 'password'), isFalse);
    expect(container.read(authControllerProvider).hasError, isTrue);
  });

  test('sign-up success', () async {
    final response = successResponse();
    when(() => mockRepo.signUpWithEmailPassword('test@example.com', 'password', name: any(named: 'name')))
        .thenAnswer((_) async => response);

    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);

    expect(await controller.signup('test@example.com', 'password'), isTrue);
    verify(() => mockRepo.signUpWithEmailPassword('test@example.com', 'password', name: any(named: 'name'))).called(1);
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('forgot-password success', () async {
    when(() => mockRepo.resetPassword('test@example.com'))
        .thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);

    expect(await controller.resetPassword('test@example.com'), isTrue);
    verify(() => mockRepo.resetPassword('test@example.com')).called(1);
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('OAuth success', () async {
    when(() => mockRepo.signInWithOAuth(any()))
        .thenAnswer((_) async => true);

    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);

    expect(await controller.loginWithOAuth(OAuthProvider.google), isTrue);
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('OAuth cancellation', () async {
    when(() => mockRepo.signInWithOAuth(any()))
        .thenAnswer((_) async => false);

    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);

    expect(await controller.loginWithOAuth(OAuthProvider.apple), isFalse);
    // Cancellation should not be an error.
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('OAuth failure', () async {
    when(() => mockRepo.signInWithOAuth(any()))
        .thenThrow(Exception('OAuth Failed'));

    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);

    expect(await controller.loginWithOAuth(OAuthProvider.google), isFalse);
    expect(container.read(authControllerProvider).hasError, isTrue);
  });

  test('reset-password success', () async {
    when(() => mockRepo.updatePassword('new_password'))
        .thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);

    expect(await controller.updatePassword('new_password'), isTrue);
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('reset-password failure', () async {
    when(() => mockRepo.updatePassword('new_password'))
        .thenThrow(Exception('Update failed'));

    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);

    expect(await controller.updatePassword('new_password'), isFalse);
    expect(container.read(authControllerProvider).hasError, isTrue);
  });
}
