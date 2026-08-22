import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/invite_friends_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppTheme.dashBg,
        colorScheme: const ColorScheme.dark(primary: AppTheme.brandPrimary),
      ),
      home: Scaffold(
        backgroundColor: AppTheme.dashBg,
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  test('referral URL includes the user id', () {
    expect(InviteLinks.referralUrl(null), 'https://www.swipess.com');
    expect(
      InviteLinks.referralUrl('user-123'),
      'https://www.swipess.com/?ref=user-123',
    );
  });

  testWidgets(
    'invite section shows header, labeled link, and full share actions',
    (tester) async {
      await tester.pumpWidget(
        wrap(const InviteFriendsSection(profileId: 'user-123')),
      );

      expect(find.text('Invite Friends'), findsOneWidget);
      expect(
        find.text('Share your link and earn free messages'),
        findsOneWidget,
      );
      expect(find.text('Your invite link'), findsOneWidget);
      expect(
        find.text('https://www.swipess.com/?ref=user-123'),
        findsOneWidget,
      );
      expect(find.text('Copy Link'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('TikTok'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      expect(find.textContaining('5 Direct Requests'), findsOneWidget);

      expect(find.text('INVITE FRIENDS'), findsNothing);
      expect(find.text('SHARE & EARN'), findsNothing);
      expect(find.text('WA'), findsNothing);
      expect(find.text('IG'), findsNothing);
      expect(find.text('TT'), findsNothing);
    },
  );

  testWidgets('Copy Link copies the referral URL', (tester) async {
    await tester.pumpWidget(
      wrap(const InviteFriendsSection(profileId: 'user-123')),
    );

    await tester.tap(find.text('Copy Link'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Invite link copied'), findsOneWidget);
  });
}
