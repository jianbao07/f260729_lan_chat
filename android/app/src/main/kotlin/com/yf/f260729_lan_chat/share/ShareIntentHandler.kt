package com.yf.f260729_lan_chat.share

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.util.Log
import com.yf.f260729_lan_chat.pigeon.ShareIntentFlutterApi
import com.yf.f260729_lan_chat.pigeon.ShareIntentHostApi
import com.yf.f260729_lan_chat.pigeon.SharedFileItem
import com.yf.f260729_lan_chat.pigeon.SharedPayload
import io.flutter.plugin.common.BinaryMessenger
import java.io.File
import java.io.FileInputStream

class ShareIntentHandler(
    private val activity: Activity,
    binaryMessenger: BinaryMessenger,
) : ShareIntentHostApi {
    private val flutterApi = ShareIntentFlutterApi(binaryMessenger)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val inboxDir = File(activity.cacheDir, "share_inbox")
    private var pending: SharedPayload? = null
    private var dartReady = false

    init {
        ShareIntentHostApi.setUp(binaryMessenger, this)
    }

    override fun takePendingShare(): SharedPayload? {
        dartReady = true
        val payload = pending
        pending = null
        return payload
    }

    fun consume(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return
        if (intent.getBooleanExtra(EXTRA_HANDLED, false)) return
        intent.putExtra(EXTRA_HANDLED, true)
        Thread {
            val payload = parse(intent) ?: return@Thread
            mainHandler.post { deliver(payload) }
        }.start()
    }

    private fun deliver(payload: SharedPayload) {
        if (dartReady) {
            flutterApi.onShareReceived(payload) { result ->
                result.exceptionOrNull()?.let { Log.e(TAG, "deliver share failed", it) }
            }
        } else {
            pending = payload
        }
    }

    private fun parse(intent: Intent): SharedPayload? {
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.trim()?.ifEmpty { null }
        val files = collectUris(intent).mapNotNull { copyUri(it, intent.type) }
        if (text == null && files.isEmpty()) return null
        return SharedPayload(text = text, files = files)
    }

    private fun collectUris(intent: Intent): List<Uri> {
        val uris = LinkedHashSet<Uri>()
        when (intent.action) {
            Intent.ACTION_SEND -> extraStreamUri(intent)?.let { uris.add(it) }
            Intent.ACTION_SEND_MULTIPLE -> uris.addAll(extraStreamUris(intent))
        }
        intent.clipData?.let { clip ->
            for (i in 0 until clip.itemCount) {
                clip.getItemAt(i).uri?.let(uris::add)
            }
        }
        return uris.toList()
    }

    private fun extraStreamUri(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    private fun extraStreamUris(intent: Intent): List<Uri> {
        val list = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
        }
        return list ?: emptyList()
    }

    private fun copyUri(uri: Uri, fallbackMime: String?): SharedFileItem? {
        var dest: File? = null
        return try {
            tryTakePersistable(uri)
            val name = queryDisplayName(uri) ?: uri.lastPathSegment?.substringAfterLast('/') ?: "file"
            val mime = activity.contentResolver.getType(uri) ?: fallbackMime
            if (!inboxDir.exists()) inboxDir.mkdirs()
            dest = File(inboxDir, "${System.currentTimeMillis()}_${safeName(name)}")
            val outFile = dest!!
            val copied = when (uri.scheme) {
                "file" -> {
                    val path = uri.path
                    if (path == null) {
                        outFile.delete()
                        return null
                    }
                    val src = File(path)
                    if (!src.exists()) {
                        outFile.delete()
                        return null
                    }
                    FileInputStream(src).use { input -> outFile.outputStream().use { input.copyTo(it) } }
                    true
                }
                else -> {
                    activity.contentResolver.openInputStream(uri)?.use { input ->
                        outFile.outputStream().use { input.copyTo(it) }
                    } != null
                }
            }
            if (!copied || !outFile.exists()) {
                outFile.delete()
                return null
            }
            SharedFileItem(path = outFile.absolutePath, name = name, mimeType = mime)
        } catch (e: Exception) {
            Log.e(TAG, "copy share uri failed: $uri", e)
            dest?.delete()
            null
        }
    }

    private fun tryTakePersistable(uri: Uri) {
        try {
            activity.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (_: Exception) {
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        val resolver = activity.contentResolver
        return try {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (!cursor.moveToFirst()) return@use null
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index < 0) null else cursor.getString(index)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun safeName(name: String): String {
        val trimmed = name.trim().ifEmpty { "file" }
        return trimmed.replace(Regex("""[\\/:*?"<>|]"""), "_").replace("..", "_")
    }

    companion object {
        private const val TAG = "ShareIntent"
        private const val EXTRA_HANDLED = "yf_code_share_handled"
    }
}
