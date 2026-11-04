// 🌷 Jardim Mágico: plante, regue arrastando o dedo e colha flores que explodem em pétalas.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../data/musica.dart';
import '../data/repo.dart';
import '../theme.dart';
import 'comum.dart';

// =====================================================================
// Lógica pura (testada em test/)
// =====================================================================
class PlantaMagica {
  final Offset pos; // proporcional (0..1)
  final String flor;
  final bool dourada;
  final double fase;
  double crescimento = 0; // 0..3 → semente, broto, botão, flor
  double pop = 0; // animação de "pop" ao mudar de fase (1 → 0)
  double regadaAte = 0;
  PlantaMagica(this.pos, this.flor, this.dourada, this.fase);

  int get fase3 => crescimento.floor().clamp(0, 3);
  bool get pronta => crescimento >= 3;
}

class Particula {
  Offset pos, vel;
  final Color cor;
  final double vidaMax, tamanho, gravidade;
  final String? emoji;
  double vida;
  Particula(this.pos, this.vel, this.cor, this.vidaMax, this.tamanho,
      {this.gravidade = 0.6, this.emoji})
      : vida = vidaMax;
}

class TextoFlutuante {
  final Offset pos;
  final String texto;
  final Color cor;
  final double tamanho;
  double vida = 1.2;
  TextoFlutuante(this.pos, this.texto, this.cor, this.tamanho);
}

class MotorJardim {
  static const flores = ['🌷', '🌻', '🌼', '🌸', '🌹', '🌺'];
  static const maxPlantas = 18;
  static const cores = [
    Color(0xFFFF6FA5), Color(0xFFFFC23D), Color(0xFFB98CF0),
    Color(0xFF5FD3E8), Color(0xFFFF8A5B), Color(0xFF7BD389),
  ];

  final Random rnd;
  MotorJardim([Random? r]) : rnd = r ?? Random();

  final plantas = <PlantaMagica>[];
  final particulas = <Particula>[];
  final textos = <TextoFlutuante>[];
  double t = 0;
  int pontos = 0;
  int colhidas = 0;
  int combo = 0;
  double _ultimaColheita = -10;
  double florada = 0; // > 0 durante a chuva de pétalas
  double arcoIris = 0; // > 0 depois de uma flor dourada

  /// Ciclo do céu (0..1, 0 = meio-dia, 0.5 = meia-noite), a cada 3 minutos.
  /// O dia e a noite duram bastante; pôr do sol e amanhecer são mais rápidos.
  double get ciclo {
    final f = (t / 180) % 1; // 0..0.45 dia, 0.45..0.55 pôr do sol, 0.55..0.9 noite, 0.9..1 amanhecer
    if (f < 0.45) return f / 0.45 * 0.2;
    if (f < 0.55) return 0.2 + (f - 0.45) / 0.1 * 0.3;
    if (f < 0.9) return 0.5 + (f - 0.55) / 0.35 * 0.3;
    return 0.8 + (f - 0.9) / 0.1 * 0.2;
  }

  /// Toque: colhe uma flor pronta ou planta uma semente na grama.
  /// Retorna 'colheu', 'dourada', 'plantou' ou null.
  String? tocar(Offset p) {
    PlantaMagica? alvo;
    for (final pl in plantas) {
      if (pl.pronta && (pl.pos - p).distance < 0.09) alvo = pl;
    }
    if (alvo != null) return _colher(alvo);
    if (p.dy < 0.42 || p.dy > 0.97) return null; // só na grama
    if (plantas.length >= maxPlantas) return null;
    if (plantas.any((pl) => (pl.pos - p).distance < 0.07)) return null;
    final dourada = rnd.nextDouble() < 0.08;
    plantas.add(PlantaMagica(p, flores[rnd.nextInt(flores.length)], dourada, rnd.nextDouble() * 6.28));
    plantas.sort((a, b) => a.pos.dy.compareTo(b.pos.dy));
    _explosao(p, 8, const Color(0xFF8B5A2B), 0.25, 3); // terra
    return 'plantou';
  }

  /// Regar: plantas perto do dedo crescem mais rápido.
  void regar(Offset p) {
    for (final pl in plantas) {
      if ((pl.pos - p).distance < 0.12) pl.regadaAte = t + 0.4;
    }
    particulas.add(Particula(p + Offset((rnd.nextDouble() - 0.5) * 0.03, 0),
        Offset((rnd.nextDouble() - 0.5) * 0.05, 0.25), const Color(0xFF5FD3E8), 0.6, 4, gravidade: 0.8));
  }

  String _colher(PlantaMagica pl) {
    plantas.remove(pl);
    colhidas++;
    combo = (t - _ultimaColheita < 2.0) ? combo + 1 : 1;
    _ultimaColheita = t;
    final base = pl.dourada ? 50 : 10;
    final ganho = base * combo.clamp(1, 5);
    pontos += ganho;
    _explosao(pl.pos, pl.dourada ? 40 : 22, null, 0.7, 6);
    textos.add(TextoFlutuante(pl.pos - const Offset(0, 0.06),
        combo > 1 ? '+$ganho  x$combo' : '+$ganho', pl.dourada ? Cores.ouro : Colors.white, combo > 1 ? 26 : 22));
    // borboleta sai voando
    particulas.add(Particula(pl.pos, Offset((rnd.nextDouble() - 0.5) * 0.2, -0.22), Colors.white, 2.5, 26,
        gravidade: -0.02, emoji: '🦋'));
    if (pl.dourada) {
      arcoIris = 4;
      _confete();
    }
    if (colhidas % 10 == 0) {
      florada = 4;
      textos.add(TextoFlutuante(const Offset(0.5, 0.3), '🌸 FLORADA! 🌸', Cores.ouro, 34));
    }
    return pl.dourada ? 'dourada' : 'colheu';
  }

  void _explosao(Offset p, int n, Color? cor, double forca, double tam) {
    for (var i = 0; i < n; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      final v = forca * (0.4 + rnd.nextDouble() * 0.6);
      particulas.add(Particula(p, Offset(cos(a) * v * 0.6, sin(a) * v - 0.2),
          cor ?? cores[rnd.nextInt(cores.length)], 0.8 + rnd.nextDouble() * 0.6, tam * (0.6 + rnd.nextDouble())));
    }
  }

  void _confete() {
    for (var i = 0; i < 60; i++) {
      particulas.add(Particula(Offset(rnd.nextDouble(), -0.05 - rnd.nextDouble() * 0.3),
          Offset((rnd.nextDouble() - 0.5) * 0.1, 0.1 + rnd.nextDouble() * 0.2),
          cores[rnd.nextInt(cores.length)], 3, 5, gravidade: 0.05));
    }
  }

  /// Retorna true se alguma planta mudou de fase (para tocar som/vibrar).
  bool passo(double dt) {
    t += dt;
    var mudou = false;
    for (final pl in plantas) {
      final antes = pl.fase3;
      final vel = (pl.regadaAte > t ? 0.9 : 0.28) * (pl.dourada ? 0.8 : 1);
      pl.crescimento = min(3, pl.crescimento + dt * vel);
      if (pl.fase3 != antes) {
        pl.pop = 1;
        mudou = true;
        _explosao(pl.pos - const Offset(0, 0.03), 6, const Color(0xFFFFF3A0), 0.2, 3);
      }
      pl.pop = max(0, pl.pop - dt * 3);
    }
    for (final p in particulas) {
      p.vel = Offset(p.vel.dx, p.vel.dy + p.gravidade * dt);
      p.pos += p.vel * dt;
      p.vida -= dt;
    }
    particulas.removeWhere((p) => p.vida <= 0 || p.pos.dy > 1.1);
    for (final tx in textos) {
      tx.vida -= dt;
    }
    textos.removeWhere((tx) => tx.vida <= 0);
    if (florada > 0) {
      florada -= dt;
      if (rnd.nextDouble() < dt * 25) {
        particulas.add(Particula(Offset(rnd.nextDouble(), -0.03), Offset((rnd.nextDouble() - 0.5) * 0.08, 0.12),
            Colors.white, 4, 20, gravidade: 0.02, emoji: rnd.nextBool() ? '🌸' : '🌼'));
      }
    }
    arcoIris = max(0, arcoIris - dt);
    if (t - _ultimaColheita > 2.0) combo = 0;
    return mudou;
  }
}

// =====================================================================
// Tela
// =====================================================================
class JardimMagicoScreen extends StatefulWidget {
  const JardimMagicoScreen({super.key});

  @override
  State<JardimMagicoScreen> createState() => _JardimMagicoScreenState();
}

class _JardimMagicoScreenState extends State<JardimMagicoScreen> with SingleTickerProviderStateMixin {
  MotorJardim _m = MotorJardim();
  final _pintor = PintorEmoji();
  late final Ticker _ticker;
  Duration _ultimo = Duration.zero;
  var _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    Repo.log('jogo_iniciado', {'jogo': 'jardim'});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration agora) {
    final dt = ((agora - _ultimo).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _ultimo = agora;
    setState(() {
      if (_m.passo(dt)) HapticFeedback.selectionClick();
    });
  }

  void _tocar(Offset p, Size s) {
    final r = _m.tocar(Offset(p.dx / s.width, p.dy / s.height));
    switch (r) {
      case 'plantou':
        Musica.efeito(Efeito.plantar);
        HapticFeedback.lightImpact();
      case 'colheu':
        Musica.efeito(Efeito.bolhaCerta);
        HapticFeedback.mediumImpact();
      case 'dourada':
        Musica.efeito(Efeito.bolhaCerta);
        HapticFeedback.heavyImpact();
    }
  }

  Future<void> _terminar() async {
    final denovo = await finalizarPartida(
      context,
      jogo: 'jardim',
      nomeJogo: 'Jardim Mágico',
      pontos: _m.pontos,
      duracaoSeg: DateTime.now().difference(_inicio).inSeconds,
      mensagemExtra: 'Você colheu ${_m.colhidas} flores. Cuidar de algo também é cuidar de si. 🌷',
    );
    if (!mounted) return;
    if (denovo) {
      setState(() {
        _m = MotorJardim();
        _inicio = DateTime.now();
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(builder: (_, box) {
        final s = Size(box.maxWidth, box.maxHeight);
        return SizedBox.expand(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _tocar(d.localPosition, s),
            onPanUpdate: (d) => _m.regar(Offset(d.localPosition.dx / s.width, d.localPosition.dy / s.height)),
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _PintorJardimMagico(_m, _pintor))),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(children: [
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      Text('🌸 ${_m.colhidas}', style: const TextStyle(fontSize: 18)),
                      const Spacer(),
                      Text('${_m.pontos}',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Cores.ouro,
                              shadows: [Shadow(blurRadius: 6, color: Colors.black54)])),
                      const BotaoMusica(),
                      TextButton(onPressed: _terminar, child: const Text('Terminar')),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }
}

class _PintorJardimMagico extends CustomPainter {
  final MotorJardim m;
  final PintorEmoji pintor;
  _PintorJardimMagico(this.m, this.pintor);

  static const _dia = [Color(0xFF6EC6FF), Color(0xFFB3E5FC)];
  static const _tarde = [Color(0xFFFF8A65), Color(0xFFFFD180)];
  static const _noite = [Color(0xFF0D1B4C), Color(0xFF3A2C6B)];

  List<Color> _ceu(double c) {
    // dia → pôr do sol → noite → amanhecer → dia
    List<Color> mix(List<Color> a, List<Color> b, double k) =>
        [Color.lerp(a[0], b[0], k)!, Color.lerp(a[1], b[1], k)!];
    if (c < 0.25) return mix(_dia, _tarde, c / 0.25);
    if (c < 0.5) return mix(_tarde, _noite, (c - 0.25) / 0.25);
    if (c < 0.75) return mix(_noite, _tarde, (c - 0.5) / 0.25);
    return mix(_tarde, _dia, (c - 0.75) / 0.25);
  }

  @override
  void paint(Canvas c, Size s) {
    Offset px(Offset p) => Offset(p.dx * s.width, p.dy * s.height);
    final ceu = _ceu(m.ciclo);
    final noite = (1 - (m.ciclo - 0.5).abs() * 4).clamp(0.0, 1.0); // 1 à meia-noite
    c.drawRect(Offset.zero & s,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: ceu)
              .createShader(Offset.zero & s));
    // estrelas à noite
    if (noite > 0) {
      final est = Paint()..color = Colors.white.withValues(alpha: 0.8 * noite);
      for (var i = 0; i < 40; i++) {
        final brilho = 0.5 + 0.5 * sin(m.t * 2 + i);
        c.drawCircle(Offset((i * 73 % 100) / 100 * s.width, (i * 37 % 40) / 100 * s.height), 1.2 + brilho, est);
      }
    }
    // sol e lua percorrendo o céu
    final ang = m.ciclo * 2 * pi;
    // sol e lua giram em lados opostos e se escondem atrás das colinas
    pintor.desenhar(c, '☀️', 54,
        Offset(s.width * (0.5 + 0.42 * sin(ang)), s.height * (0.32 - 0.24 * cos(ang))));
    pintor.desenhar(c, '🌙', 46,
        Offset(s.width * (0.5 - 0.42 * sin(ang)), s.height * (0.32 + 0.24 * cos(ang))));
    // arco-íris depois da flor dourada
    if (m.arcoIris > 0) {
      final a = (m.arcoIris / 4).clamp(0.0, 1.0);
      const cores = [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple];
      for (var i = 0; i < cores.length; i++) {
        c.drawArc(
          Rect.fromCircle(center: Offset(s.width / 2, s.height * 0.5), radius: s.width * (0.62 - i * 0.03)),
          pi, pi, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.width * 0.03
            ..color = cores[i].withValues(alpha: 0.55 * a),
        );
      }
    }
    // colinas e grama
    final chao = Path()
      ..moveTo(0, s.height * 0.42)
      ..quadraticBezierTo(s.width * 0.25, s.height * 0.36, s.width * 0.5, s.height * 0.42)
      ..quadraticBezierTo(s.width * 0.75, s.height * 0.48, s.width, s.height * 0.4)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    c.drawPath(chao,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(const Color(0xFF6CCB5F), const Color(0xFF1E4D3A), noite)!,
              Color.lerp(const Color(0xFF2E8B57), const Color(0xFF0E2A20), noite)!,
            ],
          ).createShader(Offset.zero & s));
    if (m.plantas.isEmpty && m.colhidas == 0) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Toque na grama para plantar 🌱\nArraste o dedo para regar 💧\nToque nas flores prontas para colher ✨',
          style: TextStyle(color: Colors.white, fontSize: 17, height: 1.5, fontWeight: FontWeight.w700,
              shadows: [Shadow(blurRadius: 4, color: Colors.black45)]),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: s.width * 0.9);
      tp.paint(c, Offset((s.width - tp.width) / 2, s.height * 0.62));
    }
    // plantas
    for (final pl in m.plantas) {
      final base = px(pl.pos);
      final perto = 0.7 + pl.pos.dy * 0.6; // mais embaixo = mais perto = maior
      final escalaPop = 1 + pl.pop * 0.35;
      final emoji = switch (pl.fase3) {
        0 => '🌰',
        1 => '🌱',
        2 => '🌿',
        _ => pl.dourada ? '🌟' : pl.flor,
      };
      final tam = (pl.fase3 == 3 ? 46.0 : 26.0 + pl.fase3 * 6) * perto * escalaPop;
      if (pl.pronta) {
        // brilho pulsante: "me colha!"
        final pulso = 0.5 + 0.5 * sin(m.t * 5 + pl.fase);
        c.drawCircle(base - Offset(0, tam * 0.45), tam * (0.6 + 0.15 * pulso),
            Paint()
              ..color = (pl.dourada ? Cores.ouro : Colors.white).withValues(alpha: 0.18 + 0.2 * pulso)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      } else if (pl.regadaAte > m.t) {
        c.drawCircle(base - Offset(0, tam * 0.3), tam * 0.5,
            Paint()..color = const Color(0xFF5FD3E8).withValues(alpha: 0.25));
      }
      c.save();
      c.translate(base.dx, base.dy);
      c.rotate(sin(m.t * 1.4 + pl.fase) * 0.07);
      pintor.desenhar(c, emoji, tam, Offset(0, -tam * 0.45));
      c.restore();
      if (!pl.pronta) {
        // barrinha de crescimento
        final w = 30 * perto;
        final r = Rect.fromLTWH(base.dx - w / 2, base.dy + 4, w, 4);
        c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), Paint()..color = Colors.black26);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(r.left, r.top, w * (pl.crescimento / 3), 4), const Radius.circular(2)),
            Paint()..color = Cores.ouro);
      }
    }
    // partículas
    for (final p in m.particulas) {
      final a = (p.vida / p.vidaMax).clamp(0.0, 1.0);
      if (p.emoji != null) {
        pintor.desenhar(c, p.emoji!, p.tamanho, px(p.pos));
      } else {
        c.drawCircle(px(p.pos), p.tamanho * (0.5 + a * 0.5), Paint()..color = p.cor.withValues(alpha: a));
      }
    }
    // textos flutuantes (+10, combo, florada)
    for (final tx in m.textos) {
      final a = (tx.vida / 1.2).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: tx.texto,
          style: TextStyle(
            fontSize: tx.tamanho,
            fontWeight: FontWeight.w900,
            color: tx.cor.withValues(alpha: a),
            shadows: [
              Shadow(blurRadius: 8, color: Colors.black.withValues(alpha: 0.7 * a)),
              Shadow(offset: const Offset(1.5, 1.5), color: Colors.black.withValues(alpha: 0.5 * a)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = px(tx.pos) - Offset(tp.width / 2, (1.2 - tx.vida) * 60);
      tp.paint(c, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
