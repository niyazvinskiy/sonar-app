package com.hiddify.hiddify.sonar

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.IntentCompat
import com.hiddify.hiddify.R
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * Обновления Sonar на Android без участия человека.
 *
 * Пока работает VPN, раз в 6 часов смотрим последний выпуск на GitHub, качаем APK
 * в фоне и ставим его через системный установщик, когда экран погашен. Android 12+
 * разрешает приложению молча обновлять само себя; на старых версиях и в первый раз
 * система может спросить подтверждение, тогда приходит уведомление «Нажмите, чтобы
 * обновить». VPN после обновления включает BootReceiver по MY_PACKAGE_REPLACED.
 *
 * Файл кладётся туда же и с тем же именем, что у SonarUpdater во Flutter, поэтому
 * дважды одно и то же не качается.
 */
object SonarUpdate {
    private const val TAG = "A/SonarUpdate"
    private const val RELEASES = "https://api.github.com/repos/niyazvinskiy/sonar-app/releases/latest"
    private const val CHANNEL_ID = "sonar-update"
    private const val NOTIFICATION_ID = 7301
    private const val PREFS = "sonar_update"
    private const val EVERY_MS = 6 * 60 * 60 * 1000L
    const val ACTION_STATUS = "app.sonar.vpn.UPDATE_STATUS"

    /** Видно ли сейчас окно Sonar: тогда подтверждение показываем сразу, а не уведомлением. */
    @Volatile
    var foreground = false

    private var loop: Job? = null

    fun startLoop(context: Context) {
        if (loop?.isActive == true) return
        val app = context.applicationContext
        loop = CoroutineScope(Dispatchers.IO + SupervisorJob()).launch {
            delay(3 * 60 * 1000L) // сначала даём VPN спокойно подключиться
            while (isActive) {
                // Сверяемся с настоящими часами: во сне телефона таймеры отстают
                val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                if (System.currentTimeMillis() - prefs.getLong("checked", 0) >= EVERY_MS) {
                    val ok = runCatching { checkAndInstall(app) }.onFailure { Log.w(TAG, "update check failed", it) }
                    // Не вышло: отметку не ставим, следующая попытка через полчаса, а не через 6 часов
                    if (ok.isSuccess) prefs.edit().putLong("checked", System.currentTimeMillis()).apply()
                }
                delay(30 * 60 * 1000L)
            }
        }
    }

    fun stopLoop() {
        loop?.cancel()
        loop = null
    }

    private suspend fun checkAndInstall(context: Context) {
        val current = context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: return
        val release = JSONObject(fetch(RELEASES))
        val tag = release.optString("tag_name").removePrefix("sonar-").removePrefix("v")
        val dir = File(context.cacheDir, "sonar-update").apply { mkdirs() }
        if (!newer(tag, current)) {
            dir.listFiles()?.filter { it.name.endsWith(".apk") || it.name.endsWith(".part") }?.forEach { it.delete() }
            return
        }
        val name = assetName()
        val assets = release.optJSONArray("assets") ?: return
        val asset = (0 until assets.length()).map { assets.getJSONObject(it) }.firstOrNull { it.optString("name") == name }
            ?: return
        val file = File(dir, "$tag-$name")
        val size = asset.optLong("size")
        if (!(file.exists() && file.length() == size)) {
            // недокачанный кусок этого же файла оставляем: докачаем с места обрыва
            dir.listFiles()?.filter { it != file && it.name != file.name + ".part" }?.forEach { it.delete() }
            download(asset.getString("browser_download_url"), file, size)
        }
        // Обновление на пару секунд выключает VPN: ждём, пока экран погаснет
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        while (power.isInteractive) delay(60 * 1000L)
        Log.i(TAG, "installing $tag over $current")
        install(context, file, tag)
    }

    fun install(context: Context, file: File, version: String) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(context.packageName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
            }
        }
        val id = installer.createSession(params)
        installer.openSession(id).use { session ->
            file.inputStream().use { input ->
                session.openWrite("sonar.apk", 0, file.length()).use { out ->
                    input.copyTo(out)
                    session.fsync(out)
                }
            }
            val status = Intent(context, SonarInstallReceiver::class.java)
                .setAction(ACTION_STATUS)
                .putExtra("version", version)
            // MUTABLE: система дописывает в этот Intent итог установки
            val mutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or mutable
            session.commit(PendingIntent.getBroadcast(context, id, status, flags).intentSender)
        }
    }

    /** Система просит подтвердить: окно Sonar открыто — показываем сразу, иначе уведомление. */
    internal fun askToConfirm(context: Context, confirm: Intent, version: String) {
        confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (foreground) {
            runCatching { context.startActivity(confirm) }.onSuccess { return }
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Обновления Sonar", NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
        val open = PendingIntent.getActivity(
            context, NOTIFICATION_ID, confirm,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        manager.notify(
            NOTIFICATION_ID,
            NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_logo)
                .setContentTitle("Sonar $version готов")
                .setContentText("Нажмите, чтобы обновить. VPN включится сам.")
                .setContentIntent(open)
                .setAutoCancel(true)
                .build(),
        )
    }

    private fun assetName(): String = when (Build.SUPPORTED_ABIS.firstOrNull()) {
        "arm64-v8a" -> "Sonar-Android-arm64.apk"
        "armeabi-v7a" -> "Sonar-Android-arm7.apk"
        "x86_64" -> "Sonar-Android-x86_64.apk"
        else -> "Sonar-Android-universal.apk"
    }

    private fun newer(latest: String, current: String): Boolean {
        fun parts(v: String) = v.substringBefore('+').split('.').map { it.toIntOrNull() ?: 0 }
        val a = parts(latest)
        val b = parts(current)
        for (i in 0 until maxOf(a.size, b.size)) {
            val x = a.getOrElse(i) { 0 }
            val y = b.getOrElse(i) { 0 }
            if (x != y) return x > y
        }
        return false
    }

    private fun open(url: String) = (URL(url).openConnection() as HttpURLConnection).apply {
        connectTimeout = 15_000
        readTimeout = 60_000
        setRequestProperty("Accept", "application/vnd.github+json")
        setRequestProperty("User-Agent", "Sonar-Android")
    }

    private fun fetch(url: String): String {
        val c = open(url)
        try {
            if (c.responseCode != 200) throw IllegalStateException("GitHub ответил ${c.responseCode}")
            return c.inputStream.bufferedReader().use { it.readText() }
        } finally {
            c.disconnect()
        }
    }

    /** Три попытки, каждая докачивает с места обрыва. */
    private suspend fun download(url: String, target: File, size: Long) {
        val part = File(target.path + ".part")
        var last: Exception? = null
        for (attempt in 1..3) {
            try {
                val have = if (part.exists()) part.length() else 0L
                val c = open(url)
                if (have in 1 until size) c.setRequestProperty("Range", "bytes=$have-")
                try {
                    val code = c.responseCode
                    if (code != 200 && code != 206) throw IllegalStateException("файл не скачался: $code")
                    val append = code == 206 && have > 0
                    c.inputStream.use { input -> FileOutputStream(part, append).use { input.copyTo(it) } }
                } finally {
                    c.disconnect()
                }
                if (size > 0 && part.length() != size) throw IllegalStateException("файл скачался не целиком")
                if (!part.renameTo(target)) throw IllegalStateException("не удалось сохранить файл")
                return
            } catch (e: Exception) {
                last = e
                Log.w(TAG, "download attempt $attempt failed", e)
                delay(5_000L * attempt)
            }
        }
        throw last ?: IllegalStateException("файл не скачался")
    }
}

/** Итог установки от системы. */
class SonarInstallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val version = intent.getStringExtra("version") ?: ""
        when (val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirm = IntentCompat.getParcelableExtra(intent, Intent.EXTRA_INTENT, Intent::class.java) ?: return
                SonarUpdate.askToConfirm(context, confirm, version)
            }
            PackageInstaller.STATUS_SUCCESS -> Log.i("A/SonarUpdate", "updated to $version")
            else -> Log.w(
                "A/SonarUpdate",
                "install failed: $status ${intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)}",
            )
        }
    }
}

/** Кнопка «Обновить» во Flutter ставит скачанный файл тем же установщиком. */
class SonarUpdatePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "app.sonar/update")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "install" -> {
                val path = call.argument<String>("path")
                val version = call.argument<String>("version") ?: ""
                if (path == null) return result.error("path", "нет файла", null)
                Thread {
                    runCatching { SonarUpdate.install(context, File(path), version) }
                        .onSuccess { android.os.Handler(android.os.Looper.getMainLooper()).post { result.success(true) } }
                        .onFailure { e ->
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                result.error("install", e.message, null)
                            }
                        }
                }.start()
            }
            else -> result.notImplemented()
        }
    }
}
