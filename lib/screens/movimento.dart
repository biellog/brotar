import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/musica.dart';
import '../data/repo.dart';
import '../logic/movimento.dart';
import '../theme.dart';
import 'jogos_tab.dart';

// =====================================================================
// Aba Movimento
// =====================================================================
class MovimentoTab extends StatefulWidget {
  final VoidCallback irParaJogos;
  const MovimentoTab({super.key, required this.irParaJogos});

  @override
  State<MovimentoTab> createState() => _MovimentoTabState();
}

class _MovimentoTabState extends State<MovimentoTab> {
  int _total = 0;
  Map<String, int> _porTipo = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final r = await Future.wait([Repo.totalAtividades(), Repo.atividadesPorTipo()]);
      if (!mounted) return;
      setState(() {
        _total = r[0] as int;
        _porTipo = r[1] as Map<String, int>;
      });
    } catch (_) {}
  }

  Future<void> _abrir(Atividade a) async {
    Repo.log('tela', {'nome': 'atividade_${a.id}'});
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => a.tipo == TipoAtividade.passos
          ? AtividadePassosScreen(atividade: a)
          : AtividadeGuiadaScreen(atividade: a),
    ));
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final proximo = desbloqueios.where((d) => _total < d.atividadesNecessarias).firstOrNull;
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Movimento', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text(
            'Mexer o corpo diminui a ansiedade e a vontade. Cada atividade concluída '
            'dá XP e libera jogos relaxantes novos. 🌿',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          // ---------- Progresso das recompensas ----------
          Card(
            color: Cores.verde,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('🎁 Recompensas: $_total atividade${_total == 1 ? '' : 's'} concluída${_total == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                for (final d in desbloqueios) _LinhaDesbloqueio(d, _total),
                if (proximo != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Faltam ${proximo.atividadesNecessarias - _total} para liberar '
                    '${infoJogo(proximo.jogoId).nome}.',
                    style: const TextStyle(color: Cores.ouro),
                  ),
                ] else
                  TextButton(onPressed: widget.irParaJogos, child: const Text('Todos liberados! Ver jogos →')),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          for (final a in atividades) ...[
            Material(
              color: Cores.card,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _abrir(a),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Text(a.emoji, style: const TextStyle(fontSize: 40)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(a.descricao, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('✅ ${_porTipo[a.id] ?? 0}x  ·  +30 XP',
                            style: const TextStyle(color: Cores.ouro, fontSize: 13)),
                      ]),
                    ),
                    const Icon(Icons.play_circle_fill, size: 40, color: Cores.ouro),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Se sentir dor, tontura ou falta de ar, pare. Em caso de problemas de saúde, '
            'converse com um profissional antes de começar.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LinhaDesbloqueio extends StatelessWidget {
  final Desbloqueio d;
  final int total;
  const _LinhaDesbloqueio(this.d, this.total);

  @override
  Widget build(BuildContext context) {
    final j = infoJogo(d.jogoId);
    final ok = total >= d.atividadesNecessarias;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(ok ? j.emoji : '🔒', style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(child: Text(j.nome, style: TextStyle(color: ok ? Colors.white : Colors.white60))),
        Text(ok ? 'liberado' : '${total.clamp(0, d.atividadesNecessarias)}/${d.atividadesNecessarias}',
            style: TextStyle(color: ok ? Cores.verdeClaro : Colors.white60)),
      ]),
    );
  }
}

// =====================================================================
// Conclusão: XP + jogos liberados
// =====================================================================
Future<void> concluirAtividade(BuildContext context, Atividade a, int duracaoSeg, int passos) async {
  var antes = 0, depois = 0, xp = 0;
  try {
    antes = await Repo.totalAtividades();
    await Repo.registrarAtividade(a.id, duracaoSeg, passos);
    depois = antes + 1;
    final perfil = await Repo.perfil();
    final xpAntes = (perfil?['xp'] as num?)?.toInt() ?? 0;
    xp = (await Repo.somarXp(30, 'movimento')) - xpAntes;
  } catch (_) {}
  final novos = novosDesbloqueios(antes, depois);
  HapticFeedback.mediumImpact();
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('🎉 Atividade concluída!', textAlign: TextAlign.center),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(a.emoji, style: const TextStyle(fontSize: 64)),
        Text(a.nome, style: Theme.of(ctx).textTheme.titleLarge),
        if (passos > 0) Text('$passos passos'),
        Text('${duracaoSeg ~/ 60} min ${duracaoSeg % 60} s'),
        const SizedBox(height: 8),
        Text(xp > 0 ? '+$xp XP' : 'Limite de XP de movimento de hoje atingido',
            style: const TextStyle(color: Cores.ouro, fontWeight: FontWeight.bold)),
        for (final id in novos) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Cores.verde,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Cores.ouro),
            ),
            child: Row(children: [
              Text(infoJogo(id).emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Jogo novo liberado:\n${infoJogo(id).nome}!',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ],
      ]),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Uhuu!')),
      ],
    ),
  );
  if (context.mounted) Navigator.of(context).pop();
}

// =====================================================================
// Caminhada / corrida (contador de passos)
// =====================================================================
class AtividadePassosScreen extends StatefulWidget {
  final Atividade atividade;
  const AtividadePassosScreen({super.key, required this.atividade});

  @override
  State<AtividadePassosScreen> createState() => _AtividadePassosScreenState();
}

class _AtividadePassosScreenState extends State<AtividadePassosScreen> {
  final _contador = ContadorPassos();
  final _inicio = DateTime.now();
  StreamSubscription<StepCount>? _sub;
  Timer? _relogio;
  bool _semSensor = false;
  bool _concluindo = false;
  String _status = 'Preparando o contador de passos...';

  Atividade get a => widget.atividade;
  int get _segundos => DateTime.now().difference(_inicio).inSeconds;

  @override
  void initState() {
    super.initState();
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _verificarMeta();
    });
    _iniciarSensor();
  }

  Future<void> _iniciarSensor() async {
    try {
      final perm = await Permission.activityRecognition.request();
      if (!perm.isGranted) return _usarTempo('Sem permissão para contar passos: vamos contar pelo tempo.');
      _sub = Pedometer.stepCountStream.listen(
        (e) {
          if (!mounted) return;
          setState(() {
            _contador.novoValor(e.steps);
            _status = 'Contando seus passos. Pode guardar o celular no bolso. 👟';
          });
          _verificarMeta();
        },
        onError: (_) => _usarTempo('Seu celular não tem contador de passos: vamos contar pelo tempo.'),
      );
      // alguns aparelhos só mandam o primeiro valor depois de alguns passos
      setState(() => _status = 'Comece a andar: os passos aparecem em instantes. 👟');
    } catch (_) {
      _usarTempo('Seu celular não tem contador de passos: vamos contar pelo tempo.');
    }
  }

  void _usarTempo(String motivo) {
    if (!mounted) return;
    _sub?.cancel();
    setState(() {
      _semSensor = true;
      _status = motivo;
    });
  }

  double get _progresso => _semSensor
      ? (_segundos / (a.metaMinutosSemSensor * 60)).clamp(0.0, 1.0)
      : _contador.progresso(a.metaPassos);

  void _verificarMeta() {
    if (_concluindo || _progresso < 1) return;
    _concluindo = true;
    _relogio?.cancel();
    _sub?.cancel();
    Musica.efeito(Efeito.bolhaCerta);
    concluirAtividade(context, a, _segundos, _contador.passos);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _relogio?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _segundos;
    final tempo = '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: Text('${a.emoji} ${a.nome}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            SizedBox(
              width: 240,
              height: 240,
              child: Stack(fit: StackFit.expand, children: [
                CircularProgressIndicator(
                  value: _progresso,
                  strokeWidth: 16,
                  backgroundColor: Colors.white12,
                  color: Cores.verdeClaro,
                ),
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_semSensor ? tempo : '${_contador.passos}',
                        style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900)),
                    Text(_semSensor ? 'de ${a.metaMinutosSemSensor}:00 min' : 'de ${a.metaPassos} passos',
                        style: const TextStyle(color: Colors.white70)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            if (!_semSensor)
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Text('⏱️ $tempo', style: const TextStyle(fontSize: 20)),
                Text('📍 ${_contador.km.toStringAsFixed(2)} km', style: const TextStyle(fontSize: 20)),
              ]),
            const SizedBox(height: 16),
            Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const Spacer(),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Parar (sem recompensa)'),
            ),
          ]),
        ),
      ),
    );
  }
}

// =====================================================================
// Alongamento / treino (roteiro guiado com cronômetro)
// =====================================================================
class AtividadeGuiadaScreen extends StatefulWidget {
  final Atividade atividade;
  const AtividadeGuiadaScreen({super.key, required this.atividade});

  @override
  State<AtividadeGuiadaScreen> createState() => _AtividadeGuiadaScreenState();
}

class _AtividadeGuiadaScreenState extends State<AtividadeGuiadaScreen> {
  int _segundos = 0; // posição no roteiro (avança ao pular)
  int _real = 0; // tempo realmente feito (não conta os pulos)
  int _etapaAnterior = 0;
  bool _pausado = false;
  bool _concluindo = false;
  Timer? _timer;

  Atividade get a => widget.atividade;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_pausado || !mounted) return;
      setState(() {
        _segundos++;
        _real++;
      });
      final p = posicaoNoRoteiro(a.etapas, _segundos);
      if (p.etapa != _etapaAnterior) {
        _etapaAnterior = p.etapa;
        Musica.efeito(Efeito.carta);
        HapticFeedback.mediumImpact();
      }
      if (p.terminou && !_concluindo) {
        _concluindo = true;
        _timer?.cancel();
        if (_real >= a.duracaoGuiada * 0.6) {
          concluirAtividade(context, a, _real, 0);
        } else {
          _rapidoDemais();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _rapidoDemais() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quase!'),
        content: const Text(
          'Você pulou boa parte do roteiro. Para ganhar XP e liberar jogos, '
          'faça pelo menos a maior parte das etapas. Que tal de novo, com calma? 🧘',
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ok'))],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  void _pular() {
    final p = posicaoNoRoteiro(a.etapas, _segundos);
    setState(() => _segundos += p.restante);
  }

  @override
  Widget build(BuildContext context) {
    final p = posicaoNoRoteiro(a.etapas, _segundos);
    final e = a.etapas[p.etapa];
    final proxima = p.etapa + 1 < a.etapas.length ? a.etapas[p.etapa + 1] : null;
    return Scaffold(
      appBar: AppBar(title: Text('${a.emoji} ${a.nome}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Row(children: [
              for (var i = 0; i < a.etapas.length; i++)
                Expanded(
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i < p.etapa
                          ? Cores.verdeClaro
                          : (i == p.etapa ? Cores.ouro : Colors.white12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ]),
            const Spacer(),
            Text(e.emoji, style: const TextStyle(fontSize: 96)),
            const SizedBox(height: 12),
            Text(e.nome,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(e.dica, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, color: Colors.white70)),
            const SizedBox(height: 24),
            Text('${p.restante}',
                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Cores.ouro)),
            const Text('segundos'),
            const Spacer(),
            if (proxima != null)
              Text('Próximo: ${proxima.emoji} ${proxima.nome}', style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _pausado = !_pausado),
                  icon: Icon(_pausado ? Icons.play_arrow : Icons.pause),
                  label: Text(_pausado ? 'Continuar' : 'Pausar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pular,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Pular'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
