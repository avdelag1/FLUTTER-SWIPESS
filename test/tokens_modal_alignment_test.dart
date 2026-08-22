import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/payments/domain/iap_catalog.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';

void main() {
  testWidgets('every token purchase label is centered inside its offer button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          directRequestBalanceProvider.overrideWith(
            (ref) async => const DirectRequestBalance(
              total: 6,
              reserved: 1,
              available: 5,
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TokensModal()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buttons = find.byType(FilledButton);
    final labels = find.text('GET');
    expect(buttons, findsNWidgets(IapCatalog.tokens.length));
    expect(labels, findsNWidgets(IapCatalog.tokens.length));

    for (var i = 0; i < IapCatalog.tokens.length; i++) {
      final buttonCenter = tester.getCenter(buttons.at(i));
      final labelCenter = tester.getCenter(labels.at(i));
      expect((buttonCenter.dx - labelCenter.dx).abs(), lessThan(1));
      expect((buttonCenter.dy - labelCenter.dy).abs(), lessThan(1));
    }

    expect(tester.takeException(), isNull);
  });
}
