import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Toda a comunicação com o Supabase fica aqui.
class Repo {
  static SupabaseClient get _db => Supabase.instance.client;
  static String? get uid {
    try {
      return _db.auth.currentUser?.id;
    } catch (_) {
      return null; // Supabase ainda não iniciado (ex.: prévia)
    }
  }

  // ---------------- Dispositivo ----------------
  static Map<String, dynamic>? _dispositivo;

  static Future<Map<String, dynamic>> dispositivo() async {
    if (_dispositivo != null) return _dispositivo!;
    final info = <String, dynamic>{};
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final a = await DeviceInfoPlugin().androidInfo;
        info.addAll({
          'plataforma': 'android',
          'marca': a.brand,
          'modelo': a.model,
          'fabricante': a.manufacturer,
          'android': a.version.release,
          'sdk': a.version.sdkInt,
          'fisico': a.isPhysicalDevice,
        });
      } else if (!kIsWeb && Platform.isIOS) {
        final i = await DeviceInfoPlugin().iosInfo;
        info.addAll({
          'plataforma': 'ios',
          'modelo': i.utsname.machine,
          'ios': i.systemVersion,
        });
      } else {
        info['plataforma'] = kIsWeb ? 'web' : Platform.operatingSystem;
      }
    } catch (_) {
      info['plataforma'] = 'desconhecida';
    }
    info['fuso'] = DateTime.now().timeZoneName;
    info['versao_app'] = '1.0.0';
    return _dispositivo = info;
  }

  /// Registra QUALQUER ação feita no app. Nunca trava o app se falhar.
  static Future<void> log(String tipo, [Map<String, dynamic> dados = const {}]) async {
    if (uid == null) return;
    try {
      await _db.from('eventos').insert({
        'tipo': tipo,
        'dados': dados,
        'dispositivo': await dispositivo(),
      });
    } catch (e) {
      debugPrint('Falha ao registrar evento $tipo: $e');
    }
  }

  /// Tipos de eventos registrados hoje (usado nas missões diárias).
  static Future<Set<String>> eventosHoje() async {
    final agora = DateTime.now();
    final inicio = DateTime(agora.year, agora.month, agora.day).toUtc();
    final rows = await _db
        .from('eventos')
        .select('tipo')
        .gte('criado_em', inicio.toIso8601String());
    return rows.map<String>((r) => r['tipo'] as String).toSet();
  }

  // ---------------- Autenticação ----------------
  static Future<void> entrar(String email, String senha) async {
    await _db.auth.signInWithPassword(email: email.trim(), password: senha);
    await log('login');
  }

  static Future<bool> cadastrar(String nome, String email, String senha) async {
    final res = await _db.auth.signUp(
      email: email.trim(),
      password: senha,
      data: {'nome': nome.trim(), 'consentimento': 'true'},
    );
    if (res.session != null) await log('cadastro');
    // true = já entrou; false = precisa confirmar o e-mail
    return res.session != null;
  }

  static Future<void> recuperarSenha(String email) =>
      _db.auth.resetPasswordForEmail(email.trim());

  static Future<void> sair() async {
    await log('logout');
    await _db.auth.signOut();
  }

  static Future<void> excluirConta() async {
    await _db.rpc('excluir_minha_conta');
    await _db.auth.signOut();
  }

  // ---------------- Perfil ----------------
  static Future<Map<String, dynamic>?> perfil() async {
    if (uid == null) return null;
    return _db.from('perfis').select().eq('id', uid!).maybeSingle();
  }

  static Future<void> salvarPerfil(Map<String, dynamic> campos) async {
    await _db.from('perfis').update({
      ...campos,
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid!);
    await log('perfil_atualizado', {'campos': campos.keys.toList()});
  }

  /// Pede XP ao servidor. O servidor aplica limites diários por [motivo]
  /// (checkin, agua, recaida, jogo, movimento, conquista...), então repetir
  /// a mesma ação não gera XP infinito.
  static Future<int> somarXp(int qtd, [String motivo = 'outro']) async {
    final r = await _db.rpc('somar_xp', params: {'qtd': qtd, 'motivo': motivo});
    await log('xp_ganho', {'qtd': qtd, 'motivo': motivo});
    return (r as num?)?.toInt() ?? 0;
  }

  static Future<bool> usarConvite(String codigo) async {
    final ok = await _db.rpc('usar_convite', params: {'codigo': codigo}) == true;
    await log('convite_usado', {'codigo': codigo, 'ok': ok});
    return ok;
  }

  static Future<void> registrarRecaida() async {
    await _db.rpc('registrar_recaida');
    await log('recaida');
  }

  // ---------------- Check-in ----------------
  static String _hoje() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static Future<Map<String, dynamic>?> checkinHoje() => _db
      .from('checkins')
      .select()
      .eq('user_id', uid!)
      .eq('data', _hoje())
      .maybeSingle();

  static Future<void> salvarCheckin({
    required int humor,
    required int fissura,
    required bool sobrio,
    String? nota,
  }) async {
    await _db.from('checkins').upsert({
      'user_id': uid,
      'data': _hoje(),
      'humor': humor,
      'fissura': fissura,
      'sobrio': sobrio,
      'nota': nota,
    }, onConflict: 'user_id,data');
    await log('checkin', {'humor': humor, 'fissura': fissura, 'sobrio': sobrio});
  }

  static Future<List<Map<String, dynamic>>> ultimosCheckins([int n = 7]) => _db
      .from('checkins')
      .select()
      .eq('user_id', uid!)
      .order('data', ascending: false)
      .limit(n);

  // ---------------- Jogo ----------------
  static Future<void> salvarPartida(String jogo, int pontos, int duracaoSeg) async {
    if (uid == null) return;
    await _db.from('partidas').insert({'jogo': jogo, 'pontos': pontos, 'duracao_seg': duracaoSeg});
    await log('partida', {'jogo': jogo, 'pontos': pontos, 'duracao_seg': duracaoSeg});
  }

  /// Maior pontuação (de um jogo específico ou de todos).
  static Future<int> recorde([String? jogo]) async {
    if (uid == null) return 0;
    var q = _db.from('partidas').select('pontos').eq('user_id', uid!);
    if (jogo != null) q = q.eq('jogo', jogo);
    final r = await q.order('pontos', ascending: false).limit(1).maybeSingle();
    return (r?['pontos'] as num?)?.toInt() ?? 0;
  }

  /// Recorde de cada jogo: {'tempestade': 820, 'memoria': 950, ...}
  static Future<Map<String, int>> recordesPorJogo() async {
    if (uid == null) return {};
    final rows = await _db
        .from('partidas')
        .select('jogo, pontos')
        .eq('user_id', uid!)
        .order('pontos', ascending: false)
        .limit(300);
    final m = <String, int>{};
    for (final r in rows) {
      final j = r['jogo'] as String? ?? 'tempestade';
      m.putIfAbsent(j, () => (r['pontos'] as num).toInt());
    }
    return m;
  }

  static Future<int> totalPartidas() async {
    final r = await _db.from('partidas').select('id').eq('user_id', uid!).count();
    return r.count;
  }

  // ---------------- Fissura (SOS) ----------------
  /// Segundos mínimos surfando a onda para o "venci a fissura" valer XP.
  static const minimoSosSeg = 90;

  /// Registra o momento de fissura. Retorna o XP ganho (0 ou 50).
  /// Quem decide é o servidor: precisa de 90 s, no máximo 3 por dia e 30 min de intervalo.
  static Future<int> registrarFissura({
    required int intensidade,
    String? gatilho,
    required bool superou,
    required int duracaoSeg,
  }) async {
    final r = await _db.rpc('vencer_fissura', params: {
      'intensidade': intensidade,
      'gatilho': gatilho,
      'superou': superou,
      'duracao_seg': duracaoSeg,
    });
    final xp = (r as num?)?.toInt() ?? 0;
    await log('fissura', {
      'intensidade': intensidade,
      'gatilho': gatilho,
      'superou': superou,
      'duracao_seg': duracaoSeg,
      'xp': xp,
    });
    return xp;
  }

  static Future<int> fissurasVencidas() async {
    final r = await _db
        .from('fissuras')
        .select('id')
        .eq('user_id', uid!)
        .eq('superou', true)
        .gte('duracao_seg', minimoSosSeg) // cliques rápidos não contam para conquista
        .count();
    return r.count;
  }

  // ---------------- Movimento ----------------
  static Future<void> registrarAtividade(String tipo, int duracaoSeg, int passos) async {
    if (uid == null) return;
    await _db.from('atividades').insert({'tipo': tipo, 'duracao_seg': duracaoSeg, 'passos': passos});
    await log('atividade', {'tipo': tipo, 'duracao_seg': duracaoSeg, 'passos': passos});
  }

  static Future<int> totalAtividades() async {
    if (uid == null) return 0;
    final r = await _db.from('atividades').select('id').eq('user_id', uid!).count();
    return r.count;
  }

  /// Quantas vezes cada atividade foi concluída: {'caminhada': 3, ...}
  static Future<Map<String, int>> atividadesPorTipo() async {
    if (uid == null) return {};
    final rows = await _db.from('atividades').select('tipo').eq('user_id', uid!).limit(1000);
    final m = <String, int>{};
    for (final r in rows) {
      final t = r['tipo'] as String;
      m[t] = (m[t] ?? 0) + 1;
    }
    return m;
  }

  // ---------------- Conquistas ----------------
  static Future<Set<String>> conquistas() async {
    final rows = await _db.from('conquistas').select('codigo').eq('user_id', uid!);
    return rows.map<String>((r) => r['codigo'] as String).toSet();
  }

  static Future<void> desbloquear(String codigo) async {
    await _db.from('conquistas').upsert(
      {'user_id': uid, 'codigo': codigo},
      onConflict: 'user_id,codigo',
      ignoreDuplicates: true,
    );
    await log('conquista', {'codigo': codigo});
  }
}
