import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_swipes/src/features/profile/data/repositories/profile_repository.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_providers.dart';

/// Cap `useProfileGpsPersist`.
///
/// The Passport map reads `client_profiles.latitude/longitude` for its people
/// pins, but nothing in the Flutter build ever wrote them, so every member was
/// invisible on it. Cap refreshed the phone position at sign-in and on every
/// app resume, and stamped `location_source = 'device'` so the map can tell a
/// real position from a city-centroid backfill.
class ProfileGpsService {
  ProfileGpsService(this._repository);

  /// Cap's floor between two full GPS refreshes (sign-in and resume).
  static const minRefreshGap = Duration(minutes: 2);

  /// Cap's write throttle: skip a write that is both recent and barely moved
  /// (~100 m).
  static const minWriteGap = Duration(seconds: 30);
  static const _minMoveDegrees = 0.001;

  final ProfileRepository _repository;

  DateTime? _lastRefresh;
  DateTime? _lastWrite;
  double? _lastLatitude;
  double? _lastLongitude;
  String? _lastUserId;

  /// [force] is a sign-in; a resume passes `false` and respects the gap.
  Future<void> refresh({required String? userId, bool force = false}) async {
    if (userId == null || kIsWeb) return;
    final now = DateTime.now();
    if (!force &&
        _lastRefresh != null &&
        now.difference(_lastRefresh!) < minRefreshGap) {
      return;
    }
    _lastRefresh = now;

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // No fake city pin fallback, same as Cap.
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      await persist(
        userId: userId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      debugPrint('[ProfileGps] refresh skipped: $e');
    }
  }

  Future<void> persist({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    if (!latitude.isFinite || !longitude.isFinite) return;
    final visible = await _repository.fetchMapVisibleOnPassport();
    if (!visible) return;
    if (_isRedundant(userId, latitude, longitude)) return;

    _lastUserId = userId;
    _lastLatitude = latitude;
    _lastLongitude = longitude;
    _lastWrite = DateTime.now();
    try {
      await _repository.persistDeviceLocation(
        userId: userId,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      debugPrint('[ProfileGps] write failed: $e');
    }
  }

  bool _isRedundant(String userId, double latitude, double longitude) {
    if (_lastUserId != userId || _lastWrite == null) return false;
    if (DateTime.now().difference(_lastWrite!) >= minWriteGap) return false;
    return (latitude - (_lastLatitude ?? 0)).abs() < _minMoveDegrees &&
        (longitude - (_lastLongitude ?? 0)).abs() < _minMoveDegrees;
  }

  /// Signing out must not let the next account inherit this throttle.
  void reset() {
    _lastUserId = null;
    _lastWrite = null;
    _lastRefresh = null;
    _lastLatitude = null;
    _lastLongitude = null;
  }
}

final profileGpsServiceProvider = Provider<ProfileGpsService>((ref) {
  return ProfileGpsService(ref.watch(profileRepositoryProvider));
});
