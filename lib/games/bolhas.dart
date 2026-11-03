import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../data/musica.dart';
import '../data/repo.dart';
import '../theme.dart';
import 'comum.dart';

class Bolha {
  double x, y; // 0..1
  final double vel, raio, fase;
  final String emoji;
  final bool ruim;
  Bolha(this.x, this.y, this.vel, this.raio, this.fase, this.emoji, this.ruim);
}

/// Lógica pura: bolhas sobem; toque nas boas, evite as nuvens.
class MotorBolhas {
  static const duracao = 45.0;
  static const boas = ['😊', '💚', '🌸', '✨', '🕊️', '🌿', '🌞', '🎵'];
  final Random _rnd;
  MotorBolhas([Random? rnd]) : _rnd = rnd ?? Random();

  final bolhas = <Bolha>[];
  double tempo = 0;
  double _spawn = 0;
  int pontos = 0;
  int combo = 0;
  bool get acabou => tempo >= duracao;
  int get restante => max(0, (duracao - tempo).ceil());

  void passo(double dt) {
    if (acabou) return;
    tempo += dt;
    _spawn -= dt;
    if (_spawn <= 0) {
      _spawn = max(0.35, 0.8 - tempo / 90);
      final ruim = _rnd.nextDouble() < 0.22;
      bolhas.add(Bolha(
        0.1 + _rnd.nextDouble() * 0.8,
        1.1,
        0.16 + _rnd.nextDouble() * 0.12 + tempo / 400,
        0.055 + _rnd.nextDouble() * 0.03,
        _rnd.nextDouble() * pi * 2,
        ruim ? '⛈️' : boas[_rnd.nextInt(boas.length)],
        ruim,
      ));
    }
    for (final b in bolhas) {
      b.y -= b.vel * dt;
    }
    bolhas.removeWhere((b) => b.y < -0.15);
  }

  /// Toque em (x, y) proporcionais. Retorna 'boa', 'ruim' ou null.
  String? tocar(double x, double y, double proporcao) {
    for (final b in bolhas.reversed) {
      final bx = b.x + sin(tempo * 2 + b.fase) * 0.03;
      final dx = (x - bx);
      final dy = (y - b.y) / proporcao; // corrige a tela não ser quadrada
      if (sqrt(dx * dx + dy * dy) < b.raio * 1.25) {
        bolhas.remove(b);
        if (b.ruim) {
          combo = 0;
          pontos = max(0, pontos - 20);
          return 'ruim';
        }
        combo++;
        pontos += 10 + min(combo, 10) * 2;
        return 'boa';
      }
    }
    return null;
  }
}

class BolhasScreen extends StatefulWidget {
  const BolhasScreen({super.key});

  @override
  State<BolhasScreen> createState() => _BolhasScreenState();
}

class _BolhasScreenState extends State<BolhasScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  MotorBolhas _m = MotorBolhas();
  Duration _ultimo = Duration.zero;
  final _pintor = PintorEmoji();
  bool _fimChamado = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    Musica.tocar();
    Repo.log('jogo_iniciado', {'jogo': 'bolhas'});
  }

  @override
  void dispose() {
    _ticker.dispose();
    Musica.parar();
    super.dispose();
  }

  void _tick(Duration agora) {
    final dt = ((agora - _ultimo).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _ultimo = agora;
    setState(() => _m.passo(dt));
    if (_m.acabou && !_fimChamado) {
      _fimChamado = true;
      _ticker.stop();
      _fim();
    }
  }

  Future<void> _fim() async {
    final denovo = await finalizarPartida(
      context,
      jogo: 'bolhas',
      nomeJogo: 'Bolhas da Calma',
      pontos: _m.pontos,
      duracaoSeg: MotorBolhas.duracao.round(),
    );
    if (!mounted) return;
    if (denovo) {
      setState(() {
        _m = MotorBolhas();
        _ultimo = Duration.zero;
        _fimChamado = false;
      });
      _ticker.start();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071C26),
      body: LayoutBuilder(builder: (context, box) {
        return SizedBox.expand(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final r = _m.tocar(
                d.localPosition.dx / box.maxWidth,
                d.localPosition.dy / box.maxHeight,
                box.maxWidth / box.maxHeight,
              );
              if (r == 'boa') HapticFeedback.selectionClick();
              if (r == 'ruim') HapticFeedback.heavyImpact();
            },
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _PintorBolhas(_m, _pintor))),
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
                      Text('⏱️ ${_m.restante}s', style: const TextStyle(fontSize: 20)),
                      const Spacer(),
                      if (_m.combo >= 3)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text('x${_m.combo}',
                              style: const TextStyle(fontSize: 18, color: Cores.verdeClaro)),
                        ),
                      Text('${_m.pontos}',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w900, color: Cores.ouro)),
                      const BotaoMusica(),
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

class _PintorBolhas extends CustomPainter {
  final MotorBolhas m;
  final PintorEmoji pintor;
  _PintorBolhas(this.m, this.pintor);

  @override
  void paint(Canvas canvas, Size s) {
    for (final b in m.bolhas) {
      final c = Offset((b.x + sin(m.tempo * 2 + b.fase) * 0.03) * s.width, b.y * s.height);
      final r = b.raio * s.width;
      final cor = b.ruim ? const Color(0xFF5B6475) : const Color(0xFF5FD3E8);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: [cor.withValues(alpha: 0.55), cor.withValues(alpha: 0.12)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = cor.withValues(alpha: 0.7),
      );
      pintor.desenhar(canvas, b.emoji, r * 1.0, c);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
