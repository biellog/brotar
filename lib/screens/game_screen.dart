import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../data/repo.dart';
import '../theme.dart';
import '../widgets/compartilhar.dart';

// =====================================================================
// Aba "Jogo": capa com recorde + botão jogar
// =====================================================================
class JogoTab extends StatefulWidget {
  const JogoTab({super.key});

  @override
  State<JogoTab> createState() => _JogoTabState();
}

class _JogoTabState extends State<JogoTab> {
  int _recorde = 0;

  @override
  void initState() {
    super.initState();
    _atualizar();
  }

  Future<void> _atualizar() async {
    try {
      final r = await Repo.recorde();
      if (mounted) setState(() => _recorde = r);
    } catch (_) {}
  }

  Future<void> _jogar() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GameScreen(), fullscreenDialog: true),
    );
    _atualizar();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        const Text('😎', textAlign: TextAlign.center, style: TextStyle(fontSize: 80)),
        Text('Desvia da Garrafa',
            textAlign: TextAlign.center,
            style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text(
          'Arraste o dedo para desviar das garrafas 🍺🍷🥃 e cigarros 🚬.\n'
          'Pegue água 💧, estrelas ⭐ e corações ❤️.\n'
          'A cada 10 pontos você ganha 1 XP.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Text('🏆', style: TextStyle(fontSize: 30)),
            title: const Text('Seu recorde'),
            trailing: Text('$_recorde',
                style: t.headlineSmall?.copyWith(color: Cores.ouro, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _jogar,
          icon: const Icon(Icons.play_arrow),
          label: const Text('JOGAR'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Por que um jogo? A fissura dura em média 15 a 20 minutos. '
          'Ocupar a mente e as mãos nesse tempo ajuda a onda passar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60),
        ),
      ],
    );
  }
}

// =====================================================================
// Lógica pura do jogo (sem Flutter) — fácil de testar
// =====================================================================
enum TipoItem { garrafa, agua, estrela, coracao }

class Item {
  double x, y; // 0..1 (proporção da tela)
  final double vel;
  final TipoItem tipo;
  final String emoji;
  Item(this.x, this.y, this.vel, this.tipo, this.emoji);
}

class MotorJogo {
  static const _ruins = ['🍺', '🍷', '🥃', '🍾', '🚬'];
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

  double get dificuldade => 1 + tempo / 25; // fica mais rápido com o tempo

  void mover(double dxProporcional) {
    jogadorX = (jogadorX + dxProporcional).clamp(0.06, 0.94);
  }

  void passo(double dt) {
    if (acabou) return;
    tempo += dt;
    ultimoEfeito = null;

    // pontos por sobreviver
    _acumPontos += dt * 10;
    if (_acumPontos >= 1) {
      pontos += _acumPontos.floor();
      _acumPontos -= _acumPontos.floor();
    }

    // gerar itens
    _proximoSpawn -= dt;
    if (_proximoSpawn <= 0) {
      _proximoSpawn = max(0.25, 0.9 / dificuldade);
      final r = _rnd.nextDouble();
      final TipoItem tipo;
      final String emoji;
      if (r < 0.62) {
        tipo = TipoItem.garrafa;
        emoji = _ruins[_rnd.nextInt(_ruins.length)];
      } else if (r < 0.88) {
        tipo = TipoItem.agua;
        emoji = '💧';
      } else if (r < 0.97) {
        tipo = TipoItem.estrela;
        emoji = '⭐';
      } else {
        tipo = TipoItem.coracao;
        emoji = '❤️';
      }
      itens.add(Item(0.06 + _rnd.nextDouble() * 0.88, -0.05,
          (0.28 + _rnd.nextDouble() * 0.2) * dificuldade, tipo, emoji));
    }

    // mover e colidir
    const yJogador = 0.88;
    itens.removeWhere((it) {
      it.y += it.vel * dt;
      final colidiu = (it.y - yJogador).abs() < 0.045 && (it.x - jogadorX).abs() < 0.085;
      if (colidiu) {
        switch (it.tipo) {
          case TipoItem.garrafa:
            vidas--;
            ultimoEfeito = 'dano';
            if (vidas <= 0) acabou = true;
          case TipoItem.agua:
            pontos += 10;
            ultimoEfeito = 'ponto';
          case TipoItem.estrela:
            pontos += 30;
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
// Tela do jogo
// =====================================================================
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  MotorJogo _motor = MotorJogo();
  Duration _ultimo = Duration.zero;
  bool _pausado = false;
  bool _flashDano = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    Repo.log('jogo_iniciado');
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
          HapticFeedback.heavyImpact();
          _flashDano = true;
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted) setState(() => _flashDano = false);
          });
        case 'ponto':
          HapticFeedback.selectionClick();
      }
    });
    if (_motor.acabou) {
      _ticker.stop();
      _fimDeJogo();
    }
  }

  Future<void> _fimDeJogo() async {
    final pontos = _motor.pontos;
    final duracao = _motor.tempo.round();
    var recordeAnterior = 0;
    var xp = 0;
    String? codigo;
    try {
      recordeAnterior = await Repo.recorde();
      await Repo.salvarPartida(pontos, duracao);
      xp = min(pontos ~/ 10, 300);
      if (xp > 0) await Repo.somarXp(xp);
      codigo = (await Repo.perfil())?['codigo_convite'];
    } catch (_) {}
    if (!mounted) return;
    final novoRecorde = pontos > recordeAnterior;
    final denovo = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(novoRecorde ? '🏆 Novo recorde!' : 'Fim de jogo', textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$pontos', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900)),
          const Text('pontos'),
          const SizedBox(height: 8),
          Text('+$xp XP', style: const TextStyle(color: Cores.ouro, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Você ficou $duracao segundos focado em outra coisa. Isso é vitória. 💚',
              textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
            onPressed: () => compartilhar(
              'Fiz $pontos pontos no Desvia da Garrafa! Consegue me passar? 😎',
              codigoConvite: codigo,
              origem: 'jogo',
            ),
            child: const Text('Desafiar amigos'),
          ),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Sair')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('De novo')),
        ],
      ),
    );
    if (!mounted) return;
    if (denovo == true) {
      setState(() {
        _motor = MotorJogo();
        _ultimo = Duration.zero;
      });
      _ticker.start();
      Repo.log('jogo_iniciado');
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061A13),
      body: LayoutBuilder(builder: (context, box) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => _motor.mover(d.delta.dx / box.maxWidth),
          onTapDown: (d) => _motor.mover(d.localPosition.dx / box.maxWidth - _motor.jogadorX),
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _PintorJogo(_motor))),
            if (_flashDano)
              Positioned.fill(child: Container(color: Cores.perigo.withValues(alpha: 0.25))),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _motor.acabou = true;
                      _ticker.stop();
                      Navigator.pop(context);
                    },
                  ),
                  Text('❤️' * _motor.vidas + '🖤' * (3 - _motor.vidas),
                      style: const TextStyle(fontSize: 20)),
                  const Spacer(),
                  Text('${_motor.pontos}',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Cores.ouro)),
                  IconButton(
                    icon: Icon(_pausado ? Icons.play_arrow : Icons.pause),
                    onPressed: () => setState(() => _pausado = !_pausado),
                  ),
                ]),
              ),
            ),
            if (_pausado)
              const Center(child: Text('PAUSADO', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900))),
          ]),
        );
      }),
    );
  }
}

class _PintorJogo extends CustomPainter {
  final MotorJogo m;
  _PintorJogo(this.m);

  static final _cache = <String, TextPainter>{};

  TextPainter _emoji(String e, double tamanho) {
    final chave = '$e$tamanho';
    return _cache.putIfAbsent(chave, () {
      return TextPainter(
        text: TextSpan(text: e, style: TextStyle(fontSize: tamanho)),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  @override
  void paint(Canvas canvas, Size s) {
    // fundo com "estrelas" que descem para dar sensação de movimento
    final p = Paint()..color = Colors.white10;
    for (var i = 0; i < 40; i++) {
      final x = (i * 97 % 100) / 100 * s.width;
      final y = ((i * 53 % 100) / 100 * s.height + m.tempo * 40 * (1 + i % 3)) % s.height;
      canvas.drawCircle(Offset(x, y), 1.5 + i % 2, p);
    }
    final tamanho = (s.width * 0.09).clamp(28.0, 52.0);
    for (final it in m.itens) {
      final tp = _emoji(it.emoji, tamanho);
      tp.paint(canvas, Offset(it.x * s.width - tp.width / 2, it.y * s.height - tp.height / 2));
    }
    // jogador
    final jog = _emoji('😎', tamanho * 1.25);
    final pos = Offset(m.jogadorX * s.width, 0.88 * s.height);
    canvas.drawCircle(pos, tamanho * 0.85, Paint()..color = Cores.verdeClaro.withValues(alpha: 0.25));
    jog.paint(canvas, pos - Offset(jog.width / 2, jog.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
