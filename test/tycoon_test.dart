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

  test('missões: progresso, resgate com gemas e sempre 3 ativas', () {
    final m = MotorTycoon(Random(1));
    expect(m.missoesAtivas.length, 3);
    final primeira = m.missoesAtivas.first;
    expect(missoes[primeira].tipo, TipoMissao.vender);
    expect(m.resgatarMissao(primeira), -1); // ainda não cumpriu
    m.estados[0].vendas = 25;
    expect(m.progressoMissao(primeira), 1);
    expect(m.missoesProntas, greaterThanOrEqualTo(1));
    final gemasAntes = m.gemas;
    expect(m.resgatarMissao(primeira), greaterThan(0));
    expect(m.gemas, gemasAntes + missoes[primeira].gemas);
    expect(m.resgatarMissao(primeira), -1); // não resgata duas vezes
    expect(m.missoesAtivas.contains(primeira), isFalse);
    expect(m.missoesAtivas.length, 3);
  });

  test('há missões para todos os sucos e gerentes', () {
    for (var i = 0; i < produtos.length; i++) {
      expect(missoes.any((x) => x.tipo == TipoMissao.gerente && x.produto == i), isTrue);
    }
    expect(missoes.length, greaterThan(50));
  });

  test('hora do rush: combo cresce, dourado vale 5x, acaba no tempo', () {
    final m = MotorTycoon(Random(1));
    expect(m.atenderClienteRush(), 0); // sem rush
    m.iniciarRush();
    final v1 = m.atenderClienteRush();
    m.passo(0.3);
    final v2 = m.atenderClienteRush();
    expect(m.combo, 2);
    expect(v2, closeTo(v1 * 2, 1e-9));
    m.passo(0.3);
    final v3 = m.atenderClienteRush(dourado: true);
    expect(v3, closeTo(v1 * 3 * 5, 1e-9));
    m.passo(2); // demorou: combo zera
    expect(m.combo, 0);
    for (var i = 0; i < 400; i++) {
      m.passo(0.05);
    }
    expect(m.rush, 0);
    expect(m.clientesRush, 3);
  });

  test('rush acontece sozinho de tempos em tempos', () {
    final m = MotorTycoon(Random(1));
    var houve = false;
    for (var i = 0; i < 3000 && !houve; i++) {
      m.passo(0.1);
      houve = m.rush > 0;
    }
    expect(houve, isTrue);
  });

  test('turbos: x2 por 5 min, viagem no tempo, gemas insuficientes', () {
    final m = MotorTycoon(Random(1))..dinheiro = 5000;
    m.comprarGerente(0);
    expect(m.usarTurbo(Turbo.dobro), -1); // sem gemas
    m.gemas = 20;
    final base = m.receita(0);
    expect(m.usarTurbo(Turbo.dobro), 0);
    expect(m.receita(0), closeTo(base * 2, 1e-9));
    expect(m.gemas, 15);
    final antes = m.dinheiro;
    final v = m.usarTurbo(Turbo.tempo);
    expect(v, closeTo(m.ganhoPorSegundoBase * 3600, 1e-6));
    expect(m.dinheiro, closeTo(antes + v, 1e-6));
    for (var i = 0; i < 3100; i++) {
      m.passo(0.1);
    }
    expect(m.turboDobro, 0);
  });

  test('onda de calor triplica a receita por 30 s', () {
    final m = MotorTycoon(Random(1));
    final base = m.receita(0);
    var viu = false;
    for (var i = 0; i < 4000 && !viu; i++) {
      m.passo(0.1);
      viu = m.ondaCalor > 0;
    }
    expect(viu, isTrue);
    expect(m.receita(0), closeTo(base * 3, 1e-9));
  });

  test('nível do império sobe com o faturamento e dá gemas uma vez', () {
    final m = MotorTycoon(Random(1));
    expect(m.nivelImperio, 1);
    m.ganhoDaVida = 600; // 100 * 5 = 500 -> nível 3
    expect(m.nivelImperio, 3);
    expect(m.premiarNivelImperio(), 4);
    expect(m.premiarNivelImperio(), 0);
    m.ganhoDaVida = 1e15;
    expect(m.fachada, fachadas.length - 1);
    expect(m.progressoImperio(), inInclusiveRange(0, 1));
  });

  test('baú diário: 1 vez por dia', () {
    final m = MotorTycoon(Random(1));
    final hoje = DateTime(2026, 11, 4, 10);
    expect(m.podeAbrirBau(hoje), isTrue);
    final (g, v) = m.abrirBau(hoje);
    expect(g, inInclusiveRange(3, 8));
    expect(v, greaterThan(0));
    expect(m.podeAbrirBau(hoje.add(const Duration(hours: 5))), isFalse);
    expect(m.abrirBau(hoje).$1, 0);
    expect(m.podeAbrirBau(hoje.add(const Duration(days: 1))), isTrue);
  });

  test('salva e carrega gemas, missões, vendas e baú', () {
    final m = MotorTycoon(Random(1))
      ..gemas = 12
      ..vipsAtendidos = 4
      ..clientesRush = 50;
    m.estados[0].vendas = 30;
    m.resgatarMissao(m.missoesAtivas.first);
    m.abrirBau(DateTime(2026, 11, 4));
    final n = MotorTycoon(Random(2))..carregar(m.paraJson(DateTime(2026, 11, 4)), DateTime(2026, 11, 4));
    expect(n.gemas, m.gemas);
    expect(n.missoesFeitas, m.missoesFeitas);
    expect(n.estados[0].vendas, 30);
    expect(n.vipsAtendidos, 4);
    expect(n.clientesRush, 50);
    expect(n.podeAbrirBau(DateTime(2026, 11, 4, 20)), isFalse);
  });

  test('save antigo (v1) continua carregando', () {
    final n = MotorTycoon(Random(2));
    n.carregar({'v': 1, 'dinheiro': 500, 'produtos': [{'n': 10, 'g': true, 'p': 0.5}]}, DateTime.now());
    expect(n.dinheiro, 500);
    expect(n.gemas, 0);
    expect(n.estados[0].gerente, isTrue);
  });
}
