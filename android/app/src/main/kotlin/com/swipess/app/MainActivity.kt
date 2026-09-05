package com.swipess.app

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.view.WindowManager
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Native bridges used by Swipess for privacy protection and delivery-grade
 * listing video exports.
 */
@UnstableApi
class MainActivity : FlutterActivity() {
    private var privacyChannel: MethodChannel? = null
    private var videoOptimizerChannel: MethodChannel? = null
    private var incomingShareChannel: MethodChannel? = null
    private val pendingShareMedia = mutableListOf<Map<String, Any?>>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

        privacyChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PRIVACY_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        setSecure(true)
                        result.success(true)
                    }
                    "disable" -> {
                        setSecure(false)
                        result.success(true)
                    }
                    "isCaptured" -> result.success(false)
                    else -> result.notImplemented()
                }
            }
        }

        videoOptimizerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VIDEO_OPTIMIZER_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                if (call.method != "optimize") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val path = call.argument<String>("path")?.trim().orEmpty()
                if (path.isEmpty()) {
                    result.error("invalid_path", "Missing input video path", null)
                    return@setMethodCallHandler
                }

                val source = File(path)
                if (!source.exists() || source.length() <= 0L) {
                    result.error("missing_video", "Selected video is unavailable", null)
                    return@setMethodCallHandler
                }

                val startMs = (call.argument<Number>("startMs")?.toLong() ?: 0L).coerceAtLeast(0L)
                val endMs = call.argument<Number>("endMs")?.toLong() ?: -1L
                val portraitCrop = call.argument<Boolean>("portraitCrop") ?: false
                val includeOriginalAudio = call.argument<Boolean>("includeOriginalAudio") ?: true
                val musicPath = call.argument<String>("musicPath")?.trim().orEmpty()
                val musicStartMs = (call.argument<Number>("musicStartMs")?.toLong() ?: 0L).coerceAtLeast(0L)
                val musicEndMs = call.argument<Number>("musicEndMs")?.toLong() ?: -1L

                optimizeVideo(
                    source = source,
                    startMs = startMs,
                    endMs = endMs,
                    portraitCrop = portraitCrop,
                    includeOriginalAudio = includeOriginalAudio,
                    musicPath = musicPath,
                    musicStartMs = musicStartMs,
                    musicEndMs = musicEndMs,
                    result = result,
                )
            }
        }
    }

    override fun onNewIntent(nextIntent: Intent) {
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
        source: File,
        startMs: Long,
        endMs: Long,
        portraitCrop: Boolean,
        includeOriginalAudio: Boolean,
        musicPath: String,
        musicStartMs: Long,
        musicEndMs: Long,
        result: MethodChannel.Result,
    ) {
        val output = File(cacheDir, "swipess_${System.currentTimeMillis()}.mp4")
        if (output.exists()) output.delete()

        val clippingBuilder = MediaItem.ClippingConfiguration.Builder()
            .setStartPositionMs(startMs)
        if (endMs > startMs) clippingBuilder.setEndPositionMs(endMs)

        val mediaItem = MediaItem.Builder()
            .setUri(Uri.fromFile(source))
            .setClippingConfiguration(clippingBuilder.build())
            .build()

        val videoEffects = if (portraitCrop) {
            listOf(
                Presentation.createForWidthAndHeight(
                    1080,
                    1920,
                    Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP,
                ),
            )
        } else {
            listOf(Presentation.createForShortSide(720))
        }

        val edited = EditedMediaItem.Builder(mediaItem)
            .setRemoveAudio(!includeOriginalAudio)
            .setEffects(Effects(emptyList(), videoEffects))
            .build()

        val musicFile = musicPath.takeIf { it.isNotEmpty() }?.let(::File)
        val composition = if (musicFile != null && musicFile.exists() && musicFile.length() > 0L) {
            val musicClip = MediaItem.ClippingConfiguration.Builder()
                .setStartPositionMs(musicStartMs)
            if (musicEndMs > musicStartMs) musicClip.setEndPositionMs(musicEndMs)
            val musicItem = EditedMediaItem.Builder(
                MediaItem.Builder()
                    .setUri(Uri.fromFile(musicFile))
                    .setClippingConfiguration(musicClip.build())
                    .build(),
            ).build()
            val backgroundAudioSequence = EditedMediaItemSequence
                .withAudioFrom(listOf(musicItem))
                .buildUpon()
                .setIsLooping(true)
                .build()
            Composition.Builder(
                EditedMediaItemSequence(edited),
                backgroundAudioSequence,
            ).build()
        } else {
            Composition.Builder(EditedMediaItemSequence(edited)).build()
        }

        val transformer = Transformer.Builder(this)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .addListener(
                object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        if (!output.exists() || output.length() <= 64L) {
                            result.error("empty_export", "Video export produced no data", null)
                            return
                        }
                        result.success(
                            mapOf(
                                "path" to output.absolutePath,
                                "name" to output.name,
                                "mimeType" to "video/mp4",
                                "size" to output.length(),
                            ),
                        )
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException,
                    ) {
                        try {
                            output.delete()
                        } catch (_: Throwable) {
                        }
                        result.error(
                            "video_export_failed",
                            exportException.message ?: "Could not optimize video",
                            null,
                        )
                    }
                },
            )
            .build()

        try {
            transformer.start(composition, output.absolutePath)
        } catch (error: Throwable) {
            try {
                output.delete()
            } catch (_: Throwable) {
            }
            result.error("video_export_failed", error.message ?: error.toString(), null)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        privacyChannel?.setMethodCallHandler(null)
        privacyChannel = null
        videoOptimizerChannel?.setMethodCallHandler(null)
        videoOptimizerChannel = null
        incomingShareChannel?.setMethodCallHandler(null)
        incomingShareChannel = null
        pendingShareMedia.clear()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun setSecure(secure: Boolean) {
        runOnUiThread {
            if (secure) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }

    private companion object {
        const val PRIVACY_CHANNEL = "swipess/privacy_screen"
        const val VIDEO_OPTIMIZER_CHANNEL = "swipess/video_optimizer"
        const val INCOMING_SHARE_CHANNEL = "swipess/incoming_share"
    }
}
