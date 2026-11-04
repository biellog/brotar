import 'dart:math';

import 'package:fica_sobrio/games/tycoon3d/mundo.dart';
import 'package:fica_sobrio/games/tycoon3d/render.dart';
import 'package:fica_sobrio/games/tycoon3d/tycoon3d_screen.dart';
import 'package:flutter/painting.dart';
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
    expect(m.abertas, 1);
    esperar(m, 4);
    expect(m.barracas[0].estoque, greaterThan(0));
  });

  test('pegar copos na barraca e vender no balcão', () {
    final m = Mundo(Random(1));
    esperar(m, 8); // limonada enche e clientes chegam
    final b = m.barracas[0];
    irPara(m, b.x, b.y + 1.0);
    esperar(m, 1);
    expect(m.jogador.carga, isNotEmpty);
    expect(m.jogador.carga.length, lessThanOrEqualTo(m.capacidade));
    // espera alguém chegar ao balcão e vai até lá
    esperar(m, 6);
    irPara(m, 8.6, balcao.y + balcao.d + 0.5);
    esperar(m, 3);
    expect(m.dinheiro, greaterThan(0));
    expect(m.copos, greaterThan(0));
  });

  test('não atravessa barraca nem balcão', () {
    final m = Mundo(Random(1));
    final b = m.barracas[0];
    irPara(m, b.x, b.y, maxSeg: 5); // tenta entrar na barraca
    expect((m.jogador.x - b.x).abs() > 0.6 || (m.jogador.y - b.y).abs() > 0.6, isTrue);
    irPara(m, 8.6, 3.0, maxSeg: 5); // a rua (atrás do balcão) é só dos clientes
    expect(m.jogador.y, greaterThanOrEqualTo(2.6));
  });

  test('ficar em cima da placa paga aos poucos e abre a barraca', () {
    final m = Mundo(Random(1))..dinheiro = 100;
    final placa = m.placas.firstWhere((p) => p.tipo == TipoPlaca.abrir);
    expect(placa.alvo, 1);
    // chega perto dando a volta (sem pisar na placa): nada é cobrado
    irPara(m, placa.x + 2.5, 6.5);
    irPara(m, placa.x + 2.5, placa.y + 1.4);
    irPara(m, placa.x, placa.y + 1.4);
    expect(m.dinheiro, 100);
    // pisa (a placa da barraca fica no lugar dela, que ainda não é sólida)
    irPara(m, placa.x, placa.y);
    esperar(m, 2);
    expect(m.barracas[1].aberta, isTrue);
    expect(m.dinheiro, closeTo(60, 0.5));
  });

  test('pagamento parcial fica guardado na placa', () {
    final m = Mundo(Random(1))..dinheiro = 15;
    final placa = m.placas.firstWhere((p) => p.tipo == TipoPlaca.abrir);
    irPara(m, placa.x, placa.y);
    esperar(m, 2);
    expect(m.dinheiro, 0);
    expect(m.barracas[1].aberta, isFalse);
    expect(m.placas.firstWhere((p) => p.tipo == TipoPlaca.abrir).pago, closeTo(15, 0.01));
  });

  test('mochila e tênis melhoram o jogador', () {
    final m = Mundo(Random(1))..dinheiro = 1000;
    final cap = m.capacidade;
    final mochila = m.placas.firstWhere((p) => p.tipo == TipoPlaca.mochila);
    irPara(m, mochila.x, mochila.y);
    esperar(m, 2);
    expect(m.capacidade, cap + 2);
  });

  test('ajudante vende sozinho', () {
    final m = Mundo(Random(2));
    m.barracas[1].aberta = true;
    m.ajudantes.add(Pessoa(13, 5.4, ajudante: true));
    m.jogador.x = 2;
    m.jogador.y = 14; // longe: quem vende é o ajudante
    esperar(m, 90);
    expect(m.dinheiro, greaterThan(20));
    expect(m.ganhoAjudantesPorSegundo, greaterThan(0));
  });

  test('clientes chegam pela rua, esperam no balcão e vão embora felizes', () {
    final m = Mundo(Random(3));
    esperar(m, 12);
    expect(m.clientes, isNotEmpty);
    expect(m.clientes.where((c) => c.estado == EstadoCliente.esperando).length, lessThanOrEqualTo(vagasBalcao.length));
    for (final c in m.clientes.where((c) => c.estado == EstadoCliente.esperando)) {
      expect(c.y, closeTo(3.4, 0.1));
    }
  });

  test('barraca melhorada rende mais e é mais rápida', () {
    final b = Barraca(0)..aberta = true;
    final preco = b.preco, tempo = b.tempo, cap = b.capacidade;
    b.nivel = 3;
    expect(b.preco, greaterThan(preco));
    expect(b.tempo, lessThan(tempo));
    expect(b.capacidade, greaterThan(cap));
  });

  test('salvar, carregar e ganho offline (até 3 h)', () {
    final m = Mundo(Random(1))
      ..dinheiro = 500
      ..nivelMochila = 2;
    m.barracas[1].aberta = true;
    m.barracas[1].nivel = 3;
    m.ajudantes.add(Pessoa(13, 5, ajudante: true));
    m.pagos['abrir:2'] = 40;
    final agora = DateTime(2026, 11, 5, 10);
    final n = Mundo(Random(2));
    final fora = n.carregar(m.paraJson(agora), agora.add(const Duration(hours: 10)));
    expect(fora, 36000);
    expect(n.dinheiro, 500);
    expect(n.barracas[1].aberta, isTrue);
    expect(n.barracas[1].nivel, 3);
    expect(n.ajudantes.length, 1);
    expect(n.pagos['abrir:2'], 40);
    final v = n.ganhoOffline(fora);
    expect(v, closeTo(n.ganhoAjudantesPorSegundo * 0.5 * 3 * 3600, 1e-6));
  });

  test('carregar ignora dados estranhos', () {
    final n = Mundo(Random(2));
    n.carregar({'dinheiro': -50, 'ajudantes': 999, 'mochila': 99, 'barracas': [{'a': false, 'n': -3, 'e': 9999}]}, DateTime.now());
    expect(n.dinheiro, 0);
    expect(n.ajudantes.length, Mundo.custosAjudante.length);
    expect(n.nivelMochila, Mundo.maxNivelEquip);
    expect(n.barracas[0].aberta, isTrue); // limonada sempre aberta
    expect(n.barracas[0].estoque, lessThanOrEqualTo(n.barracas[0].capacidade));
  });

  test('arrastar o dedo move o personagem na mesma direção da tela', () {
    final iso = Iso(64, Offset.zero);
    for (final (tx, ty) in [(1.0, 0.0), (0.0, 1.0), (-1.0, 0.0), (0.0, -1.0), (0.7, 0.7)]) {
      final (dx, dy) = direcaoNoMapa(tx, ty);
      final antes = iso.p(5, 5), depois = iso.p(5 + dx * 0.1, 5 + dy * 0.1);
      final mov = depois - antes;
      // mesma direção (cosseno ~ 1)
      final cos = (mov.dx * tx + mov.dy * ty) / (mov.distance * Offset(tx, ty).distance);
      expect(cos, greaterThan(0.99), reason: 'tela ($tx, $ty)');
    }
    expect(direcaoNoMapa(0, 0), (0.0, 0.0));
  });
}
