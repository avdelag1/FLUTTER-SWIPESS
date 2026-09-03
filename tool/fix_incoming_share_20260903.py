from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]


def load(rel: str) -> str:
    return (ROOT / rel).read_text()


def save(rel: str, text: str) -> None:
    (ROOT / rel).write_text(text)


def replace_once(rel: str, old: str, new: str) -> None:
    text = load(rel)
    if old not in text:
        raise SystemExit(f'missing anchor in {rel}: {old[:120]!r}')
    save(rel, text.replace(old, new, 1))


# ---------------------------------------------------------------------------
# Android: make Swipess a genuine image/video share-sheet destination without
# adding another Flutter plugin. Materialize granted content URIs immediately
# into app cache, then hand stable local files to Dart over MethodChannel.
# ---------------------------------------------------------------------------
MANIFEST = 'android/app/src/main/AndroidManifest.xml'
replace_once(
    MANIFEST,
    '''            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="swipess"/>
            </intent-filter>
        </activity>''',
    '''            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="swipess"/>
            </intent-filter>

            <!-- Gallery / Photos -> Share -> Swipess. The sender grants the
                 selected content URI; MainActivity copies it into app cache
                 before Flutter consumes it, so no broad storage access is
                 required for incoming shares. -->
            <intent-filter>
                <action android:name="android.intent.action.SEND"/>
                <action android:name="android.intent.action.SEND_MULTIPLE"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="image/*"/>
                <data android:mimeType="video/*"/>
            </intent-filter>
        </activity>''',
)

MAIN = 'android/app/src/main/kotlin/com/swipess/app/MainActivity.kt'
replace_once(MAIN, 'import android.net.Uri\n', 'import android.content.Intent\nimport android.net.Uri\nimport android.provider.OpenableColumns\n')
replace_once(
    MAIN,
    '''    private var privacyChannel: MethodChannel? = null
    private var videoOptimizerChannel: MethodChannel? = null
''',
    '''    private var privacyChannel: MethodChannel? = null
    private var videoOptimizerChannel: MethodChannel? = null
    private var incomingShareChannel: MethodChannel? = null
    private val pendingShareMedia = mutableListOf<Map<String, Any?>>()
''',
)
replace_once(
    MAIN,
    '''        super.configureFlutterEngine(flutterEngine)

        privacyChannel = MethodChannel(''',
    '''        super.configureFlutterEngine(flutterEngine)

        incomingShareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INCOMING_SHARE_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "take" -> {
                        val payload = pendingShareMedia.toList()
                        pendingShareMedia.clear()
                        result.success(payload)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        captureIncomingShare(intent, notifyFlutter = false)

        privacyChannel = MethodChannel(''',
)
replace_once(
    MAIN,
    '''    private fun optimizeVideo(
''',
    '''    override fun onNewIntent(nextIntent: Intent) {
        super.onNewIntent(nextIntent)
        setIntent(nextIntent)
        captureIncomingShare(nextIntent, notifyFlutter = true)
    }

    @Suppress("DEPRECATION")
    private fun captureIncomingShare(sourceIntent: Intent?, notifyFlutter: Boolean) {
        if (sourceIntent == null) return
        if (sourceIntent.action != Intent.ACTION_SEND &&
            sourceIntent.action != Intent.ACTION_SEND_MULTIPLE
        ) {
            return
        }

        val uris = mutableListOf<Uri>()
        if (sourceIntent.action == Intent.ACTION_SEND) {
            (sourceIntent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri)?.let(uris::add)
        } else {
            sourceIntent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                ?.let(uris::addAll)
        }

        if (uris.isEmpty()) {
            val clip = sourceIntent.clipData
            if (clip != null) {
                for (index in 0 until clip.itemCount) {
                    clip.getItemAt(index).uri?.let(uris::add)
                }
            }
        }
        if (uris.isEmpty()) return

        val materialized = uris
            .take(32)
            .mapIndexedNotNull { index, uri -> materializeSharedUri(uri, index, sourceIntent.type) }
        if (materialized.isEmpty()) return

        pendingShareMedia.clear()
        pendingShareMedia.addAll(materialized)
        if (notifyFlutter) {
            val payload = pendingShareMedia.toList()
            pendingShareMedia.clear()
            incomingShareChannel?.invokeMethod("received", payload)
        }
    }

    private fun materializeSharedUri(
        uri: Uri,
        index: Int,
        fallbackMimeType: String?,
    ): Map<String, Any?>? {
        val mimeType = contentResolver.getType(uri)?.trim().orEmpty()
            .ifEmpty { fallbackMimeType?.trim().orEmpty() }
        if (!mimeType.startsWith("image/") && !mimeType.startsWith("video/")) {
            return null
        }

        var displayName: String? = null
        try {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (column >= 0) displayName = cursor.getString(column)
                }
            }
        } catch (_: Throwable) {
        }

        val extension = when {
            mimeType == "image/png" -> ".png"
            mimeType == "image/webp" -> ".webp"
            mimeType.startsWith("image/") -> ".jpg"
            mimeType == "video/quicktime" -> ".mov"
            mimeType.startsWith("video/") -> ".mp4"
            else -> ""
        }
        val rawName = displayName?.trim().takeUnless { it.isNullOrEmpty() }
            ?: "shared-$index$extension"
        val safeName = rawName
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .takeLast(120)
            .ifEmpty { "shared-$index$extension" }
        val target = File(
            cacheDir,
            "incoming_${System.currentTimeMillis()}_${index}_$safeName",
        )

        return try {
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            if (!target.exists() || target.length() <= 0L) {
                target.delete()
                null
            } else {
                mapOf(
                    "path" to target.absolutePath,
                    "name" to safeName,
                    "mimeType" to mimeType,
                    "size" to target.length(),
                )
            }
        } catch (_: Throwable) {
            try {
                target.delete()
            } catch (_: Throwable) {
            }
            null
        }
    }

    private fun optimizeVideo(
''',
)
replace_once(
    MAIN,
    '''        videoOptimizerChannel?.setMethodCallHandler(null)
        videoOptimizerChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
''',
    '''        videoOptimizerChannel?.setMethodCallHandler(null)
        videoOptimizerChannel = null
        incomingShareChannel?.setMethodCallHandler(null)
        incomingShareChannel = null
        pendingShareMedia.clear()
        super.cleanUpFlutterEngine(flutterEngine)
''',
)
replace_once(
    MAIN,
    '''        const val PRIVACY_CHANNEL = "swipess/privacy_screen"
        const val VIDEO_OPTIMIZER_CHANNEL = "swipess/video_optimizer"
''',
    '''        const val PRIVACY_CHANNEL = "swipess/privacy_screen"
        const val VIDEO_OPTIMIZER_CHANNEL = "swipess/video_optimizer"
        const val INCOMING_SHARE_CHANNEL = "swipess/incoming_share"
''',
)


# ---------------------------------------------------------------------------
# PWA: installed browsers that support Web Share Target can receive images and
# videos directly from the OS share sheet. The service worker stores only the
# newest share session in a transient cache and redirects into the signed-in
# dashboard with an opaque session id; Dart converts the bytes to XFiles.
# ---------------------------------------------------------------------------
manifest_path = ROOT / 'web/manifest.json'
manifest = json.loads(manifest_path.read_text())
manifest['share_target'] = {
    'action': '/share-target',
    'method': 'POST',
    'enctype': 'multipart/form-data',
    'params': {
        'title': 'title',
        'text': 'text',
        'url': 'url',
        'files': [
            {
                'name': 'media',
                'accept': ['image/*', 'video/*'],
            },
        ],
    },
}
manifest_path.write_text(json.dumps(manifest, indent=4, ensure_ascii=False) + '\n')

SW = 'web/swipess_service_worker.js'
replace_once(
    SW,
    "const SWIPESS_WORKER_VERSION = '2026-08-28.1';",
    "const SWIPESS_WORKER_VERSION = '2026-09-03.2';\nconst SWIPESS_SHARE_CACHE = 'swipess-share-inbox-v1';",
)
replace_once(
    SW,
    '''self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
''',
    '''async function acceptIncomingShare(request) {
  const form = await request.formData();
  const files = form.getAll('media').filter((entry) =>
    entry instanceof File &&
    entry.size > 0 &&
    (entry.type.startsWith('image/') || entry.type.startsWith('video/'))
  ).slice(0, 32);

  if (files.length === 0) {
    return Response.redirect('/client/dashboard', 303);
  }

  // Keep only the latest not-yet-consumed share. This prevents a long-lived PWA
  // cache from accumulating private gallery media across sessions.
  await caches.delete(SWIPESS_SHARE_CACHE);
  const cache = await caches.open(SWIPESS_SHARE_CACHE);
  const session = self.crypto?.randomUUID?.() ||
    `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const manifest = [];

  for (let index = 0; index < files.length; index += 1) {
    const file = files[index];
    const resourcePath = `/__swipess_share/${encodeURIComponent(session)}/${index}`;
    const resourceUrl = new URL(resourcePath, self.location.origin).toString();
    await cache.put(
      new Request(resourceUrl),
      new Response(file, {
        headers: {
          'Content-Type': file.type || 'application/octet-stream',
          'Cache-Control': 'no-store',
        },
      }),
    );
    manifest.push({
      url: resourcePath,
      name: file.name || `shared-${index}`,
      type: file.type || '',
      size: file.size,
    });
  }

  const manifestPath = `/__swipess_share/${encodeURIComponent(session)}/manifest.json`;
  await cache.put(
    new Request(new URL(manifestPath, self.location.origin).toString()),
    new Response(JSON.stringify({ files: manifest }), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store',
      },
    }),
  );

  return Response.redirect(
    `/client/dashboard?share_session=${encodeURIComponent(session)}`,
    303,
  );
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (request.method === 'POST' && url.pathname === '/share-target') {
    event.respondWith(acceptIncomingShare(request));
    return;
  }

  if (request.method === 'GET' && url.pathname.startsWith('/__swipess_share/')) {
    event.respondWith((async () => {
      const cache = await caches.open(SWIPESS_SHARE_CACHE);
      return (await cache.match(request)) || new Response('Not found', { status: 404 });
    })());
    return;
  }

  if (request.method !== 'GET') return;
''',
)


# ---------------------------------------------------------------------------
# Dart bridge + chooser. Incoming listing media is merged into the existing
# AI draft and then opens the same full listing editor. A shared image can also
# enter ProfileCameraScreen already selected, so the user only reviews + saves.
# ---------------------------------------------------------------------------
service = ROOT / 'lib/src/core/native/incoming_share_service.dart'
service.parent.mkdir(parents=True, exist_ok=True)
service.write_text(r'''import 'dart:async';
import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class IncomingSharedMedia {
  const IncomingSharedMedia({
    required this.file,
    required this.mimeType,
  });

  final XFile file;
  final String mimeType;

  bool get isImage {
    final lower = mimeType.toLowerCase();
    if (lower.startsWith('image/')) return true;
    final name = file.name.toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.heic') ||
        name.endsWith('.heif');
  }

  bool get isVideo {
    final lower = mimeType.toLowerCase();
    if (lower.startsWith('video/')) return true;
    final name = file.name.toLowerCase();
    return name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.m4v') ||
        name.endsWith('.webm');
  }
}

class IncomingShareService {
  IncomingShareService._() {
    _installNativeHandler();
  }

  static final IncomingShareService instance = IncomingShareService._();
  static const MethodChannel _channel = MethodChannel('swipess/incoming_share');

  final StreamController<List<IncomingSharedMedia>> _events =
      StreamController<List<IncomingSharedMedia>>.broadcast();
  bool _nativeHandlerInstalled = false;

  Stream<List<IncomingSharedMedia>> get events {
    _installNativeHandler();
    return _events.stream;
  }

  void _installNativeHandler() {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        _nativeHandlerInstalled) {
      return;
    }
    _nativeHandlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'received') return;
      final media = _decodeNative(call.arguments);
      if (media.isNotEmpty) _events.add(media);
    });
  }

  Future<List<IncomingSharedMedia>> takeInitial() async {
    if (kIsWeb) return _takeWebShare();
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const <IncomingSharedMedia>[];
    }
    _installNativeHandler();
    try {
      final raw = await _channel.invokeMethod<Object?>('take');
      return _decodeNative(raw);
    } catch (error) {
      debugPrint('[IncomingShare] native take skipped: $error');
      return const <IncomingSharedMedia>[];
    }
  }

  List<IncomingSharedMedia> _decodeNative(Object? raw) {
    if (raw is! List) return const <IncomingSharedMedia>[];
    final out = <IncomingSharedMedia>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.map((key, value) => MapEntry(key.toString(), value));
      final path = map['path']?.toString().trim() ?? '';
      if (path.isEmpty) continue;
      final name = map['name']?.toString().trim();
      final mimeType = map['mimeType']?.toString().trim() ?? '';
      final size = map['size'];
      out.add(
        IncomingSharedMedia(
          file: XFile(
            path,
            name: name == null || name.isEmpty ? null : name,
            mimeType: mimeType.isEmpty ? null : mimeType,
            length: size is num ? size.toInt() : null,
          ),
          mimeType: mimeType,
        ),
      );
    }
    return out;
  }

  Future<List<IncomingSharedMedia>> _takeWebShare() async {
    final session = Uri.base.queryParameters['share_session']?.trim() ?? '';
    if (session.isEmpty) return const <IncomingSharedMedia>[];

    try {
      final encoded = Uri.encodeComponent(session);
      final manifestUri = Uri.base.resolve(
        '/__swipess_share/$encoded/manifest.json',
      );
      final manifestResponse = await http
          .get(manifestUri, headers: const {'Cache-Control': 'no-store'})
          .timeout(const Duration(seconds: 8));
      if (manifestResponse.statusCode != 200) {
        return const <IncomingSharedMedia>[];
      }

      final decoded = jsonDecode(utf8.decode(manifestResponse.bodyBytes));
      if (decoded is! Map || decoded['files'] is! List) {
        return const <IncomingSharedMedia>[];
      }

      final out = <IncomingSharedMedia>[];
      for (final raw in (decoded['files'] as List).take(32)) {
        if (raw is! Map) continue;
        final item = raw.map((key, value) => MapEntry(key.toString(), value));
        final href = item['url']?.toString().trim() ?? '';
        if (href.isEmpty) continue;
        final response = await http
            .get(Uri.base.resolve(href), headers: const {'Cache-Control': 'no-store'})
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) continue;
        final mimeType = item['type']?.toString().trim() ?? '';
        final name = item['name']?.toString().trim();
        final safeName = name == null || name.isEmpty ? 'shared-media' : name;
        out.add(
          IncomingSharedMedia(
            file: XFile.fromData(
              response.bodyBytes,
              name: safeName,
              mimeType: mimeType.isEmpty ? null : mimeType,
            ),
            mimeType: mimeType,
          ),
        );
      }
      return out;
    } catch (error) {
      debugPrint('[IncomingShare] web share skipped: $error');
      return const <IncomingSharedMedia>[];
    }
  }
}
''')

bootstrap = ROOT / 'lib/src/core/widgets/incoming_share_bootstrap.dart'
bootstrap.write_text(r'''import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/native/incoming_share_service.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/routing/app_router.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/add/data/listing_draft_repository.dart';
import 'package:flutter_swipes/src/features/camera/presentation/screens/profile_camera_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IncomingShareBootstrap extends ConsumerStatefulWidget {
  const IncomingShareBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IncomingShareBootstrap> createState() =>
      _IncomingShareBootstrapState();
}

class _IncomingShareBootstrapState
    extends ConsumerState<IncomingShareBootstrap> {
  StreamSubscription<List<IncomingSharedMedia>>? _subscription;
  List<IncomingSharedMedia>? _queued;
  bool _presenting = false;

  @override
  void initState() {
    super.initState();
    final service = IncomingShareService.instance;
    _subscription = service.events.listen(_enqueue);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = await service.takeInitial();
      if (mounted && initial.isNotEmpty) _enqueue(initial);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _enqueue(List<IncomingSharedMedia> media) {
    if (!mounted || media.isEmpty) return;
    final usable = media
        .where((item) => item.isImage || item.isVideo)
        .take(32)
        .toList(growable: false);
    if (usable.isEmpty) return;
    if (_presenting) {
      _queued = usable;
      return;
    }
    unawaited(_present(usable));
  }

  Future<BuildContext?> _navigatorContext() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final context = rootNavigatorKey.currentContext;
      if (context != null) return context;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return null;
    }
    return null;
  }

  Future<void> _present(List<IncomingSharedMedia> media) async {
    if (_presenting || !mounted) return;
    _presenting = true;
    try {
      final navContext = await _navigatorContext();
      if (!mounted || navContext == null) return;

      final hasImage = media.any((item) => item.isImage);
      final hasVideo = media.any((item) => item.isVideo);
      final choice = await showModalBottomSheet<String>(
        context: navContext,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          final isLight = Theme.of(context).brightness == Brightness.light;
          final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
          final muted = ink.withAlpha(150);
          return SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              decoration: BoxDecoration(
                color: isLight ? Colors.white : const Color(0xFF17171C),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isLight
                      ? Colors.black.withAlpha(18)
                      : Colors.white.withAlpha(20),
                ),
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
                        color: muted.withAlpha(70),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'USE IN SWIPESS',
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${media.length} shared ${media.length == 1 ? 'item' : 'items'} ready${hasVideo ? ' · video included' : ''}.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ShareChoice(
                    icon: Icons.add_business_rounded,
                    title: 'Create listing',
                    subtitle: 'Open the AI listing creator with this media already loaded.',
                    onTap: () => Navigator.of(context).pop('listing'),
                  ),
                  if (hasImage) ...[
                    const SizedBox(height: 8),
                    _ShareChoice(
                      icon: Icons.account_circle_rounded,
                      title: 'Use as profile photo',
                      subtitle: 'Review the selected photo, then save it to your profile.',
                      onTap: () => Navigator.of(context).pop('profile'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );

      if (!mounted || choice == null) return;
      if (Supabase.instance.client.auth.currentUser == null) {
        ScaffoldMessenger.of(navContext).showSnackBar(
          const SnackBar(content: Text('Sign in to use shared media in Swipess.')),
        );
        return;
      }

      if (choice == 'listing') {
        await _openListing(media);
      } else if (choice == 'profile') {
        final image = media.where((item) => item.isImage).firstOrNull;
        if (image != null) await _openProfilePhoto(image.file);
      }
    } finally {
      _presenting = false;
      final queued = _queued;
      _queued = null;
      if (mounted && queued != null && queued.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _enqueue(queued));
      }
    }
  }

  Future<void> _openListing(List<IncomingSharedMedia> media) async {
    final repository = ref.read(listingDraftRepositoryProvider);
    SavedListingDraft? existing;
    try {
      existing = await repository.load('ai-new');
    } catch (_) {}

    final incomingPhotos = media
        .where((item) => item.isImage)
        .map((item) => item.file)
        .toList(growable: false);
    final incomingVideo = media.where((item) => item.isVideo).firstOrNull?.file;
    final mergedPhotos = <XFile>[
      ...incomingPhotos,
      ...?existing?.photos,
    ].take(30).toList(growable: false);
    final payload = Map<String, dynamic>.from(
      existing?.payload ?? const <String, dynamic>{},
    );
    payload.putIfAbsent('video_audio_enabled', () => true);

    await repository.save(
      draftKey: 'ai-new',
      kind: existing?.kind ?? 'ai',
      category: existing?.category ?? 'property',
      step: existing?.step ?? 0,
      payload: payload,
      sourceListingId: existing?.sourceListingId,
      photos: mergedPhotos,
      video: incomingVideo ?? existing?.video,
      documents: existing?.documents ?? const <XFile>[],
      backgroundMusic: existing?.backgroundMusic,
    );

    if (!mounted) return;
    final router = ref.read(appRouterProvider);
    _removeShareQuery(router);
    router.push(AppPaths.ownerListingsNew);
  }

  Future<void> _openProfilePhoto(XFile image) async {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push<String>(
      MaterialPageRoute(
        builder: (_) => ProfileCameraScreen(
          mode: ProfileCameraMode.selfie,
          initialFile: image,
        ),
      ),
    );
    if (!mounted) return;
    ref.invalidate(currentProfileProvider);
    final router = ref.read(appRouterProvider);
    _removeShareQuery(router);
  }

  void _removeShareQuery(GoRouter router) {
    if (!kIsWeb) return;
    final uri = router.routeInformationProvider.value.uri;
    if (!uri.queryParameters.containsKey('share_session')) return;
    final query = Map<String, String>.from(uri.queryParameters)
      ..remove('share_session');
    router.replace(
      uri
          .replace(queryParameters: query.isEmpty ? null : query)
          .toString(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ShareChoice extends StatelessWidget {
  const _ShareChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ink = isLight ? const Color(0xFF0A0A0D) : Colors.white;
    return Material(
      color: isLight ? const Color(0xFFF6F6F8) : const Color(0xFF222228),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppTheme.brandPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: ink.withAlpha(145),
                        fontSize: 10.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ink.withAlpha(120)),
            ],
          ),
        ),
      ),
    );
  }
}
''')

# GoRouter needs an explicit root navigator key so a global cold-start share can
# present its chooser from a context that is genuinely below Navigator.
ROUTER = 'lib/src/core/routing/app_router.dart'
replace_once(
    ROUTER,
    "import 'package:flutter_swipes/src/features/video_tours/presentation/screens/video_tours_screen.dart';\n\nfinal appRouterProvider",
    "import 'package:flutter_swipes/src/features/video_tours/presentation/screens/video_tours_screen.dart';\n\nfinal rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'swipess-root');\n\nfinal appRouterProvider",
)
replace_once(
    ROUTER,
    '''  final router = GoRouter(
    initialLocation: AppPaths.splash,''',
    '''  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppPaths.splash,''',
)

APP = 'lib/src/app.dart'
replace_once(
    APP,
    "import 'package:flutter_swipes/src/core/widgets/overlay_modals_host.dart';",
    "import 'package:flutter_swipes/src/core/widgets/incoming_share_bootstrap.dart';\nimport 'package:flutter_swipes/src/core/widgets/overlay_modals_host.dart';",
)
replace_once(
    APP,
    '''                        child: BiometricGate(
                          child: OverlayModalsHost(
                            child: child ?? const SizedBox.shrink(),
                          ),
                        ),''',
    '''                        child: BiometricGate(
                          child: IncomingShareBootstrap(
                            child: OverlayModalsHost(
                              child: child ?? const SizedBox.shrink(),
                            ),
                          ),
                        ),''',
)

PROFILE_CAMERA = 'lib/src/features/camera/presentation/screens/profile_camera_screen.dart'
replace_once(
    PROFILE_CAMERA,
    '''class ProfileCameraScreen extends StatefulWidget {
  const ProfileCameraScreen({super.key, this.mode = ProfileCameraMode.selfie});

  final ProfileCameraMode mode;
''',
    '''class ProfileCameraScreen extends StatefulWidget {
  const ProfileCameraScreen({
    super.key,
    this.mode = ProfileCameraMode.selfie,
    this.initialFile,
  });

  final ProfileCameraMode mode;
  final XFile? initialFile;
''',
)
replace_once(
    PROFILE_CAMERA,
    '''class _ProfileCameraScreenState extends State<ProfileCameraScreen> {
  XFile? _shot;
  bool _busy = false;
  String? _error;

  Future<void> _capture() async {''',
    '''class _ProfileCameraScreenState extends State<ProfileCameraScreen> {
  XFile? _shot;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _shot = widget.initialFile;
  }

  Future<void> _capture() async {''',
)

print('incoming share patch applied')
