import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../data/repo.dart';
import '../logic/progresso.dart';
import 'compartilhar.dart';

const _lado = 1080.0;

/// Desenha o cartão quadrado "Estou sóbrio há X dias" e devolve o PNG.
Future<Uint8List> gerarCartaoSobriedade({
  required Duration tempo,
  double economia = 0,
  String? conquistaEmoji,
  String? conquistaTitulo,
  String? codigoConvite,
}) async {
  final gravador = ui.PictureRecorder();
  final c = Canvas(gravador, const Rect.fromLTWH(0, 0, _lado, _lado));
  const area = Rect.fromLTWH(0, 0, _lado, _lado);
  final dias = tempo.inDays;
  final (numero, unidade) = tempoPrincipal(tempo);

  // fundo em degradê verde + luzes
  c.drawRect(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF062A1F), Color(0xFF0B3D2E), Color(0xFF15724F), Color(0xFF1FAF7A)],
          stops: [0, 0.35, 0.75, 1],
        ).createShader(area));
  for (final (x, y, r, a) in const [(900.0, 160.0, 320.0, 0.10), (120.0, 980.0, 360.0, 0.08), (540.0, 520.0, 460.0, 0.06)]) {
    c.drawCircle(Offset(x, y), r, Paint()..color = Colors.white.withValues(alpha: a));
  }
  // confete dourado
  final rnd = Random(dias);
  const cores = [Color(0xFFFFC23D), Color(0xFFFF8FB1), Color(0xFF5FD3E8), Color(0xFFFFFFFF)];
  for (var k = 0; k < 46; k++) {
    final p = Offset(rnd.nextDouble() * _lado, rnd.nextDouble() * _lado);
    if ((p - const Offset(540, 520)).distance < 330) continue; // não cobre o número
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(rnd.nextDouble() * pi);
    c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -4, 18, 8), const Radius.circular(3)),
        Paint()..color = cores[k % cores.length].withValues(alpha: 0.75));
    c.restore();
  }

  // logo
  try {
    final dados = await rootBundle.load('assets/icon/icon.png');
    final codec = await ui.instantiateImageCodec(dados.buffer.asUint8List(), targetWidth: 120, targetHeight: 120);
    final img = (await codec.getNextFrame()).image;
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(70, 64, 120, 120), const Radius.circular(30)));
    c.drawImage(img, const Offset(70, 64), Paint());
    c.restore();
  } catch (_) {}
  _texto(c, appNome, const Offset(214, 92), 52, Colors.white, peso: FontWeight.w900, centro: false);
  _texto(c, appSlogan, const Offset(214, 152), 30, const Color(0xFFFFC23D), centro: false);

  // número
  _texto(c, 'Estou sóbrio há', const Offset(540, 300), 60, Colors.white.withValues(alpha: 0.9), peso: FontWeight.w700);
  final tamNumero = numero >= 1000 ? 250.0 : (numero >= 100 ? 300.0 : 340.0);
  _texto(c, '$numero', const Offset(540, 500), tamNumero, Colors.white,
      peso: FontWeight.w900, sombra: const Color(0xFFFFC23D));
  _texto(c, unidade.toUpperCase(), const Offset(540, 690), 96, const Color(0xFFFFC23D), peso: FontWeight.w900, espaco: 10);

  // frase do marco ou conquista
  final faixa = conquistaTitulo != null ? '${conquistaEmoji ?? '🏅'} Conquista: $conquistaTitulo' : fraseDoMarco(dias);
  final fundo = RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(540, 800), width: 900, height: 96), const Radius.circular(48));
  c.drawRRect(fundo, Paint()..color = Colors.black.withValues(alpha: 0.28));
  _texto(c, faixa, const Offset(540, 800), 44, Colors.white, peso: FontWeight.w800, largura: 860);

  if (economia >= 1) {
    _texto(c, '💰 ${dinheiro(economia)} economizados', const Offset(540, 900), 42, const Color(0xFFB9F6CA), peso: FontWeight.w800);
  }
  // rodapé
  c.drawRect(const Rect.fromLTWH(0, 975, _lado, 105), Paint()..color = Colors.black.withValues(alpha: 0.3));
  final convite = (codigoConvite == null || codigoConvite.isEmpty) ? '' : '   ·   Convite: $codigoConvite';
  _texto(c, '#FicaSobrio   ·   App grátis$convite', const Offset(540, 1027), 34, Colors.white70, peso: FontWeight.w700);

  final imagem = await gravador.endRecording().toImage(_lado.toInt(), _lado.toInt());
  final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

void _texto(Canvas c, String s, Offset pos, double tam, Color cor,
    {FontWeight peso = FontWeight.w500, bool centro = true, Color? sombra, double espaco = 0, double largura = 1000}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontSize: tam,
        fontWeight: peso,
        color: cor,
        letterSpacing: espaco,
        height: 1.0,
        shadows: [
          if (sombra != null) Shadow(color: sombra.withValues(alpha: 0.55), blurRadius: 40),
          Shadow(color: Colors.black.withValues(alpha: 0.35), offset: const Offset(0, 6), blurRadius: 14),
        ],
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: largura);
  tp.paint(c, centro ? pos - Offset(tp.width / 2, tp.height / 2) : pos - Offset(0, tp.height / 2));
}

/// Compartilha o cartão com a imagem + texto (WhatsApp, Instagram etc.).
Future<void> compartilharConquistaDeTempo({
  required Duration tempo,
  double economia = 0,
  String? conquistaEmoji,
  String? conquistaTitulo,
  String? codigoConvite,
  String origem = '',
}) async {
  final (n, unidade) = tempoPrincipal(tempo);
  final mensagem = conquistaTitulo != null
      ? 'Desbloqueei "$conquistaTitulo" ${conquistaEmoji ?? ''} no Fica Sóbrio: estou sóbrio há $n $unidade! 💪'
      : 'Estou sóbrio há $n $unidade${economia >= 1 ? ' e já economizei ${dinheiro(economia)}' : ''}! 💪';
  final texto = '$mensagem\n\n#FicaSobrio — $appSlogan${blocoConvite(codigoConvite)}\n\nBaixe grátis: $linkDownload';
  await Repo.log('compartilhou', {'origem': origem, 'imagem': true});
  try {
    if (kIsWeb) throw UnsupportedError('web');
    final png = await gerarCartaoSobriedade(
      tempo: tempo,
      economia: economia,
      conquistaEmoji: conquistaEmoji,
      conquistaTitulo: conquistaTitulo,
      codigoConvite: codigoConvite,
    );
    final dir = await getTemporaryDirectory();
    final arquivo = File('${dir.path}/fica-sobrio-$n-$unidade.png');
    await arquivo.writeAsBytes(png, flush: true);
    await Share.shareXFiles([XFile(arquivo.path, mimeType: 'image/png')], text: texto, subject: appNome);
  } catch (_) {
    await Share.share(texto, subject: appNome); // se a imagem falhar, manda só o texto
  }
}
