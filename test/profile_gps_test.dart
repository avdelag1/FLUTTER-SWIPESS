import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/profile/data/profile_gps_service.dart';
import 'package:flutter_swipes/src/features/profile/data/repositories/profile_repository.dart';

class _RecordingProfileRepository implements ProfileRepository {
  final writes = <List<double>>[];

  @override
  Future<void> persistDeviceLocation({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    writes.add([latitude, longitude]);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _RecordingProfileRepository repository;
  late ProfileGpsService service;

  setUp(() {
    repository = _RecordingProfileRepository();
    service = ProfileGpsService(repository);
  });

  test('writes the first fix', () async {
    await service.persist(userId: 'u1', latitude: 20.21, longitude: -87.46);
    expect(repository.writes, [
      [20.21, -87.46],
    ]);
  });

  test(
    'skips a fix that has barely moved inside the throttle window',
    () async {
      await service.persist(userId: 'u1', latitude: 20.21, longitude: -87.46);
      // ~10 m away, seconds later.
      await service.persist(
        userId: 'u1',
        latitude: 20.2101,
        longitude: -87.4601,
      );
      expect(repository.writes, hasLength(1));
    },
  );

  test('writes again once the user has actually moved', () async {
    await service.persist(userId: 'u1', latitude: 20.21, longitude: -87.46);
    // ~1 km away.
    await service.persist(userId: 'u1', latitude: 20.22, longitude: -87.46);
    expect(repository.writes, hasLength(2));
  });

  test('a different account is never throttled by the previous one', () async {
    await service.persist(userId: 'u1', latitude: 20.21, longitude: -87.46);
    await service.persist(userId: 'u2', latitude: 20.21, longitude: -87.46);
    expect(repository.writes, hasLength(2));
  });

  test('signing out drops the throttle', () async {
    await service.persist(userId: 'u1', latitude: 20.21, longitude: -87.46);
    service.reset();
    await service.persist(userId: 'u1', latitude: 20.21, longitude: -87.46);
    expect(repository.writes, hasLength(2));
  });

  test('a nonsense fix is never written', () async {
    await service.persist(userId: 'u1', latitude: double.nan, longitude: 0);
    await service.persist(
      userId: 'u1',
      latitude: 0,
      longitude: double.infinity,
    );
    expect(repository.writes, isEmpty);
  });
}
