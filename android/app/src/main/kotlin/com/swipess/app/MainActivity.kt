package com.swipess.app

import android.net.Uri
import android.view.WindowManager
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

                optimizeVideo(
                    source = source,
                    startMs = startMs,
                    endMs = endMs,
                    portraitCrop = portraitCrop,
                    includeOriginalAudio = includeOriginalAudio,
                    result = result,
                )
            }
        }
    }

    private fun optimizeVideo(
        source: File,
        startMs: Long,
        endMs: Long,
        portraitCrop: Boolean,
        includeOriginalAudio: Boolean,
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
                    720,
                    1280,
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
            transformer.start(edited, output.absolutePath)
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
    }
}
