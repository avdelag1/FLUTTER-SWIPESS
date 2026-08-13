import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/widgets/search_frame_shine.dart';

void main() {
  testWidgets('search frame shine paints a CustomPaint over the bar',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SearchFrameShine(
            color: Color(0xFF93C5FD),
            child: SizedBox(width: 280, height: 56),
          ),
        ),
      ),
    );
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SearchFrameShine), findsOneWidget);
  });
}
