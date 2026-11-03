// Garante que o app inteiro (com todos os plugins) compila, inclusive o código
// de plataforma do workmanager, que já quebrou o build do APK uma vez.
// ignore_for_file: depend_on_referenced_packages
import 'package:fica_sobrio/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager_apple/workmanager_apple.dart';

void main() {
  test('o app compila com todos os plugins', () {
    expect(WorkmanagerApple, isNotNull);
    expect(app.main, isNotNull);
  });
}
