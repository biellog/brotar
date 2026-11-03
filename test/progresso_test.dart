import 'dart:math';

import 'package:fica_sobrio/logic/progresso.dart';
import 'package:fica_sobrio/games/bolhas.dart';
import 'package:fica_sobrio/games/memoria.dart';
import 'package:fica_sobrio/games/tempestade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('níveis sobem com XP', () {
    expect(nivelDe(0).numero, 1);
    expect(nivelDe(99).numero, 1);
    expect(nivelDe(100).numero, 2);
    expect(nivelDe(300).numero, 3);
    expect(nivelDe(100000).titulo, 'Lenda Sóbria');
    expect(nivelDe(150).progresso, closeTo(0.25, 0.001));
  });

  test('formata dinheiro em reais', () {
    expect(dinheiro(1234.5), 'R\$ 1.234,50');
    expect(dinheiro(0), 'R\$ 0,00');
  });

  test('conquistas por dias', () {
    const c = Contexto(dias: 7, recorde: 0, partidas: 0, fissurasVencidas: 0, convidou: false);
    final ganhas = conquistasLista.where((x) => x.regra(c)).map((x) => x.codigo).toSet();
    expect(ganhas, {'dia1', 'dia3', 'dia7'});
  });

  test('motor do jogo pontua e termina', () {
    final m = MotorJogo(Random(42));
    for (var i = 0; i < 20000 && !m.acabou; i++) {
      m.passo(1 / 60);
    }
    expect(m.pontos, greaterThan(0));
    expect(m.acabou, isTrue); // parado no meio, uma hora as tempestades acertam
  });

  test('jogador não sai da tela', () {
    final m = MotorJogo(Random(1));
    m.mover(5);
    expect(m.jogadorX, lessThanOrEqualTo(0.92));
    m.mover(-5);
    expect(m.jogadorX, greaterThanOrEqualTo(0.08));
  });

  test('tempestade não usa bebida nem cigarro', () {
    const proibidos = ['🍺', '🍷', '🥃', '🍾', '🚬', '🍸', '🍻'];
    for (final o in MotorJogo.obstaculos) {
      expect(proibidos.contains(o), isFalse);
    }
  });

  test('memória: acha todos os pares', () {
    final m = MotorMemoria(Random(3));
    for (final s in MotorMemoria.simbolos) {
      final idx = [for (var i = 0; i < 16; i++) if (m.cartas[i] == s) i];
      m.virar(idx[0]);
      expect(m.virar(idx[1]), 'par');
    }
    expect(m.terminou, isTrue);
    expect(m.jogadas, 8);
    expect(m.pontos(30), 1080);
  });

  test('memória: erro desvira', () {
    final m = MotorMemoria(Random(5));
    final a = 0;
    final b = m.cartas.indexWhere((c) => c != m.cartas[0]);
    m.virar(a);
    expect(m.virar(b), 'erro');
    m.desvirar();
    expect(m.virada, isEmpty);
  });

  test('bolhas: tocar pontua e o tempo acaba', () {
    final m = MotorBolhas(Random(2));
    for (var i = 0; i < 120; i++) {
      m.passo(1 / 30);
    }
    final b = m.bolhas.firstWhere((b) => !b.ruim);
    final antes = m.pontos;
    // toca no centro aproximado da bolha (sem oscilação: usa a mesma fórmula do motor)
    expect(m.tocar(b.x + sin(m.tempo * 2 + b.fase) * 0.03, b.y, 1), 'boa');
    expect(m.pontos, greaterThan(antes));
    while (!m.acabou) {
      m.passo(0.05);
    }
    expect(m.restante, 0);
  });
}
