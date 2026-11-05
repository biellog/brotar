import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/musica.dart';
import '../../data/repo.dart';
import '../comum.dart';
import 'mundo.dart';
import 'rede_suco.dart';
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

class _Poeira {
  Offset pos;
  double vida = 1;
  _Poeira(this.pos);
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
  /// Código do império em grupo (null = modo sozinho, com ajudantes).
  final String? codigoGrupo;
  final bool web;
  final String? nome;
  const Tycoon3dScreen({super.key, this.codigoGrupo, this.web = false, this.nome});

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
  final _poeiras = <_Poeira>[];
  bool _pc = false, _skills = false;
  int _abaPc = 0;
  final _inicio = DateTime.now();
  int _coposNoInicio = 0;
  // modo em grupo
  RedeSuco? _rede;
  String _meuId = '', _meuNome = 'Amigo', _nomeImperio = 'Império';
  int _minhaCor = coresAmigos.first;
  bool _anfitriao = true, _presencaOk = false;
  String? _erro;
  double _ultEnvio = 0, _ultMov = 0, _ultSalvoServidor = 0;
  final _eventosDeFora = <Evento>[];
  String? get _codigo => widget.codigoGrupo;
  bool get _grupo => _codigo != null;

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
    _salvar(forcar: true);
    _rede?.sair();
    _ticker.dispose();
    _ciclo.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    if (_grupo) return _carregarGrupo();
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
            content: Text(
              'Seus ajudantes venderam enquanto você estava fora:\n\nR\$ ${v.toStringAsFixed(0)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Recolher 💰'))],
          ),
        );
      }
    }
  }

  // ---------------- império em grupo ----------------
  Future<void> _carregarGrupo() async {
    final codigo = _codigo!;
    try {
      final p = await SharedPreferences.getInstance();
      var id = RedeSuco.idConta ?? p.getString('suco_id');
      if (id == null) {
        id = gerarIdLocal(_rnd);
        await p.setString('suco_id', id);
      }
      _meuId = id;
      _minhaCor = coresAmigos[id.hashCode.abs() % coresAmigos.length];
      _meuNome = widget.nome ?? p.getString('brilha_apelido') ?? 'Amigo';
      if (widget.nome == null && !widget.web) {
        final perfil = await Repo.perfil();
        final n = (perfil?['nome'] as String?)?.trim().split(RegExp(r'\s+')).first;
        if (n != null && n.isNotEmpty) _meuNome = n.length > 16 ? n.substring(0, 16) : n;
      }
      final r = await RedeSuco.abrir(codigo);
      if (r == null) {
        if (mounted) setState(() => _erro = 'Não achei o império $codigo. Confira o código.');
        return;
      }
      _nomeImperio = r.$1;
      _m.grupo = true;
      _m.carregar(r.$2, DateTime.now());
      final lista = p.getStringList('suco_grupos') ?? [];
      lista.removeWhere((e) => e.startsWith('$codigo|'));
      lista.insert(0, '$codigo|$_nomeImperio');
      await p.setStringList('suco_grupos', lista.take(20).toList());
    } catch (e) {
      if (mounted) setState(() => _erro = 'Sem conexão com o servidor. Tente de novo em instantes.');
      return;
    }
    if (!mounted) return;
    _m.espelho = true; // até saber quem roda o jogo
    _coposNoInicio = _m.copos;
    _exibido = _m.dinheiro;
    setState(() => _carregado = true);
    _ticker.start();
    final rede = RedeSuco();
    _rede = rede;
    rede.entrar(
      codigo: codigo,
      meuId: _meuId,
      meuNome: _meuNome,
      minhaCor: _minhaCor,
      entrouEm: DateTime.now().millisecondsSinceEpoch,
      aoReceberEstado: (e) {
        if (_anfitriao) return;
        _eventosDeFora.addAll(_m.aplicarAoVivo(e, _meuId));
      },
      aoReceberMovimento: (id, d) {
        if (_anfitriao && rede.presentes.containsKey(id)) _m.atualizarAmigo(id, d);
      },
      aoReceberAcao: (id, t, k) {
        if (!_anfitriao || !rede.presentes.containsKey(id)) return;
        if (_m.executar(t, k)) _eventosDeFora.add(Evento(TipoEvento.comprou, _m.jogador.x, _m.jogador.y));
      },
      aoMudarPresenca: _decidirAnfitriao,
      aoMudarConexao: (ok) {
        if (!ok) _virar(anfitriao: true); // sem internet: continua jogando aqui
        if (mounted) setState(() {});
      },
    );
    // se a presença não chegar logo, roda o jogo aqui mesmo
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_presencaOk) _virar(anfitriao: true);
    });
  }

  void _decidirAnfitriao() {
    final rede = _rede;
    if (rede == null || !rede.presentes.containsKey(_meuId)) return;
    _presencaOk = true;
    _virar(anfitriao: escolherAnfitriao(rede.presentes.values) == _meuId);
    if (_anfitriao) {
      for (final id in _m.amigos.keys.toList()) {
        if (!rede.presentes.containsKey(id)) _m.removerAmigo(id);
      }
    }
    if (mounted) setState(() {});
  }

  void _virar({required bool anfitriao}) {
    if (_anfitriao == anfitriao && _m.espelho == !anfitriao) return;
    _anfitriao = anfitriao;
    _m.espelho = !anfitriao;
  }

  /// Compra no computador: no celular que roda o jogo é na hora; nos outros, vai pela rede.
  bool _executar(String tipo, String k) {
    if (_grupo && !_anfitriao) {
      _rede?.enviarAcao(_meuId, tipo, k);
      return true;
    }
    return _m.executar(tipo, k);
  }

  Future<void> _convidarGrupo() async {
    final c = _codigo;
    if (c == null) return;
    Repo.log('compartilhou', {'origem': 'imperio_grupo'});
    try {
      await Share.share(mensagemConviteImperio(c, _nomeImperio), subject: 'Império do Suco');
    } catch (_) {}
  }

  void _copiarCodigo() {
    final c = _codigo;
    if (c == null) return;
    Clipboard.setData(ClipboardData(text: c));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Código $c copiado!')));
  }

  Future<void> _salvar({bool forcar = false}) async {
    if (!_carregado) return;
    if (_grupo) {
      if (!_anfitriao || _m.espelho) return;
      if (!forcar && _t - _ultimoSalvo < 14) return;
      _ultimoSalvo = _t;
      await RedeSuco.salvar(_codigo!, _m.paraJson(DateTime.now()));
      return;
    }
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_chave, jsonEncode(_m.paraJson(DateTime.now())));
    } catch (_) {}
  }

  Future<void> _sair() async {
    await _salvar(forcar: true);
    await _rede?.sair();
    final vendidos = _m.copos - _coposNoInicio;
    if (vendidos > 0 && !widget.web) {
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
    final eventos = _m.passo(dt, dx, dy)..addAll(_eventosDeFora);
    _eventosDeFora.clear();
    if (_grupo) _rodarRede();
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
          case TipoEvento.missao:
            Musica.efeito(Efeito.tyMissao);
            HapticFeedback.heavyImpact();
            _confete(Offset(_tela.width / 2, 120), 60);
            _textos.add(
              _Texto(
                Offset(_tela.width / 2, _tela.height * 0.32),
                '✅ ${e.texto}\n+R\$ ${e.valor.toStringAsFixed(0)}  ·  +1 ⭐',
                Colors.white,
              ),
            );
            _salvar();
          case TipoEvento.sentou:
            Musica.efeito(Efeito.tyGema);
            HapticFeedback.mediumImpact();
            _direcao = Offset.zero;
            _joyOrigem = null;
            _pc = true;
          case TipoEvento.poeira:
            _poeiras.add(_Poeira(iso.p(e.x, e.y) + Offset(_rnd.nextDouble() * 10 - 5, 0)));
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
    for (final p in _poeiras) {
      p.vida -= dt * 2.2;
      p.pos += Offset(0, -18 * dt);
    }
    _poeiras.removeWhere((p) => p.vida <= 0);
    if (!_m.sentado && _pc) _pc = false;
    if (!_grupo && _t - _ultimoSalvo > 6) {
      _ultimoSalvo = _t;
      _salvar();
    }
    setState(() {});
  }

  void _rodarRede() {
    final rede = _rede;
    if (rede == null) return;
    if (_anfitriao && !_m.espelho) {
      _m.amigos.removeWhere((_, a) => a.visto > 6);
      if (_m.amigos.isNotEmpty && _t - _ultEnvio > 0.25) {
        _ultEnvio = _t;
        rede.enviarEstado(_m.estadoAoVivo(_meuId, _meuNome, _minhaCor));
      }
      if (_t - _ultSalvoServidor > 15) {
        _ultSalvoServidor = _t;
        _salvar(forcar: true);
      }
    } else if (_t - _ultMov > 0.15) {
      _ultMov = _t;
      final j = _m.jogador;
      rede.enviarMovimento({
        'i': _meuId,
        'x': (j.x * 100).roundToDouble() / 100,
        'y': (j.y * 100).roundToDouble() / 100,
        's': _m.sentado,
        'n': _meuNome,
        'o': _minhaCor,
      });
    }
  }

  void _confete(Offset p, int n) {
    const cores = [Color(0xFFFFC23D), Color(0xFFFF4D8D), Color(0xFF4CC9F0), Color(0xFF7BD389), Color(0xFFB98CF0)];
    for (var k = 0; k < n; k++) {
      final a = _rnd.nextDouble() * 2 * pi;
      final v = 120 + _rnd.nextDouble() * 240;
      _confetes.add(_Confete(p, Offset(cos(a) * v, sin(a) * v - 200), cores[k % cores.length], 1 + _rnd.nextDouble() * 0.6, a));
    }
  }

  void _comprouNoPc(bool ok) {
    if (ok) {
      Musica.efeito(Efeito.tyCompra);
      HapticFeedback.mediumImpact();
      _confete(Offset(_tela.width / 2, _tela.height / 2), 25);
      _salvar();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {});
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
    if (_erro != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF7EC8F2),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🧃', style: TextStyle(fontSize: 56)),
                Text(
                  _erro!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Voltar')),
              ],
            ),
          ),
        ),
      );
    }
    if (!_carregado) {
      return const Scaffold(
        backgroundColor: Color(0xFF7EC8F2),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final carga = _m.jogador.carga.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (pop, _) {
        if (!pop) _sair();
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (_, box) {
            _tela = Size(box.maxWidth, box.maxHeight);
            return Stack(
              key: _chaveRaiz,
              children: [
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
                    child: CustomPaint(painter: _PintorEfeitos(_moedas, _alvoMoedas(), _textos, _confetes, _poeiras)),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                        child: Row(
                          children: [
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
                                child: Text(
                                  '💵 R\$ ${_formatar(_exibido)}',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ),
                            ),
                            const Spacer(),
                            _BotaoSkills(pontos: _m.pontosHabilidade, aoTocar: () => setState(() => _skills = true)),
                            const SizedBox(width: 6),
                            const _FundoBotaoMusica(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _BannerMissao(m: _m),
                      if (_grupo)
                        _FaixaGrupo(
                          nome: _nomeImperio,
                          codigo: _codigo!,
                          online: max(1, _rede?.presentes.length ?? 1),
                          conectado: _rede?.conectado ?? false,
                          copiar: _copiarCodigo,
                          convidar: _convidarGrupo,
                        ),
                      _BarraBoosts(m: _m),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Etiqueta('🥤 $carga/${_m.capacidade}', carga >= _m.capacidade ? _ouro : Colors.white),
                            const SizedBox(width: 8),
                            _grupo
                                ? _Etiqueta('👥 ${1 + _m.amigos.length}', Colors.white)
                                : _Etiqueta('🧑‍🍳 ${_m.ajudantes.length}', Colors.white),
                            const SizedBox(width: 8),
                            _Etiqueta('🏪 ${_m.abertas}/${sucos.length}', Colors.white),
                          ],
                        ),
                      ),
                      if (_t < 8 && _m.copos == 0)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 18),
                          child: Text(
                            '👆 Arraste o dedo para andar  ·  pegue copos na barraca  ·  entregue no CAIXA',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 6)]),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_pc)
                  Positioned.fill(
                    child: _Computador(
                      m: _m,
                      executar: _executar,
                      grupo: _grupo,
                      convidar: _convidarGrupo,
                      aba: _abaPc,
                      trocarAba: (a) => setState(() => _abaPc = a),
                      comprou: _comprouNoPc,
                      levantar: () => setState(() {
                        _m.levantar();
                        _pc = false;
                        _salvar();
                      }),
                    ),
                  ),
                if (_skills && !_pc)
                  Positioned.fill(
                    child: _FundoEscuro(
                      fechar: () => setState(() => _skills = false),
                      child: _PainelSkills(m: _m, executar: _executar, comprou: _comprouNoPc),
                    ),
                  ),
              ],
            );
          },
        ),
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
    child: IconButton(
      icon: Icon(icone, color: Colors.white),
      onPressed: aoTocar,
    ),
  );
}

class _FundoBotaoMusica extends StatelessWidget {
  const _FundoBotaoMusica();

  @override
  Widget build(BuildContext context) => const Material(color: Colors.black38, shape: CircleBorder(), child: BotaoMusica());
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color cor;
  const _Etiqueta(this.texto, this.cor);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
    child: Text(
      texto,
      style: TextStyle(color: cor, fontWeight: FontWeight.w900, fontSize: 15),
    ),
  );
}

class _PintorEfeitos extends CustomPainter {
  final List<_Moeda> moedas;
  final Offset? alvo;
  final List<_Texto> textos;
  final List<_Confete> confetes;
  final List<_Poeira> poeiras;
  _PintorEfeitos(this.moedas, this.alvo, this.textos, this.confetes, this.poeiras);

  @override
  void paint(Canvas c, Size s) {
    for (final p in poeiras) {
      c.drawCircle(p.pos, 4 + (1 - p.vida) * 7, Paint()..color = const Color(0xFFD7C4A3).withValues(alpha: 0.55 * p.vida));
    }
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
      c.drawCircle(
        p,
        r,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFFFF1A8), Color(0xFFFFC23D), Color(0xFFD48806)],
          ).createShader(Rect.fromCircle(center: p, radius: r)),
      );
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
        textAlign: TextAlign.center,
      )..layout();
      tp.paint(c, tx.pos - Offset(tp.width / 2, tp.height / 2 + (1 - tx.vida) * 50));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ---------------- HUD: missão, boosts e habilidades ----------------
class _BannerMissao extends StatelessWidget {
  final Mundo m;
  const _BannerMissao({required this.m});

  @override
  Widget build(BuildContext context) {
    final mi = m.missaoAtual;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ouro.withValues(alpha: 0.6)),
      ),
      child: mi == null
          ? const Text(
              '🏆 Você completou todas as missões! Agora é crescer o império.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '🎯 ${m.missao + 1}/${missoes.length}',
                      style: const TextStyle(color: _ouro, fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mi.texto,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    Text(
                      '${reais3d(mi.premio)} +1⭐',
                      style: const TextStyle(color: Color(0xFFFFE08A), fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: m.progressoMissao,
                    minHeight: 7,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(_ouro),
                  ),
                ),
              ],
            ),
    );
  }
}

class _BarraBoosts extends StatelessWidget {
  final Mundo m;
  const _BarraBoosts({required this.m});

  @override
  Widget build(BuildContext context) {
    final ativos = Boost.values.where(m.ativo).toList();
    if (ativos.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        children: [
          for (final b in ativos)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7B2FF7), Color(0xFFF107A3)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${b.emoji} ${m.boosts[b]!.ceil()}s',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _BotaoSkills extends StatelessWidget {
  final int pontos;
  final VoidCallback aoTocar;
  const _BotaoSkills({required this.pontos, required this.aoTocar});

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Material(
        color: Colors.black38,
        shape: const CircleBorder(),
        child: IconButton(
          icon: const Icon(Icons.auto_awesome, color: _ouro),
          tooltip: 'Habilidades',
          onPressed: aoTocar,
        ),
      ),
      if (pontos > 0)
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(color: Color(0xFFFF4D6D), shape: BoxShape.circle),
            child: Text(
              '$pontos',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ),
    ],
  );
}

class _FundoEscuro extends StatelessWidget {
  final VoidCallback fechar;
  final Widget child;
  const _FundoEscuro({required this.fechar, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: fechar,
    child: Container(
      color: Colors.black54,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: () {},
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
          child: Material(
            color: const Color(0xFF14213D),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: fechar,
                  ),
                ),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PainelSkills extends StatelessWidget {
  final Mundo m;
  final bool Function(String, String) executar;
  final void Function(bool) comprou;
  const _PainelSkills({required this.m, required this.executar, required this.comprou});

  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    children: [
      const Text(
        '⭐ Habilidades',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 4),
      Text(
        'Pontos: ${m.pontosHabilidade}  ·  cada missão completa dá +1 ponto',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFFFE08A), fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      for (final h in Habilidade.values)
        _Linha(
          emoji: h.emoji,
          titulo: h.nome,
          sub: h.efeito,
          nivel: m.nivel(h),
          maxNivel: maxHabilidade,
          preco: m.nivel(h) >= maxHabilidade ? 'MÁX' : '${m.custoHabilidade(h)} ⭐',
          pode: m.nivel(h) < maxHabilidade && m.pontosHabilidade >= m.custoHabilidade(h),
          aoTocar: () => comprou(executar('hab', h.name)),
        ),
    ],
  );
}

/// Uma linha de compra (ícone, nome, nível em bolinhas e botão de preço).
class _Linha extends StatelessWidget {
  final String emoji, titulo, sub, preco;
  final int nivel, maxNivel;
  final bool pode;
  final VoidCallback aoTocar;
  const _Linha({
    required this.emoji,
    required this.titulo,
    required this.sub,
    required this.preco,
    required this.pode,
    required this.aoTocar,
    this.nivel = 0,
    this.maxNivel = 0,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14)),
    child: Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
              ),
              Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              if (maxNivel > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      for (var k = 0; k < maxNivel; k++)
                        Container(
                          width: 12,
                          height: 6,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            color: k < nivel ? _ouro : Colors.white24,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(92, 40),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            backgroundColor: pode ? const Color(0xFF1FAF7A) : Colors.white12,
            foregroundColor: pode ? Colors.white : Colors.white54,
          ),
          onPressed: aoTocar,
          child: Text(preco, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        ),
      ],
    ),
  );
}

// ---------------- computador da gerência ----------------
class _Computador extends StatelessWidget {
  final Mundo m;
  final bool Function(String, String) executar;
  final bool grupo;
  final VoidCallback convidar;
  final int aba;
  final void Function(int) trocarAba;
  final void Function(bool) comprou;
  final VoidCallback levantar;
  const _Computador({
    required this.m,
    required this.executar,
    required this.grupo,
    required this.convidar,
    required this.aba,
    required this.trocarAba,
    required this.comprou,
    required this.levantar,
  });

  static const _abas = ['⚡ Boosts', '🏢 Empresa', '🧑‍🍳 Equipe', '⭐ Skills'];

  @override
  Widget build(BuildContext context) {
    final equipMax = Mundo.maxNivelEquip;
    final itens = switch (aba) {
      0 => [
        for (final b in Boost.values)
          _Linha(
            emoji: b.emoji,
            titulo: b.nome,
            sub: '${b.descricao} · ${b.duracao.toInt()}s${m.ativo(b) ? ' (ativo: ${m.boosts[b]!.ceil()}s)' : ''}',
            preco: reais3d(m.custoBoost(b)),
            pode: m.dinheiro >= m.custoBoost(b),
            aoTocar: () => comprou(executar('boost', b.name)),
          ),
      ],
      1 => [
        for (final e in Melhoria.values)
          _Linha(
            emoji: e.emoji,
            titulo: e.nome,
            sub: e.descricao,
            nivel: m.nivelMelhoria(e),
            maxNivel: e.maxNivel,
            preco: m.nivelMelhoria(e) >= e.maxNivel ? 'FEITO ✓' : reais3d(m.custoMelhoria(e)),
            pode: m.nivelMelhoria(e) < e.maxNivel && m.dinheiro >= m.custoMelhoria(e),
            aoTocar: () => comprou(executar('emp', e.name)),
          ),
      ],
      2 => [
        if (grupo)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                const Text(
                  '👥 No império em grupo não tem ajudante: quem trabalha são os amigos!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(180, 42), backgroundColor: const Color(0xFF1FAF7A)),
                  onPressed: convidar,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Chamar amigo', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          )
        else
          _Linha(
            emoji: '🧑‍🍳',
            titulo: 'Contratar alguém pra trabalhar',
            sub: 'Pega copos e vende sozinho (${m.ajudantes.length}/${Mundo.custosAjudante.length}), até com o app fechado',
            nivel: m.ajudantes.length,
            maxNivel: Mundo.custosAjudante.length,
            preco: m.custoAjudante.isInfinite ? 'EQUIPE ✓' : reais3d(m.custoAjudante),
            pode: m.dinheiro >= m.custoAjudante,
            aoTocar: () => comprou(executar('ajudante', '')),
          ),
        _Linha(
          emoji: '🎒',
          titulo: 'Mochila maior',
          sub: '+2 copos carregados (agora: ${m.capacidade})',
          nivel: m.nivelMochila,
          maxNivel: equipMax,
          preco: m.nivelMochila >= equipMax ? 'MÁX' : reais3d(m.custoMochila),
          pode: m.nivelMochila < equipMax && m.dinheiro >= m.custoMochila,
          aoTocar: () => comprou(executar('mochila', '')),
        ),
        _Linha(
          emoji: '👟',
          titulo: 'Tênis de corrida',
          sub: 'Você anda mais rápido',
          nivel: m.nivelTenis,
          maxNivel: equipMax,
          preco: m.nivelTenis >= equipMax ? 'MÁX' : reais3d(m.custoTenis),
          pode: m.nivelTenis < equipMax && m.dinheiro >= m.custoTenis,
          aoTocar: () => comprou(executar('tenis', '')),
        ),
      ],
      _ => [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Pontos: ${m.pontosHabilidade} ⭐ (ganhe completando missões)',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFFE08A), fontWeight: FontWeight.w700),
          ),
        ),
        for (final h in Habilidade.values)
          _Linha(
            emoji: h.emoji,
            titulo: h.nome,
            sub: h.efeito,
            nivel: m.nivel(h),
            maxNivel: maxHabilidade,
            preco: m.nivel(h) >= maxHabilidade ? 'MÁX' : '${m.custoHabilidade(h)} ⭐',
            pode: m.nivel(h) < maxHabilidade && m.pontosHabilidade >= m.custoHabilidade(h),
            aoTocar: () => comprou(executar('hab', h.name)),
          ),
      ],
    };
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  // moldura do monitor
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF263238),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Color(0x884FC3F7), blurRadius: 30)],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF0D47A1), Color(0xFF0A1931)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              color: Colors.black26,
                              child: Row(
                                children: [
                                  const Text(
                                    '🧃 SucoOS',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '💵 ${reais3d(m.dinheiro)}',
                                    style: const TextStyle(color: _ouro, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 46,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.all(6),
                                children: [
                                  for (var k = 0; k < _abas.length; k++)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(_abas[k]),
                                        selected: aba == k,
                                        onSelected: (_) => trocarAba(k),
                                        selectedColor: _ouro,
                                        labelStyle: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: aba == k ? Colors.black : Colors.white,
                                        ),
                                        backgroundColor: Colors.white10,
                                        showCheckmark: false,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView(padding: const EdgeInsets.fromLTRB(10, 4, 10, 10), children: itens),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // pé do monitor
                  Container(width: 70, height: 14, color: const Color(0xFF37474F)),
                  Container(
                    width: 160,
                    height: 8,
                    decoration: BoxDecoration(color: const Color(0xFF37474F), borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(220, 48), backgroundColor: const Color(0xFFFF9F1C)),
                    onPressed: levantar,
                    icon: const Icon(Icons.directions_walk),
                    label: const Text('Levantar e voltar a vender', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FaixaGrupo extends StatelessWidget {
  final String nome, codigo;
  final int online;
  final bool conectado;
  final VoidCallback copiar, convidar;
  const _FaixaGrupo({
    required this.nome,
    required this.codigo,
    required this.online,
    required this.conectado,
    required this.copiar,
    required this.convidar,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: const Color(0xCC1E3A6E), borderRadius: BorderRadius.circular(14)),
    child: Row(
      children: [
        Icon(Icons.circle, size: 9, color: conectado ? const Color(0xFF7BD389) : Colors.white38),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '👥 $nome · $online online',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        GestureDetector(
          onTap: copiar,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
            child: Text(
              '📋 $codigo',
              style: const TextStyle(color: _ouro, fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: convidar,
          child: const Text(
            'Convidar ↗',
            style: TextStyle(color: _ouro, fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}
