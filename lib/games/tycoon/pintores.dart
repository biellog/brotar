// Visual do Império do Suco: fachada que evolui, efeitos, Hora do Rush e componentes.
import 'dart:math';

import 'package:flutter/material.dart';

import '../comum.dart';

const _ouro = Color(0xFFFFC23D);
const _laranja = Color(0xFFFF9F1C);

const coresConfete = [
  Color(0xFFFFC23D), Color(0xFFFF4D8D), Color(0xFF4CC9F0), Color(0xFF7BD389), Color(0xFFB98CF0), Color(0xFFFF8A5B),
];

// =====================================================================
// Modelos simples de animação
// =====================================================================
class ClienteCalcada {
  final String emoji;
  final bool vip;
  final double vel, fase;
  double x = -0.12;
  double espera = 0.7;
  bool comSuco = false;
  ClienteCalcada(this.emoji, this.vel, this.fase, {this.vip = false});

  void andar(double dt, {required bool vipAindaAqui}) {
    final parado = x >= 0.5 && espera > 0 && !(vip && !vipAindaAqui);
    if (parado) {
      espera -= dt;
      if (espera <= 0) comSuco = true;
    } else {
      x += vel * dt;
    }
  }
}

class Confete {
  Offset pos, vel;
  final Color cor;
  final double vidaMax;
  double vida, giro;
  Confete(this.pos, this.vel, this.cor, this.vidaMax, this.giro) : vida = vidaMax;

  void passo(double dt) {
    vel = Offset(vel.dx * (1 - dt * 0.8), vel.dy + 420 * dt);
    pos += vel * dt;
    giro += dt * 8;
    vida -= dt;
  }
}

// =====================================================================
// Fachada: evolui com o Nível do Império
// =====================================================================
class PintorFachada extends CustomPainter {
  final List<ClienteCalcada> clientes;
  final double t;
  final PintorEmoji pintor;
  final bool vip, calor, turbo;
  final int nivel; // 0 barraquinha ... 5 shopping
  PintorFachada({
    required this.clientes,
    required this.t,
    required this.pintor,
    required this.vip,
    required this.nivel,
    required this.calor,
    required this.turbo,
  });

  void _texto(Canvas c, String s, Offset centro, double tam, Color cor, {double brilho = 0}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: cor,
          fontSize: tam,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          shadows: [
            if (brilho > 0) Shadow(color: cor.withValues(alpha: brilho), blurRadius: 12),
            const Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 2),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, centro - Offset(tp.width / 2, tp.height / 2));
  }

  void _toldo(Canvas c, Rect r, int listras) {
    final w = r.width / listras;
    for (var k = 0; k < listras; k++) {
      final cor = k.isEven ? const Color(0xFFFF6B35) : Colors.white;
      final faixa = Rect.fromLTWH(r.left + k * w, r.top, w + 0.5, r.height);
      c.drawRect(faixa, Paint()..color = cor);
      c.drawArc(Rect.fromLTWH(faixa.left, faixa.bottom - w / 2, w, w), 0, pi, true, Paint()..color = cor);
    }
  }

  void _janelas(Canvas c, Rect area, int cols, int lins, {double piscar = 0}) {
    final gw = area.width / cols, gh = area.height / lins;
    for (var i = 0; i < cols; i++) {
      for (var j = 0; j < lins; j++) {
        final acesa = piscar == 0 || sin(t * 0.7 + i * 3.1 + j * 1.7) > -0.6;
        final r = Rect.fromLTWH(area.left + i * gw + gw * 0.15, area.top + j * gh + gh * 0.15, gw * 0.7, gh * 0.7);
        c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)),
            Paint()..color = acesa ? const Color(0xFFFFF3B0) : const Color(0xFF5B7B9A));
      }
    }
  }

  @override
  void paint(Canvas c, Size s) {
    final chao = s.height * 0.82;
    // céu
    c.drawRect(Offset.zero & s,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: calor
                ? const [Color(0xFFFF7B39), Color(0xFFFFD27A)]
                : const [Color(0xFF3FA9F5), Color(0xFFBDE7FF)],
          ).createShader(Offset.zero & s));
    // sol
    final sol = Offset(s.width * 0.88, s.height * 0.22);
    c.drawCircle(sol, calor ? 26 : 18,
        Paint()
          ..color = const Color(0xFFFFE066)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    c.drawCircle(sol, calor ? 18 : 13, Paint()..color = const Color(0xFFFFF4B0));
    // nuvens
    final nuvem = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (var k = 0; k < 3; k++) {
      final x = ((t * (6 + k * 3) + k * 170) % (s.width + 120)) - 60;
      final y = s.height * (0.12 + k * 0.1);
      for (final (dx, dy, r) in const [(0.0, 0.0, 12.0), (14.0, -5.0, 15.0), (30.0, 0.0, 11.0)]) {
        c.drawCircle(Offset(x + dx, y + dy), r, nuvem);
      }
    }
    // prédios ao fundo (cidade)
    final fundo = Paint()..color = const Color(0xFF7FB3D5).withValues(alpha: 0.55);
    for (var k = 0; k < 9; k++) {
      final w = s.width / 9;
      final h = s.height * (0.25 + (k * 37 % 5) * 0.06);
      c.drawRect(Rect.fromLTWH(k * w, chao - h, w * 0.85, h), fundo);
    }
    // calçada e rua
    c.drawRect(Rect.fromLTWH(0, chao, s.width, s.height - chao), Paint()..color = const Color(0xFFCFCFCF));
    c.drawRect(Rect.fromLTWH(0, chao, s.width, 3), Paint()..color = const Color(0xFF9E9E9E));

    switch (nivel) {
      case 0:
        _barraquinha(c, s, chao);
      case 1:
        _quiosque(c, s, chao);
      case 2:
        _lojinha(c, s, chao);
      case 3:
        _lojaGrande(c, s, chao);
      case 4:
        _megaloja(c, s, chao);
      default:
        _shopping(c, s, chao);
    }

    if (turbo) {
      for (var k = 0; k < 6; k++) {
        final a = t * 3 + k;
        pintor.desenhar(c, '✨', 14, Offset(s.width * (0.5 + 0.36 * cos(a)), s.height * (0.4 + 0.25 * sin(a * 1.3))));
      }
    }
    if (calor) {
      // ar "tremendo" de calor
      final onda = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.25);
      for (var k = 0; k < 5; k++) {
        final caminho = Path();
        final y0 = chao - 8 - k * 9.0;
        for (var x = 0.0; x <= s.width; x += 8) {
          final y = y0 + sin(x / 18 + t * 6 + k) * 2;
          x == 0 ? caminho.moveTo(x, y) : caminho.lineTo(x, y);
        }
        c.drawPath(caminho, onda);
      }
    }
    // clientes
    for (final cl in clientes) {
      final y = chao + 4 - 2.5 * sin(t * 12 + cl.fase).abs();
      final pos = Offset(cl.x * s.width, y);
      c.drawOval(Rect.fromCenter(center: Offset(pos.dx, chao + 13), width: 20, height: 5),
          Paint()..color = Colors.black.withValues(alpha: 0.2));
      if (cl.vip) {
        c.drawCircle(pos, 20 + 3 * sin(t * 6),
            Paint()
              ..color = _ouro.withValues(alpha: 0.55)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      }
      pintor.desenhar(c, cl.emoji, cl.vip ? 30 : 24, pos);
      if (cl.comSuco) pintor.desenhar(c, '🥤', 13, pos + const Offset(12, 2));
    }
    if (vip) {
      final centro = Offset(s.width / 2, 14 + 2 * sin(t * 5));
      final fundo = RRect.fromRectAndRadius(Rect.fromCenter(center: centro, width: 230, height: 22), const Radius.circular(11));
      c.drawRRect(fundo, Paint()..color = const Color(0xE6FF4D8D));
      c.drawRRect(fundo,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = _ouro);
      _texto(c, '🌟 TOQUE NO CLIENTE VIP! 🌟', centro, 12, Colors.white);
    }
  }

  void _barraquinha(Canvas c, Size s, double chao) {
    final cx = s.width / 2;
    final corpo = Rect.fromCenter(center: Offset(cx, chao - 22), width: 90, height: 34);
    c.drawRRect(RRect.fromRectAndRadius(corpo, const Radius.circular(6)), Paint()..color = const Color(0xFF29B6F6));
    c.drawRect(Rect.fromLTWH(corpo.left, corpo.top, corpo.width, 6), Paint()..color = Colors.white);
    for (final dx in [-28.0, 28.0]) {
      c.drawCircle(Offset(cx + dx, chao - 3), 7, Paint()..color = const Color(0xFF424242));
      c.drawCircle(Offset(cx + dx, chao - 3), 3, Paint()..color = const Color(0xFFBDBDBD));
    }
    c.drawRect(Rect.fromLTWH(cx - 1.5, chao - 82, 3, 48), Paint()..color = const Color(0xFF8D6E63));
    final guarda = Rect.fromCenter(center: Offset(cx, chao - 80), width: 120, height: 50);
    for (var k = 0; k < 8; k++) {
      c.drawArc(guarda, pi + k * pi / 8, pi / 8, true,
          Paint()..color = k.isEven ? const Color(0xFFFF6B35) : Colors.white);
    }
    _texto(c, 'SUCOS', Offset(cx, chao - 20), 12, const Color(0xFF0D47A1));
    pintor.desenhar(c, '🍋', 14, Offset(cx - 30, corpo.top - 4));
  }

  void _quiosque(Canvas c, Size s, double chao) {
    final cx = s.width / 2;
    final corpo = Rect.fromLTWH(cx - 70, chao - 62, 140, 62);
    c.drawRect(corpo, Paint()..color = const Color(0xFFFFE0B2));
    final telhado = Path()
      ..moveTo(corpo.left - 14, corpo.top)
      ..lineTo(cx, corpo.top - 30)
      ..lineTo(corpo.right + 14, corpo.top)
      ..close();
    c.drawPath(telhado, Paint()..color = const Color(0xFFD84315));
    final janela = Rect.fromLTWH(corpo.left + 14, corpo.top + 12, corpo.width - 28, 24);
    c.drawRect(janela, Paint()..color = const Color(0xFF5D4037));
    _toldo(c, Rect.fromLTWH(janela.left, janela.top, janela.width, 8), 8);
    c.drawRect(Rect.fromLTWH(corpo.left, corpo.bottom - 22, corpo.width, 22), Paint()..color = const Color(0xFF8D6E63));
    _texto(c, 'QUIOSQUE DO SUCO', Offset(cx, corpo.top - 9), 9, Colors.white);
    for (var k = 0; k < 4; k++) {
      pintor.desenhar(c, const ['🍋', '🍊', '🍓', '🥥'][k], 13, Offset(janela.left + 18 + k * 26, corpo.bottom - 26));
    }
  }

  void _lojinha(Canvas c, Size s, double chao) {
    final loja = Rect.fromLTWH(s.width * 0.2, chao - s.height * 0.66, s.width * 0.6, s.height * 0.66);
    c.drawRect(loja, Paint()..color = const Color(0xFFFFE0B2));
    _toldo(c, Rect.fromLTWH(loja.left, loja.top, loja.width, s.height * 0.16), 10);
    _texto(c, '🧃 IMPÉRIO DO SUCO', Offset(s.width / 2, loja.top + s.height * 0.32), 12, const Color(0xFF5D4037));
    final balcao = Rect.fromLTWH(loja.left + 8, chao - s.height * 0.18, loja.width - 16, s.height * 0.18);
    c.drawRRect(RRect.fromRectAndRadius(balcao, const Radius.circular(4)), Paint()..color = const Color(0xFF8D6E63));
    for (var k = 0; k < 5; k++) {
      pintor.desenhar(c, const ['🍋', '🍊', '🍓', '🥥', '🍉'][k], 14,
          Offset(balcao.left + balcao.width * (0.12 + k * 0.19), balcao.top - 6));
    }
  }

  void _lojaGrande(Canvas c, Size s, double chao) {
    final loja = Rect.fromLTWH(s.width * 0.14, chao - s.height * 0.78, s.width * 0.72, s.height * 0.78);
    c.drawRect(loja, Paint()..color = const Color(0xFFFFCC80));
    c.drawRect(Rect.fromLTWH(loja.left, loja.top, loja.width, 6), Paint()..color = const Color(0xFFE65100));
    _janelas(c, Rect.fromLTWH(loja.left + 8, loja.top + 26, loja.width - 16, s.height * 0.18), 6, 1);
    final neon = 0.5 + 0.5 * sin(t * 4);
    _texto(c, 'IMPÉRIO DO SUCO', Offset(s.width / 2, loja.top + 15), 13, const Color(0xFFFF4D8D), brilho: 0.4 + 0.6 * neon);
    _toldo(c, Rect.fromLTWH(loja.left, chao - s.height * 0.36, loja.width, s.height * 0.1), 12);
    final vitrine = Rect.fromLTWH(loja.left + 10, chao - s.height * 0.24, loja.width - 20, s.height * 0.24);
    c.drawRect(vitrine, Paint()..color = const Color(0xFF8D6E63));
    for (var k = 0; k < 7; k++) {
      pintor.desenhar(c, const ['🍋', '🍊', '🍓', '🥥', '🥭', '🍇', '🍉'][k], 14,
          Offset(vitrine.left + vitrine.width * (0.08 + k * 0.14), vitrine.top + 8));
    }
  }

  void _megaloja(Canvas c, Size s, double chao) {
    final loja = Rect.fromLTWH(s.width * 0.07, chao - s.height * 0.8, s.width * 0.86, s.height * 0.8);
    c.drawRect(loja,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF90CAF9), Color(0xFF1E88E5)],
          ).createShader(loja));
    for (var k = 1; k < 8; k++) {
      final x = loja.left + loja.width * k / 8;
      c.drawLine(Offset(x, loja.top + 22), Offset(x, chao), Paint()..color = Colors.white24);
    }
    // letreiro de LED
    final placa = Rect.fromLTWH(loja.left + 16, loja.top + 3, loja.width - 32, 18);
    c.drawRRect(RRect.fromRectAndRadius(placa, const Radius.circular(4)), Paint()..color = const Color(0xFF1A1A1A));
    c.save();
    c.clipRect(placa);
    final desloc = (t * 40) % (placa.width + 200);
    _texto(c, '★ MEGALOJA IMPÉRIO DO SUCO ★', Offset(placa.right + 100 - desloc, placa.center.dy), 11, _ouro, brilho: 0.8);
    c.restore();
    c.drawRect(Rect.fromLTWH(loja.left, chao - 26, loja.width, 26), Paint()..color = const Color(0xFF6D4C41));
    for (final x in [s.width * 0.04, s.width * 0.96]) {
      pintor.desenhar(c, '🌴', 40, Offset(x, chao - 22));
    }
  }

  void _shopping(Canvas c, Size s, double chao) {
    // holofotes girando
    for (var k = 0; k < 2; k++) {
      final base = Offset(s.width * (k == 0 ? 0.2 : 0.8), chao);
      final a = -pi / 2 + 0.5 * sin(t * 0.8 + k * 2);
      final ponta = base + Offset(cos(a), sin(a)) * s.height * 1.2;
      c.drawPath(
        Path()
          ..moveTo(base.dx, base.dy)
          ..lineTo(ponta.dx - 22, ponta.dy)
          ..lineTo(ponta.dx + 22, ponta.dy)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );
    }
    final torre = Rect.fromLTWH(s.width * 0.3, 18, s.width * 0.4, chao - 18);
    c.drawRect(torre,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF37474F), Color(0xFF263238)],
          ).createShader(torre));
    _janelas(c, Rect.fromLTWH(torre.left + 4, torre.top + 18, torre.width - 8, torre.height - 40), 6, 5, piscar: 1);
    final alas = [Rect.fromLTWH(s.width * 0.05, chao - 50, s.width * 0.27, 50), Rect.fromLTWH(s.width * 0.68, chao - 50, s.width * 0.27, 50)];
    for (final a in alas) {
      c.drawRect(a, Paint()..color = const Color(0xFF455A64));
      _janelas(c, Rect.fromLTWH(a.left + 4, a.top + 6, a.width - 8, a.height - 14), 4, 2, piscar: 1);
    }
    final neon = 0.5 + 0.5 * sin(t * 3);
    _texto(c, 'SHOPPING DO SUCO', Offset(s.width / 2, 11), 13, _ouro, brilho: 0.5 + 0.5 * neon);
    pintor.desenhar(c, '🧃', 22, Offset(s.width / 2, torre.top + 8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// =====================================================================
// Efeitos por cima da tela: moedas, confete e textos
// =====================================================================
class PintorEfeitos extends CustomPainter {
  final List<(Offset, Offset, double)> moedas;
  final List<Confete> confetes;
  final List<(Offset, String, Color, double, double)> textos;
  final PintorEmoji pintor;
  PintorEfeitos({required this.moedas, required this.confetes, required this.textos, required this.pintor});

  static void moeda(Canvas c, Offset p, double r) {
    c.drawCircle(p + const Offset(1, 2), r, Paint()..color = Colors.black26);
    c.drawCircle(p, r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [Color(0xFFFFF1A8), Color(0xFFFFC23D), Color(0xFFD48806)],
          ).createShader(Rect.fromCircle(center: p, radius: r)));
    c.drawCircle(p, r * 0.68,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFFB36B00));
  }

  @override
  void paint(Canvas c, Size s) {
    for (final (de, para, t) in moedas) {
      final controle = Offset((de.dx + para.dx) / 2 + 40, min(de.dy, para.dy) - 90);
      final u = Curves.easeIn.transform(t.clamp(0.0, 1.0));
      final p = Offset(
        (1 - u) * (1 - u) * de.dx + 2 * (1 - u) * u * controle.dx + u * u * para.dx,
        (1 - u) * (1 - u) * de.dy + 2 * (1 - u) * u * controle.dy + u * u * para.dy,
      );
      moeda(c, p, 9 - 3 * u);
    }
    for (final k in confetes) {
      final a = (k.vida / k.vidaMax).clamp(0.0, 1.0);
      c.save();
      c.translate(k.pos.dx, k.pos.dy);
      c.rotate(k.giro);
      c.drawRect(Rect.fromCenter(center: Offset.zero, width: 8, height: 4.5 * (0.5 + 0.5 * cos(k.giro * 1.7)).abs() + 1),
          Paint()..color = k.cor.withValues(alpha: a));
      c.restore();
    }
    for (final (pos, texto, cor, tam, vida) in textos) {
      final a = vida.clamp(0.0, 1.0);
      final escala = vida > 0.8 ? 1 + (vida - 0.8) * 2 : 1.0; // "pop" ao aparecer
      final tp = TextPainter(
        text: TextSpan(
          text: texto,
          style: TextStyle(
            fontSize: tam * escala,
            fontWeight: FontWeight.w900,
            color: cor.withValues(alpha: a),
            shadows: [
              Shadow(blurRadius: 6, color: Colors.black.withValues(alpha: 0.8 * a)),
              Shadow(offset: const Offset(1.5, 1.5), color: Colors.black.withValues(alpha: 0.6 * a)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, pos - Offset(tp.width / 2, tp.height / 2 + (1 - vida) * 50));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// =====================================================================
// Hora do Rush
// =====================================================================
class PintorRush extends CustomPainter {
  final List<(Offset, String, bool, double)> clientes;
  final double t, restante, total;
  final int combo;
  final PintorEmoji pintor;
  PintorRush({
    required this.clientes,
    required this.t,
    required this.restante,
    required this.total,
    required this.combo,
    required this.pintor,
  });

  @override
  void paint(Canvas c, Size s) {
    c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(20)),
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFF3A1D5C).withValues(alpha: 0.92), const Color(0xFF12061F).withValues(alpha: 0.96)],
          ).createShader(Offset.zero & s));
    // listras de velocidade
    final listra = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (var k = 0; k < 12; k++) {
      final y = (k * 53 + t * 140) % s.height;
      c.drawRect(Rect.fromLTWH(0, y, s.width, 2), listra);
    }
    // faixa do título + tempo
    final tp = TextPainter(
      text: const TextSpan(
        text: '⚡ HORA DO RUSH! Toque nos clientes ⚡',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: s.width);
    tp.paint(c, Offset((s.width - tp.width) / 2, 8));
    final barra = Rect.fromLTWH(16, 32, s.width - 32, 8);
    c.drawRRect(RRect.fromRectAndRadius(barra, const Radius.circular(4)), Paint()..color = Colors.white12);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(barra.left, barra.top, barra.width * (restante / total), barra.height),
          const Radius.circular(4)),
      Paint()..shader = const LinearGradient(colors: [Color(0xFFFF4D8D), _ouro]).createShader(barra),
    );
    // combo
    if (combo >= 2) {
      final escala = 1 + min(combo, 10) * 0.06 + 0.05 * sin(t * 12);
      final cor = Color.lerp(Colors.white, const Color(0xFFFF4D8D), min(combo, 10) / 10)!;
      final ct = TextPainter(
        text: TextSpan(
          text: 'COMBO x${min(combo, 10)}${combo > 10 ? '+' : ''}',
          style: TextStyle(
            fontSize: 26 * escala,
            fontWeight: FontWeight.w900,
            color: cor,
            shadows: [Shadow(color: cor, blurRadius: 16)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      ct.paint(c, Offset((s.width - ct.width) / 2, 46));
    }
    // clientes
    for (final (pos, emoji, dourado, vida) in clientes) {
      final p = Offset(pos.dx * s.width, pos.dy * s.height);
      final nasce = Curves.easeOutBack.transform((vida / 0.25).clamp(0.0, 1.0));
      final r = 30.0 * nasce;
      if (r <= 1) continue;
      if (dourado) {
        c.drawCircle(p, r + 8 + 3 * sin(t * 10),
            Paint()
              ..color = _ouro.withValues(alpha: 0.6)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      }
      c.drawCircle(p + const Offset(2, 3), r, Paint()..color = Colors.black38);
      c.drawCircle(p, r, Paint()..color = dourado ? const Color(0xFFFFE082) : Colors.white);
      c.drawCircle(p, r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = dourado ? _laranja : const Color(0xFF4CC9F0));
      pintor.desenhar(c, emoji, 30 * nasce, p);
      pintor.desenhar(c, '🥤', 14 * nasce, p + Offset(r * 0.7, -r * 0.7));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// =====================================================================
// Componentes
// =====================================================================
/// Barra de progresso com degradê e um brilho que corre por cima.
class BarraBrilhante extends StatelessWidget {
  final double valor, t, altura;
  final Color cor;
  const BarraBrilhante({super.key, required this.valor, required this.cor, required this.t, this.altura = 22});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: altura,
        width: double.infinity,
        child: CustomPaint(painter: _PintorBarra(valor.clamp(0.0, 1.0), cor, t)),
      );
}

class _PintorBarra extends CustomPainter {
  final double v, t;
  final Color cor;
  _PintorBarra(this.v, this.cor, this.t);

  @override
  void paint(Canvas c, Size s) {
    final raio = Radius.circular(s.height / 2);
    c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, raio), Paint()..color = Colors.black.withValues(alpha: 0.4));
    if (v <= 0) return;
    final cheio = Rect.fromLTWH(0, 0, max(s.height, s.width * v), s.height);
    final rr = RRect.fromRectAndRadius(cheio, raio);
    c.drawRRect(rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(cor, Colors.white, 0.35)!, cor, Color.lerp(cor, Colors.black, 0.2)!],
          ).createShader(cheio));
    c.save();
    c.clipRRect(rr);
    final x = (t * 0.6 % 1.4 - 0.2) * s.width;
    c.drawRect(Rect.fromLTWH(x, 0, s.width * 0.18, s.height),
        Paint()
          ..shader = LinearGradient(colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0),
          ]).createShader(Rect.fromLTWH(x, 0, s.width * 0.18, s.height)));
    c.drawRect(Rect.fromLTWH(0, 0, cheio.width, s.height * 0.35), Paint()..color = Colors.white.withValues(alpha: 0.12));
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _PintorBarra old) => old.v != v || old.t != t || old.cor != cor;
}

/// Botão que "afunda" ao ser tocado.
class _Apertavel extends StatefulWidget {
  final Widget child;
  final VoidCallback? aoTocar;
  const _Apertavel({required this.child, this.aoTocar});

  @override
  State<_Apertavel> createState() => _ApertavelState();
}

class _ApertavelState extends State<_Apertavel> {
  bool _apertado = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: widget.aoTocar == null ? null : (_) => setState(() => _apertado = true),
        onTapCancel: () => setState(() => _apertado = false),
        onTapUp: widget.aoTocar == null
            ? null
            : (_) {
                setState(() => _apertado = false);
                widget.aoTocar!();
              },
        child: AnimatedScale(
          scale: _apertado ? 0.92 : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      );
}

class BotaoCompra extends StatelessWidget {
  final String linha1, linha2;
  final bool ativo;
  final VoidCallback aoTocar;
  const BotaoCompra({super.key, required this.linha1, required this.linha2, required this.ativo, required this.aoTocar});

  @override
  Widget build(BuildContext context) => _Apertavel(
        aoTocar: ativo ? aoTocar : null,
        child: Container(
          width: 92,
          height: 54,
          decoration: BoxDecoration(
            gradient: ativo ? const LinearGradient(colors: [Color(0xFFFFE08A), _ouro, _laranja], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
            color: ativo ? null : Colors.white10,
            borderRadius: BorderRadius.circular(14),
            boxShadow: ativo ? [const BoxShadow(color: Color(0x66FF9F1C), blurRadius: 10, offset: Offset(0, 3))] : null,
          ),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(linha1,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: ativo ? Colors.black : Colors.white38)),
            FittedBox(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(linha2,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ativo ? Colors.black87 : Colors.white38)),
              ),
            ),
          ]),
        ),
      );
}

class BotaoDourado extends StatelessWidget {
  final String texto;
  final bool ativo;
  final VoidCallback aoTocar;
  const BotaoDourado({super.key, required this.texto, required this.aoTocar, this.ativo = true});

  @override
  Widget build(BuildContext context) => _Apertavel(
        aoTocar: ativo ? aoTocar : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: ativo ? const LinearGradient(colors: [Color(0xFFFFE08A), _ouro, _laranja]) : null,
            color: ativo ? null : Colors.white12,
            borderRadius: BorderRadius.circular(16),
            boxShadow: ativo ? [const BoxShadow(color: Color(0x66FF9F1C), blurRadius: 14, offset: Offset(0, 4))] : null,
          ),
          alignment: Alignment.center,
          child: Text(texto,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ativo ? Colors.black : Colors.white38)),
        ),
      );
}

class BotaoAcao extends StatelessWidget {
  final String emoji, rotulo;
  final bool destaque;
  final VoidCallback aoTocar;
  final double t;
  const BotaoAcao(this.emoji, this.rotulo, this.destaque, this.aoTocar, {super.key, required this.t});

  @override
  Widget build(BuildContext context) => _Apertavel(
        aoTocar: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            Transform.scale(
              scale: destaque ? 1 + 0.08 * sin(t * 6) : 1,
              child: Badge(
                isLabelVisible: destaque,
                label: const Text('!'),
                backgroundColor: const Color(0xFFFF4D8D),
                child: Text(emoji, style: const TextStyle(fontSize: 25)),
              ),
            ),
            Text(rotulo,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: destaque ? _ouro : Colors.white60)),
          ]),
        ),
      );
}

class Pilula extends StatelessWidget {
  final String texto;
  final Color cor;
  const Pilula({super.key, required this.texto, required this.cor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cor.withValues(alpha: 0.6)),
        ),
        child: Text(texto, style: TextStyle(fontWeight: FontWeight.w900, color: cor)),
      );
}

class ItemLoja extends StatelessWidget {
  final String emoji, titulo, subtitulo, rotulo, acao;
  final bool pode;
  final double? progresso;
  final VoidCallback aoComprar;
  const ItemLoja({
    this.acao = 'Comprar',
    super.key,
    required this.emoji,
    required this.titulo,
    required this.subtitulo,
    required this.rotulo,
    required this.pode,
    required this.aoComprar,
    this.progresso,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: pode ? _ouro.withValues(alpha: 0.5) : Colors.white10),
        ),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              Text(subtitulo, style: const TextStyle(color: Colors.white60, fontSize: 12)),
              if (progresso != null) ...[
                const SizedBox(height: 6),
                BarraBrilhante(valor: progresso!, cor: pode ? _ouro : const Color(0xFF4CC9F0), t: 0, altura: 8),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: BotaoCompra(linha1: pode ? acao : '', linha2: rotulo, ativo: pode, aoTocar: aoComprar),
          ),
        ]),
      );
}
