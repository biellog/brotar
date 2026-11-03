import 'dart:math';

import 'package:fica_sobrio/logic/progresso.dart';
import 'package:fica_sobrio/screens/game_screen.dart';
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
    expect(m.acabou, isTrue); // parado no meio, uma hora as garrafas acertam
  });

  test('jogador não sai da tela', () {
    final m = MotorJogo(Random(1));
    m.mover(5);
    expect(m.jogadorX, lessThanOrEqualTo(0.94));
    m.mover(-5);
    expect(m.jogadorX, greaterThanOrEqualTo(0.06));
  });
}
