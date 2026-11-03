import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/repo.dart';
import '../games/comum.dart';
import '../theme.dart';

/// Botão de emergência para momentos de fissura ("urge surfing").
class SosScreen extends StatefulWidget {
  final VoidCallback irParaJogo;
  const SosScreen({super.key, required this.irParaJogo});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  static const _gatilhos = ['Estresse', 'Festa/Social', 'Tédio', 'Solidão', 'Tristeza', 'Comemoração', 'Briga', 'Outro'];

  late final AnimationController _resp = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14), // 4s inspira, 4s segura, 6s solta
  );
  Timer? _timer;
  int _segundos = 0;
  bool _ativo = false;
  double _intensidade = 6;
  String? _gatilho;

  @override
  void dispose() {
    _resp.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _comecar() {
    setState(() {
      _ativo = true;
      _segundos = 0;
    });
    _resp.repeat();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _segundos++));
    Repo.log('sos_iniciado', {'intensidade': _intensidade.round()});
  }

  Future<void> _encerrar(bool superou) async {
    _timer?.cancel();
    _resp.stop();
    final dur = _segundos;
    setState(() => _ativo = false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Repo.registrarFissura(
        intensidade: _intensidade.round(),
        gatilho: _gatilho,
        superou: superou,
        duracaoSeg: dur,
      );
      if (superou) await Repo.somarXp(50);
    } catch (_) {}
    messenger.showSnackBar(SnackBar(
      content: Text(superou
          ? 'Você surfou a onda! 🌊 +50 XP. Tenha orgulho disso.'
          : 'Obrigado por registrar. Amanhã é um novo dia, e você não está sozinho. 💚'),
    ));
  }

  Future<void> _abrir(String url, String tipo) async {
    Repo.log('ajuda_externa', {'tipo': tipo});
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String get _faseRespiracao {
    final s = _resp.value * 14;
    if (s < 4) return 'Inspire...';
    if (s < 8) return 'Segure...';
    return 'Solte devagar...';
  }

  double get _escala {
    final s = _resp.value * 14;
    if (s < 4) return 0.6 + 0.4 * (s / 4);
    if (s < 8) return 1.0;
    return 1.0 - 0.4 * ((s - 8) / 6);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mm = (_segundos ~/ 60).toString().padLeft(2, '0');
    final ss = (_segundos % 60).toString().padLeft(2, '0');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(children: [
          Expanded(child: Text('SOS Fissura', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w900))),
          const BotaoMusica(),
        ]),
        const SizedBox(height: 4),
        const Text('A vontade é como uma onda: sobe, atinge o pico e passa — '
            'geralmente em 15 a 20 minutos. Vamos atravessar juntos.'),
        const SizedBox(height: 20),
        if (!_ativo) ...[
          Text('Intensidade agora: ${_intensidade.round()}/10', style: t.titleMedium),
          Slider(
            value: _intensidade,
            max: 10,
            divisions: 10,
            activeColor: Color.lerp(Cores.ouro, Cores.perigo, _intensidade / 10),
            onChanged: (v) => setState(() => _intensidade = v),
          ),
          Text('O que provocou?', style: t.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _gatilhos
                .map((g) => ChoiceChip(
                      label: Text(g),
                      selected: _gatilho == g,
                      onSelected: (_) => setState(() => _gatilho = g),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Cores.perigo),
            onPressed: _comecar,
            icon: const Icon(Icons.waves),
            label: const Text('Surfar a onda agora'),
          ),
        ] else ...[
          Center(
            child: AnimatedBuilder(
              animation: _resp,
              builder: (_, _) => Column(children: [
                SizedBox(
                  height: 220,
                  child: Center(
                    child: Container(
                      width: 200 * _escala,
                      height: 200 * _escala,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          Cores.verdeClaro.withValues(alpha: 0.9),
                          Cores.verde.withValues(alpha: 0.4),
                        ]),
                      ),
                    ),
                  ),
                ),
                Text(_faseRespiracao, style: t.headlineSmall),
                const SizedBox(height: 4),
                Text('$mm:$ss', style: t.titleLarge?.copyWith(color: Cores.ouro)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: widget.irParaJogo,
            icon: const Icon(Icons.sports_esports),
            label: const Text('Distrair com um jogo'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _encerrar(true),
            icon: const Icon(Icons.emoji_events),
            label: const Text('Passou! Venci a fissura (+50 XP)'),
          ),
          TextButton(onPressed: () => _encerrar(false), child: const Text('Não consegui desta vez')),
        ],
        const SizedBox(height: 24),
        const Divider(),
        Text('Fale com alguém agora', style: t.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.phone, color: Cores.verdeClaro),
            title: const Text('CVV — 188 (24h, gratuito)'),
            subtitle: const Text('Apoio emocional por telefone'),
            onTap: () => _abrir('tel:188', 'cvv'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.phone, color: Cores.verdeClaro),
            title: const Text('Disque Saúde — 136'),
            subtitle: const Text('Informação sobre CAPS AD e tratamento pelo SUS'),
            onTap: () => _abrir('tel:136', 'disque_saude'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.groups, color: Cores.verdeClaro),
            title: const Text('Alcoólicos Anônimos'),
            subtitle: const Text('Encontre uma reunião perto de você'),
            onTap: () => _abrir('https://www.aa.org.br', 'aa'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.groups, color: Cores.verdeClaro),
            title: const Text('Narcóticos Anônimos'),
            onTap: () => _abrir('https://www.na.org.br', 'na'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.local_hospital, color: Cores.perigo),
            title: const Text('Emergência — SAMU 192'),
            subtitle: const Text('Tremores fortes, confusão, convulsão ou alucinação'),
            onTap: () => _abrir('tel:192', 'samu'),
          ),
        ),
      ],
    );
  }
}
