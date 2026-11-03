import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/musica.dart';
import '../data/repo.dart';
import '../theme.dart';
import 'comum.dart';

/// Lógica pura do jogo da memória (testada em test/).
class MotorMemoria {
  static const simbolos = ['🌱', '🌻', '🌈', '🦋', '🌊', '🍀', '🌙', '☀️'];
  late final List<String> cartas;
  final virada = <int>{};
  final achadas = <int>{};
  int jogadas = 0;

  MotorMemoria([Random? rnd]) {
    cartas = [...simbolos, ...simbolos]..shuffle(rnd ?? Random());
  }

  bool get terminou => achadas.length == cartas.length;

  /// Vira a carta [i]. Retorna 'par', 'erro' ou null (primeira carta do par).
  String? virar(int i) {
    if (achadas.contains(i) || virada.contains(i) || virada.length == 2) return null;
    virada.add(i);
    if (virada.length < 2) return null;
    jogadas++;
    final [a, b] = virada.toList();
    if (cartas[a] == cartas[b]) {
      achadas.addAll(virada);
      virada.clear();
      return 'par';
    }
    return 'erro';
  }

  void desvirar() => virada.clear();

  int pontos(int segundos) => max(100, 1200 - (jogadas - 8) * 30 - segundos * 4);
}

class MemoriaScreen extends StatefulWidget {
  const MemoriaScreen({super.key});

  @override
  State<MemoriaScreen> createState() => _MemoriaScreenState();
}

class _MemoriaScreenState extends State<MemoriaScreen> {
  MotorMemoria _m = MotorMemoria();
  final _relogio = Stopwatch();
  Timer? _timer;
  bool _travado = false;

  @override
  void initState() {
    super.initState();
    _comecar();
  }

  void _comecar() {
    _m = MotorMemoria();
    _relogio
      ..reset()
      ..start();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    Repo.log('jogo_iniciado', {'jogo': 'memoria'});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tocar(int i) async {
    if (_travado) return;
    final abertasAntes = _m.virada.length + _m.achadas.length;
    final r = _m.virar(i);
    if (_m.virada.length + _m.achadas.length != abertasAntes || r != null) {
      Musica.efeito(Efeito.carta); // virou uma carta
    }
    setState(() {});
    if (r == 'par') {
      HapticFeedback.mediumImpact();
      if (_m.terminou) {
        _relogio.stop();
        _timer?.cancel();
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        final seg = _relogio.elapsed.inSeconds;
        final denovo = await finalizarPartida(
          context,
          jogo: 'memoria',
          nomeJogo: 'Memória Zen',
          pontos: _m.pontos(seg),
          duracaoSeg: seg,
          mensagemExtra: 'Você encontrou os 8 pares em ${_m.jogadas} jogadas e $seg segundos. 🧠',
        );
        if (!mounted) return;
        if (denovo) {
          setState(_comecar);
        } else {
          Navigator.pop(context);
        }
      }
    } else if (r == 'erro') {
      _travado = true;
      await Future.delayed(const Duration(milliseconds: 750));
      if (!mounted) return;
      setState(() {
        _m.desvirar();
        _travado = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final seg = _relogio.elapsed.inSeconds;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memória Zen'),
        actions: const [BotaoMusica()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              Text('🔁 ${_m.jogadas} jogadas', style: const TextStyle(fontSize: 18)),
              Text('⏱️ ${seg ~/ 60}:${(seg % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 18)),
              Text('✨ ${_m.achadas.length ~/ 2}/8', style: const TextStyle(fontSize: 18)),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: 16,
                    itemBuilder: (_, i) {
                      final aberta = _m.virada.contains(i) || _m.achadas.contains(i);
                      final achada = _m.achadas.contains(i);
                      return GestureDetector(
                        onTap: () => _tocar(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: aberta ? (achada ? Cores.verde : Cores.card) : Cores.verdeClaro,
                            border: Border.all(
                              color: achada ? Cores.ouro : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                              child: Text(
                                aberta ? _m.cartas[i] : '🌿',
                                key: ValueKey(aberta),
                                style: TextStyle(fontSize: aberta ? 34 : 24),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const Text(
              'Encontre os pares com calma. Respire entre uma jogada e outra.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          ]),
        ),
      ),
    );
  }
}
