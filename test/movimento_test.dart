import 'package:fica_sobrio/games/relaxantes.dart';
import 'package:fica_sobrio/logic/movimento.dart';
import 'package:fica_sobrio/screens/jogos_tab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contador de passos usa o primeiro valor do sensor como base', () {
    final c = ContadorPassos();
    c.novoValor(10500); // passos desde que o celular ligou
    expect(c.passos, 0);
    c.novoValor(10750);
    expect(c.passos, 250);
    expect(c.progresso(1000), 0.25);
    expect(c.km, closeTo(0.1875, 0.0001));
    c.novoValor(30); // celular reiniciou no meio
    expect(c.passos, 0);
  });

  test('roteiro guiado avança etapa por etapa e termina', () {
    final a = atividades.firstWhere((a) => a.id == 'alongamento');
    expect(a.duracaoGuiada, 180);
    expect(posicaoNoRoteiro(a.etapas, 0).etapa, 0);
    expect(posicaoNoRoteiro(a.etapas, 29).restante, 1);
    expect(posicaoNoRoteiro(a.etapas, 30).etapa, 1);
    expect(posicaoNoRoteiro(a.etapas, 180).terminou, isTrue);
  });

  test('atividades liberam jogos na ordem 1, 3 e 5', () {
    expect(jogoLiberado('jardim', 0), isFalse);
    expect(jogoLiberado('jardim', 1), isTrue);
    expect(jogoLiberado('mandala', 2), isFalse);
    expect(jogoLiberado('aquario', 5), isTrue);
    expect(jogoLiberado('tempestade', 0), isTrue); // jogos normais sempre liberados
    expect(jogoLiberado('plastico', 0), isTrue);
    expect(novosDesbloqueios(0, 1), ['jardim']);
    expect(novosDesbloqueios(2, 3), ['mandala']);
    expect(novosDesbloqueios(3, 4), isEmpty);
  });

  test('todo jogo desbloqueável existe na lista de jogos', () {
    for (final d in desbloqueios) {
      expect(infoJogo(d.jogoId).id, d.jogoId);
    }
  });

  test('plástico bolha: cada bolha estoura uma vez e a folha se renova', () {
    final m = PlasticoBolha();
    expect(m.tocar(0.01, 0.01), isTrue);
    expect(m.tocar(0.02, 0.02), isFalse); // mesma bolha
    for (var l = 0; l < PlasticoBolha.linhas; l++) {
      for (var c = 0; c < PlasticoBolha.colunas; c++) {
        m.tocar((c + 0.5) / PlasticoBolha.colunas, (l + 0.5) / PlasticoBolha.linhas);
      }
    }
    expect(m.folhaCompleta, isTrue);
    expect(m.total, PlasticoBolha.colunas * PlasticoBolha.linhas);
    m.novaFolha();
    expect(m.folhaCompleta, isFalse);
  });
}
