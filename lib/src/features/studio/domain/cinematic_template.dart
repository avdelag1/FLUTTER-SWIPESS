import 'dart:math' as math;

enum StudioCategory { property, motorcycle, bicycle, worker, yacht, jet }

enum StudioTransition {
  crossFade,
  hardCut,
  pushLeft,
  pushUp,
  splitVertical,
  splitHorizontal,
}

enum StudioEasing { linear, easeIn, easeOut, easeInOut }

/// How one source photo is framed inside Studio's fixed 9:16 movie.
/// [portrait] is the default full-bleed crop; [fit] preserves the entire photo.
enum StudioPhotoFit { portrait, fit }

class StudioPoint {
  const StudioPoint(this.x, this.y);

  final double x;
  final double y;

  Map<String, dynamic> toJson() => <String, dynamic>{'x': x, 'y': y};

  factory StudioPoint.fromJson(Map<String, dynamic> json) => StudioPoint(
    (json['x'] as num?)?.toDouble() ?? 0,
    (json['y'] as num?)?.toDouble() ?? 0,
  );

  static const center = StudioPoint(0, 0);
}

class StudioFocalPoint {
  const StudioFocalPoint({this.x = .5, this.y = .5});

  /// Normalized source-image focal point in the inclusive 0..1 range.
  final double x;
  final double y;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'x': x.clamp(0.0, 1.0),
    'y': y.clamp(0.0, 1.0),
  };

  factory StudioFocalPoint.fromJson(Map<String, dynamic> json) =>
      StudioFocalPoint(
        x: ((json['x'] as num?)?.toDouble() ?? .5).clamp(0.0, 1.0),
        y: ((json['y'] as num?)?.toDouble() ?? .5).clamp(0.0, 1.0),
      );
}

class CinematicShot {
  const CinematicShot({
    required this.durationSeconds,
    this.startScale = 1.04,
    this.endScale = 1.12,
    this.startPosition = StudioPoint.center,
    this.endPosition = StudioPoint.center,
    this.easing = StudioEasing.easeInOut,
    this.transition = StudioTransition.crossFade,
    this.transitionSeconds = .45,
    this.cutAt = .5,
  });

  final double durationSeconds;
  final double startScale;
  final double endScale;

  /// Normalized travel relative to the cropped frame. Keep values small
  /// (roughly -0.16..0.16) so portrait output never exposes empty edges.
  final StudioPoint startPosition;
  final StudioPoint endPosition;
  final StudioEasing easing;
  final StudioTransition transition;
  final double transitionSeconds;

  /// Split transition pivot in the 0..1 range.
  final double cutAt;

  CinematicShot copyWith({
    double? durationSeconds,
    double? startScale,
    double? endScale,
    StudioPoint? startPosition,
    StudioPoint? endPosition,
    StudioEasing? easing,
    StudioTransition? transition,
    double? transitionSeconds,
    double? cutAt,
  }) => CinematicShot(
    durationSeconds: durationSeconds ?? this.durationSeconds,
    startScale: startScale ?? this.startScale,
    endScale: endScale ?? this.endScale,
    startPosition: startPosition ?? this.startPosition,
    endPosition: endPosition ?? this.endPosition,
    easing: easing ?? this.easing,
    transition: transition ?? this.transition,
    transitionSeconds: transitionSeconds ?? this.transitionSeconds,
    cutAt: cutAt ?? this.cutAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'duration': durationSeconds,
    'start_scale': startScale,
    'end_scale': endScale,
    'start_position': startPosition.toJson(),
    'end_position': endPosition.toJson(),
    'easing': easing.name,
    'transition': transition.name,
    'transition_duration': transitionSeconds,
    'cut_at': cutAt,
  };
}

class StudioFrameState {
  const StudioFrameState({
    required this.imageIndex,
    required this.nextImageIndex,
    required this.shotProgress,
    required this.transitionProgress,
    required this.scale,
    required this.x,
    required this.y,
    required this.transition,
  });

  final int imageIndex;
  final int nextImageIndex;
  final double shotProgress;
  final double transitionProgress;
  final double scale;
  final double x;
  final double y;
  final StudioTransition transition;
}

class CinematicTemplate {
  const CinematicTemplate({
    required this.id,
    required this.version,
    required this.name,
    required this.category,
    required this.description,
    required this.audioPresetId,
    required this.shotPattern,
    this.width = 1080,
    this.height = 1920,
    this.fps = 30,
  });

  final String id;
  final int version;
  final String name;
  final StudioCategory category;
  final String description;
  final String audioPresetId;
  final int width;
  final int height;
  final int fps;
  final List<CinematicShot> shotPattern;

  List<CinematicShot> shotsFor(int photoCount) {
    if (photoCount <= 0 || shotPattern.isEmpty) return const <CinematicShot>[];
    return List<CinematicShot>.generate(
      photoCount,
      (index) => shotPattern[index % shotPattern.length],
      growable: false,
    );
  }

  double totalDurationFor(int photoCount) => shotsFor(
    photoCount,
  ).fold<double>(0, (sum, shot) => sum + shot.durationSeconds);

  StudioFrameState resolveAtSeconds(double elapsedSeconds, int photoCount) {
    final shots = shotsFor(photoCount);
    if (shots.isEmpty) {
      return const StudioFrameState(
        imageIndex: 0,
        nextImageIndex: 0,
        shotProgress: 0,
        transitionProgress: 0,
        scale: 1,
        x: 0,
        y: 0,
        transition: StudioTransition.hardCut,
      );
    }

    final total = totalDurationFor(photoCount);
    final wrapped = total <= 0
        ? 0.0
        : ((elapsedSeconds % total) + total) % total;
    var cursor = 0.0;
    var index = shots.length - 1;
    for (var i = 0; i < shots.length; i++) {
      final end = cursor + shots[i].durationSeconds;
      if (wrapped < end || i == shots.length - 1) {
        index = i;
        break;
      }
      cursor = end;
    }

    final shot = shots[index];
    final local = (wrapped - cursor).clamp(0.0, shot.durationSeconds);
    final rawProgress = shot.durationSeconds <= 0
        ? 1.0
        : (local / shot.durationSeconds).clamp(0.0, 1.0);
    final eased = studioEase(shot.easing, rawProgress);
    final transitionStart = math.max(
      0.0,
      shot.durationSeconds - shot.transitionSeconds,
    );
    final transitionProgress =
        shot.transitionSeconds <= 0 || local <= transitionStart
        ? 0.0
        : ((local - transitionStart) / shot.transitionSeconds).clamp(0.0, 1.0);

    return StudioFrameState(
      imageIndex: index,
      nextImageIndex: (index + 1) % shots.length,
      shotProgress: rawProgress,
      transitionProgress: transitionProgress,
      scale: _lerp(shot.startScale, shot.endScale, eased),
      x: _lerp(shot.startPosition.x, shot.endPosition.x, eased),
      y: _lerp(shot.startPosition.y, shot.endPosition.y, eased),
      transition: shot.transition,
    );
  }

  Map<String, dynamic> toRenderJson({
    required int photoCount,
    Map<int, StudioFocalPoint> focalPoints = const <int, StudioFocalPoint>{},
    Map<int, StudioPhotoFit> photoFits = const <int, StudioPhotoFit>{},
  }) => <String, dynamic>{
    'id': id,
    'version': version,
    'name': name,
    'category': category.name,
    'fps': fps,
    'width': width,
    'height': height,
    'audio_preset': audioPresetId,
    'shots': <Map<String, dynamic>>[
      for (var i = 0; i < shotsFor(photoCount).length; i++)
        <String, dynamic>{
          ...shotsFor(photoCount)[i].toJson(),
          'image_index': i,
          'focal': (focalPoints[i] ?? const StudioFocalPoint()).toJson(),
          'fit': (photoFits[i] ?? StudioPhotoFit.portrait).name,
        },
    ],
  };
}

class StudioProject {
  const StudioProject({
    required this.templateId,
    required this.templateVersion,
    required this.category,
    required this.audioPresetId,
    this.focalPoints = const <int, StudioFocalPoint>{},
    this.photoFits = const <int, StudioPhotoFit>{},
  });

  final String templateId;
  final int templateVersion;
  final StudioCategory category;
  final String audioPresetId;
  final Map<int, StudioFocalPoint> focalPoints;
  final Map<int, StudioPhotoFit> photoFits;

  StudioProject copyWith({
    String? templateId,
    int? templateVersion,
    StudioCategory? category,
    String? audioPresetId,
    Map<int, StudioFocalPoint>? focalPoints,
    Map<int, StudioPhotoFit>? photoFits,
  }) => StudioProject(
    templateId: templateId ?? this.templateId,
    templateVersion: templateVersion ?? this.templateVersion,
    category: category ?? this.category,
    audioPresetId: audioPresetId ?? this.audioPresetId,
    focalPoints: focalPoints ?? this.focalPoints,
    photoFits: photoFits ?? this.photoFits,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'template_id': templateId,
    'template_version': templateVersion,
    'category': category.name,
    'audio_preset': audioPresetId,
    'focal_points': <String, dynamic>{
      for (final entry in focalPoints.entries)
        entry.key.toString(): entry.value.toJson(),
    },
    'photo_fits': <String, dynamic>{
      for (final entry in photoFits.entries)
        entry.key.toString(): entry.value.name,
    },
  };

  factory StudioProject.fromJson(Map<String, dynamic> json) {
    final categoryRaw = json['category']?.toString() ?? 'property';
    final focalRaw = json['focal_points'];
    final fitRaw = json['photo_fits'];
    final focalPoints = <int, StudioFocalPoint>{};
    if (focalRaw is Map) {
      for (final entry in focalRaw.entries) {
        final index = int.tryParse(entry.key.toString());
        if (index == null || entry.value is! Map) continue;
        focalPoints[index] = StudioFocalPoint.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }
    final photoFits = <int, StudioPhotoFit>{};
    if (fitRaw is Map) {
      for (final entry in fitRaw.entries) {
        final index = int.tryParse(entry.key.toString());
        if (index == null) continue;
        photoFits[index] = entry.value.toString() == StudioPhotoFit.fit.name
            ? StudioPhotoFit.fit
            : StudioPhotoFit.portrait;
      }
    }
    return StudioProject(
      templateId: json['template_id']?.toString() ?? '',
      templateVersion: (json['template_version'] as num?)?.toInt() ?? 1,
      category: studioCategoryFromName(categoryRaw),
      audioPresetId: json['audio_preset']?.toString() ?? 'clean_ambient',
      focalPoints: focalPoints,
      photoFits: photoFits,
    );
  }
}

StudioCategory studioCategoryFromName(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'motorcycle':
    case 'moto':
      return StudioCategory.motorcycle;
    case 'bicycle':
    case 'bike':
      return StudioCategory.bicycle;
    case 'worker':
    case 'people':
    case 'service':
    case 'job':
      return StudioCategory.worker;
    case 'yacht':
    case 'boat':
      return StudioCategory.yacht;
    case 'jet':
    case 'jets':
    case 'aircraft':
      return StudioCategory.jet;
    default:
      return StudioCategory.property;
  }
}

double studioEase(StudioEasing easing, double value) {
  final t = value.clamp(0.0, 1.0);
  switch (easing) {
    case StudioEasing.linear:
      return t;
    case StudioEasing.easeIn:
      return t * t * t;
    case StudioEasing.easeOut:
      final inverse = 1 - t;
      return 1 - inverse * inverse * inverse;
    case StudioEasing.easeInOut:
      return t * t * (3 - 2 * t);
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
