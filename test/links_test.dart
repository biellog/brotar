import 'package:fica_sobrio/config.dart';
import 'package:fica_sobrio/data/links.dart';
import 'package:fica_sobrio/games/brilha/brilha_screen.dart';
import 'package:fica_sobrio/games/brilha/rede.dart';
import 'package:fica_sobrio/web_brilha.dart';
import 'package:fica_sobrio/widgets/compartilhar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    LinksApp.salaPendente.value = null;
    LinksApp.convitePendente.value = null;
  });

  test('links do app: sala e convite válidos', () {
    LinksApp.tratar(Uri.parse('ficasobrio://brilha?sala=k7q2p'));
    expect(LinksApp.salaPendente.value, 'K7Q2P');
    LinksApp.tratar(Uri.parse('ficasobrio://brilha?sala=geral'));
    expect(LinksApp.salaPendente.value, 'geral');
    LinksApp.tratar(Uri.parse('ficasobrio://convite?c=ABC123'));
    expect(LinksApp.convitePendente.value, 'ABC123');
  });

  test('links maliciosos ou estranhos são ignorados', () {
    for (final u in [
      'https://site.com/brilha?sala=K7Q2P', // outro esquema
      'ficasobrio://brilha?sala=../../x',
      'ficasobrio://brilha?sala=%3Cscript%3E',
      'ficasobrio://brilha?sala=${'A' * 50}',
      'ficasobrio://desconhecido?sala=K7Q2P',
      'ficasobrio://convite?c=',
    ]) {
      LinksApp.tratar(Uri.parse(u));
    }
    expect(LinksApp.salaPendente.value, isNull);
    expect(LinksApp.convitePendente.value, isNull);
  });

  test('página web lê a sala do link', () {
    expect(salaDoLink(Uri.parse('https://x.io/jogar/?sala=k7q2p')), 'K7Q2P');
    expect(salaDoLink(Uri.parse('https://x.io/jogar/?sala=GERAL')), 'geral');
    expect(salaDoLink(Uri.parse('https://x.io/jogar/')), isNull);
    expect(salaDoLink(Uri.parse('https://x.io/jogar/?sala=<b>')), isNull);
  });

  test('"Jogar pelo aplicativo" abre o app na sala e cai no site se não tiver o app', () {
    final l = linkAbrirNoApp('K7Q2P');
    expect(l, startsWith('intent://brilha?sala=K7Q2P#Intent;scheme=ficasobrio;package=$pacoteAndroid;'));
    expect(Uri.decodeComponent(l.split('S.browser_fallback_url=')[1].replaceAll(';end', '')),
        '${linkSalaBrilha('K7Q2P')}&semapp=1');
  });

  test('convite da sala: link + código sozinho numa linha', () {
    final m = BrilhaScreenMensagens.convite('K7Q2P');
    expect(m, contains(linkSalaBrilha('K7Q2P')));
    expect(m.split('\n'), contains('K7Q2P'));
  });

  test('convite de XP: código copiável numa linha + link da página', () {
    final b = blocoConvite('ABC123');
    expect(b.split('\n'), contains('ABC123'));
    expect(b, contains(linkConvite('ABC123')));
    expect(blocoConvite(null), '');
  });

  test('achar partidas: agrupa salas públicas e a Arena Geral vem primeiro', () {
    final salas = agruparSalas([
      {'s': 'K7Q2P', 'pub': true, 'n': 'Ana'},
      {'s': 'K7Q2P', 'pub': true, 'n': 'Léo'},
      {'s': 'ZZ999', 'pub': true, 'n': 'Bia'},
      {'s': 'SECRT', 'pub': false, 'n': 'Oculto'}, // sala privada não aparece
      {'s': '<x>', 'pub': true, 'n': 'Hacker'}, // inválida
      {'s': 'geral', 'pub': true, 'n': 'Caio'},
    ]);
    expect(salas.map((s) => s.codigo), ['geral', 'K7Q2P', 'ZZ999']);
    expect(salas[1].pessoas, 2);
    expect(salas[1].nomes, ['Ana', 'Léo']);
    expect(agruparSalas(const []).single.codigo, 'geral'); // Arena Geral sempre aparece
  });

  test('códigos de sala', () {
    final c = gerarCodigoSala();
    expect(codigoValido(c), isTrue);
    expect(c.contains(RegExp('[01OIL]')), isFalse); // sem letras que confundem
    expect(codigoValido('ab'), isFalse);
  });
}
