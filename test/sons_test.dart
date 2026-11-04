import 'dart:io';

import 'package:fica_sobrio/data/musica.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('todo efeito sonoro tem arquivo em assets/', () {
    for (final e in Efeito.values) {
      expect(File('assets/${e.arquivo}').existsSync(), isTrue, reason: e.arquivo);
    }
  });

  test('existe a música calma de fundo', () {
    expect(File('assets/musica/serenidade.ogg').existsSync(), isTrue);
  });

  test('pastas de som estão declaradas no pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/musica/'));
    expect(pubspec, contains('- assets/sons/'));
  });

  test('música começa baixa por padrão', () {
    expect(Musica.volumeMusica.value, lessThanOrEqualTo(0.3));
  });
}
