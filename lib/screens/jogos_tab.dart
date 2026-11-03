import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../games/bolhas.dart';
import '../games/comum.dart';
import '../games/memoria.dart';
import '../games/tempestade.dart';
import '../theme.dart';

class InfoJogo {
  final String id, emoji, nome, descricao, tipo;
  final Color cor;
  final Widget Function() tela;
  const InfoJogo(this.id, this.emoji, this.nome, this.descricao, this.tipo, this.cor, this.tela);
}

final jogos = <InfoJogo>[
  InfoJogo('tempestade', '⛈️', 'Desvia da Tempestade',
      'Arraste para pegar estrelas, gotas e trevos e fugir das tempestades.',
      'Agilidade', const Color(0xFF1FAF7A), () => const TempestadeScreen()),
  InfoJogo('bolhas', '🫧', 'Bolhas da Calma',
      'Estoure as bolhas boas em 45 segundos. Cuidado com as nuvens!',
      'Reflexo', const Color(0xFF3BB8D0), () => const BolhasScreen()),
  InfoJogo('memoria', '🧠', 'Memória Zen',
      'Encontre os 8 pares com calma. Ótimo para acalmar a mente.',
      'Foco', const Color(0xFFB98CF0), () => const MemoriaScreen()),
];

class JogoTab extends StatefulWidget {
  const JogoTab({super.key});

  @override
  State<JogoTab> createState() => _JogoTabState();
}

class _JogoTabState extends State<JogoTab> {
  Map<String, int> _recordes = {};

  @override
  void initState() {
    super.initState();
    _atualizar();
  }

  Future<void> _atualizar() async {
    try {
      final r = await Repo.recordesPorJogo();
      if (mounted) setState(() => _recordes = r);
    } catch (_) {}
  }

  Future<void> _abrir(InfoJogo j) async {
    Repo.log('tela', {'nome': 'jogo_${j.id}'});
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => j.tela(), fullscreenDialog: true),
    );
    _atualizar();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
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
          for (final j in jogos) ...[
            _CartaoJogo(j, _recordes[j.id] ?? 0, () => _abrir(j)),
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
  final VoidCallback aoTocar;
  const _CartaoJogo(this.j, this.recorde, this.aoTocar);

  @override
  Widget build(BuildContext context) {
    return Material(
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
              child: Text(j.emoji, style: const TextStyle(fontSize: 34)),
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
                  Text('🏆 $recorde', style: const TextStyle(color: Cores.ouro, fontSize: 13)),
                ]),
              ]),
            ),
            const Icon(Icons.play_circle_fill, size: 40, color: Cores.ouro),
          ]),
        ),
      ),
    );
  }
}
