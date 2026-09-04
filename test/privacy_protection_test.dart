import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/native/privacy_screen.dart';
import 'package:flutter_swipes/src/core/widgets/protected_media.dart';
import 'package:flutter_swipes/src/features/documents/domain/legal_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('identity, contracts and fideicomiso are sensitive originals', () {
    LegalDocument doc(String type) => LegalDocument(
      id: type,
      fileName: '$type.jpg',
      filePath: 'path/$type.jpg',
      documentType: type,
      status: 'approved',
      createdAt: DateTime.utc(2026, 9, 1),
    );

    expect(doc('passport').isSensitive, isTrue);
    expect(doc('government_id').isSensitive, isTrue);
    expect(doc('rental_agreement').isSensitive, isTrue);
    expect(doc('fideicomiso').isSensitive, isTrue);
    expect(doc('recommendation').isSensitive, isFalse);
  });

  testWidgets('protected media paints a watermark over copy-concern content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProtectedMedia(
          watermark: true,
          absorbLongPress: false,
          child: SizedBox(width: 120, height: 120),
        ),
      ),
    );
    expect(find.byType(SwipessWatermark), findsOneWidget);
    expect(find.text('SWIPESS'), findsWidgets);
  });

  testWidgets('privacy guard still reference-counts nested identity surfaces', (
    tester,
  ) async {
    PrivacyScreen.resetForTest();
    await tester.pumpWidget(
      const MaterialApp(
        home: PrivacyScreenGuard(
          child: PrivacyScreenGuard(child: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();
    expect(PrivacyScreen.holders, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(PrivacyScreen.holders, 0);
  });
}
