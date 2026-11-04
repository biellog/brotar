import 'package:fica_sobrio/data/atualizacao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  VersaoApp v(String url) => VersaoApp(9, '1.0.9', url, '', false);

  test('só aceita atualização do repositório oficial', () {
    expect(v('https://github.com/biellog/fica-sobrio/releases/download/v1.0.9/FicaSobrio.apk').urlOficial, isTrue);
    expect(v('https://site-malicioso.com/FicaSobrio.apk').urlOficial, isFalse);
    expect(v('https://github.com/outra-pessoa/fica-sobrio/releases/download/v1/x.apk').urlOficial, isFalse);
    expect(v('http://github.com/biellog/fica-sobrio/releases/download/v1/x.apk').urlOficial, isFalse);
    expect(v('https://github.com/biellog/fica-sobrio/releases/download/../../x/y.apk').urlOficial, isFalse);
  });
}
