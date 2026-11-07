import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/musica.dart';
import '../data/repo.dart';
import '../theme.dart';
import 'comum.dart';

/// Níveis da Memória Zen: quantos pares, colunas, quanto tempo para decorar e o bônus de pontos.
enum NivelMemoria {
  facil('Fácil', '🌱', 6, 3, 4.0, 0.6),
  medio('Médio', '🌻', 8, 4, 3.0, 1.0),
  dificil('Difícil', '🔥', 12, 4, 2.5, 1.6),
  impossivel('Impossível', '💀', 18, 6, 1.5, 2.5);

  final String nome, emoji;
  final int pares, colunas;
  final double segundosPrevia, multiplicador;
  const NivelMemoria(this.nome, this.emoji, this.pares, this.colunas, this.segundosPrevia, this.multiplicador);

  int get cartas => pares * 2;
  int get linhas => cartas ~/ colunas;
}

/// Lógica pura do jogo da memória (testada em test/).
class MotorMemoria {
  static const simbolos = ['🌱', '🌻', '🌈', '🦋', '🌊', '🍀', '🌙', '☀️'];
  static const todosSimbolos = [...simbolos, '🐢', '🌸', '🍄', '🐬', '🌵', '🐝', '🍉', '🦜', '⭐', '🐞'];
  final NivelMemoria nivel;
  late final List<String> cartas;
  final virada = <int>{};
  final achadas = <int>{};
  int jogadas = 0;

  MotorMemoria([Random? rnd, this.nivel = NivelMemoria.medio]) {
    final s = todosSimbolos.take(nivel.pares);
    cartas = [...s, ...s]..shuffle(rnd ?? Random());
  }

  bool get terminou => achadas.length == cartas.length;

  /// Vira a carta [i]. Retorna 'par', 'erro' ou null (primeira carta do par).
  String? virar(int i) {
    if (i < 0 || i >= cartas.length || achadas.contains(i) || virada.contains(i) || virada.length == 2) return null;
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

  int pontos(int segundos) =>
      max(100, ((1200 - (jogadas - nivel.pares) * 30 - segundos * 4) * nivel.multiplicador).round());
}

class MemoriaScreen extends StatefulWidget {
  const MemoriaScreen({super.key});

  @override
  State<MemoriaScreen> createState() => _MemoriaScreenState();
}

class _MemoriaScreenState extends State<MemoriaScreen> {
  static const _chaveNivel = 'memoria_nivel';
  NivelMemoria _nivel = NivelMemoria.medio;
  MotorMemoria _m = MotorMemoria();
  final _relogio = Stopwatch();
  Timer? _timer, _timerPrevia;
  bool _travado = true;

  /// Cartas mostradas para decorar no começo (vão desvirando uma a uma).
  final _mostrando = <int>{};
  double _previaResta = 0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final n = NivelMemoria.values.asNameMap()[p.getString(_chaveNivel)];
      if (n != null) _nivel = n;
      if (mounted) setState(_comecar);
    }).catchError((_) {
      if (mounted) setState(_comecar);
    });
  }

  void _comecar() {
    _m = MotorMemoria(null, _nivel);
    _relogio.reset();
    _timer?.cancel();
    _timerPrevia?.cancel();
    _travado = true;
    // 1) todas as cartas viram para cima, 2) contagem para decorar, 3) desviram e o jogo começa
    _mostrando
      ..clear()
      ..addAll(List.generate(_m.cartas.length, (i) => i));
    Musica.efeito(Efeito.carta);
    _previaResta = _nivel.segundosPrevia;
    _timerPrevia = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) return t.cancel();
      setState(() => _previaResta = max(0, _previaResta - 0.1));
      if (_previaResta <= 0) {
        t.cancel();
        _desvirarPrevia();
      }
    });
    Repo.log('jogo_iniciado', {'jogo': 'memoria', 'nivel': _nivel.name});
  }

  /// Desvira as cartas uma a uma (efeito cascata) e libera o jogo.
  void _desvirarPrevia() {
    final ordem = _mostrando.toList();
    var k = 0;
    _timerPrevia = Timer.periodic(Duration(milliseconds: max(25, 420 ~/ ordem.length)), (t) {
      if (!mounted) return t.cancel();
      if (k >= ordem.length) {
        t.cancel();
        setState(() {
          _travado = false;
          _relogio.start();
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
        return;
      }
      if (k % 3 == 0) Musica.efeito(Efeito.carta);
      setState(() => _mostrando.remove(ordem[k++]));
    });
  }

  Future<void> _trocarNivel(NivelMemoria n) async {
    if (n == _nivel && _travado) return;
    HapticFeedback.selectionClick();
    setState(() {
      _nivel = n;
      _comecar();
    });
    try {
      (await SharedPreferences.getInstance()).setString(_chaveNivel, n.name);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerPrevia?.cancel();
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
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        final seg = _relogio.elapsed.inSeconds;
        final denovo = await finalizarPartida(
          context,
          jogo: 'memoria',
          nomeJogo: 'Memória Zen',
          pontos: _m.pontos(seg),
          duracaoSeg: seg,
          mensagemExtra:
              '${_nivel.emoji} ${_nivel.nome}: você encontrou os ${_nivel.pares} pares em ${_m.jogadas} jogadas e $seg segundos. 🧠',
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
      await Future.delayed(Duration(milliseconds: _nivel == NivelMemoria.impossivel ? 550 : 800));
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
    final previa = _mostrando.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memória Zen'),
        actions: const [BotaoMusica()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(children: [
            // níveis
            Row(children: [
              for (final n in NivelMemoria.values)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _trocarNivel(n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: n == _nivel ? (n == NivelMemoria.impossivel ? Cores.perigo : Cores.ouro) : Cores.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(children: [
                        Text(n.emoji, style: const TextStyle(fontSize: 18)),
                        FittedBox(
                          child: Text(n.nome,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13, color: n == _nivel ? Colors.black : Colors.white70)),
                        ),
                      ]),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 10),
            if (previa)
              Column(children: [
                Text(
                  _previaResta > 0 ? '👀 Decore as cartas! ${_previaResta.ceil()}' : '🙈 Escondendo...',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Cores.ouro),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _previaResta / _nivel.segundosPrevia,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Cores.ouro),
                  ),
                ),
              ])
            else
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                Text('🔁 ${_m.jogadas}', style: const TextStyle(fontSize: 18)),
                Text('⏱️ ${seg ~/ 60}:${(seg % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 18)),
                Text('✨ ${_m.achadas.length ~/ 2}/${_nivel.pares}', style: const TextStyle(fontSize: 18)),
              ]),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: _nivel.colunas / _nivel.linhas,
                  child: LayoutBuilder(builder: (_, box) {
                    final lado = box.maxWidth / _nivel.colunas;
                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _nivel.colunas,
                        mainAxisSpacing: _nivel.colunas > 4 ? 6 : 10,
                        crossAxisSpacing: _nivel.colunas > 4 ? 6 : 10,
                      ),
                      itemCount: _m.cartas.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _tocar(i),
                        child: _Carta(
                          simbolo: _m.cartas[i],
                          aberta: _mostrando.contains(i) || _m.virada.contains(i) || _m.achadas.contains(i),
                          achada: _m.achadas.contains(i),
                          tamanho: lado,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Text(
              _nivel == NivelMemoria.impossivel
                  ? '💀 Impossível: 18 pares e só um instante para decorar. Boa sorte!'
                  : 'Encontre os pares com calma. Respire entre uma jogada e outra.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Carta com virada em 3D (gira no eixo vertical).
class _Carta extends StatelessWidget {
  final String simbolo;
  final bool aberta, achada;
  final double tamanho;
  const _Carta({required this.simbolo, required this.aberta, required this.achada, required this.tamanho});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: aberta ? 0 : pi),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        builder: (_, angulo, _) {
          final frente = angulo < pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(angulo),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(frente ? 0 : pi),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(tamanho * 0.18),
                  color: frente ? (achada ? Cores.verde : Cores.card) : Cores.verdeClaro,
                  border: Border.all(color: achada && frente ? Cores.ouro : Colors.transparent, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Center(
                  child: Text(
                    frente ? simbolo : '🌿',
                    style: TextStyle(fontSize: tamanho * (frente ? 0.42 : 0.3)),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
