import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/legal/domain/contract_templates.dart';
import 'package:flutter_swipes/src/features/legal/domain/digital_contract.dart';

void main() {
  group('Swipess Sign templates', () {
    test('ships a broad marketplace document library', () {
      expect(contractTemplates.length, greaterThanOrEqualTo(12));
      expect(
        contractTemplates.map((t) => t.id),
        containsAll(<String>[
          'lease-residential-12-month',
          'lease-month-to-month',
          'short-term-rental',
          'property-sale-contract',
          'bicycle-rental-agreement',
          'motorcycle-rental-agreement',
          'yacht-charter-agreement',
          'service-agreement',
          'mutual-nda',
        ]),
      );
    });

    test('Quick Fill replaces supplied values and leaves missing fields visible', () {
      final template = contractTemplates.firstWhere(
        (t) => t.id == 'lease-residential-12-month',
      );
      final output = template.applyValues(<String, String>{
        'landlord_name': 'Owner Example',
        'tenant_name': 'Tenant Example',
      });

      expect(output, contains('Owner Example'));
      expect(output, contains('Tenant Example'));
      expect(output, isNot(contains('{{landlord_name}}')));
      expect(output, isNot(contains('{{tenant_name}}')));
    });
  });

  group('Swipess Sign state rules', () {
    const owner = '11111111-1111-1111-1111-111111111111';
    const client = '22222222-2222-2222-2222-222222222222';

    test('draft belongs to creator and can be edited', () {
      const contract = DigitalContract(
        id: 'contract-1',
        title: 'Lease',
        status: 'draft',
        ownerId: owner,
        clientId: owner,
        createdBy: owner,
      );

      expect(contract.isDraft, isTrue);
      expect(contract.canEdit(owner), isTrue);
      expect(contract.isLocked, isFalse);
    });

    test('sent document locks editing and exposes correct signer needs', () {
      const contract = DigitalContract(
        id: 'contract-2',
        title: 'Lease',
        status: 'sent',
        ownerId: owner,
        clientId: client,
        createdBy: owner,
      );

      expect(contract.isLocked, isTrue);
      expect(contract.canEdit(owner), isFalse);
      expect(contract.needsSignature(owner), isTrue);
      expect(contract.needsSignature(client), isTrue);
    });

    test('completed document needs no more signatures', () {
      final now = DateTime.utc(2026, 8, 22);
      final contract = DigitalContract(
        id: 'contract-3',
        title: 'Lease',
        status: 'completed',
        ownerId: owner,
        clientId: client,
        createdBy: owner,
        ownerSignedAt: now,
        clientSignedAt: now,
      );

      expect(contract.isCompleted, isTrue);
      expect(contract.needsSignature(owner), isFalse);
      expect(contract.needsSignature(client), isFalse);
      expect(contract.compactStatusLabel, 'SIGNED');
    });
  });
}
