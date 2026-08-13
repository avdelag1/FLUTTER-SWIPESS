import 'dart:math';

import 'package:flutter_swipes/src/features/legal/domain/legal_service_package.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LegalRepository {
  LegalRepository(this._client);
  final SupabaseClient _client;

  Future<List<LegalServicePackage>> fetchActivePackages() async {
    try {
      final response = await _client
          .from('legal_service_packages')
          .select()
          .eq('is_active', true)
          .order('category')
          .order('price');
      return (response as List<dynamic>)
          .map((e) => LegalServicePackage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> submitLegalCase({
    required String caseNumber,
    required String title,
    required String description,
    required String caseType,
    required String priority,
    required Map<String, dynamic> partiesInvolved,
  }) async {
    await _client.from('legal_cases').insert({
      'case_number': caseNumber,
      'title': title,
      'description': description,
      'case_type': caseType,
      'priority': priority,
      'status': 'open',
      'parties_involved': partiesInvolved,
    });
  }

  Future<({String fullName, String email, String phone})> fetchProfilePrefill(
    String userId,
    String? userEmail,
  ) async {
    try {
      final row = await _client
          .from('profiles')
          .select('name, full_name, phone, contact_phone, contact_email, email')
          .eq('id', userId)
          .maybeSingle();
      final map = row ?? const <String, dynamic>{};
      final fullName = (map['full_name'] as String?)?.trim().isNotEmpty == true
          ? map['full_name'] as String
          : (map['name'] as String? ?? '');
      final email = (map['contact_email'] as String?)?.trim().isNotEmpty == true
          ? map['contact_email'] as String
          : (map['email'] as String? ?? userEmail ?? '');
      final phone = (map['contact_phone'] as String?)?.trim().isNotEmpty == true
          ? map['contact_phone'] as String
          : (map['phone'] as String? ?? '');
      return (fullName: fullName, email: email, phone: phone);
    } catch (_) {
      return (fullName: '', email: userEmail ?? '', phone: '');
    }
  }

  /// Cap `submitLegalPackageRequest`.
  Future<void> submitPackageRequest({
    required String userId,
    required String packageId,
    required String packageName,
    required String packageCategory,
    required double quotedPrice,
    required String situation,
    required String fullName,
    required String email,
    required String phone,
    required String preferredContact,
    required String requestType,
  }) async {
    await _client.from('legal_package_requests').insert({
      'requested_by': userId,
      'package_id': packageId.startsWith('seed-') || packageId.startsWith('contract-')
          ? null
          : packageId,
      'package_name': packageName,
      'package_category': packageCategory,
      'quoted_price': quotedPrice,
      'situation': situation,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'preferred_contact': preferredContact,
      'request_type': requestType,
      'status': 'pending',
      'source': 'swipess_app',
    });
  }

  Future<int> countAvailableLawyers() async {
    try {
      final data = await _client.rpc('count_available_lawyers');
      return (data as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<LegalVideoCall> startVideoCall({
    required String clientUserId,
    String? clientName,
    String? clientEmail,
    String topic = 'Legal video consultation',
  }) async {
    final available = await countAvailableLawyers();
    if (available < 1) {
      throw const LegalVideoException('NO_LAWYERS_AVAILABLE');
    }
    final id = _uuidV4();
    final roomId = 'SwipessLegal-${id.replaceAll('-', '').substring(0, 16)}';
    await _client.from('legal_video_calls').insert({
      'id': id,
      'client_user_id': clientUserId,
      'client_name': clientName,
      'client_email': clientEmail,
      'status': 'ringing',
      'room_id': roomId,
      'topic': topic,
    });
    return LegalVideoCall(
      id: id,
      roomId: roomId,
      status: 'ringing',
    );
  }

  Future<void> updateVideoCallStatus(String callId, String status) async {
    final ended = {'ended', 'missed', 'cancelled', 'declined'}.contains(status);
    await _client.from('legal_video_calls').update({
      'status': status,
      if (ended) 'ended_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', callId);
  }

  Stream<Map<String, dynamic>> watchVideoCall(String callId) {
    return _client
        .from('legal_video_calls')
        .stream(primaryKey: ['id'])
        .eq('id', callId)
        .map((rows) => rows.isEmpty ? <String, dynamic>{} : rows.first);
  }

  static String jitsiUrl(String roomId, String displayName) {
    final safeRoom = roomId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final name = Uri.encodeComponent(
      displayName.length > 40 ? displayName.substring(0, 40) : displayName,
    );
    return 'https://meet.jit.si/$safeRoom#userInfo.displayName="$name"'
        '&config.prejoinConfig.enabled=false'
        '&config.startWithAudioMuted=false'
        '&config.startWithVideoMuted=false';
  }

  static String _uuidV4() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String h(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
    return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
        '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
  }
}

class LegalVideoCall {
  const LegalVideoCall({
    required this.id,
    required this.roomId,
    required this.status,
  });

  final String id;
  final String roomId;
  final String status;
}

class LegalVideoException implements Exception {
  const LegalVideoException(this.code);
  final String code;

  @override
  String toString() => code;
}
