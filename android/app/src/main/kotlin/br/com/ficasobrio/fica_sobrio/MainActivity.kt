package br.com.ficasobrio.fica_sobrio

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Instalador de atualizações: o app baixa o APK na própria pasta interna (cache)
 * e pede ao Android para instalar por cima, sem passar pela pasta Downloads.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fica_sobrio/instalador")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "podeInstalar" -> result.success(podeInstalar())
                    "abrirPermissao" -> {
                        abrirPermissao()
                        result.success(null)
                    }
                    "instalar" -> {
                        val caminho = call.argument<String>("caminho")
                        if (caminho == null) {
                            result.error("SEM_ARQUIVO", "Caminho do APK não informado", null)
                        } else {
                            try {
                                instalar(File(caminho))
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("FALHA_INSTALAR", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Android 8+ exige que a pessoa autorize o app a instalar atualizações. */
    private fun podeInstalar(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }

    private fun abrirPermissao() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            )
            startActivity(intent)
        }
    }

    private fun instalar(arquivo: File) {
        val uri = FileProvider.getUriForFile(this, "$packageName.instalador", arquivo)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
