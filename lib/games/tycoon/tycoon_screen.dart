import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/musica.dart';
import '../../data/repo.dart';
import '../comum.dart';
import 'motor.dart';
import 'pintores.dart';

const ouro = Color(0xFFFFC23D);
const laranja = Color(0xFFFF9F1C);
const rosa = Color(0xFFFF4D8D);
const fundoEscuro = Color(0xFF140B05);
const cartao = Color(0xFF26180C);
const _chaveSalvo = 'tycoon_suco_v1';

Color corDe(int i) => Color(produtos[i].cor);

/// Moeda voando do suco até o caixa.
class _Moeda {
  final Offset de, para;
  double t;
  _Moeda(this.de, this.para, this.t);
}

class _ClienteRush {
  Offset pos; // proporcional dentro da área do rush
  final Offset vel;
  final String emoji;
  final bool dourado;
  double vida = 0;
  _ClienteRush(this.pos, this.vel, this.emoji, this.dourado);
}

class _Texto {
  final Offset pos; // em pixels, na tela
  final String texto;
  final Color cor;
  final double tamanho;
  double vida = 1;
  _Texto(this.pos, this.texto, this.cor, this.tamanho);
}

class TycoonScreen extends StatefulWidget {
  const TycoonScreen({super.key});

  @override
  State<TycoonScreen> createState() => _TycoonScreenState();
}

class _TycoonScreenState extends State<TycoonScreen> with SingleTickerProviderStateMixin {
  static const _pessoas = ['🧑', '👩', '👨', '👵', '🧔', '👧', '👦', '🧓', '👱'];
  final _m = MotorTycoon();
  final _rnd = Random();
  final _pintor = PintorEmoji();
  final _calcada = <ClienteCalcada>[];
  final _moedas = <_Moeda>[];
  final _rushClientes = <_ClienteRush>[];
  final _textos = <_Texto>[];
  final _confetes = <Confete>[];
  final _chaveRaiz = GlobalKey();
  final _chaveDinheiro = GlobalKey();
  final _chaveRush = GlobalKey();
  final _chavesIcone = List.generate(produtos.length, (_) => GlobalKey());
  late final Ticker _ticker;
  late final AppLifecycleListener _ciclo;
  Duration _ultimo = Duration.zero;
  double _t = 0, _ultimoSomMoeda = 0, _ultimoSalvo = 0, _proximoCliente = 0, _proximoRush = 0;
  double _exibido = 0, _pulso = 0, _ultimaChecagem = 0;
  bool _estavaNoRush = false, _estavaNoCalor = false;
  int _rushAtendidos = 0;
  double _rushGanho = 0;
  int _modo = 1;
  bool _carregado = false;
  final _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _ciclo = AppLifecycleListener(onHide: _salvar, onShow: _voltouDoSegundoPlano);
    _carregar();
    Repo.log('jogo_iniciado', {'jogo': 'tycoon'});
  }

  @override
  void dispose() {
    _salvar();
    _ticker.dispose();
    _ciclo.dispose();
    super.dispose();
  }

  // ======================= salvar / carregar =======================
  Future<void> _carregar() async {
    double fora = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final txt = prefs.getString(_chaveSalvo);
      if (txt != null) fora = _m.carregar(jsonDecode(txt) as Map<String, dynamic>, DateTime.now());
    } catch (_) {}
    if (!mounted) return;
    _exibido = _m.dinheiro;
    setState(() => _carregado = true);
    _ticker.start();
    if (fora > 60) await _mostrarOffline(_m.ganhoOffline(fora), fora);
  }

  Future<void> _salvar() async {
    if (!_carregado) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveSalvo, jsonEncode(_m.paraJson(DateTime.now())));
    } catch (_) {}
  }

  Future<void> _voltouDoSegundoPlano() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final txt = prefs.getString(_chaveSalvo);
      if (txt == null) return;
      final salvoEm = (jsonDecode(txt) as Map)['salvoEm'] as int?;
      if (salvoEm == null) return;
      final fora = (DateTime.now().millisecondsSinceEpoch - salvoEm) / 1000;
      if (fora > 60 && mounted) await _mostrarOffline(_m.ganhoOffline(fora), fora);
    } catch (_) {}
  }

  Future<void> _mostrarOffline(double valor, double segundos) async {
    if (valor <= 0 || !mounted) return;
    Musica.efeito(Efeito.tyCaixa);
    final h = segundos ~/ 3600, mi = (segundos % 3600) ~/ 60;
    await _celebrar(
      emoji: '💤',
      titulo: 'Bem-vindo de volta!',
      texto: 'Você ficou fora ${h > 0 ? '${h}h ' : ''}${mi}min${segundos > 3 * 3600 ? ' (conta até 3h)' : ''}.\n'
          'Seus gerentes faturaram:',
      destaque: reais(valor),
      botao: 'Recolher 💰',
    );
    _salvar();
  }

  // ======================= posições na tela =======================
  Offset? _centro(GlobalKey k) {
    final raiz = _chaveRaiz.currentContext?.findRenderObject() as RenderBox?;
    final box = k.currentContext?.findRenderObject() as RenderBox?;
    if (raiz == null || box == null || !box.attached) return null;
    return box.localToGlobal(box.size.center(Offset.zero), ancestor: raiz);
  }

  Rect? _retangulo(GlobalKey k) {
    final raiz = _chaveRaiz.currentContext?.findRenderObject() as RenderBox?;
    final box = k.currentContext?.findRenderObject() as RenderBox?;
    if (raiz == null || box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero, ancestor: raiz) & box.size;
  }

  // ======================= loop =======================
  void _tick(Duration agora) {
    final dt = ((agora - _ultimo).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _ultimo = agora;
    _t += dt;
    final vendas = _m.passo(dt);

    // moedas voando + som (com limite para não virar barulho)
    final destino = _centro(_chaveDinheiro);
    for (final v in vendas) {
      final de = _centro(_chavesIcone[v.produto]);
      if (de != null && destino != null && _moedas.length < 14) {
        _moedas.add(_Moeda(de, destino, 0));
      }
    }
    if (vendas.isNotEmpty && _t - _ultimoSomMoeda > 0.2) {
      _ultimoSomMoeda = _t;
      Musica.efeito(Efeito.tyMoeda);
    }
    for (final mo in _moedas) {
      mo.t += dt * 1.6;
    }
    final chegaram = _moedas.where((mo) => mo.t >= 1).length;
    if (chegaram > 0) _pulso = 1;
    _moedas.removeWhere((mo) => mo.t >= 1);
    _pulso = max(0, _pulso - dt * 4);
    _exibido += (_m.dinheiro - _exibido) * min(1, dt * 7);
    if ((_m.dinheiro - _exibido).abs() < 0.01 || _m.dinheiro < _exibido) _exibido = _m.dinheiro;

    // calçada
    _proximoCliente -= dt;
    if (_proximoCliente <= 0 && _calcada.length < 7) {
      _calcada.add(ClienteCalcada(_pessoas[_rnd.nextInt(_pessoas.length)], 0.16 + _rnd.nextDouble() * 0.08,
          _rnd.nextDouble() * 6));
      _proximoCliente = max(0.7, 3.5 - log(_m.ganhoPorSegundo + 1) * 0.25);
    }
    if (_m.vipVisivel > 0 && !_calcada.any((c) => c.vip)) {
      _calcada.add(ClienteCalcada('🤩', 0.25, 0, vip: true)..espera = 6);
    }
    for (final c in _calcada) {
      c.andar(dt, vipAindaAqui: _m.vipVisivel > 0);
    }
    _calcada.removeWhere((c) => c.x > 1.15 || (c.vip && _m.vipVisivel <= 0 && c.x < 0.5));

    _tickRush(dt);
    _tickEventos();

    for (final tx in _textos) {
      tx.vida -= dt * 1.2;
    }
    _textos.removeWhere((tx) => tx.vida <= 0);
    for (final c in _confetes) {
      c.passo(dt);
    }
    _confetes.removeWhere((c) => c.vida <= 0);

    // a cada segundo: nível do império
    if (_t - _ultimaChecagem > 1) {
      _ultimaChecagem = _t;
      final fachadaAntes = _m.fachada;
      final nivelAntes = _m.nivelImperioPremiado;
      final g = _m.premiarNivelImperio();
      if (g > 0) _subiuImperio(nivelAntes, g, fachadaAntes != _m.fachada);
    }
    if (_t - _ultimoSalvo > 5) {
      _ultimoSalvo = _t;
      _salvar();
    }
    setState(() {});
  }

  void _tickRush(double dt) {
    if (_m.rush > 0 && !_estavaNoRush) {
      _estavaNoRush = true;
      _rushAtendidos = 0;
      _rushGanho = 0;
      _rushClientes.clear();
      Musica.efeito(Efeito.tyRush);
      HapticFeedback.heavyImpact();
    }
    if (_m.rush <= 0 && _estavaNoRush) {
      _estavaNoRush = false;
      _rushClientes.clear();
      if (_rushAtendidos > 0) {
        Musica.efeito(Efeito.tyCaixa);
        _aviso('⚡ Rush encerrado: $_rushAtendidos clientes, ${reais(_rushGanho)}!');
      }
    }
    if (_m.rush > 0) {
      _proximoRush -= dt;
      if (_proximoRush <= 0 && _rushClientes.length < 9) {
        _proximoRush = 0.22 + _rnd.nextDouble() * 0.25;
        final dourado = _rnd.nextDouble() < 0.12;
        final daEsquerda = _rnd.nextBool();
        _rushClientes.add(_ClienteRush(
          Offset(daEsquerda ? -0.05 : 1.05, 0.15 + _rnd.nextDouble() * 0.7),
          Offset((daEsquerda ? 1 : -1) * (0.22 + _rnd.nextDouble() * 0.2), (_rnd.nextDouble() - 0.5) * 0.15),
          dourado ? '🤑' : _pessoas[_rnd.nextInt(_pessoas.length)],
          dourado,
        ));
      }
      for (final c in _rushClientes) {
        c.pos += c.vel * dt;
        c.vida += dt;
      }
      _rushClientes.removeWhere((c) => c.pos.dx < -0.1 || c.pos.dx > 1.1);
    }
  }

  void _tickEventos() {
    if (_m.ondaCalor > 0 && !_estavaNoCalor) {
      _estavaNoCalor = true;
      Musica.efeito(Efeito.tyCalor);
      _aviso('🔥 Onda de calor! Todo mundo quer suco: tudo rende x3 por 30 s');
    }
    if (_m.ondaCalor <= 0) _estavaNoCalor = false;
  }

  // ======================= ações =======================
  int _quantos(int i) => _modo == -1 ? max(1, _m.maxCompravel(i)) : _modo;

  void _comprar(int i) {
    final n = _quantos(i);
    final antes = _m.estados[i].nivel;
    if (_m.custo(i, n) > _m.dinheiro) return;
    final marco = _m.comprar(i, n);
    HapticFeedback.lightImpact();
    final pos = _centro(_chavesIcone[i]);
    if (antes == 0) {
      Musica.efeito(Efeito.tyMarco);
      if (pos != null) _explodirConfete(pos, 40);
      _aviso('${produtos[i].emoji} ${produtos[i].nome} aberto!');
    } else if (marco) {
      Musica.efeito(Efeito.tyMarco);
      HapticFeedback.mediumImpact();
      if (pos != null) {
        _explodirConfete(pos, 30);
        _textos.add(_Texto(pos, '⚡ 2x MAIS RÁPIDO', ouro, 18));
      }
    } else {
      Musica.efeito(Efeito.tyCompra);
    }
  }

  void _tocarProduto(int i) {
    if (_m.tocar(i)) {
      Musica.efeito(Efeito.tyToque);
      HapticFeedback.selectionClick();
    }
  }

  void _vip() {
    final v = _m.atenderVip();
    if (v <= 0) return;
    Musica.efeito(Efeito.tyCaixa);
    Future.delayed(const Duration(milliseconds: 350), () => Musica.efeito(Efeito.tyGema));
    HapticFeedback.heavyImpact();
    _aviso('🤩 Cliente VIP: gorjeta de ${reais(v)} e +1 💎!');
  }

  void _tocarRush(Offset local, Size area) {
    _ClienteRush? alvo;
    var melhor = double.infinity;
    for (final c in _rushClientes) {
      final p = Offset(c.pos.dx * area.width, c.pos.dy * area.height);
      final d = (p - local).distance;
      if (d < 46 && d < melhor) {
        melhor = d;
        alvo = c;
      }
    }
    if (alvo == null) return;
    _rushClientes.remove(alvo);
    final v = _m.atenderClienteRush(dourado: alvo.dourado);
    _rushAtendidos++;
    _rushGanho += v;
    final c = _m.combo;
    Musica.efeito(c >= 8 ? Efeito.tyCombo4 : c >= 5 ? Efeito.tyCombo3 : c >= 3 ? Efeito.tyCombo2 : Efeito.tyCombo1);
    if (alvo.dourado) Future.delayed(const Duration(milliseconds: 120), () => Musica.efeito(Efeito.tyGema));
    HapticFeedback.selectionClick();
    final r = _retangulo(_chaveRush);
    final pos = (r?.topLeft ?? Offset.zero) + local;
    _textos.add(_Texto(pos, '+${reais(v)}', alvo.dourado ? ouro : Colors.white, alvo.dourado ? 24 : 18));
    _explodirConfete(pos, alvo.dourado ? 24 : 8);
  }

  void _explodirConfete(Offset pos, int n) {
    for (var k = 0; k < n; k++) {
      final a = _rnd.nextDouble() * 2 * pi;
      final v = 120 + _rnd.nextDouble() * 220;
      _confetes.add(Confete(pos, Offset(cos(a) * v, sin(a) * v - 120),
          coresConfete[_rnd.nextInt(coresConfete.length)], 0.9 + _rnd.nextDouble() * 0.7, _rnd.nextDouble() * 6));
    }
  }

  void _chuvaDeConfete(Size tela) {
    for (var k = 0; k < 90; k++) {
      _confetes.add(Confete(Offset(_rnd.nextDouble() * tela.width, -20 - _rnd.nextDouble() * 200),
          Offset((_rnd.nextDouble() - 0.5) * 80, 60 + _rnd.nextDouble() * 120),
          coresConfete[_rnd.nextInt(coresConfete.length)], 3, _rnd.nextDouble() * 6));
    }
  }

  Future<void> _subiuImperio(int nivelAntes, int gemas, bool novaFachada) async {
    _chuvaDeConfete(MediaQuery.of(context).size);
    Musica.efeito(novaFachada ? Efeito.tyFilial : Efeito.tyMissao);
    HapticFeedback.mediumImpact();
    if (novaFachada) {
      await _celebrar(
        emoji: '🏙️',
        titulo: 'Seu império cresceu!',
        texto: 'Império nível ${_m.nivelImperio}. Sua loja virou:',
        destaque: fachadas[_m.fachada],
        extra: '+$gemas 💎',
        botao: 'Incrível!',
      );
    } else {
      _aviso('🏙️ Império nível ${_m.nivelImperio}! +$gemas 💎');
    }
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texto, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF3A2410),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  Future<void> _celebrar({
    required String emoji,
    required String titulo,
    required String texto,
    required String destaque,
    String? extra,
    required String botao,
  }) =>
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF3A2410), Color(0xFF1E1208)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: ouro.withValues(alpha: 0.6), width: 2),
              boxShadow: [BoxShadow(color: ouro.withValues(alpha: 0.25), blurRadius: 30)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(emoji, style: const TextStyle(fontSize: 64)),
              Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(colors: [ouro, laranja]).createShader(r),
                child: Text(destaque,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
              if (extra != null) Text(extra, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              BotaoDourado(texto: botao, aoTocar: () => Navigator.pop(ctx)),
            ]),
          ),
        ),
      );

  Future<void> _sair() async {
    await _salvar();
    final niveis = _m.estados.fold<int>(0, (s, e) => s + e.nivel);
    try {
      await Repo.salvarPartida('tycoon', min(niveis + _m.estrelas * 100, 1000000),
          DateTime.now().difference(_inicio).inSeconds);
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  // ======================= folhas (gerentes, melhorias, turbos, missões, filial) =======================
  void _folha(String titulo, String sub, List<Widget> Function(VoidCallback atualizar) itens) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF221509),
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        void atualizar() {
          setLocal(() {});
          setState(() {});
        }

        final lista = itens(atualizar);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.92,
          builder: (_, rolagem) => ListView(
            controller: rolagem,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(titulo, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              Text(sub, style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 4),
              Text('Caixa: ${reais(_m.dinheiro)}   ·   💎 ${_m.gemas}',
                  style: const TextStyle(color: ouro, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (lista.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Tudo comprado! 🎉')),
              ...lista,
            ],
          ),
        );
      }),
    );
  }

  void _abrirMissoes() => _folha('🎯 Missões', 'Cumpra objetivos e ganhe 💎 gemas e dinheiro.', (atualizar) => [
        for (final k in _m.missoesAtivas)
          ItemLoja(
            emoji: _emojiMissao(missoes[k]),
            titulo: missoes[k].texto,
            subtitulo: '${_textoProgresso(k)}   ·   🎁 💎${missoes[k].gemas} + ${reais(_m.recompensaMissao(k))}',
            progresso: _m.progressoMissao(k),
            acao: '🎁',
            rotulo: _m.progressoMissao(k) >= 1 ? 'Resgatar' : '${(_m.progressoMissao(k) * 100).floor()}%',
            pode: _m.progressoMissao(k) >= 1,
            aoComprar: () {
              final v = _m.resgatarMissao(k);
              if (v >= 0) {
                Musica.efeito(Efeito.tyMissao);
                Future.delayed(const Duration(milliseconds: 400), () => Musica.efeito(Efeito.tyGema));
                HapticFeedback.mediumImpact();
                _chuvaDeConfete(MediaQuery.of(context).size);
                Repo.somarXp(5, 'jogo').catchError((_) => 0);
                atualizar();
              }
            },
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('${_m.missoesFeitas.length} de ${missoes.length} missões cumpridas',
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
        ),
      ]);

  String _emojiMissao(Missao m) => switch (m.tipo) {
        TipoMissao.vip => '🤩',
        TipoMissao.rush => '⚡',
        TipoMissao.filial => '🏪',
        TipoMissao.ganhar => '💰',
        TipoMissao.gerente => '👔',
        _ => produtos[m.produto].emoji,
      };

  String _textoProgresso(int k) {
    final m = missoes[k];
    final v = _m.valorMissao(m);
    if (m.tipo == TipoMissao.ganhar) return '${reais(min(v, m.alvo))} / ${reais(m.alvo)}';
    return '${min(v, m.alvo).floor()} / ${m.alvo.floor()}';
  }

  void _abrirGerentes() => _folha('👔 Gerentes', 'Fazem o suco sozinhos, até com o app fechado.', (atualizar) => [
        for (var i = 0; i < produtos.length; i++)
          if (!_m.estados[i].gerente)
            ItemLoja(
              emoji: produtos[i].emoji,
              titulo: produtos[i].gerente,
              subtitulo: 'Cuida: ${produtos[i].nome}${_m.estados[i].nivel == 0 ? ' (abra o suco antes)' : ''}',
              acao: 'Contratar',
              rotulo: reais(produtos[i].custoGerente),
              pode: _m.estados[i].nivel > 0 && _m.dinheiro >= produtos[i].custoGerente,
              aoComprar: () {
                if (_m.comprarGerente(i)) {
                  Musica.efeito(Efeito.tyGerente);
                  HapticFeedback.mediumImpact();
                  Repo.somarXp(10, 'jogo').catchError((_) => 0);
                  atualizar();
                }
              },
            ),
      ]);

  void _abrirMelhorias() => _folha('⚡ Melhorias', 'Multiplicam quanto cada suco rende.', (atualizar) => [
        for (var k = 0; k < melhorias.length; k++)
          if (!_m.compradas.contains(k))
            ItemLoja(
              emoji: melhorias[k].produto == -1 ? '📣' : produtos[melhorias[k].produto].emoji,
              titulo: melhorias[k].nome,
              subtitulo: melhorias[k].descricao,
              rotulo: reais(melhorias[k].custo),
              pode: _m.dinheiro >= melhorias[k].custo,
              aoComprar: () {
                if (_m.comprarMelhoria(k)) {
                  Musica.efeito(Efeito.tyMarco);
                  atualizar();
                }
              },
            ),
      ]);

  void _abrirTurbos() => _folha('💎 Turbos', 'Ganhe gemas em missões, clientes VIP, Rush e no baú diário.', (atualizar) => [
        ItemLoja(
          emoji: '🚀',
          titulo: 'Turbo x2 (5 min)',
          subtitulo: _m.turboDobro > 0 ? 'Ativo: ${_tempo(_m.turboDobro)} restantes (soma mais tempo)' : 'Tudo rende o dobro',
          acao: 'Usar',
          rotulo: '💎 ${custoTurbo[Turbo.dobro]}',
          pode: _m.gemas >= custoTurbo[Turbo.dobro]!,
          aoComprar: () {
            if (_m.usarTurbo(Turbo.dobro) >= 0) {
              Musica.efeito(Efeito.tyFilial);
              atualizar();
            }
          },
        ),
        ItemLoja(
          emoji: '⏩',
          titulo: 'Viagem no tempo (+1 hora)',
          subtitulo: 'Recebe agora ${reais(max(_m.ganhoPorSegundoBase, 1) * 3600)}',
          acao: 'Usar',
          rotulo: '💎 ${custoTurbo[Turbo.tempo]}',
          pode: _m.gemas >= custoTurbo[Turbo.tempo]!,
          aoComprar: () {
            final v = _m.usarTurbo(Turbo.tempo);
            if (v >= 0) {
              Musica.efeito(Efeito.tyCaixa);
              _chuvaDeConfete(MediaQuery.of(context).size);
              atualizar();
            }
          },
        ),
        ItemLoja(
          emoji: '⚡',
          titulo: 'Chamar a Hora do Rush',
          subtitulo: _m.rush > 0 ? 'O rush já está acontecendo!' : '20 s de clientes para tocar, com combos',
          acao: 'Usar',
          rotulo: '💎 ${custoTurbo[Turbo.rush]}',
          pode: _m.gemas >= custoTurbo[Turbo.rush]! && _m.rush <= 0,
          aoComprar: () {
            if (_m.usarTurbo(Turbo.rush) >= 0) Navigator.pop(context);
          },
        ),
      ]);

  Future<void> _abrirBau() async {
    if (!_m.podeAbrirBau(DateTime.now())) {
      _aviso('🎁 Você já abriu o baú de hoje. Volte amanhã!');
      return;
    }
    final (g, v) = _m.abrirBau(DateTime.now());
    Musica.efeito(Efeito.tyBau);
    HapticFeedback.heavyImpact();
    _chuvaDeConfete(MediaQuery.of(context).size);
    _salvar();
    await _celebrar(
        emoji: '🎁', titulo: 'Baú do dia!', texto: 'Você ganhou:', destaque: '+$g 💎', extra: '+${reais(v)}', botao: 'Oba!');
  }

  void _abrirFilial() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF221509),
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏪 Abrir nova filial', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            'Recomece do zero numa cidade nova, mas com ⭐ estrelas: cada uma faz TODOS os sucos '
            'renderem +${(MotorTycoon.bonusPorEstrela * 100).round()}% para sempre. Gemas e missões continuam.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text('Estrelas agora: ⭐ ${_m.estrelas}  (+${_m.estrelas * 5}%)'),
          Text('Ganharia: ⭐ +${_m.estrelasNovas}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ouro)),
          if (_m.estrelasNovas == 0)
            Text('Fature mais para ganhar estrelas (faltam ${reais(_faltaProximaEstrela())}).',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 16),
          BotaoDourado(
            texto: 'Abrir filial',
            ativo: _m.estrelasNovas > 0,
            aoTocar: () {
              Navigator.pop(ctx);
              if (_m.abrirFilial()) {
                _exibido = 0;
                Musica.efeito(Efeito.tyFilial);
                HapticFeedback.heavyImpact();
                _chuvaDeConfete(MediaQuery.of(context).size);
                Repo.somarXp(50, 'jogo').catchError((_) => 0);
                _salvar();
                _aviso('🏪 Filial nº ${_m.filiais} aberta com ⭐ ${_m.estrelas}!');
              }
            },
          ),
        ]),
      ),
    );
  }

  double _faltaProximaEstrela() => max(0, pow((_m.estrelasPossiveis + 1) / 10, 2) * 1e9 - _m.ganhoDaVida);

  String _tempo(double s) => '${s ~/ 60}:${(s % 60).floor().toString().padLeft(2, '0')}';

  // ======================= interface =======================
  @override
  Widget build(BuildContext context) {
    if (!_carregado) {
      return const Scaffold(backgroundColor: fundoEscuro, body: Center(child: CircularProgressIndicator()));
    }
    final abertos = _m.estados.where((e) => e.nivel > 0).length;
    final visiveis = min(produtos.length, abertos + 1);
    final temGerente = List.generate(produtos.length,
        (i) => _m.estados[i].nivel > 0 && !_m.estados[i].gerente && _m.dinheiro >= produtos[i].custoGerente).any((x) => x);
    final temMelhoria =
        List.generate(melhorias.length, (k) => !_m.compradas.contains(k) && _m.dinheiro >= melhorias[k].custo).any((x) => x);
    final temTurbo = _m.gemas >= 3;
    final temBau = _m.podeAbrirBau(DateTime.now());
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (pop, _) {
        if (!pop) _sair();
      },
      child: Scaffold(
        backgroundColor: fundoEscuro,
        body: Stack(key: _chaveRaiz, children: [
          // fundo com brilho quente
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.6),
                  radius: 1.3,
                  colors: [
                    Color.lerp(const Color(0xFF4A2508), const Color(0xFF7A2E05), _m.ondaCalor > 0 ? 1 : 0)!,
                    fundoEscuro,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(children: [
              _topo(),
              // fachada (toque no VIP)
              GestureDetector(
                onTapDown: (_) => _vip(),
                child: SizedBox(
                  height: 132,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: PintorFachada(
                      clientes: _calcada,
                      t: _t,
                      pintor: _pintor,
                      vip: _m.vipVisivel > 0,
                      nivel: _m.fachada,
                      calor: _m.ondaCalor > 0,
                      turbo: _m.turboDobro > 0,
                    ),
                  ),
                ),
              ),
              _painelDinheiro(),
              _faixaMissao(),
              _modosDeCompra(),
              Expanded(
                child: Stack(children: [
                  ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: visiveis + (visiveis < produtos.length ? 1 : 0),
                    itemBuilder: (_, i) => i < visiveis ? _cartaoProduto(i) : _cartaoSecreto(),
                  ),
                  if (_m.rush > 0) Positioned.fill(child: _camadaRush()),
                ]),
              ),
              _barraAcoes(temGerente, temMelhoria, temTurbo, temBau),
            ]),
          ),
          // efeitos por cima de tudo (não bloqueiam toques)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: PintorEfeitos(
                  moedas: [for (final mo in _moedas) (mo.de, mo.para, mo.t)],
                  confetes: _confetes,
                  textos: [for (final tx in _textos) (tx.pos, tx.texto, tx.cor, tx.tamanho, tx.vida)],
                  pintor: _pintor,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _topo() => Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.close), onPressed: _sair),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('🧃 Império do Suco', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              Row(children: [
                Text('🏙️ Nv ${_m.nivelImperio} · ${fachadas[_m.fachada]}  ',
                    style: const TextStyle(fontSize: 11, color: Colors.white70)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        value: _m.progressoImperio(), minHeight: 5, backgroundColor: Colors.white12, color: ouro),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Pilula(texto: '💎 ${_m.gemas}', cor: const Color(0xFF4CC9F0)),
          if (_m.estrelas > 0) ...[const SizedBox(width: 4), Pilula(texto: '⭐ ${_m.estrelas}', cor: ouro)],
          const BotaoMusica(),
        ]),
      );

  Widget _painelDinheiro() {
    final efeitos = <String>[
      if (_m.ondaCalor > 0) '🔥 x3 ${_m.ondaCalor.ceil()}s',
      if (_m.turboDobro > 0) '🚀 x2 ${_tempo(_m.turboDobro)}',
    ];
    return Container(
      key: _chaveDinheiro,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [laranja.withValues(alpha: 0.35), rosa.withValues(alpha: 0.25)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ouro.withValues(alpha: 0.35 + 0.4 * _pulso)),
        boxShadow: [BoxShadow(color: ouro.withValues(alpha: 0.15 + 0.25 * _pulso), blurRadius: 18)],
      ),
      child: Column(children: [
        Transform.scale(
          scale: 1 + 0.06 * _pulso,
          child: FittedBox(
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(colors: [Color(0xFFFFE08A), ouro, laranja]).createShader(r),
              child: Text(reais(_exibido),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_m.ganhoPorSegundo > 0 ? '+${reais(_m.ganhoPorSegundo)}/s' : 'Toque nos sucos para vender!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          for (final e in efeitos)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)),
              child: Text(e, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ouro)),
            ),
        ]),
      ]),
    );
  }

  Widget _faixaMissao() {
    final ativas = _m.missoesAtivas;
    if (ativas.isEmpty) return const SizedBox(height: 6);
    // mostra primeiro uma que já pode ser resgatada
    final k = ativas.firstWhere((x) => _m.progressoMissao(x) >= 1, orElse: () => ativas.first);
    final pronta = _m.progressoMissao(k) >= 1;
    final brilho = pronta ? 0.5 + 0.5 * sin(_t * 6) : 0.0;
    return GestureDetector(
      onTap: _abrirMissoes,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cartao,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pronta ? ouro.withValues(alpha: 0.5 + 0.5 * brilho) : Colors.white12, width: pronta ? 2 : 1),
          boxShadow: pronta ? [BoxShadow(color: ouro.withValues(alpha: 0.3 * brilho), blurRadius: 16)] : null,
        ),
        child: Row(children: [
          Text(_emojiMissao(missoes[k]), style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('🎯 ${missoes[k].texto}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 4),
              BarraBrilhante(valor: _m.progressoMissao(k), cor: pronta ? ouro : const Color(0xFF4CC9F0), t: _t, altura: 8),
            ]),
          ),
          const SizedBox(width: 10),
          if (pronta)
            Text('🎁 Resgatar', style: TextStyle(color: ouro, fontWeight: FontWeight.w900, fontSize: 13 + brilho))
          else
            Text('💎${missoes[k].gemas}  ›', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          if (_m.missoesProntas > 1)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Badge(label: Text('${_m.missoesProntas}'), backgroundColor: rosa),
            ),
        ]),
      ),
    );
  }

  Widget _modosDeCompra() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          const Text('Comprar ', style: TextStyle(color: Colors.white70)),
          for (final (n, r) in const [(1, 'x1'), (10, 'x10'), (100, 'x100'), (-1, 'MAX')])
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Musica.efeito(Efeito.tyToque);
                  setState(() => _modo = n);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: _modo == n ? const LinearGradient(colors: [ouro, laranja]) : null,
                    color: _modo == n ? null : Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(r,
                      style: TextStyle(fontWeight: FontWeight.w900, color: _modo == n ? Colors.black : Colors.white70)),
                ),
              ),
            ),
        ]),
      );

  Widget _cartaoSecreto() => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: const Row(children: [
          Text('❓', style: TextStyle(fontSize: 30)),
          SizedBox(width: 12),
          Expanded(child: Text('Suco secreto\nAbra o suco de cima para descobrir', style: TextStyle(color: Colors.white54))),
        ]),
      );

  Widget _cartaoProduto(int i) {
    final p = produtos[i];
    final e = _m.estados[i];
    final cor = corDe(i);
    final n = _quantos(i);
    final preco = _m.custo(i, n);
    final pode = _m.dinheiro >= preco && (_modo != -1 || _m.maxCompravel(i) > 0);
    final aberto = e.nivel > 0;
    final rapido = _m.tempo(i) < 0.25 && e.gerente;
    final restante = (1 - e.progresso) * _m.tempo(i);
    final marco = _m.proximoMarco(i);
    final ativo = e.rodando || e.gerente;
    return GestureDetector(
      onTap: aberto ? () => _tocarProduto(i) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: aberto
                ? [Color.lerp(cartao, cor, 0.28)!, cartao]
                : [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: e.gerente ? cor.withValues(alpha: 0.7) : Colors.white10, width: e.gerente ? 1.5 : 1),
          boxShadow: e.gerente ? [BoxShadow(color: cor.withValues(alpha: 0.18), blurRadius: 14)] : null,
        ),
        child: Row(children: [
          // fruta com nível
          Stack(clipBehavior: Clip.none, children: [
            Transform.scale(
              scale: ativo ? 1 + 0.05 * sin(_t * 9 + i) : 1,
              child: Container(
                key: _chavesIcone[i],
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: aberto ? [cor.withValues(alpha: 0.85), cor.withValues(alpha: 0.25)] : [Colors.white12, Colors.white10],
                  ),
                  boxShadow: aberto ? [BoxShadow(color: cor.withValues(alpha: 0.4), blurRadius: ativo ? 14 : 6)] : null,
                ),
                alignment: Alignment.center,
                child: Text(aberto ? p.emoji : '🔒', style: const TextStyle(fontSize: 32)),
              ),
            ),
            if (aberto)
              Positioned(
                bottom: -5,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [ouro, laranja]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: fundoEscuro, width: 2),
                  ),
                  child: Text('${e.nivel}',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ),
            if (e.gerente)
              const Positioned(top: -6, left: -4, child: Text('👔', style: TextStyle(fontSize: 18))),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.nome, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 6),
              Stack(alignment: Alignment.center, children: [
                BarraBrilhante(valor: !aberto ? 0 : (rapido ? 1 : e.progresso), cor: cor, t: _t, altura: 24),
                Text(
                  aberto ? '${reais(_m.receita(i))}${rapido ? ' · ${(1 / _m.tempo(i)).toStringAsFixed(0)}x/s' : ''}' : '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 13, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                !aberto
                    ? 'Rende ${reais(p.receitaBase)} a cada ${p.tempoBase.toStringAsFixed(0)}s'
                    : ativo
                        ? '⏱️ ${restante < 1 ? (restante * 10).ceil() / 10 : restante.ceil()}s${marco != null ? '  ·  ⚡ nível $marco' : ''}'
                        : '👆 Toque para preparar${marco != null ? '  ·  ⚡ nível $marco' : ''}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          BotaoCompra(
            linha1: aberto ? 'x$n' : 'Abrir',
            linha2: reais(preco),
            ativo: pode,
            aoTocar: () => _comprar(i),
          ),
        ]),
      ),
    );
  }

  Widget _camadaRush() => LayoutBuilder(builder: (_, box) {
        final area = Size(box.maxWidth, box.maxHeight);
        return GestureDetector(
          key: _chaveRush,
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _tocarRush(d.localPosition, area),
          child: CustomPaint(
            painter: PintorRush(
              clientes: [for (final c in _rushClientes) (c.pos, c.emoji, c.dourado, c.vida)],
              t: _t,
              restante: _m.rush,
              total: MotorTycoon.duracaoRush,
              combo: _m.combo,
              pintor: _pintor,
            ),
          ),
        );
      });

  Widget _barraAcoes(bool gerente, bool melhoria, bool turbo, bool bau) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1108),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(children: [
          Expanded(child: BotaoAcao('👔', 'Gerentes', gerente, _abrirGerentes, t: _t)),
          Expanded(child: BotaoAcao('⚡', 'Melhorias', melhoria, _abrirMelhorias, t: _t)),
          Expanded(child: BotaoAcao('💎', 'Turbos', turbo, _abrirTurbos, t: _t)),
          Expanded(child: BotaoAcao('🎁', 'Baú', bau, _abrirBau, t: _t)),
          Expanded(child: BotaoAcao('🏪', 'Filial', _m.estrelasNovas > 0, _abrirFilial, t: _t)),
        ]),
      );
}
