import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../theme.dart';

class OnboardingScreen extends StatefulWidget {
  final Map<String, dynamic>? perfil;
  final VoidCallback aoConcluir;
  const OnboardingScreen({super.key, required this.perfil, required this.aoConcluir});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  DateTime _inicio = DateTime.now();
  final _gasto = TextEditingController();
  final _motivo = TextEditingController();
  final _convite = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _gasto.dispose();
    _motivo.dispose();
    _convite.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _inicio,
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
      helpText: 'Desde quando você está sóbrio?',
    );
    if (d != null) setState(() => _inicio = d);
  }

  Future<void> _concluir() async {
    setState(() => _salvando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final gasto = double.tryParse(_gasto.text.replaceAll(',', '.')) ?? 0;
      final agora = DateTime.now();
      // Se escolheu hoje, conta a partir de agora; senão, do começo do dia escolhido.
      final inicio = (_inicio.year == agora.year &&
              _inicio.month == agora.month &&
              _inicio.day == agora.day)
          ? agora
          : DateTime(_inicio.year, _inicio.month, _inicio.day);
      await Repo.salvarPerfil({
        'data_inicio': inicio.toUtc().toIso8601String(),
        'gasto_diario': gasto,
        'motivo': _motivo.text.trim(),
        'onboarding_ok': true,
      });
      await Repo.somarXp(50, 'onboarding');
      if (_convite.text.trim().isNotEmpty) {
        final ok = await Repo.usarConvite(_convite.text);
        messenger.showSnackBar(SnackBar(
          content: Text(ok ? 'Convite aceito! +100 XP pra você 🎉' : 'Código de convite inválido.'),
        ));
      }
      await Repo.log('onboarding_concluido', {'gasto_diario': gasto});
      widget.aoConcluir();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final nome = (widget.perfil?['nome'] as String?) ?? '';
    final d = _inicio;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Bem-vindo${nome.isEmpty ? '' : ', $nome'}! 👋',
                style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Vamos montar seu personagem. Cada dia sóbrio, check-in e fissura '
              'vencida te dá XP e você sobe de nível.',
            ),
            const SizedBox(height: 28),
            Text('1. Desde quando você está sóbrio?', style: t.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _escolherData,
              icon: const Icon(Icons.calendar_month),
              label: Text('${d.day.toString().padLeft(2, '0')}/'
                  '${d.month.toString().padLeft(2, '0')}/${d.year}'),
            ),
            const SizedBox(height: 4),
            const Text('Se é hoje que você começa, deixe a data de hoje. 💪',
                style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 24),
            Text('2. Quanto você gastava por dia (bebida, cigarro, etc.)?', style: t.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _gasto,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(prefixText: 'R\$ ', hintText: '30,00'),
            ),
            const SizedBox(height: 4),
            const Text('Vamos mostrar quanto dinheiro você está economizando.',
                style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 24),
            Text('3. Qual é o seu maior motivo?', style: t.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _motivo,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ex.: Estar presente para meus filhos',
              ),
            ),
            const SizedBox(height: 24),
            Text('4. Recebeu um código de convite? (opcional)', style: t.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _convite,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'ABC123'),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _salvando ? null : _concluir,
              child: _salvando
                  ? const CircularProgressIndicator()
                  : const Text('Começar (+50 XP)'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aviso: o Fica Sóbrio é um apoio, não substitui tratamento. '
              'Parar de beber de uma vez após uso pesado pode ser perigoso — procure um médico, '
              'um CAPS AD ou ligue 136 (Disque Saúde).',
              style: TextStyle(color: Cores.ouro, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
