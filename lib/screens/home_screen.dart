import 'dart:async';

import 'package:flutter/material.dart';

import '../data/atualizacao.dart';
import '../data/instalador.dart';
import '../data/notificacoes.dart';
import '../data/repo.dart';
import '../logic/progresso.dart';
import '../theme.dart';
import '../widgets/compartilhar.dart';
import 'checkin_sheet.dart';
import 'jogos_tab.dart';
import 'perfil_screen.dart';
import 'sos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _aba = 0;
  int _versao = 0; // força recarregar a aba Início quando voltamos dela
  VersaoApp? _novaVersao;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciarAtualizacoes());
  }

  Future<void> _iniciarAtualizacoes() async {
    await Notificacoes.iniciar(aoTocar: _mostrarAtualizacao);
    await Notificacoes.agendarVerificacao();
    final nova = await Atualizacao.verificar();
    if (nova == null) {
      await Instalador.limpar(); // já atualizado: apaga o APK baixado
      return;
    }
    if (!mounted) return;
    setState(() => _novaVersao = nova);
    Repo.log('atualizacao_disponivel', {'versao': nova.nome});
    await Notificacoes.avisarAtualizacao(nova);
    if (mounted) await Atualizacao.mostrarDialogo(context, nova);
  }

  Future<void> _mostrarAtualizacao() async {
    final nova = _novaVersao ?? await Atualizacao.verificar();
    if (nova != null && mounted) await Atualizacao.mostrarDialogo(context, nova);
  }

  static const _nomesAbas = ['inicio', 'jogo', 'sos', 'perfil'];

  void _irPara(int i) {
    setState(() {
      _aba = i;
      _versao++;
    });
    Repo.log('tela', {'nome': _nomesAbas[i]});
  }

  @override
  Widget build(BuildContext context) {
    final telas = [
      InicioTab(key: ValueKey('inicio$_versao'), irPara: _irPara, novaVersao: _novaVersao),
      const JogoTab(),
      SosScreen(irParaJogo: () => _irPara(1)),
      PerfilScreen(key: ValueKey('perfil$_versao')),
    ];
    return Scaffold(
      body: SafeArea(child: telas[_aba]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: _irPara,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.sports_esports_outlined), selectedIcon: Icon(Icons.sports_esports), label: 'Jogo'),
          NavigationDestination(icon: Icon(Icons.sos_outlined, color: Cores.perigo), selectedIcon: Icon(Icons.sos, color: Cores.perigo), label: 'SOS'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

// ======================================================================
class InicioTab extends StatefulWidget {
  final void Function(int) irPara;
  final VersaoApp? novaVersao;
  const InicioTab({super.key, required this.irPara, this.novaVersao});

  @override
  State<InicioTab> createState() => _InicioTabState();
}

class _InicioTabState extends State<InicioTab> {
  Map<String, dynamic>? _perfil;
  Set<String> _hoje = {};
  int _recorde = 0;
  bool _carregando = true;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _carregar();
    _relogio = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  DateTime get _inicio =>
      DateTime.tryParse(_perfil?['data_inicio'] ?? '')?.toLocal() ?? DateTime.now();

  Future<void> _carregar() async {
    try {
      final resultados = await Future.wait([
        Repo.perfil(),
        Repo.eventosHoje(),
        Repo.recorde(),
      ]);
      if (!mounted) return;
      setState(() {
        _perfil = resultados[0] as Map<String, dynamic>?;
        _hoje = resultados[1] as Set<String>;
        _recorde = resultados[2] as int;
        _carregando = false;
      });
      await _verificarConquistas();
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sem conexão. Puxe para atualizar. ($e)')),
      );
    }
  }

  Future<void> _verificarConquistas() async {
    final ja = await Repo.conquistas();
    final ctx = Contexto(
      dias: tempoSobrio(_inicio).inDays,
      recorde: _recorde,
      partidas: await Repo.totalPartidas(),
      fissurasVencidas: await Repo.fissurasVencidas(),
      convidou: _perfil?['convidado_por'] != null,
    );
    for (final c in conquistasLista) {
      if (!ja.contains(c.codigo) && c.regra(ctx)) {
        await Repo.desbloquear(c.codigo);
        await Repo.somarXp(100);
        if (!mounted) return;
        await _mostrarConquista(c);
      }
    }
  }

  Future<void> _mostrarConquista(Conquista c) => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Conquista desbloqueada!', textAlign: TextAlign.center),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(c.emoji, style: const TextStyle(fontSize: 72)),
            Text(c.titulo, style: Theme.of(context).textTheme.titleLarge),
            Text(c.descricao),
            const SizedBox(height: 8),
            const Text('+100 XP', style: TextStyle(color: Cores.ouro, fontWeight: FontWeight.bold)),
          ]),
          actions: [
            TextButton(
              onPressed: () => compartilhar(
                'Desbloqueei "${c.titulo}" ${c.emoji} no Fica Sóbrio: ${c.descricao}!',
                codigoConvite: _perfil?['codigo_convite'],
                origem: 'conquista_${c.codigo}',
              ),
              child: const Text('Compartilhar'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Uhuu!')),
          ],
        ),
      );

  Future<void> _abrirCheckin() async {
    final salvou = await mostrarCheckin(context);
    if (salvou == true) _carregar();
  }

  Future<void> _missaoAgua() async {
    if (_hoje.contains('missao_agua')) return;
    await Repo.log('missao_agua');
    await Repo.somarXp(5);
    _carregar();
  }

  Future<void> _recaida() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tudo bem. Respira. 💚'),
        content: const Text(
          'Uma recaída não apaga o caminho que você fez. Você mantém seu XP, nível e '
          'conquistas — só o contador de dias recomeça.\n\nQuer recomeçar a contagem agora?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Não')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Recomeçar')),
        ],
      ),
    );
    if (ok == true) {
      await Repo.registrarRecaida();
      await Repo.somarXp(10); // honestidade também conta
      _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    final tempo = tempoSobrio(_inicio);
    final nivel = nivelDe((_perfil?['xp'] as num?)?.toInt() ?? 0);
    final gasto = (_perfil?['gasto_diario'] as num?) ?? 0;
    final economia = gasto * tempo.inMinutes / (60 * 24);
    final nome = _perfil?['nome'] ?? '';

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(
              child: Text('Olá, $nome 👋',
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Chip(
              avatar: const Icon(Icons.bolt, color: Cores.ouro, size: 18),
              label: Text('Nv ${nivel.numero} · ${nivel.titulo}'),
            ),
          ]),
          const SizedBox(height: 12),
          if (widget.novaVersao != null) ...[
            Card(
              color: Cores.ouro,
              child: ListTile(
                leading: const Text('🚀', style: TextStyle(fontSize: 28)),
                title: Text('Nova versão ${widget.novaVersao!.nome}',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                subtitle: const Text('Toque para atualizar o app', style: TextStyle(color: Colors.black87)),
                trailing: const Icon(Icons.system_update, color: Colors.black),
                onTap: () => Atualizacao.mostrarDialogo(context, widget.novaVersao!),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // ------- Contador -------
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Cores.verde, Color(0xFF15724F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(children: [
              const Text('VOCÊ ESTÁ SÓBRIO HÁ', style: TextStyle(letterSpacing: 2, color: Colors.white70)),
              Text('${tempo.inDays}',
                  style: t.displayLarge?.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
              Text(tempo.inDays == 1 ? 'dia' : 'dias', style: t.titleLarge),
              const SizedBox(height: 4),
              Text('${tempo.inHours % 24}h ${tempo.inMinutes % 60}min',
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => compartilhar(
                  'Estou há ${tempo.inDays} dias sóbrio e já economizei ${dinheiro(economia)}! 💪',
                  codigoConvite: _perfil?['codigo_convite'],
                  origem: 'contador',
                ),
                icon: const Icon(Icons.share, color: Cores.ouro),
                label: const Text('Compartilhar minha vitória', style: TextStyle(color: Cores.ouro)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _Stat('💰', dinheiro(economia), 'economizados'),
            const SizedBox(width: 8),
            _Stat('⚡', '${nivel.xp}', 'XP total'),
            const SizedBox(width: 8),
            _Stat('🎮', '$_recorde', 'recorde'),
          ]),
          const SizedBox(height: 12),
          // ------- Nível -------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Nível ${nivel.numero} — ${nivel.titulo}', style: t.titleMedium),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: nivel.progresso,
                    minHeight: 12,
                    color: Cores.ouro,
                    backgroundColor: Colors.white12,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Faltam ${nivel.faltam} XP para o próximo nível',
                    style: const TextStyle(color: Colors.white60)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // ------- Missões -------
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                const ListTile(title: Text('🎯 Missões de hoje', style: TextStyle(fontWeight: FontWeight.bold))),
                _Missao('Fazer o check-in diário', '+20 XP', _hoje.contains('checkin'), _abrirCheckin),
                _Missao('Jogar um dos jogos', '+XP', _hoje.contains('partida'), () => widget.irPara(1)),
                _Missao('Beber um copo d\'água 💧', '+5 XP', _hoje.contains('missao_agua'), _missaoAgua),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // ------- Motivo e frase -------
          if ((_perfil?['motivo'] ?? '').toString().isNotEmpty)
            Card(
              child: ListTile(
                leading: const Text('❤️', style: TextStyle(fontSize: 28)),
                title: const Text('Seu motivo'),
                subtitle: Text(_perfil!['motivo']),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Text('💬', style: TextStyle(fontSize: 28)),
              title: const Text('Frase do dia'),
              subtitle: Text(fraseDoDia()),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Cores.perigo),
            onPressed: () => widget.irPara(2),
            icon: const Icon(Icons.sos),
            label: const Text('Estou com vontade agora'),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _recaida, child: const Text('Tive uma recaída')),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String emoji, valor, rotulo;
  const _Stat(this.emoji, this.valor, this.rotulo);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              FittedBox(
                child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              Text(rotulo, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          ),
        ),
      );
}

class _Missao extends StatelessWidget {
  final String titulo, premio;
  final bool feita;
  final VoidCallback aoTocar;
  const _Missao(this.titulo, this.premio, this.feita, this.aoTocar);

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: feita ? null : aoTocar,
        leading: Icon(feita ? Icons.check_circle : Icons.radio_button_unchecked,
            color: feita ? Cores.verdeClaro : Colors.white38),
        title: Text(titulo,
            style: TextStyle(decoration: feita ? TextDecoration.lineThrough : null)),
        trailing: Text(premio, style: const TextStyle(color: Cores.ouro)),
      );
}
