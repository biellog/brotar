// Jogos relaxantes: sem perder, sem pressa. Toque em "Terminar" quando quiser.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../data/musica.dart';
import '../data/repo.dart';
import '../theme.dart';
import 'comum.dart';

/// Estrutura comum: barra com contador, música e botão Terminar.
class _TelaRelaxante extends StatelessWidget {
  final String titulo;
  final String contador;
  final VoidCallback aoTerminar;
  final Widget corpo;
  final Color fundo;
  final List<Widget> extras;
  const _TelaRelaxante({
    required this.titulo,
    required this.contador,
    required this.aoTerminar,
    required this.corpo,
    this.fundo = Cores.fundo,
    this.extras = const [],
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: fundo,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(titulo),
          actions: [
            Center(child: Text(contador, style: const TextStyle(fontSize: 18, color: Cores.ouro))),
            ...extras,
            const BotaoMusica(),
            TextButton(onPressed: aoTerminar, child: const Text('Terminar')),
          ],
        ),
        body: SafeArea(top: false, child: corpo),
      );
}

Future<void> _terminar(BuildContext context, String jogo, String nome, int pontos, DateTime inicio,
    String mensagem, VoidCallback aoRecomecar) async {
  final denovo = await finalizarPartida(
    context,
    jogo: jogo,
    nomeJogo: nome,
    pontos: pontos,
    duracaoSeg: DateTime.now().difference(inicio).inSeconds,
    mensagemExtra: mensagem,
  );
  if (!context.mounted) return;
  if (denovo) {
    aoRecomecar();
  } else {
    Navigator.pop(context);
  }
}

// =====================================================================
// 🫧 Plástico Bolha
// =====================================================================
class PlasticoBolha {
  static const colunas = 6, linhas = 9;
  final estouradas = List<bool>.filled(colunas * linhas, false);
  int total = 0;

  bool get folhaCompleta => !estouradas.contains(false);

  /// Estoura a bolha na posição proporcional (x, y). Retorna true se estourou.
  bool tocar(double x, double y) {
    if (x < 0 || x >= 1 || y < 0 || y >= 1) return false;
    final i = (y * linhas).floor() * colunas + (x * colunas).floor();
    if (estouradas[i]) return false;
    estouradas[i] = true;
    total++;
    return true;
  }

  void novaFolha() => estouradas.fillRange(0, estouradas.length, false);
}

class PlasticoBolhaScreen extends StatefulWidget {
  const PlasticoBolhaScreen({super.key});

  @override
  State<PlasticoBolhaScreen> createState() => _PlasticoBolhaScreenState();
}

class _PlasticoBolhaScreenState extends State<PlasticoBolhaScreen> {
  var _m = PlasticoBolha();
  var _inicio = DateTime.now();
  int _folhas = 0;

  @override
  void initState() {
    super.initState();
    Repo.log('jogo_iniciado', {'jogo': 'plastico'});
  }

  void _toque(Offset p, Size s) {
    if (_m.tocar(p.dx / s.width, p.dy / s.height)) {
      Musica.efeito(Efeito.plastico);
      HapticFeedback.selectionClick();
      setState(() {});
      if (_m.folhaCompleta) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          setState(() {
            _m.novaFolha();
            _folhas++;
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _TelaRelaxante(
        titulo: 'Plástico Bolha',
        contador: '🫧 ${_m.total}  ',
        aoTerminar: () => _terminar(context, 'plastico', 'Plástico Bolha', _m.total * 2, _inicio,
            'Você estourou ${_m.total} bolhas${_folhas > 0 ? ' e $_folhas folhas inteiras' : ''}. Que alívio! 🫧',
            () => setState(() {
                  _m = PlasticoBolha();
                  _inicio = DateTime.now();
                  _folhas = 0;
                })),
        corpo: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(builder: (_, box) {
            final s = Size(box.maxWidth, box.maxHeight);
            return GestureDetector(
              onPanDown: (d) => _toque(d.localPosition, s),
              onPanUpdate: (d) => _toque(d.localPosition, s),
              child: CustomPaint(size: s, painter: _PintorPlastico(_m)),
            );
          }),
        ),
      );
}

class _PintorPlastico extends CustomPainter {
  final PlasticoBolha m;
  _PintorPlastico(this.m);

  @override
  void paint(Canvas c, Size s) {
    c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(20)),
        Paint()..color = const Color(0xFF1C3B4A));
    final w = s.width / PlasticoBolha.colunas, h = s.height / PlasticoBolha.linhas;
    final r = min(w, h) * 0.4;
    for (var i = 0; i < m.estouradas.length; i++) {
      final ctr = Offset((i % PlasticoBolha.colunas + 0.5) * w, (i ~/ PlasticoBolha.colunas + 0.5) * h);
      if (m.estouradas[i]) {
        c.drawCircle(ctr, r * 0.9, Paint()..color = Colors.white.withValues(alpha: 0.06));
        c.drawCircle(ctr, r * 0.9,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = Colors.white.withValues(alpha: 0.12));
      } else {
        c.drawCircle(
          ctr,
          r,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.4),
              colors: [Colors.white.withValues(alpha: 0.85), const Color(0xFF8FD6EA).withValues(alpha: 0.35)],
            ).createShader(Rect.fromCircle(center: ctr, radius: r)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// =====================================================================
// 🎨 Mandala Mágica (desenho com simetria)
// =====================================================================
class _Traco {
  final Color cor;
  final List<Offset> pontos = []; // relativos ao centro, normalizados
  _Traco(this.cor);
}

class MandalaScreen extends StatefulWidget {
  const MandalaScreen({super.key});

  @override
  State<MandalaScreen> createState() => _MandalaScreenState();
}

class _MandalaScreenState extends State<MandalaScreen> {
  static const _cores = [
    Color(0xFFFFC23D), Color(0xFF33D69A), Color(0xFF5FD3E8), Color(0xFFB98CF0),
    Color(0xFFFF8FB1), Color(0xFFFFFFFF),
  ];
  final _tracos = <_Traco>[];
  Color _cor = _cores[0];
  int _pontos = 0;
  var _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    Repo.log('jogo_iniciado', {'jogo': 'mandala'});
  }

  Offset _rel(Offset p, Size s) {
    final r = min(s.width, s.height) / 2;
    return Offset((p.dx - s.width / 2) / r, (p.dy - s.height / 2) / r);
  }

  @override
  Widget build(BuildContext context) => _TelaRelaxante(
        titulo: 'Mandala Mágica',
        contador: '',
        fundo: const Color(0xFF0B0F1E),
        extras: [
          IconButton(
            tooltip: 'Desfazer',
            icon: const Icon(Icons.undo),
            onPressed: () => setState(() {
              if (_tracos.isNotEmpty) _tracos.removeLast();
            }),
          ),
          IconButton(
            tooltip: 'Limpar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(_tracos.clear),
          ),
        ],
        aoTerminar: () => _terminar(context, 'mandala', 'Mandala Mágica', min(600, _pontos ~/ 4), _inicio,
            'Que obra! Desenhar devagar ajuda a mente a desacelerar. 🎨',
            () => setState(() {
                  _tracos.clear();
                  _pontos = 0;
                  _inicio = DateTime.now();
                })),
        corpo: Column(children: [
          Expanded(
            child: LayoutBuilder(builder: (_, box) {
              final s = Size(box.maxWidth, box.maxHeight);
              return GestureDetector(
                onPanStart: (d) => setState(() => _tracos.add(_Traco(_cor)..pontos.add(_rel(d.localPosition, s)))),
                onPanUpdate: (d) => setState(() {
                  _tracos.last.pontos.add(_rel(d.localPosition, s));
                  _pontos++;
                }),
                child: CustomPaint(size: s, painter: _PintorMandala(_tracos)),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final c in _cores)
                GestureDetector(
                  onTap: () => setState(() => _cor = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _cor == c ? 44 : 34,
                    height: _cor == c ? 44 : 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: _cor == c ? 3 : 0),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      );
}

class _PintorMandala extends CustomPainter {
  final List<_Traco> tracos;
  _PintorMandala(this.tracos);
  static const _gomos = 8;

  @override
  void paint(Canvas c, Size s) {
    final ctr = Offset(s.width / 2, s.height / 2);
    final r = min(s.width, s.height) / 2;
    final guia = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.06);
    for (final f in [0.3, 0.6, 0.9]) {
      c.drawCircle(ctr, r * f, guia);
    }
    if (tracos.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(
            text: 'Arraste o dedo para desenhar ✨', style: TextStyle(color: Colors.white54, fontSize: 18)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, ctr - Offset(tp.width / 2, -r * 0.95 + 30));
    }
    for (final tr in tracos) {
      if (tr.pontos.length < 2) continue;
      final caminho = Path()..moveTo(tr.pontos.first.dx * r, tr.pontos.first.dy * r);
      for (final p in tr.pontos.skip(1)) {
        caminho.lineTo(p.dx * r, p.dy * r);
      }
      final brilho = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 9
        ..color = tr.cor.withValues(alpha: 0.18);
      final linha = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3
        ..color = tr.cor;
      for (var g = 0; g < _gomos; g++) {
        for (final espelho in [1.0, -1.0]) {
          c.save();
          c.translate(ctr.dx, ctr.dy);
          c.rotate(g * 2 * pi / _gomos);
          c.scale(espelho, 1);
          c.drawPath(caminho, brilho);
          c.drawPath(caminho, linha);
          c.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// =====================================================================
// 🐠 Aquário da Calma
// =====================================================================
class _Peixe {
  Offset pos, vel;
  final String emoji;
  final double fase;
  double satisfeito = 0; // segundos "digerindo" depois de comer (não come de novo na hora)
  _Peixe(this.pos, this.vel, this.emoji, this.fase);
}

/// Comida que cai devagar; só pode ser comida depois de afundar um pouco.
class _Comida {
  Offset pos;
  double idade = 0;
  _Comida(this.pos);
  bool get pronta => idade >= 0.5;
}

class AquarioScreen extends StatefulWidget {
  const AquarioScreen({super.key});

  @override
  State<AquarioScreen> createState() => _AquarioScreenState();
}

class _AquarioScreenState extends State<AquarioScreen> with SingleTickerProviderStateMixin {
  final _rnd = Random();
  final _peixes = <_Peixe>[];
  final _comida = <_Comida>[];
  final _bolhas = <Offset>[];
  final _pintor = PintorEmoji();
  late final Ticker _ticker;
  Duration _ultimo = Duration.zero;
  double _t = 0;
  int _alimentados = 0;
  var _inicio = DateTime.now();
  double _ultimoNhac = -1, _ultimaBolha = 0;
  final _nhacs = <(Offset, double)>[]; // "nhac!" que aparece onde o peixe comeu

  @override
  void initState() {
    super.initState();
    for (final e in ['🐠', '🐟', '🐡', '🐠', '🐟', '🐢']) {
      _peixes.add(_Peixe(Offset(_rnd.nextDouble(), 0.2 + _rnd.nextDouble() * 0.6),
          Offset(_rnd.nextBool() ? 0.06 : -0.06, 0), e, _rnd.nextDouble() * 6));
    }
    _ticker = createTicker(_tick)..start();
    Repo.log('jogo_iniciado', {'jogo': 'aquario'});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration agora) {
    final dt = ((agora - _ultimo).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _ultimo = agora;
    _t += dt;
    for (final c in _comida) {
      c
        ..idade += dt
        ..pos = Offset(c.pos.dx, min(0.95, c.pos.dy + dt * 0.05));
    }
    // cada peixe escolhe uma comida diferente (assim eles não se amontoam todos no mesmo lugar)
    final reservada = <_Comida>{};
    final ordem = [..._peixes]..sort((a, b) => a.satisfeito.compareTo(b.satisfeito));
    final alvos = <_Peixe, _Comida?>{};
    for (final p in ordem) {
      _Comida? melhor;
      if (p.satisfeito <= 0) {
        for (final c in _comida) {
          if (reservada.contains(c)) continue;
          if (melhor == null || (c.pos - p.pos).distance < (melhor.pos - p.pos).distance) melhor = c;
        }
      }
      if (melhor != null) reservada.add(melhor);
      alvos[p] = melhor;
    }
    for (final p in _peixes) {
      p.satisfeito = max(0, p.satisfeito - dt);
      final comida = alvos[p];
      final alvo = comida?.pos ?? Offset(p.pos.dx + p.vel.dx, 0.5 + 0.3 * sin(_t * 0.3 + p.fase));
      final dir = alvo - p.pos;
      final dist = dir.distance;
      final velMax = comida != null ? 0.16 : 0.06;
      var desejo = dist > 0.001 ? dir / dist * velMax : p.vel;
      // espaço pessoal: afasta dos outros peixes muito perto
      for (final o in _peixes) {
        if (identical(o, p)) continue;
        final d = p.pos - o.pos;
        final dd = d.distance;
        if (dd > 0.0001 && dd < 0.12) desejo += d / dd * (0.12 - dd) * 1.6;
      }
      p.vel = Offset.lerp(p.vel, desejo, dt * 1.5)!;
      p.pos += p.vel * dt;
      if (p.pos.dx < 0.05 || p.pos.dx > 0.95) {
        p.vel = Offset(-p.vel.dx, p.vel.dy);
        p.pos = Offset(p.pos.dx.clamp(0.05, 0.95), p.pos.dy);
      }
      p.pos = Offset(p.pos.dx, p.pos.dy.clamp(0.08, 0.92));
      _comida.removeWhere((c) {
        if (p.satisfeito <= 0 && c.pronta && (c.pos - p.pos).distance < 0.045) {
          p.satisfeito = 2.5;
          _alimentados++;
          _bolhas.add(p.pos);
          _comeu(p);
          return true;
        }
        return false;
      });
    }
    for (var i = 0; i < _bolhas.length; i++) {
      _bolhas[i] = Offset(_bolhas[i].dx + sin(_t * 3 + i) * 0.001, _bolhas[i].dy - dt * 0.12);
    }
    _bolhas.removeWhere((b) => b.dy < 0);
    if (_rnd.nextDouble() < dt * 0.8) {
      _bolhas.add(Offset(0.1 + _rnd.nextDouble() * 0.8, 1));
      // de vez em quando, o "blup" de uma bolha subindo
      if (_t - _ultimaBolha > 2.5 && _rnd.nextDouble() < 0.35) {
        _ultimaBolha = _t;
        Musica.efeito(Efeito.aqBolha);
      }
    }
    for (var i = 0; i < _nhacs.length; i++) {
      _nhacs[i] = (_nhacs[i].$1, _nhacs[i].$2 - dt * 1.4);
    }
    _nhacs.removeWhere((n) => n.$2 <= 0);
    setState(() {});
  }

  /// Peixe comeu: som de mastigar (sem empilhar quando vários comem juntos) e "nhac!" na tela.
  void _comeu(_Peixe p) {
    if (_t - _ultimoNhac > 0.18) {
      _ultimoNhac = _t;
      Musica.efeito(Efeito.aqNhac);
      HapticFeedback.lightImpact();
      _nhacs.add((p.pos, 1.0));
    }
    if (_alimentados % 10 == 0) {
      Musica.efeito(Efeito.aqFeliz);
      HapticFeedback.mediumImpact();
    }
  }

  void _alimentar(Offset p, Size s) {
    if (_comida.length >= 12) return; // água cheia de comida: espera os peixes comerem
    Musica.efeito(Efeito.aqPlop);
    HapticFeedback.selectionClick();
    for (var i = 0; i < 2; i++) {
      _comida.add(_Comida(Offset(p.dx / s.width + (_rnd.nextDouble() - 0.5) * 0.06, p.dy / s.height)));
    }
  }

  @override
  Widget build(BuildContext context) => _TelaRelaxante(
        titulo: 'Aquário da Calma',
        contador: '🍤 $_alimentados  ',
        fundo: const Color(0xFF06283D),
        aoTerminar: () => _terminar(context, 'aquario', 'Aquário da Calma', _alimentados * 5, _inicio,
            'Os peixinhos agradecem: $_alimentados petiscos! 🐠',
            () => setState(() {
                  _alimentados = 0;
                  _inicio = DateTime.now();
                })),
        corpo: LayoutBuilder(builder: (_, box) {
          final s = Size(box.maxWidth, box.maxHeight);
          return GestureDetector(
            onTapDown: (d) => _alimentar(d.localPosition, s),
            child: CustomPaint(size: s, painter: _PintorAquario(this)),
          );
        }),
      );
}

class _PintorAquario extends CustomPainter {
  final _AquarioScreenState e;
  _PintorAquario(this.e);

  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B6CA8), Color(0xFF06283D)],
          ).createShader(Offset.zero & s));
    // raios de luz
    final luz = Paint()..color = Colors.white.withValues(alpha: 0.04);
    for (var i = 0; i < 4; i++) {
      final x = s.width * (0.15 + i * 0.25) + sin(e._t * 0.4 + i) * 20;
      c.drawPath(
          Path()
            ..moveTo(x - 20, 0)
            ..lineTo(x + 20, 0)
            ..lineTo(x + 80, s.height)
            ..lineTo(x - 10, s.height)
            ..close(),
          luz);
    }
    // fundo de areia e plantas
    c.drawRect(Rect.fromLTWH(0, s.height * 0.92, s.width, s.height * 0.08), Paint()..color = const Color(0xFFC9B27C));
    for (var i = 0; i < 5; i++) {
      e._pintor.desenhar(c, i.isEven ? '🌿' : '🐚', 34, Offset(s.width * (0.1 + i * 0.2), s.height * 0.9));
    }
    final bolha = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.5);
    for (final b in e._bolhas) {
      c.drawCircle(Offset(b.dx * s.width, b.dy * s.height), 5, bolha);
    }
    final comida = Paint()..color = const Color(0xFFE0A458);
    for (final f in e._comida) {
      c.drawCircle(Offset(f.pos.dx * s.width, f.pos.dy * s.height), 4, comida);
    }
    for (final p in e._peixes) {
      final pos = Offset(p.pos.dx * s.width, p.pos.dy * s.height);
      c.save();
      c.translate(pos.dx, pos.dy);
      if (p.vel.dx > 0) c.scale(-1, 1); // emojis de peixe olham para a esquerda
      e._pintor.desenhar(c, p.emoji, 40, Offset.zero);
      c.restore();
    }
    // "nhac!" subindo onde o peixe comeu
    for (final (pos, vida) in e._nhacs) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'nhac!',
          style: TextStyle(
            color: const Color(0xFFFFE08A).withValues(alpha: vida.clamp(0, 1)),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(pos.dx * s.width - tp.width / 2, pos.dy * s.height - 34 - (1 - vida) * 30));
    }
    if (e._alimentados == 0 && e._comida.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(
            text: 'Toque na água para dar comida 🍤', style: TextStyle(color: Colors.white70, fontSize: 17)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset((s.width - tp.width) / 2, s.height * 0.12));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
