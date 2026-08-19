import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final rolePortalRepositoryProvider = Provider<RolePortalRepository>((ref) {
  return RolePortalRepository(Supabase.instance.client);
});

class RolePortalRepository {
  RolePortalRepository(this._client);

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<bool> isAdmin() async {
    final uid = currentUserId;
    if (uid == null) return false;
    try {
      final result = await _client.rpc(
        'is_admin_user',
        params: {'check_user_id': uid},
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<PortalLawyerProfile?> fetchCurrentLawyer() async {
    final uid = currentUserId;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('lawyer_users')
          .select(
            'id, user_id, full_name, email, bar_number, specialization, is_active, is_available, commission_rate',
          )
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return null;
      return PortalLawyerProfile.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLawyerAvailability(bool value) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not signed in');
    await _client
        .from('lawyer_users')
        .update({'is_available': value})
        .eq('user_id', uid);
  }

  Future<List<PortalLegalRequest>> fetchLegalRequests() async {
    final rows = await _client
        .from('legal_package_requests')
        .select(
          'id, requested_by, package_name, package_category, quoted_price, situation, full_name, email, phone, preferred_contact, request_type, status, lawyer_notes, created_at, updated_at',
        )
        .order('created_at', ascending: false)
        .limit(200);
    return [
      for (final row in rows as List)
        if (row is Map)
          PortalLegalRequest.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<void> updateLegalRequest({
    required String id,
    required String status,
    String? lawyerNotes,
  }) async {
    final result = await _client.rpc(
      'update_legal_request_workflow',
      params: {
        'p_request_id': id,
        'p_status': status,
        'p_lawyer_notes': lawyerNotes?.trim(),
      },
    );
    if (result != true) {
      throw StateError('Legal request could not be updated');
    }
  }

  Future<List<PortalVideoCall>> fetchLegalVideoCalls() async {
    final rows = await _client
        .from('legal_video_calls')
        .select(
          'id, client_user_id, client_name, client_email, lawyer_user_id, status, room_id, topic, created_at, answered_at, ended_at',
        )
        .order('created_at', ascending: false)
        .limit(100);
    return [
      for (final row in rows as List)
        if (row is Map)
          PortalVideoCall.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<bool> acceptLegalVideoCall(String callId) async {
    final result = await _client.rpc(
      'transition_legal_video_call',
      params: {'p_call_id': callId, 'p_status': 'accepted'},
    );
    return result == true;
  }

  Future<void> endLegalVideoCall(String callId) async {
    final result = await _client.rpc(
      'transition_legal_video_call',
      params: {'p_call_id': callId, 'p_status': 'ended'},
    );
    if (result != true) {
      throw StateError('Legal call could not be ended');
    }
  }

  Future<List<PortalBusinessSubmission>> fetchBusinessSubmissions({
    bool admin = false,
  }) async {
    var query = _client.from('business_promo_submissions').select(
      'id, user_id, title, business_name, event_type, business_type, location, contact_name, owner_name, contact_phone, whatsapp, website, image_url, photo_urls, video_url, status, created_at, updated_at',
    );
    final uid = currentUserId;
    if (!admin) {
      if (uid == null) return const [];
      query = query.eq('user_id', uid);
    }
    final rows = await query.order('created_at', ascending: false).limit(200);
    return [
      for (final row in rows as List)
        if (row is Map)
          PortalBusinessSubmission.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<AdminPortalOverview> fetchAdminOverview() async {
    final eventRows = await _client
        .from('events')
        .select('id, is_published, created_at')
        .order('created_at', ascending: false)
        .limit(500);
    final submissions = await fetchBusinessSubmissions(admin: true);
    final legal = await fetchLegalRequests();
    final lawyers = await _client
        .from('lawyer_users')
        .select('id, is_active, is_available')
        .limit(200);

    var publishedEvents = 0;
    for (final row in eventRows as List) {
      if (row is Map && row['is_published'] == true) publishedEvents++;
    }
    var pendingBusiness = 0;
    for (final row in submissions) {
      if (row.status == 'pending') pendingBusiness++;
    }
    var openLegal = 0;
    for (final row in legal) {
      if (!const {'completed', 'closed', 'cancelled'}.contains(row.status)) {
        openLegal++;
      }
    }
    var activeLawyers = 0;
    var availableLawyers = 0;
    for (final row in lawyers as List) {
      if (row is! Map) continue;
      if (row['is_active'] == true) activeLawyers++;
      if (row['is_active'] == true && row['is_available'] == true) {
        availableLawyers++;
      }
    }

    return AdminPortalOverview(
      totalEvents: (eventRows as List).length,
      publishedEvents: publishedEvents,
      businessSubmissions: submissions.length,
      pendingBusinessSubmissions: pendingBusiness,
      legalRequests: legal.length,
      openLegalRequests: openLegal,
      activeLawyers: activeLawyers,
      availableLawyers: availableLawyers,
    );
  }
}

class PortalLawyerProfile {
  const PortalLawyerProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.barNumber,
    required this.specialization,
    required this.isActive,
    required this.isAvailable,
    required this.commissionRate,
  });

  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String barNumber;
  final String specialization;
  final bool isActive;
  final bool isAvailable;
  final double commissionRate;

  factory PortalLawyerProfile.fromJson(Map<String, dynamic> json) {
    return PortalLawyerProfile(
      id: json['id']?.toString() ?? '',
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

class PortalLegalRequest {
  const PortalLegalRequest({
    required this.id,
    required this.packageName,
    required this.category,
    required this.price,
    required this.situation,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.preferredContact,
    required this.requestType,
    required this.status,
    required this.lawyerNotes,
    required this.createdAt,
  });

  final String id;
  final String packageName;
  final String category;
  final double price;
  final String situation;
  final String fullName;
  final String email;
  final String phone;
  final String preferredContact;
  final String requestType;
  final String status;
  final String lawyerNotes;
  final DateTime? createdAt;

  factory PortalLegalRequest.fromJson(Map<String, dynamic> json) {
    return PortalLegalRequest(
      id: json['id']?.toString() ?? '',
      packageName: json['package_name']?.toString() ?? 'Legal request',
      category: json['package_category']?.toString() ?? 'general',
      price: (json['quoted_price'] as num?)?.toDouble() ?? 0,
      situation: json['situation']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Client',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      preferredContact: json['preferred_contact']?.toString() ?? '',
      requestType: json['request_type']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      lawyerNotes: json['lawyer_notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class PortalVideoCall {
  const PortalVideoCall({
    required this.id,
    required this.clientName,
    required this.clientEmail,
    required this.lawyerUserId,
    required this.status,
    required this.roomId,
    required this.topic,
    required this.createdAt,
  });

  final String id;
  final String clientName;
  final String clientEmail;
  final String lawyerUserId;
  final String status;
  final String roomId;
  final String topic;
  final DateTime? createdAt;

  factory PortalVideoCall.fromJson(Map<String, dynamic> json) {
    return PortalVideoCall(
      id: json['id']?.toString() ?? '',
      clientName: json['client_name']?.toString() ?? 'Client',
      clientEmail: json['client_email']?.toString() ?? '',
      lawyerUserId: json['lawyer_user_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ringing',
      roomId: json['room_id']?.toString() ?? '',
      topic: json['topic']?.toString() ?? 'Legal consultation',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class PortalBusinessSubmission {
  const PortalBusinessSubmission({
    required this.id,
    required this.title,
    required this.type,
    required this.location,
    required this.contactName,
    required this.contactPhone,
    required this.website,
    required this.imageUrl,
    required this.videoUrl,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String type;
  final String location;
  final String contactName;
  final String contactPhone;
  final String website;
  final String imageUrl;
  final String videoUrl;
  final String status;
  final DateTime? createdAt;

  factory PortalBusinessSubmission.fromJson(Map<String, dynamic> json) {
    final photos = json['photo_urls'];
    String legacyPhoto = '';
    if (photos is List && photos.isNotEmpty) legacyPhoto = photos.first.toString();
    return PortalBusinessSubmission(
      id: json['id']?.toString() ?? '',
      title:
          json['title']?.toString().trim().isNotEmpty == true
              ? json['title'].toString()
              : (json['business_name']?.toString() ?? 'Promotion'),
      type:
          json['event_type']?.toString().trim().isNotEmpty == true
              ? json['event_type'].toString()
              : (json['business_type']?.toString() ?? 'business'),
      location: json['location']?.toString() ?? '',
      contactName:
          json['contact_name']?.toString().trim().isNotEmpty == true
              ? json['contact_name'].toString()
              : (json['owner_name']?.toString() ?? ''),
      contactPhone:
          json['contact_phone']?.toString().trim().isNotEmpty == true
              ? json['contact_phone'].toString()
              : (json['whatsapp']?.toString() ?? ''),
      website: json['website']?.toString() ?? '',
      imageUrl:
          json['image_url']?.toString().trim().isNotEmpty == true
              ? json['image_url'].toString()
              : legacyPhoto,
      videoUrl: json['video_url']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class AdminPortalOverview {
  const AdminPortalOverview({
    required this.totalEvents,
    required this.publishedEvents,
    required this.businessSubmissions,
    required this.pendingBusinessSubmissions,
    required this.legalRequests,
    required this.openLegalRequests,
    required this.activeLawyers,
    required this.availableLawyers,
  });

  final int totalEvents;
  final int publishedEvents;
  final int businessSubmissions;
  final int pendingBusinessSubmissions;
  final int legalRequests;
  final int openLegalRequests;
  final int activeLawyers;
  final int availableLawyers;
}