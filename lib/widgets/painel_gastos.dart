import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/progresso.dart';
import '../theme.dart';

/// Aceita "1.234,56", "1234,56" e também "760.94" (ponto como decimal).
double lerValorReais(String texto) {
  var t = texto.trim();
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'\.\d{3}$').hasMatch(t)) {
    t = t.replaceAll('.', ''); // 1.500 = mil e quinhentos
  }
  return double.tryParse(t) ?? 0;
}

enum _Periodo { dia, semana, mes }

/// Mini painel da tela inicial: quanto o vício custa por mês e o que dá para juntar.
class PainelGastos extends StatefulWidget {
  final double gastoDiario;
  final Future<void> Function(double novoGastoDiario) aoSalvar;
  const PainelGastos({super.key, required this.gastoDiario, required this.aoSalvar});

  @override
  State<PainelGastos> createState() => _PainelGastosState();
}

class _PainelGastosState extends State<PainelGastos> {
  late final TextEditingController _campo;
  _Periodo _periodo = _Periodo.mes;
  late double _mensal;
  Timer? _salvar;

  @override
  void initState() {
    super.initState();
    _mensal = widget.gastoDiario * diasPorMes;
    _campo = TextEditingController(text: _formatar(_mensal));
  }

  @override
  void dispose() {
    // saiu da tela antes do salvamento automático: salva agora para não perder o valor
    if (_salvar?.isActive ?? false) widget.aoSalvar(_mensal / diasPorMes);
    _salvar?.cancel();
    _campo.dispose();
    super.dispose();
  }

  String _formatar(double v) =>
      v == 0 ? '' : v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2).replaceAll('.', ',');

  double _paraMensal(double v) => switch (_periodo) {
    _Periodo.dia => v * diasPorMes,
    _Periodo.semana => v * diasPorMes / 7,
    _Periodo.mes => v,
  };

  double _doMensal(double m) => switch (_periodo) {
    _Periodo.dia => m / diasPorMes,
    _Periodo.semana => m * 7 / diasPorMes,
    _Periodo.mes => m,
  };

  void _mudou(String texto) {
    final v = lerValorReais(texto);
    setState(() => _mensal = _paraMensal(v));
    _salvar?.cancel();
    _salvar = Timer(const Duration(milliseconds: 900), () => widget.aoSalvar(_mensal / diasPorMes));
  }

  void _trocarPeriodo(_Periodo p) {
    setState(() {
      _periodo = p;
      _campo.text = _formatar(double.parse(_doMensal(_mensal).toStringAsFixed(2)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final proj = projecoesGasto(_mensal);
    final dezAnosInvestindo = comRendimento(_mensal, 120);
    final sonhoAno = oQueDaPraComprar(_mensal * 12);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '💸 Quanto o vício custa',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Bebida, cigarro, apostas ou o que for. Quanto você gastava?',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _campo,
                    onChanged: _mudou,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(prefixText: 'R\$ ', hintText: '0', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<_Periodo>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: _Periodo.dia, label: Text('dia')),
                    ButtonSegment(value: _Periodo.semana, label: Text('sem.')),
                    ButtonSegment(value: _Periodo.mes, label: Text('mês')),
                  ],
                  selected: {_periodo},
                  onSelectionChanged: (s) => _trocarPeriodo(s.first),
                ),
              ],
            ),
            if (_periodo != _Periodo.mes && _mensal > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('= ${dinheiro(_mensal)} por mês', style: const TextStyle(color: Colors.white70)),
              ),
            const SizedBox(height: 14),
            const Text('Ficando sóbrio, você junta:', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.35,
              children: [
                for (final p in proj)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: p.meses >= 60 ? Cores.verde : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: p.meses == 120 ? Border.all(color: Cores.ouro) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p.rotulo, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 2),
                        FittedBox(
                          child: Text(
                            dinheiro(p.total),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: p.meses >= 60 ? Cores.ouro : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF15724F), Cores.verde]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('10 anos rendendo', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 2),
                      FittedBox(
                        child: Text(
                          dinheiro(dezAnosInvestindo),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Cores.ouro,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_mensal > 0) ...[
              const SizedBox(height: 10),
              Text(
                sonhoAno != null
                    ? 'Em 1 ano, só com esse dinheiro, dá para ter $sonhoAno'
                    : 'Cada real guardado é um passo para um sonho seu. 💚',
                style: const TextStyle(color: Cores.ouro),
              ),
              const Text(
                '"10 anos rendendo": guardando todo mês com ~0,6% ao mês, perto da poupança.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
