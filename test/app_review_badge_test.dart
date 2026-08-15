import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_swipes/src/core/native/app_badge.dart';
import 'package:flutter_swipes/src/core/native/app_review.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/providers/messages_provider.dart';
import 'package:flutter_swipes/src/features/notifications/presentation/providers/notifications_provider.dart';

class _FakeInAppReview implements InAppReview {
  int requested = 0;
  bool available = true;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requested++;

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeInAppReview review;

  setUp(() {
    review = _FakeInAppReview();
    SharedPreferences.setMockInitialValues({});
  });

  test('stays quiet on the first match, asks on the second', () async {
    final gate = AppReview(review: review);

    expect(await gate.maybeRequestAfterMatch(), isFalse);
    expect(review.requested, 0);

    expect(await gate.maybeRequestAfterMatch(), isTrue);
    expect(review.requested, 1);
  });

  test('does not ask again inside the 90-day window', () async {
    final gate = AppReview(review: review);
    await gate.maybeRequestAfterMatch();
    await gate.maybeRequestAfterMatch();
    expect(review.requested, 1);

    expect(await gate.maybeRequestAfterMatch(), isFalse);
    expect(await gate.maybeRequestAfterMatch(), isFalse);
    expect(review.requested, 1);
  });

  test('asks again once the cooldown has passed', () async {
    SharedPreferences.setMockInitialValues({
      'swipess_review_matches': 5,
      'swipess_review_last_asked': DateTime.now()
          .subtract(const Duration(days: 91))
          .millisecondsSinceEpoch,
    });

    expect(await AppReview(review: review).maybeRequestAfterMatch(), isTrue);
    expect(review.requested, 1);
  });

  test('a store that cannot show the prompt still counts the match', () async {
    review.available = false;
    final gate = AppReview(review: review);
    await gate.maybeRequestAfterMatch();
    await gate.maybeRequestAfterMatch();

    expect(review.requested, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('swipess_review_matches'), 2);
    // Nothing was shown, so the 90-day clock must not have started.
    expect(prefs.getInt('swipess_review_last_asked'), isNull);
  });

  group('unreadBadgeCountProvider (Cap useAppBadge)', () {
    ChatConversation conversation(int unread) => ChatConversation(
      id: 'c$unread',
      otherUserId: 'u$unread',
      name: 'Someone',
      lastMessage: 'hey',
      timestamp: 'now',
      unreadCount: unread,
    );

    ProviderContainer containerWith({
      required int notifications,
      required List<ChatConversation> conversations,
    }) {
      final container = ProviderContainer(
        overrides: [
          unreadNotificationsProvider.overrideWith((_) async => notifications),
          conversationsProvider.overrideWith(
            () => _FakeConversations(conversations),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('adds unread pulses to unread conversations', () async {
      final container = containerWith(
        notifications: 3,
        conversations: [conversation(2), conversation(4)],
      );
      await container.read(unreadNotificationsProvider.future);
      await container.read(conversationsProvider.future);

      expect(container.read(unreadBadgeCountProvider), 9);
    });

    test('is zero when everything is read', () async {
      final container = containerWith(
        notifications: 0,
        conversations: [conversation(0)],
      );
      await container.read(unreadNotificationsProvider.future);
      await container.read(conversationsProvider.future);

      expect(container.read(unreadBadgeCountProvider), 0);
    });
  });
}

class _FakeConversations extends ConversationsNotifier {
  _FakeConversations(this.items);

  final List<ChatConversation> items;

  @override
  Future<List<ChatConversation>> build() async => items;
}
