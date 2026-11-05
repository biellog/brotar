// Visual 3D isométrico do Império do Suco (desenhado à mão no Canvas, sem motor 3D).
import 'dart:math';

import 'package:flutter/material.dart';

import '../comum.dart';
import 'mundo.dart';

const _peles = [Color(0xFFF1C27D), Color(0xFFE0AC69), Color(0xFFC68642), Color(0xFF8D5524), Color(0xFFFFDBAC)];
const _camisas = [
  Color(0xFF4CC9F0), Color(0xFFFF6FA5), Color(0xFF7BD389), Color(0xFFB98CF0),
  Color(0xFFFF9F1C), Color(0xFF3A86FF), Color(0xFFF94144), Color(0xFF90BE6D),
];

class _Desenho {
  final double prof;
  final void Function(Canvas) pintar;
  _Desenho(this.prof, this.pintar);
}

/// Texto desenhado POR CIMA de tudo (nada esconde preço, placa ou pedido).
class _Rotulo {
  final Offset pos;
  final String texto;
  final double tam;
  final Color cor;
  final Color? fundo;
  _Rotulo(this.pos, this.texto, this.tam, this.cor, this.fundo);
}

/// Projeção isométrica: (x, y) do chão + altura z → ponto na tela.
class Iso {
  final double tw, th, zs;
  final Offset origem;
  Iso(this.tw, this.origem) : th = tw / 2, zs = tw * 0.55;

  Offset p(double x, double y, [double z = 0]) => origem + Offset((x - y) * tw / 2, (x + y) * th / 2 - z * zs);
}

Color _claro(Color c, double k) => Color.lerp(c, Colors.white, k)!;
Color _escuro(Color c, double k) => Color.lerp(c, Colors.black, k)!;

class PintorMundo extends CustomPainter {
  final Mundo m;
  final double t;
  final PintorEmoji pintor;
  final Offset? joyOrigem, joyPonto;
  PintorMundo({required this.m, required this.t, required this.pintor, this.joyOrigem, this.joyPonto});

  late Iso _iso;
  final _rotulos = <_Rotulo>[];

  /// Projeção usada na tela (a câmera segue o jogador).
  static Iso isoPara(Size s, Mundo m) {
    final tw = max(58.0, s.width / 6.2);
    final foco = Iso(tw, Offset.zero).p(m.jogador.x, m.jogador.y);
    return Iso(tw, Offset(s.width / 2, s.height * 0.55) - foco);
  }

  static const _arvores = [
    (0.5, 2.9), (0.5, 9.5), (0.5, 14.5), // atrás das barracas (fundo)
    (15.3, 4.5), (15.3, 8.0), (15.4, 10.6), (5.0, 15.4), (8.4, 15.4), (10.6, 15.4),
  ];
  static const _postes = [(5.2, 2.8), (12.2, 2.8), (6.2, 10.4), (14.8, 6.4)];

  @override
  void paint(Canvas c, Size s) {
    _iso = isoPara(s, m);
    _rotulos.clear();
    c.drawRect(Offset.zero & s,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7EC8F2), Color(0xFFCDEBFA)],
          ).createShader(Offset.zero & s));
    _ilha(c);
    _chao(c);
    _escritorioChao(c);
    for (final pl in m.placas) {
      _placa(c, pl);
    }
    // objetos ordenados pela profundidade
    final lista = <_Desenho>[];
    for (final b in m.barracas) {
      if (b.aberta) {
        lista.add(_Desenho(b.x + b.y, (c) => _barraca(c, b)));
      } else if (b.indice == m.abertas) {
        lista.add(_Desenho(b.x + b.y, (c) => _barracaFantasma(c, b)));
      }
    }
    lista.add(_Desenho(balcao.x + balcao.w / 2 + balcao.y + balcao.d / 2 + 0.3, _balcao));
    lista.add(_Desenho(mesa.x + mesa.w / 2 + mesa.y + mesa.d / 2, _mesa));
    lista.add(_Desenho(cadeira.x + cadeira.y - 0.05, _cadeira));
    for (final (x, y) in _arvores) {
      lista.add(_Desenho(x + y, (c) => _arvore(c, x, y)));
    }
    lista.add(_Desenho(fonte.x + fonte.w / 2 + fonte.y + fonte.d / 2, _fonte));
    for (final (x, y) in _postes) {
      lista.add(_Desenho(x + y, (c) => _poste(c, x, y)));
    }
    for (final cl in m.clientes) {
      lista.add(_Desenho(cl.x + cl.y + 0.01, (c) => _cliente(c, cl)));
    }
    for (final a in m.ajudantes) {
      lista.add(_Desenho(a.x + a.y + 0.01, (c) => _pessoa(c, a, const Color(0xFF2A9D8F), _peles[1], chef: true)));
    }
    lista.add(_Desenho(m.jogador.x + m.jogador.y + 0.02,
        (c) => _pessoa(c, m.jogador, const Color(0xFFFF9F1C), _peles[0], eu: true, sentado: m.sentado)));
    lista.sort((a, b) => a.prof.compareTo(b.prof));
    for (final d in lista) {
      d.pintar(c);
    }
    // por último, os rótulos (sempre visíveis)
    for (final r in _rotulos) {
      _texto(c, r.texto, r.pos, r.tam, r.cor, fundo: r.fundo);
    }
    if (joyOrigem != null && joyPonto != null) {
      c.drawCircle(joyOrigem!, 58,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white.withValues(alpha: 0.6));
      final v = joyPonto! - joyOrigem!;
      final ponta = joyOrigem! + (v.distance > 58 ? v / v.distance * 58 : v);
      c.drawCircle(ponta, 24, Paint()..color = Colors.white.withValues(alpha: 0.45));
    }
  }

  void _rotulo(Offset p, String s, double tam, Color cor, {Color? fundo}) => _rotulos.add(_Rotulo(p, s, tam, cor, fundo));

  // ---------------- primitivas ----------------
  void _poligono(Canvas c, List<Offset> pts, Paint p) => c.drawPath(Path()..addPolygon(pts, true), p);

  void _caixa(Canvas c, double x, double y, double w, double d, double z, double h, Color cor,
      {Color? topo, double bordas = 0.12}) {
    final i = _iso;
    final t1 = i.p(x, y, z + h), t2 = i.p(x + w, y, z + h), t3 = i.p(x + w, y + d, z + h), t4 = i.p(x, y + d, z + h);
    _poligono(c, [i.p(x, y + d, z), i.p(x + w, y + d, z), t3, t4], Paint()..color = cor);
    _poligono(c, [i.p(x + w, y, z), i.p(x + w, y + d, z), t3, t2], Paint()..color = _escuro(cor, 0.22));
    _poligono(c, [t1, t2, t3, t4], Paint()..color = topo ?? _claro(cor, 0.25));
    if (bordas > 0) {
      _poligono(
          c,
          [t1, t2, t3, t4],
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.black.withValues(alpha: bordas));
    }
  }

  void _sombra(Canvas c, double x, double y, double raio) {
    c.drawOval(Rect.fromCenter(center: _iso.p(x, y), width: _iso.tw * raio, height: _iso.th * raio),
        Paint()..color = Colors.black.withValues(alpha: 0.22));
  }

  void _texto(Canvas c, String s, Offset centro, double tam, Color cor, {Color? fundo}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontSize: tam,
              fontWeight: FontWeight.w900,
              color: cor,
              shadows: fundo == null ? const [Shadow(blurRadius: 3, color: Colors.black54)] : null)),
      textDirection: TextDirection.ltr,
    )..layout();
    if (fundo != null) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: centro, width: tp.width + 14, height: tp.height + 6), const Radius.circular(9)),
          Paint()..color = fundo);
    }
    tp.paint(c, centro - Offset(tp.width / 2, tp.height / 2));
  }

  // ---------------- cenário ----------------
  void _ilha(Canvas c) {
    final i = _iso;
    const h = 0.6;
    _poligono(c, [i.p(0, alturaMapa), i.p(larguraMapa, alturaMapa), i.p(larguraMapa, alturaMapa, -h), i.p(0, alturaMapa, -h)],
        Paint()..color = const Color(0xFF8D6E4A));
    _poligono(c, [i.p(larguraMapa, 0), i.p(larguraMapa, alturaMapa), i.p(larguraMapa, alturaMapa, -h), i.p(larguraMapa, 0, -h)],
        Paint()..color = const Color(0xFF6D5235));
  }

  void _chao(Canvas c) {
    final i = _iso;
    for (var x = 0; x < larguraMapa; x++) {
      for (var y = 0; y < alturaMapa; y++) {
        Color cor;
        if (y == 1) {
          cor = const Color(0xFF5A6270);
        } else if (y == 0 || y == 2) {
          cor = (x + y).isEven ? const Color(0xFFD7DCE2) : const Color(0xFFCBD1D8);
        } else if (x <= 2) {
          cor = (x + y).isEven ? const Color(0xFFE9C9A0) : const Color(0xFFE1BE92); // piso das barracas
        } else if (x >= 3 && x <= 14 && y >= 3 && y <= 14) {
          cor = (x + y).isEven ? const Color(0xFFF2E3C6) : const Color(0xFFEAD7B4);
        } else {
          cor = (x + y).isEven ? const Color(0xFF7CC66B) : const Color(0xFF71BA60);
        }
        _poligono(c, [i.p(x * 1.0, y * 1.0), i.p(x + 1.0, y * 1.0), i.p(x + 1.0, y + 1.0), i.p(x * 1.0, y + 1.0)],
            Paint()..color = cor);
      }
    }
    final faixa = Paint()
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.8);
    for (var x = 0.0; x < larguraMapa; x += 1.2) {
      c.drawLine(i.p(x + 0.2, 1.5), i.p(x + 0.7, 1.5), faixa);
    }
  }

  void _escritorioChao(Canvas c) {
    // carpete da gerência
    const x0 = 11.4, y0 = 11.2, x1 = 15.2, y1 = 15.2;
    _poligono(c, [_iso.p(x0, y0), _iso.p(x1, y0), _iso.p(x1, y1), _iso.p(x0, y1)], Paint()..color = const Color(0xFF3F5B8C));
    _poligono(
        c,
        [_iso.p(x0 + 0.15, y0 + 0.15), _iso.p(x1 - 0.15, y0 + 0.15), _iso.p(x1 - 0.15, y1 - 0.15), _iso.p(x0 + 0.15, y1 - 0.15)],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFFC23D).withValues(alpha: 0.7));
    _rotulo(_iso.p((x0 + x1) / 2, y0 + 0.2, 0.05), '💻 GERÊNCIA', 12, Colors.white, fundo: const Color(0xCC1E3A6E));
  }

  /// Árvore fica transparente quando está perto de você ou de uma placa.
  double _transparenciaArvore(double x, double y) {
    bool perto(double ax, double ay, double r) => (ax - x) * (ax - x) + (ay - y) * (ay - y) < r * r;
    if (perto(m.jogador.x, m.jogador.y, 2.6)) return 0.3;
    if (m.placas.any((p) => perto(p.x, p.y, 2.0))) return 0.45;
    return 1;
  }

  void _arvore(Canvas c, double x, double y) {
    final alfa = _transparenciaArvore(x, y);
    if (alfa < 1) c.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: alfa));
    _sombra(c, x, y, 0.9);
    _caixa(c, x - 0.08, y - 0.08, 0.16, 0.16, 0, 0.55, const Color(0xFF8B5A2B), bordas: 0);
    final topo = _iso.p(x, y, 1.05);
    final r = _iso.tw * 0.36;
    for (final (dx, dy, k) in [(0.0, 0.0, 1.0), (-0.45, 0.25, 0.75), (0.45, 0.25, 0.75), (0.0, -0.4, 0.8)]) {
      final ctr = topo + Offset(dx * r, dy * r);
      c.drawCircle(
          ctr,
          r * k,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.35, -0.45),
              colors: [Color(0xFF8BD66F), Color(0xFF3E8E41)],
            ).createShader(Rect.fromCircle(center: ctr, radius: r * k)));
    }
    if (alfa < 1) c.restore();
  }

  void _poste(Canvas c, double x, double y) {
    _caixa(c, x - 0.05, y - 0.05, 0.1, 0.1, 0, 1.6, const Color(0xFF37474F), bordas: 0);
    final luz = _iso.p(x, y, 1.7);
    c.drawCircle(luz, 7, Paint()..color = const Color(0xFFFFF3B0));
    c.drawCircle(luz, 16, Paint()..color = const Color(0xFFFFF3B0).withValues(alpha: 0.25));
  }

  void _fonte(Canvas c) {
    final x = fonte.x, y = fonte.y;
    _caixa(c, x, y, fonte.w, fonte.d, 0, 0.32, const Color(0xFFB0BEC5), topo: const Color(0xFF4FC3F7));
    final ctr = _iso.p(x + 0.8, y + 0.8, 0.32);
    for (var k = 0; k < 3; k++) {
      final f = (t * 0.6 + k / 3) % 1;
      c.drawOval(Rect.fromCenter(center: ctr, width: _iso.tw * 1.2 * f, height: _iso.th * 1.2 * f),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white.withValues(alpha: 0.7 * (1 - f)));
    }
    _caixa(c, x + 0.7, y + 0.7, 0.2, 0.2, 0.32, 0.6, const Color(0xFFCFD8DC), bordas: 0);
    for (var k = 0; k < 6; k++) {
      final a = k / 6 * 2 * pi + t;
      final fase = (t * 1.5 + k / 6) % 1;
      final pt = _iso.p(x + 0.8 + cos(a) * 0.5 * fase, y + 0.8 + sin(a) * 0.5 * fase, 0.95 + 0.5 * sin(pi * fase));
      c.drawCircle(pt, 2.5, Paint()..color = const Color(0xFFB3E5FC));
    }
  }

  // ---------------- escritório ----------------
  void _mesa(Canvas c) {
    _sombra(c, mesa.x + mesa.w / 2, mesa.y + mesa.d / 2, 2.2);
    _caixa(c, mesa.x, mesa.y, mesa.w, mesa.d, 0, 0.7, const Color(0xFF6D4C41), topo: const Color(0xFFA1887F));
    // monitor virado para a cadeira (lado -x da mesa)
    final mx = mesa.x + 0.3, my = mesa.y + 0.55;
    _caixa(c, mx, my, 0.08, 0.7, 0.7, 0.55, const Color(0xFF263238), bordas: 0);
    final brilho = 0.75 + 0.25 * sin(t * 3);
    _poligono(c, [_iso.p(mx, my + 0.06, 0.76), _iso.p(mx, my + 0.64, 0.76), _iso.p(mx, my + 0.64, 1.19), _iso.p(mx, my + 0.06, 1.19)],
        Paint()..color = Color.lerp(const Color(0xFF1565C0), const Color(0xFF4FC3F7), brilho)!);
    _caixa(c, mesa.x + 0.08, my + 0.1, 0.18, 0.5, 0.7, 0.03, const Color(0xFF424242), bordas: 0); // teclado
    pintor.desenhar(c, '🧃', _iso.tw * 0.16, _iso.p(mx, my + 0.35, 0.98));
  }

  void _cadeira(Canvas c) {
    final x = cadeira.x - 0.25, y = cadeira.y - 0.25;
    _caixa(c, x, y, 0.5, 0.5, 0.25, 0.08, const Color(0xFF212121), topo: const Color(0xFF37474F), bordas: 0);
    _caixa(c, x + 0.2, y + 0.2, 0.1, 0.1, 0, 0.25, const Color(0xFF424242), bordas: 0);
    _caixa(c, x, y, 0.06, 0.5, 0.33, 0.45, const Color(0xFF263238), bordas: 0); // encosto
    if (!m.sentado) {
      final p = _iso.p(cadeira.x, cadeira.y, 1.2 + 0.08 * sin(t * 4));
      _rotulo(p, '💻 Sente aqui', 12, Colors.white, fundo: const Color(0xCC1565C0));
    }
  }

  // ---------------- barracas, balcão e placas ----------------
  void _barracaFantasma(Canvas c, Barraca b) {
    final x = b.x - 0.7, y = b.y - 0.7;
    final traco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.6);
    _poligono(c, [_iso.p(x, y), _iso.p(x + 1.4, y), _iso.p(x + 1.4, y + 1.4), _iso.p(x, y + 1.4)], traco);
    pintor.desenhar(c, b.suco.emoji, _iso.tw * 0.35, _iso.p(b.x, b.y, 0.4 + 0.08 * sin(t * 3)));
  }

  void _barraca(Canvas c, Barraca b) {
    final cor = Color(b.suco.cor);
    final x = b.x - 0.7, y = b.y - 0.7;
    _sombra(c, b.x + 0.15, b.y + 0.15, 1.8);
    _caixa(c, x, y, 1.4, 1.4, 0, 0.75, _escuro(cor, 0.15), topo: const Color(0xFFFFF8E7));
    final qtd = min(b.estoque, 12);
    for (var k = 0; k < qtd; k++) {
      final cx = x + 0.25 + (k % 4) * 0.3, cy = y + 0.3 + (k ~/ 4) * 0.35;
      _copo(c, _iso.p(cx, cy, 0.75), cor, _iso.tw * 0.11);
    }
    final poste = Paint()
      ..strokeWidth = 2.5
      ..color = const Color(0xFF5D4037);
    for (final (px, py) in [(x, y), (x + 1.4, y), (x + 1.4, y + 1.4), (x, y + 1.4)]) {
      c.drawLine(_iso.p(px, py, 0.75), _iso.p(px, py, 1.45), poste);
    }
    const listras = 6;
    for (var k = 0; k < listras; k++) {
      final x0 = x - 0.1 + k * 1.6 / listras, x1 = x0 + 1.6 / listras;
      _poligono(c, [_iso.p(x0, y - 0.1, 1.5), _iso.p(x1, y - 0.1, 1.5), _iso.p(x1, y + 1.5, 1.5), _iso.p(x0, y + 1.5, 1.5)],
          Paint()..color = k.isEven ? cor : Colors.white);
      _poligono(c, [_iso.p(x0, y + 1.5, 1.5), _iso.p(x1, y + 1.5, 1.5), _iso.p(x1, y + 1.5, 1.32), _iso.p(x0, y + 1.5, 1.32)],
          Paint()..color = k.isEven ? _escuro(cor, 0.2) : const Color(0xFFE0E0E0));
    }
    _poligono(c, [_iso.p(x + 1.5, y - 0.1, 1.5), _iso.p(x + 1.5, y + 1.5, 1.5), _iso.p(x + 1.5, y + 1.5, 1.32), _iso.p(x + 1.5, y - 0.1, 1.32)],
        Paint()..color = _escuro(cor, 0.35));
    final topo = _iso.p(b.x, b.y, 2.15 + 0.08 * sin(t * 2.5 + b.indice));
    c.drawCircle(topo, _iso.tw * 0.32, Paint()..color = Colors.white.withValues(alpha: 0.35));
    pintor.desenhar(c, b.suco.emoji, _iso.tw * 0.5, topo);
    final cheia = b.estoque >= m.capacidadeBarraca(b);
    _rotulo(_iso.p(b.x, b.y, 1.75), '${b.estoque}/${m.capacidadeBarraca(b)} · nv ${b.nivel}', 11, cheia ? const Color(0xFFFFE08A) : Colors.white,
        fundo: Colors.black54);
  }

  void _copo(Canvas c, Offset base, Color cor, double w) {
    final r = Rect.fromLTWH(base.dx - w / 2, base.dy - w * 1.25, w, w * 1.25);
    c.drawRRect(RRect.fromRectAndCorners(r, bottomLeft: Radius.circular(w * 0.25), bottomRight: Radius.circular(w * 0.25)),
        Paint()..color = cor);
    c.drawRect(Rect.fromLTWH(r.left - 1, r.top - 2, w + 2, 3), Paint()..color = Colors.white);
    c.drawLine(Offset(base.dx + w * 0.15, r.top - 2), Offset(base.dx + w * 0.35, r.top - w * 0.6),
        Paint()
          ..strokeWidth = 1.6
          ..color = const Color(0xFFFF4D6D));
  }

  void _balcao(Canvas c) {
    _sombra(c, balcao.x + balcao.w / 2, balcao.y + 0.6, 3.6);
    _caixa(c, balcao.x, balcao.y, balcao.w, balcao.d, 0, 0.85, const Color(0xFF8D6E63), topo: const Color(0xFFFFF3E0));
    _caixa(c, balcao.x + balcao.w - 0.6, balcao.y + 0.15, 0.45, 0.45, 0.85, 0.3, const Color(0xFF455A64));
    pintor.desenhar(c, '💰', _iso.tw * 0.3, _iso.p(balcao.x + balcao.w - 0.38, balcao.y + 0.38, 1.4));
    _rotulo(_iso.p(balcao.x + balcao.w / 2, balcao.y + balcao.d, 0.4), 'CAIXA · ENTREGUE AQUI', 10, Colors.white,
        fundo: const Color(0xCC5D4037));
  }

  void _placa(Canvas c, Placa pl) {
    final custo = m.custo(pl);
    final prog = (pl.pago / custo).clamp(0.0, 1.0);
    final ctr = _iso.p(pl.x, pl.y);
    final pulso = 0.5 + 0.5 * sin(t * 4);
    final tam = pl.tipo == TipoPlaca.abrir ? 0.55 : 0.42;
    List<Offset> diamante(double k) =>
        [_iso.p(pl.x - k, pl.y - k), _iso.p(pl.x + k, pl.y - k), _iso.p(pl.x + k, pl.y + k), _iso.p(pl.x - k, pl.y + k)];
    final pode = m.dinheiro > 0;
    _poligono(c, diamante(tam),
        Paint()..color = (pode ? const Color(0xFF1FAF7A) : const Color(0xFF607D8B)).withValues(alpha: 0.4 + 0.15 * pulso));
    if (prog > 0) _poligono(c, diamante(tam * prog), Paint()..color = const Color(0xFFFFC23D).withValues(alpha: 0.8));
    _poligono(
        c,
        diamante(tam),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white.withValues(alpha: 0.9));
    pintor.desenhar(c, m.icone(pl), _iso.tw * 0.3, ctr - Offset(0, _iso.th * 0.1));
    final nome = pl.tipo == TipoPlaca.abrir
        ? 'Abrir ${sucos[pl.alvo].nome}'
        : '${sucos[pl.alvo].emoji} nv ${m.barracas[pl.alvo].nivel + 1}';
    _rotulo(ctr + Offset(0, _iso.th * (tam + 0.35)), '$nome · ${_curto(custo - pl.pago)}', 11,
        pl.tipo == TipoPlaca.abrir ? const Color(0xFFFFE08A) : Colors.white,
        fundo: Colors.black.withValues(alpha: 0.7));
  }

  // ---------------- pessoas ----------------
  void _pessoa(Canvas c, Pessoa p, Color camisa, Color pele, {bool eu = false, bool chef = false, bool sentado = false}) {
    final base = _iso.p(p.x, p.y, sentado ? 0.33 : 0);
    final u = _iso.tw / 64;
    if (eu && !sentado) {
      c.drawOval(Rect.fromCenter(center: base, width: 44 * u, height: 22 * u),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = Colors.white.withValues(alpha: 0.8));
    }
    if (!sentado) {
      c.drawOval(Rect.fromCenter(center: base, width: 30 * u, height: 12 * u), Paint()..color = Colors.black.withValues(alpha: 0.25));
    }
    c.save();
    // vira para o lado em que anda
    c.translate(base.dx, base.dy);
    if (p.olhandoEsquerda) c.scale(-1, 1);
    final passo = p.andando > 0 ? sin(p.andando * 14) : 0.0;
    final pula = p.andando > 0 ? (sin(p.andando * 14).abs() * 3 * u) : 0.0;
    final inclina = p.andando > 0 ? 0.08 : 0.0; // corre inclinado para frente
    final corpo = Offset(0, -pula);
    final perna = Paint()..color = const Color(0xFF34495E);
    if (sentado) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-7 * u, -6 * u, 14 * u, 6 * u), Radius.circular(2 * u)), perna);
    } else {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-7 * u, -14 * u + passo * 4 * u, 5 * u, 14 * u), Radius.circular(2 * u)), perna);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(2 * u, -14 * u - passo * 4 * u, 5 * u, 14 * u), Radius.circular(2 * u)), perna);
      c.drawOval(Rect.fromLTWH(-8 * u, -2 * u + passo * 4 * u, 8 * u, 4 * u), Paint()..color = const Color(0xFF212121));
      c.drawOval(Rect.fromLTWH(2 * u, -2 * u - passo * 4 * u, 8 * u, 4 * u), Paint()..color = const Color(0xFF212121));
    }
    c.save();
    c.translate(corpo.dx, corpo.dy - 14 * u);
    c.rotate(inclina);
    final tronco = Rect.fromCenter(center: Offset(0, -10 * u), width: 20 * u, height: 22 * u);
    c.drawRRect(RRect.fromRectAndRadius(tronco, Radius.circular(7 * u)),
        Paint()..shader = LinearGradient(colors: [_claro(camisa, 0.2), _escuro(camisa, 0.15)]).createShader(tronco));
    final carregando = p.carga.isNotEmpty || sentado;
    final braco = Paint()
      ..strokeWidth = 4.5 * u
      ..strokeCap = StrokeCap.round
      ..color = pele;
    for (final lado in [-1.0, 1.0]) {
      final ombro = Offset(lado * 10 * u, -17 * u);
      final mao = sentado
          ? Offset(lado * 6 * u + 8 * u, -10 * u) // digitando
          : carregando
              ? Offset(lado * 2 * u, -14 * u)
              : Offset(lado * 3 * u, 12 * u - lado * passo * 4 * u);
      c.drawLine(ombro, ombro + mao, braco);
    }
    final cabeca = Offset(0, -29 * u);
    c.drawCircle(cabeca, 9 * u, Paint()..color = pele);
    c.drawArc(Rect.fromCircle(center: cabeca, radius: 9.5 * u), pi, pi, true, Paint()..color = const Color(0xFF3E2723));
    c.drawCircle(cabeca + Offset(1 * u, 1 * u), 1.4 * u, Paint()..color = Colors.black);
    c.drawCircle(cabeca + Offset(5 * u, 1 * u), 1.4 * u, Paint()..color = Colors.black);
    c.drawArc(Rect.fromCenter(center: cabeca + Offset(3 * u, 4 * u), width: 6 * u, height: 3 * u), 0, pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 * u
          ..color = Colors.black54);
    if (chef) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: cabeca - Offset(0, 10 * u), width: 16 * u, height: 9 * u), Radius.circular(4 * u)),
          Paint()..color = Colors.white);
    }
    if (eu) {
      c.drawArc(Rect.fromCircle(center: cabeca - Offset(0, 1 * u), radius: 10 * u), pi, pi, true, Paint()..color = const Color(0xFFE85D04));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cabeca.dx - 2 * u, cabeca.dy - 3 * u, 14 * u, 3.5 * u), Radius.circular(2 * u)),
          Paint()..color = const Color(0xFFE85D04));
    }
    c.restore();
    c.restore();
    // pilha de copos (sem espelhar, por cima da cabeça)
    final cabecaTela = base + Offset(0, -pula - 43 * u);
    for (var k = 0; k < p.carga.length; k++) {
      final balanco = sin(t * 3 + k * 0.6) * k * 0.5 * u;
      _copo(c, cabecaTela - Offset(-balanco, 14 * u + k * 11 * u), Color(sucos[p.carga[k]].cor), 11 * u);
    }
    if (eu && p.carga.length >= m.capacidade && !sentado) {
      _rotulo(cabecaTela - Offset(0, 24 * u + p.carga.length * 11 * u), 'CHEIO!', 11, const Color(0xFFFFE08A), fundo: Colors.black54);
    }
  }

  void _cliente(Canvas c, Cliente cl) {
    final pessoa = Pessoa(cl.x, cl.y)
      ..andando = cl.andando
      ..olhandoEsquerda = cl.estado == EstadoCliente.saindo ? cl.x < larguraMapa / 2 : false;
    _pessoa(c, pessoa, _camisas[cl.aparencia % _camisas.length], _peles[cl.aparencia % _peles.length]);
    final u = _iso.tw / 64;
    final topo = _iso.p(cl.x, cl.y) - Offset(0, 74 * u);
    if (cl.estado == EstadoCliente.saindo) {
      if (cl.feliz > 0) pintor.desenhar(c, '😍', 22 * u, topo + Offset(0, -6 * u * (2 - cl.feliz)));
      return;
    }
    _rotulos.add(_Rotulo(topo, '${sucos[cl.quer].emoji} x${cl.faltam}', 14 * u, const Color(0xFF333333), Colors.white));
  }

  static String _curto(double v) {
    if (v >= 1e6) return 'R\$ ${(v / 1e6).toStringAsFixed(1)} mi';
    if (v >= 1e3) return 'R\$ ${(v / 1e3).toStringAsFixed(v >= 1e4 ? 0 : 1)} mil';
    return 'R\$ ${v.ceil()}';
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
