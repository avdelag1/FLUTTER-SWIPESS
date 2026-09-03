from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
PROVIDER = ROOT / 'lib/src/features/add/presentation/providers/edit_listing_provider.dart'
SCREEN = ROOT / 'lib/src/features/add/presentation/screens/edit_listing_screen.dart'
AI = ROOT / 'lib/src/features/add/presentation/screens/ai_listing_builder_screen_v2.dart'


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if old not in text:
        raise SystemExit(f'guard failed in {path}: {old[:100]!r}')
    path.write_text(text.replace(old, new, 1))


def regex_once(path: Path, pattern: str, replacement: str) -> None:
    text = path.read_text()
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'regex guard failed in {path}: {pattern[:100]!r} count={count}')
    path.write_text(updated)


# ---------------------------------------------------------------------------
# Edit listing state/provider: preserve and update the same video/audio metadata
# that the create flows already publish.
# ---------------------------------------------------------------------------
replace_once(
    PROVIDER,
    """    this.existingVideoUrl,\n    this.newVideo,\n    this.removeExistingVideo = false,\n    this.saving = false,\n""",
    """    this.existingVideoUrl,\n    this.newVideo,\n    this.removeExistingVideo = false,\n    this.videoAudioEnabled = true,\n    this.existingBackgroundMusicUrl,\n    this.backgroundMusic,\n    this.backgroundMusicPreset,\n    this.backgroundMusicName,\n    this.removeExistingBackgroundMusic = false,\n    this.saving = false,\n""",
)

replace_once(
    PROVIDER,
    """  final String? existingVideoUrl;\n  final XFile? newVideo;\n  final bool removeExistingVideo;\n  final bool saving;\n""",
    """  final String? existingVideoUrl;\n  final XFile? newVideo;\n  final bool removeExistingVideo;\n  final bool videoAudioEnabled;\n  final String? existingBackgroundMusicUrl;\n  final XFile? backgroundMusic;\n  final String? backgroundMusicPreset;\n  final String? backgroundMusicName;\n  final bool removeExistingBackgroundMusic;\n  final bool saving;\n""",
)

replace_once(
    PROVIDER,
    """    String? existingVideoUrl,\n    XFile? newVideo,\n    bool clearNewVideo = false,\n    bool? removeExistingVideo,\n    bool? saving,\n""",
    """    String? existingVideoUrl,\n    XFile? newVideo,\n    bool clearNewVideo = false,\n    bool? removeExistingVideo,\n    bool? videoAudioEnabled,\n    String? existingBackgroundMusicUrl,\n    XFile? backgroundMusic,\n    bool clearBackgroundMusic = false,\n    String? backgroundMusicPreset,\n    bool clearBackgroundMusicPreset = false,\n    String? backgroundMusicName,\n    bool clearBackgroundMusicName = false,\n    bool? removeExistingBackgroundMusic,\n    bool? saving,\n""",
)

replace_once(
    PROVIDER,
    """      existingVideoUrl: existingVideoUrl ?? this.existingVideoUrl,\n      newVideo: clearNewVideo ? null : (newVideo ?? this.newVideo),\n      removeExistingVideo: removeExistingVideo ?? this.removeExistingVideo,\n      saving: saving ?? this.saving,\n""",
    """      existingVideoUrl: existingVideoUrl ?? this.existingVideoUrl,\n      newVideo: clearNewVideo ? null : (newVideo ?? this.newVideo),\n      removeExistingVideo: removeExistingVideo ?? this.removeExistingVideo,\n      videoAudioEnabled: videoAudioEnabled ?? this.videoAudioEnabled,\n      existingBackgroundMusicUrl:\n          existingBackgroundMusicUrl ?? this.existingBackgroundMusicUrl,\n      backgroundMusic: clearBackgroundMusic\n          ? null\n          : (backgroundMusic ?? this.backgroundMusic),\n      backgroundMusicPreset: clearBackgroundMusicPreset\n          ? null\n          : (backgroundMusicPreset ?? this.backgroundMusicPreset),\n      backgroundMusicName: clearBackgroundMusicName\n          ? null\n          : (backgroundMusicName ?? this.backgroundMusicName),\n      removeExistingBackgroundMusic:\n          removeExistingBackgroundMusic ?? this.removeExistingBackgroundMusic,\n      saving: saving ?? this.saving,\n""",
)

replace_once(
    PROVIDER,
    """      existingVideoUrl: listing.videoUrl,\n    );\n""",
    """      existingVideoUrl: listing.videoUrl,\n      videoAudioEnabled: listing.videoAudioEnabled,\n      existingBackgroundMusicUrl: listing.backgroundMusicUrl,\n      backgroundMusicPreset: listing.backgroundMusicPreset,\n      backgroundMusicName: listing.backgroundMusicName,\n    );\n""",
)

regex_once(
    PROVIDER,
    r"  /// One clean video per listing\..*?\n  void removeVideo\(\) \{",
    """  /// One clean video per listing. The picker only returns a candidate; the\n  /// edit screen commits it after the same crop/trim/audio editor used by AI.\n  Future<bool> ensureVideoAccess() async {\n    final current = state;\n    if (current == null) return false;\n    try {\n      final allowed = await Supabase.instance.client.rpc(\n        'rpc_can_upload_listing_video',\n      );\n      if (allowed == true) return true;\n      state = current.copyWith(\n        error: 'Replacing or editing a listing video is a paid Premium benefit.',\n      );\n      return false;\n    } catch (_) {\n      state = current.copyWith(\n        error: 'Could not verify Premium video access. Please retry.',\n      );\n      return false;\n    }\n  }\n\n  Future<XFile?> pickVideo() async {\n    if (!await ensureVideoAccess()) return null;\n    return ImagePicker().pickVideo(\n      source: ImageSource.gallery,\n      maxDuration: const Duration(seconds: 60),\n    );\n  }\n\n  void removeVideo() {""",
)

replace_once(
    PROVIDER,
    """    state = current.copyWith(\n      clearNewVideo: true,\n      removeExistingVideo: true,\n      clearError: true,\n    );\n""",
    """    state = current.copyWith(\n      clearNewVideo: true,\n      removeExistingVideo: true,\n      videoAudioEnabled: true,\n      clearBackgroundMusic: true,\n      clearBackgroundMusicPreset: true,\n      clearBackgroundMusicName: true,\n      removeExistingBackgroundMusic: true,\n      clearError: true,\n    );\n""",
)

replace_once(
    PROVIDER,
    """      } else if (!current.removeExistingVideo) {\n        videoUrl = current.existingVideoUrl;\n      }\n\n      final payload = <String, dynamic>{\n""",
    """      } else if (!current.removeExistingVideo) {\n        videoUrl = current.existingVideoUrl;\n      }\n\n      String? backgroundMusicUrl;\n      if (videoUrl != null && current.backgroundMusic != null) {\n        backgroundMusicUrl = await repo.uploadListingAudio(\n          userId: user.id,\n          file: current.backgroundMusic!,\n        );\n      } else if (videoUrl != null && !current.removeExistingBackgroundMusic) {\n        backgroundMusicUrl = current.existingBackgroundMusicUrl;\n      }\n\n      final payload = <String, dynamic>{\n""",
)

replace_once(
    PROVIDER,
    """      payload.removeWhere((key, value) => value == null && key != 'video_url');\n      // Null is intentional here: it removes an existing clip when requested.\n      payload['video_url'] = videoUrl;\n\n      await repo.updateListing(current.listingId, payload);\n""",
    """      payload.removeWhere((key, value) => value == null);\n      // These nullable media values are intentional: they remove stale video or\n      // soundtrack metadata when the owner clears/replaces media.\n      payload['video_url'] = videoUrl;\n      payload['video_audio_enabled'] =\n          videoUrl == null ? true : current.videoAudioEnabled;\n      payload['background_music_url'] =\n          videoUrl == null ? null : backgroundMusicUrl;\n      payload['background_music_preset'] =\n          videoUrl == null ? null : current.backgroundMusicPreset;\n      payload['background_music_name'] =\n          videoUrl == null ? null : current.backgroundMusicName;\n\n      await repo.updateListing(current.listingId, payload);\n""",
)

# ---------------------------------------------------------------------------
# Edit listing UI: use the exact cropper + soundtrack controls from AI/manual
# upload, including downloading a published video before re-editing it.
# ---------------------------------------------------------------------------
replace_once(
    SCREEN,
    """import 'package:flutter_swipes/src/features/add/presentation/providers/edit_listing_provider.dart';\nimport 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_inline_preview.dart';\nimport 'package:flutter_swipes/src/features/camera/presentation/screens/listing_camera_screen.dart';\n""",
    """import 'package:flutter_swipes/src/features/add/data/remote_media_file.dart';\nimport 'package:flutter_swipes/src/features/add/presentation/providers/edit_listing_provider.dart';\nimport 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_inline_preview.dart';\nimport 'package:flutter_swipes/src/features/add/presentation/widgets/listing_video_soundtrack_picker.dart';\nimport 'package:flutter_swipes/src/features/camera/presentation/screens/listing_camera_screen.dart';\nimport 'package:flutter_swipes/src/features/camera/presentation/screens/video_cropper_screen.dart';\n""",
)

new_video_card = r'''class _VideoEditorCard extends ConsumerStatefulWidget {
  const _VideoEditorCard({required this.state});

  final EditListingState state;

  @override
  ConsumerState<_VideoEditorCard> createState() => _VideoEditorCardState();
}

class _VideoEditorCardState extends ConsumerState<_VideoEditorCard> {
  bool _preparingVideo = false;

  EditListingState get state => widget.state;

  Future<void> _replaceVideo() async {
    if (state.saving || _preparingVideo) return;
    final notifier = ref.read(editListingProvider.notifier);
    final file = await notifier.pickVideo();
    if (!mounted || file == null) return;
    await _openEditor(file);
  }

  Future<void> _editVideo() async {
    if (state.saving || _preparingVideo) return;
    final notifier = ref.read(editListingProvider.notifier);
    if (!await notifier.ensureVideoAccess() || !mounted) return;

    XFile? file = state.newVideo;
    if (file == null) {
      final url = state.existingVideoUrl?.trim() ?? '';
      if (url.isEmpty) return;
      setState(() => _preparingVideo = true);
      try {
        file = await materializeRemoteMedia(
          url,
          suggestedName: 'swipess-listing-${state.listingId}.mp4',
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not prepare the current video for editing. Please retry or replace it.',
                ),
              ),
            );
        }
        return;
      } finally {
        if (mounted) setState(() => _preparingVideo = false);
      }
    }

    if (!mounted || file == null) return;
    await _openEditor(file);
  }

  Future<void> _openEditor(XFile file) async {
    final notifier = ref.read(editListingProvider.notifier);
    final current = ref.read(editListingProvider) ?? state;
    final cropped = await Navigator.of(context, rootNavigator: true).push<XFile>(
      MaterialPageRoute(
        builder: (_) => VideoCropperScreen(
          file: file,
          videoAudioEnabled: current.videoAudioEnabled,
          backgroundMusic: current.backgroundMusic,
          backgroundMusicPreset: current.backgroundMusicPreset,
          backgroundMusicName: current.backgroundMusicName,
          onVideoAudioChanged: (enabled) {
            notifier.update((c) => c.copyWith(videoAudioEnabled: enabled));
          },
          onBackgroundMusicFile: (music) {
            notifier.update(
              (c) => c.copyWith(
                backgroundMusic: music,
                clearBackgroundMusicPreset: true,
                backgroundMusicName: music.name,
                videoAudioEnabled: false,
                removeExistingBackgroundMusic: true,
              ),
            );
          },
          onBackgroundMusicPreset: (id, name) {
            notifier.update(
              (c) => c.copyWith(
                clearBackgroundMusic: true,
                backgroundMusicPreset: id,
                backgroundMusicName: name,
                videoAudioEnabled: false,
                removeExistingBackgroundMusic: true,
              ),
            );
          },
          onBackgroundMusicClear: () {
            notifier.update(
              (c) => c.copyWith(
                clearBackgroundMusic: true,
                clearBackgroundMusicPreset: true,
                clearBackgroundMusicName: true,
                removeExistingBackgroundMusic: true,
              ),
            );
          },
        ),
      ),
    );
    if (cropped == null || !mounted) return;
    notifier.update(
      (c) => c.copyWith(
        newVideo: cropped,
        removeExistingVideo: false,
      ),
    );
  }

  void _customSoundtrack(XFile file) {
    ref.read(editListingProvider.notifier).update(
          (c) => c.copyWith(
            backgroundMusic: file,
            clearBackgroundMusicPreset: true,
            backgroundMusicName: file.name,
            videoAudioEnabled: false,
            removeExistingBackgroundMusic: true,
          ),
        );
  }

  void _presetSoundtrack(String id, String name) {
    ref.read(editListingProvider.notifier).update(
          (c) => c.copyWith(
            clearBackgroundMusic: true,
            backgroundMusicPreset: id,
            backgroundMusicName: name,
            videoAudioEnabled: false,
            removeExistingBackgroundMusic: true,
          ),
        );
  }

  void _clearSoundtrack() {
    ref.read(editListingProvider.notifier).update(
          (c) => c.copyWith(
            clearBackgroundMusic: true,
            clearBackgroundMusicPreset: true,
            clearBackgroundMusicName: true,
            removeExistingBackgroundMusic: true,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(editListingProvider.notifier);
    final pendingName = state.newVideo?.name.trim();
    final hasPending = pendingName != null && pendingName.isNotEmpty;
    final hasExisting =
        !state.removeExistingVideo &&
        (state.existingVideoUrl?.trim().isNotEmpty ?? false);
    final hasExistingCustomSoundtrack =
        state.backgroundMusic == null &&
        !state.removeExistingBackgroundMusic &&
        (state.existingBackgroundMusicUrl?.trim().isNotEmpty ?? false) &&
        !(state.backgroundMusicPreset?.trim().isNotEmpty ?? false);

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasPending || hasExisting) ...[
            ListingVideoInlinePreview(
              file: hasPending ? state.newVideo : null,
              networkUrl: hasPending ? null : state.existingVideoUrl,
              muted: true,
              height: 260,
            ),
            SizedBox(height: 12),
          ],
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary.withAlpha(36),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _preparingVideo
                    ? Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.movie_edit_rounded,
                        color: Colors.white,
                        size: 25,
                      ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPending
                          ? pendingName
                          : hasExisting
                              ? 'Current listing video'
                              : 'Add one listing video',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      _preparingVideo
                          ? 'Preparing the published clip for re-editing…'
                          : state.hasVideo
                              ? 'Trim, reframe, mute, add music or use a Swipess sound'
                              : 'Up to 60 sec • one Premium video per listing',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white60,
                        fontSize: 11,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              if (state.hasVideo) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: state.saving || _preparingVideo ? null : _editVideo,
                    icon: Icon(Icons.tune_rounded, size: 18),
                    label: Text('Edit video'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.saving || _preparingVideo ? null : _replaceVideo,
                  icon: Icon(
                    state.hasVideo
                        ? Icons.swap_horiz_rounded
                        : Icons.video_library_rounded,
                    size: 18,
                  ),
                  label: Text(state.hasVideo ? 'Replace' : 'Choose video'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withAlpha(54)),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              if (state.hasVideo) ...[
                SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Remove video',
                  onPressed: state.saving || _preparingVideo
                      ? null
                      : notifier.removeVideo,
                  icon: Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
          if (state.hasVideo) ...[
            SizedBox(height: 10),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              title: Text(
                'Original video sound',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                state.videoAudioEnabled ? 'On' : 'Muted',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: state.videoAudioEnabled,
              activeTrackColor: AppTheme.brandPrimary,
              onChanged: state.saving
                  ? null
                  : (enabled) => notifier.update(
                        (c) => c.copyWith(videoAudioEnabled: enabled),
                      ),
            ),
            ListingVideoSoundtrackPicker(
              videoFile: state.newVideo,
              customMusic: state.backgroundMusic,
              presetId: state.backgroundMusicPreset,
              soundtrackName: state.backgroundMusicName,
              disabled: state.saving || _preparingVideo,
              onCustomPicked: _customSoundtrack,
              onPresetSelected: _presetSoundtrack,
              onClear: _clearSoundtrack,
            ),
            if (hasExistingCustomSoundtrack) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.fromLTRB(10, 7, 6, 7),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.music_note_rounded, color: Colors.white70, size: 17),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        state.backgroundMusicName?.trim().isNotEmpty == true
                            ? state.backgroundMusicName!
                            : 'Current uploaded soundtrack',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: state.saving ? null : _clearSoundtrack,
                      child: Text('REMOVE'),
                    ),
                  ],
                ),
              ),
            ],
          ],
          SizedBox(height: 8),
          Text(
            'The edit page now uses the same video editor as Create with AI: 5–60s trim, portrait reframing, original-audio control, your own music and the 10 built-in Swipess sounds.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 10,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
'''
regex_once(
    SCREEN,
    r"class _VideoEditorCard extends ConsumerWidget \{.*?\n\}\n\nclass _PhotoGrid",
    new_video_card + "\nclass _PhotoGrid",
)

# ---------------------------------------------------------------------------
# AI listing microphone: screen-level health watchdog on top of LiveVoiceInput's
# transport retries. Do not show LIVE until the recognizer actually reports it.
# ---------------------------------------------------------------------------
replace_once(
    AI,
    """  Timer? _micRestartTimer;\n""",
    """  Timer? _micRestartTimer;\n  Timer? _micHealthTimer;\n  int _micRecoveryAttempt = 0;\n""",
)

replace_once(
    AI,
    """  void dispose() {\n    _micRestartTimer?.cancel();\n    _voice.cancel(owner: this);\n""",
    """  void dispose() {\n    _micRestartTimer?.cancel();\n    _micHealthTimer?.cancel();\n    _voice.cancel(owner: this);\n""",
)

replace_once(
    AI,
    """    setState(() {\n      _micWanted = true;\n      _micActive = true;\n    });\n    AppHaptics.medium();\n    await _startDictationSession();\n""",
    """    setState(() {\n      _micWanted = true;\n      _micActive = false;\n      _micConnecting = true;\n    });\n    _micRecoveryAttempt = 0;\n    AppHaptics.medium();\n    await _startDictationSession();\n""",
)

mic_methods = r'''  Future<void> _startDictationSession() async {
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
        languageCode: 'en-US',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
      final healthy =
          _voice.isOwnedBy(this) && _voice.listeningNotifier.value;
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

'''
regex_once(
    AI,
    r"  Future<void> _startDictationSession\(\) async \{.*?\n  Future<void> _pickPhotos\(\) async \{",
    mic_methods + "  Future<void> _pickPhotos() async {",
)

replace_once(
    AI,
    """                            'Listening — tap the microphone when finished.',\n""",
    """                            _micActive\n                                ? 'Listening — tap the microphone when finished.'\n                                : _micConnecting\n                                ? 'Connecting microphone…'\n                                : 'Reconnecting microphone…',\n""",
)

regex_once(
    AI,
    r"  Widget _micStatusChip\(\) \{.*?\n  Widget _micButton\(\) \{",
    r'''  Widget _micStatusChip() {
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
        color: _micWanted
            ? _pink.withValues(alpha: .16)
            : Colors.white.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: _micWanted ? _pink : const Color(0xFF8F8F98),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
        ),
      ),
    );
  }

  Widget _micButton() {''',
)

print('Patched edit listing video re-editor + AI listing mic health watchdog.')
