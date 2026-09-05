import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/widgets/app_action_banner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('action banner appears at the top and auto dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => AppActionBanner.success(
                  context,
                  title: 'Listing published',
                  detail: 'It is live on the swipe deck.',
                  duration: const Duration(milliseconds: 500),
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Listing published'), findsOneWidget);
    expect(find.text('It is live on the swipe deck.'), findsOneWidget);

    final bannerTop = tester.getTopLeft(find.text('Listing published')).dy;
    expect(bannerTop, lessThan(160));

    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Listing published'), findsNothing);
  });

  testWidgets('a new action replaces the previous banner', (tester) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    AppActionBanner.info(
      hostContext,
      title: 'Saving listing',
      duration: const Duration(seconds: 5),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Saving listing'), findsOneWidget);

    AppActionBanner.success(
      hostContext,
      title: 'Listing updated',
      duration: const Duration(milliseconds: 500),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Saving listing'), findsNothing);
    expect(find.text('Listing updated'), findsOneWidget);
  });
}
