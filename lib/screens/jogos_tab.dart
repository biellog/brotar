import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../games/bolhas.dart';
import '../games/brilha/brilha_screen.dart';
import '../games/comum.dart';
import '../games/jardim_magico.dart';
import '../games/memoria.dart';
import '../games/relaxantes.dart';
import '../games/tempestade.dart';
import '../games/tycoon3d/tycoon_inicio.dart';
import '../logic/movimento.dart';
import '../theme.dart';

class InfoJogo {
  final String id, emoji, nome, descricao, tipo;
  final Color cor;
  final Widget Function() tela;
  const InfoJogo(this.id, this.emoji, this.nome, this.descricao, this.tipo, this.cor, this.tela);
}

final jogos = <InfoJogo>[
  InfoJogo('brilha', '🌟', 'Brilha Junto',
      'ONLINE: voe como vagalume, colete luzes e brilhe junto com pessoas do Brasil todo. Ninguém perde!',
      'Online', const Color(0xFFFFD166), () => const BrilhaScreen()),
  InfoJogo('tycoon', '🧃', 'Império do Suco 3D',
      'Mundo aberto em 3D: ande pela praça, faça sucos, venda no balcão, contrate ajudantes e abra 8 barracas!',
      'Simulador', const Color(0xFFFF9F1C), () => const TycoonInicio()),
  InfoJogo('tempestade', '⛈️', 'Desvia da Tempestade',
      'Arraste para pegar estrelas, gotas e trevos e fugir das tempestades.',
      'Agilidade', const Color(0xFF1FAF7A), () => const TempestadeScreen()),
  InfoJogo('bolhas', '🫧', 'Bolhas da Calma',
      'Estoure as bolhas boas em 45 segundos. Cuidado com as nuvens!',
      'Reflexo', const Color(0xFF3BB8D0), () => const BolhasScreen()),
  InfoJogo('memoria', '🧠', 'Memória Zen',
      'Encontre os 8 pares com calma. Ótimo para acalmar a mente.',
      'Foco', const Color(0xFFB98CF0), () => const MemoriaScreen()),
  InfoJogo('plastico', '🟦', 'Plástico Bolha',
      'Estoure quantas bolhas quiser. Arraste o dedo para estourar várias.',
      'Relaxante', const Color(0xFF5FD3E8), () => const PlasticoBolhaScreen()),
  InfoJogo('jardim', '🌷', 'Jardim Mágico',
      'Plante, regue arrastando o dedo e colha flores que explodem em pétalas. Faça combos!',
      'Relaxante', const Color(0xFF7BD389), () => const JardimMagicoScreen()),
  InfoJogo('mandala', '🎨', 'Mandala Mágica',
      'Desenhe com o dedo e veja tudo virar uma mandala simétrica.',
      'Relaxante', const Color(0xFFFF8FB1), () => const MandalaScreen()),
  InfoJogo('aquario', '🐠', 'Aquário da Calma',
      'Alimente os peixinhos e observe eles nadarem devagar.',
      'Relaxante', const Color(0xFF4FA3D9), () => const AquarioScreen()),
];

InfoJogo infoJogo(String id) => jogos.firstWhere((j) => j.id == id);

class JogoTab extends StatefulWidget {
  final VoidCallback? irParaMovimento;
  const JogoTab({super.key, this.irParaMovimento});

  @override
  State<JogoTab> createState() => _JogoTabState();
}

class _JogoTabState extends State<JogoTab> {
  Map<String, int> _recordes = {};
  int _atividades = 0;

  @override
  void initState() {
    super.initState();
    _atualizar();
  }

  Future<void> _atualizar() async {
    try {
      final r = await Future.wait([Repo.recordesPorJogo(), Repo.totalAtividades()]);
      if (mounted) {
        setState(() {
          _recordes = r[0] as Map<String, int>;
          _atividades = r[1] as int;
        });
      }
    } catch (_) {}
  }

  Future<void> _abrir(InfoJogo j) async {
    if (!jogoLiberado(j.id, _atividades)) {
      final falta = atividadesParaLiberar(j.id) - _atividades;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('🔒 ${j.nome}'),
          content: Text('Complete mais $falta atividade${falta == 1 ? '' : 's'} de movimento '
              '(caminhada, corrida, alongamento ou treino) para liberar este jogo.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Depois')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.irParaMovimento?.call();
              },
              child: const Text('Ir para Movimento'),
            ),
          ],
        ),
      );
      return;
    }
    Repo.log('tela', {'nome': 'jogo_${j.id}'});
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => j.tela(), fullscreenDialog: true),
    );
    _atualizar();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final online = jogos.where((j) => j.tipo == 'Online');
    final simuladores = jogos.where((j) => j.tipo == 'Simulador');
    final desafios = jogos.where((j) => !const {'Relaxante', 'Simulador', 'Online'}.contains(j.tipo));
    final relaxantes = jogos.where((j) => j.tipo == 'Relaxante');
    return RefreshIndicator(
      onRefresh: _atualizar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(
              child: Text('Jogos', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            ),
            const BotaoMusica(),
          ]),
          const SizedBox(height: 4),
          const Text(
            'A vontade dura, em média, de 15 a 20 minutos. Ocupar a mente e as mãos '
            'ajuda a onda passar. Cada 10 pontos = 1 XP.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Text('🌐 Online', style: t.titleMedium),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Cores.perigo, borderRadius: BorderRadius.circular(10)),
              child: const Text('NOVO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ]),
          const SizedBox(height: 8),
          for (final j in online) ...[
            _CartaoJogo(j, _recordes[j.id] ?? 0, true, 0, () => _abrir(j)),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          Text('🏪 Simulador', style: t.titleMedium),
          const SizedBox(height: 8),
          for (final j in simuladores) ...[
            _CartaoJogo(j, _recordes[j.id] ?? 0, true, 0, () => _abrir(j)),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          Text('🎯 Desafios', style: t.titleMedium),
          const SizedBox(height: 8),
          for (final j in desafios) ...[
            _CartaoJogo(j, _recordes[j.id] ?? 0, true, 0, () => _abrir(j)),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          Text('🌿 Para relaxar', style: t.titleMedium),
          const Text('Sem perder, sem pressa. Alguns são liberados com atividades de Movimento.',
              style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 8),
          for (final j in relaxantes) ...[
            _CartaoJogo(j, _recordes[j.id] ?? 0, jogoLiberado(j.id, _atividades),
                atividadesParaLiberar(j.id), () => _abrir(j)),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _CartaoJogo extends StatelessWidget {
  final InfoJogo j;
  final int recorde;
  final bool liberado;
  final int requer;
  final VoidCallback aoTocar;
  const _CartaoJogo(this.j, this.recorde, this.liberado, this.requer, this.aoTocar);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: liberado ? 1 : 0.6,
      child: Material(
        color: Cores.card,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: j.cor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(liberado ? j.emoji : '🔒', style: const TextStyle(fontSize: 34)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(j.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(j.descricao, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: j.cor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(j.tipo, style: TextStyle(color: j.cor, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        liberado ? '🏆 $recorde' : '🚶 Libera com $requer atividade${requer == 1 ? '' : 's'}',
                        style: const TextStyle(color: Cores.ouro, fontSize: 13),
                      ),
                    ),
                  ]),
                ]),
              ),
              Icon(liberado ? Icons.play_circle_fill : Icons.lock_outline, size: 40, color: Cores.ouro),
            ]),
          ),
        ),
      ),
    );
  }
}
