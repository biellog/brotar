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

  /// Projeção usada na tela (a câmera segue o jogador).
  static Iso isoPara(Size s, Mundo m) {
    final tw = max(58.0, s.width / 6.2);
    final foco = Iso(tw, Offset.zero).p(m.jogador.x, m.jogador.y);
    return Iso(tw, Offset(s.width / 2, s.height * 0.55) - foco);
  }

  @override
  void paint(Canvas c, Size s) {
    _iso = isoPara(s, m);

    c.drawRect(Offset.zero & s,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7EC8F2), Color(0xFFCDEBFA)],
          ).createShader(Offset.zero & s));
    _ilha(c);
    _chao(c);
    for (final pl in m.placas) {
      _placa(c, pl);
    }
    // objetos com profundidade
    final lista = <_Desenho>[];
    for (final b in m.barracas) {
      if (b.aberta) lista.add(_Desenho(b.x + b.y, (c) => _barraca(c, b)));
    }
    lista.add(_Desenho(balcao.x + balcao.w / 2 + balcao.y + balcao.d / 2 + 0.3, _balcao));
    for (final (x, y) in _arvores) {
      lista.add(_Desenho(x + y, (c) => _arvore(c, x, y)));
    }
    lista.add(_Desenho(13.8 + 13.8, _fonte));
    for (final (x, y) in _postes) {
      lista.add(_Desenho(x + y, (c) => _poste(c, x, y)));
    }
    for (final cl in m.clientes) {
      lista.add(_Desenho(cl.x + cl.y + 0.01, (c) => _cliente(c, cl)));
    }
    for (final a in m.ajudantes) {
      lista.add(_Desenho(a.x + a.y + 0.01, (c) => _pessoa(c, a, const Color(0xFF2A9D8F), _peles[1], chef: true)));
    }
    lista.add(_Desenho(m.jogador.x + m.jogador.y + 0.02, (c) => _pessoa(c, m.jogador, const Color(0xFFFF9F1C), _peles[0], eu: true)));
    lista.sort((a, b) => a.prof.compareTo(b.prof));
    for (final d in lista) {
      d.pintar(c);
    }
    // joystick
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

  static const _arvores = [
    (0.8, 3.6), (0.8, 7.0), (0.8, 10.5), (0.8, 14.2), (15.2, 6.6), (15.2, 10.2),
    (3.0, 15.2), (6.2, 15.3), (9.6, 15.2), (15.2, 3.4), (1.8, 15.0),
  ];
  static const _postes = [(5.4, 2.8), (11.8, 2.8), (3.0, 9.8), (14.0, 9.8)];

  // ---------------- primitivas ----------------
  void _poligono(Canvas c, List<Offset> pts, Paint p) {
    final caminho = Path()..addPolygon(pts, true);
    c.drawPath(caminho, p);
  }

  void _caixa(Canvas c, double x, double y, double w, double d, double z, double h, Color cor,
      {Color? topo, double bordas = 0.12}) {
    final i = _iso;
    final t1 = i.p(x, y, z + h), t2 = i.p(x + w, y, z + h), t3 = i.p(x + w, y + d, z + h), t4 = i.p(x, y + d, z + h);
    _poligono(c, [i.p(x, y + d, z), i.p(x + w, y + d, z), t3, t4], Paint()..color = cor); // frente esquerda
    _poligono(c, [i.p(x + w, y, z), i.p(x + w, y + d, z), t3, t2], Paint()..color = _escuro(cor, 0.22)); // direita
    _poligono(c, [t1, t2, t3, t4], Paint()..color = topo ?? _claro(cor, 0.25)); // topo
    if (bordas > 0) {
      final linha = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: bordas);
      _poligono(c, [t1, t2, t3, t4], linha);
    }
  }

  void _sombra(Canvas c, double x, double y, double raio) {
    final p = _iso.p(x, y);
    c.drawOval(Rect.fromCenter(center: p, width: _iso.tw * raio, height: _iso.th * raio),
        Paint()..color = Colors.black.withValues(alpha: 0.22));
  }

  void _texto(Canvas c, String s, Offset centro, double tam, Color cor, {Color? fundo}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(fontSize: tam, fontWeight: FontWeight.w900, color: cor,
              shadows: fundo == null ? const [Shadow(blurRadius: 3, color: Colors.black54)] : null)),
      textDirection: TextDirection.ltr,
    )..layout();
    if (fundo != null) {
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: centro, width: tp.width + 12, height: tp.height + 4), const Radius.circular(8)),
          Paint()..color = fundo);
    }
    tp.paint(c, centro - Offset(tp.width / 2, tp.height / 2));
  }

  // ---------------- cenário ----------------
  void _ilha(Canvas c) {
    // laterais de terra embaixo do mapa: dá a cara de "maquete 3D"
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
          cor = const Color(0xFF5A6270); // rua
        } else if (y == 0 || y == 2) {
          cor = (x + y).isEven ? const Color(0xFFD7DCE2) : const Color(0xFFCBD1D8); // calçada
        } else if (x >= 2 && x <= 14 && y >= 3 && y <= 13) {
          cor = (x + y).isEven ? const Color(0xFFF2E3C6) : const Color(0xFFEAD7B4); // praça de pedra
        } else {
          cor = (x + y).isEven ? const Color(0xFF7CC66B) : const Color(0xFF71BA60); // grama
        }
        _poligono(c, [i.p(x * 1.0, y * 1.0), i.p(x + 1.0, y * 1.0), i.p(x + 1.0, y + 1.0), i.p(x * 1.0, y + 1.0)], Paint()..color = cor);
      }
    }
    // faixa da rua
    final faixa = Paint()
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.8);
    for (var x = 0.0; x < larguraMapa; x += 1.2) {
      c.drawLine(i.p(x + 0.2, 1.5), i.p(x + 0.7, 1.5), faixa);
    }
  }

  void _arvore(Canvas c, double x, double y) {
    _sombra(c, x, y, 0.9);
    _caixa(c, x - 0.08, y - 0.08, 0.16, 0.16, 0, 0.55, const Color(0xFF8B5A2B), bordas: 0);
    final topo = _iso.p(x, y, 1.05);
    final r = _iso.tw * 0.36;
    for (final (dx, dy, k) in [(0.0, 0.0, 1.0), (-0.45, 0.25, 0.75), (0.45, 0.25, 0.75), (0.0, -0.4, 0.8)]) {
      final ctr = topo + Offset(dx * r, dy * r);
      c.drawCircle(ctr, r * k,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.45),
              colors: const [Color(0xFF8BD66F), Color(0xFF3E8E41)],
            ).createShader(Rect.fromCircle(center: ctr, radius: r * k)));
    }
  }

  void _poste(Canvas c, double x, double y) {
    _caixa(c, x - 0.05, y - 0.05, 0.1, 0.1, 0, 1.6, const Color(0xFF37474F), bordas: 0);
    final luz = _iso.p(x, y, 1.7);
    c.drawCircle(luz, 7, Paint()..color = const Color(0xFFFFF3B0));
    c.drawCircle(luz, 16, Paint()..color = const Color(0xFFFFF3B0).withValues(alpha: 0.25));
  }

  void _fonte(Canvas c) {
    const x = 13.0, y = 13.0;
    _caixa(c, x, y, 1.6, 1.6, 0, 0.32, const Color(0xFFB0BEC5), topo: const Color(0xFF4FC3F7));
    final ctr = _iso.p(x + 0.8, y + 0.8, 0.32);
    for (var k = 0; k < 3; k++) {
      final f = ((t * 0.6 + k / 3) % 1);
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

  // ---------------- barracas, balcão e placas ----------------
  void _barraca(Canvas c, Barraca b) {
    final cor = Color(b.suco.cor);
    final x = b.x - 0.7, y = b.y - 0.7;
    _sombra(c, b.x + 0.15, b.y + 0.15, 1.8);
    _caixa(c, x, y, 1.4, 1.4, 0, 0.75, _escuro(cor, 0.15), topo: const Color(0xFFFFF8E7));
    // copos prontos em cima do balcão da barraca
    final qtd = min(b.estoque, 12);
    for (var k = 0; k < qtd; k++) {
      final cx = x + 0.25 + (k % 4) * 0.3, cy = y + 0.3 + (k ~/ 4) * 0.35;
      _copo(c, _iso.p(cx, cy, 0.75), cor, _iso.tw * 0.11);
    }
    // postes e toldo listrado
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
    // fruta gigante flutuando
    final topo = _iso.p(b.x, b.y, 2.15 + 0.08 * sin(t * 2.5 + b.indice));
    c.drawCircle(topo, _iso.tw * 0.32, Paint()..color = Colors.white.withValues(alpha: 0.35));
    pintor.desenhar(c, b.suco.emoji, _iso.tw * 0.5, topo);
    final barra = _iso.p(b.x, b.y, 1.75);
    _texto(c, '${b.estoque}/${b.capacidade}  ·  nv ${b.nivel}', barra, 11, Colors.white, fundo: Colors.black45);
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
    _sombra(c, balcao.x + balcao.w / 2, balcao.y + 0.6, 3.2);
    _caixa(c, balcao.x, balcao.y, balcao.w, balcao.d, 0, 0.85, const Color(0xFF8D6E63), topo: const Color(0xFFFFF3E0));
    _caixa(c, balcao.x + balcao.w - 0.6, balcao.y + 0.15, 0.45, 0.45, 0.85, 0.3, const Color(0xFF455A64));
    pintor.desenhar(c, '💰', _iso.tw * 0.3, _iso.p(balcao.x + balcao.w - 0.38, balcao.y + 0.38, 1.4));
    _texto(c, 'CAIXA · ENTREGUE AQUI', _iso.p(balcao.x + balcao.w / 2, balcao.y + balcao.d, 0.4), 10, Colors.white,
        fundo: const Color(0xCC5D4037));
  }

  void _placa(Canvas c, Placa pl) {
    final custo = m.custo(pl);
    final prog = (pl.pago / custo).clamp(0.0, 1.0);
    final ctr = _iso.p(pl.x, pl.y);
    final pulso = 0.5 + 0.5 * sin(t * 4);
    final tam = pl.tipo == TipoPlaca.abrir ? 0.75 : 0.45;
    final pts = [_iso.p(pl.x - tam, pl.y - tam), _iso.p(pl.x + tam, pl.y - tam), _iso.p(pl.x + tam, pl.y + tam), _iso.p(pl.x - tam, pl.y + tam)];
    final podePagar = m.dinheiro > 0;
    _poligono(c, pts, Paint()..color = (podePagar ? const Color(0xFF1FAF7A) : const Color(0xFF607D8B)).withValues(alpha: 0.35 + 0.15 * pulso));
    // preenchimento conforme vai pagando
    if (prog > 0) {
      final k = tam * prog;
      _poligono(c, [_iso.p(pl.x - k, pl.y - k), _iso.p(pl.x + k, pl.y - k), _iso.p(pl.x + k, pl.y + k), _iso.p(pl.x - k, pl.y + k)],
          Paint()..color = const Color(0xFFFFC23D).withValues(alpha: 0.75));
    }
    _poligono(
        c,
        pts,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white.withValues(alpha: 0.85));
    pintor.desenhar(c, m.icone(pl), _iso.tw * (pl.tipo == TipoPlaca.abrir ? 0.45 : 0.3), ctr - Offset(0, _iso.th * 0.15));
    final falta = custo - pl.pago;
    _texto(c, m.rotulo(pl), ctr - Offset(0, _iso.th * (tam + 0.55)), 11, Colors.white, fundo: Colors.black54);
    _texto(c, 'R\$ ${_curto(falta)}', ctr + Offset(0, _iso.th * 0.42), 12, const Color(0xFFFFE08A), fundo: Colors.black54);
  }

  // ---------------- pessoas ----------------
  void _pessoa(Canvas c, Pessoa p, Color camisa, Color pele, {bool eu = false, bool chef = false}) {
    final base = _iso.p(p.x, p.y);
    final u = _iso.tw / 64; // escala
    if (eu) {
      c.drawOval(Rect.fromCenter(center: base, width: 44 * u, height: 22 * u),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = Colors.white.withValues(alpha: 0.8));
    }
    c.drawOval(Rect.fromCenter(center: base, width: 30 * u, height: 12 * u), Paint()..color = Colors.black.withValues(alpha: 0.25));
    final passo = p.andando > 0 ? sin(p.andando * 14) : 0.0;
    final pula = p.andando > 0 ? (sin(p.andando * 14).abs() * 2.5 * u) : 0.0;
    final corpo = base - Offset(0, pula);
    // pernas
    final perna = Paint()..color = const Color(0xFF34495E);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(corpo.dx - 7 * u, corpo.dy - 14 * u + passo * 3 * u, 5 * u, 14 * u), Radius.circular(2 * u)), perna);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(corpo.dx + 2 * u, corpo.dy - 14 * u - passo * 3 * u, 5 * u, 14 * u), Radius.circular(2 * u)), perna);
    // corpo
    final tronco = Rect.fromCenter(center: corpo - Offset(0, 24 * u), width: 20 * u, height: 22 * u);
    c.drawRRect(RRect.fromRectAndRadius(tronco, Radius.circular(7 * u)),
        Paint()
          ..shader = LinearGradient(colors: [_claro(camisa, 0.2), _escuro(camisa, 0.15)]).createShader(tronco));
    // braços (para cima se estiver carregando copos)
    final carregando = p.carga.isNotEmpty;
    final braco = Paint()
      ..strokeWidth = 4.5 * u
      ..strokeCap = StrokeCap.round
      ..color = pele;
    for (final lado in [-1.0, 1.0]) {
      final ombro = corpo + Offset(lado * 10 * u, -31 * u);
      c.drawLine(ombro, ombro + (carregando ? Offset(lado * 2 * u, -14 * u) : Offset(lado * 3 * u, 12 * u + lado * passo * 2 * u)), braco);
    }
    // cabeça
    final cabeca = corpo - Offset(0, 43 * u);
    c.drawCircle(cabeca, 9 * u, Paint()..color = pele);
    c.drawArc(Rect.fromCircle(center: cabeca, radius: 9.5 * u), pi, pi, true, Paint()..color = const Color(0xFF3E2723));
    c.drawCircle(cabeca + Offset(-3 * u, 1 * u), 1.4 * u, Paint()..color = Colors.black);
    c.drawCircle(cabeca + Offset(3 * u, 1 * u), 1.4 * u, Paint()..color = Colors.black);
    if (chef) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: cabeca - Offset(0, 10 * u), width: 16 * u, height: 9 * u), Radius.circular(4 * u)),
          Paint()..color = Colors.white);
    }
    if (eu) {
      // boné laranja
      c.drawArc(Rect.fromCircle(center: cabeca - Offset(0, 1 * u), radius: 10 * u), pi, pi, true, Paint()..color = const Color(0xFFE85D04));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cabeca.dx - 2 * u, cabeca.dy - 3 * u, 14 * u, 3.5 * u), Radius.circular(2 * u)),
          Paint()..color = const Color(0xFFE85D04));
    }
    // pilha de copos em cima da cabeça
    for (var k = 0; k < p.carga.length; k++) {
      final balanco = sin(t * 3 + k * 0.6) * k * 0.4 * u;
      _copo(c, cabeca - Offset(-balanco, 14 * u + k * 11 * u), Color(sucos[p.carga[k]].cor), 11 * u);
    }
  }

  void _cliente(Canvas c, Cliente cl) {
    final pessoa = Pessoa(cl.x, cl.y)..andando = cl.andando;
    _pessoa(c, pessoa, _camisas[cl.aparencia % _camisas.length], _peles[cl.aparencia % _peles.length]);
    final u = _iso.tw / 64;
    final topo = _iso.p(cl.x, cl.y) - Offset(0, 74 * u);
    if (cl.estado == EstadoCliente.saindo) {
      if (cl.feliz > 0) pintor.desenhar(c, '😍', 22 * u, topo + Offset(0, -6 * u * (2 - cl.feliz)));
      return;
    }
    // balão com o que o cliente quer
    final balao = RRect.fromRectAndRadius(Rect.fromCenter(center: topo, width: 48 * u, height: 30 * u), Radius.circular(12 * u));
    c.drawRRect(balao, Paint()..color = Colors.white);
    c.drawPath(
        Path()
          ..moveTo(topo.dx - 5 * u, topo.dy + 14 * u)
          ..lineTo(topo.dx + 5 * u, topo.dy + 14 * u)
          ..lineTo(topo.dx, topo.dy + 22 * u)
          ..close(),
        Paint()..color = Colors.white);
    pintor.desenhar(c, sucos[cl.quer].emoji, 18 * u, topo - Offset(7 * u, 0));
    _texto(c, 'x${cl.faltam}', topo + Offset(12 * u, 0), 12 * u, const Color(0xFF333333));
  }

  static String _curto(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)} mi';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(v >= 1e4 ? 0 : 1)} mil';
    return v.ceil().toString();
  }

  /// Ponto na tela de uma posição do mundo (para moedas e textos flutuantes).
  Offset tela(double x, double y, [double z = 0]) => _iso.p(x, y, z);

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
