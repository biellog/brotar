import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
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

  /// Só para a prévia visual (tool/preview_jogo.dart): começa com um agito e numa posição.
  final TipoAgito? agitoPrevia;
  final (double, double)? posicaoPrevia;
  const Tycoon3dScreen({super.key, this.codigoGrupo, this.web = false, this.nome, this.agitoPrevia, this.posicaoPrevia});

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
  double _tremer = 0;
  // modo leve automático: se o celular não aguenta ~38 quadros por segundo, tira detalhes
  bool _leve = false;
  Duration? _ultimoReal;
  double _mediaQuadro = 1 / 60, _tempoLento = 0;
  Area _areaAtual = Area.praca;
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
    // no celular o jogo é deitado (tela de lado) e em tela cheia
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    _carregar();
    Repo.log('jogo_iniciado', {'jogo': 'tycoon3d'});
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations(const []);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
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
    if (widget.agitoPrevia != null) _m.comecarAgito(widget.agitoPrevia!, []);
    if (widget.posicaoPrevia != null) {
      _m.jogador
        ..x = widget.posicaoPrevia!.$1
        ..y = widget.posicaoPrevia!.$2;
    }
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

  void _abrirGrupo() {
    final c = _codigo;
    if (c == null) return;
    final nomes = [for (final p in _rede?.presentes.values ?? const <Presente>[]) p.nome];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14213D),
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '👥 $_nomeImperio',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                nomes.isEmpty ? 'Só você por enquanto' : 'Online: ${nomes.join(', ')}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _copiarCodigo,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _ouro),
                  ),
                  child: Text(
                    '📋 $c',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _ouro, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 4),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Toque no código para copiar',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1FAF7A)),
                onPressed: _convidarGrupo,
                icon: const Icon(Icons.share),
                label: const Text('Convidar amigos (link)', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
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
    if (!_leve && _t > 3) {
      final real = (agora - (_ultimoReal ?? agora)).inMicroseconds / 1e6;
      _mediaQuadro += (real - _mediaQuadro) * 0.05;
      _tempoLento = _mediaQuadro > 1 / 38 ? _tempoLento + real : 0;
      if (_tempoLento > 3) _leve = true;
    }
    _ultimoReal = agora;
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
            if (!_leve) _poeiras.add(_Poeira(iso.p(e.x, e.y) + Offset(_rnd.nextDouble() * 10 - 5, 0)));
          case TipoEvento.combo:
            final nivel = e.valor < 1.25 ? 0 : (e.valor < 1.45 ? 1 : (e.valor < 1.75 ? 2 : 3));
            Musica.efeito([Efeito.tyCombo1, Efeito.tyCombo2, Efeito.tyCombo3, Efeito.tyCombo4][nivel]);
            HapticFeedback.mediumImpact();
            _textos.add(_Texto(pos - const Offset(0, 40), '🔥 ${e.texto}', const Color(0xFFFF7A3D)));
            _confete(pos, 12 + nivel * 8);
          case TipoEvento.agito:
            Musica.efeito(e.suco == TipoAgito.calor.index ? Efeito.tyCalor : Efeito.tyRush);
            HapticFeedback.heavyImpact();
            _tremer = 0.5;
            _confete(Offset(_tela.width / 2, _tela.height * 0.3), 40);
            _textos.add(_Texto(Offset(_tela.width / 2, _tela.height * 0.4), e.texto, Colors.white));
          case TipoEvento.moeda:
            Musica.efeito(Efeito.tyMoeda);
            HapticFeedback.selectionClick();
            _moedas.add(_Moeda(iso.p(e.x, e.y, 0.3)));
            _textos.add(_Texto(iso.p(e.x, e.y, 0.8), '+${reais3d(e.valor)}', _ouro));
          case TipoEvento.fruta:
            Musica.efeito(Efeito.tyBau);
            HapticFeedback.heavyImpact();
            _confete(iso.p(e.x, e.y, 0.5), 60);
            _textos.add(_Texto(iso.p(e.x, e.y, 1.2), e.texto, const Color(0xFFFFE08A)));
          case TipoEvento.vip:
            Musica.efeito(Efeito.tyMarco);
            HapticFeedback.heavyImpact();
            _confete(pos, 50);
            _textos.add(_Texto(pos - const Offset(0, 50), '${e.texto}\n+${reais3d(e.valor)}', const Color(0xFFFFE08A)));
          case TipoEvento.area:
            Musica.efeito(Efeito.tyFilial);
            HapticFeedback.heavyImpact();
            _confete(pos, 70);
            _textos.add(_Texto(Offset(_tela.width / 2, _tela.height * 0.38), '🔓 ${e.texto}', Colors.white));
            _salvar();
          case TipoEvento.colheu:
            if (_t - _ultimoSomPegar > 0.12) {
              _ultimoSomPegar = _t;
              Musica.efeito(Efeito.plantar);
              HapticFeedback.selectionClick();
            }
          case TipoEvento.frutas:
            Musica.efeito(Efeito.tyCaixa);
            HapticFeedback.mediumImpact();
            _confete(pos, 25);
            _textos.add(_Texto(pos - const Offset(0, 30), e.texto, const Color(0xFFB9F6CA)));
          case TipoEvento.pedidoNovo:
            Musica.efeito(Efeito.tyGema);
            _textos.add(_Texto(Offset(_tela.width / 2, _tela.height * 0.4), e.texto, Colors.white));
          case TipoEvento.pedido:
            Musica.efeito(Efeito.tyMarco);
            HapticFeedback.heavyImpact();
            _confete(pos, 40);
            _textos.add(_Texto(pos - const Offset(0, 40), '${e.texto}\n+${reais3d(e.valor)}', _ouro));
            for (var k = 0; k < 5; k++) {
              _moedas.add(_Moeda(pos + Offset(_rnd.nextDouble() * 30 - 15, _rnd.nextDouble() * 10))..t = -k * 0.06);
            }
          case TipoEvento.cidade:
            Musica.efeito(Efeito.tyFilial);
            HapticFeedback.heavyImpact();
            _confete(Offset(_tela.width / 2, _tela.height / 2), 90);
        }
      }
    }
    for (final mo in _moedas) {
      mo.t += dt * 1.8;
    }
    if (_moedas.any((mo) => mo.t >= 1)) _pulso = 1;
    _moedas.removeWhere((mo) => mo.t >= 1);
    _pulso = max(0, _pulso - dt * 4);
    _tremer = max(0, _tremer - dt);
    final area = areaDe(_m.jogador.x, _m.jogador.y);
    if (area != _areaAtual) {
      _areaAtual = area;
      if (_t > 1 && _tela != Size.zero) {
        _textos.add(_Texto(Offset(_tela.width / 2, _tela.height * 0.3), '📍 ${area.emoji} ${area.nome}', Colors.white));
      }
    }
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
    if (_leve) n = n ~/ 3;
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
                      painter: PintorMundo(m: _m, t: _t, pintor: _pintor, joyOrigem: _joyOrigem, joyPonto: _joyPonto, leve: _leve),
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
                            if (_grupo) ...[
                              _BotaoGrupo(
                                conectado: _rede?.conectado ?? false,
                                online: max(1, _rede?.presentes.length ?? 1),
                                aoTocar: _abrirGrupo,
                              ),
                              const SizedBox(width: 6),
                            ],
                            _BotaoSkills(pontos: _m.pontosHabilidade, aoTocar: () => setState(() => _skills = true)),
                            const SizedBox(width: 6),
                            const _FundoBotaoMusica(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: _MissaoCompacta(m: _m)),
                      ),
                      _Pilulas(m: _m, tremer: _tremer),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (carga == 0) _Etiqueta('🥤 0 · ${_m.capacidade} de cada', Colors.white),
                                  for (final e in _m.cargaPorSuco(_m.jogador).entries)
                                    _Etiqueta('${sucos[e.key].emoji} ${e.value}/${_m.capacidade}',
                                        e.value >= _m.capacidade ? _ouro : Colors.white),
                                  _grupo
                                      ? _Etiqueta('👥 ${1 + _m.amigos.length}', Colors.white)
                                      : _Etiqueta('🧑‍🍳 ${_m.ajudantes.length}', Colors.white),
                                  _Etiqueta('🏪 ${_m.abertas}/${sucos.length}', Colors.white),
                                ],
                              ),
                            ),
                            _MiniMapa(m: _m, t: _t),
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
        _Linha(
          emoji: '🌎',
          titulo: 'Cidade nova: ${nomeCidade(m.cidades + 1)}',
          sub: m.podeNovaCidade
              ? 'Recomeça as barracas e o dinheiro, mas TUDO passa a valer +${50 * (m.cidades + 1)}% para sempre. '
                    'Habilidades, empresa e equipamentos continuam.'
              : 'Abra as 8 barracas para poder mudar de cidade (bônus de +50% para sempre).',
          preco: m.podeNovaCidade ? 'Mudar!' : '${m.abertas}/${sucos.length} 🏪',
          pode: m.podeNovaCidade,
          aoTocar: () async {
            if (!m.podeNovaCidade) return comprou(false);
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('🌎 Mudar para ${nomeCidade(m.cidades + 1)}?'),
                content: const Text(
                  'As barracas e o dinheiro recomeçam do zero, mas todos os sucos passam a valer '
                  '+50% a mais para sempre. Habilidades, melhorias da empresa e equipamentos continuam.',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Agora não')),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Mudar!'),
                  ),
                ],
              ),
            );
            if (ok == true) comprou(executar('cidade', ''));
          },
        ),
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

/// Missão numa linha só (com barrinha de progresso).
class _MissaoCompacta extends StatelessWidget {
  final Mundo m;
  const _MissaoCompacta({required this.m});

  @override
  Widget build(BuildContext context) {
    final mi = m.missaoAtual;
    if (mi == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('🎯 ', style: TextStyle(fontSize: 13)),
              Expanded(
                child: Text(
                  mi.texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              Text(
                ' ${reais3d(mi.premio)} +1⭐',
                style: const TextStyle(color: Color(0xFFFFE08A), fontWeight: FontWeight.w800, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: m.progressoMissao,
              minHeight: 4,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(_ouro),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tudo o que está acontecendo agora, em pílulas pequenas numa linha (sem tampar a tela).
class _Pilulas extends StatelessWidget {
  final Mundo m;
  final double tremer;
  const _Pilulas({required this.m, required this.tremer});

  @override
  Widget build(BuildContext context) {
    final area = areaDe(m.jogador.x, m.jogador.y);
    final a = m.agito;
    final vip = m.clientes.where((c) => c.vip && c.estado != EstadoCliente.saindo).firstOrNull;
    final pe = m.pedido;
    final itens = <Widget>[
      _Pilula('📍 ${area.emoji} ${area.nome}${m.cidades > 0 ? ' · +${50 * m.cidades}%' : ''}', const [
        Color(0xCC263238),
        Color(0xCC37474F),
      ]),
      if (a != null)
        Transform.translate(
          offset: Offset(tremer > 0 ? sin(tremer * 60) * 5 * tremer : 0, 0),
          child: _Pilula(
            switch (a) {
              TipoAgito.vip when vip != null => '👑 ${vip.faltam}x ${sucos[vip.quer].emoji} · ${m.agitoResta.ceil()}s',
              TipoAgito.moedas => '🪙 ${m.moedasChao.length} moedas · ${m.agitoResta.ceil()}s',
              _ => '${a.emoji} ${a.nome.replaceAll('!', '')} · ${m.agitoResta.ceil()}s',
            },
            const [Color(0xFFFF4D6D), Color(0xFFFF9F1C)],
          ),
        ),
      for (final b in Boost.values.where(m.ativo))
        _Pilula('${b.emoji} ${m.boosts[b]!.ceil()}s', const [Color(0xFF7B2FF7), Color(0xFFF107A3)]),
      if (m.combo >= 2)
        _Pilula('🔥 x${m.multCombo.toStringAsFixed(1)}', [
          const Color(0xFFFF7A3D).withValues(alpha: 0.5 + 0.5 * (m.comboTempo / Mundo.tempoCombo).clamp(0, 1)),
          const Color(0xFFFF4D00),
        ]),
      if (pe != null)
        _Pilula(
          '📦 ${pe.qtd}${sucos[pe.suco].emoji} → ${destinosParque[pe.destino].$1} ${destinosParque[pe.destino].$2} · ${pe.resta.ceil()}s',
          const [Color(0xFF00897B), Color(0xFF26A69A)],
        ),
      if (m.jogador.frutas > 0)
        _Pilula('🧺 ${m.jogador.frutas}/${m.capacidadeCesta} → depósito', const [Color(0xFF2E7D32), Color(0xFF66BB6A)]),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Wrap(alignment: WrapAlignment.center, spacing: 5, runSpacing: 5, children: itens),
    );
  }
}

class _Pilula extends StatelessWidget {
  final String texto;
  final List<Color> cores;
  const _Pilula(this.texto, this.cores);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: cores),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Text(
      texto,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
    ),
  );
}

class _BotaoGrupo extends StatelessWidget {
  final bool conectado;
  final int online;
  final VoidCallback aoTocar;
  const _BotaoGrupo({required this.conectado, required this.online, required this.aoTocar});

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Material(
        color: Colors.black38,
        shape: const CircleBorder(),
        child: IconButton(
          icon: const Icon(Icons.group, color: Colors.white),
          tooltip: 'Império em grupo',
          onPressed: aoTocar,
        ),
      ),
      Positioned(
        right: -2,
        top: -2,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: conectado ? const Color(0xFF1FAF7A) : Colors.grey, shape: BoxShape.circle),
          child: Text(
            '$online',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    ],
  );
}

/// Mapa pequeno do mundo (as 4 áreas, você, amigos, pedido e depósito).
class _MiniMapa extends StatelessWidget {
  final Mundo m;
  final double t;
  const _MiniMapa({required this.m, required this.t});

  @override
  Widget build(BuildContext context) => Container(
    width: 112,
    height: 64,
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(12)),
    child: CustomPaint(painter: _PintorMiniMapa(m, t)),
  );
}

class _PintorMiniMapa extends CustomPainter {
  final Mundo m;
  final double t;
  _PintorMiniMapa(this.m, this.t);

  static const _cores = {
    Area.praca: Color(0xFFF2E3C6),
    Area.pomar: Color(0xFF7CC66B),
    Area.praia: Color(0xFFF5DEB3),
    Area.parque: Color(0xFFB98CF0),
  };

  @override
  void paint(Canvas c, Size s) {
    final k = (s.width - 12) / (larguraMapa * 2);
    Offset p(double x, double y) => Offset(s.width / 2 + (x - y) * k, 4 + (x + y) * k / 2);
    for (final a in Area.values) {
      final cor = m.aberta(a) ? _cores[a]! : const Color(0xFF616161);
      c.drawPath(
        Path()..addPolygon([p(a.x0, a.y0), p(a.x1, a.y0), p(a.x1, a.y1), p(a.x0, a.y1)], true),
        Paint()..color = cor.withValues(alpha: 0.9),
      );
      if (!m.aberta(a)) {
        final tp = TextPainter(
          text: const TextSpan(text: '🔒', style: TextStyle(fontSize: 9)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, p((a.x0 + a.x1) / 2, (a.y0 + a.y1) / 2) - Offset(tp.width / 2, tp.height / 2));
      }
    }
    if (m.aberta(Area.praia)) {
      c.drawPath(
        Path()..addPolygon([p(marX, 2), p(larguraMapa, 2), p(larguraMapa, 16.25), p(marX, 16.25)], true),
        Paint()..color = const Color(0xFF4FC3F7),
      );
    }
    final brilho = 0.5 + 0.5 * sin(t * 6);
    final pe = m.pedido;
    if (pe != null) {
      final d = destinosParque[pe.destino];
      c.drawCircle(p(d.$3, d.$4), 3 + 2 * brilho, Paint()..color = const Color(0xFF26A69A));
    }
    if (m.jogador.frutas > 0) {
      c.drawCircle(p(depositoFrutas.x, depositoFrutas.y), 3 + 2 * brilho, Paint()..color = const Color(0xFF2E7D32));
    }
    for (final a in m.amigos.values) {
      c.drawCircle(p(a.x, a.y), 2.6, Paint()..color = Color(a.cor));
    }
    c.drawCircle(p(m.jogador.x, m.jogador.y), 3.4, Paint()..color = Colors.white);
    c.drawCircle(p(m.jogador.x, m.jogador.y), 2.4, Paint()..color = const Color(0xFFFF9F1C));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
