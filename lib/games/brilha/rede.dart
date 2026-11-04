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

/// Uma sala aberta, para a lista "Achar partidas".
class SalaInfo {
  final String codigo;
  final int pessoas;
  final List<String> nomes;
  const SalaInfo(this.codigo, this.pessoas, this.nomes);

  bool get geral => codigo == 'geral';
}

final _codigoSala = RegExp(r'^[A-Z0-9]{4,8}$');

/// Junta os avisos de presença do diretório em uma lista de salas públicas.
/// A Arena Geral sempre aparece primeiro; as outras, da mais cheia para a mais vazia.
List<SalaInfo> agruparSalas(Iterable<Map<String, dynamic>> presencas) {
  final porSala = <String, List<String>>{};
  for (final p in presencas) {
    final sala = p['s'];
    if (sala is! String || p['pub'] != true) continue;
    if (sala != 'geral' && !_codigoSala.hasMatch(sala)) continue;
    porSala.putIfAbsent(sala, () => []).add(limparNome(p['n']));
  }
  porSala.putIfAbsent('geral', () => []);
  final lista = [for (final e in porSala.entries) SalaInfo(e.key, e.value.length, e.value)];
  lista.sort((a, b) => a.geral ? -1 : (b.geral ? 1 : b.pessoas.compareTo(a.pessoas)));
  return lista.take(30).toList();
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
  RealtimeChannel? _diretorio;
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
    bool publica = true,
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
          // aparece em "Achar partidas" (salas privadas não são listadas)
          final dir = db.channel(canalDiretorio, opts: RealtimeChannelConfig(key: meuId));
          _diretorio = dir;
          dir.subscribe((st, _) async {
            if (st == RealtimeSubscribeStatus.subscribed) {
              await dir.track({'s': sala, 'pub': publica, 'n': meuNome});
            }
          });
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
    final d = _diretorio;
    _canal = null;
    _diretorio = null;
    conectado = false;
    if (d != null) {
      try {
        await d.untrack();
        await _db?.removeChannel(d);
      } catch (_) {}
    }
    if (c == null) return;
    try {
      await c.untrack();
      await _db?.removeChannel(c);
    } catch (_) {}
  }

  static const canalDiretorio = 'brilha-diretorio';

  /// Acompanha, ao vivo, as salas abertas (para "Achar partidas" e o contador do saguão).
  static Future<void Function()> observarSalas(void Function(List<SalaInfo> salas, int totalOnline) aoMudar) async {
    final db = _db;
    if (db == null) {
      aoMudar(agruparSalas(const []), 0);
      return () {};
    }
    final canal = db.channel(canalDiretorio);
    canal
      ..onPresenceSync((_) {
        final todas = [for (final e in canal.presenceState()) for (final p in e.presences) p.payload];
        aoMudar(agruparSalas(todas), todas.length);
      })
      ..subscribe();
    return () => db.removeChannel(canal);
  }
}
