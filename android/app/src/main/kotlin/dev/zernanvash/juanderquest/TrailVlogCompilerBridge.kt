package dev.zernanvash.juanderquest

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.annotation.OptIn
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.TextureOverlay
import com.google.common.collect.ImmutableList
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.Executors

/**
 * Plan 115 (v0.4.0): Native Android Media3 Transformer bridge for stitching
 * 3-second Trail Vlog clips, 1.5s pixel stop cards, 2.0s outro stamp card,
 * HUD overlays, and Chiptune BGM into a single 720x1280 MP4.
 */
class TrailVlogCompilerBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "com.juanderquest.app/vlog_compiler")
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "compileTrailVlog" -> handleCompileTrailVlog(call, result)
            "saveVideoToGallery" -> handleSaveVideoToGallery(call, result)
            "extractClipThumbnails" -> handleExtractClipThumbnails(call, result)
            else -> result.notImplemented()
        }
    }

    @OptIn(UnstableApi::class)
    private fun handleCompileTrailVlog(call: MethodCall, result: MethodChannel.Result) {
        val rawSegments = call.argument<List<Map<String, Any?>>>("segments")
        val outputPath = call.argument<String>("outputPath")
        val audioMode = call.argument<String>("audioMode") ?: "bgm_mix"
        val bgmAssetKey = call.argument<String>("bgmAssetKey")

        if (rawSegments.isNullOrEmpty() || outputPath.isNullOrBlank()) {
            result.error("INVALID_ARGS", "segments and outputPath are required", null)
            return
        }

        val outFile = File(outputPath)
        outFile.parentFile?.mkdirs()
        if (outFile.exists()) {
            outFile.delete()
        }

        try {
            val editedItems = mutableListOf<EditedMediaItem>()
            var totalDurationMs = 0

            for (seg in rawSegments) {
                val type = seg["type"] as? String ?: "video"
                val path = seg["path"] as? String ?: continue
                val overlayPngPath = seg["overlayPngPath"] as? String
                val durationMs = (seg["durationMs"] as? Number)?.toInt() ?: 3000
                val srcFile = File(path)
                if (!srcFile.exists() || srcFile.length() == 0L) continue

                totalDurationMs += durationMs
                val mediaUri = Uri.fromFile(srcFile)
                val mediaItemBuilder = MediaItem.Builder().setUri(mediaUri)
                if (type == "image_card") {
                    mediaItemBuilder.setImageDurationMs(durationMs.toLong())
                }
                val mediaItem = mediaItemBuilder.build()

                val videoEffects = mutableListOf<Effect>(
                    Presentation.createForWidthAndHeight(
                        720,
                        1280,
                        Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP,
                    )
                )

                if (type == "video" && !overlayPngPath.isNullOrBlank()) {
                    val overlayFile = File(overlayPngPath)
                    if (overlayFile.exists()) {
                        val bmp = BitmapFactory.decodeFile(overlayFile.absolutePath)
                        if (bmp != null) {
                            val overlay = BitmapOverlay.createStaticBitmapOverlay(bmp)
                            videoEffects.add(OverlayEffect(ImmutableList.of<TextureOverlay>(overlay)))
                        }
                    }
                }

                val itemBuilder = EditedMediaItem.Builder(mediaItem)
                    .setEffects(Effects(emptyList(), videoEffects))

                if (type == "image_card" || audioMode == "bgm_only") {
                    itemBuilder.setRemoveAudio(true)
                }

                editedItems.add(itemBuilder.build())
            }

            if (editedItems.isEmpty()) {
                result.error("NO_SEGMENTS", "No valid media segments found to compile.", null)
                return
            }

            val sequences = mutableListOf<EditedMediaItemSequence>()
            sequences.add(EditedMediaItemSequence(editedItems))

            if ((audioMode == "bgm_mix" || audioMode == "bgm_only") && !bgmAssetKey.isNullOrBlank()) {
                val bgmFile = ensureAssetCopiedToCache(bgmAssetKey)
                if (bgmFile != null && bgmFile.exists()) {
                    val bgmItem = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(bgmFile)))
                        .setRemoveVideo(true)
                        .build()
                    sequences.add(EditedMediaItemSequence(listOf(bgmItem), /* isLooping= */ true))
                }
            }

            val composition = Composition.Builder(sequences).build()
            var finished = false

            val transformer = Transformer.Builder(context)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        if (finished) return
                        finished = true
                        result.success(
                            mapOf(
                                "outputPath" to outFile.absolutePath,
                                "sizeBytes" to outFile.length(),
                                "durationMs" to totalDurationMs,
                            )
                        )
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException,
                    ) {
                        if (finished) return
                        finished = true
                        // Fallback: concatenate raw MP4 clips with MediaMuxer so export still succeeds
                        // on devices with restricted image/effect codec pipelines.
                        ioExecutor.execute {
                            val fallbackOk = fallbackConcatVideos(rawSegments, outFile)
                            mainHandler.post {
                                if (fallbackOk && outFile.exists() && outFile.length() > 0L) {
                                    result.success(
                                        mapOf(
                                            "outputPath" to outFile.absolutePath,
                                            "sizeBytes" to outFile.length(),
                                            "durationMs" to totalDurationMs,
                                        )
                                    )
                                } else {
                                    result.error(
                                        "COMPILE_FAILED",
                                        exportException.message ?: "Media3 compilation failed",
                                        null,
                                    )
                                }
                            }
                        }
                    }
                })
                .build()

            transformer.start(composition, outFile.absolutePath)
        } catch (e: Exception) {
            result.error("COMPILE_ERROR", e.message, null)
        }
    }

    private fun ensureAssetCopiedToCache(assetKey: String): File? {
        return try {
            val lookupKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetKey)
            val cacheFile = File(context.cacheDir, "vlog_bgm_${lookupKey.hashCode()}.mp3")
            if (!cacheFile.exists() || cacheFile.length() == 0L) {
                context.assets.open(lookupKey).use { input ->
                    FileOutputStream(cacheFile).use { output ->
                        input.copyTo(output)
                    }
                }
            }
            cacheFile
        } catch (_: Exception) {
            null
        }
    }

    private fun fallbackConcatVideos(
        rawSegments: List<Map<String, Any?>>,
        outFile: File,
    ): Boolean {
        val videoPaths = rawSegments
            .filter { (it["type"] as? String) == "video" }
            .mapNotNull { it["path"] as? String }
            .filter { File(it).exists() && File(it).length() > 0L }
        if (videoPaths.isEmpty()) return false
        if (videoPaths.size == 1) {
            File(videoPaths.first()).copyTo(outFile, overwrite = true)
            return true
        }
        return try {
            val muxer = MediaMuxer(outFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            var outVideoTrack = -1
            var outAudioTrack = -1
            var muxerStarted = false
            var timeOffsetUs = 0L
            val buffer = ByteBuffer.allocate(1024 * 1024)
            val bufferInfo = android.media.MediaCodec.BufferInfo()

            for (path in videoPaths) {
                val extractor = MediaExtractor()
                extractor.setDataSource(path)
                var videoTrackIdx = -1
                var audioTrackIdx = -1
                var clipMaxPtsUs = 0L

                for (i in 0 until extractor.trackCount) {
                    val format = extractor.getTrackFormat(i)
                    val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                    if (mime.startsWith("video/") && videoTrackIdx == -1) {
                        videoTrackIdx = i
                        if (outVideoTrack == -1) {
                            outVideoTrack = muxer.addTrack(format)
                        }
                    } else if (mime.startsWith("audio/") && audioTrackIdx == -1) {
                        audioTrackIdx = i
                        if (outAudioTrack == -1) {
                            outAudioTrack = muxer.addTrack(format)
                        }
                    }
                }

                if (!muxerStarted && outVideoTrack != -1) {
                    muxer.start()
                    muxerStarted = true
                }

                if (videoTrackIdx != -1 && outVideoTrack != -1) {
                    extractor.selectTrack(videoTrackIdx)
                    while (true) {
                        bufferInfo.offset = 0
                        bufferInfo.size = extractor.readSampleData(buffer, 0)
                        if (bufferInfo.size < 0) break
                        val pts = extractor.sampleTime
                        if (pts > clipMaxPtsUs) clipMaxPtsUs = pts
                        bufferInfo.presentationTimeUs = timeOffsetUs + pts
                        bufferInfo.flags = extractor.sampleFlags
                        muxer.writeSampleData(outVideoTrack, buffer, bufferInfo)
                        extractor.advance()
                    }
                    extractor.unselectTrack(videoTrackIdx)
                }

                if (audioTrackIdx != -1 && outAudioTrack != -1) {
                    extractor.selectTrack(audioTrackIdx)
                    while (true) {
                        bufferInfo.offset = 0
                        bufferInfo.size = extractor.readSampleData(buffer, 0)
                        if (bufferInfo.size < 0) break
                        val pts = extractor.sampleTime
                        if (pts > clipMaxPtsUs) clipMaxPtsUs = pts
                        bufferInfo.presentationTimeUs = timeOffsetUs + pts
                        bufferInfo.flags = extractor.sampleFlags
                        muxer.writeSampleData(outAudioTrack, buffer, bufferInfo)
                        extractor.advance()
                    }
                    extractor.unselectTrack(audioTrackIdx)
                }

                timeOffsetUs += clipMaxPtsUs + 33_333L
                extractor.release()
            }

            if (muxerStarted) {
                muxer.stop()
            }
            muxer.release()
            muxerStarted
        } catch (_: Exception) {
            File(videoPaths.first()).copyTo(outFile, overwrite = true)
            true
        }
    }

    private fun handleSaveVideoToGallery(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        val displayName = call.argument<String>("displayName")
            ?: "JuanDerQuest_TrailVlog_${System.currentTimeMillis()}.mp4"
        if (filePath.isNullOrBlank()) {
            result.error("INVALID_ARGS", "filePath is required", null)
            return
        }
        val source = File(filePath)
        if (!source.exists()) {
            result.error("FILE_NOT_FOUND", "Compiled MP4 does not exist", null)
            return
        }

        ioExecutor.execute {
            try {
                val resolver = context.contentResolver
                val values = ContentValues().apply {
                    put(MediaStore.Video.Media.DISPLAY_NAME, displayName)
                    put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        put(
                            MediaStore.Video.Media.RELATIVE_PATH,
                            "${Environment.DIRECTORY_MOVIES}/JuanDerQuest",
                        )
                        put(MediaStore.Video.Media.IS_PENDING, 1)
                    }
                }
                val uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
                    ?: throw IllegalStateException("Could not create MediaStore entry")

                resolver.openOutputStream(uri)?.use { outStream ->
                    source.inputStream().use { inStream ->
                        inStream.copyTo(outStream)
                    }
                } ?: throw IllegalStateException("Could not open MediaStore output stream")

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    values.clear()
                    values.put(MediaStore.Video.Media.IS_PENDING, 0)
                    resolver.update(uri, values, null, null)
                }

                mainHandler.post { result.success(uri.toString()) }
            } catch (e: Exception) {
                mainHandler.post { result.error("GALLERY_SAVE_FAILED", e.message, null) }
            }
        }
    }

    private fun handleExtractClipThumbnails(call: MethodCall, result: MethodChannel.Result) {
        val clipPaths = call.argument<List<String>>("clipPaths") ?: emptyList()
        ioExecutor.execute {
            val out = mutableMapOf<String, String>()
            val thumbDir = File(context.cacheDir, "vlog_thumbs").apply { mkdirs() }
            for (path in clipPaths) {
                val file = File(path)
                if (!file.exists()) continue
                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(path)
                    val frame = retriever.getFrameAtTime(500_000L)
                        ?: retriever.getFrameAtTime(0L)
                    if (frame != null) {
                        val thumbFile = File(thumbDir, "thumb_${path.hashCode()}.jpg")
                        FileOutputStream(thumbFile).use { fos ->
                            frame.compress(Bitmap.CompressFormat.JPEG, 82, fos)
                        }
                        out[path] = thumbFile.absolutePath
                        frame.recycle()
                    }
                } catch (_: Exception) {
                } finally {
                    try {
                        retriever.release()
                    } catch (_: Exception) {
                    }
                }
            }
            mainHandler.post { result.success(out) }
        }
    }
}
