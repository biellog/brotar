import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../config.dart';
import '../../data/musica.dart';
import '../../data/repo.dart';
import '../comum.dart';
import 'motor.dart';
import 'rede.dart';

const _ouro = Color(0xFFFFC23D);
const _rosa = Color(0xFFFF6FA5);
const _ceuTopo = Color(0xFF0B1026);
const _ceuBaixo = Color(0xFF241A4F);

class _Faisca {
  Offset pos, vel; // no mundo
  final Color cor;
  double vida;
  _Faisca(this.pos, this.vel, this.cor, this.vida);
}

class _Texto {
  final Offset pos;
  final String texto;
  final Color cor;
  double vida = 1;
  _Texto(this.pos, this.texto, this.cor);
}

String gerarCodigoSala([Random? r]) {
  const letras = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // sem 0/O, 1/I/L
  final rnd = r ?? Random();
  return List.generate(5, (_) => letras[rnd.nextInt(letras.length)]).join();
}

bool codigoValido(String c) => RegExp(r'^[A-Z0-9]{4,8}$').hasMatch(c);

class BrilhaScreen extends StatefulWidget {
  const BrilhaScreen({super.key});

  @override
  State<BrilhaScreen> createState() => _BrilhaScreenState();
}

class _BrilhaScreenState extends State<BrilhaScreen> with SingleTickerProviderStateMixin {
  final _rnd = Random();
  final _pintor = PintorEmoji();
  late final Ticker _ticker;
  Duration _ultimo = Duration.zero;
  double _t = 0;

  // saguão
  int _onlineGeral = 0;
  void Function()? _pararContagem;

  // jogo
  MotorBrilha? _m;
  RedeBrilha? _rede;
  String _sala = 'geral';
  late final String _meuId = 'p-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_rnd.nextInt(9999)}';
  String _meuNome = 'Vagalume';
  int _minhaCor = coresVagalume[0];
  bool _online = false;
  Offset? _joyOrigem, _joyPonto;
  Offset _direcao = Offset.zero;
  double _proximoEnvio = 0;
  bool _estavaEmDupla = false, _premiado = false, _jogou = false;
  int? _ganhoXp;
  final _faiscas = <_Faisca>[];
  final _textos = <_Texto>[];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _minhaCor = coresVagalume[_rnd.nextInt(coresVagalume.length)];
    _carregarNome();
    RedeBrilha.observarOnline((n) {
      if (mounted) setState(() => _onlineGeral = n);
    }).then((r) => _pararContagem = r.$2);
    Repo.log('jogo_iniciado', {'jogo': 'brilha'});
  }

  Future<void> _carregarNome() async {
    try {
      final p = await Repo.perfil();
      final n = (p?['nome'] as String?)?.trim().split(RegExp(r'\s+')).first;
      if (n != null && n.isNotEmpty && mounted) setState(() => _meuNome = limparNome(n));
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pararContagem?.call();
    _rede?.sair();
    super.dispose();
  }

  // ======================= entrar / sair =======================
  Future<void> _jogar(String sala) async {
    Musica.efeito(Efeito.brRodada);
    HapticFeedback.mediumImpact();
    _pararContagem?.call();
    _pararContagem = null;
    final m = MotorBrilha(sala)..sincronizarRodada(DateTime.now());
    m.entrar(_meuId, _meuNome, _minhaCor, eu: true);
    m.ajustarBots(8);
    final rede = RedeBrilha();
    setState(() {
      _sala = sala;
      _m = m;
      _rede = rede;
      _premiado = MotorBrilha.emIntervalo(DateTime.now()); // entrou no pódio: não conta essa rodada
      _jogou = false;
    });
    Repo.log('brilha_entrou', {'sala': sala == 'geral' ? 'geral' : 'privada'});
    await rede.entrar(
      sala: sala,
      meuId: _meuId,
      meuNome: _meuNome,
      minhaCor: _minhaCor,
      aoReceberPosicoes: (lista) {
        for (final j in lista) {
          if (j.id == _meuId) continue;
          m.posicaoRemota(j.id, j.x, j.y, j.pontos, nome: j.nome, cor: j.cor, robo: j.robo);
        }
      },
      aoReceberLuz: m.coletaRemota,
      aoReceberEmote: m.emote,
      aoMudarPresenca: () {},
      aoMudarConexao: (ok) {
        if (mounted) setState(() => _online = ok);
      },
    );
  }

  Future<void> _sairDaArena() async {
    await _rede?.sair();
    setState(() {
      _m = null;
      _rede = null;
      _online = false;
    });
    RedeBrilha.observarOnline((n) {
      if (mounted) setState(() => _onlineGeral = n);
    }).then((r) => _pararContagem = r.$2);
  }

  // ======================= loop =======================
  void _tick(Duration agora) {
    final dt = ((agora - _ultimo).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _ultimo = agora;
    _t += dt;
    final m = _m;
    if (m != null) _passoJogo(m, dt);
    setState(() {});
  }

  void _passoJogo(MotorBrilha m, double dt) {
    final agora = DateTime.now();
    if (m.sincronizarRodada(agora)) {
      _premiado = false;
      _jogou = false;
      _ganhoXp = null;
      Musica.efeito(Efeito.brRodada);
      _textoNaTela('✨ Nova rodada! ✨', _ouro);
    }
    m.atualizarEstrelas(agora);
    final intervaloAgora = MotorBrilha.emIntervalo(agora);

    // anfitrião = pessoa real com menor id na sala: só ele controla os bots (todos veem os mesmos)
    final reais = {...?_rede?.presentes.keys, _meuId};
    final anfitriao = !_online || reais.reduce((a, b) => a.compareTo(b) < 0 ? a : b) == _meuId;
    if (anfitriao) {
      m.ajustarBots(8, reaisNaSala: reais.length);
    } else {
      m.jogadores.removeWhere((_, j) => j.bot);
    }

    m.moverMeu(_meuId, intervaloAgora ? 0 : _direcao.dx, intervaloAgora ? 0 : _direcao.dy, dt);
    if (_direcao != Offset.zero) _jogou = true;
    final coletas = m.passo(dt, _meuId, pausado: intervaloAgora);
    final eu = m.jogadores[_meuId];
    for (final c in coletas) {
      final meu = c.jogador == _meuId;
      final dono = m.jogadores[c.jogador];
      if (meu || (dono?.bot ?? false)) _rede?.enviarLuz(c.luz.id, c.luz.geracao);
      if (meu && eu != null) {
        _faiscasEm(Offset(eu.x, eu.y), c.luz.estrela ? 28 : 10, c.luz.estrela ? _ouro : Color(eu.cor));
        _textos.add(_Texto(Offset(eu.x, eu.y - 30), c.dupla ? '+${c.ganho} 💞' : '+${c.ganho}', c.luz.estrela ? _ouro : Colors.white));
        if (c.luz.estrela) {
          Musica.efeito(Efeito.tyGema);
          HapticFeedback.mediumImpact();
        } else {
          Musica.efeito([Efeito.brLuz1, Efeito.brLuz2, Efeito.brLuz3][_rnd.nextInt(3)]);
          HapticFeedback.selectionClick();
        }
      }
    }
    if (eu != null) {
      final dupla = m.emDupla(eu);
      if (dupla && !_estavaEmDupla) Musica.efeito(Efeito.brDupla);
      _estavaEmDupla = dupla;
    }
    // envia minha posição (e a dos bots, se sou o anfitrião) 5x por segundo
    _proximoEnvio -= dt;
    if (_proximoEnvio <= 0 && eu != null) {
      _proximoEnvio = 0.2;
      _rede?.enviarPosicoes([eu, if (anfitriao) ...m.jogadores.values.where((j) => j.bot)]);
    }
    // fim da rodada: todo mundo ganha
    if (intervaloAgora && !_premiado) {
      _premiado = true;
      _premiar(m);
    }
    for (final f in _faiscas) {
      f.pos += f.vel * dt;
      f.vel *= (1 - dt * 2.5);
      f.vida -= dt * 1.6;
    }
    _faiscas.removeWhere((f) => f.vida <= 0);
    for (final tx in _textos) {
      tx.vida -= dt * 1.1;
    }
    _textos.removeWhere((tx) => tx.vida <= 0);
  }

  Future<void> _premiar(MotorBrilha m) async {
    final eu = m.jogadores[_meuId];
    if (eu == null || !_jogou) return;
    Musica.efeito(Efeito.tyFilial);
    HapticFeedback.heavyImpact();
    final xp = 10 + min<int>(50, eu.pontos ~/ 3);
    try {
      final antes = ((await Repo.perfil())?['xp'] as num?)?.toInt() ?? 0;
      final depois = await Repo.somarXp(xp, 'jogo');
      await Repo.salvarPartida('brilha', eu.pontos, duracaoRodada);
      if (mounted) setState(() => _ganhoXp = max(0, depois - antes));
    } catch (_) {
      if (mounted) setState(() => _ganhoXp = 0);
    }
  }

  void _faiscasEm(Offset p, int n, Color cor) {
    for (var k = 0; k < n; k++) {
      final a = _rnd.nextDouble() * 2 * pi;
      final v = 60 + _rnd.nextDouble() * 160;
      _faiscas.add(_Faisca(p, Offset(cos(a), sin(a)) * v, cor, 0.6 + _rnd.nextDouble() * 0.5));
    }
  }

  void _textoNaTela(String s, Color cor) {
    final eu = _m?.jogadores[_meuId];
    if (eu != null) _textos.add(_Texto(Offset(eu.x, eu.y - 80), s, cor));
  }

  void _emote(String e) {
    _m?.emote(_meuId, e);
    _rede?.enviarEmote(_meuId, e);
    Musica.efeito(Efeito.bolhaCerta);
    HapticFeedback.lightImpact();
    Repo.log('brilha_emote', {'e': e});
  }

  Future<void> _criarSala() async {
    final codigo = gerarCodigoSala(_rnd);
    await _convidar(codigo);
    _jogar(codigo);
  }

  Future<void> _convidar(String codigo) async {
    Repo.log('compartilhou', {'origem': 'brilha_sala'});
    try {
      await Share.share(
        '🌟 Vem brilhar comigo no Brilha Junto, o jogo online do Fica Sóbrio!\n'
        'Abra o app → Jogos → Brilha Junto → "Entrar com código" e digite: $codigo\n\n'
        'Juntos a gente brilha mais. 💚 Baixe grátis: $linkDownload',
        subject: 'Brilha Junto',
      );
    } catch (_) {}
  }

  Future<void> _entrarComCodigo() async {
    final campo = TextEditingController();
    final codigo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1446),
        title: const Text('🔑 Código da sala'),
        content: TextField(
          controller: campo,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 8,
          style: const TextStyle(fontSize: 28, letterSpacing: 6, fontWeight: FontWeight.w900),
          decoration: const InputDecoration(hintText: 'K7Q2P'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, campo.text.trim().toUpperCase()), child: const Text('Entrar')),
        ],
      ),
    );
    if (codigo == null) return;
    if (!codigoValido(codigo)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código inválido (use 4 a 8 letras e números).')));
      }
      return;
    }
    _jogar(codigo);
  }

  // ======================= interface =======================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _m == null,
      onPopInvokedWithResult: (pop, _) {
        if (!pop) _sairDaArena();
      },
      child: Scaffold(
        backgroundColor: _ceuTopo,
        body: _m == null ? _saguao() : _arena(_m!),
      ),
    );
  }

  Widget _saguao() => Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _PintorCeuSaguao(_t, _pintor))),
        SafeArea(
          child: Column(children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              const Spacer(),
              const BotaoMusica(),
            ]),
            const Spacer(),
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(colors: [Color(0xFFFFE08A), _ouro, _rosa]).createShader(r),
              child: const Text('Brilha Junto',
                  style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
            ),
            const Text('🌟 o jogo online do Fica Sóbrio 🌟', style: TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF06D6A0),
                    boxShadow: [BoxShadow(color: const Color(0xFF06D6A0).withValues(alpha: 0.5 + 0.5 * sin(_t * 4)), blurRadius: 8)],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _onlineGeral > 0
                      ? '$_onlineGeral ${_onlineGeral == 1 ? 'pessoa brilhando' : 'pessoas brilhando'} agora'
                      : 'Seja o primeiro a brilhar agora!',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ]),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                _comoJogar('👆', 'Deslize o dedo para voar'),
                _comoJogar('✨', 'Pegue luzes e estrelas cadentes ⭐ (valem 10)'),
                _comoJogar('💞', 'Voe PERTO de alguém: vocês dois ganham x2'),
                _comoJogar('🏅', 'Rodadas de 2 min. Ninguém perde: todo mundo ganha XP'),
                const SizedBox(height: 18),
                _BotaoGrande(
                  texto: '▶  Jogar agora',
                  sub: 'Arena Geral, com gente do Brasil todo',
                  cores: const [Color(0xFFFFE08A), _ouro, Color(0xFFFF9F1C)],
                  aoTocar: () => _jogar('geral'),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _BotaoGrande(
                      texto: '👥 Sala com amigos',
                      sub: 'cria um código',
                      cores: const [Color(0xFFB98CF0), Color(0xFF7B5CD6)],
                      aoTocar: _criarSala,
                      claro: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BotaoGrande(
                      texto: '🔑 Tenho código',
                      sub: 'entrar na sala',
                      cores: const [Color(0xFF4CC9F0), Color(0xFF3A86FF)],
                      aoTocar: _entrarComCodigo,
                      claro: false,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                const Text(
                  'Quando tem pouca gente, vagalumes 🤖 (bots) completam a sala para ela não ficar vazia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ]),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ]);

  Widget _comoJogar(String emoji, String texto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 14))),
        ]),
      );

  Widget _arena(MotorBrilha m) {
    final eu = m.jogadores[_meuId];
    final agora = DateTime.now();
    final intervalo = MotorBrilha.emIntervalo(agora);
    final resta = MotorBrilha.restante(agora);
    final reais = m.pessoas.length;
    final bots = m.jogadores.length - reais;
    final dupla = eu != null && m.emDupla(eu);
    return LayoutBuilder(builder: (_, box) {
      final tela = Size(box.maxWidth, box.maxHeight);
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => setState(() {
              _joyOrigem = d.localPosition;
              _joyPonto = d.localPosition;
            }),
            onPanUpdate: (d) => setState(() {
              _joyPonto = d.localPosition;
              final v = (d.localPosition - _joyOrigem!) / 60;
              _direcao = v.distance > 1 ? v / v.distance : v;
            }),
            onPanEnd: (_) => setState(() {
              _joyOrigem = null;
              _direcao = Offset.zero;
            }),
            child: CustomPaint(
              painter: _PintorArena(
                m: m,
                meuId: _meuId,
                t: _t,
                pintor: _pintor,
                faiscas: _faiscas,
                textos: _textos,
                joyOrigem: _joyOrigem,
                joyPonto: _joyPonto,
              ),
              size: tela,
            ),
          ),
        ),
        // topo
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(children: [
              Row(children: [
                IconButton(icon: const Icon(Icons.close), onPressed: _sairDaArena),
                _Pilula(intervalo ? '🏅 Pódio' : '⏱️ ${resta ~/ 60}:${(resta % 60).toString().padLeft(2, '0')}',
                    resta <= 10 && !intervalo ? _rosa : Colors.white),
                const SizedBox(width: 6),
                _Pilula('✨ ${eu?.pontos ?? 0}', _ouro),
                const SizedBox(width: 6),
                _Pilula('${m.posicao(_meuId)}º/${m.jogadores.length}', const Color(0xFF4CC9F0)),
                const Spacer(),
                const BotaoMusica(),
              ]),
              Row(children: [
                const SizedBox(width: 8),
                Text(
                  _online
                      ? '🟢 $reais ${reais == 1 ? 'pessoa' : 'pessoas'}${bots > 0 ? ' · 🤖 $bots' : ''}${_sala == 'geral' ? '' : '  ·  sala $_sala'}'
                      : '⚪ offline · só com vagalumes 🤖',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (_sala != 'geral') ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _convidar(_sala),
                    child: const Text('Convidar ↗', style: TextStyle(color: _ouro, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ],
              ]),
              const SizedBox(height: 6),
              _miniRanking(m),
            ]),
          ),
        ),
        if (dupla && !intervalo)
          Positioned(
            top: 150,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.scale(
                scale: 1 + 0.05 * sin(_t * 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_rosa, Color(0xFFB98CF0)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: _rosa.withValues(alpha: 0.5), blurRadius: 16)],
                  ),
                  child: const Text('💞 JUNTOS: luzes valem x2!', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ),
        // emotes
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final e in emotes)
                  GestureDetector(
                    onTap: () => _emote(e),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        if (intervalo) Positioned.fill(child: _podio(m)),
      ]);
    });
  }

  Widget _miniRanking(MotorBrilha m) {
    final r = m.ranking;
    final top = r.take(3).toList();
    final eu = m.jogadores[_meuId];
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var k = 0; k < top.length; k++) _linhaRank(k + 1, top[k]),
          if (eu != null && !top.contains(eu)) _linhaRank(m.posicao(_meuId), eu),
        ]),
      ),
    );
  }

  Widget _linhaRank(int pos, Vagalume j) => Text(
        '${const ['🥇', '🥈', '🥉'].elementAtOrNull(pos - 1) ?? '$posº'} ${j.nome}${j.robo ? ' 🤖' : ''}  ${j.pontos}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: j.eu ? FontWeight.w900 : FontWeight.w600,
          color: j.eu ? _ouro : Colors.white,
        ),
      );

  Widget _podio(MotorBrilha m) {
    final r = m.ranking;
    final eu = m.jogadores[_meuId];
    final proxima = (duracaoRodada + intervalo - MotorBrilha.segundosNaRodada(DateTime.now())).ceil();
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2B1F66), Color(0xFF151036)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _ouro.withValues(alpha: 0.6), width: 2),
          boxShadow: [BoxShadow(color: _ouro.withValues(alpha: 0.25), blurRadius: 30)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🌟 Fim da rodada! 🌟', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (r.length > 1) _degrau(r[1], 2, 70),
            if (r.isNotEmpty) _degrau(r[0], 1, 100),
            if (r.length > 2) _degrau(r[2], 3, 50),
          ]),
          const SizedBox(height: 14),
          if (eu != null)
            Text('Você ficou em ${m.posicao(_meuId)}º com ${eu.pontos} luzes',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            !_jogou
                ? 'Mexa-se na próxima rodada para ganhar XP!'
                : _ganhoXp == null
                    ? 'Somando seu XP...'
                    : _ganhoXp! > 0
                        ? 'Todo mundo ganha! Você ganhou +$_ganhoXp XP 💚'
                        : 'Todo mundo ganha! (limite de XP de jogos de hoje atingido)',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _ouro, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Text('Próxima rodada em ${max(0, proxima)}s', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _convidar(_sala == 'geral' ? gerarCodigoSala(_rnd) : _sala),
                child: const Text('Chamar amigos'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: _sairDaArena, child: const Text('Sair'))),
          ]),
        ]),
      ),
    );
  }

  Widget _degrau(Vagalume j, int pos, double altura) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(const ['🥇', '🥈', '🥉'][pos - 1], style: const TextStyle(fontSize: 28)),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(j.cor),
              boxShadow: [BoxShadow(color: Color(j.cor), blurRadius: 14)],
            ),
          ),
          SizedBox(
            width: 84,
            child: Text('${j.nome}${j.robo ? ' 🤖' : ''}',
                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: j.eu ? _ouro : Colors.white)),
          ),
          Container(
            width: 76,
            height: altura,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(j.cor).withValues(alpha: 0.8), Color(j.cor).withValues(alpha: 0.3)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            alignment: Alignment.center,
            child: Text('${j.pontos}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ),
        ]),
      );
}

class _Pilula extends StatelessWidget {
  final String texto;
  final Color cor;
  const _Pilula(this.texto, this.cor);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cor.withValues(alpha: 0.5)),
        ),
        child: Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.w900)),
      );
}

class _BotaoGrande extends StatelessWidget {
  final String texto, sub;
  final List<Color> cores;
  final VoidCallback aoTocar;
  final bool claro;
  const _BotaoGrande({required this.texto, required this.sub, required this.cores, required this.aoTocar, this.claro = true});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: aoTocar,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: cores),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: cores.last.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
            Text(texto,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: claro ? Colors.black : Colors.white)),
            Text(sub, style: TextStyle(fontSize: 12, color: claro ? Colors.black87 : Colors.white70)),
          ]),
        ),
      );
}

// =====================================================================
// Pintores
// =====================================================================
void _brilho(Canvas c, Offset p, double r, Color cor, {double forca = 1}) {
  c.drawCircle(p, r * 2.6,
      Paint()
        ..shader = RadialGradient(colors: [cor.withValues(alpha: 0.45 * forca), cor.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: p, radius: r * 2.6)));
  c.drawCircle(p, r,
      Paint()
        ..shader = RadialGradient(colors: [Colors.white, cor, cor.withValues(alpha: 0.7)], stops: const [0, 0.5, 1])
            .createShader(Rect.fromCircle(center: p, radius: r)));
}

class _PintorCeuSaguao extends CustomPainter {
  final double t;
  final PintorEmoji pintor;
  _PintorCeuSaguao(this.t, this.pintor);

  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_ceuTopo, _ceuBaixo])
              .createShader(Offset.zero & s));
    for (var i = 0; i < 70; i++) {
      final p = Offset(hashUnit(1, i, 0) * s.width, hashUnit(2, i, 0) * s.height);
      final b = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * 2 + i));
      c.drawCircle(p, 1 + (i % 3) * 0.6, Paint()..color = Colors.white.withValues(alpha: 0.6 * b));
    }
    for (var i = 0; i < 12; i++) {
      final cor = Color(coresVagalume[i % coresVagalume.length]);
      final x = s.width * (0.5 + 0.42 * sin(t * 0.3 + i * 1.7));
      final y = s.height * (0.5 + 0.4 * sin(t * 0.23 + i * 2.3));
      _brilho(c, Offset(x, y), 6 + (i % 3) * 2.0, cor, forca: 0.8);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _PintorArena extends CustomPainter {
  final MotorBrilha m;
  final String meuId;
  final double t;
  final PintorEmoji pintor;
  final List<_Faisca> faiscas;
  final List<_Texto> textos;
  final Offset? joyOrigem, joyPonto;
  _PintorArena({
    required this.m,
    required this.meuId,
    required this.t,
    required this.pintor,
    required this.faiscas,
    required this.textos,
    required this.joyOrigem,
    required this.joyPonto,
  });

  @override
  void paint(Canvas c, Size s) {
    final eu = m.jogadores[meuId];
    final cam = Offset(eu?.x ?? larguraMundo / 2, eu?.y ?? alturaMundo / 2);
    Offset tela(double x, double y) => Offset(x - cam.dx + s.width / 2, y - cam.dy + s.height / 2);
    bool visivel(Offset p, [double margem = 80]) =>
        p.dx > -margem && p.dy > -margem && p.dx < s.width + margem && p.dy < s.height + margem;

    // céu + estrelas com profundidade (paralaxe)
    c.drawRect(Offset.zero & s,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_ceuTopo, _ceuBaixo])
              .createShader(Offset.zero & s));
    for (var camada = 1; camada <= 3; camada++) {
      final fator = 0.15 * camada;
      final paint = Paint()..color = Colors.white.withValues(alpha: 0.2 + 0.15 * camada);
      for (var i = 0; i < 40; i++) {
        final x = (hashUnit(camada, i, 1) * (s.width + 200) - cam.dx * fator) % (s.width + 200) - 100;
        final y = (hashUnit(camada, i, 2) * (s.height + 200) - cam.dy * fator) % (s.height + 200) - 100;
        c.drawCircle(Offset(x, y), 0.6 * camada, paint);
      }
    }
    // borda do mundo
    final borda = Rect.fromPoints(tela(0, 0), tela(larguraMundo, alturaMundo));
    c.drawRRect(RRect.fromRectAndRadius(borda, const Radius.circular(40)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = const Color(0xFF7B5CD6).withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    // grade suave
    final grade = Paint()..color = Colors.white.withValues(alpha: 0.03);
    for (var g = 0.0; g <= larguraMundo; g += 200) {
      c.drawLine(tela(g, 0), tela(g, alturaMundo), grade);
      c.drawLine(tela(0, g), tela(larguraMundo, g), grade);
    }
    // luzes
    for (final l in m.luzes.values) {
      final (lx, ly) = m.posicaoLuz(l);
      final p = tela(lx, ly);
      if (!visivel(p)) continue;
      if (l.estrela) {
        final pulso = 1 + 0.15 * sin(t * 6 + l.id);
        // cauda da estrela cadente
        c.drawLine(p, p + const Offset(-46, -26),
            Paint()
              ..strokeWidth = 6
              ..strokeCap = StrokeCap.round
              ..shader = LinearGradient(colors: [_ouro.withValues(alpha: 0.8), _ouro.withValues(alpha: 0)])
                  .createShader(Rect.fromPoints(p, p + const Offset(-46, -26))));
        _brilho(c, p, 12 * pulso, _ouro);
        pintor.desenhar(c, '⭐', 26 * pulso, p);
      } else {
        final cor = Color(coresVagalume[l.id % coresVagalume.length]);
        _brilho(c, p, 5 + 1.5 * sin(t * 3 + l.id), cor, forca: 0.9);
      }
    }
    // faíscas
    for (final f in faiscas) {
      final p = tela(f.pos.dx, f.pos.dy);
      c.drawCircle(p, 2.5 * f.vida + 0.5, Paint()..color = f.cor.withValues(alpha: f.vida.clamp(0, 1)));
    }
    // vagalumes (o meu por último, por cima)
    final ordem = m.jogadores.values.toList()..sort((a, b) => (a.eu ? 1 : 0) - (b.eu ? 1 : 0));
    for (final j in ordem) {
      final p = tela(j.x, j.y);
      if (!visivel(p, 200)) continue;
      final cor = Color(j.cor);
      // rastro de luz
      for (var k = 0; k < j.trilha.length; k++) {
        final (tx, ty) = j.trilha[k];
        final a = (k + 1) / j.trilha.length;
        c.drawCircle(tela(tx, ty), j.raio * 0.55 * a, Paint()..color = cor.withValues(alpha: 0.35 * a));
      }
      if (j.eu) {
        c.drawCircle(p, j.raio + 8 + 2 * sin(t * 5),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.white.withValues(alpha: 0.7));
      }
      _brilho(c, p, j.raio, cor);
      // asinhas
      final bater = sin(t * 18 + j.cor) * 0.35;
      final asa = Paint()..color = Colors.white.withValues(alpha: 0.55);
      c.save();
      c.translate(p.dx, p.dy);
      for (final lado in [-1.0, 1.0]) {
        c.save();
        c.rotate(lado * (0.6 + bater));
        c.drawOval(Rect.fromCenter(center: Offset(lado * j.raio * 0.9, -j.raio * 0.5), width: j.raio * 0.9, height: j.raio * 0.5), asa);
        c.restore();
      }
      c.restore();
      // nome
      final tp = TextPainter(
        text: TextSpan(
          text: '${j.nome}${j.robo ? ' 🤖' : ''}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: j.eu ? FontWeight.w900 : FontWeight.w600,
            color: j.eu ? _ouro : Colors.white,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, p + Offset(-tp.width / 2, j.raio + 6));
      if (j.emote != null) {
        final b = p + Offset(0, -j.raio - 30);
        c.drawCircle(b, 20, Paint()..color = Colors.white);
        c.drawPath(
            Path()
              ..moveTo(b.dx - 6, b.dy + 16)
              ..lineTo(b.dx + 6, b.dy + 16)
              ..lineTo(b.dx, b.dy + 26)
              ..close(),
            Paint()..color = Colors.white);
        pintor.desenhar(c, j.emote!, 24, b);
      }
    }
    // linha de "juntos" entre mim e quem está perto
    if (eu != null) {
      for (final o in m.jogadores.values) {
        if (o.eu) continue;
        final d2 = (o.x - eu.x) * (o.x - eu.x) + (o.y - eu.y) * (o.y - eu.y);
        if (d2 < raioDupla * raioDupla) {
          c.drawLine(tela(eu.x, eu.y), tela(o.x, o.y),
              Paint()
                ..strokeWidth = 2
                ..color = _rosa.withValues(alpha: 0.35 + 0.25 * sin(t * 8)));
        }
      }
    }
    // textos flutuantes
    for (final tx in textos) {
      final p = tela(tx.pos.dx, tx.pos.dy) - Offset(0, (1 - tx.vida) * 50);
      final tp = TextPainter(
        text: TextSpan(
          text: tx.texto,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: tx.cor.withValues(alpha: tx.vida.clamp(0, 1)),
            shadows: const [Shadow(blurRadius: 6, color: Colors.black)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, p - Offset(tp.width / 2, tp.height / 2));
    }
    // mini mapa
    const mm = 86.0;
    final canto = Offset(s.width - mm - 12, s.height - mm - 80);
    c.drawRRect(RRect.fromRectAndRadius(canto & const Size(mm, mm), const Radius.circular(12)),
        Paint()..color = Colors.black.withValues(alpha: 0.45));
    for (final j in m.jogadores.values) {
      final p = canto + Offset(j.x / larguraMundo * mm, j.y / alturaMundo * mm);
      c.drawCircle(p, j.eu ? 3.5 : 2.2, Paint()..color = j.eu ? Colors.white : Color(j.cor));
    }
    for (final l in m.luzes.values.where((l) => l.estrela)) {
      final (lx, ly) = m.posicaoLuz(l);
      c.drawCircle(canto + Offset(lx / larguraMundo * mm, ly / alturaMundo * mm), 2.5, Paint()..color = _ouro);
    }
    // joystick
    if (joyOrigem != null && joyPonto != null) {
      c.drawCircle(joyOrigem!, 60,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white30);
      final v = joyPonto! - joyOrigem!;
      final ponta = joyOrigem! + (v.distance > 60 ? v / v.distance * 60 : v);
      c.drawCircle(ponta, 22, Paint()..color = Colors.white24);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
