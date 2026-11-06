// Amigos: lista (pelo servidor), quem está online agora (Supabase Realtime presence)
// e convites para jogar juntos (tabela convites_jogo, entregue ao vivo pelo Realtime).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/progresso.dart';

class Amigo {
  final String id, nome, status;
  final int xp;
  final bool enviadoPorMim;
  const Amigo(this.id, this.nome, this.xp, this.status, this.enviadoPorMim);

  bool get aceito => status == 'aceito';
  bool get pedidoRecebido => status == 'pendente' && !enviadoPorMim;
  bool get pedidoEnviado => status == 'pendente' && enviadoPorMim;
  Nivel get nivel => nivelDe(xp);

  static Amigo? ler(Object? m) {
    if (m is! Map) return null;
    final id = m['id'], nome = m['nome'], status = m['status'];
    if (id is! String || status is! String) return null;
    final n = nome is String && nome.trim().isNotEmpty ? nome.trim() : 'Amigo';
    return Amigo(id, n.length > 20 ? n.substring(0, 20) : n, (m['xp'] as num?)?.toInt() ?? 0, status,
        m['enviado_por_mim'] == true);
  }
}

/// Jogos para chamar um amigo.
enum JogoConvite {
  brilha('🌟', 'Brilha Junto'),
  suco('🧃', 'Império do Suco');

  final String emoji, nome;
  const JogoConvite(this.emoji, this.nome);
}

class ConviteJogo {
  final String deId, deNome, codigo, detalhe;
  final JogoConvite jogo;
  const ConviteJogo(this.deId, this.deNome, this.jogo, this.codigo, this.detalhe);
}

final _codigo = RegExp(r'^[A-Z0-9]{4,12}$');

/// Lê e VALIDA um convite que chegou pela rede (dados de fora nunca são confiáveis).
ConviteJogo? lerConvite(Map<String, dynamic> d, Set<String> amigosAceitos) {
  final de = d['de'], n = d['n'], j = d['j'], c = d['c'], x = d['x'];
  if (de is! String || !amigosAceitos.contains(de)) return null; // só de amigos
  final jogo = JogoConvite.values.where((e) => e.name == j).firstOrNull;
  if (jogo == null || c is! String || !_codigo.hasMatch(c)) return null;
  String limpar(Object? s, String padrao) {
    if (s is! String) return padrao;
    final l = s.replaceAll(RegExp(r'[\u0000-\u001F<>]'), '').trim();
    return l.isEmpty ? padrao : (l.length > 30 ? l.substring(0, 30) : l);
  }

  return ConviteJogo(de, limpar(n, 'Um amigo'), jogo, c, limpar(x, ''));
}

/// Mensagem amigável para o resultado de "adicionar amigo".
String textoPedido(String r) => switch (r) {
  'enviado' => 'Pedido enviado! Quando aceitarem, vocês viram amigos. 💚',
  'aceito' => 'Vocês agora são amigos! 🎉',
  'ja_amigos' => 'Vocês já são amigos.',
  'voce_mesmo' => 'Esse é o seu próprio código. 😄',
  'nao_encontrado' => 'Não achei ninguém com esse código. Confira e tente de novo.',
  'limite' => 'Muitos pedidos por hoje. Tente amanhã.',
  _ => 'Não deu agora. Confira a internet e tente de novo.',
};

class Amigos {
  Amigos._();

  static SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static String? get meuId => _db?.auth.currentUser?.id;

  /// Lista de amigos e pedidos (atualizada pela tela de amigos).
  static final lista = ValueNotifier<List<Amigo>>(const []);

  /// Ids dos amigos aceitos que estão com o app aberto agora.
  static final online = ValueNotifier<Set<String>>(const {});

  /// Convite recebido de um amigo (a tela inicial mostra e depois limpa).
  static final conviteRecebido = ValueNotifier<ConviteJogo?>(null);

  static Set<String> get aceitos => {for (final a in lista.value) if (a.aceito) a.id};
  static int get onlineAgora => online.value.intersection(aceitos).length;

  // ---------------- servidor ----------------
  static Future<List<Amigo>> carregar() async {
    final db = _db;
    if (db == null || meuId == null) return const [];
    final r = await db.rpc('meus_amigos');
    final l = r is List ? [for (final x in r) ?Amigo.ler(x)] : <Amigo>[];
    lista.value = l;
    _atualizarOnline();
    return l;
  }

  static Future<String> pedir(String codigo) async {
    final db = _db;
    if (db == null) return 'erro';
    try {
      final r = await db.rpc('pedir_amizade', params: {'p_codigo': codigo.trim().toUpperCase()});
      await carregar();
      return r is String ? r : 'erro';
    } catch (e) {
      debugPrint('pedir amizade: $e');
      return 'erro';
    }
  }

  static Future<bool> responder(String de, bool aceitar) async {
    final db = _db;
    if (db == null) return false;
    final ok = await db.rpc('responder_amizade', params: {'p_de': de, 'p_aceitar': aceitar}) == true;
    await carregar();
    return ok;
  }

  static Future<bool> remover(String outro) async {
    final db = _db;
    if (db == null) return false;
    final ok = await db.rpc('remover_amizade', params: {'p_outro': outro}) == true;
    await carregar();
    return ok;
  }

  // ---------------- online e convites ----------------
  static RealtimeChannel? _presenca, _caixa;
  static final _todosOnline = <String>{};
  static bool _visivel = false;

  /// Liga o "estou online" e a caixa de convites (chamado ao abrir o app logado).
  static Future<void> conectar() async {
    final db = _db, eu = meuId;
    if (db == null || eu == null || _presenca != null) return;
    try {
      await carregar();
    } catch (_) {}
    final p = db.channel('fs-online', opts: RealtimeChannelConfig(key: eu));
    _presenca = p;
    p
      ..onPresenceSync((_) {
        _todosOnline.clear();
        for (final estado in p.presenceState()) {
          for (final x in estado.presences) {
            final id = x.payload['i'];
            if (id is String && id.length <= 40) _todosOnline.add(id);
          }
        }
        _atualizarOnline();
      })
      ..subscribe((status, _) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _visivel = true;
          await p.track({'i': eu});
        }
      });
    // convites: chegam como linha nova na tabela convites_jogo (só eu consigo ler as minhas)
    final caixa = db.channel('fs-convites-$eu');
    _caixa = caixa;
    caixa
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'convites_jogo',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'para', value: eu),
        callback: (m) {
          final r = m.newRecord;
          final c = lerConvite({'de': r['de'], 'n': r['de_nome'], 'j': r['jogo'], 'c': r['codigo'], 'x': r['detalhe']}, aceitos);
          if (c != null) conviteRecebido.value = c;
        },
      )
      ..subscribe();
  }

  /// App foi para o fundo: some da lista de online. Voltou: aparece de novo.
  static Future<void> visivel(bool sim) async {
    final p = _presenca, eu = meuId;
    if (p == null || eu == null || sim == _visivel) return;
    _visivel = sim;
    try {
      if (sim) {
        await p.track({'i': eu});
      } else {
        await p.untrack();
      }
    } catch (_) {}
  }

  static Future<void> desconectar() async {
    final db = _db;
    for (final c in [_presenca, _caixa]) {
      if (c == null) continue;
      try {
        await db?.removeChannel(c);
      } catch (_) {}
    }
    _presenca = null;
    _caixa = null;
    _todosOnline.clear();
    online.value = const {};
  }

  static void _atualizarOnline() {
    final eu = meuId;
    online.value = {for (final id in _todosOnline) if (id != eu && aceitos.contains(id)) id};
  }

  /// Manda o convite (o servidor confere se vocês são amigos e entrega ao vivo).
  static Future<bool> convidar(Amigo amigo, JogoConvite jogo, String codigo, {String detalhe = ''}) async {
    final db = _db;
    if (db == null || meuId == null || !amigo.aceito) return false;
    try {
      return await db.rpc('convidar_amigo', params: {
            'p_para': amigo.id,
            'p_jogo': jogo.name,
            'p_codigo': codigo,
            'p_detalhe': detalhe,
          }) ==
          true;
    } catch (e) {
      debugPrint('convite: $e');
      return false;
    }
  }
}
