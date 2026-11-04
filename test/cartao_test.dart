import 'package:fica_sobrio/logic/progresso.dart';
import 'package:fica_sobrio/widgets/cartao_compartilhar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contador: textos fáceis, com singular e plural', () {
    expect(tempoPrincipal(const Duration(minutes: 1)), (1, 'minuto'));
    expect(tempoPrincipal(const Duration(minutes: 40)), (40, 'minutos'));
    expect(tempoPrincipal(const Duration(hours: 1, minutes: 5)), (1, 'hora'));
    expect(tempoPrincipal(const Duration(hours: 7)), (7, 'horas'));
    expect(tempoPrincipal(const Duration(days: 1, hours: 3)), (1, 'dia'));
    expect(tempoPrincipal(const Duration(days: 43)), (43, 'dias'));
    expect(tempoDetalhe(const Duration(days: 43, hours: 1, minutes: 12)), 'e 1 hora e 12 minutos');
    expect(tempoDetalhe(const Duration(hours: 5, minutes: 1)), 'e 1 minuto');
  });

  test('próximo marco', () {
    expect(proximoMarcoTexto(const Duration(hours: 20)), contains('4 horas para o seu primeiro dia'));
    expect(proximoMarcoTexto(const Duration(days: 4)), '🎯 Faltam 3 dias para 1 semana!');
    expect(proximoMarcoTexto(const Duration(days: 29)), '🎯 Falta 1 dia para 1 mês!');
    expect(proximoMarcoTexto(const Duration(hours: 23)), '🎯 Falta 1 hora para o seu primeiro dia!');
    expect(proximoMarcoTexto(const Duration(days: 364)), contains('1 ano'));
    expect(proximoMarcoTexto(const Duration(days: 5000)), contains('lenda'));
  });

  test('frase do cartão muda com os dias', () {
    expect(fraseDoMarco(0), contains('nova história'));
    expect(fraseDoMarco(1), contains('primeiro dia'));
    expect(fraseDoMarco(8), contains('semana'));
    expect(fraseDoMarco(400), contains('ANO'));
  });

  testWidgets('gera o cartão quadrado em PNG', (tester) async {
    final png = await tester.runAsync(() => gerarCartaoSobriedade(
          tempo: const Duration(days: 43),
          economia: 1290,
          codigoConvite: 'ABC123',
        ));
    expect(png, isNotNull);
    expect(png!.sublist(1, 4), [0x50, 0x4E, 0x47]); // "PNG"
    // largura e altura no cabeçalho IHDR
    int u32(int i) => (png[i] << 24) | (png[i + 1] << 16) | (png[i + 2] << 8) | png[i + 3];
    expect(u32(16), 1080);
    expect(u32(20), 1080);
  });
}
