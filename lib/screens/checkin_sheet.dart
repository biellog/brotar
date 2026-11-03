import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../theme.dart';

/// Abre o check-in diário. Retorna true se salvou.
Future<bool?> mostrarCheckin(BuildContext context) => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CheckinSheet(),
    );

class _CheckinSheet extends StatefulWidget {
  const _CheckinSheet();

  @override
  State<_CheckinSheet> createState() => _CheckinSheetState();
}

class _CheckinSheetState extends State<_CheckinSheet> {
  static const _humores = ['😣', '😕', '😐', '🙂', '😄'];
  int _humor = 3;
  double _fissura = 0;
  bool _sobrio = true;
  bool _jaFeito = false;
  bool _salvando = false;
  final _nota = TextEditingController();

  @override
  void initState() {
    super.initState();
    Repo.checkinHoje().then((c) {
      if (c == null || !mounted) return;
      setState(() {
        _jaFeito = true;
        _humor = (c['humor'] as num).toInt();
        _fissura = (c['fissura'] as num).toDouble();
        _sobrio = c['sobrio'] == true;
        _nota.text = c['nota'] ?? '';
      });
    });
  }

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    final nav = Navigator.of(context);
    try {
      await Repo.salvarCheckin(
        humor: _humor,
        fissura: _fissura.round(),
        sobrio: _sobrio,
        nota: _nota.text.trim().isEmpty ? null : _nota.text.trim(),
      );
      if (!_jaFeito) await Repo.somarXp(20);
      nav.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Como você está hoje?', style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final sel = _humor == i + 1;
              return GestureDetector(
                onTap: () => setState(() => _humor = i + 1),
                child: AnimatedScale(
                  scale: sel ? 1.35 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Opacity(
                    opacity: sel ? 1 : 0.45,
                    child: Text(_humores[i], style: const TextStyle(fontSize: 40)),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          Text('Vontade de beber/usar: ${_fissura.round()}/10', style: t.titleMedium),
          Slider(
            value: _fissura,
            max: 10,
            divisions: 10,
            activeColor: Color.lerp(Cores.verdeClaro, Cores.perigo, _fissura / 10),
            onChanged: (v) => setState(() => _fissura = v),
          ),
          SwitchListTile(
            value: _sobrio,
            onChanged: (v) => setState(() => _sobrio = v),
            title: const Text('Me mantive sóbrio desde o último check-in'),
          ),
          TextField(
            controller: _nota,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Diário (opcional): o que aconteceu hoje?'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _salvando ? null : _salvar,
            child: Text(_jaFeito ? 'Atualizar check-in' : 'Salvar check-in (+20 XP)'),
          ),
          if (!_sobrio)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Obrigado pela honestidade. Se quiser, use "Tive uma recaída" na tela inicial '
                'para recomeçar a contagem — seu XP continua com você. 💚',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
        ]),
      ),
    );
  }
}
