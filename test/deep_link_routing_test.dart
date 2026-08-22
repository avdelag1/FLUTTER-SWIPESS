import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/routing/app_redirect.dart';
import 'package:flutter_swipes/src/core/routing/pending_deep_link.dart';

/// Shorthand for the redirect decision at a given point in the gate/auth flow.
/// Routing tests model the web gate explicitly; native production bypasses it.
String? redirect(
  String location, {
  bool granted = true,
  bool signedIn = true,
  bool grantLoading = false,
  bool platformIsWeb = true,
  PendingDeepLink? pending,
  String? uri,
}) {
  return AppRedirect.resolve(
    location: location,
    uri: uri ?? location,
    grantLoading: grantLoading,
    granted: granted,
    signedIn: signedIn,
    pending: pending ?? PendingDeepLink(),
    platformIsWeb: platformIsWeb,
  );
}

void main() {
  group('public share links', () {
    test('resolve without the access gate or a session', () {
      for (final path in const [
        '/preview/listing/abc',
        '/preview/profile/abc',
        '/u/abc',
        '/vap-validate/abc',
        '/s/listing/abc',
        AppPaths.resetPassword,
        AppPaths.paymentSuccess,
        AppPaths.legal,
      ]) {
        expect(
          redirect(path, granted: false, signedIn: false),
          isNull,
          reason: '$path should render for a signed-out guest',
        );
      }
    });

    test('the /u/ member link the share sheets hand out is public', () {
      expect(AppRedirect.isPublic('/u/9f3a'), isTrue);
    });
  });

  group('gated deep links', () {
    test('a listing link bounces to the web gate and is remembered', () {
      final pending = PendingDeepLink();
      expect(
        redirect(
          '/listing/42',
          granted: false,
          signedIn: false,
          pending: pending,
        ),
        AppPaths.gate,
      );
      expect(pending.peek, '/listing/42');
    });

    test('after the gate it bounces to welcome, still remembered', () {
      final pending = PendingDeepLink();
      expect(
        redirect('/listing/42', signedIn: false, pending: pending),
        AppPaths.welcome,
      );
      expect(pending.peek, '/listing/42');
    });

    test('signing in lands on the remembered link, not the dashboard', () {
      final pending = PendingDeepLink()..remember('/listing/42');
      expect(redirect(AppPaths.auth, pending: pending), '/listing/42');
    });

    test('the link only resumes once', () {
      final pending = PendingDeepLink()..remember('/listing/42');
      expect(redirect(AppPaths.auth, pending: pending), '/listing/42');
      expect(
        redirect(AppPaths.welcome, pending: pending),
        AppPaths.clientDashboard,
      );
    });

    test('query strings survive the round trip', () {
      final pending = PendingDeepLink();
      redirect(
        AppPaths.exploreEvents,
        signedIn: false,
        pending: pending,
        uri: '/explore/events?city=tulum',
      );
      expect(
        redirect(AppPaths.auth, pending: pending),
        '/explore/events?city=tulum',
      );
    });

    test('with nothing queued, signing in lands on the dashboard', () {
      expect(redirect(AppPaths.auth), AppPaths.clientDashboard);
    });
  });

  group('pending deep link', () {
    test('never queues a gate or auth screen, which would loop', () {
      for (final path in const [
        '/',
        AppPaths.gate,
        AppPaths.welcome,
        AppPaths.onboarding,
        AppPaths.auth,
        AppPaths.resetPassword,
        AppPaths.clientDashboard,
        AppPaths.legacyDashboard,
      ]) {
        expect(PendingDeepLink.isResumable(path), isFalse, reason: path);
      }
    });

    test('queues real destinations', () {
      for (final path in const [
        '/listing/42',
        '/explore/events/7',
        AppPaths.messages,
        AppPaths.clientVapId,
      ]) {
        expect(PendingDeepLink.isResumable(path), isTrue, reason: path);
      }
    });

    test('take clears, so a second read is empty', () {
      final pending = PendingDeepLink()..remember('/listing/42');
      expect(pending.take(), '/listing/42');
      expect(pending.take(), isNull);
    });

    test('a queued path with a query is still matched against its path', () {
      final pending = PendingDeepLink()..remember('/client/dashboard?tab=1');
      expect(pending.peek, isNull);
    });
  });

  group('gate flow', () {
    test('an ungated web launch stays on the gate', () {
      expect(redirect(AppPaths.gate, granted: false, signedIn: false), isNull);
    });

    test('native launch bypasses the access-code gate', () {
      expect(
        redirect(
          '/listing/42',
          granted: false,
          signedIn: false,
          platformIsWeb: false,
        ),
        AppPaths.welcome,
      );
    });

    test('passing the gate moves on to welcome', () {
      expect(redirect(AppPaths.gate, signedIn: false), AppPaths.welcome);
    });

    test('a signed-in user never sits on an auth screen', () {
      for (final path in const [
        AppPaths.gate,
        AppPaths.welcome,
        AppPaths.onboarding,
        AppPaths.auth,
      ]) {
        expect(redirect(path), AppPaths.clientDashboard, reason: path);
      }
    });

    test('a signed-in web user who skipped the gate stays on the gate', () {
      expect(
        redirect(AppPaths.clientDashboard, granted: false, signedIn: true),
        AppPaths.gate,
      );
      expect(redirect(AppPaths.gate, granted: false, signedIn: true), isNull);
    });

    test('grant loading routes protected content to splash', () {
      expect(
        redirect(
          '/listing/42',
          grantLoading: true,
          granted: false,
          signedIn: false,
        ),
        AppPaths.splash,
      );
      expect(
        redirect(
          AppPaths.splash,
          grantLoading: true,
          granted: false,
          signedIn: false,
        ),
        isNull,
      );
    });
  });

  group('Capacitor path aliases', () {
    test('legacy aliases map onto their Flutter home', () {
      expect(redirect('/'), AppPaths.gate);
      expect(redirect(AppPaths.legacyDashboard), AppPaths.clientDashboard);
      expect(redirect(AppPaths.exploreServices), AppPaths.clientServices);
      expect(redirect('/promote'), AppPaths.clientAdvertise);
      expect(redirect('/privacy-policy'), '${AppPaths.legal}?doc=privacy');
      expect(redirect('/terms-of-service'), '${AppPaths.legal}?doc=terms');
      expect(redirect('/agl'), '${AppPaths.legal}?doc=agl');
      expect(redirect('/share-target'), AppPaths.clientDashboard);
    });

    test('real owner and authenticated routes are left alone', () {
      expect(redirect(AppPaths.ownerDashboard), isNull);
      expect(redirect(AppPaths.ownerProfile), isNull);
      expect(redirect(AppPaths.messages), isNull);
      expect(redirect('/listing/42'), isNull);
    });
  });
}
