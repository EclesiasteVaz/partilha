package com.partilha.partilha

import android.app.DownloadManager
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Hosts the platform side of [MulticastLock] and [ReceivedFileService].
 *
 * - `partilha/multicast_lock`: reference-counted `WifiManager.MulticastLock`
 *   held only while mDNS discovery runs.
 * - `partilha/downloads`: publishes received files into Android's public
 *   `Downloads` collection via `MediaStore.Downloads` (API 29+) or public
 *   directory + `MediaScannerConnection` (API < 29), and opens received files
 *   using `Intent.ACTION_VIEW` with fallback to `ACTION_VIEW_DOWNLOADS`.
 */
class MainActivity : FlutterActivity() {
    private var lock: WifiManager.MulticastLock? = null
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val savedUris = ConcurrentHashMap<String, Uri>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MULTICAST_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        acquireMulticastLock()
                        result.success(null)
                    }
                    "release" -> {
                        releaseMulticastLock()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOADS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                        val fileName = call.argument<String>("fileName")
                        if (sourcePath.isNullOrEmpty() || fileName.isNullOrEmpty()) {
                            result.success(sourcePath ?: "")
                            return@setMethodCallHandler
                        }
                        ioExecutor.execute {
                            val finalPath = saveFileToPublicDownloads(sourcePath, fileName)
                            runOnUiThread {
                                result.success(finalPath)
                            }
                        }
                    }
                    "openFile" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrEmpty()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val opened = openReceivedFile(path)
                        result.success(opened)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveFileToPublicDownloads(sourcePath: String, fileName: String): String {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) {
            return sourcePath
        }

        val mimeType = resolveMimeType(fileName)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val resolver = applicationContext.contentResolver
                val publicDownloadsDir =
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)

                // If the file is already in the public Downloads directory (e.g. when
                // MANAGE_EXTERNAL_STORAGE is granted), just index it via MediaScanner.
                if (sourceFile.parentFile?.canonicalPath == publicDownloadsDir?.canonicalPath) {
                    MediaScannerConnection.scanFile(
                        applicationContext,
                        arrayOf(sourceFile.absolutePath),
                        arrayOf(mimeType)
                    ) { scannedPath, uri ->
                        if (uri != null && scannedPath != null) {
                            savedUris[scannedPath] = uri
                        }
                    }
                    return sourceFile.absolutePath
                }

                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }

                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: return sourcePath

                resolver.openOutputStream(uri)?.use { output ->
                    FileInputStream(sourceFile).use { input ->
                        input.copyTo(output)
                    }
                } ?: return sourcePath

                val completeValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                resolver.update(uri, completeValues, null, null)

                // Remove the temporary staging copy in app-scoped storage so disk
                // space is not duplicated.
                sourceFile.delete()

                var displayPath = "/storage/emulated/0/Download/$fileName"
                resolver.query(
                    uri,
                    arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
                    null,
                    null,
                    null
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val actualName = cursor.getString(0)
                        if (!actualName.isNullOrEmpty()) {
                            displayPath = "/storage/emulated/0/Download/$actualName"
                        }
                    }
                }

                savedUris[displayPath] = uri
                savedUris[sourcePath] = uri
                return displayPath
            } catch (_: Exception) {
                return sourcePath
            }
        } else {
            try {
                val publicDir =
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                if (!publicDir.exists()) {
                    publicDir.mkdirs()
                }
                val destFile = resolveUniqueLegacyFile(publicDir, fileName)
                if (sourceFile.canonicalPath != destFile.canonicalPath) {
                    FileInputStream(sourceFile).use { input ->
                        FileOutputStream(destFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                    sourceFile.delete()
                }
                MediaScannerConnection.scanFile(
                    applicationContext,
                    arrayOf(destFile.absolutePath),
                    arrayOf(mimeType)
                ) { scannedPath, uri ->
                    if (uri != null && scannedPath != null) {
                        savedUris[scannedPath] = uri
                    }
                }
                return destFile.absolutePath
            } catch (_: Exception) {
                return sourcePath
            }
        }
    }

    private fun resolveUniqueLegacyFile(dir: File, fileName: String): File {
        var candidate = File(dir, fileName)
        if (!candidate.exists()) return candidate

        val dotIndex = fileName.lastIndexOf('.')
        val base = if (dotIndex > 0) fileName.substring(0, dotIndex) else fileName
        val ext = if (dotIndex > 0) fileName.substring(dotIndex) else ""
        var counter = 1
        while (candidate.exists()) {
            candidate = File(dir, "$base ($counter)$ext")
            counter++
        }
        return candidate
    }

    private fun openReceivedFile(path: String): Boolean {
        val fileName = File(path).name
        val mimeType = resolveMimeType(fileName)
        val uri = savedUris[path] ?: findMediaStoreUri(fileName)

        if (uri != null) {
            try {
                val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, mimeType)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(viewIntent)
                return true
            } catch (_: Exception) {
                // Fall through to opening the Downloads explorer below.
            }
        }

        return try {
            val downloadsIntent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(downloadsIntent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun findMediaStoreUri(fileName: String): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return null
        }
        try {
            val resolver = applicationContext.contentResolver
            val projection = arrayOf(MediaStore.MediaColumns._ID)
            val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
            val selectionArgs = arrayOf(fileName)
            val sortOrder = "${MediaStore.MediaColumns.DATE_ADDED} DESC"
            resolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                sortOrder
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id = cursor.getLong(0)
                    return ContentUris.withAppendedId(
                        MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                        id
                    )
                }
            }
        } catch (_: Exception) {
            return null
        }
        return null
    }

    private fun resolveMimeType(fileName: String): String {
        val dotIndex = fileName.lastIndexOf('.')
        if (dotIndex >= 0 && dotIndex < fileName.length - 1) {
            val ext = fileName.substring(dotIndex + 1).lowercase()
            val detected = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
            if (!detected.isNullOrEmpty()) {
                return detected
            }
        }
        return "application/octet-stream"
    }

    /**
     * Acquires the lock, or increments its hold count when already held.
     *
     * `isReferenceCounted` is left at its default of true, so concurrent
     * acquire/release pairs nest correctly instead of the second release
     * dropping a lock the first caller still needs.
     */
    private fun acquireMulticastLock() {
        val current = lock ?: run {
            val wifiManager =
                applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            wifiManager.createMulticastLock(LOCK_TAG).also {
                it.setReferenceCounted(true)
            }
        }
        current.acquire()
        lock = current
    }

    /**
     * Releases one hold, dropping the reference once nothing holds the lock.
     *
     * With reference counting enabled, [WifiManager.MulticastLock.isHeld] stays
     * true until every acquire has a matching release, so it is what decides
     * whether the lock can be discarded.
     */
    private fun releaseMulticastLock() {
        val current = lock ?: return
        if (current.isHeld) {
            current.release()
        }
        if (!current.isHeld) {
            lock = null
        }
    }

    override fun onDestroy() {
        // A lock leaked past the activity would keep the Wi-Fi radio awake for
        // the rest of the process lifetime.
        lock?.let { if (it.isHeld) it.release() }
        lock = null
        ioExecutor.shutdown()
        super.onDestroy()
    }

    private companion object {
        const val MULTICAST_CHANNEL = "partilha/multicast_lock"
        const val DOWNLOADS_CHANNEL = "partilha/downloads"
        const val LOCK_TAG = "partilha-discovery"
    }
}