import 'dart:math';

import 'package:fica_sobrio/games/jardim_magico.dart';
import 'package:fica_sobrio/logic/progresso.dart';
import 'package:fica_sobrio/widgets/painel_gastos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('painel de gastos: projeções de 1 mês a 10 anos', () {
    final p = projecoesGasto(300);
    expect(p.map((e) => e.rotulo), ['1 mês', '5 meses', '1 ano', '5 anos', '10 anos']);
    expect(p.map((e) => e.total), [300, 1500, 3600, 18000, 36000]);
  });

  test('rendimento composto rende mais que só guardar', () {
    expect(comRendimento(300, 120, taxa: 0), 36000);
    final rendendo = comRendimento(300, 120);
    expect(rendendo, greaterThan(36000));
    expect(rendendo, closeTo(52350, 300)); // 0,6% ao mês por 10 anos
  });

  test('o que dá para comprar', () {
    expect(oQueDaPraComprar(100), isNull);
    expect(oQueDaPraComprar(3600), contains('celular'));
    expect(oQueDaPraComprar(1e6), contains('casa'));
  });

  test('jardim: planta, cresce, colhe com combo', () {
    final m = MotorJardim(Random(1));
    expect(m.tocar(const Offset(0.2, 0.2)), isNull); // céu não planta
    expect(m.tocar(const Offset(0.2, 0.6)), 'plantou');
    expect(m.tocar(const Offset(0.21, 0.6)), isNull); // muito perto de outra
    expect(m.tocar(const Offset(0.6, 0.7)), 'plantou');
    // cresce sozinha (sem regar ~11 s)
    for (var i = 0; i < 400; i++) {
      m.passo(0.05);
    }
    expect(m.plantas.every((p) => p.pronta), isTrue);
    final r1 = m.tocar(const Offset(0.2, 0.6));
    final r2 = m.tocar(const Offset(0.6, 0.7));
    expect([r1, r2].every((r) => r == 'colheu' || r == 'dourada'), isTrue);
    expect(m.colhidas, 2);
    expect(m.combo, 2); // colheu em sequência
    expect(m.pontos, greaterThanOrEqualTo(10 + 20));
  });

  test('jardim: regar faz crescer mais rápido', () {
    final normal = MotorJardim(Random(2))..tocar(const Offset(0.5, 0.6));
    final regado = MotorJardim(Random(2))..tocar(const Offset(0.5, 0.6));
    for (var i = 0; i < 40; i++) {
      normal.passo(0.05);
      regado.regar(const Offset(0.5, 0.6));
      regado.passo(0.05);
    }
    expect(regado.plantas.first.crescimento, greaterThan(normal.plantas.first.crescimento * 2));
  });

  test('painel entende valores em reais escritos de vários jeitos', () {
    expect(lerValorReais('760,94'), 760.94);
    expect(lerValorReais('1.234,56'), 1234.56);
    expect(lerValorReais('760.94'), 760.94);
    expect(lerValorReais('1.500'), 1500);
    expect(lerValorReais(''), 0);
  });

  test('jardim: o dia dura mais que o pôr do sol', () {
    final m = MotorJardim(Random(3));
    m.t = 40; // 40 s depois ainda é dia
    expect(m.ciclo, lessThan(0.25));
    m.t = 120; // 2 min: noite
    expect(m.ciclo, greaterThan(0.5));
  });
}
