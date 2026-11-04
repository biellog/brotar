import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/musica.dart';
import '../../data/repo.dart';
import '../comum.dart';
import 'mundo.dart';
import 'render.dart';

const _ouro = Color(0xFFFFC23D);
const _chave = 'tycoon3d_v1';

class _Moeda {
  final Offset de;
  double t = 0;
  _Moeda(this.de);
}

class _Texto {
  final Offset pos;
  final String texto;
  final Color cor;
  double vida = 1;
  _Texto(this.pos, this.texto, this.cor);
}

class _Confete {
  Offset pos, vel;
  final Color cor;
  double vida, giro;
  _Confete(this.pos, this.vel, this.cor, this.vida, this.giro);
}

/// Converte a direção do dedo na TELA para a direção no MAPA isométrico
/// (para o personagem andar exatamente para onde você arrasta).
(double, double) direcaoNoMapa(double telaX, double telaY) {
  final x = telaX * 0.5 + telaY, y = telaY - telaX * 0.5;
  final tam = sqrt(x * x + y * y);
  final forca = sqrt(telaX * telaX + telaY * telaY);
  return tam < 1e-6 ? (0.0, 0.0) : (x / tam * forca, y / tam * forca);
}

/// 🧃 Império do Suco em 3D: ande pela praça, pegue os sucos e venda no balcão.
class Tycoon3dScreen extends StatefulWidget {
  const Tycoon3dScreen({super.key});

  @override
  State<Tycoon3dScreen> createState() => _Tycoon3dScreenState();
}

class _Tycoon3dScreenState extends State<Tycoon3dScreen> with SingleTickerProviderStateMixin {
  final _m = Mundo();
  final _rnd = Random();
  final _pintor = PintorEmoji();
  final _chaveDinheiro = GlobalKey();
  final _chaveRaiz = GlobalKey();
  late final Ticker _ticker;
  late final AppLifecycleListener _ciclo;
  Duration _ultimo = Duration.zero;
  double _t = 0, _ultimoSalvo = 0, _ultimoSomPegar = 0, _pulso = 0, _exibido = 0;
  Offset? _joyOrigem, _joyPonto;
  Offset _direcao = Offset.zero;
  Size _tela = Size.zero;
  bool _carregado = false;
  final _moedas = <_Moeda>[];
  final _textos = <_Texto>[];
  final _confetes = <_Confete>[];
  final _inicio = DateTime.now();
  int _coposNoInicio = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _ciclo = AppLifecycleListener(onHide: _salvar);
    _carregar();
    Repo.log('jogo_iniciado', {'jogo': 'tycoon3d'});
  }

  @override
  void dispose() {
    _salvar();
    _ticker.dispose();
    _ciclo.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    double fora = 0;
    try {
      final p = await SharedPreferences.getInstance();
      final txt = p.getString(_chave);
      if (txt != null) fora = _m.carregar(jsonDecode(txt) as Map<String, dynamic>, DateTime.now());
    } catch (_) {}
    if (!mounted) return;
    _coposNoInicio = _m.copos;
    _exibido = _m.dinheiro;
    setState(() => _carregado = true);
    _ticker.start();
    if (fora > 60) {
      final v = _m.ganhoOffline(fora);
      if (v > 0 && mounted) {
        Musica.efeito(Efeito.tyCaixa);
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('💤 Bem-vindo de volta!', textAlign: TextAlign.center),
            content: Text('Seus ajudantes venderam enquanto você estava fora:\n\nR\$ ${v.toStringAsFixed(0)}',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
            actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Recolher 💰'))],
          ),
        );
      }
    }
  }

  Future<void> _salvar() async {
    if (!_carregado) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_chave, jsonEncode(_m.paraJson(DateTime.now())));
    } catch (_) {}
  }

  Future<void> _sair() async {
    await _salvar();
    final vendidos = _m.copos - _coposNoInicio;
    if (vendidos > 0) {
      try {
        await Repo.salvarPartida('tycoon', min(vendidos * 10, 1000000), DateTime.now().difference(_inicio).inSeconds);
        await Repo.somarXp(min(60, 5 + vendidos ~/ 2), 'jogo');
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context);
  }

  // ---------------- loop ----------------
  void _tick(Duration agora) {
    final dt = ((agora - _ultimo).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _ultimo = agora;
    _t += dt;
    final (dx, dy) = direcaoNoMapa(_direcao.dx, _direcao.dy);
    final eventos = _m.passo(dt, dx, dy);
    if (_tela != Size.zero) {
      final iso = PintorMundo.isoPara(_tela, _m);
      for (final e in eventos) {
        final pos = iso.p(e.x, e.y, 1.2);
        switch (e.tipo) {
          case TipoEvento.pegou:
            if (_t - _ultimoSomPegar > 0.12) {
              _ultimoSomPegar = _t;
              Musica.efeito(Efeito.tyToque);
              HapticFeedback.selectionClick();
            }
          case TipoEvento.vendeu:
            Musica.efeito(Efeito.tyMoeda);
            HapticFeedback.lightImpact();
            _textos.add(_Texto(pos, '+R\$ ${e.valor.toStringAsFixed(e.valor < 10 ? 1 : 0)}', _ouro));
            for (var k = 0; k < 3; k++) {
              _moedas.add(_Moeda(pos + Offset(_rnd.nextDouble() * 20 - 10, _rnd.nextDouble() * 10))..t = -k * 0.06);
            }
          case TipoEvento.abriu:
            Musica.efeito(Efeito.tyFilial);
            HapticFeedback.heavyImpact();
            _confete(pos, 50);
            _textos.add(_Texto(pos - const Offset(0, 30), '${sucos[e.suco].emoji} ${sucos[e.suco].nome} aberta!', Colors.white));
            _salvar();
          case TipoEvento.contratou:
            Musica.efeito(Efeito.tyGerente);
            HapticFeedback.mediumImpact();
            _confete(pos, 30);
            _textos.add(_Texto(pos - const Offset(0, 30), '🧑‍🍳 Ajudante contratado!', Colors.white));
            _salvar();
          case TipoEvento.comprou:
            Musica.efeito(Efeito.tyMarco);
            HapticFeedback.mediumImpact();
            _confete(pos, 20);
        }
      }
    }
    for (final mo in _moedas) {
      mo.t += dt * 1.8;
    }
    if (_moedas.any((mo) => mo.t >= 1)) _pulso = 1;
    _moedas.removeWhere((mo) => mo.t >= 1);
    _pulso = max(0, _pulso - dt * 4);
    _exibido += (_m.dinheiro - _exibido) * min(1, dt * 8);
    if ((_m.dinheiro - _exibido).abs() < 0.05) _exibido = _m.dinheiro;
    for (final tx in _textos) {
      tx.vida -= dt * 0.9;
    }
    _textos.removeWhere((tx) => tx.vida <= 0);
    for (final c in _confetes) {
      c.vel = Offset(c.vel.dx * (1 - dt), c.vel.dy + 500 * dt);
      c.pos += c.vel * dt;
      c.giro += dt * 9;
      c.vida -= dt;
    }
    _confetes.removeWhere((c) => c.vida <= 0);
    if (_t - _ultimoSalvo > 6) {
      _ultimoSalvo = _t;
      _salvar();
    }
    setState(() {});
  }

  void _confete(Offset p, int n) {
    const cores = [Color(0xFFFFC23D), Color(0xFFFF4D8D), Color(0xFF4CC9F0), Color(0xFF7BD389), Color(0xFFB98CF0)];
    for (var k = 0; k < n; k++) {
      final a = _rnd.nextDouble() * 2 * pi;
      final v = 120 + _rnd.nextDouble() * 240;
      _confetes.add(_Confete(p, Offset(cos(a) * v, sin(a) * v - 200), cores[k % cores.length], 1 + _rnd.nextDouble() * 0.6, a));
    }
  }

  Offset? _alvoMoedas() {
    final raiz = _chaveRaiz.currentContext?.findRenderObject() as RenderBox?;
    final box = _chaveDinheiro.currentContext?.findRenderObject() as RenderBox?;
    if (raiz == null || box == null) return null;
    return box.localToGlobal(box.size.center(Offset.zero), ancestor: raiz);
  }

  // ---------------- interface ----------------
  @override
  Widget build(BuildContext context) {
    if (!_carregado) return const Scaffold(backgroundColor: Color(0xFF7EC8F2), body: Center(child: CircularProgressIndicator()));
    final carga = _m.jogador.carga.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (pop, _) {
        if (!pop) _sair();
      },
      child: Scaffold(
        body: LayoutBuilder(builder: (_, box) {
          _tela = Size(box.maxWidth, box.maxHeight);
          return Stack(key: _chaveRaiz, children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => setState(() {
                  _joyOrigem = d.localPosition;
                  _joyPonto = d.localPosition;
                }),
                onPanUpdate: (d) => setState(() {
                  _joyPonto = d.localPosition;
                  final v = (d.localPosition - _joyOrigem!) / 58;
                  _direcao = v.distance > 1 ? v / v.distance : v;
                }),
                onPanEnd: (_) => setState(() {
                  _joyOrigem = null;
                  _direcao = Offset.zero;
                }),
                child: CustomPaint(
                  painter: PintorMundo(m: _m, t: _t, pintor: _pintor, joyOrigem: _joyOrigem, joyPonto: _joyPonto),
                  size: _tela,
                ),
              ),
            ),
            // efeitos (moedas voando até o caixa, textos e confete)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _PintorEfeitos(_moedas, _alvoMoedas(), _textos, _confetes)),
              ),
            ),
            SafeArea(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Row(children: [
                    _BotaoRedondo(icone: Icons.close, aoTocar: _sair),
                    const Spacer(),
                    Transform.scale(
                      scale: 1 + 0.08 * _pulso,
                      child: Container(
                        key: _chaveDinheiro,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)]),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _ouro, width: 2),
                          boxShadow: [BoxShadow(color: _ouro.withValues(alpha: 0.2 + 0.4 * _pulso), blurRadius: 16)],
                        ),
                        child: Text('💵 R\$ ${_formatar(_exibido)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ),
                    const Spacer(),
                    const _FundoBotaoMusica(),
                  ]),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(16)),
                  child: Text(_m.objetivo,
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _Etiqueta('🥤 $carga/${_m.capacidade}', carga >= _m.capacidade ? _ouro : Colors.white),
                    const SizedBox(width: 8),
                    _Etiqueta('🧑‍🍳 ${_m.ajudantes.length}', Colors.white),
                    const SizedBox(width: 8),
                    _Etiqueta('🏪 ${_m.abertas}/${sucos.length}', Colors.white),
                  ]),
                ),
                if (_t < 8 && _m.copos == 0)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 18),
                    child: Text('👆 Arraste o dedo para andar  ·  pegue copos na barraca  ·  entregue no CAIXA',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 6)])),
                  ),
              ]),
            ),
          ]);
        }),
      ),
    );
  }

  static String _formatar(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2)} bi';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(2)} mi';
    if (v >= 1e4) return '${(v / 1e3).toStringAsFixed(1)} mil';
    return v.toStringAsFixed(0);
  }
}

class _BotaoRedondo extends StatelessWidget {
  final IconData icone;
  final VoidCallback aoTocar;
  const _BotaoRedondo({required this.icone, required this.aoTocar});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black38,
        shape: const CircleBorder(),
        child: IconButton(icon: Icon(icone, color: Colors.white), onPressed: aoTocar),
      );
}

class _FundoBotaoMusica extends StatelessWidget {
  const _FundoBotaoMusica();

  @override
  Widget build(BuildContext context) =>
      const Material(color: Colors.black38, shape: CircleBorder(), child: BotaoMusica());
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color cor;
  const _Etiqueta(this.texto, this.cor);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
        child: Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.w900, fontSize: 15)),
      );
}

class _PintorEfeitos extends CustomPainter {
  final List<_Moeda> moedas;
  final Offset? alvo;
  final List<_Texto> textos;
  final List<_Confete> confetes;
  _PintorEfeitos(this.moedas, this.alvo, this.textos, this.confetes);

  @override
  void paint(Canvas c, Size s) {
    final destino = alvo ?? Offset(s.width / 2, 40);
    for (final mo in moedas) {
      if (mo.t < 0) continue;
      final u = Curves.easeIn.transform(mo.t.clamp(0, 1));
      final ctrl = Offset((mo.de.dx + destino.dx) / 2 + 60, min(mo.de.dy, destino.dy) - 80);
      final p = Offset(
        (1 - u) * (1 - u) * mo.de.dx + 2 * (1 - u) * u * ctrl.dx + u * u * destino.dx,
        (1 - u) * (1 - u) * mo.de.dy + 2 * (1 - u) * u * ctrl.dy + u * u * destino.dy,
      );
      final r = 9 - 3 * u;
      c.drawCircle(p + const Offset(1, 2), r, Paint()..color = Colors.black26);
      c.drawCircle(p, r,
          Paint()
            ..shader = const RadialGradient(colors: [Color(0xFFFFF1A8), Color(0xFFFFC23D), Color(0xFFD48806)])
                .createShader(Rect.fromCircle(center: p, radius: r)));
    }
    for (final k in confetes) {
      c.save();
      c.translate(k.pos.dx, k.pos.dy);
      c.rotate(k.giro);
      c.drawRect(const Rect.fromLTWH(-4, -2.5, 8, 5), Paint()..color = k.cor.withValues(alpha: k.vida.clamp(0, 1)));
      c.restore();
    }
    for (final tx in textos) {
      final a = tx.vida.clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: tx.texto,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: tx.cor.withValues(alpha: a),
            shadows: [Shadow(blurRadius: 6, color: Colors.black.withValues(alpha: a))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, tx.pos - Offset(tp.width / 2, tp.height / 2 + (1 - tx.vida) * 50));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
