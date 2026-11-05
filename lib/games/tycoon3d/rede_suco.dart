// Império do Suco em grupo: conexão em tempo real (Supabase Realtime) e o
// progresso compartilhado salvo no servidor (funções *_imperio_grupo).
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config.dart';

const _letras = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // sem 0/O, 1/I/L
final _codigoImperio = RegExp(r'^[A-Z2-9]{8}$');

/// Limpa e valida um código de império (8 letras/números).
String? codigoImperio(String? c) {
  final s = (c ?? '').trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  return _codigoImperio.hasMatch(s) ? s : null;
}

String gerarIdLocal([Random? r]) {
  final rnd = r ?? Random();
  return 'w${List.generate(10, (_) => _letras[rnd.nextInt(_letras.length)]).join()}';
}

/// Link que abre o império no app (ou no site, se não tiver o app).
String linkImperio(String codigo) => '${siteUrl}jogar/?suco=${Uri.encodeComponent(codigo)}';

String mensagemConviteImperio(String codigo, String nome) =>
    '🧃 Vem construir o império "$nome" comigo no Império do Suco 3D, do app Fica Sóbrio!\n\n'
    'O progresso é um só para todo mundo: o dinheiro, as barracas e as missões são do grupo.\n\n'
    '👉 Toque para entrar (no app ou no navegador):\n'
    '${linkImperio(codigo)}\n\n'
    'Ou use o código do império:\n'
    '$codigo';

/// Quem está no império agora (pela presença do canal).
class Presente {
  final String id, nome;
  final int cor;
  final int entrou; // ms: quem entrou primeiro roda o jogo
  const Presente(this.id, this.nome, this.cor, this.entrou);
}

/// Escolhe quem roda o jogo: quem entrou primeiro (empate: menor id). Todos chegam na mesma resposta.
String? escolherAnfitriao(Iterable<Presente> ps) {
  final l = ps.toList()..sort((a, b) => a.entrou != b.entrou ? a.entrou.compareTo(b.entrou) : a.id.compareTo(b.id));
  return l.firstOrNull?.id;
}

class ImperioInfo {
  final String codigo, nome;
  final int membros;
  const ImperioInfo(this.codigo, this.nome, this.membros);
}

class RedeSuco {
  static SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static bool get logado => _db?.auth.currentUser != null;
  static String? get idConta => _db?.auth.currentUser?.id;

  // ---------------- servidor ----------------
  static Future<String> criar(String nome) async {
    final db = _db;
    if (db == null) throw Exception('sem servidor');
    final r = await db.rpc('criar_imperio_grupo', params: {'p_nome': nome});
    final c = codigoImperio(r as String?);
    if (c == null) throw Exception('código inválido');
    return c;
  }

  /// (nome, estado) ou null se o código não existe.
  static Future<(String, Map<String, dynamic>)?> abrir(String codigo) async {
    final db = _db;
    if (db == null) throw Exception('sem servidor');
    final r = await db.rpc('abrir_imperio_grupo', params: {'p_codigo': codigo});
    if (r is! Map) return null;
    final nome = r['nome'] is String ? r['nome'] as String : 'Império';
    final estado = r['estado'] is Map ? Map<String, dynamic>.from(r['estado'] as Map) : <String, dynamic>{};
    return (nome, estado);
  }

  static Future<bool> salvar(String codigo, Map<String, dynamic> estado) async {
    final db = _db;
    if (db == null) return false;
    try {
      return await db.rpc('salvar_imperio_grupo', params: {'p_codigo': codigo, 'p_estado': estado}) == true;
    } catch (e) {
      debugPrint('salvar império: $e');
      return false;
    }
  }

  static Future<List<ImperioInfo>> meus() async {
    final db = _db;
    if (db == null || !logado) return const [];
    final r = await db.rpc('meus_imperios_grupo');
    if (r is! List) return const [];
    return [
      for (final i in r)
        if (i is Map && codigoImperio(i['codigo'] as String?) != null)
          ImperioInfo(
            i['codigo'] as String,
            i['nome'] is String ? i['nome'] as String : 'Império',
            i['membros'] is int ? i['membros'] as int : 1,
          ),
    ];
  }

  // ---------------- tempo real ----------------
  RealtimeChannel? _canal;
  bool conectado = false;
  final presentes = <String, Presente>{};

  Future<void> entrar({
    required String codigo,
    required String meuId,
    required String meuNome,
    required int minhaCor,
    required int entrouEm,
    required void Function(Map<String, dynamic>) aoReceberEstado,
    required void Function(String id, Map<String, dynamic>) aoReceberMovimento,
    required void Function(String id, String tipo, String k) aoReceberAcao,
    required void Function() aoMudarPresenca,
    required void Function(bool) aoMudarConexao,
  }) async {
    final db = _db;
    if (db == null) return aoMudarConexao(false);
    final canal = db.channel('suco-${codigo.toLowerCase()}', opts: RealtimeChannelConfig(key: meuId));
    _canal = canal;
    Map<String, dynamic> dados(Map<String, dynamic> m) =>
        m['payload'] is Map ? Map<String, dynamic>.from(m['payload'] as Map) : m;
    canal
      ..onBroadcast(event: 's', callback: (m) => aoReceberEstado(dados(m)))
      ..onBroadcast(
        event: 'm',
        callback: (m) {
          final d = dados(m);
          final id = d['i'];
          if (id is String && id != meuId) aoReceberMovimento(id, d);
        },
      )
      ..onBroadcast(
        event: 'a',
        callback: (m) {
          final d = dados(m);
          final id = d['i'], t = d['t'], k = d['k'];
          if (id is String && t is String && k is String && t.length < 12 && k.length < 20) aoReceberAcao(id, t, k);
        },
      )
      ..onPresenceSync((_) {
        presentes.clear();
        for (final estado in canal.presenceState()) {
          for (final p in estado.presences) {
            final id = p.payload['i'], n = p.payload['n'], c = p.payload['c'], t = p.payload['t'];
            if (id is! String || id.isEmpty || id.length > 40 || t is! int) continue;
            presentes[id] = Presente(
              id,
              n is String && n.trim().isNotEmpty ? (n.trim().length > 16 ? n.trim().substring(0, 16) : n.trim()) : 'Amigo',
              c is int ? c : 0,
              t,
            );
          }
        }
        aoMudarPresenca();
      })
      ..subscribe((status, erro) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          conectado = true;
          aoMudarConexao(true);
          await canal.track({'i': meuId, 'n': meuNome, 'c': minhaCor, 't': entrouEm});
        } else if (status == RealtimeSubscribeStatus.closed ||
            status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          conectado = false;
          aoMudarConexao(false);
          if (erro != null) debugPrint('Realtime suco: $erro');
        }
      });
  }

  void enviarEstado(Map<String, dynamic> e) {
    if (conectado) _canal?.sendBroadcastMessage(event: 's', payload: e);
  }

  void enviarMovimento(Map<String, dynamic> m) {
    if (conectado) _canal?.sendBroadcastMessage(event: 'm', payload: m);
  }

  void enviarAcao(String meuId, String tipo, String k) {
    if (conectado) _canal?.sendBroadcastMessage(event: 'a', payload: {'i': meuId, 't': tipo, 'k': k});
  }

  Future<void> sair() async {
    final c = _canal;
    _canal = null;
    conectado = false;
    if (c == null) return;
    try {
      await c.untrack();
      await _db?.removeChannel(c);
    } catch (_) {}
  }
}
