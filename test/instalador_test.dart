import 'dart:io';

import 'package:fica_sobrio/data/instalador.dart';
import 'package:flutter_test/flutter_test.dart';

/// Servidor local que imita o GitHub: redireciona e entrega um "APK" falso.
Future<HttpServer> _servidor(List<int> conteudo, {bool cortar = false}) async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  s.listen((req) async {
    if (req.uri.path == '/releases/download/v1.0.9/FicaSobrio.apk') {
      req.response
        ..statusCode = 302
        ..headers.set('location', '/objeto/apk');
      await req.response.close();
      return;
    }
    if (cortar) {
      // simula a internet caindo no meio: anuncia o tamanho todo e manda só metade
      final sock = await req.response.detachSocket(writeHeaders: false);
      sock.write('HTTP/1.1 200 OK\r\nContent-Length: ${conteudo.length}\r\n\r\n');
      sock.add(conteudo.sublist(0, conteudo.length ~/ 2));
      await sock.flush();
      await sock.close();
      return;
    }
    req.response.headers.contentLength = conteudo.length;
    req.response.add(conteudo);
    await req.response.close();
  });
  return s;
}

void main() {
  final apkFalso = [0x50, 0x4B, ...List<int>.generate(300000, (i) => i % 251)];

  test('baixa seguindo o redirecionamento, mostra progresso e sobrescreve o mesmo arquivo', () async {
    final s = await _servidor(apkFalso);
    final dir = await Directory.systemTemp.createTemp('fica_');
    final url = 'http://127.0.0.1:${s.port}/releases/download/v1.0.9/FicaSobrio.apk';
    final progressos = <double>[];

    final f1 = await Instalador.baixarPara(dir, url, 9, progressos.add);
    expect(await f1.readAsBytes(), apkFalso);
    expect(progressos.last, 1.0);
    expect(progressos.length, greaterThan(1));

    // segunda vez: mesmo arquivo, sem acumular APKs
    await Instalador.baixarPara(dir, url, 10, (_) {});
    final arquivos = dir.listSync().map((e) => e.uri.pathSegments.last).toSet();
    expect(arquivos, {'atualizacao.apk', 'versao.txt'});
    expect(await File('${dir.path}/versao.txt').readAsString(), '10');

    await s.close(force: true);
    await dir.delete(recursive: true);
  });

  test('download incompleto dá erro e não deixa APK pela metade', () async {
    final s = await _servidor(apkFalso, cortar: true);
    final dir = await Directory.systemTemp.createTemp('fica_');
    final url = 'http://127.0.0.1:${s.port}/objeto/apk';
    await expectLater(Instalador.baixarPara(dir, url, 9, (_) {}), throwsA(anything));
    expect(File('${dir.path}/atualizacao.apk').existsSync(), isFalse);
    await s.close(force: true);
    await dir.delete(recursive: true);
  });

  test('recusa arquivo que não é APK', () async {
    final s = await _servidor(List<int>.filled(1000, 60)); // "<<<<": página HTML, por exemplo
    final dir = await Directory.systemTemp.createTemp('fica_');
    await expectLater(
        Instalador.baixarPara(dir, 'http://127.0.0.1:${s.port}/objeto/apk', 9, (_) {}), throwsA(anything));
    expect(File('${dir.path}/atualizacao.apk').existsSync(), isFalse);
    await s.close(force: true);
    await dir.delete(recursive: true);
  });
}
