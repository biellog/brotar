import 'dart:math';

import 'package:fica_sobrio/games/brilha/motor.dart';
import 'package:fica_sobrio/games/brilha/rede.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final agora = DateTime.fromMillisecondsSinceEpoch(1762300000000);

  test('dois celulares veem as luzes nos MESMOS lugares', () {
    final a = MotorBrilha('geral', Random(1))..sincronizarRodada(agora);
    final b = MotorBrilha('geral', Random(99))..sincronizarRodada(agora);
    for (var i = 0; i < totalLuzes; i++) {
      expect(a.posicaoLuz(a.luzes[i]!), b.posicaoLuz(b.luzes[i]!));
    }
    final c = MotorBrilha('outra', Random(1))..sincronizarRodada(agora);
    expect(c.posicaoLuz(c.luzes[0]!), isNot(a.posicaoLuz(a.luzes[0]!))); // sala diferente, mapa diferente
  });

  test('pegar uma luz: ganha ponto e ela renasce em outro lugar (também no outro celular)', () {
    final a = MotorBrilha('geral', Random(1))..sincronizarRodada(agora);
    final b = MotorBrilha('geral', Random(2))..sincronizarRodada(agora);
    final eu = a.entrar('eu', 'Eu', coresVagalume[0], eu: true);
    final luz = a.luzes[5]!;
    final (lx, ly) = a.posicaoLuz(luz);
    eu
      ..x = lx
      ..y = ly;
    final coletas = a.passo(0.016, 'eu');
    expect(coletas.map((c) => c.luz.id), contains(5)); // (pode pegar outra que nasceu colada)
    expect(eu.pontos, coletas.fold<int>(0, (s, c) => s + c.ganho));
    expect(a.posicaoLuz(luz), isNot((lx, ly)));
    b.coletaRemota(5, a.luzes[5]!.geracao);
    expect(b.posicaoLuz(b.luzes[5]!), a.posicaoLuz(a.luzes[5]!));
    b.coletaRemota(5, 0); // mensagem velha não volta a luz
    expect(b.luzes[5]!.geracao, a.luzes[5]!.geracao);
  });

  test('juntos brilham mais: perto de alguém vale x2', () {
    final m = MotorBrilha('geral', Random(1))..sincronizarRodada(agora);
    final eu = m.entrar('eu', 'Eu', coresVagalume[0], eu: true);
    final amigo = m.entrar('amigo', 'Amigo', coresVagalume[1]);
    final (lx, ly) = m.posicaoLuz(m.luzes[3]!);
    eu
      ..x = lx
      ..y = ly;
    amigo
      ..x = lx + 100
      ..y = ly
      ..alvoX = lx + 100
      ..alvoY = ly;
    final c = m.passo(0.016, 'eu');
    expect(c.single.dupla, isTrue);
    expect(eu.pontos, 2);
  });

  test('estrela cadente vale 10, some depois de pega e ninguém perde nada', () {
    final m = MotorBrilha('geral', Random(1))..sincronizarRodada(agora);
    m.atualizarEstrelas(agora);
    final estrelas = m.luzes.values.where((l) => l.estrela).toList();
    expect(estrelas.length, totalEstrelas);
    final eu = m.entrar('eu', 'Eu', coresVagalume[0], eu: true);
    final (sx, sy) = m.posicaoLuz(estrelas.first);
    eu
      ..x = sx
      ..y = sy;
    m.passo(0.016, 'eu');
    expect(eu.pontos, greaterThanOrEqualTo(10));
    expect(m.luzes.containsKey(estrelas.first.id), isFalse);
    m.atualizarEstrelas(agora);
    expect(m.luzes.containsKey(estrelas.first.id), isFalse); // não volta na mesma leva
  });

  test('bots completam a sala e saem quando chega gente', () {
    final m = MotorBrilha('geral', Random(1))..sincronizarRodada(agora);
    m.entrar('eu', 'Eu', coresVagalume[0], eu: true);
    m.ajustarBots(8);
    expect(m.jogadores.length, 8);
    expect(m.jogadores.values.where((j) => j.robo).length, 7);
    for (var k = 0; k < 3; k++) {
      m.entrar('pessoa$k', 'Pessoa', coresVagalume[1]);
    }
    m.ajustarBots(8);
    expect(m.jogadores.length, 8);
    expect(m.pessoas.length, 4);
  });

  test('bots se mexem e pegam luzes sozinhos', () {
    final m = MotorBrilha('geral', Random(3))..sincronizarRodada(agora);
    m.entrar('eu', 'Eu', coresVagalume[0], eu: true);
    m.ajustarBots(6);
    for (var i = 0; i < 1200; i++) {
      m.passo(0.05, 'eu');
    }
    final pontosBots = m.jogadores.values.where((j) => j.bot).fold<int>(0, (s, j) => s + j.pontos);
    expect(pontosBots, greaterThan(5));
  });

  test('rodadas sincronizadas pelo relógio e ranking', () {
    expect(MotorBrilha.rodadaDe(agora), MotorBrilha.rodadaDe(agora.add(const Duration(seconds: 1))) );
    final m = MotorBrilha('geral', Random(1));
    expect(m.sincronizarRodada(agora), isTrue);
    expect(m.sincronizarRodada(agora), isFalse);
    final a = m.entrar('a', 'A', coresVagalume[0], eu: true)..pontos = 5;
    m.entrar('b', 'B', coresVagalume[1]).pontos = 9;
    expect(m.ranking.first.id, 'b');
    expect(m.posicao('a'), 2);
    expect(m.sincronizarRodada(agora.add(const Duration(seconds: duracaoRodada + intervalo + 1))), isTrue);
    expect(a.pontos, 0); // rodada nova zera
  });

  test('jogador remoto que some (sem sinal) sai da sala', () {
    final m = MotorBrilha('geral', Random(1))..sincronizarRodada(agora);
    m.entrar('eu', 'Eu', coresVagalume[0], eu: true);
    m.posicaoRemota('x', 100, 100, 3, nome: 'X', cor: coresVagalume[2]);
    expect(m.jogadores.containsKey('x'), isTrue);
    for (var i = 0; i < 100; i++) {
      m.passo(0.1, 'eu');
    }
    expect(m.jogadores.containsKey('x'), isFalse);
  });

  test('dados que chegam pela rede são validados', () {
    expect(JogadorRede.ler(null), isNull);
    expect(JogadorRede.ler({'i': 'a', 'x': 'oi', 'y': 2}), isNull);
    expect(JogadorRede.ler({'i': '', 'x': 1, 'y': 2}), isNull);
    expect(JogadorRede.ler({'i': 'a' * 100, 'x': 1, 'y': 2}), isNull);
    final j = JogadorRede.ler({'i': 'a', 'x': 99999, 'y': -5, 's': 9999999, 'n': '<b>${'x' * 50}', 'c': 123})!;
    expect(j.x, larguraMundo);
    expect(j.y, 0);
    expect(j.pontos, 100000);
    expect(j.nome.length, lessThanOrEqualTo(16));
    expect(j.nome.contains('<'), isFalse);
    expect(coresVagalume.contains(j.cor), isTrue);
    expect(limparNome('   '), 'Vagalume');
  });

  test('emote desconhecido é ignorado', () {
    final m = MotorBrilha('geral', Random(1));
    m.entrar('a', 'A', coresVagalume[0]);
    m.emote('a', '<script>');
    expect(m.jogadores['a']!.emote, isNull);
    m.emote('a', '💚');
    expect(m.jogadores['a']!.emote, '💚');
  });

  test('luz renasce espalhada (não em fila) e o sorteio é bem distribuído', () {
    final m = MotorBrilha('geral', Random(1))..sincronizarRodada(agora);
    final l = m.luzes[0]!;
    final pos = <(double, double)>[];
    for (var g = 0; g < 50; g++) {
      l.geracao = g;
      pos.add(m.posicaoLuz(l));
    }
    // passos entre renascimentos não podem ser sempre iguais
    final passos = {for (var g = 1; g < 50; g++) ((pos[g].$1 - pos[g - 1].$1) / 50).round()};
    expect(passos.length, greaterThan(20));
    // distribuição: as 4 metades do mapa recebem luzes
    final quadrantes = <int>{for (final (x, y) in pos) (x > larguraMundo / 2 ? 1 : 0) + (y > alturaMundo / 2 ? 2 : 0)};
    expect(quadrantes.length, 4);
    final media = [for (var i = 0; i < 2000; i++) hashUnit(7, i, 3)].reduce((a, b) => a + b) / 2000;
    expect(media, closeTo(0.5, 0.03));
  });

  test('equilíbrio: bots juntos não ganham x2 entre si', () {
    final m = MotorBrilha('geral', Random(1))..sincronizarRodada(agora);
    final b1 = m.entrar('b1', 'B1', coresVagalume[0], bot: true);
    final b2 = m.entrar('b2', 'B2', coresVagalume[1], bot: true)
      ..x = b1.x + 50
      ..y = b1.y;
    expect(m.emDupla(b1), isFalse);
    final eu = m.entrar('eu', 'Eu', coresVagalume[2], eu: true)
      ..x = b2.x + 40
      ..y = b2.y;
    expect(m.emDupla(b2), isTrue);
    expect(m.emDupla(eu), isTrue);
  });

  test('equilíbrio: em 1 minuto os bots fazem uma pontuação razoável', () {
    final m = MotorBrilha('geral', Random(5))..sincronizarRodada(agora);
    m.entrar('eu', 'Eu', coresVagalume[0], eu: true);
    m.ajustarBots(8);
    for (var i = 0; i < 1200; i++) {
      m.passo(0.05, 'eu');
    }
    final melhorBot = m.jogadores.values.where((j) => j.bot).map((j) => j.pontos).reduce(max);
    expect(melhorBot, lessThan(150)); // antes passava de 800
  });
}
