import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/legal/domain/contract_templates.dart';

void main() {
  test('Swipess Sign keeps a broad ready-made legal template library', () {
    expect(contractTemplates.length, greaterThanOrEqualTo(10));
    expect(
      contractTemplates.any((t) => t.id == 'lease-residential-12-month'),
      isTrue,
    );
    expect(
      contractTemplates.any((t) => t.id == 'lease-month-to-month'),
      isTrue,
    );
    expect(
      contractTemplates.any((t) => t.id == 'lease-furnished-apartment'),
      isTrue,
    );
    expect(
      contractTemplates.any((t) => t.id == 'lease-commercial'),
      isTrue,
    );
    expect(
      contractTemplates.any((t) => t.id == 'lease-room-rental'),
      isTrue,
    );
  });
}
