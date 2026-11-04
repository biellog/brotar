import 'dart:math';

import 'package:fica_sobrio/games/tycoon/motor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('começa com limonada nível 1 e tocar faz vender', () {
    final m = MotorTycoon(Random(1));
    expect(m.estados[0].nivel, 1);
    expect(m.tocar(0), isTrue);
    expect(m.tocar(0), isFalse); // já está preparando
    final vendas = <Venda>[];
    for (var i = 0; i < 20; i++) {
      vendas.addAll(m.passo(0.05));
    }
    expect(vendas.length, 1); // 1 ciclo de 0,8 s, sem gerente não repete sozinho
    expect(m.dinheiro, 1);
  });

  test('custo cresce em progressão geométrica e MAX nunca passa do caixa', () {
    final m = MotorTycoon(Random(1));
    expect(m.custo(0, 1), closeTo(4 * 1.07, 1e-9));
    expect(m.custo(0, 10), closeTo(4 * 1.07 * (pow(1.07, 10) - 1) / 0.07, 1e-6));
    m.dinheiro = 1000;
    final n = m.maxCompravel(0);
    expect(m.custo(0, n), lessThanOrEqualTo(1000));
    expect(m.custo(0, n + 1), greaterThan(1000));
    expect(m.comprar(0, n), isA<bool>());
    expect(m.dinheiro, greaterThanOrEqualTo(0));
  });

  test('não compra sem dinheiro (nem gerente, nem melhoria)', () {
    final m = MotorTycoon(Random(1));
    expect(m.comprar(1, 1), isFalse);
    expect(m.comprarGerente(0), isFalse);
    expect(m.comprarMelhoria(0), isFalse);
    expect(m.dinheiro, 0);
  });

  test('marco no nível 25 dobra a velocidade', () {
    final m = MotorTycoon(Random(1))..dinheiro = 1e9;
    final antes = m.tempo(0);
    expect(m.comprar(0, 24), isTrue); // 1 + 24 = 25
    expect(m.tempo(0), closeTo(antes / 2, 1e-9));
  });

  test('gerente vende sozinho e gera ganho offline (até 3 h)', () {
    final m = MotorTycoon(Random(1))..dinheiro = 2000;
    expect(m.comprarGerente(0), isTrue);
    for (var i = 0; i < 100; i++) {
      m.passo(0.1); // 10 s
    }
    expect(m.dinheiro, closeTo(1000 + 10 / 0.8 * 1, 2));
    final porSeg = m.ganhoPorSegundo;
    expect(m.ganhoOffline(100 * 3600), closeTo(porSeg * 3 * 3600, 1e-6)); // limitado a 3 h
  });

  test('melhoria multiplica a receita', () {
    final m = MotorTycoon(Random(1))..dinheiro = 1e6;
    final r = m.receita(0);
    expect(m.comprarMelhoria(0), isTrue);
    expect(m.receita(0), closeTo(r * 3, 1e-9));
    expect(m.comprarMelhoria(0), isFalse); // não compra duas vezes
  });

  test('nova filial reinicia e dá estrelas que aumentam a receita', () {
    final m = MotorTycoon(Random(1));
    expect(m.abrirFilial(), isFalse); // sem faturamento, sem estrelas
    m.ganhoDaVida = 4e9; // 10·√4 = 20 estrelas
    m.dinheiro = 5e8;
    m.estados[1].nivel = 50;
    expect(m.estrelasNovas, 20);
    expect(m.abrirFilial(), isTrue);
    expect(m.estrelas, 20);
    expect(m.dinheiro, 0);
    expect(m.estados[1].nivel, 0);
    expect(m.estados[0].nivel, 1);
    expect(m.multEstrelas, closeTo(2.0, 1e-9)); // +5% x 20
    expect(m.estrelasNovas, 0);
  });

  test('cliente VIP aparece e dá gorjeta uma vez', () {
    final m = MotorTycoon(Random(1));
    for (var i = 0; i < 300 && m.vipVisivel <= 0; i++) {
      m.passo(0.1);
    }
    expect(m.vipVisivel, greaterThan(0));
    expect(m.atenderVip(), greaterThanOrEqualTo(50));
    expect(m.atenderVip(), 0);
  });

  test('salvar e carregar mantém o jogo e mede o tempo fora', () {
    final m = MotorTycoon(Random(1))..dinheiro = 1e6;
    m.comprar(0, 30);
    m.comprarGerente(0);
    m.comprarMelhoria(0);
    final agora = DateTime(2026, 11, 4, 10);
    final json = m.paraJson(agora);
    final n = MotorTycoon(Random(2));
    final fora = n.carregar(json, agora.add(const Duration(minutes: 10)));
    expect(fora, 600);
    expect(n.estados[0].nivel, 31);
    expect(n.estados[0].gerente, isTrue);
    expect(n.compradas, {0});
    expect(n.dinheiro, m.dinheiro);
  });

  test('carregar ignora dados corrompidos', () {
    final n = MotorTycoon(Random(2));
    n.carregar({'compradas': [999, -1, 2], 'produtos': [{'n': -5}]}, DateTime.now());
    expect(n.compradas, {2});
    expect(n.estados[0].nivel, 1);
  });

  test('formata dinheiro grande em português', () {
    expect(reais(1.5), 'R\$ 1,50');
    expect(reais(999), 'R\$ 999');
    expect(reais(12345), 'R\$ 12,3 mil');
    expect(reais(4.56e6), 'R\$ 4,56 mi');
    expect(reais(7.8e9), 'R\$ 7,80 bi');
    expect(reais(1e40), contains('e+'));
  });
}
