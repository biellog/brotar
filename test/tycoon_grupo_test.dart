import 'dart:convert';
import 'dart:math';

import 'package:fica_sobrio/games/tycoon3d/mundo.dart';
import 'package:fica_sobrio/games/tycoon3d/rede_suco.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simula a rede: o que vai é JSON de verdade (como no Supabase Realtime).
Map<String, dynamic> pelaRede(Map<String, dynamic> m) => jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

void esperar(Mundo m, double seg) {
  for (var t = 0.0; t < seg; t += 0.05) {
    m.passo(0.05, 0, 0);
  }
}

void main() {
  test('em grupo não tem ajudante (nem contratar, nem vindo do save)', () {
    final m = Mundo(Random(1))
      ..grupo = true
      ..dinheiro = 1e6;
    expect(m.contratarAjudante(), isFalse);
    expect(m.executar('ajudante', ''), isFalse);
    m.carregar({'ajudantes': 3, 'dinheiro': 10}, DateTime.now());
    expect(m.ajudantes, isEmpty);
    expect(m.ganhoAjudantesPorSegundo, 0);
  });

  test('sozinho continua tendo ajudante', () {
    final m = Mundo(Random(1))..dinheiro = 1e6;
    expect(m.executar('ajudante', ''), isTrue);
    expect(m.ajudantes.length, 1);
  });

  test('em grupo as missões de ajudante são puladas (não travam o jogo)', () {
    final m = Mundo(Random(1))..grupo = true;
    m.missao = missoes.indexWhere((x) => x.tipo == TipoMissao.ajudantes);
    final antes = m.missao;
    m.passo(0.016, 0, 0);
    expect(m.missao, antes + 1);
    expect(missoes[antes].tipo, TipoMissao.ajudantes);
  });

  test('o amigo pega copos e vende no MESMO caixa (dinheiro do grupo)', () {
    final host = Mundo(Random(1))..grupo = true;
    host.jogador
      ..x = 14
      ..y = 15; // o dono fica longe
    esperar(host, 8);
    final b = host.barracas[0];
    host.atualizarAmigo('amigo1', {'x': b.x + 1.1, 'y': b.y, 'n': 'Ana'});
    esperar(host, 2);
    expect(host.amigos['amigo1']!.carga, isNotEmpty);
    expect(host.amigos['amigo1']!.nome, 'Ana');
    host.atualizarAmigo('amigo1', {'x': 8.6, 'y': balcao.y + balcao.d + 0.5});
    esperar(host, 6);
    expect(host.dinheiro, greaterThan(0));
    expect(host.copos, greaterThan(0));
  });

  test('o amigo em cima da placa também paga com o dinheiro do grupo', () {
    final host = Mundo(Random(1))
      ..grupo = true
      ..dinheiro = 100;
    final placa = host.placas.firstWhere((p) => p.tipo == TipoPlaca.abrir);
    host.atualizarAmigo('amigo1', {'x': placa.x, 'y': placa.y});
    esperar(host, 3);
    expect(host.barracas[1].aberta, isTrue);
  });

  test('o espelho recebe a foto do jogo: dinheiro, barracas, clientes e a própria carga', () {
    final host = Mundo(Random(1))
      ..grupo = true
      ..dinheiro = 321;
    host.barracas[1].aberta = true;
    host.atualizarAmigo('eu', {'x': 9, 'y': 7});
    host.amigos['eu']!.carga.addAll([0, 1]);
    esperar(host, 6);
    final foto = pelaRede(host.estadoAoVivo('dono', 'Bia', coresAmigos[1]));

    final eu = Mundo(Random(2))
      ..grupo = true
      ..espelho = true;
    eu.aplicarAoVivo(foto, 'eu');
    expect(eu.dinheiro, closeTo(host.dinheiro, 0.01));
    expect(eu.barracas[1].aberta, isTrue);
    expect(eu.clientes.length, host.clientes.length);
    expect(eu.jogador.carga, [0, 1]);
    expect(eu.amigos.keys, ['dono']); // o dono aparece como amigo
    expect(eu.amigos['dono']!.nome, 'Bia');
  });

  test('no espelho o boneco anda livre, mas o jogo não roda sozinho (não duplica vendas)', () {
    final eu = Mundo(Random(2))
      ..grupo = true
      ..espelho = true;
    final x0 = eu.jogador.x;
    for (var k = 0; k < 30; k++) {
      eu.passo(0.05, 1, 0);
    }
    expect(eu.jogador.x, greaterThan(x0 + 1));
    esperar(eu, 10);
    expect(eu.barracas[0].estoque, 0); // quem produz é o celular que roda o jogo
    expect(eu.clientes, isEmpty);
  });

  test('eventos (vendas, barraca aberta) chegam no amigo para tocar som e moedas', () {
    final host = Mundo(Random(1))
      ..grupo = true
      ..dinheiro = 100;
    final placa = host.placas.firstWhere((p) => p.tipo == TipoPlaca.abrir);
    host.atualizarAmigo('amigo1', {'x': placa.x, 'y': placa.y});
    esperar(host, 3);
    final eu = Mundo(Random(2))
      ..grupo = true
      ..espelho = true;
    final ev = eu.aplicarAoVivo(pelaRede(host.estadoAoVivo('dono', 'Bia', coresAmigos[0])), 'amigo1');
    expect(ev.any((e) => e.tipo == TipoEvento.abriu), isTrue);
    // a foto seguinte não repete o evento
    expect(eu.aplicarAoVivo(pelaRede(host.estadoAoVivo('dono', 'Bia', coresAmigos[0])), 'amigo1'), isEmpty);
  });

  test('compra do amigo pelo computador (ação pela rede) usa o dinheiro do grupo', () {
    final host = Mundo(Random(1))
      ..grupo = true
      ..dinheiro = 5000;
    expect(host.executar('boost', 'turbo'), isTrue);
    expect(host.ativo(Boost.turbo), isTrue);
    expect(host.executar('emp', 'gelo'), isTrue);
    expect(host.nivelMelhoria(Melhoria.gelo), 1);
    expect(host.executar('boost', 'nao-existe'), isFalse);
    expect(host.executar('xyz', 'turbo'), isFalse);
  });

  test('dados estranhos vindos da rede são ignorados', () {
    final eu = Mundo(Random(2))
      ..grupo = true
      ..espelho = true;
    eu.aplicarAoVivo({
      'e': {'dinheiro': 'muito'},
      'cl': [
        ['x'],
        [1, 2, 3, 99, 99, 0, 99, 9],
      ],
      'js': {
        'eu': {'c': [0, 999, -1, 'a']},
        'outro': {'x': double.nan, 'y': 1},
      },
      'ev': [
        [999, 0, 0, 0, 0, ''],
        'lixo',
      ],
    }, 'eu');
    expect(eu.dinheiro, 0);
    expect(eu.jogador.carga, [0]);
    expect(eu.clientes.single.quer, sucos.length - 1);
    expect(eu.amigos, isEmpty);
    for (var k = 0; k < 20; k++) {
      eu.atualizarAmigo('a$k', {'x': 5, 'y': 5});
    }
    expect(eu.amigos.length, 7); // limite de gente no império
  });

  test('o save do grupo volta igual (o mesmo progresso para todos)', () {
    final a = Mundo(Random(1))
      ..grupo = true
      ..dinheiro = 777
      ..missao = 5;
    a.barracas[2].aberta = true;
    a.comprarBoost(Boost.producao);
    final b = Mundo(Random(3))..grupo = true;
    b.carregar(pelaRede(a.paraJson(DateTime.now())), DateTime.now());
    expect(b.dinheiro, closeTo(a.dinheiro, 0.01));
    expect(b.missao, 5);
    expect(b.barracas[2].aberta, isTrue);
    expect(b.ativo(Boost.producao), isTrue);
  });

  test('todos escolhem o mesmo celular para rodar o jogo', () {
    const ps = [Presente('b', 'B', 0, 200), Presente('a', 'A', 0, 300), Presente('c', 'C', 0, 200)];
    expect(escolherAnfitriao(ps), 'b');
    expect(escolherAnfitriao(ps.reversed), 'b');
    expect(escolherAnfitriao(const []), isNull);
  });

  test('código e link do império', () {
    expect(codigoImperio(' k7q2-pmnx '), 'K7Q2PMNX');
    expect(codigoImperio('K7Q2PMN'), isNull); // 7 letras
    expect(codigoImperio('K7Q2PMN0'), isNull); // 0 não existe no código
    expect(codigoImperio(null), isNull);
    expect(linkImperio('K7Q2PMNX'), endsWith('/jogar/?suco=K7Q2PMNX'));
    expect(mensagemConviteImperio('K7Q2PMNX', 'Galera'), contains('\nK7Q2PMNX'));
    expect(gerarIdLocal().length, 11);
  });
}
