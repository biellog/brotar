import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Resultado de uma tentativa de instalação.
enum ResultadoInstalacao { instalando, precisaPermissao }

/// Baixa a atualização para a pasta interna do app e abre o instalador do Android.
///
/// O APK fica sempre no MESMO arquivo (cache/atualizacoes/atualizacao.apk):
/// cada download substitui o anterior e a pasta é limpa depois de atualizar,
/// então o celular não acumula APKs na pasta Downloads.
class Instalador {
  static const _canal = MethodChannel('fica_sobrio/instalador');

  static bool get suportado => !kIsWeb && Platform.isAndroid;

  static Future<Directory> _pasta() async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/atualizacoes');
    return dir.create(recursive: true);
  }

  /// Arquivo já baixado e completo para esta versão (ou null).
  static Future<File?> jaBaixado(int versaoCodigo) async {
    if (!suportado) return null;
    final dir = await _pasta();
    final marca = File('${dir.path}/versao.txt');
    final apk = File('${dir.path}/atualizacao.apk');
    if (await apk.exists() && await marca.exists() &&
        (await marca.readAsString()).trim() == '$versaoCodigo') {
      return apk;
    }
    return null;
  }

  /// Baixa a atualização mostrando o progresso (0.0 a 1.0).
  static Future<File> baixar(
    String url,
    int versaoCodigo,
    void Function(double progresso) aoProgredir,
  ) async {
    final dir = await _pasta();
    return baixarPara(dir, url, versaoCodigo, aoProgredir);
  }

  /// Igual a [baixar], mas numa pasta escolhida (usado nos testes).
  static Future<File> baixarPara(
    Directory dir,
    String url,
    int versaoCodigo,
    void Function(double progresso) aoProgredir, {
    http.Client? cliente,
  }) async {
    final apk = File('${dir.path}/atualizacao.apk');
    final parcial = File('${dir.path}/atualizacao.apk.parcial');
    final marca = File('${dir.path}/versao.txt');
    for (final f in [apk, parcial, marca]) {
      if (await f.exists()) await f.delete();
    }

    final c = cliente ?? http.Client();
    try {
      final resp = await c.send(http.Request('GET', Uri.parse(url)));
      if (resp.statusCode != 200) {
        throw HttpException('Servidor respondeu ${resp.statusCode}');
      }
      final total = resp.contentLength ?? 0;
      var recebido = 0;
      final saida = parcial.openWrite();
      try {
        await for (final pedaco in resp.stream) {
          saida.add(pedaco);
          recebido += pedaco.length;
          if (total > 0) aoProgredir(recebido / total);
        }
      } finally {
        await saida.close();
      }
      if (total > 0 && recebido != total) {
        throw const HttpException('Download incompleto. Verifique a internet e tente de novo.');
      }
      // confere se é mesmo um APK (arquivo ZIP começa com "PK") antes de aceitar
      final cabecalho = await parcial.openRead(0, 2).first;
      if (cabecalho.length < 2 || cabecalho[0] != 0x50 || cabecalho[1] != 0x4B) {
        await parcial.delete();
        throw const HttpException('O arquivo baixado não é um APK válido.');
      }
      await parcial.rename(apk.path);
      await marca.writeAsString('$versaoCodigo');
      aoProgredir(1);
      return apk;
    } finally {
      if (cliente == null) c.close();
    }
  }

  /// O Android já autorizou o app a instalar atualizações?
  static Future<bool> podeInstalar() async =>
      await _canal.invokeMethod<bool>('podeInstalar') ?? false;

  /// Abre o instalador do Android. Se faltar autorização, abre a tela de permissão.
  static Future<ResultadoInstalacao> instalar(File apk) async {
    if (!await podeInstalar()) {
      await _canal.invokeMethod('abrirPermissao');
      return ResultadoInstalacao.precisaPermissao;
    }
    await _canal.invokeMethod('instalar', {'caminho': apk.path});
    return ResultadoInstalacao.instalando;
  }

  /// Apaga APKs baixados (chamado quando o app já está na versão mais nova).
  static Future<void> limpar() async {
    if (!suportado) return;
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/atualizacoes');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
