import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../data/musica.dart';
import '../data/repo.dart';
import '../theme.dart';
import 'comum.dart';

// =====================================================================
// Lógica pura do jogo (sem Flutter) — testada em test/
// =====================================================================
enum TipoItem { tempestade, gota, estrela, trevo, coracao }

class Item {
  double x, y; // 0..1 (proporção da tela)
  final double vel;
  final TipoItem tipo;
  final String emoji;
  Item(this.x, this.y, this.vel, this.tipo, this.emoji);
}

class MotorJogo {
  /// Obstáculos: "dias difíceis". Nada de bebida ou cigarro, para não gerar gatilho.
  static const obstaculos = ['⛈️', '⚡', '🌪️', '☄️'];
  static const yJogador = 0.84;

  final Random _rnd;
  MotorJogo([Random? rnd]) : _rnd = rnd ?? Random();

  final itens = <Item>[];
  double jogadorX = 0.5;
  double tempo = 0;
  double _proximoSpawn = 0;
  double _acumPontos = 0;
  int pontos = 0;
  int vidas = 3;
  bool acabou = false;
  String? ultimoEfeito;

  double get dificuldade => 1 + tempo / 25;

  void mover(double dxProporcional) {
    jogadorX = (jogadorX + dxProporcional).clamp(0.08, 0.92);
  }

  void passo(double dt) {
    if (acabou) return;
    tempo += dt;
    ultimoEfeito = null;

    _acumPontos += dt * 10;
    if (_acumPontos >= 1) {
      pontos += _acumPontos.floor();
      _acumPontos -= _acumPontos.floor();
    }

    _proximoSpawn -= dt;
    if (_proximoSpawn <= 0) {
      _proximoSpawn = max(0.25, 0.9 / dificuldade);
      final r = _rnd.nextDouble();
      final (TipoItem tipo, String emoji) = switch (r) {
        < 0.58 => (TipoItem.tempestade, obstaculos[_rnd.nextInt(obstaculos.length)]),
        < 0.80 => (TipoItem.gota, '💧'),
        < 0.90 => (TipoItem.estrela, '⭐'),
        < 0.97 => (TipoItem.trevo, '🍀'),
        _ => (TipoItem.coracao, '❤️'),
      };
      itens.add(Item(0.08 + _rnd.nextDouble() * 0.84, -0.05,
          (0.26 + _rnd.nextDouble() * 0.2) * dificuldade, tipo, emoji));
    }

    itens.removeWhere((it) {
      it.y += it.vel * dt;
      final colidiu = (it.y - yJogador).abs() < 0.045 && (it.x - jogadorX).abs() < 0.09;
      if (colidiu) {
        switch (it.tipo) {
          case TipoItem.tempestade:
            vidas--;
            ultimoEfeito = 'dano';
            if (vidas <= 0) acabou = true;
          case TipoItem.gota:
            pontos += 10;
            ultimoEfeito = 'ponto';
          case TipoItem.estrela:
            pontos += 30;
            ultimoEfeito = 'ponto';
          case TipoItem.trevo:
            pontos += 50;
            ultimoEfeito = 'ponto';
          case TipoItem.coracao:
            vidas = min(3, vidas + 1);
            ultimoEfeito = 'vida';
        }
        return true;
      }
      return it.y > 1.1;
    });
  }
}

// =====================================================================
// Tela
// =====================================================================
class TempestadeScreen extends StatefulWidget {
  const TempestadeScreen({super.key});

  @override
  State<TempestadeScreen> createState() => _TempestadeScreenState();
}

class _TempestadeScreenState extends State<TempestadeScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  MotorJogo _motor = MotorJogo();
  Duration _ultimo = Duration.zero;
  bool _pausado = false;
  bool _flashDano = false;
  final _pintor = PintorEmoji();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    Repo.log('jogo_iniciado', {'jogo': 'tempestade'});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration agora) {
    final dt = ((agora - _ultimo).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _ultimo = agora;
    if (_pausado) return;
    setState(() {
      _motor.passo(dt);
      switch (_motor.ultimoEfeito) {
        case 'dano':
          Musica.efeito(Efeito.erro);
          HapticFeedback.heavyImpact();
          _flashDano = true;
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted) setState(() => _flashDano = false);
          });
        case 'ponto' || 'vida':
          HapticFeedback.selectionClick();
      }
    });
    if (_motor.acabou) {
      _ticker.stop();
      _fim();
    }
  }

  Future<void> _fim() async {
    final denovo = await finalizarPartida(
      context,
      jogo: 'tempestade',
      nomeJogo: 'Desvia da Tempestade',
      pontos: _motor.pontos,
      duracaoSeg: _motor.tempo.round(),
    );
    if (!mounted) return;
    if (denovo) {
      setState(() {
        _motor = MotorJogo();
        _ultimo = Duration.zero;
      });
      _ticker.start();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061A13),
      body: LayoutBuilder(builder: (context, box) {
        // SizedBox.expand garante que o jogo ocupe a TELA INTEIRA
        return SizedBox.expand(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => _motor.mover(d.delta.dx / box.maxWidth),
            onTapDown: (d) => _motor.mover(d.localPosition.dx / box.maxWidth - _motor.jogadorX),
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _PintorJogo(_motor, _pintor))),
              if (_flashDano)
                Positioned.fill(child: ColoredBox(color: Cores.perigo.withValues(alpha: 0.25))),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _motor.acabou = true;
                          _ticker.stop();
                          Navigator.pop(context);
                        },
                      ),
                      Text('❤️' * _motor.vidas + '🤍' * (3 - _motor.vidas),
                          style: const TextStyle(fontSize: 20)),
                      const Spacer(),
                      Text('${_motor.pontos}',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w900, color: Cores.ouro)),
                      const BotaoMusica(),
                      IconButton(
                        icon: Icon(_pausado ? Icons.play_arrow : Icons.pause),
                        onPressed: () => setState(() => _pausado = !_pausado),
                      ),
                    ]),
                  ),
                ),
              ),
              if (_pausado)
                const Center(
                  child: Text('PAUSADO', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                ),
            ]),
          ),
        );
      }),
    );
  }
}

class _PintorJogo extends CustomPainter {
  final MotorJogo m;
  final PintorEmoji pintor;
  _PintorJogo(this.m, this.pintor);

  @override
  void paint(Canvas canvas, Size s) {
    desenharCeu(canvas, s, m.tempo);
    final tamanho = (s.width * 0.1).clamp(30.0, 56.0);
    for (final it in m.itens) {
      pintor.desenhar(canvas, it.emoji, tamanho, Offset(it.x * s.width, it.y * s.height));
    }
    final pos = Offset(m.jogadorX * s.width, MotorJogo.yJogador * s.height);
    canvas.drawCircle(pos, tamanho * 0.9, Paint()..color = Cores.verdeClaro.withValues(alpha: 0.25));
    pintor.desenhar(canvas, '😎', tamanho * 1.25, pos);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
