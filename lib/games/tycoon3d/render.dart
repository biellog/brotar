// Visual 3D isométrico do Império do Suco (desenhado à mão no Canvas, sem motor 3D).
import 'dart:math';

import 'package:flutter/material.dart';

import '../comum.dart';
import 'mundo.dart';

const _peles = [Color(0xFFF1C27D), Color(0xFFE0AC69), Color(0xFFC68642), Color(0xFF8D5524), Color(0xFFFFDBAC)];
const _camisas = [
  Color(0xFF4CC9F0),
  Color(0xFFFF6FA5),
  Color(0xFF7BD389),
  Color(0xFFB98CF0),
  Color(0xFFFF9F1C),
  Color(0xFF3A86FF),
  Color(0xFFF94144),
  Color(0xFF90BE6D),
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

  /// Modo leve (celulares mais fracos): sem sombras e com menos detalhes animados.
  final bool leve;
  PintorMundo({required this.m, required this.t, required this.pintor, this.joyOrigem, this.joyPonto, this.leve = false});

  /// Textos já medidos (medir texto a cada quadro pesa muito em celular fraco).
  static final _cacheTexto = <String, TextPainter>{};
  static Shader? _ceu;
  static Size _tamCeu = Size.zero;

  late Iso _iso;
  final _rotulos = <_Rotulo>[];

  /// Projeção usada na tela (a câmera segue o jogador).
  static Iso isoPara(Size s, Mundo m) {
    final tw = max(58.0, s.shortestSide / 6.2);
    final foco = Iso(tw, Offset.zero).p(m.jogador.x, m.jogador.y);
    return Iso(tw, Offset(s.width / 2, s.height * 0.55) - foco);
  }

  static const _arvores = [
    (0.5, 2.9), (0.5, 9.5), (0.5, 14.5), // atrás das barracas (fundo)
    (17.6, 23.2), (30.6, 30.6), (25.0, 31.0), (17.6, 31.0), (30.8, 22.6), (24.6, 18.0), // parque
  ];
  static const _postes = [(5.2, 2.8), (12.2, 2.8), (6.2, 10.4), (18.0, 2.8), (26.0, 2.8)];
  static const _coqueiros = [(18.0, 12.4), (24.4, 13.6), (26.8, 6.4), (19.0, 8.6), (27.2, 11.0)];
  static const _guardasSol = [(25.0, 9.0), (22.0, 11.2), (21.0, 14.2)];
  Size _tam = Size.zero;

  @override
  void paint(Canvas c, Size s) {
    _iso = isoPara(s, m);
    _tam = s;
    _rotulos.clear();
    if (_ceu == null || _tamCeu != s) {
      _tamCeu = s;
      _ceu = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF7EC8F2), Color(0xFFCDEBFA)],
      ).createShader(Offset.zero & s);
    }
    c.drawRect(Offset.zero & s, Paint()..shader = _ceu);
    _ilha(c);
    _chao(c);
    _escritorioChao(c);
    for (final pl in m.placas) {
      _placa(c, pl);
    }
    if (m.agito == TipoAgito.excursao) _onibus(c);
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
    void add(double x, double y, double prof, void Function(Canvas) f) {
      if (_naTela(_iso.p(x, y), 4)) lista.add(_Desenho(prof, f));
    }

    if (m.aberta(Area.praia)) {
      for (final (x, y) in _coqueiros) {
        add(x, y, x + y, (c) => _coqueiro(c, x, y));
      }
      for (final (x, y) in _guardasSol) {
        add(x, y, x + y, (c) => _guardaSol(c, x, y));
      }
      add(quiosque.x, quiosque.y, quiosque.x + quiosque.w / 2 + quiosque.y + quiosque.d / 2 + 0.3, _quiosque);
    }
    if (m.aberta(Area.pomar)) {
      for (var k = 0; k < arvoresPomar.length; k++) {
        final (x, y) = arvoresPomar[k];
        add(x, y, x + y, (c) => _arvoreFruta(c, x, y, m.frutasArvore[k]));
      }
      add(depositoFrutas.x, depositoFrutas.y, depositoFrutas.x + depositoFrutas.y, _deposito);
    }
    final parque = m.aberta(Area.parque);
    add(rodaGigante.x, rodaGigante.y, rodaGigante.x + rodaGigante.w / 2 + rodaGigante.y + rodaGigante.d / 2, (c) {
      // fechado: a roda-gigante aparece apagada, só para dar vontade de abrir
      if (!parque) c.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: 0.4));
      _rodaGigante(c);
      if (!parque) c.restore();
    });
    if (parque) {
      add(carrossel.x, carrossel.y, carrossel.x + carrossel.y, _carrossel);
      add(palco.x, palco.y, palco.x + palco.w / 2 + palco.y + palco.d / 2, _palco);
    }
    final pe = m.pedido;
    if (pe != null) {
      final (emoji, nome, dx, dy) = destinosParque[pe.destino];
      add(dx, dy, dx + dy + 0.5, (c) {
        final topo = _iso.p(dx, dy, 1.6 + 0.15 * sin(t * 4));
        _rotulo(
          topo,
          '📦 $emoji $nome · ${pe.qtd}${sucos[pe.suco].emoji} · ${pe.resta.ceil()}s',
          12,
          Colors.white,
          fundo: const Color(0xDD00897B),
        );
        pintor.desenhar(c, '⬇️', _iso.tw * 0.3, topo + Offset(0, _iso.tw * 0.35));
      });
    }
    for (final cl in m.clientes) {
      lista.add(_Desenho(cl.x + cl.y + 0.01, (c) => _cliente(c, cl)));
    }
    for (final mo in m.moedasChao) {
      lista.add(_Desenho(mo.x + mo.y, (c) => _moedaChao(c, mo)));
    }
    final f = m.fruta;
    if (f != null) lista.add(_Desenho(f.$1 + f.$2, (c) => _frutaDourada(c, f.$1, f.$2)));
    for (final a in m.ajudantes) {
      lista.add(_Desenho(a.x + a.y + 0.01, (c) => _pessoa(c, a, const Color(0xFF2A9D8F), _peles[1], chef: true)));
    }
    for (final a in m.amigos.values) {
      lista.add(_Desenho(a.x + a.y + 0.015, (c) => _amigo(c, a)));
    }
    lista.add(
      _Desenho(
        m.jogador.x + m.jogador.y + 0.02,
        (c) => _pessoa(c, m.jogador, const Color(0xFFFF9F1C), _peles[0], eu: true, sentado: m.sentado),
      ),
    );
    lista.sort((a, b) => a.prof.compareTo(b.prof));
    for (final d in lista) {
      d.pintar(c);
    }
    if (m.agito == TipoAgito.calor) {
      c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFFF8A00).withValues(alpha: 0.10 + 0.04 * sin(t * 2)));
    }
    // setas na borda da tela apontando para o pedido e para o depósito
    if (pe != null) {
      final (emoji, _, dx, dy) = destinosParque[pe.destino];
      _setaFora(c, _iso.p(dx, dy), '📦$emoji', const Color(0xFF00897B));
    }
    if (m.aberta(Area.pomar) && m.jogador.frutas > 0) {
      _setaFora(c, _iso.p(depositoFrutas.x, depositoFrutas.y), '🧺', const Color(0xFF2E7D32));
    }
    // por último, os rótulos (sempre visíveis)
    for (final r in _rotulos) {
      _texto(c, r.texto, r.pos, r.tam, r.cor, fundo: r.fundo);
    }
    if (joyOrigem != null && joyPonto != null) {
      c.drawCircle(
        joyOrigem!,
        58,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: 0.6),
      );
      final v = joyPonto! - joyOrigem!;
      final ponta = joyOrigem! + (v.distance > 58 ? v / v.distance * 58 : v);
      c.drawCircle(ponta, 24, Paint()..color = Colors.white.withValues(alpha: 0.45));
    }
  }

  void _rotulo(Offset p, String s, double tam, Color cor, {Color? fundo}) => _rotulos.add(_Rotulo(p, s, tam, cor, fundo));

  /// Tela limpa: a maioria dos textos só aparece quando você chega perto.
  bool _perto(double x, double y, [double r = 3]) {
    final dx = m.jogador.x - x, dy = m.jogador.y - y;
    return dx * dx + dy * dy < r * r;
  }

  // ---------------- primitivas ----------------
  void _poligono(Canvas c, List<Offset> pts, Paint p) => c.drawPath(Path()..addPolygon(pts, true), p);

  void _caixa(
    Canvas c,
    double x,
    double y,
    double w,
    double d,
    double z,
    double h,
    Color cor, {
    Color? topo,
    double bordas = 0.12,
  }) {
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
          ..color = Colors.black.withValues(alpha: bordas),
      );
    }
  }

  void _sombra(Canvas c, double x, double y, double raio) {
    if (leve) return;
    c.drawOval(
      Rect.fromCenter(center: _iso.p(x, y), width: _iso.tw * raio, height: _iso.th * raio),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
  }

  void _texto(Canvas c, String s, Offset centro, double tam, Color cor, {Color? fundo}) {
    if (_cacheTexto.length > 400) _cacheTexto.clear();
    final tp = _cacheTexto.putIfAbsent(
      '$s|${tam.toStringAsFixed(1)}|${cor.toARGB32()}|${fundo == null}',
      () => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontSize: tam,
            fontWeight: FontWeight.w900,
            color: cor,
            shadows: fundo == null ? const [Shadow(blurRadius: 3, color: Colors.black54)] : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    if (fundo != null) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: centro, width: tp.width + 14, height: tp.height + 6),
          const Radius.circular(9),
        ),
        Paint()..color = fundo,
      );
    }
    tp.paint(c, centro - Offset(tp.width / 2, tp.height / 2));
  }

  // ---------------- cenário ----------------
  void _ilha(Canvas c) {
    final i = _iso;
    const h = 0.6;
    _poligono(c, [
      i.p(0, alturaMapa),
      i.p(larguraMapa, alturaMapa),
      i.p(larguraMapa, alturaMapa, -h),
      i.p(0, alturaMapa, -h),
    ], Paint()..color = const Color(0xFF8D6E4A));
    _poligono(c, [
      i.p(larguraMapa, 0),
      i.p(larguraMapa, alturaMapa),
      i.p(larguraMapa, alturaMapa, -h),
      i.p(larguraMapa, 0, -h),
    ], Paint()..color = const Color(0xFF6D5235));
  }

  /// Piso da praça muda a cada cidade nova.
  static const _pisos = [
    (Color(0xFFF2E3C6), Color(0xFFEAD7B4)),
    (Color(0xFFFFE0B2), Color(0xFFFFD08A)),
    (Color(0xFFD4ECF7), Color(0xFFBFE0F0)),
    (Color(0xFFDCEFD0), Color(0xFFCBE6BA)),
    (Color(0xFFEAD9F2), Color(0xFFDCC5E9)),
    (Color(0xFFF7E1C8), Color(0xFFEFCFA8)),
    (Color(0xFFF2D7D9), Color(0xFFE9C3C7)),
  ];

  bool _naTela(Offset o, [double margem = 1.5]) =>
      o.dx > -_iso.tw * margem &&
      o.dx < _tam.width + _iso.tw * margem &&
      o.dy > -_iso.tw * margem &&
      o.dy < _tam.height + _iso.tw * margem;

  Color _corPiso(int x, int y) {
    final par = (x + y).isEven;
    if (y == 1) return const Color(0xFF5A6270);
    if (y == 0 || y == 2) return par ? const Color(0xFFD7DCE2) : const Color(0xFFCBD1D8);
    final area = areaDe(x + 0.5, y + 0.5);
    Color cor;
    switch (area) {
      case Area.praca:
        if (x <= 2) {
          cor = par ? const Color(0xFFE9C9A0) : const Color(0xFFE1BE92); // piso das barracas
        } else if (x >= 3 && x <= 14 && y >= 3 && y <= 14) {
          final (a, b) = _pisos[m.cidades % _pisos.length];
          cor = par ? a : b;
        } else {
          cor = par ? const Color(0xFF7CC66B) : const Color(0xFF71BA60);
        }
      case Area.pomar:
        cor = y % 5 == 2 ? const Color(0xFFC9A66B) : (par ? const Color(0xFF6DBE5A) : const Color(0xFF63B350));
      case Area.praia:
        if (x + 0.5 >= marX) {
          final onda = leve ? 0.5 : ((0.5 + 0.5 * sin(t * 2 + x * 0.8 + y * 0.6)) * 4).round() / 4;
          cor = Color.lerp(const Color(0xFF29B6F6), const Color(0xFF4FC3F7), onda)!;
        } else if (x + 1.5 >= marX) {
          cor = par ? const Color(0xFFE6C88E) : const Color(0xFFDDBE82); // areia molhada
        } else {
          cor = par ? const Color(0xFFF5DEB3) : const Color(0xFFEED5A0);
        }
      case Area.parque:
        cor = x == 24 || y == 24 ? const Color(0xFFE0C9A6) : (par ? const Color(0xFF8BD17C) : const Color(0xFF80C671));
    }
    return m.aberta(area) ? cor : Color.lerp(cor, const Color(0xFF6B6B6B), 0.55)!;
  }

  void _chao(Canvas c) {
    final i = _iso;
    // junta os quadradinhos da mesma cor num desenho só (muito menos trabalho por quadro)
    final porCor = <int, Path>{};
    for (var x = 0; x < larguraMapa; x++) {
      for (var y = 0; y < alturaMapa; y++) {
        if (!_naTela(i.p(x + 0.5, y + 0.5))) continue;
        porCor.putIfAbsent(_corPiso(x, y).toARGB32(), Path.new).addPolygon([
          i.p(x * 1.0, y * 1.0),
          i.p(x + 1.0, y * 1.0),
          i.p(x + 1.0, y + 1.0),
          i.p(x * 1.0, y + 1.0),
        ], true);
      }
    }
    for (final e in porCor.entries) {
      c.drawPath(e.value, Paint()..color = Color(e.key));
    }
    final faixa = Paint()
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.8);
    for (var x = 0.0; x < larguraMapa; x += 1.2) {
      c.drawLine(i.p(x + 0.2, 1.5), i.p(x + 0.7, 1.5), faixa);
    }
    // lago do parque
    if (_naTela(i.p(lago.x + lago.w / 2, lago.y + lago.d / 2), 4)) {
      final pts = [
        for (var k = 0; k < 20; k++)
          i.p(lago.x + lago.w / 2 + cos(k / 20 * 2 * pi) * lago.w / 2, lago.y + lago.d / 2 + sin(k / 20 * 2 * pi) * lago.d / 2),
      ];
      _poligono(c, pts, Paint()..color = m.aberta(Area.parque) ? const Color(0xFF4FC3F7) : const Color(0xFF8A9BA3));
      if (m.aberta(Area.parque)) pintor.desenhar(c, '🦆', i.tw * 0.25, i.p(lago.x + 1.2 + 0.3 * sin(t * 0.7), lago.y + 0.8, 0.1));
    }
    // cercas e placas das áreas fechadas
    for (final a in Area.values.where((a) => !m.aberta(a))) {
      final cerca = Paint()
        ..strokeWidth = 3
        ..color = const Color(0xFF8D6E63);
      final cantos = [(a.x0, a.y0), (a.x1, a.y0), (a.x1, a.y1), (a.x0, a.y1)];
      for (var k = 0; k < 4; k++) {
        final (x0, y0) = cantos[k];
        final (x1, y1) = cantos[(k + 1) % 4];
        final borda =
            (y0 < 2.5 && y1 < 2.5) || (x0 >= larguraMapa && x1 >= larguraMapa) || (y0 >= alturaMapa && y1 >= alturaMapa);
        if (borda) continue;
        c.drawLine(i.p(x0, max(y0, 2.5), 0.5), i.p(x1, max(y1, 2.5), 0.5), cerca);
        c.drawLine(i.p(x0, max(y0, 2.5), 0.25), i.p(x1, max(y1, 2.5), 0.25), cerca);
      }
    }
    // destino do pedido (anel no chão)
    final pe = m.pedido;
    if (pe != null) {
      final (_, _, dx, dy) = destinosParque[pe.destino];
      final pulso = 0.5 + 0.5 * sin(t * 5);
      final r = Rect.fromCenter(center: i.p(dx, dy), width: i.tw * (1.6 + 0.3 * pulso), height: i.th * (1.6 + 0.3 * pulso));
      c.drawOval(r, Paint()..color = const Color(0xFF26A69A).withValues(alpha: 0.35));
      c.drawOval(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white,
      );
    }
    // depósito de frutas (cesto)
    if (m.aberta(Area.pomar) && m.jogador.frutas > 0) {
      final pulso = 0.5 + 0.5 * sin(t * 5);
      final r = Rect.fromCenter(
        center: i.p(depositoFrutas.x, depositoFrutas.y),
        width: i.tw * (1.8 + 0.3 * pulso),
        height: i.th * (1.8 + 0.3 * pulso),
      );
      c.drawOval(r, Paint()..color = const Color(0xFF66BB6A).withValues(alpha: 0.35));
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
        ..color = const Color(0xFFFFC23D).withValues(alpha: 0.7),
    );
    if (_perto((x0 + x1) / 2, (y0 + y1) / 2, 4.5)) {
      _rotulo(_iso.p((x0 + x1) / 2, y0 + 0.2, 0.05), '💻 GERÊNCIA', 12, Colors.white, fundo: const Color(0xCC1E3A6E));
    }
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
    final escuro = Paint()..color = const Color(0xFF3E8E41), claro = Paint()..color = const Color(0xFF6CC15A);
    for (final (dx, dy, k) in [(0.0, 0.0, 1.0), (-0.45, 0.25, 0.75), (0.45, 0.25, 0.75), (0.0, -0.4, 0.8)]) {
      final ctr = topo + Offset(dx * r, dy * r);
      c.drawCircle(ctr, r * k, escuro);
      c.drawCircle(ctr - Offset(r * k * 0.18, r * k * 0.2), r * k * 0.72, claro);
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
      c.drawOval(
        Rect.fromCenter(center: ctr, width: _iso.tw * 1.2 * f, height: _iso.th * 1.2 * f),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.7 * (1 - f)),
      );
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
    _poligono(c, [
      _iso.p(mx, my + 0.06, 0.76),
      _iso.p(mx, my + 0.64, 0.76),
      _iso.p(mx, my + 0.64, 1.19),
      _iso.p(mx, my + 0.06, 1.19),
    ], Paint()..color = Color.lerp(const Color(0xFF1565C0), const Color(0xFF4FC3F7), brilho)!);
    _caixa(c, mesa.x + 0.08, my + 0.1, 0.18, 0.5, 0.7, 0.03, const Color(0xFF424242), bordas: 0); // teclado
    pintor.desenhar(c, '🧃', _iso.tw * 0.16, _iso.p(mx, my + 0.35, 0.98));
  }

  void _cadeira(Canvas c) {
    final x = cadeira.x - 0.25, y = cadeira.y - 0.25;
    _caixa(c, x, y, 0.5, 0.5, 0.25, 0.08, const Color(0xFF212121), topo: const Color(0xFF37474F), bordas: 0);
    _caixa(c, x + 0.2, y + 0.2, 0.1, 0.1, 0, 0.25, const Color(0xFF424242), bordas: 0);
    _caixa(c, x, y, 0.06, 0.5, 0.33, 0.45, const Color(0xFF263238), bordas: 0); // encosto
    if (!m.sentado && _perto(cadeira.x, cadeira.y, 3.5)) {
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
      _poligono(c, [
        _iso.p(x0, y - 0.1, 1.5),
        _iso.p(x1, y - 0.1, 1.5),
        _iso.p(x1, y + 1.5, 1.5),
        _iso.p(x0, y + 1.5, 1.5),
      ], Paint()..color = k.isEven ? cor : Colors.white);
      _poligono(c, [
        _iso.p(x0, y + 1.5, 1.5),
        _iso.p(x1, y + 1.5, 1.5),
        _iso.p(x1, y + 1.5, 1.32),
        _iso.p(x0, y + 1.5, 1.32),
      ], Paint()..color = k.isEven ? _escuro(cor, 0.2) : const Color(0xFFE0E0E0));
    }
    _poligono(c, [
      _iso.p(x + 1.5, y - 0.1, 1.5),
      _iso.p(x + 1.5, y + 1.5, 1.5),
      _iso.p(x + 1.5, y + 1.5, 1.32),
      _iso.p(x + 1.5, y - 0.1, 1.32),
    ], Paint()..color = _escuro(cor, 0.35));
    final topo = _iso.p(b.x, b.y, 2.15 + 0.08 * sin(t * 2.5 + b.indice));
    c.drawCircle(topo, _iso.tw * 0.32, Paint()..color = Colors.white.withValues(alpha: 0.35));
    pintor.desenhar(c, b.suco.emoji, _iso.tw * 0.5, topo);
    final cheia = b.estoque >= m.capacidadeBarraca(b);
    if (_perto(b.x + 1, b.y, 2.4)) {
      _rotulo(
        _iso.p(b.x, b.y, 1.75),
        '${b.estoque}/${m.capacidadeBarraca(b)} · nv ${b.nivel}',
        11,
        cheia ? const Color(0xFFFFE08A) : Colors.white,
        fundo: Colors.black54,
      );
    }
  }

  void _copo(Canvas c, Offset base, Color cor, double w) {
    final r = Rect.fromLTWH(base.dx - w / 2, base.dy - w * 1.25, w, w * 1.25);
    c.drawRRect(
      RRect.fromRectAndCorners(r, bottomLeft: Radius.circular(w * 0.25), bottomRight: Radius.circular(w * 0.25)),
      Paint()..color = cor,
    );
    c.drawRect(Rect.fromLTWH(r.left - 1, r.top - 2, w + 2, 3), Paint()..color = Colors.white);
    c.drawLine(
      Offset(base.dx + w * 0.15, r.top - 2),
      Offset(base.dx + w * 0.35, r.top - w * 0.6),
      Paint()
        ..strokeWidth = 1.6
        ..color = const Color(0xFFFF4D6D),
    );
  }

  void _balcao(Canvas c) {
    _sombra(c, balcao.x + balcao.w / 2, balcao.y + 0.6, 3.6);
    _caixa(c, balcao.x, balcao.y, balcao.w, balcao.d, 0, 0.85, const Color(0xFF8D6E63), topo: const Color(0xFFFFF3E0));
    _caixa(c, balcao.x + balcao.w - 0.6, balcao.y + 0.15, 0.45, 0.45, 0.85, 0.3, const Color(0xFF455A64));
    pintor.desenhar(c, '💰', _iso.tw * 0.3, _iso.p(balcao.x + balcao.w - 0.38, balcao.y + 0.38, 1.4));
    _rotulo(
      _iso.p(balcao.x + balcao.w / 2, balcao.y + balcao.d, 0.4),
      _perto(balcao.x + balcao.w / 2, balcao.y + 1, 4.5) ? 'CAIXA · ENTREGUE AQUI' : 'CAIXA',
      10,
      Colors.white,
      fundo: const Color(0xCC5D4037),
    );
  }

  void _placa(Canvas c, Placa pl) {
    final custo = m.custo(pl);
    final prog = (pl.pago / custo).clamp(0.0, 1.0);
    final ctr = _iso.p(pl.x, pl.y);
    final pulso = 0.5 + 0.5 * sin(t * 4);
    final tam = pl.tipo == TipoPlaca.abrir ? 0.55 : 0.42;
    List<Offset> diamante(double k) => [
      _iso.p(pl.x - k, pl.y - k),
      _iso.p(pl.x + k, pl.y - k),
      _iso.p(pl.x + k, pl.y + k),
      _iso.p(pl.x - k, pl.y + k),
    ];
    final pode = m.dinheiro > 0;
    _poligono(
      c,
      diamante(tam),
      Paint()..color = (pode ? const Color(0xFF1FAF7A) : const Color(0xFF607D8B)).withValues(alpha: 0.4 + 0.15 * pulso),
    );
    if (prog > 0) _poligono(c, diamante(tam * prog), Paint()..color = const Color(0xFFFFC23D).withValues(alpha: 0.8));
    _poligono(
      c,
      diamante(tam),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: 0.9),
    );
    pintor.desenhar(c, m.icone(pl), _iso.tw * 0.3, ctr - Offset(0, _iso.th * 0.1));
    // espera de 5 s: um anel enche antes de começar a cobrar
    final espera = [
      m.jogador,
      ...m.amigos.values,
    ].where((p) => p.placaAtual == pl.id).fold<double>(0, (a, p) => max(a, p.naPlaca));
    if (espera > 0 && espera < esperaPlaca) {
      final r = Rect.fromCenter(center: ctr, width: _iso.tw * tam * 2.6, height: _iso.th * tam * 2.6);
      c.drawOval(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = Colors.black26,
      );
      c.drawArc(
        r,
        -pi / 2,
        2 * pi * espera / esperaPlaca,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFFFC23D),
      );
      _rotulo(
        ctr - Offset(0, _iso.th * (tam + 0.9)),
        '⏳ ${(esperaPlaca - espera).ceil()}s',
        13,
        Colors.white,
        fundo: const Color(0xDD1E3A6E),
      );
    }
    // preço só perto da placa (ou quando já dá para abrir uma barraca/área nova)
    final daParaAbrir = pl.tipo != TipoPlaca.melhorar && m.dinheiro >= custo - pl.pago;
    if (!_perto(pl.x, pl.y, 2.2) && !daParaAbrir) return;
    final nome = switch (pl.tipo) {
      TipoPlaca.abrir => 'Abrir ${sucos[pl.alvo].nome}',
      TipoPlaca.melhorar => '${sucos[pl.alvo].emoji} nv ${m.barracas[pl.alvo].nivel + 1}',
      TipoPlaca.area => 'Abrir ${Area.values[pl.alvo].emoji} ${Area.values[pl.alvo].nome}',
    };
    _rotulo(
      ctr + Offset(0, _iso.th * (tam + 0.35)),
      '$nome · ${_curto(custo - pl.pago)}',
      11,
      pl.tipo == TipoPlaca.abrir ? const Color(0xFFFFE08A) : Colors.white,
      fundo: Colors.black.withValues(alpha: 0.7),
    );
  }

  // ---------------- pessoas ----------------
  void _pessoa(Canvas c, Pessoa p, Color camisa, Color pele, {bool eu = false, bool chef = false, bool sentado = false}) {
    final base = _iso.p(p.x, p.y, sentado ? 0.33 : 0);
    final u = _iso.tw / 64;
    if (eu && !sentado) {
      c.drawOval(
        Rect.fromCenter(center: base, width: 44 * u, height: 22 * u),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white.withValues(alpha: 0.8),
      );
    }
    if (!sentado) {
      c.drawOval(
        Rect.fromCenter(center: base, width: 30 * u, height: 12 * u),
        Paint()..color = Colors.black.withValues(alpha: 0.25),
      );
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
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-7 * u, -14 * u + passo * 4 * u, 5 * u, 14 * u), Radius.circular(2 * u)),
        perna,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(2 * u, -14 * u - passo * 4 * u, 5 * u, 14 * u), Radius.circular(2 * u)),
        perna,
      );
      c.drawOval(Rect.fromLTWH(-8 * u, -2 * u + passo * 4 * u, 8 * u, 4 * u), Paint()..color = const Color(0xFF212121));
      c.drawOval(Rect.fromLTWH(2 * u, -2 * u - passo * 4 * u, 8 * u, 4 * u), Paint()..color = const Color(0xFF212121));
    }
    c.save();
    c.translate(corpo.dx, corpo.dy - 14 * u);
    c.rotate(inclina);
    final tronco = Rect.fromCenter(center: Offset(0, -10 * u), width: 20 * u, height: 22 * u);
    c.drawRRect(
      RRect.fromRectAndRadius(tronco, Radius.circular(7 * u)),
      Paint()..color = camisa,
    );
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
    c.drawArc(
      Rect.fromCenter(center: cabeca + Offset(3 * u, 4 * u), width: 6 * u, height: 3 * u),
      0,
      pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * u
        ..color = Colors.black54,
    );
    if (chef) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: cabeca - Offset(0, 10 * u), width: 16 * u, height: 9 * u),
          Radius.circular(4 * u),
        ),
        Paint()..color = Colors.white,
      );
    }
    if (eu) {
      c.drawArc(
        Rect.fromCircle(center: cabeca - Offset(0, 1 * u), radius: 10 * u),
        pi,
        pi,
        true,
        Paint()..color = const Color(0xFFE85D04),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cabeca.dx - 2 * u, cabeca.dy - 3 * u, 14 * u, 3.5 * u), Radius.circular(2 * u)),
        Paint()..color = const Color(0xFFE85D04),
      );
    }
    c.restore();
    c.restore();
    // pilha de copos (sem espelhar, por cima da cabeça)
    // uma pilha para cada suco (cada barraca tem seu espaço na mão)
    final cabecaTela = base + Offset(0, -pula - 43 * u);
    final porSuco = m.cargaPorSuco(p).entries.take(5).toList(); // no máximo 5 pilhas de 4 (não tampa a tela)
    var coluna = 0;
    for (final e in porSuco) {
      final dx = (coluna - (porSuco.length - 1) / 2) * 12 * u;
      final altura = min(e.value, 4);
      for (var k = 0; k < altura; k++) {
        final balanco = sin(t * 3 + k * 0.6 + coluna) * k * 0.5 * u;
        _copo(c, cabecaTela + Offset(dx + balanco, -14 * u - k * 9 * u), Color(sucos[e.key].cor), 10 * u);
      }
      coluna++;
    }
  }

  void _amigo(Canvas c, Amigo a) {
    _pessoa(c, a, Color(a.cor), _peles[a.id.hashCode.abs() % _peles.length], sentado: a.sentado);
    final u = _iso.tw / 64;
    final topo = _iso.p(a.x, a.y, a.sentado ? 0.33 : 0) - Offset(0, 62 * u + a.carga.length * 11 * u);
    _rotulo(topo, '👤 ${a.nome}', 11, Colors.white, fundo: Color(a.cor).withValues(alpha: 0.85));
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
    if (cl.vip) {
      pintor.desenhar(c, '👑', 20 * u, _iso.p(cl.x, cl.y) - Offset(0, 54 * u));
      final barra = Rect.fromCenter(center: topo + Offset(0, 16 * u), width: 46 * u, height: 6 * u);
      final frac = (cl.paciencia / TipoAgito.vip.duracao).clamp(0.0, 1.0);
      c.drawRRect(RRect.fromRectAndRadius(barra, const Radius.circular(3)), Paint()..color = Colors.black45);
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(barra.left, barra.top, barra.width * frac, barra.height), const Radius.circular(3)),
        Paint()..color = Color.lerp(const Color(0xFFFF4D6D), const Color(0xFF7BD389), frac)!,
      );
      _rotulos.add(
        _Rotulo(topo, '👑 ${sucos[cl.quer].emoji} x${cl.faltam}', 15 * u, const Color(0xFF5D4037), const Color(0xFFFFE08A)),
      );
      return;
    }
    _rotulos.add(_Rotulo(topo, '${sucos[cl.quer].emoji} x${cl.faltam}', 14 * u, const Color(0xFF333333), Colors.white));
  }

  void _moedaChao(Canvas c, MoedaChao mo) {
    final pulo = 0.25 + 0.12 * sin(t * 5 + mo.x * 3);
    final ctr = _iso.p(mo.x, mo.y, pulo);
    _sombra(c, mo.x, mo.y, 0.4);
    final larg = _iso.tw * 0.24 * (0.35 + 0.65 * cos(t * 4 + mo.y).abs()); // gira
    final r = Rect.fromCenter(center: ctr, width: larg, height: _iso.tw * 0.24);
    c.drawOval(
      r,
      Paint()..shader = const RadialGradient(colors: [Color(0xFFFFF1A8), Color(0xFFFFC23D), Color(0xFFD48806)]).createShader(r),
    );
    c.drawOval(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFB8860B),
    );
  }

  void _frutaDourada(Canvas c, double x, double y) {
    final ctr = _iso.p(x, y, 0.55 + 0.15 * sin(t * 3));
    _sombra(c, x, y, 0.8);
    for (var k = 0; k < 8; k++) {
      final a = k / 8 * 2 * pi + t;
      c.drawLine(
        ctr,
        ctr + Offset(cos(a), sin(a)) * _iso.tw * (0.45 + 0.08 * sin(t * 6 + k)),
        Paint()
          ..strokeWidth = 3
          ..color = const Color(0xFFFFE08A).withValues(alpha: 0.6),
      );
    }
    c.drawCircle(ctr, _iso.tw * 0.3, Paint()..color = const Color(0xFFFFF3B0).withValues(alpha: 0.6));
    pintor.desenhar(c, '🍊', _iso.tw * 0.42, ctr);
    _rotulo(ctr - Offset(0, _iso.tw * 0.5), '🌟 PEGUE!', 12, const Color(0xFF5D4037), fundo: const Color(0xFFFFE08A));
  }

  /// Ônibus da excursão parado na rua.
  void _onibus(Canvas c) {
    const x = 11.2, y = 0.25;
    _caixa(c, x, y, 3.4, 1.0, 0.1, 1.1, const Color(0xFFFFC23D), topo: const Color(0xFFFFE08A));
    for (var k = 0; k < 4; k++) {
      final x0 = x + 0.3 + k * 0.75;
      _poligono(c, [
        _iso.p(x0, y + 1.0, 0.55),
        _iso.p(x0 + 0.55, y + 1.0, 0.55),
        _iso.p(x0 + 0.55, y + 1.0, 0.95),
        _iso.p(x0, y + 1.0, 0.95),
      ], Paint()..color = const Color(0xFF4FC3F7));
    }
    for (final wx in [x + 0.6, x + 2.8]) {
      c.drawCircle(_iso.p(wx, y + 1.0, 0.1), _iso.tw * 0.09, Paint()..color = const Color(0xFF263238));
    }
    _rotulo(_iso.p(x + 1.7, y + 0.5, 1.5), '🚌 EXCURSÃO', 11, Colors.white, fundo: const Color(0xCCFF4D6D));
  }

  /// Seta na borda da tela quando o alvo está fora da vista.
  void _setaFora(Canvas c, Offset alvo, String emoji, Color cor) {
    final area = Rect.fromLTWH(40, 150, _tam.width - 80, _tam.height - 260);
    if (area.contains(alvo)) return;
    final ctr = _tam.center(Offset.zero);
    final v = alvo - ctr;
    final k = min((area.width / 2) / max(v.dx.abs(), 1e-6), (area.height / 2) / max(v.dy.abs(), 1e-6));
    final ponto = ctr + v * k;
    final ang = atan2(v.dy, v.dx);
    c.save();
    c.translate(ponto.dx, ponto.dy);
    c.rotate(ang);
    c.drawPath(Path()..addPolygon(const [Offset(22, 0), Offset(4, -12), Offset(4, 12)], true), Paint()..color = cor);
    c.restore();
    c.drawCircle(ponto, 17, Paint()..color = cor);
    c.drawCircle(
      ponto,
      17,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    _rotulos.add(_Rotulo(ponto, emoji, 13, Colors.white, null));
  }

  void _coqueiro(Canvas c, double x, double y) {
    final alfa = _transparenciaArvore(x, y);
    if (alfa < 1) c.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: alfa));
    _sombra(c, x, y, 0.8);
    final base = _iso.p(x, y), topo = _iso.p(x + 0.15, y - 0.1, 1.9);
    c.drawPath(
      Path()
        ..moveTo(base.dx - 4, base.dy)
        ..quadraticBezierTo((base.dx + topo.dx) / 2 + 8, (base.dy + topo.dy) / 2, topo.dx, topo.dy)
        ..lineTo(topo.dx + 3, topo.dy)
        ..quadraticBezierTo((base.dx + topo.dx) / 2 + 11, (base.dy + topo.dy) / 2, base.dx + 4, base.dy)
        ..close(),
      Paint()..color = const Color(0xFF8D6E63),
    );
    final folha = Paint()..color = const Color(0xFF43A047);
    for (var k = 0; k < 6; k++) {
      final a = k / 6 * 2 * pi + 0.1 * sin(t * 1.5 + x);
      final fim = topo + Offset(cos(a) * _iso.tw * 0.55, sin(a) * _iso.tw * 0.25 + _iso.tw * 0.12);
      c.drawPath(
        Path()
          ..moveTo(topo.dx, topo.dy)
          ..quadraticBezierTo((topo.dx + fim.dx) / 2, topo.dy - _iso.tw * 0.12, fim.dx, fim.dy)
          ..quadraticBezierTo((topo.dx + fim.dx) / 2, topo.dy - _iso.tw * 0.02, topo.dx, topo.dy),
        folha,
      );
    }
    for (final o in [const Offset(-4, 4), const Offset(4, 5)]) {
      c.drawCircle(topo + o, 4, Paint()..color = const Color(0xFF6D4C41));
    }
    if (alfa < 1) c.restore();
  }

  void _guardaSol(Canvas c, double x, double y) {
    _sombra(c, x + 0.3, y + 0.3, 1.0);
    c.drawLine(
      _iso.p(x, y),
      _iso.p(x, y, 1.3),
      Paint()
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );
    final topo = _iso.p(x, y, 1.35);
    final r = _iso.tw * 0.55;
    for (var k = 0; k < 6; k++) {
      c.drawArc(
        Rect.fromCenter(center: topo + Offset(0, r * 0.25), width: r * 2, height: r * 0.9),
        pi + k * pi / 6,
        pi / 6,
        true,
        Paint()..color = k.isEven ? const Color(0xFFFF4D6D) : Colors.white,
      );
    }
    _caixa(c, x + 0.25, y + 0.05, 0.9, 0.45, 0, 0.12, const Color(0xFF4CC9F0), bordas: 0); // toalha/espreguiçadeira
  }

  void _quiosque(Canvas c) {
    final q = quiosque;
    _sombra(c, q.x + q.w / 2, q.y + 0.6, 3.0);
    _caixa(c, q.x, q.y, q.w, q.d, 0, 0.85, const Color(0xFFA1887F), topo: const Color(0xFFFFF8E1));
    final poste = Paint()
      ..strokeWidth = 2.5
      ..color = const Color(0xFF6D4C41);
    for (final (px, py) in [(q.x, q.y), (q.x + q.w, q.y), (q.x + q.w, q.y + q.d), (q.x, q.y + q.d)]) {
      c.drawLine(_iso.p(px, py, 0.85), _iso.p(px, py, 1.7), poste);
    }
    _poligono(c, [
      _iso.p(q.x - 0.3, q.y - 0.3, 1.7),
      _iso.p(q.x + q.w + 0.3, q.y - 0.3, 1.7),
      _iso.p(q.x + q.w + 0.3, q.y + q.d + 0.3, 1.7),
      _iso.p(q.x - 0.3, q.y + q.d + 0.3, 1.7),
    ], Paint()..color = const Color(0xFFD7B56D)); // telhado de palha
    _poligono(c, [
      _iso.p(q.x - 0.3, q.y + q.d + 0.3, 1.7),
      _iso.p(q.x + q.w + 0.3, q.y + q.d + 0.3, 1.7),
      _iso.p(q.x + q.w + 0.3, q.y + q.d + 0.3, 1.5),
      _iso.p(q.x - 0.3, q.y + q.d + 0.3, 1.5),
    ], Paint()..color = const Color(0xFFB8934A));
    pintor.desenhar(c, '🥥', _iso.tw * 0.3, _iso.p(q.x + q.w / 2, q.y + 0.4, 2.05));
    if (!_perto(q.x + q.w / 2, q.y + 1, 5)) return;
    _rotulo(
      _iso.p(q.x + q.w / 2, q.y + q.d, 0.4),
      'QUIOSQUE · 1,5x · ENTREGUE AQUI',
      10,
      Colors.white,
      fundo: const Color(0xCC0277BD),
    );
  }

  void _arvoreFruta(Canvas c, double x, double y, int frutas) {
    final alfa = _transparenciaArvore(x, y);
    if (alfa < 1) c.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: alfa));
    _sombra(c, x, y, 1.1);
    _caixa(c, x - 0.1, y - 0.1, 0.2, 0.2, 0, 0.6, const Color(0xFF795548), bordas: 0);
    final topo = _iso.p(x, y, 1.15);
    final r = _iso.tw * 0.42;
    c.drawCircle(topo, r, Paint()..color = const Color(0xFF2E7D32));
    c.drawCircle(topo - Offset(r * 0.18, r * 0.2), r * 0.74, Paint()..color = const Color(0xFF7CB342));
    const pos = [Offset(-0.45, -0.1), Offset(0.35, -0.35), Offset(0.15, 0.35)];
    for (var k = 0; k < frutas && k < pos.length; k++) {
      final o = topo + pos[k] * r;
      c.drawCircle(o, r * 0.2, Paint()..color = const Color(0xFFFF9800));
      c.drawCircle(o - Offset(r * 0.06, r * 0.06), r * 0.06, Paint()..color = Colors.white70);
    }
    if (alfa < 1) c.restore();
  }

  void _deposito(Canvas c) {
    final d = depositoFrutas;
    _sombra(c, d.x, d.y, 1.0);
    _caixa(c, d.x - 0.45, d.y - 0.35, 0.9, 0.7, 0, 0.55, const Color(0xFFA1887F), topo: const Color(0xFFFFB74D));
    pintor.desenhar(c, '🧺', _iso.tw * 0.35, _iso.p(d.x, d.y, 0.95));
    if (m.jogador.frutas == 0 && !_perto(d.x, d.y, 4)) return;
    _rotulo(
      _iso.p(d.x, d.y, 1.5),
      m.jogador.frutas > 0 ? '🧺 ENTREGUE AS FRUTAS AQUI' : '🧺 DEPÓSITO',
      10,
      Colors.white,
      fundo: const Color(0xCC2E7D32),
    );
  }

  void _rodaGigante(Canvas c) {
    final g = rodaGigante;
    _caixa(c, g.x, g.y, g.w, g.d, 0, 0.3, const Color(0xFF546E7A));
    final ctr = _iso.p(g.x + g.w / 2, g.y + g.d / 2, 3.0);
    final r = _iso.tw * 1.35;
    final base1 = _iso.p(g.x + 0.1, g.y + g.d / 2, 0.3), base2 = _iso.p(g.x + g.w - 0.1, g.y + g.d / 2, 0.3);
    final suporte = Paint()
      ..strokeWidth = 4
      ..color = const Color(0xFF455A64);
    c.drawLine(base1, ctr, suporte);
    c.drawLine(base2, ctr, suporte);
    c.drawCircle(
      ctr,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFE91E63),
    );
    const cores = [
      Color(0xFFFFC23D),
      Color(0xFF4CC9F0),
      Color(0xFF7BD389),
      Color(0xFFB98CF0),
      Color(0xFFFF6FA5),
      Color(0xFFFF9F1C),
    ];
    for (var k = 0; k < 8; k++) {
      final a = t * 0.4 + k / 8 * 2 * pi;
      final pt = ctr + Offset(cos(a), sin(a)) * r;
      c.drawLine(
        ctr,
        pt,
        Paint()
          ..strokeWidth = 1.5
          ..color = const Color(0xFFF8BBD0),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: pt + const Offset(0, 6), width: 14, height: 11),
          const Radius.circular(3),
        ),
        Paint()..color = cores[k % cores.length],
      );
    }
    c.drawCircle(ctr, 5, Paint()..color = const Color(0xFF455A64));
  }

  void _carrossel(Canvas c) {
    final k = carrossel;
    final base = _iso.p(k.x, k.y);
    final rx = _iso.tw * k.r, ry = _iso.th * k.r;
    c.drawOval(Rect.fromCenter(center: base, width: rx * 2, height: ry * 2), Paint()..color = const Color(0xFFBCAAA4));
    final altura = _iso.zs * 1.4;
    for (var n = 0; n < 6; n++) {
      final a = t * 0.8 + n / 6 * 2 * pi;
      final pe = base + Offset(cos(a) * rx * 0.75, sin(a) * ry * 0.75);
      c.drawLine(
        pe,
        pe - Offset(0, altura),
        Paint()
          ..strokeWidth = 2
          ..color = const Color(0xFFFFD54F),
      );
      pintor.desenhar(c, '🐴', _iso.tw * 0.22, pe - Offset(0, altura * (0.35 + 0.1 * sin(t * 3 + n))));
    }
    final topo = base - Offset(0, altura);
    for (var n = 0; n < 8; n++) {
      c.drawPath(
        Path()
          ..moveTo(topo.dx, topo.dy - altura * 0.45)
          ..lineTo(topo.dx + cos(n / 8 * 2 * pi) * rx * 1.05, topo.dy + sin(n / 8 * 2 * pi) * ry * 1.05)
          ..lineTo(topo.dx + cos((n + 1) / 8 * 2 * pi) * rx * 1.05, topo.dy + sin((n + 1) / 8 * 2 * pi) * ry * 1.05)
          ..close(),
        Paint()..color = n.isEven ? const Color(0xFFE53935) : Colors.white,
      );
    }
  }

  void _palco(Canvas c) {
    final p = palco;
    _caixa(c, p.x, p.y, p.w, p.d, 0, 0.5, const Color(0xFF5D4037), topo: const Color(0xFF8D6E63));
    _poligono(c, [
      _iso.p(p.x, p.y + 0.1, 0.5),
      _iso.p(p.x + p.w, p.y + 0.1, 0.5),
      _iso.p(p.x + p.w, p.y + 0.1, 2.0),
      _iso.p(p.x, p.y + 0.1, 2.0),
    ], Paint()..color = const Color(0xFFC62828)); // cortina
    for (var k = 0; k < 3; k++) {
      final luz = 0.5 + 0.5 * sin(t * 3 + k * 2);
      c.drawCircle(
        _iso.p(p.x + 0.8 + k * 1.4, p.y + 0.1, 2.1),
        5,
        Paint()..color = Color.lerp(const Color(0xFFFFF59D), const Color(0xFFFFC107), luz)!,
      );
    }
    pintor.desenhar(c, '🎤', _iso.tw * 0.3, _iso.p(p.x + p.w / 2, p.y + p.d / 2, 0.85));
  }

  static String _curto(double v) {
    if (v >= 1e6) return 'R\$ ${(v / 1e6).toStringAsFixed(1)} mi';
    if (v >= 1e3) return 'R\$ ${(v / 1e3).toStringAsFixed(v >= 1e4 ? 0 : 1)} mil';
    return 'R\$ ${v.ceil()}';
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
