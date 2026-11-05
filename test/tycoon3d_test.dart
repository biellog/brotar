import 'dart:math';

import 'package:fica_sobrio/games/tycoon3d/mundo.dart';
import 'package:fica_sobrio/games/tycoon3d/render.dart';
import 'package:fica_sobrio/games/tycoon3d/tycoon3d_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Anda com o jogador até (x, y), como se fosse o joystick.
void irPara(Mundo m, double x, double y, {double maxSeg = 20}) {
  for (var t = 0.0; t < maxSeg; t += 0.05) {
    final dx = x - m.jogador.x, dy = y - m.jogador.y;
    final d = sqrt(dx * dx + dy * dy);
    if (d < 0.1) return;
    m.passo(0.05, dx / d, dy / d);
  }
}

void esperar(Mundo m, double seg) {
  for (var t = 0.0; t < seg; t += 0.05) {
    m.passo(0.05, 0, 0);
  }
}

void main() {
  test('começa com a limonada aberta e produzindo', () {
    final m = Mundo(Random(1));
    expect(m.barracas[0].aberta, isTrue);
    esperar(m, 4);
    expect(m.barracas[0].estoque, greaterThan(0));
  });

  test('barracas ficam no fundo e a placa fica NA FRENTE (nunca no lugar da barraca)', () {
    final m = Mundo(Random(1));
    for (final b in m.barracas) {
      expect(b.x, lessThan(2.5)); // encostadas no fundo
    }
    for (final p in m.placas) {
      final b = m.barracas[p.alvo];
      expect(p.x - b.x, greaterThan(1.5)); // fora da área da barraca
    }
  });

  test('BUG CORRIGIDO: comprar barraca não prende o boneco', () {
    final m = Mundo(Random(1))..dinheiro = 100;
    final placa = m.placas.firstWhere((p) => p.tipo == TipoPlaca.abrir);
    irPara(m, placa.x, placa.y);
    esperar(m, esperaPlaca + 2);
    expect(m.barracas[1].aberta, isTrue);
    final antes = (m.jogador.x, m.jogador.y);
    irPara(m, 9, 7, maxSeg: 4); // consegue sair andando
    expect((m.jogador.x - antes.$1).abs() + (m.jogador.y - antes.$2).abs(), greaterThan(2));
  });

  test('mesmo se ficar dentro de algo sólido, consegue sair', () {
    final m = Mundo(Random(1));
    m.jogador
      ..x = m.barracas[0].x
      ..y = m.barracas[0].y; // dentro da barraca
    irPara(m, 8, 7, maxSeg: 4);
    expect(m.jogador.x, greaterThan(5));
  });

  test('pegar copos na frente da barraca e vender no balcão', () {
    final m = Mundo(Random(1));
    esperar(m, 8);
    final b = m.barracas[0];
    irPara(m, b.x + 1.1, b.y);
    esperar(m, 1);
    expect(m.jogador.carga, isNotEmpty);
    esperar(m, 6);
    irPara(m, 8.6, balcao.y + balcao.d + 0.5);
    esperar(m, 3);
    expect(m.dinheiro, greaterThan(0));
    expect(m.copos, greaterThan(0));
  });

  test('ficar na placa paga aos poucos; parcial fica guardado', () {
    final m = Mundo(Random(1))..dinheiro = 15;
    final placa = m.placas.firstWhere((p) => p.tipo == TipoPlaca.abrir);
    irPara(m, placa.x, placa.y);
    esperar(m, esperaPlaca + 2);
    expect(m.dinheiro, 0);
    expect(m.barracas[1].aberta, isFalse);
    expect(m.placas.firstWhere((p) => p.tipo == TipoPlaca.abrir).pago, closeTo(15, 0.01));
  });

  test('movimento: acelera suave e vira para o lado em que anda', () {
    final m = Mundo(Random(1));
    m.passo(0.016, 1, 0);
    final v1 = m.jogador.vx;
    expect(v1, greaterThan(0));
    expect(v1, lessThan(m.velocidade)); // não sai de 0 a 100 num quadro
    for (var k = 0; k < 30; k++) {
      m.passo(0.016, 1, 0);
    }
    expect(m.jogador.vx, closeTo(m.velocidade, 0.1));
    for (var k = 0; k < 30; k++) {
      m.passo(0.016, -1, 1); // tela: esquerda
    }
    expect(m.jogador.olhandoEsquerda, isTrue);
  });

  test('sentar no computador da gerência e levantar', () {
    final m = Mundo(Random(1));
    irPara(m, cadeira.x, cadeira.y);
    final ev = <Evento>[];
    for (var k = 0; k < 20; k++) {
      ev.addAll(m.passo(0.05, 0, 0));
    }
    expect(m.sentado, isTrue);
    expect(ev.any((e) => e.tipo == TipoEvento.sentou), isTrue);
    expect(m.usouComputador, isTrue);
    m.passo(0.05, 1, 0); // sentado, o boneco não anda
    expect(m.jogador.x, cadeira.x);
    m.levantar();
    esperar(m, 1);
    expect(m.sentado, isFalse); // não senta de novo sozinho logo depois
  });

  test('boosts, melhorias da empresa, equipe e habilidades', () {
    final m = Mundo(Random(1))..dinheiro = 1e6;
    final v = m.velocidade;
    expect(m.comprarBoost(Boost.turbo), isTrue);
    expect(m.velocidade, closeTo(v * 1.6, 1e-9));
    esperar(m, Boost.turbo.duracao + 1);
    expect(m.velocidade, closeTo(v, 1e-9));
    final p = m.preco(m.barracas[0]);
    expect(m.comprarMelhoria(Melhoria.logo), isTrue);
    expect(m.preco(m.barracas[0]), closeTo(p * 1.1, 1e-9));
    expect(m.comprarMelhoria(Melhoria.logo), isFalse); // só 1 nível
    expect(m.vagas.length, 3);
    m.comprarMelhoria(Melhoria.mesas);
    expect(m.vagas.length, 4);
    expect(m.contratarAjudante(), isTrue);
    expect(m.ajudantes.length, 1);
    final cap = m.capacidade;
    expect(m.comprarMochila(), isTrue);
    expect(m.capacidade, cap + 2);
    expect(m.subirHabilidade(Habilidade.forca), isFalse); // sem pontos
    m.pontosHabilidade = 3;
    expect(m.subirHabilidade(Habilidade.forca), isTrue);
    expect(m.capacidade, cap + 3);
    expect(m.pontosHabilidade, 2);
  });

  test('sem dinheiro não compra nada no computador', () {
    final m = Mundo(Random(1));
    expect(m.comprarBoost(Boost.producao), isFalse);
    expect(m.comprarMelhoria(Melhoria.gelo), isFalse);
    expect(m.contratarAjudante(), isFalse);
    expect(m.comprarTenis(), isFalse);
    expect(m.dinheiro, 0);
  });

  test('missões em sequência dão dinheiro e ponto de habilidade', () {
    final m = Mundo(Random(1));
    expect(m.missaoAtual!.tipo, TipoMissao.copos);
    m.copos = 5;
    final ev = m.passo(0.016, 0, 0);
    expect(ev.any((e) => e.tipo == TipoEvento.missao), isTrue);
    expect(m.missao, 1);
    expect(m.pontosHabilidade, 1);
    expect(m.dinheiro, greaterThan(0));
    expect(missoes.length, greaterThan(20));
  });

  test('delivery vende sozinho', () {
    final m = Mundo(Random(1))..dinheiro = 5000;
    m.comprarMelhoria(Melhoria.delivery);
    final antes = m.dinheiro;
    m.jogador.y = 15; // longe de tudo
    esperar(m, 10);
    expect(m.dinheiro, greaterThan(antes));
  });

  test('ajudante vende sozinho', () {
    final m = Mundo(Random(2));
    m.barracas[1].aberta = true;
    m.ajudantes.add(Pessoa(9, 6.4, ajudante: true));
    m.jogador
      ..x = 14
      ..y = 15;
    esperar(m, 90);
    expect(m.copos, greaterThan(3));
  });

  test('salvar e carregar tudo (habilidades, empresa, missões)', () {
    final m = Mundo(Random(1))
      ..dinheiro = 500
      ..nivelMochila = 2
      ..pontosHabilidade = 4
      ..missao = 6
      ..usouComputador = true;
    m.habilidades[Habilidade.carisma] = 2;
    m.melhorias[Melhoria.gelo] = 1;
    m.barracas[1]
      ..aberta = true
      ..nivel = 3;
    m.ajudantes.add(Pessoa(9, 6, ajudante: true));
    final agora = DateTime(2026, 11, 5, 10);
    final n = Mundo(Random(2));
    final fora = n.carregar(m.paraJson(agora), agora.add(const Duration(hours: 10)));
    expect(fora, 36000);
    expect(n.dinheiro, 500);
    expect(n.pontosHabilidade, 4);
    expect(n.missao, 6);
    expect(n.nivel(Habilidade.carisma), 2);
    expect(n.nivelMelhoria(Melhoria.gelo), 1);
    expect(n.barracas[1].nivel, 3);
    expect(n.ajudantes.length, 1);
    expect(n.ganhoOffline(fora), closeTo(n.ganhoAjudantesPorSegundo * 0.5 * 3 * 3600, 1e-6));
  });

  test('carregar ignora dados estranhos e saves antigos', () {
    final n = Mundo(Random(2));
    n.carregar({'dinheiro': -50, 'ajudantes': 999, 'hab': {'forca': 99}, 'emp': 'x', 'missao': 9999,
      'barracas': [{'a': false, 'n': -3, 'e': 9999}]}, DateTime.now());
    expect(n.dinheiro, 0);
    expect(n.ajudantes.length, Mundo.custosAjudante.length);
    expect(n.nivel(Habilidade.forca), maxHabilidade);
    expect(n.missao, lessThanOrEqualTo(missoes.length + 1000));
    expect(n.barracas[0].aberta, isTrue);
    expect(n.barracas[0].estoque, lessThanOrEqualTo(n.capacidadeBarraca(n.barracas[0])));
  });

  test('arrastar o dedo move o personagem na mesma direção da tela', () {
    final iso = Iso(64, Offset.zero);
    for (final (tx, ty) in [(1.0, 0.0), (0.0, 1.0), (-1.0, 0.0), (0.0, -1.0), (0.7, 0.7)]) {
      final (dx, dy) = direcaoNoMapa(tx, ty);
      final mov = iso.p(5 + dx * 0.1, 5 + dy * 0.1) - iso.p(5, 5);
      final cos = (mov.dx * tx + mov.dy * ty) / (mov.distance * Offset(tx, ty).distance);
      expect(cos, greaterThan(0.99));
    }
  });

  test('placa só começa a cobrar depois de 5 s parado em cima', () {
    final m = Mundo(Random(1))..dinheiro = 100;
    final placa = m.placas.firstWhere((p) => p.tipo == TipoPlaca.abrir);
    irPara(m, placa.x, placa.y);
    esperar(m, esperaPlaca - 0.5);
    expect(m.dinheiro, 100); // ainda não cobrou
    expect(m.jogador.naPlaca, greaterThan(3));
    irPara(m, 9, 7); // saiu: o tempo zera
    expect(m.jogador.naPlaca, 0);
    irPara(m, placa.x, placa.y);
    esperar(m, 2);
    expect(m.dinheiro, 100); // contou de novo do zero
    esperar(m, 5);
    expect(m.barracas[1].aberta, isTrue);
  });

  test('combo: vender seguido aumenta o preço (até x2) e zera se demorar', () {
    final m = Mundo(Random(1));
    expect(m.multCombo, 1);
    m
      ..combo = 6
      ..comboTempo = 1;
    expect(m.multCombo, closeTo(1.5, 1e-9));
    m.combo = 50;
    expect(m.multCombo, closeTo(2, 1e-9));
    esperar(m, Mundo.tempoCombo + 0.5);
    expect(m.combo, 0);
  });

  test('vendas em sequência fazem combo de verdade', () {
    final m = Mundo(Random(1));
    final c1 = Cliente(vagasBase[0].$1, vagasBase[0].$2, 0, 3, 0)
      ..estado = EstadoCliente.esperando
      ..vaga = 0;
    m.clientes.add(c1);
    m.jogador
      ..x = 8
      ..y = balcao.y + balcao.d + 0.5
      ..carga.addAll([0, 0, 0]);
    final ev = <Evento>[];
    for (var k = 0; k < 20; k++) {
      ev.addAll(m.passo(0.05, 0, 0));
    }
    expect(m.copos, 3);
    expect(m.combo, 3);
    expect(ev.any((e) => e.tipo == TipoEvento.combo), isTrue);
    expect(m.dinheiro, greaterThan(3 * m.preco(m.barracas[0])));
  });

  test('agitos aparecem sozinhos depois de um tempo', () {
    final m = Mundo(Random(4))..copos = 10;
    final ev = <Evento>[];
    for (var t = 0.0; t < 80; t += 0.05) {
      ev.addAll(m.passo(0.05, 0, 0));
    }
    expect(ev.any((e) => e.tipo == TipoEvento.agito), isTrue);
  });

  test('chuva de moedas: passar por cima pega o dinheiro', () {
    final m = Mundo(Random(1))..copos = 10;
    m.comecarAgito(TipoAgito.moedas, []);
    expect(m.moedasChao, isNotEmpty);
    final mo = m.moedasChao.first;
    m.jogador
      ..x = mo.x
      ..y = mo.y;
    final ev = m.passo(0.016, 0, 0);
    expect(ev.any((e) => e.tipo == TipoEvento.moeda), isTrue);
    expect(m.dinheiro, greaterThanOrEqualTo(mo.valor));
  });

  test('fruta dourada enche as barracas e liga produção x2', () {
    final m = Mundo(Random(1));
    m.comecarAgito(TipoAgito.fruta, []);
    final f = m.fruta!;
    m.jogador
      ..x = f.$1
      ..y = f.$2;
    m.passo(0.016, 0, 0);
    expect(m.fruta, isNull);
    expect(m.barracas[0].estoque, m.capacidadeBarraca(m.barracas[0]));
    expect(m.ativo(Boost.producao), isTrue);
  });

  test('onda de calor: suco vale +50% só enquanto dura', () {
    final m = Mundo(Random(1));
    final p = m.preco(m.barracas[0]);
    m.comecarAgito(TipoAgito.calor, []);
    expect(m.preco(m.barracas[0]), closeTo(p * 1.5, 1e-9));
    esperar(m, TipoAgito.calor.duracao + 1);
    expect(m.agito, isNull);
    expect(m.preco(m.barracas[0]), closeTo(p, 1e-9));
  });

  test('cliente VIP paga 5x e vai embora se esperar demais', () {
    final m = Mundo(Random(1));
    m.barracas[1].aberta = true;
    m.comecarAgito(TipoAgito.vip, []);
    final vip = m.clientes.singleWhere((c) => c.vip);
    expect(vip.quer, 1);
    esperar(m, TipoAgito.vip.duracao + 1);
    expect(vip.estado, EstadoCliente.saindo);
    expect(m.agito, isNull);
  });

  test('excursão traz muito mais cliente', () {
    final a = Mundo(Random(1)), b = Mundo(Random(1));
    b.comecarAgito(TipoAgito.excursao, []);
    var maxA = 0, maxB = 0;
    for (var t = 0.0; t < 15; t += 0.05) {
      a.passo(0.05, 0, 0);
      b.passo(0.05, 0, 0);
      maxA = max(maxA, a.clientes.length);
      maxB = max(maxB, b.clientes.length);
    }
    expect(maxB, greaterThan(maxA));
  });

  test('cidade nova: só com as 8 barracas, recomeça com +50% para sempre', () {
    final m = Mundo(Random(1))..dinheiro = 9e9;
    expect(m.novaCidade(), isFalse);
    for (final b in m.barracas) {
      b
        ..aberta = true
        ..nivel = 5;
    }
    m.subirHabilidade(Habilidade.forca); // sem pontos, não sobe
    m.pontosHabilidade = 2;
    m.subirHabilidade(Habilidade.forca);
    m.comprarMelhoria(Melhoria.logo);
    final base = m.barracas[0].precoBase;
    expect(m.executar('cidade', ''), isTrue);
    expect(m.cidades, 1);
    expect(m.dinheiro, 0);
    expect(m.abertas, 1);
    expect(m.barracas[0].nivel, 1);
    expect(m.nivel(Habilidade.forca), 1); // habilidades ficam
    expect(m.nivelMelhoria(Melhoria.logo), 1); // empresa fica
    expect(m.preco(m.barracas[0]), closeTo(m.barracas[0].precoBase * 1.1 * 1.5, 1e-9));
    expect(base, greaterThan(m.barracas[0].precoBase));
    final n = Mundo(Random(2))..carregar(m.paraJson(DateTime.now()), DateTime.now());
    expect(n.cidades, 1);
    expect(nomeCidade(1), 'Vila do Sol');
  });

  test('missões nunca acabam (e passam pelas áreas novas)', () {
    final m = Mundo(Random(1))..missao = missoes.length;
    expect(m.missaoAtual!.tipo, TipoMissao.areas); // primeiro: abrir o mapa todo
    m.areas.addAll(Area.values);
    final tipos = <TipoMissao>{};
    for (var k = 0; k < 5; k++) {
      tipos.add(m.missaoAtual!.tipo);
      expect(m.missaoAtual!.premio, greaterThan(0));
      m.missao++;
    }
    expect(tipos, {TipoMissao.copos, TipoMissao.frutas, TipoMissao.faturar, TipoMissao.pedidos, TipoMissao.cidade});
    m.missao += 300;
    expect(m.missaoAtual, isNotNull);
  });

  test('mapa maior: áreas fechadas não deixam passar até abrir pela placa', () {
    final m = Mundo(Random(1))..dinheiro = 1e6;
    expect(m.aberta(Area.praca), isTrue);
    expect(m.aberta(Area.praia), isFalse);
    m.jogador
      ..x = 14
      ..y = 11;
    irPara(m, 24, 11, maxSeg: 6); // tenta ir para a praia (longe da placa)
    expect(m.jogador.x, lessThan(16.3));
    expect(m.aberta(Area.praia), isFalse);
    final placa = m.placas.firstWhere((p) => p.tipo == TipoPlaca.area && p.alvo == Area.praia.index);
    irPara(m, placa.x, placa.y);
    final ev = <Evento>[];
    for (var t = 0.0; t < esperaPlaca + 3; t += 0.05) {
      ev.addAll(m.passo(0.05, 0, 0));
    }
    expect(m.aberta(Area.praia), isTrue);
    expect(ev.any((e) => e.tipo == TipoEvento.area), isTrue);
    irPara(m, 22, 8, maxSeg: 8);
    expect(areaDe(m.jogador.x, m.jogador.y), Area.praia);
  });

  test('o mar não dá para atravessar', () {
    final m = Mundo(Random(1))..areas.add(Area.praia);
    m.jogador
      ..x = 26
      ..y = 9;
    irPara(m, 31, 9, maxSeg: 4);
    expect(m.jogador.x, lessThan(marX));
  });

  test('pomar: colher frutas e levar ao depósito enche as barracas', () {
    final m = Mundo(Random(1))..areas.add(Area.pomar);
    m.barracas[1].aberta = true;
    final (ax, ay) = arvoresPomar[1];
    irPara(m, ax, ay - 0.9);
    esperar(m, 2);
    expect(m.jogador.frutas, greaterThan(0));
    final ev = <Evento>[];
    final antes = m.jogador.frutas;
    irPara(m, depositoFrutas.x, depositoFrutas.y);
    ev.addAll(m.passo(0.05, 0, 0));
    expect(m.jogador.frutas, 0);
    expect(m.frutasColhidas, greaterThanOrEqualTo(antes));
    expect(m.barracas[1].estoque, greaterThan(0));
  });

  test('pomar: a árvore volta a dar fruta com o tempo', () {
    final m = Mundo(Random(1))..areas.add(Area.pomar);
    m.frutasArvore[0] = 0;
    esperar(m, 8);
    expect(m.frutasArvore[0], greaterThan(0));
  });

  test('praia: banhistas no quiosque pagam 1,5x', () {
    final m = Mundo(Random(1))..areas.add(Area.praia);
    esperar(m, 30);
    final banhista = m.clientes.where((c) => c.praia && c.estado == EstadoCliente.esperando).firstOrNull;
    expect(banhista, isNotNull);
    m.jogador
      ..x = quiosque.x + 1
      ..y = quiosque.y + quiosque.d + 0.5
      ..carga.addAll(List.filled(3, banhista!.quer));
    final d0 = m.dinheiro;
    final ev = m.passo(0.05, 0, 0);
    final venda = ev.firstWhere((e) => e.tipo == TipoEvento.vendeu);
    expect(m.dinheiro - d0, closeTo(venda.valor, 1e-9));
    expect(venda.valor, closeTo(m.preco(m.barracas[banhista.quer]) * 1.5, 1e-9));
  });

  test('parque: pedido com tempo, entregar no destino paga 3x', () {
    final m = Mundo(Random(1))..areas.add(Area.parque);
    final ev = <Evento>[];
    for (var t = 0.0; t < 6; t += 0.05) {
      ev.addAll(m.passo(0.05, 0, 0));
    }
    final pe = m.pedido!;
    expect(ev.any((e) => e.tipo == TipoEvento.pedidoNovo), isTrue);
    final (_, _, dx, dy) = destinosParque[pe.destino];
    m.jogador
      ..x = dx
      ..y = dy
      ..carga.addAll(List.filled(pe.qtd, pe.suco));
    final d0 = m.dinheiro;
    final ev2 = m.passo(0.05, 0, 0);
    expect(ev2.any((e) => e.tipo == TipoEvento.pedido), isTrue);
    expect(m.dinheiro - d0, closeTo(pe.valor, 1e-9));
    expect(pe.valor, closeTo((m.preco(m.barracas[pe.suco]) * pe.qtd * 3).roundToDouble(), 1));
    expect(m.pedidosFeitos, 1);
    expect(m.jogador.carga, isEmpty);
  });

  test('parque: pedido some se o tempo acabar e outro aparece depois', () {
    final m = Mundo(Random(1))..areas.add(Area.parque);
    esperar(m, 6);
    expect(m.pedido, isNotNull);
    esperar(m, 52);
    esperar(m, 8);
    expect(m.pedido, isNotNull); // um novo
    expect(m.pedidosFeitos, 0);
  });

  test('áreas abertas, frutas e pedidos ficam salvos', () {
    final m = Mundo(Random(1))
      ..areas.addAll([Area.pomar, Area.parque])
      ..frutasColhidas = 12
      ..pedidosFeitos = 3;
    final n = Mundo(Random(2))..carregar(m.paraJson(DateTime.now()), DateTime.now());
    expect(n.areas, {Area.praca, Area.pomar, Area.parque});
    expect(n.frutasColhidas, 12);
    expect(n.pedidosFeitos, 3);
  });
}
