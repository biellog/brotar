import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'motor.dart';

/// Um jogador visto pela rede.
class JogadorRede {
  final String id, nome;
  final int cor;
  final bool robo;
  final double x, y;
  final int pontos;
  const JogadorRede(this.id, this.nome, this.cor, this.robo, this.x, this.y, this.pontos);

  /// Lê e VALIDA o que chegou (dados de outros celulares não são confiáveis).
  static JogadorRede? ler(Object? m) {
    if (m is! Map) return null;
    final id = m['i'];
    if (id is! String || id.isEmpty || id.length > 40) return null;
    final x = m['x'], y = m['y'];
    if (x is! num || y is! num || !x.isFinite || !y.isFinite) return null;
    return JogadorRede(
      id,
      limparNome(m['n']),
      coresVagalume.contains(m['c']) ? m['c'] as int : coresVagalume.first,
      m['b'] == 1,
      x.toDouble().clamp(0, larguraMundo),
      y.toDouble().clamp(0, alturaMundo),
      (m['s'] is num) ? (m['s'] as num).toInt().clamp(0, 100000) : 0,
    );
  }
}

String limparNome(Object? n) {
  if (n is! String) return 'Vagalume';
  final limpo = n.replaceAll(RegExp(r'[\u0000-\u001F<>]'), '').trim();
  if (limpo.isEmpty) return 'Vagalume';
  return limpo.length > 16 ? limpo.substring(0, 16) : limpo;
}

/// Conexão em tempo real pelo Supabase Realtime (broadcast + presence).
/// Sem internet ou sem Supabase, o jogo roda só com bots (modo offline).
class RedeBrilha {
  RealtimeChannel? _canal;
  bool conectado = false;
  final _presentes = <String, (String, int)>{}; // id -> (nome, cor)

  Map<String, (String, int)> get presentes => Map.unmodifiable(_presentes);

  static SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static String nomeCanal(String sala) => 'brilha-${sala.toLowerCase()}';

  Future<void> entrar({
    required String sala,
    required String meuId,
    required String meuNome,
    required int minhaCor,
    required void Function(List<JogadorRede>) aoReceberPosicoes,
    required void Function(int luz, int geracao) aoReceberLuz,
    required void Function(String id, String emote) aoReceberEmote,
    required void Function() aoMudarPresenca,
    required void Function(bool) aoMudarConexao,
  }) async {
    final db = _db;
    if (db == null) return aoMudarConexao(false);
    final canal = db.channel(nomeCanal(sala), opts: RealtimeChannelConfig(key: meuId));
    _canal = canal;
    canal
      ..onBroadcast(
        event: 'p',
        callback: (m) {
          final dados = _dados(m);
          final lista = dados['j'];
          if (lista is! List) return;
          aoReceberPosicoes([for (final j in lista.take(12)) ?JogadorRede.ler(j)]);
        },
      )
      ..onBroadcast(
        event: 'l',
        callback: (m) {
          final d = _dados(m);
          final l = d['l'], g = d['g'];
          if (l is int && g is int && l >= 0 && l < 100000 && g >= 0) aoReceberLuz(l, g);
        },
      )
      ..onBroadcast(
        event: 'e',
        callback: (m) {
          final d = _dados(m);
          if (d['i'] is String && d['e'] is String) aoReceberEmote(d['i'] as String, d['e'] as String);
        },
      )
      ..onPresenceSync((_) {
        _presentes.clear();
        for (final estado in canal.presenceState()) {
          for (final p in estado.presences) {
            final id = p.payload['i'];
            if (id is String && id.length <= 40) {
              _presentes[id] = (
                limparNome(p.payload['n']),
                coresVagalume.contains(p.payload['c']) ? p.payload['c'] as int : coresVagalume.first,
              );
            }
          }
        }
        aoMudarPresenca();
      })
      ..subscribe((status, erro) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          conectado = true;
          aoMudarConexao(true);
          await canal.track({'i': meuId, 'n': meuNome, 'c': minhaCor});
        } else if (status == RealtimeSubscribeStatus.closed ||
            status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          conectado = false;
          aoMudarConexao(false);
          if (erro != null) debugPrint('Realtime: $erro');
        }
      });
  }

  static Map<String, dynamic> _dados(Map<String, dynamic> m) =>
      m['payload'] is Map ? Map<String, dynamic>.from(m['payload'] as Map) : m;

  void enviarPosicoes(List<Vagalume> js) {
    if (!conectado) return;
    _canal?.sendBroadcastMessage(event: 'p', payload: {
      'j': [
        for (final j in js)
          {
            'i': j.id,
            'x': j.x.roundToDouble(),
            'y': j.y.roundToDouble(),
            's': j.pontos,
            'n': j.nome,
            'c': j.cor,
            if (j.robo) 'b': 1,
          }
      ],
    });
  }

  void enviarLuz(int luz, int geracao) {
    if (conectado) _canal?.sendBroadcastMessage(event: 'l', payload: {'l': luz, 'g': geracao});
  }

  void enviarEmote(String id, String e) {
    if (conectado) _canal?.sendBroadcastMessage(event: 'e', payload: {'i': id, 'e': e});
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

  /// Conta quantas pessoas estão na Arena Geral agora (para o lobby).
  static Future<(RealtimeChannel?, void Function())> observarOnline(void Function(int) aoContar) async {
    final db = _db;
    if (db == null) return (null, () {});
    final canal = db.channel(nomeCanal('geral'));
    canal
      ..onPresenceSync((_) {
        var n = 0;
        for (final e in canal.presenceState()) {
          n += e.presences.length;
        }
        aoContar(n);
      })
      ..subscribe();
    return (canal, () => db.removeChannel(canal));
  }
}
