import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final legalAdminRepositoryProvider = Provider<LegalAdminRepository>((ref) {
  return LegalAdminRepository(Supabase.instance.client);
});

class LegalAdminRepository {
  LegalAdminRepository(this._client);

  final SupabaseClient _client;

  Future<List<LegalAdminLawyer>> fetchLawyers() async {
    final rows = await _client
        .from('lawyer_users')
        .select(
          'id, user_id, full_name, email, bar_number, specialization, role, is_active, is_available, commission_rate, created_at',
        )
        .order('created_at', ascending: false)
        .limit(200);
    return [
      for (final row in rows as List)
        if (row is Map)
          LegalAdminLawyer.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<void> setLawyerActive(String userId, bool value) async {
    await _client
        .from('lawyer_users')
        .update({'is_active': value, if (!value) 'is_available': false})
        .eq('user_id', userId);
  }
}

class LegalAdminLawyer {
  const LegalAdminLawyer({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.barNumber,
    required this.specialization,
    required this.isActive,
    required this.isAvailable,
    required this.commissionRate,
  });

  final String userId;
  final String fullName;
  final String email;
  final String barNumber;
  final String specialization;
  final bool isActive;
  final bool isAvailable;
  final double commissionRate;

  factory LegalAdminLawyer.fromJson(Map<String, dynamic> json) {
    return LegalAdminLawyer(
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Lawyer',
      email: json['email']?.toString() ?? '',
      barNumber: json['bar_number']?.toString() ?? '',
      specialization: json['specialization']?.toString() ?? '',
      isActive: json['is_active'] == true,
      isAvailable: json['is_available'] == true,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}
