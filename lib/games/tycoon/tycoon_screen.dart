import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/musica.dart';
import '../../data/repo.dart';
import '../../theme.dart';
import '../comum.dart';
import 'motor.dart';

const _laranja = Color(0xFFFF9F1C);
const _fundo = Color(0xFF1A1208);
const _cartao = Color(0xFF2A1D0E);
const _chaveSalvo = 'tycoon_suco_v1';

class _Cliente {
  final String emoji;
  final bool vip;
  double x = -0.12; // posição na calçada
  double espera = 0.7; // tempo parado no balcão
  final double vel, fase;
  _Cliente(this.emoji, this.vel, this.fase, {this.vip = false});
}

class _Flutuante {
  final int produto;
  final String texto;
  double vida = 1;
  _Flutuante(this.produto, this.texto);
}

class TycoonScreen extends StatefulWidget {
  const TycoonScreen({super.key});

  @override
  State<TycoonScreen> createState() => _TycoonScreenState();
}

class _TycoonScreenState extends State<TycoonScreen> with SingleTickerProviderStateMixin {
  static const _pessoas = ['🧑', '👩', '👨', '👵', '🧔', '👧', '👦', '🧓', '👱', '👩‍🦱'];
  final _m = MotorTycoon();
  final _rnd = Random();
  final _pintor = PintorEmoji();
  final _clientes = <_Cliente>[];
  final _flutuantes = <_Flutuante>[];
  late final Ticker _ticker;
  late final AppLifecycleListener _ciclo;
  Duration _ultimo = Duration.zero;
  double _t = 0, _ultimoSomMoeda = 0, _ultimoSalvo = 0, _proximoCliente = 0;
  int _modo = 1; // 1, 10, 100 ou -1 (máximo)
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

  // ---------------- salvar / carregar ----------------
  Future<void> _carregar() async {
    double fora = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final txt = prefs.getString(_chaveSalvo);
      if (txt != null) fora = _m.carregar(jsonDecode(txt) as Map<String, dynamic>, DateTime.now());
    } catch (_) {}
    if (!mounted) return;
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
    // o Ticker para em segundo plano: calcula o que os gerentes fizeram nesse tempo
    try {
      final prefs = await SharedPreferences.getInstance();
      final txt = prefs.getString(_chaveSalvo);
      if (txt == null) return;
      final salvoEm = (jsonDecode(txt) as Map)['salvoEm'] as int?;
      if (salvoEm == null) return;
      final fora = (DateTime.now().millisecondsSinceEpoch - salvoEm) / 1000;
      if (fora > 60) {
        final v = _m.ganhoOffline(fora);
        if (mounted) await _mostrarOffline(v, fora);
      }
    } catch (_) {}
  }

  Future<void> _mostrarOffline(double valor, double segundos) async {
    if (valor <= 0 || !mounted) return;
    Musica.efeito(Efeito.tyCaixa);
    final h = segundos ~/ 3600, min_ = (segundos % 3600) ~/ 60;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cartao,
        title: const Text('💤 Bem-vindo de volta!', textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Você ficou fora ${h > 0 ? '${h}h ' : ''}${min_}min.${segundos > 3 * 3600 ? ' (conta até 3h)' : ''}'),
          const SizedBox(height: 8),
          const Text('Seus gerentes faturaram:'),
          Text(reais(valor), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Cores.ouro)),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Recolher 💰'))],
      ),
    );
    _salvar();
  }

  // ---------------- loop ----------------
  void _tick(Duration agora) {
    final dt = ((agora - _ultimo).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _ultimo = agora;
    _t += dt;
    final vendas = _m.passo(dt);
    for (final v in vendas) {
      if (_flutuantes.where((f) => f.produto == v.produto).length < 2) {
        _flutuantes.add(_Flutuante(v.produto, '+${reais(v.valor)}'));
      }
    }
    if (vendas.isNotEmpty && _t - _ultimoSomMoeda > 0.18) {
      _ultimoSomMoeda = _t;
      Musica.efeito(Efeito.tyMoeda);
    }
    for (final f in _flutuantes) {
      f.vida -= dt * 1.4;
    }
    _flutuantes.removeWhere((f) => f.vida <= 0);
    // clientes andando na calçada (mais vendas = mais movimento)
    _proximoCliente -= dt;
    if (_proximoCliente <= 0 && _clientes.length < 6) {
      _clientes.add(_Cliente(_pessoas[_rnd.nextInt(_pessoas.length)], 0.18 + _rnd.nextDouble() * 0.08, _rnd.nextDouble() * 6));
      _proximoCliente = max(0.8, 4.0 - log(_m.ganhoPorSegundo + 1) * 0.3);
    }
    if (_m.vipVisivel > 0 && !_clientes.any((c) => c.vip)) {
      _clientes.add(_Cliente('🤩', 0.25, 0, vip: true)..espera = 6);
    }
    for (final c in _clientes) {
      if (c.x >= 0.5 && c.espera > 0 && !(c.vip && _m.vipVisivel <= 0)) {
        c.espera -= dt;
      } else {
        c.x += c.vel * dt;
      }
    }
    _clientes.removeWhere((c) => c.x > 1.15 || (c.vip && _m.vipVisivel <= 0 && c.x < 0.5));
    if (_t - _ultimoSalvo > 5) {
      _ultimoSalvo = _t;
      _salvar();
    }
    setState(() {});
  }

  // ---------------- ações ----------------
  int _quantos(int i) => _modo == -1 ? max(1, _m.maxCompravel(i)) : _modo;

  void _comprar(int i) {
    final n = _quantos(i);
    final nivelAntes = _m.estados[i].nivel;
    if (_m.custo(i, n) > _m.dinheiro) return;
    final marco = _m.comprar(i, n);
    HapticFeedback.lightImpact();
    if (nivelAntes == 0) {
      Musica.efeito(Efeito.tyMarco);
      _aviso('${produtos[i].emoji} ${produtos[i].nome} aberto!');
    } else if (marco) {
      Musica.efeito(Efeito.tyMarco);
      HapticFeedback.mediumImpact();
      _aviso('⭐ Marco! ${produtos[i].nome} agora é 2x mais rápido');
    } else {
      Musica.efeito(Efeito.tyCompra);
    }
  }

  void _tocar(int i) {
    if (_m.tocar(i)) {
      Musica.efeito(Efeito.tyToque);
      HapticFeedback.selectionClick();
    }
  }

  void _vip() {
    final v = _m.atenderVip();
    if (v <= 0) return;
    Musica.efeito(Efeito.tyCaixa);
    HapticFeedback.heavyImpact();
    _aviso('🤩 Cliente VIP deixou uma gorjeta de ${reais(v)}!');
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), duration: const Duration(seconds: 2)));
  }

  Future<void> _sair() async {
    await _salvar();
    final niveis = _m.estados.fold<int>(0, (s, e) => s + e.nivel);
    try {
      await Repo.salvarPartida('tycoon', min(niveis + _m.estrelas * 100, 1000000),
          DateTime.now().difference(_inicio).inSeconds);
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  // ---------------- telas de compra ----------------
  void _abrirGerentes() => _folha('👔 Gerentes', 'Fazem o suco sozinhos, até com o app fechado.', (atualizar) => [
        for (var i = 0; i < produtos.length; i++)
          if (!_m.estados[i].gerente)
            _ItemLoja(
              emoji: produtos[i].emoji,
              titulo: produtos[i].gerente,
              subtitulo: 'Cuida: ${produtos[i].nome}${_m.estados[i].nivel == 0 ? ' (abra o suco antes)' : ''}',
              preco: produtos[i].custoGerente,
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
            _ItemLoja(
              emoji: melhorias[k].produto == -1 ? '📣' : produtos[melhorias[k].produto].emoji,
              titulo: melhorias[k].nome,
              subtitulo: melhorias[k].descricao,
              preco: melhorias[k].custo,
              pode: _m.dinheiro >= melhorias[k].custo,
              aoComprar: () {
                if (_m.comprarMelhoria(k)) {
                  Musica.efeito(Efeito.tyMarco);
                  atualizar();
                }
              },
            ),
      ]);

  void _abrirFilial() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cartao,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏪 Abrir nova filial', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            'Você recomeça do zero numa cidade nova, mas ganha ⭐ estrelas: '
            'cada uma faz TODOS os sucos renderem +${(MotorTycoon.bonusPorEstrela * 100).round()}% para sempre.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text('Estrelas agora: ⭐ ${_m.estrelas}  (+${(_m.estrelas * 5)}%)'),
          Text('Ganharia: ⭐ +${_m.estrelasNovas}',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Cores.ouro)),
          if (_m.estrelasNovas == 0)
            Text('Fature mais para ganhar estrelas (próxima em ${reais(_faltaProximaEstrela())}).',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _m.estrelasNovas == 0
                ? null
                : () {
                    Navigator.pop(ctx);
                    if (_m.abrirFilial()) {
                      Musica.efeito(Efeito.tyFilial);
                      HapticFeedback.heavyImpact();
                      Repo.somarXp(50, 'jogo').catchError((_) => 0);
                      _salvar();
                      _aviso('🏪 Filial nº ${_m.filiais} aberta com ⭐ ${_m.estrelas} estrelas!');
                    }
                  },
            child: const Text('Abrir filial'),
          ),
        ]),
      ),
    );
  }

  double _faltaProximaEstrela() {
    final alvo = pow((_m.estrelasPossiveis + 1) / 10, 2) * 1e9;
    return max(0, alvo - _m.ganhoDaVida);
  }

  void _folha(String titulo, String sub, List<Widget> Function(VoidCallback atualizar) itens) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cartao,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          void atualizar() {
            setLocal(() {});
            setState(() {});
          }

          final lista = itens(atualizar);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            maxChildSize: 0.9,
            builder: (_, rolagem) => ListView(
              controller: rolagem,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text(titulo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                Text(sub, style: const TextStyle(color: Colors.white60)),
                Text('Seu caixa: ${reais(_m.dinheiro)}', style: const TextStyle(color: Cores.ouro)),
                const SizedBox(height: 12),
                if (lista.isEmpty) const Text('Tudo comprado! 🎉'),
                ...lista,
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- interface ----------------
  @override
  Widget build(BuildContext context) {
    if (!_carregado) return const Scaffold(backgroundColor: _fundo, body: Center(child: CircularProgressIndicator()));
    // mostra os sucos abertos + o próximo (os demais ficam em segredo)
    final abertos = _m.estados.where((e) => e.nivel > 0).length;
    final visiveis = min(produtos.length, abertos + 1);
    final temGerente = List.generate(produtos.length, (i) => _m.estados[i].nivel > 0 && !_m.estados[i].gerente && _m.dinheiro >= produtos[i].custoGerente).any((x) => x);
    final temMelhoria = List.generate(melhorias.length, (k) => !_m.compradas.contains(k) && _m.dinheiro >= melhorias[k].custo).any((x) => x);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (pop, _) {
        if (!pop) _sair();
      },
      child: Scaffold(
        backgroundColor: _fundo,
        body: SafeArea(
          child: Column(children: [
            // topo
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.close), onPressed: _sair),
                const Text('🧃 Império do Suco', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const Spacer(),
                if (_m.estrelas > 0) Text('⭐ ${_m.estrelas}  ', style: const TextStyle(color: Cores.ouro)),
                const BotaoMusica(),
              ]),
            ),
            // fachada da loja (toque no cliente VIP!)
            GestureDetector(
              onTapDown: (_) => _vip(),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: CustomPaint(painter: _PintorLoja(_clientes, _t, _pintor, _m.vipVisivel > 0)),
              ),
            ),
            // dinheiro
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.black26,
              child: Column(children: [
                FittedBox(
                  child: Text(reais(_m.dinheiro),
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Cores.ouro)),
                ),
                Text(_m.ganhoPorSegundo > 0 ? '+${reais(_m.ganhoPorSegundo)} por segundo' : 'Toque nos sucos para vender!',
                    style: const TextStyle(color: Colors.white70)),
              ]),
            ),
            // modo de compra
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                const Text('Comprar: '),
                for (final (n, r) in const [(1, 'x1'), (10, 'x10'), (100, 'x100'), (-1, 'MAX')])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(r),
                      selected: _modo == n,
                      onSelected: (_) => setState(() => _modo = n),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ]),
            ),
            // sucos
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: visiveis + (visiveis < produtos.length ? 1 : 0),
                itemBuilder: (_, i) => i < visiveis
                    ? _cartaoProduto(i)
                    : const Card(
                        color: _cartao,
                        child: ListTile(
                          leading: Text('❓', style: TextStyle(fontSize: 30)),
                          title: Text('Suco secreto'),
                          subtitle: Text('Abra o suco de cima para descobrir'),
                        ),
                      ),
              ),
            ),
            // barra de ações
            Container(
              color: Colors.black38,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(children: [
                Expanded(child: _BotaoAcao('👔', 'Gerentes', temGerente, _abrirGerentes)),
                Expanded(child: _BotaoAcao('⚡', 'Melhorias', temMelhoria, _abrirMelhorias)),
                Expanded(child: _BotaoAcao('🏪', 'Filial', _m.estrelasNovas > 0, _abrirFilial)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _cartaoProduto(int i) {
    final p = produtos[i];
    final e = _m.estados[i];
    final n = _quantos(i);
    final preco = _m.custo(i, n);
    final pode = _m.dinheiro >= preco && (_modo != -1 || _m.maxCompravel(i) > 0);
    final aberto = e.nivel > 0;
    final rapido = _m.tempo(i) < 0.25 && e.gerente; // tão rápido que a barra fica cheia
    final restante = (1 - e.progresso) * _m.tempo(i);
    final marco = _m.proximoMarco(i);
    final flut = _flutuantes.where((f) => f.produto == i).toList();
    return Card(
      color: _cartao,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: e.gerente ? Cores.verdeClaro.withValues(alpha: 0.6) : Colors.transparent),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: aberto ? () => _tocar(i) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // ícone com nível
            Stack(clipBehavior: Clip.none, children: [
              AnimatedScale(
                scale: e.rodando || e.gerente ? 1.0 + 0.06 * sin(_t * 8 + i) : 1,
                duration: Duration.zero,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: aberto ? _laranja.withValues(alpha: 0.2) : Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(aberto ? p.emoji : '🔒', style: const TextStyle(fontSize: 32)),
                ),
              ),
              if (aberto)
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: _laranja, borderRadius: BorderRadius.circular(9)),
                    child: Text('${e.nivel}',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ),
              for (final f in flut)
                Positioned(
                  left: 0,
                  top: -26 * (1 - f.vida),
                  child: Opacity(
                    opacity: f.vida.clamp(0.0, 1.0),
                    child: Text(f.texto,
                        style: const TextStyle(color: Cores.ouro, fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(p.nome,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  if (e.gerente)
                    const Padding(padding: EdgeInsets.only(left: 6), child: Text('👔', style: TextStyle(fontSize: 14))),
                ]),
                const SizedBox(height: 6),
                Stack(alignment: Alignment.center, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: !aberto ? 0 : (rapido ? 1 : e.progresso),
                      minHeight: 22,
                      backgroundColor: Colors.black38,
                      color: e.gerente ? Cores.verdeClaro : _laranja,
                    ),
                  ),
                  Text(
                    aberto ? '${reais(_m.receita(i))}${rapido ? ' · ${(1 / _m.tempo(i)).toStringAsFixed(0)}x/s' : ''}' : '',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, shadows: [Shadow(blurRadius: 3)]),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  !aberto
                      ? 'Rende ${reais(p.receitaBase)} a cada ${p.tempoBase.toStringAsFixed(0)}s'
                      : (e.gerente || e.rodando)
                          ? '⏱️ ${restante < 1 ? '${(restante * 10).ceil() / 10}' : restante.ceil()}s${marco != null ? '  ·  marco no nível $marco' : ''}'
                          : '👆 Toque para preparar${marco != null ? '  ·  marco no nível $marco' : ''}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _laranja,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  minimumSize: const Size(96, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: pode ? () => _comprar(i) : null,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(aberto ? 'Comprar x$n' : 'Abrir',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  FittedBox(child: Text(reais(preco), style: const TextStyle(fontSize: 13))),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BotaoAcao extends StatelessWidget {
  final String emoji, rotulo;
  final bool destaque;
  final VoidCallback aoTocar;
  const _BotaoAcao(this.emoji, this.rotulo, this.destaque, this.aoTocar);

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            Badge(
              isLabelVisible: destaque,
              label: const Text('!'),
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            Text(rotulo, style: TextStyle(fontSize: 12, color: destaque ? Cores.ouro : Colors.white70)),
          ]),
        ),
      );
}

class _ItemLoja extends StatelessWidget {
  final String emoji, titulo, subtitulo;
  final double preco;
  final bool pode;
  final VoidCallback aoComprar;
  const _ItemLoja({
    required this.emoji,
    required this.titulo,
    required this.subtitulo,
    required this.preco,
    required this.pode,
    required this.aoComprar,
  });

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.black26,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Text(emoji, style: const TextStyle(fontSize: 30)),
          title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitulo),
          trailing: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _laranja,
              foregroundColor: Colors.black,
              minimumSize: const Size(90, 40),
              disabledBackgroundColor: Colors.white12,
            ),
            onPressed: pode ? aoComprar : null,
            child: FittedBox(child: Text(reais(preco))),
          ),
        ),
      );
}

/// Fachada da loja: toldo listrado, balcão, placa e clientes na calçada.
class _PintorLoja extends CustomPainter {
  final List<_Cliente> clientes;
  final double t;
  final PintorEmoji pintor;
  final bool vip;
  _PintorLoja(this.clientes, this.t, this.pintor, this.vip);

  @override
  void paint(Canvas c, Size s) {
    // céu e parede
    c.drawRect(Offset.zero & s,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4FC3F7), Color(0xFFB3E5FC)],
          ).createShader(Offset.zero & s));
    final loja = Rect.fromLTWH(s.width * 0.2, s.height * 0.12, s.width * 0.6, s.height * 0.68);
    c.drawRect(loja, Paint()..color = const Color(0xFFFFE0B2));
    // toldo listrado
    final listras = 10;
    final w = loja.width / listras;
    for (var k = 0; k < listras; k++) {
      final r = Rect.fromLTWH(loja.left + k * w, loja.top, w, s.height * 0.2);
      c.drawRect(r, Paint()..color = k.isEven ? const Color(0xFFFF7043) : Colors.white);
      c.drawArc(Rect.fromLTWH(r.left, r.bottom - w / 2, w, w), 0, pi, true,
          Paint()..color = k.isEven ? const Color(0xFFFF7043) : Colors.white);
    }
    // placa
    final tp = TextPainter(
      text: const TextSpan(
          text: '🧃 IMPÉRIO DO SUCO',
          style: TextStyle(color: Color(0xFF5D4037), fontWeight: FontWeight.w900, fontSize: 12)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(s.width / 2 - tp.width / 2, loja.top + s.height * 0.3));
    // balcão com frutas
    final balcao = Rect.fromLTWH(loja.left + 8, loja.bottom - s.height * 0.2, loja.width - 16, s.height * 0.2);
    c.drawRRect(RRect.fromRectAndRadius(balcao, const Radius.circular(4)), Paint()..color = const Color(0xFF8D6E63));
    for (var k = 0; k < 5; k++) {
      pintor.desenhar(c, const ['🍋', '🍊', '🍓', '🥥', '🍉'][k], 14,
          Offset(balcao.left + balcao.width * (0.15 + k * 0.17), balcao.top - 6));
    }
    // calçada
    c.drawRect(Rect.fromLTWH(0, s.height * 0.8, s.width, s.height * 0.2), Paint()..color = const Color(0xFFBDBDBD));
    // clientes
    for (final cl in clientes) {
      final y = s.height * 0.8 - 2 * sin(t * 12 + cl.fase).abs();
      final pos = Offset(cl.x * s.width, y);
      if (cl.vip) {
        c.drawCircle(pos - const Offset(0, 14), 20 + 3 * sin(t * 6),
            Paint()
              ..color = Cores.ouro.withValues(alpha: 0.5)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      }
      pintor.desenhar(c, cl.emoji, cl.vip ? 30 : 24, pos - const Offset(0, 14));
    }
    if (vip) {
      final aviso = TextPainter(
        text: const TextSpan(
            text: '🌟 Toque no cliente VIP!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
        textDirection: TextDirection.ltr,
      )..layout();
      aviso.paint(c, Offset(s.width / 2 - aviso.width / 2, 2 + 2 * sin(t * 5)));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
