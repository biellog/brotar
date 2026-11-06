import 'package:fica_sobrio/data/amigos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lê a lista de amigos do servidor (com dados estranhos ignorados)', () {
    final a = Amigo.ler({'id': 'u1', 'nome': '  Ana  ', 'xp': 450, 'status': 'aceito', 'enviado_por_mim': false})!;
    expect(a.nome, 'Ana');
    expect(a.aceito, isTrue);
    expect(a.nivel.numero, greaterThan(1));
    final p = Amigo.ler({'id': 'u2', 'nome': null, 'xp': null, 'status': 'pendente', 'enviado_por_mim': false})!;
    expect(p.nome, 'Amigo');
    expect(p.pedidoRecebido, isTrue);
    expect(p.pedidoEnviado, isFalse);
    expect(Amigo.ler({'id': 3}), isNull);
    expect(Amigo.ler('lixo'), isNull);
    expect(Amigo.ler({'id': 'u3', 'nome': 'Nome muito muito muito comprido', 'status': 'aceito'})!.nome.length, 20);
  });

  test('convite só vale se vier de um amigo aceito', () {
    final amigos = {'amigo1'};
    final ok = lerConvite({'de': 'amigo1', 'n': 'Ana', 'j': 'brilha', 'c': 'K7Q2P', 'x': ''}, amigos)!;
    expect(ok.jogo, JogoConvite.brilha);
    expect(ok.codigo, 'K7Q2P');
    expect(ok.deNome, 'Ana');
    expect(lerConvite({'de': 'estranho', 'n': 'X', 'j': 'brilha', 'c': 'K7Q2P'}, amigos), isNull);
  });

  test('convite com dados estranhos é ignorado ou limpo', () {
    final amigos = {'a'};
    expect(lerConvite({'de': 'a', 'j': 'xadrez', 'c': 'K7Q2P'}, amigos), isNull);
    expect(lerConvite({'de': 'a', 'j': 'suco', 'c': 'k7"; drop'}, amigos), isNull);
    expect(lerConvite({'de': 'a', 'j': 'suco', 'c': 123}, amigos), isNull);
    final c = lerConvite({'de': 'a', 'n': '<b>Bia</b>\n', 'j': 'suco', 'c': 'K7Q2PMNX', 'x': 'Sucos da Galera'}, amigos)!;
    expect(c.deNome, 'bBia/b');
    expect(c.detalhe, 'Sucos da Galera');
    expect(lerConvite({'de': 'a', 'n': null, 'j': 'suco', 'c': 'K7Q2PMNX'}, amigos)!.deNome, 'Um amigo');
  });

  test('mensagens de adicionar amigo', () {
    for (final r in ['enviado', 'aceito', 'ja_amigos', 'voce_mesmo', 'nao_encontrado', 'limite', 'erro', 'qualquer']) {
      expect(textoPedido(r), isNotEmpty);
    }
    expect(textoPedido('aceito'), contains('amigos'));
  });
}
