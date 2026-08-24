import 'package:flutter_swipes/src/features/business/domain/business_visit.dart';
import 'package:flutter_swipes/src/features/business/domain/business_workspace.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessWorkspaceRepository {
  BusinessWorkspaceRepository(this._client);

  final SupabaseClient _client;

  Future<BusinessWorkspace> fetch() async {
    final result = await _client.rpc('app_business_workspace');
    if (result is! Map) {
      throw StateError('Invalid business workspace response');
    }
    return BusinessWorkspace.fromJson(Map<String, dynamic>.from(result));
  }

  Future<BusinessVisit> scanMember(String payload, {String? notes}) async {
    final result = await _client.rpc(
      'app_business_scan_member',
      params: {'p_payload': payload, 'p_notes': notes},
    );
    if (result is! Map) {
      throw StateError('Invalid business scan response');
    }
    return BusinessVisit.fromJson(Map<String, dynamic>.from(result));
  }

  Future<BusinessTransactionResult> recordTransaction({
    required String scanId,
    required double totalAmount,
    required double discountPercentage,
    String? description,
  }) async {
    final result = await _client.rpc(
      'app_business_record_transaction',
      params: {
        'p_scan_id': scanId,
        'p_total_amount': totalAmount,
        'p_discount_percentage': discountPercentage,
        'p_order_description': description,
      },
    );
    if (result is! Map) {
      throw StateError('Invalid business transaction response');
    }
    return BusinessTransactionResult.fromJson(
      Map<String, dynamic>.from(result),
    );
  }

  Future<String?> sendPromo({
    required String userId,
    required double discountPercentage,
    String title = 'Partner Promo',
    String? message,
  }) async {
    final result = await _client.rpc(
      'send_business_customer_promo',
      params: {
        'p_user_id': userId,
        'p_discount_percent': discountPercentage,
        'p_title': title,
        'p_message': message,
        'p_expires_hours': 168,
      },
    );
    if (result is! Map) return null;
    return result['code']?.toString();
  }
}
