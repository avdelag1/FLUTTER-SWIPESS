import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/app_action_banner.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/add/domain/listing_draft.dart';
import 'package:flutter_swipes/src/features/add/presentation/providers/add_listing_provider.dart';
import 'package:flutter_swipes/src/features/add/data/listing_draft_repository.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_soundtrack_picker.dart';
import 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_inline_preview.dart';
import 'package:flutter_swipes/src/features/add/presentation/screens/listing_photo_framing_screen.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/video_cropper_screen.dart';
import 'package:flutter_swipes/src/features/studio/data/cinematic_catalog.dart';
import 'package:flutter_swipes/src/features/studio/presentation/providers/studio_listing_selection_provider.dart';
import 'package:flutter_swipes/src/features/studio/presentation/widgets/cinematic_preview.dart';
import 'package:flutter_swipes/src/features/studio/presentation/screens/studio_composer_screen.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/ai/presentation/providers/voice_language_provider.dart';
import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// Direct AI listing flow:
/// photos + required basics -> continuous dictation -> AI filter extraction
/// -> Create Listing -> publish.
///
/// The user stays on this screen while AI turns the natural-language
/// description into the category-specific listing filters.
class AiListingBuilderScreen extends ConsumerStatefulWidget {
  const AiListingBuilderScreen({super.key});

  @override
  ConsumerState<AiListingBuilderScreen> createState() =>
      _AiListingBuilderScreenState();
}

class _AiListingBuilderScreenState
    extends ConsumerState<AiListingBuilderScreen> {
  static const _pink = Color(0xFFFF2D6F);
  static const _panel = Color(0xFF17171C);
  static const _panelRaised = Color(0xFF212128);
  static const _blue = Color(0xFF4DA3FF);

  bool get _isLight => Theme.of(context).brightness == Brightness.light;
  Color get _ink => _isLight ? const Color(0xFF0A0A0D) : Colors.white;
  Color get _muted =>
      _isLight ? const Color(0xFF666670) : const Color(0xFF9B9BA5);
  Color get _faint =>
      _isLight ? const Color(0xFF81818B) : const Color(0xFF777780);
  Color get _panelColor => _isLight ? Colors.white : _panel;
  Color get _panelRaisedColor =>
      _isLight ? const Color(0xFFF3F3F6) : _panelRaised;
  Color get _hairline => _isLight
      ? Colors.black.withValues(alpha: .10)
      : Colors.white.withValues(alpha: .08);
  List<Color> get _lightAwareGradient => _isLight
      ? const [Color(0xFFFFFFFF), Color(0xFFF4F4F7)]
      : const [Color(0xFF25252B), Color(0xFF1A1A1F)];

  final _city = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();
  final _photos = <XFile>[];
  XFile? _video;
  bool _videoAudioEnabled = true;
  XFile? _backgroundMusic;
  String? _backgroundMusicPreset;
  String? _backgroundMusicName;
  ListingMode? _modeOverride;
  final _voice = LiveVoiceInput.instance;

  String _category = 'property';
  String _currency = 'USD';
  bool _busy = false;
  bool _enhancing = false;
  bool _micWanted = false;
  bool _micActive = false;
  bool _micConnecting = false;
  String? _status;
  Map<String, dynamic> _aiPreview = <String, dynamic>{};
  Timer? _micRestartTimer;
  Timer? _micHealthTimer;
  int _micRecoveryAttempt = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_restoreSavedDraft);
  }

  Future<void> _restoreSavedDraft() async {
    try {
      final saved = await ref
          .read(listingDraftRepositoryProvider)
          .load('ai-new');
      if (!mounted || saved == null) return;
      final payload = saved.payload;
      final savedCategory = saved.category.toLowerCase();
      setState(() {
        if (const {
          'property',
          'worker',
          'motorcycle',
          'bicycle',
          'yacht',
        }.contains(savedCategory)) {
          _category = savedCategory;
        }
        _city.text = payload['city']?.toString() ?? '';
        _price.text = payload['price']?.toString() ?? '';
        _description.text = payload['description']?.toString() ?? '';
        final currency = (payload['currency']?.toString() ?? '').toUpperCase();
        if (currency == 'USD' || currency == 'MXN') _currency = currency;
        _videoAudioEnabled = payload['video_audio_enabled'] != false;
        _backgroundMusicPreset = payload['background_music_preset']?.toString();
        _backgroundMusicName = payload['background_music_name']?.toString();
        _photos
          ..clear()
          ..addAll(saved.photos);
        _video = saved.video;
        _backgroundMusic = saved.backgroundMusic;
      });
      _showMessage('Your saved listing draft is ready.');
    } catch (error) {
      debugPrint('[AiListingBuilder] draft restore skipped: $error');
    }
  }

  Future<void> _saveDraft() async {
    if (_busy) return;
    await _stopMic();
    if (!mounted) return;
    setState(() {
      _busy = true;
      _status = 'Pausing your draft…';
    });
    try {
      final documents = List<XFile>.of(
        ref.read(addListingProvider).legalDocuments,
      );
      await ref
          .read(listingDraftRepositoryProvider)
          .save(
            draftKey: 'ai-new',
            kind: 'ai',
            category: _category,
            step: 0,
            payload: <String, dynamic>{
              'city': _city.text.trim(),
              'price': _price.text.trim(),
              'description': _description.text,
              'currency': _currency,
              'video_audio_enabled': _videoAudioEnabled,
              'background_music_preset': _backgroundMusicPreset,
              'background_music_name': _backgroundMusicName,
            },
            photos: _photos,
            video: _video,
            documents: documents,
            backgroundMusic: _backgroundMusic,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Draft paused ✓';
      });
      _showMessage('Paused locally. Nothing was published or uploaded.');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) _closeBuilder();
    } catch (error) {
      debugPrint('[AiListingBuilder] draft save failed: $error');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
      });
      _showMessage(
        'Could not save the draft right now. Nothing on this page was cleared.',
      );
    }
  }

  @override
  void dispose() {
    _micRestartTimer?.cancel();
    _micHealthTimer?.cancel();
    _voice.cancel(owner: this);
    _city.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  void _closeBuilder() {
    NavBack.popOrGo(context, fallbackPath: AppPaths.clientDashboard);
  }

  Future<void> _toggleMic() async {
    if (_micWanted) {
      await _stopMic();
      return;
    }
    setState(() {
      _micWanted = true;
      _micActive = false;
      _micConnecting = true;
    });
    _micRecoveryAttempt = 0;
    AppHaptics.medium();
    await _startDictationSession();
  }

  Future<void> _startDictationSession() async {
    if (!mounted || !_micWanted || _micConnecting && _voice.isOwnedBy(this)) {
      return;
    }
    if (!_micConnecting) setState(() => _micConnecting = true);

    try {
      final started = await _voice.start(
        owner: this,
        initialText: _description.text,
        onText: (text) {
          if (!mounted || !_micWanted) return;
          _description.text = text;
          _description.selection = TextSelection.collapsed(
            offset: _description.text.length,
          );
        },
        onSilence: () {
          if (!mounted || !_micWanted) return;
          _armMicHealthCheck();
        },
        onSpeechActivity: () {
          if (!mounted || !_micWanted) return;
          if (!_micActive) setState(() => _micActive = true);
        },
        onListeningChanged: (listening) {
          if (!mounted || !_micWanted) return;
          if (_micActive != listening) setState(() => _micActive = listening);
          if (listening) {
            _micRecoveryAttempt = 0;
            _micHealthTimer?.cancel();
            _micHealthTimer = null;
          } else {
            _armMicHealthCheck();
          }
        },
        onError: _handleMicError,
        listenMode: ListenMode.dictation,
        // Use the same explicit global language that Dashboard AI and Intel
        // Core use. A user changing voice language must not leave this mic
        // silently pinned to English.
        languageCode: ref.read(voiceLanguageProvider).localeCode,
        restartAfterSilence: true,
      );
      if (!mounted || !_micWanted) return;
      if (!started) {
        if (_micActive) setState(() => _micActive = false);
        _scheduleMicRestart();
        return;
      }
      _armMicHealthCheck();
    } finally {
      if (mounted && _micConnecting) setState(() => _micConnecting = false);
    }
  }

  void _handleMicError(String message) {
    if (!mounted || !_micWanted) return;
    final lower = message.toLowerCase();
    final permissionProblem =
        lower.contains('permission') ||
        lower.contains('allow microphone') ||
        lower.contains('not authorized');
    if (permissionProblem) {
      _micRestartTimer?.cancel();
      _micHealthTimer?.cancel();
      _micRecoveryAttempt = 0;
      setState(() {
        _micWanted = false;
        _micActive = false;
        _micConnecting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    debugPrint('[AiListingBuilder] voice health recovery: $message');
    if (_micActive) setState(() => _micActive = false);
    _scheduleMicRestart();
  }

  void _armMicHealthCheck({
    Duration delay = const Duration(milliseconds: 1100),
  }) {
    _micHealthTimer?.cancel();
    if (!mounted || !_micWanted) return;
    _micHealthTimer = Timer(delay, () {
      _micHealthTimer = null;
      if (!mounted || !_micWanted) return;
      final healthy = _voice.isOwnedBy(this) && _voice.listeningNotifier.value;
      if (healthy) {
        _micRecoveryAttempt = 0;
        if (!_micActive) setState(() => _micActive = true);
        return;
      }
      if (_micActive) setState(() => _micActive = false);
      _scheduleMicRestart();
    });
  }

  void _scheduleMicRestart() {
    if (!mounted || !_micWanted) return;
    _micRestartTimer?.cancel();
    final attempt = _micRecoveryAttempt;
    final bounded = attempt > 6 ? 6 : attempt;
    _micRecoveryAttempt = attempt >= 8 ? 8 : attempt + 1;
    final delay = Duration(milliseconds: 350 + (bounded * 250));

    _micRestartTimer = Timer(delay, () async {
      _micRestartTimer = null;
      if (!mounted || !_micWanted) return;

      final alreadyHealthy =
          _voice.isOwnedBy(this) && _voice.listeningNotifier.value;
      if (alreadyHealthy) {
        _micRecoveryAttempt = 0;
        if (!_micActive) setState(() => _micActive = true);
        return;
      }

      if (!_micConnecting) setState(() => _micConnecting = true);
      await _voice.cancel(owner: this);
      if (!mounted || !_micWanted) return;
      await _startDictationSession();
    });
  }

  Future<void> _stopMic() async {
    _micRestartTimer?.cancel();
    _micHealthTimer?.cancel();
    _micRestartTimer = null;
    _micHealthTimer = null;
    _micRecoveryAttempt = 0;
    if (mounted) {
      setState(() {
        _micWanted = false;
        _micActive = false;
        _micConnecting = false;
      });
    }
    if (_voice.isOwnedBy(this)) {
      await _voice.finish(owner: this);
    }
  }

  Future<void> _pickPhotos() async {
    if (_busy) return;
    final maxForCategory = _photoLimitForCategory(_categoryEnum(_category));
    final remaining = maxForCategory - _photos.length;
    if (remaining <= 0) {
      _showMessage('Maximum $maxForCategory photos reached for this listing.');
      return;
    }

    final picker = ImagePicker();
    final List<XFile> picked;
    if (remaining == 1) {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 93,
        maxWidth: 2880,
        maxHeight: 2880,
        requestFullMetadata: false,
      );
      picked = file == null ? const <XFile>[] : <XFile>[file];
    } else {
      picked = await picker.pickMultiImage(
        limit: remaining,
        imageQuality: 93,
        maxWidth: 2880,
        maxHeight: 2880,
        requestFullMetadata: false,
      );
    }
    if (picked.isEmpty || !mounted) return;
    final studio = ref.read(studioListingSelectionProvider);
    final framed = await Navigator.of(context, rootNavigator: true)
        .push<List<XFile>>(
          MaterialPageRoute(
            builder: (_) => ListingPhotoFramingScreen(
              photos: picked.take(remaining).toList(growable: false),
              title: studio?.hasRenderedVideo == true
                  ? 'FRAME PHOTOS AFTER VIDEO'
                  : 'PHOTO FRAMING',
            ),
          ),
        );
    if (framed == null || framed.isEmpty || !mounted) return;
    setState(() => _photos.addAll(framed));
  }

  Future<void> _openStudio() async {
    if (_busy) return;
    if (_photos.length < 3) {
      _showMessage('Add at least 3 photos first.');
      return;
    }
    final selection = ref.read(studioListingSelectionProvider);
    final initialProject = selection != null && selection.matchesPhotos(_photos)
        ? selection.project
        : null;
    final result = await Navigator.of(context, rootNavigator: true)
        .push<StudioComposerResult>(
          MaterialPageRoute(
            builder: (_) => StudioComposerScreen(
              photos: _photos,
              listingCategory: _category,
              initialProject: initialProject,
              onCreateRealVideo: (studioResult, {onProgress}) async {
                onProgress?.call('Creating real 9:16 listing photos...');
                final framedStudioPhotos = await bakeListingPhotoFrames(
                  studioResult.photos,
                  photoFits: studioResult.project.photoFits,
                  focalPoints: studioResult.project.focalPoints,
                );
                final nextPhotos = <XFile>[
                  ...framedStudioPhotos,
                  ..._photos.skip(6),
                ];
                final notifier = ref.read(addListingProvider.notifier);
                notifier.update(
                  (current) =>
                      current.copyWith(photos: List<XFile>.of(nextPhotos)),
                );
                ref
                    .read(studioListingSelectionProvider.notifier)
                    .set(project: studioResult.project, photos: nextPhotos);
                final ready = await notifier.prepareStudioVideo(
                  onProgress: onProgress,
                );
                if (!ready) {
                  throw Exception(
                    ref.read(addListingProvider).error ??
                        'Studio could not create the MP4. Please retry.',
                  );
                }
                final rendered = ref.read(studioListingSelectionProvider);
                if (rendered == null ||
                    !rendered.hasRenderedVideo ||
                    !rendered.matchesPhotos(nextPhotos)) {
                  throw Exception(
                    'Studio did not receive a confirmed MP4. Please retry.',
                  );
                }
                return StudioRenderedVideo(
                  videoUrl: rendered.renderedVideoUrl!,
                  posterUrl: rendered.renderedPosterUrl,
                  durationSeconds: rendered.renderedDurationSeconds ?? 0,
                );
              },
            ),
          ),
        );
    if (result == null || !mounted) return;
    // The renderer callback already replaced Studio's raw sources with the
    // baked 9:16 gallery photos. Keep those exact files after closing Studio.
    final nextPhotos = List<XFile>.of(ref.read(addListingProvider).photos);
    final rendered = ref.read(studioListingSelectionProvider);
    if (rendered == null ||
        !rendered.hasRenderedVideo ||
        !rendered.matchesPhotos(nextPhotos)) {
      setState(() {
        _status = 'Studio did not finish a real MP4. Reopen Studio and retry.';
      });
      return;
    }
    setState(() {
      _photos
        ..clear()
        ..addAll(nextPhotos);
      _video = ref.read(addListingProvider).video;
      _backgroundMusic = null;
      _backgroundMusicPreset = null;
      _backgroundMusicName = null;
      _videoAudioEnabled = true;
      _busy = false;
      _status = 'REAL Studio MP4 ready ✓ — play it before publishing';
    });
    ref
        .read(addListingProvider.notifier)
        .update(
          (current) => current.copyWith(photos: List<XFile>.of(nextPhotos)),
        );
  }

  Future<bool> _ensurePaidVideoAccess() async {
    // Video creation/editing is available to every signed-in listing account.
    // The server/storage policies remain the final authorization layer.
    return true;
  }

  Future<void> _pickVideo() async {
    if (_busy || !await _ensurePaidVideoAccess()) return;
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final cropped = await Navigator.of(context, rootNavigator: true)
        .push<XFile>(
          MaterialPageRoute(
            builder: (_) => VideoCropperScreen(
              file: file,
              videoAudioEnabled: _videoAudioEnabled,
              backgroundMusic: _backgroundMusic,
              backgroundMusicPreset: _backgroundMusicPreset,
              backgroundMusicName: _backgroundMusicName,
              onVideoAudioChanged: (enabled) {
                if (mounted) setState(() => _videoAudioEnabled = enabled);
              },
              onBackgroundMusicFile: (music) {
                if (!mounted) return;
                setState(() {
                  _backgroundMusic = music;
                  _backgroundMusicPreset = null;
                  _backgroundMusicName = music.name;
                  _videoAudioEnabled = false;
                });
              },
              onBackgroundMusicPreset: (id, name) {
                if (!mounted) return;
                setState(() {
                  _backgroundMusic = null;
                  _backgroundMusicPreset = id;
                  _backgroundMusicName = name;
                  _videoAudioEnabled = false;
                });
              },
              onBackgroundMusicClear: () {
                if (!mounted) return;
                setState(() {
                  _backgroundMusic = null;
                  _backgroundMusicPreset = null;
                  _backgroundMusicName = null;
                });
              },
            ),
          ),
        );
    if (cropped != null && mounted) {
      ref.read(studioListingSelectionProvider.notifier).clear();
      setState(() => _video = cropped);
    }
  }

  Future<void> _editVideo() async {
    final file = _video;
    if (_busy || file == null || !await _ensurePaidVideoAccess()) return;
    final cropped = await Navigator.of(context, rootNavigator: true)
        .push<XFile>(
          MaterialPageRoute(
            builder: (_) => VideoCropperScreen(
              file: file,
              videoAudioEnabled: _videoAudioEnabled,
              backgroundMusic: _backgroundMusic,
              backgroundMusicPreset: _backgroundMusicPreset,
              backgroundMusicName: _backgroundMusicName,
              onVideoAudioChanged: (enabled) {
                if (mounted) setState(() => _videoAudioEnabled = enabled);
              },
              onBackgroundMusicFile: (music) {
                if (!mounted) return;
                setState(() {
                  _backgroundMusic = music;
                  _backgroundMusicPreset = null;
                  _backgroundMusicName = music.name;
                  _videoAudioEnabled = false;
                });
              },
              onBackgroundMusicPreset: (id, name) {
                if (!mounted) return;
                setState(() {
                  _backgroundMusic = null;
                  _backgroundMusicPreset = id;
                  _backgroundMusicName = name;
                  _videoAudioEnabled = false;
                });
              },
              onBackgroundMusicClear: () {
                if (!mounted) return;
                setState(() {
                  _backgroundMusic = null;
                  _backgroundMusicPreset = null;
                  _backgroundMusicName = null;
                });
              },
            ),
          ),
        );
    if (cropped != null && mounted) {
      ref.read(studioListingSelectionProvider.notifier).clear();
      setState(() => _video = cropped);
    }
  }

  String _detectedCurrency(Map<String, dynamic> parsed) {
    final raw = _firstParsedText(parsed, const [
      'currency',
      'currency_code',
      'price_currency',
    ]).toUpperCase();
    if (raw == 'MXN' || raw.contains('MEXICAN') || raw.contains('PESO')) {
      return 'MXN';
    }
    if (raw == 'USD' || raw.contains('DOLLAR') || raw.contains('US ')) {
      return 'USD';
    }
    final text = _description.text.toLowerCase();
    if (text.contains('mxn') ||
        text.contains('mexican peso') ||
        text.contains('pesos')) {
      return 'MXN';
    }
    if (text.contains('usd') ||
        text.contains('us dollar') ||
        text.contains('dollars')) {
      return 'USD';
    }
    return _currency;
  }

  Future<void> _fillBasicsFromDescription(String text) async {
    if (text.trim().length < 3) return;
    try {
      final parsed = await ref
          .read(aiEdgeRepositoryProvider)
          .extractListing(
            category: _category,
            prompt: text.trim(),
            city: _city.text.trim().isEmpty ? null : _city.text.trim(),
            price: _price.text.trim().isEmpty
                ? null
                : _parsedPrice(_price.text),
          )
          .timeout(const Duration(seconds: 8));
      if (!mounted || parsed.isEmpty) return;
      final city = _firstParsedText(parsed, const [
        'city',
        'location_city',
        'municipality',
      ]);
      final price = _parsedPrice(
        parsed['price'] ?? parsed['rate'] ?? parsed['amount'],
      );
      final currency = _detectedCurrency(parsed);
      setState(() {
        if (_city.text.trim().isEmpty && city.isNotEmpty) _city.text = city;
        if (_price.text.trim().isEmpty && price.isNotEmpty) _price.text = price;
        _currency = currency;
        _aiPreview = Map<String, dynamic>.of(parsed);
      });
    } catch (error) {
      debugPrint('[AiListingBuilder] basics extraction fallback: $error');
    }
  }

  Future<void> _enhance() async {
    if (_enhancing || _busy) return;
    if (_micWanted) {
      _showMessage('Tap the microphone to finish dictation before enhancing.');
      return;
    }
    final raw = _description.text.trim();
    if (raw.length < 5) {
      _showMessage('Describe the listing first.');
      return;
    }

    setState(() => _enhancing = true);
    try {
      final polished = await ref
          .read(aiEdgeRepositoryProvider)
          .enhanceText(text: raw, type: 'listing')
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (polished == null || polished.trim().isEmpty) {
        _showMessage(
          'Could not enhance right now. Your description is still here.',
        );
        return;
      }
      setState(() {
        _description.text = polished.trim();
        _description.selection = TextSelection.collapsed(
          offset: _description.text.length,
        );
      });
      await _fillBasicsFromDescription(_description.text);
    } catch (error) {
      debugPrint('[AiListingBuilder] enhance fallback: $error');
      if (mounted) {
        _showMessage(
          'Could not enhance right now. Your description is still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _enhancing = false);
    }
  }

  String _parsedText(Map<String, dynamic> parsed, String key) {
    final value = parsed[key];
    if (value == null) return '';
    return value.toString().trim();
  }

  String _firstParsedText(Map<String, dynamic> parsed, List<String> keys) {
    for (final key in keys) {
      final value = _parsedText(parsed, key);
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }

  List<String> _parsedList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty && item.toLowerCase() != 'null')
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(RegExp(r'[,;\n]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty && item.toLowerCase() != 'null')
          .toList();
    }
    return const <String>[];
  }

  bool _parsedBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == 'yes' || normalized == '1';
  }

  String _parsedPrice(dynamic value) {
    if (value == null) return '';
    if (value is num) return value.toString();
    final raw = value.toString().trim();
    if (raw.isEmpty) return '';
    final match = RegExp(r'\d[\d,.]*').firstMatch(raw);
    return (match?.group(0) ?? raw).replaceAll(',', '');
  }

  ListingCategory _categoryEnum(String category) {
    return switch (category) {
      'motorcycle' => ListingCategory.motorcycle,
      'bicycle' => ListingCategory.bicycle,
      'yacht' => ListingCategory.yacht,
      'worker' => ListingCategory.worker,
      _ => ListingCategory.property,
    };
  }

  int _photoLimitForCategory(ListingCategory category) {
    switch (category) {
      case ListingCategory.property:
        return 30;
      case ListingCategory.yacht:
        return 12;
      case ListingCategory.worker:
        return 8;
      case ListingCategory.motorcycle:
      case ListingCategory.bicycle:
        return 5;
    }
  }

  ListingMode _modeFrom(Map<String, dynamic> parsed, String description) {
    final raw =
        '${_parsedText(parsed, 'mode')} ${_parsedText(parsed, 'listing_type')}'
            .toLowerCase();
    if (raw.contains('both')) return ListingMode.both;
    if (raw.contains('sale') || raw.contains('sell')) return ListingMode.sale;
    if (raw.contains('rent')) return ListingMode.rent;
    final text = description.toLowerCase();
    if (text.contains('for sale') || text.contains('selling')) {
      return ListingMode.sale;
    }
    return ListingMode.rent;
  }

  String _vehicleTypeFrom(Map<String, dynamic> parsed) {
    return _firstParsedText(parsed, const [
      'vehicle_type',
      'motorcycle_type',
      'bicycle_type',
      'yacht_type',
    ]);
  }

  String? _nullableText(String value, String? fallback) {
    return value.isEmpty ? fallback : value;
  }

  List<String> _useList(List<String> parsed, List<String> fallback) {
    return parsed.isEmpty ? fallback : parsed;
  }

  String? _pricingUnitFromParsed(String raw, String? fallback) {
    switch (raw.toLowerCase()) {
      case 'hour':
      case 'hourly':
        return 'Hourly';
      case 'day':
      case 'daily':
        return 'Daily';
      case 'job':
      case 'project':
      case 'per-job':
        return 'Per-job';
      case 'month':
      case 'monthly':
      case 'monthly contract':
        return 'Monthly contract';
      case 'week':
      case 'weekly':
        return 'Weekly';
      default:
        return raw.isEmpty ? fallback : raw;
    }
  }

  Future<void> _create() async {
    if (_busy) return;
    if (_photos.isEmpty) {
      _showMessage('Add at least one photo first.');
      return;
    }

    final typedCity = _city.text.trim();
    final typedPrice = _parsedPrice(_price.text);

    final originalDescription = _description.text.trim();
    if (originalDescription.length < 3) {
      _showMessage('Describe what you are listing first.');
      return;
    }

    await _stopMic();
    if (!mounted) return;

    setState(() {
      _busy = true;
      _status = 'AI is filling the listing details…';
    });
    AppHaptics.medium();

    final notifier = ref.read(addListingProvider.notifier);
    final verificationDocuments = List<XFile>.of(
      ref.read(addListingProvider).legalDocuments,
    );
    try {
      var parsed = Map<String, dynamic>.of(_aiPreview);
      if (parsed.isEmpty) {
        try {
          final structuredPrompt = <String>[
            'Description:\n$originalDescription',
            if (typedCity.isNotEmpty) 'User city: $typedCity',
            if (typedPrice.isNotEmpty) 'User price: $typedPrice $_currency',
          ].join('\n');
          parsed = await ref
              .read(aiEdgeRepositoryProvider)
              .extractListing(
                category: _category,
                prompt: structuredPrompt,
                city: typedCity,
                price: typedPrice,
              )
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () => const <String, dynamic>{},
              );
        } catch (error) {
          debugPrint('[AiListingBuilder] extractor fallback: $error');
        }
      }
      if (!mounted) return;
      setState(() => _aiPreview = Map<String, dynamic>.of(parsed));

      final detected = _parsedText(parsed, 'category').toLowerCase();
      if (const {
        'property',
        'motorcycle',
        'bicycle',
        'yacht',
        'worker',
      }.contains(detected)) {
        _category = detected;
      }

      final category = _categoryEnum(_category);
      notifier.reset();
      notifier.setCategory(category);
      notifier.setMode(_modeOverride ?? _modeFrom(parsed, originalDescription));

      final aiDescription = _parsedText(parsed, 'description');
      final description = aiDescription.isNotEmpty
          ? aiDescription
          : originalDescription;
      final country = _parsedText(parsed, 'country');
      final title = _parsedText(parsed, 'title');
      final neighborhood = _parsedText(parsed, 'neighborhood');
      final vehicleType = _vehicleTypeFrom(parsed);
      final aiCity = _firstParsedText(parsed, const [
        'city',
        'location_city',
        'municipality',
      ]);
      final aiPrice = _parsedPrice(
        parsed['price'] ?? parsed['rate'] ?? parsed['amount'],
      );
      final finalCity = typedCity.isNotEmpty ? typedCity : aiCity;
      final finalPrice = typedPrice.isNotEmpty ? typedPrice : aiPrice;
      final finalCurrency = _detectedCurrency(parsed);
      if (mounted) {
        setState(() {
          if (_city.text.trim().isEmpty && finalCity.isNotEmpty) {
            _city.text = finalCity;
          }
          if (_price.text.trim().isEmpty && finalPrice.isNotEmpty) {
            _price.text = finalPrice;
          }
          _currency = finalCurrency;
        });
      }

      final amenities = <String>[
        ..._parsedList(parsed['amenities']),
        if (originalDescription.toLowerCase().contains('wifi')) 'WiFi',
        if (originalDescription.toLowerCase().contains('pool')) 'Private Pool',
        if (originalDescription.toLowerCase().contains('air conditioning') ||
            originalDescription.toLowerCase().contains(' a/c') ||
            originalDescription.toLowerCase().contains(' ac '))
          'AC',
        if (originalDescription.toLowerCase().contains('rooftop')) 'Rooftop',
        if (originalDescription.toLowerCase().contains('patio')) 'Patio',
        if (originalDescription.toLowerCase().contains('parking')) 'Parking',
        if (originalDescription.toLowerCase().contains('gym')) 'Gym',
      ].toSet().toList();

      final maxPhotos = ref.read(addListingProvider).maxPhotos;
      final safePhotos = _photos.take(maxPhotos).toList(growable: false);

      notifier.update(
        (draft) => draft.copyWith(
          city: finalCity,
          country: country.isNotEmpty ? country : draft.country,
          neighborhood: neighborhood.isNotEmpty
              ? neighborhood
              : draft.neighborhood,
          description: description,
          title: title.isNotEmpty ? title : draft.title,
          price: finalPrice,
          currency: finalCurrency,
          photos: safePhotos,
          video: _video,
          videoAudioEnabled: _videoAudioEnabled,
          backgroundMusic: _backgroundMusic,
          clearBackgroundMusic: _backgroundMusic == null,
          backgroundMusicPreset: _backgroundMusicPreset,
          clearBackgroundMusicPreset: _backgroundMusicPreset == null,
          backgroundMusicName: _backgroundMusicName,
          clearBackgroundMusicName: _backgroundMusicName == null,
          legalDocuments: verificationDocuments,
          adjectives: _useList(
            _parsedList(parsed['adjectives']),
            draft.adjectives,
          ),
          sizes: _useList(_parsedList(parsed['sizes']), draft.sizes),
          propertyType: _nullableText(
            _parsedText(parsed, 'property_type'),
            draft.propertyType,
          ),
          beds: _nullableText(
            _firstParsedText(parsed, const [
              'beds',
              'bedrooms',
              'bedroom_count',
            ]),
            draft.beds,
          ),
          baths: _nullableText(
            _firstParsedText(parsed, const [
              'baths',
              'bathrooms',
              'bathroom_count',
            ]),
            draft.baths,
          ),
          vibe: _useList(_parsedList(parsed['vibe']), draft.vibe),
          amenities: amenities.isNotEmpty ? amenities : draft.amenities,
          included: _useList(_parsedList(parsed['included']), draft.included),
          rules: _useList(_parsedList(parsed['rules']), draft.rules),
          furnished: _parsedBool(parsed['furnished']) || draft.furnished,
          petFriendly:
              _parsedBool(parsed['pet_friendly']) ||
              _parsedBool(parsed['pets_allowed']) ||
              draft.petFriendly,
          rentalDuration: _nullableText(
            _firstParsedText(parsed, const [
              'rental_duration',
              'rental_duration_type',
            ]),
            draft.rentalDuration,
          ),
          brand: _nullableText(
            _firstParsedText(parsed, const ['make', 'brand']),
            draft.brand,
          ),
          model: _nullableText(_parsedText(parsed, 'model'), draft.model),
          year: _parsedText(parsed, 'year').isNotEmpty
              ? _parsedText(parsed, 'year')
              : draft.year,
          mileage: _parsedText(parsed, 'mileage').isNotEmpty
              ? _parsedText(parsed, 'mileage')
              : draft.mileage,
          engineCc: _parsedText(parsed, 'engine_cc').isNotEmpty
              ? _parsedText(parsed, 'engine_cc')
              : draft.engineCc,
          vehicleType: _nullableText(vehicleType, draft.vehicleType),
          condition: _nullableText(
            _parsedText(parsed, 'condition'),
            draft.condition,
          ),
          features: _useList(_parsedList(parsed['features']), draft.features),
          vehicleIncluded: _useList(
            _firstNonEmptyParsedList(parsed, const [
              'vehicle_included',
              'included_vehicle',
            ]),
            draft.vehicleIncluded,
          ),
          frameSize: _nullableText(
            _parsedText(parsed, 'frame_size'),
            draft.frameSize,
          ),
          lengthM: _parsedText(parsed, 'length_m').isNotEmpty
              ? _parsedText(parsed, 'length_m')
              : draft.lengthM,
          berths: _parsedText(parsed, 'berths').isNotEmpty
              ? _parsedText(parsed, 'berths')
              : draft.berths,
          maxPassengers: _parsedText(parsed, 'max_passengers').isNotEmpty
              ? _parsedText(parsed, 'max_passengers')
              : draft.maxPassengers,
          serviceCategory: _nullableText(
            _parsedText(parsed, 'service_category'),
            draft.serviceCategory,
          ),
          traits: _useList(_parsedList(parsed['traits']), draft.traits),
          skills: _useList(_parsedList(parsed['skills']), draft.skills),
          availability: _useList(
            _parsedList(parsed['availability']),
            draft.availability,
          ),
          pricingUnit: _pricingUnitFromParsed(
            _parsedText(parsed, 'pricing_unit'),
            draft.pricingUnit,
          ),
          languages: _useList(
            _parsedList(parsed['languages']),
            draft.languages,
          ),
        ),
      );

      final prepared = ref.read(addListingProvider);
      final parsedPrice = double.tryParse(prepared.price.trim());
      if (prepared.city.trim().isEmpty ||
          parsedPrice == null ||
          parsedPrice <= 0) {
        setState(() {
          _busy = false;
          _status = null;
        });
        _showMessage('City and price are required before publishing.');
        return;
      }

      final selectedStudio = ref.read(studioListingSelectionProvider);
      final renderingStudio =
          _video == null &&
          selectedStudio != null &&
          selectedStudio.matchesPhotos(prepared.photos) &&
          !selectedStudio.hasRenderedVideo;
      setState(
        () => _status = renderingStudio
            ? 'Rendering your Studio video and publishing…'
            : 'Uploading media and publishing…',
      );
      final published = await notifier.publish();
      if (!mounted) return;

      if (!published) {
        final error = ref.read(addListingProvider).error;
        setState(() {
          _busy = false;
          _status = null;
        });
        _showMessage(_friendlyPublishError(error));
        return;
      }

      setState(() => _status = 'Listing published ✓');
      try {
        await ref.read(listingDraftRepositoryProvider).delete('ai-new');
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      AppActionBanner.success(
        context,
        title: 'Listing published',
        detail: 'Your listing is live now.',
      );
      context.go(AppPaths.clientProfile);
    } catch (error, stackTrace) {
      debugPrint('[AiListingBuilder] direct publish failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
      });
      _showMessage(
        'Could not publish this listing right now. Your photos and description are still here — try again.',
      );
    }
  }

  List<String> _aiPreviewLabels() {
    final parsed = _aiPreview;
    if (parsed.isEmpty) return const <String>[];
    final labels = <String>[];

    void addValue(String label, String value) {
      final clean = value.trim();
      if (clean.isEmpty || clean.toLowerCase() == 'null') return;
      labels.add('$label: $clean');
    }

    addValue(
      'Type',
      _firstParsedText(parsed, const [
        'property_type',
        'vehicle_type',
        'motorcycle_type',
        'bicycle_type',
        'yacht_type',
        'service_category',
      ]),
    );
    addValue(
      'Beds',
      _firstParsedText(parsed, const ['beds', 'bedrooms', 'bedroom_count']),
    );
    addValue(
      'Baths',
      _firstParsedText(parsed, const ['baths', 'bathrooms', 'bathroom_count']),
    );
    addValue('Brand', _firstParsedText(parsed, const ['brand', 'make']));
    addValue('Model', _parsedText(parsed, 'model'));
    addValue('Year', _parsedText(parsed, 'year'));
    addValue('Condition', _parsedText(parsed, 'condition'));
    addValue('Pricing', _parsedText(parsed, 'pricing_unit'));

    if (_parsedBool(parsed['furnished'])) labels.add('Furnished');
    if (_parsedBool(parsed['pet_friendly']) ||
        _parsedBool(parsed['pets_allowed'])) {
      labels.add('Pet friendly');
    }

    for (final amenity in _parsedList(parsed['amenities']).take(5)) {
      labels.add(amenity);
    }
    for (final feature in _parsedList(parsed['features']).take(4)) {
      labels.add(feature);
    }
    for (final skill in _parsedList(parsed['skills']).take(4)) {
      labels.add(skill);
    }
    for (final rule in _parsedList(parsed['rules']).take(3)) {
      labels.add(rule);
    }

    return labels.toSet().take(12).toList(growable: false);
  }

  Widget _aiPreviewSummary() {
    final labels = _aiPreviewLabels();
    if (labels.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: _pink, size: 14),
            SizedBox(width: 6),
            Text(
              'AI ALSO FILLED',
              style: GoogleFonts.plusJakartaSans(
                color: _muted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .55,
              ),
            ),
          ],
        ),
        SizedBox(height: 7),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: labels
              .map(
                (label) => Container(
                  padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: _pink.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _pink.withValues(alpha: .22)),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      color: _ink,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  List<String> _firstNonEmptyParsedList(
    Map<String, dynamic> parsed,
    List<String> keys,
  ) {
    for (final key in keys) {
      final values = _parsedList(parsed[key]);
      if (values.isNotEmpty) return values;
    }
    return const <String>[];
  }

  String _friendlyPublishError(String? error) {
    final message = error?.trim() ?? '';
    if (message.isEmpty) {
      return 'Could not publish this listing. Please try again.';
    }
    final lower = message.toLowerCase();
    if (lower.contains('at least 1 photo')) {
      return 'Add at least one photo first.';
    }
    if (lower.contains('price greater than 0')) {
      return 'Add a valid price and try again.';
    }
    if (lower.contains('choose usd or mxn')) {
      return 'Choose USD or MXN and try again.';
    }
    if (lower.contains('city is required')) {
      return 'Add the city and try again.';
    }
    if (lower.contains('session expired')) return message;
    if (lower.contains('storageexception') ||
        lower.contains('row-level security') ||
        lower.contains('statuscode: 403') ||
        lower.contains('unauthorized')) {
      return 'We could not upload that media right now. Your listing is still here — please try again.';
    }
    if (lower.contains('postgres') ||
        lower.contains('postgrest') ||
        lower.contains('invalid input syntax') ||
        lower.contains('sqlstate')) {
      return 'The listing could not be saved. Please try again — your information is still here.';
    }
    return message.length > 180
        ? 'Could not publish this listing. Please try again.'
        : message;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showInfoSheet({
    required String title,
    required String body,
    IconData icon = Icons.info_outline_rounded,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => Container(
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.fromLTRB(18, 10, 18, 22),
        decoration: BoxDecoration(
          color: _panelColor,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: _isLight
                      ? Colors.black.withValues(alpha: .18)
                      : Colors.white.withValues(alpha: .20),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _pink.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: _pink, size: 20),
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Text(
              body,
              style: GoogleFonts.plusJakartaSans(
                color: _muted,
                fontSize: 12,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoButton({
    required String title,
    required String body,
    IconData icon = Icons.info_outline_rounded,
  }) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: title,
        onPressed: () => _showInfoSheet(title: title, body: body, icon: icon),
        icon: Icon(Icons.info_outline_rounded, color: _muted, size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoLimit = _photoLimitForCategory(_categoryEnum(_category));
    final verificationDraft = ref
        .watch(addListingProvider)
        .copyWith(category: _categoryEnum(_category));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: _busy ? null : _closeBuilder),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(
                    'CREATE WITH AI',
                    style: GoogleFonts.plusJakartaSans(
                      color: _ink,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Media. Describe it. AI handles the details.',
                    style: GoogleFonts.plusJakartaSans(
                      color: _muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 14),
                  _verificationCard(verificationDraft),
                  SizedBox(height: 18),
                  _mediaSection(photoLimit),
                  SizedBox(height: 18),
                  _sectionTitle('WHAT ARE YOU LISTING?'),
                  SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _categoryChip('property', 'Property', Icons.home_rounded),
                      _categoryChip('worker', 'Worker', Icons.handyman_rounded),
                      _categoryChip(
                        'motorcycle',
                        'Motorcycle',
                        Icons.two_wheeler_rounded,
                      ),
                      _categoryChip(
                        'bicycle',
                        'Bicycle',
                        Icons.pedal_bike_rounded,
                      ),
                      _categoryChip('yacht', 'Yacht', Icons.sailing_rounded),
                    ],
                  ),
                  if (_category != 'worker') ...[
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _sectionTitle('RENT OR SALE?')),
                        _infoButton(
                          title: 'Rent or sale',
                          body:
                              'This choice is optional. Leave both unselected and AI will detect the best match from your description.',
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _modeButton(
                            label: 'For Rent',
                            icon: Icons.key_rounded,
                            selected: _modeOverride == ListingMode.rent,
                            onTap: () => setState(
                              () => _modeOverride = ListingMode.rent,
                            ),
                          ),
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: _modeButton(
                            label: 'For Sale',
                            icon: Icons.sell_rounded,
                            selected: _modeOverride == ListingMode.sale,
                            onTap: () => setState(
                              () => _modeOverride = ListingMode.sale,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _sectionTitle('DESCRIBE IT')),
                      _micStatusChip(),
                      SizedBox(width: 8),
                      _micButton(),
                    ],
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _isLight
                            ? const [Color(0xFFFFFFFF), Color(0xFFF4F4F7)]
                            : const [Color(0xFF232329), Color(0xFF17171C)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _hairline),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: _isLight ? .08 : .38,
                          ),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    foregroundDecoration: _micWanted
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: _pink.withValues(alpha: .82),
                              width: 1.2,
                            ),
                          )
                        : null,
                    child: Column(
                      children: [
                        TextField(
                          controller: _description,
                          enabled: !_busy,
                          minLines: 6,
                          maxLines: 10,
                          style: _fieldTextStyle,
                          decoration: InputDecoration(
                            hintText:
                                'Describe it naturally — what it is, where it is, price, features, condition…',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              color: _faint,
                              fontSize: 13,
                              height: 1.35,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 10),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: (_busy || _enhancing || _micWanted)
                                  ? null
                                  : _enhance,
                              icon: _enhancing
                                  ? SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(Icons.auto_awesome_rounded),
                              label: Text('Enhance'),
                              style: TextButton.styleFrom(
                                foregroundColor: _ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_micWanted) ...[
                    SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(width: 4),
                        const _PulseDot(),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _micActive
                                ? 'Listening — tap the microphone when finished.'
                                : _micConnecting
                                ? 'Connecting microphone…'
                                : 'Reconnecting microphone…',
                            style: GoogleFonts.plusJakartaSans(
                              color: _muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _sectionTitle('AI-FILLED DETAILS')),
                      Text(
                        'EDIT ANYTHING',
                        style: GoogleFonts.plusJakartaSans(
                          color: _faint,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      SizedBox(width: 4),
                      _infoButton(
                        title: 'AI-filled details',
                        body:
                            'Mention city and price naturally in your description. Enhance can fill them here and detects USD or MXN. You can always edit the result before publishing.',
                        icon: Icons.auto_awesome_rounded,
                      ),
                    ],
                  ),
                  SizedBox(height: 9),
                  _inputShell(
                    child: TextField(
                      controller: _city,
                      enabled: !_busy,
                      textInputAction: TextInputAction.next,
                      style: _fieldTextStyle,
                      decoration: _inputDecoration(
                        hint: 'City',
                        icon: Icons.location_on_outlined,
                      ),
                    ),
                  ),
                  SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: _inputShell(
                          child: TextField(
                            controller: _price,
                            enabled: !_busy,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: _fieldTextStyle,
                            decoration: _inputDecoration(
                              hint: 'Price',
                              icon: Icons.payments_outlined,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 9),
                      SizedBox(
                        width: 112,
                        child: _inputShell(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _currency,
                                isExpanded: true,
                                dropdownColor: _panelColor,
                                iconEnabledColor: _ink,
                                style: _fieldTextStyle,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'USD',
                                    child: Text('USD'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'MXN',
                                    child: Text('MXN'),
                                  ),
                                ],
                                onChanged: _busy
                                    ? null
                                    : (value) {
                                        if (value == null) return;
                                        setState(() => _currency = value);
                                      },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_aiPreviewLabels().isNotEmpty) ...[
                    SizedBox(height: 10),
                    _aiPreviewSummary(),
                  ],
                  SizedBox(height: 20),
                  if (_status != null) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _panelColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _hairline),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: _isLight ? .07 : .26,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          if (_busy) ...[
                            SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: _pink,
                              ),
                            ),
                            SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              _status!,
                              style: GoogleFonts.plusJakartaSans(
                                color: _ink,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                  ],
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _create,
                      style: FilledButton.styleFrom(
                        backgroundColor: _pink,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _pink.withValues(alpha: .42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: _busy
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        _busy ? 'PUBLISHING…' : 'CREATE LISTING',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .35,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _saveDraft,
                      style: TextButton.styleFrom(
                        foregroundColor: _ink,
                        backgroundColor: _isLight
                            ? const Color(0xFFF2F2F5)
                            : Colors.white.withValues(alpha: .055),
                        padding: EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(color: _hairline),
                        ),
                      ),
                      icon: Icon(Icons.bookmark_outline_rounded, size: 17),
                      label: Text(
                        'Finish later',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVerificationDocuments() async {
    if (_busy) return;
    await ref.read(addListingProvider.notifier).pickLegalDocuments();
    if (!mounted) return;
    final error = ref.read(addListingProvider).error;
    if (error != null && error.trim().isNotEmpty) _showMessage(error);
  }

  Future<void> _captureVerificationDocument() async {
    if (_busy) return;
    await ref.read(addListingProvider.notifier).captureLegalDocument();
    if (!mounted) return;
    final error = ref.read(addListingProvider).error;
    if (error != null && error.trim().isNotEmpty) _showMessage(error);
  }

  Widget _verificationCard(ListingDraft draft) {
    final documents = draft.legalDocuments;
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.verified_rounded, color: _blue, size: 22),
              ),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GET THE BLUE CHECK',
                      style: GoogleFonts.plusJakartaSans(
                        color: _ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Optional verification',
                      style: GoogleFonts.plusJakartaSans(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _infoButton(
                title: 'Listing verification',
                body:
                    'Verification is optional. Send ownership, authorization, registration or professional proof privately. Swipess admins review it; approved listings can receive the blue check.\n\nUseful proof: ${draft.verificationProofHint}\n\nYour legal documents stay private and are never shown on the public listing.',
                icon: Icons.verified_user_rounded,
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _pickVerificationDocuments,
                    style: FilledButton.styleFrom(
                      backgroundColor: _isLight
                          ? const Color(0xFFF1F1F4)
                          : Colors.white.withValues(alpha: .07),
                      foregroundColor: _ink,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(Icons.upload_file_rounded, size: 19),
                    label: Text(
                      documents.isEmpty ? 'ADD DOCUMENT' : 'ADD MORE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .25,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 9),
              SizedBox(
                width: 44,
                height: 44,
                child: FilledButton(
                  onPressed: _busy ? null : _captureVerificationDocument,
                  style: FilledButton.styleFrom(
                    backgroundColor: _isLight
                        ? const Color(0xFFF1F1F4)
                        : Colors.white.withValues(alpha: .07),
                    foregroundColor: _ink,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Icon(Icons.photo_camera_rounded, size: 19),
                ),
              ),
            ],
          ),
          if (documents.isNotEmpty) ...[
            SizedBox(height: 10),
            ...List.generate(documents.length, (index) {
              final file = documents[index];
              return Container(
                margin: EdgeInsets.only(bottom: 6),
                padding: EdgeInsets.fromLTRB(11, 8, 6, 8),
                decoration: BoxDecoration(
                  color: _panelRaisedColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _hairline),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      color: Color(0xFF83C4FF),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: _ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _busy
                          ? null
                          : () => ref
                                .read(addListingProvider.notifier)
                                .removeLegalDocument(index),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: Color(0xFF9B9BA5),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _mediaSection(int photoLimit) {
    final studioSelection = ref.watch(studioListingSelectionProvider);
    final photoPanelHeight = _photos.length <= 4
        ? 320.0
        : _photos.length <= 10
        ? 430.0
        : 540.0;
    final activeStudio =
        studioSelection != null && studioSelection.matchesPhotos(_photos)
        ? studioSelection
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('MEDIA')),
            Text(
              '${_photos.length}/$photoLimit PHOTOS',
              style: GoogleFonts.plusJakartaSans(
                color: _muted,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 4),
            _infoButton(
              title: 'Media rules',
              body:
                  'Use clear photos and one short video that actually show the listing. Do not include phone numbers, private or confidential information, social-media handles, QR codes, URLs, outside ads or promotional watermarks. Inappropriate or flagged media can be removed, and repeated violations may suspend listing access.',
              icon: Icons.photo_library_outlined,
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: SizedBox(
                height: photoPanelHeight,
                child: _buildVideoPanel(),
              ),
            ),
            SizedBox(width: 9),
            Expanded(
              flex: 3,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: photoPanelHeight,
                child: _buildPhotoPanel(),
              ),
            ),
          ],
        ),
        SizedBox(height: 7),
        Text(
          'For dashboard cards, use a sharp portrait 9:16 video (1080×1920 preferred).',
          style: GoogleFonts.plusJakartaSans(
            color: _muted,
            fontSize: 9.5,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_video == null) ...[
          SizedBox(height: 10),
          _mediaActionButton(
            icon: Icons.movie_creation_rounded,
            label: activeStudio == null ? 'PHOTO → VIDEO' : 'STUDIO SELECTED',
            sublabel: _photos.length < 3
                ? 'Add 3 photos first'
                : activeStudio == null
                ? 'Pan · zoom · cuts · sound'
                : 'Tap to preview or change',
            onTap: _openStudio,
          ),
        ],
        if (_video != null) ...[
          SizedBox(height: 10),
          ListingVideoSoundtrackPicker(
            videoFile: _video,
            customMusic: _backgroundMusic,
            presetId: _backgroundMusicPreset,
            soundtrackName: _backgroundMusicName,
            disabled: _busy,
            onCustomPicked: (file) => setState(() {
              _backgroundMusic = file;
              _backgroundMusicPreset = null;
              _backgroundMusicName = file.name;
              _videoAudioEnabled = false;
            }),
            onPresetSelected: (id, name) => setState(() {
              _backgroundMusic = null;
              _backgroundMusicPreset = id;
              _backgroundMusicName = name;
              _videoAudioEnabled = false;
            }),
            onClear: () => setState(() {
              _backgroundMusic = null;
              _backgroundMusicPreset = null;
              _backgroundMusicName = null;
            }),
          ),
        ],
      ],
    );
  }

  Widget _mediaActionButton({
    required IconData icon,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _busy ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 100,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isLight
                ? const [Color(0xFFFFFFFF), Color(0xFFF3F3F6)]
                : const [Color(0xFF222228), Color(0xFF17171C)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _hairline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _pink, size: 25),
            SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: _ink,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 2),
            Text(
              sublabel,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: _faint,
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _busy ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 48,
        decoration: BoxDecoration(
          color: selected ? _pink : _panelRaisedColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _pink : _hairline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : _ink, size: 18),
            SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: selected ? Colors.white : _ink,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _micStatusChip() {
    final label = !_micWanted
        ? 'MIC OFF'
        : _micActive
        ? 'MIC LIVE'
        : _micConnecting
        ? 'CONNECTING'
        : 'RECOVERING';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _micWanted ? _pink.withValues(alpha: .16) : _panelRaisedColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: _micWanted ? _pink : _muted,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
        ),
      ),
    );
  }

  Widget _micButton() {
    return SizedBox(
      width: 42,
      height: 42,
      child: FilledButton(
        onPressed: _busy ? null : _toggleMic,
        style: FilledButton.styleFrom(
          backgroundColor: _micWanted ? _pink : _panelRaisedColor,
          foregroundColor: _micWanted ? Colors.white : _ink,
          padding: EdgeInsets.zero,
          shape: CircleBorder(
            side: BorderSide(color: _micWanted ? _pink : _hairline),
          ),
        ),
        child: _micConnecting && _micWanted
            ? SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Icon(
                _micActive ? Icons.stop_rounded : Icons.mic_rounded,
                size: 21,
              ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: GoogleFonts.plusJakartaSans(
      color: _muted,
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.1,
    ),
  );

  Widget _categoryChip(String value, String label, IconData icon) {
    final selected = _category == value;
    return ChoiceChip(
      selected: selected,
      onSelected: _busy
          ? null
          : (_) {
              final newCategory = _categoryEnum(value);
              final max = _photoLimitForCategory(newCategory);
              setState(() {
                _category = value;
                if (_photos.length > max) {
                  _photos.removeRange(max, _photos.length);
                }
              });
            },
      showCheckmark: false,
      avatar: Icon(icon, size: 17, color: selected ? Colors.white : _muted),
      label: Text(label),
      labelStyle: GoogleFonts.plusJakartaSans(
        color: selected ? Colors.white : _ink,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
      selectedColor: _pink,
      backgroundColor: _panelRaisedColor,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _inputShell({required Widget child}) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _lightAwareGradient,
      ),
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: _hairline),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: _isLight ? .07 : .34),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.plusJakartaSans(color: _faint, fontSize: 13),
    prefixIcon: Icon(icon, color: _muted, size: 20),
    border: InputBorder.none,
    contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
  );

  TextStyle get _fieldTextStyle => GoogleFonts.plusJakartaSans(
    color: _ink,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  Widget _addPhotosButton({required bool large}) => InkWell(
    onTap: _busy ? null : _pickPhotos,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      height: large ? 118 : 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _lightAwareGradient,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isLight ? .07 : .30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_rounded, color: _pink),
            SizedBox(width: 9),
            Text(
              large ? 'ADD PHOTOS' : 'ADD MORE PHOTOS',
              style: GoogleFonts.plusJakartaSans(
                color: _ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: .4,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildVideoPanel() {
    const canUploadVideo = true;
    final studioSelection = ref.watch(studioListingSelectionProvider);
    final activeStudio =
        studioSelection != null && studioSelection.matchesPhotos(_photos)
        ? studioSelection
        : null;
    if (_video == null &&
        activeStudio != null &&
        activeStudio.hasRenderedVideo) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black,
          border: Border.all(color: const Color(0xFF34D399), width: 1.4),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ListingVideoInlinePreview(
              networkUrl: activeStudio.renderedVideoUrl!,
              muted: false,
              height: 520,
            ),
            Positioned(
              left: 8,
              right: 8,
              top: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF34D399),
                        size: 15,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'REAL MP4 READY · PLAY TO CONFIRM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_video == null && activeStudio != null) {
      final template = CinematicCatalog.byId(activeStudio.project.templateId);
      return GestureDetector(
        onTap: _busy ? null : _openStudio,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.black,
            border: Border.all(color: _pink.withValues(alpha: .55)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AbsorbPointer(
                child: CinematicPreview(
                  photos: _photos.take(6).toList(growable: false),
                  template: template,
                  focalPoints: activeStudio.project.focalPoints,
                  playing: true,
                  playAudio: false,
                  borderRadius: 18,
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.movie_creation_rounded,
                        color: _pink,
                        size: 15,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'STUDIO PREVIEW ONLY · creating the real MP4 after confirmation',
                          maxLines: 2,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_video == null) {
      return _mediaActionButton(
        icon: canUploadVideo ? Icons.video_call_rounded : Icons.lock_rounded,
        label: canUploadVideo ? 'ADD VIDEO' : 'PREMIUM VIDEO',
        sublabel: canUploadVideo
            ? 'Portrait 9:16 · high quality · 5s to 60s'
            : 'Portrait 9:16 · Quick Filter ready',
        onTap: canUploadVideo
            ? _pickVideo
            : () => unawaited(_ensurePaidVideoAccess()),
      );
    }
    return GestureDetector(
      onTap: _busy ? null : _editVideo,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ListingVideoInlinePreview(file: _video, muted: !_videoAudioEnabled),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _busy
                        ? null
                        : () => setState(
                            () => _videoAudioEnabled = !_videoAudioEnabled,
                          ),
                    icon: Icon(
                      _videoAudioEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: _videoAudioEnabled ? Colors.white : _pink,
                      size: 19,
                    ),
                  ),
                  IconButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _video = null;
                            _videoAudioEnabled = true;
                            _backgroundMusic = null;
                            _backgroundMusicPreset = null;
                            _backgroundMusicName = null;
                          }),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Color(0xFF9B9BA5),
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPanel() {
    if (_photos.isEmpty) {
      return _mediaActionButton(
        icon: Icons.photo_library_rounded,
        label: 'ADD PHOTOS',
        sublabel: 'Drag to reorder',
        onTap: _pickPhotos,
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _hairline),
      ),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(8),
              itemCount: _photos.length + (_photos.length < 30 ? 1 : 0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                if (index == _photos.length) {
                  return InkWell(
                    onTap: _busy ? null : _pickPhotos,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _panelRaisedColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _hairline),
                      ),
                      child: Icon(Icons.add_rounded, color: _ink),
                    ),
                  );
                }
                final photo = _photos[index];
                return DragTarget<int>(
                  onWillAcceptWithDetails: (d) => d.data != index,
                  onAcceptWithDetails: (d) {
                    AppHaptics.light();
                    setState(() {
                      final item = _photos.removeAt(d.data);
                      _photos.insert(index, item);
                    });
                  },
                  builder: (context, candidate, rejected) {
                    return LongPressDraggable<int>(
                      data: index,
                      feedback: SizedBox(
                        width: 80,
                        height: 80,
                        child: _PhotoTile(file: photo, onRemove: null),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _PhotoTile(file: photo, onRemove: null),
                      ),
                      child: _PhotoTile(
                        file: photo,
                        onRemove: _busy
                            ? null
                            : () => setState(() => _photos.removeAt(index)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 6, 14, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back_ios_new_rounded),
            color: ink,
          ),
          const Spacer(),
          Text(
            'SWIPESS AI',
            style: GoogleFonts.plusJakartaSans(
              color: ink,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatefulWidget {
  const _PhotoTile({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback? onRemove;

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.file.readAsBytes();
  }

  @override
  void didUpdateWidget(covariant _PhotoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _bytes = widget.file.readAsBytes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List>(
            future: _bytes,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null) {
                return const ColoredBox(
                  color: Color(0xFF1C1C22),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
            },
          ),
          if (widget.onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: widget.onRemove,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: Color(0xCC000000),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: .45,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SizedBox(
        width: 8,
        height: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _AiListingBuilderScreenState._pink,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
