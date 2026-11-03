import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Toda a comunicação com o Supabase fica aqui.
class Repo {
  static SupabaseClient get _db => Supabase.instance.client;
  static String? get uid => _db.auth.currentUser?.id;

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

  static Future<int> somarXp(int qtd) async {
    final r = await _db.rpc('somar_xp', params: {'qtd': qtd});
    await log('xp_ganho', {'qtd': qtd});
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
  static Future<void> salvarPartida(int pontos, int duracaoSeg) async {
    await _db.from('partidas').insert({'pontos': pontos, 'duracao_seg': duracaoSeg});
    await log('partida', {'pontos': pontos, 'duracao_seg': duracaoSeg});
  }

  static Future<int> recorde() async {
    final r = await _db
        .from('partidas')
        .select('pontos')
        .eq('user_id', uid!)
        .order('pontos', ascending: false)
        .limit(1)
        .maybeSingle();
    return (r?['pontos'] as num?)?.toInt() ?? 0;
  }

  static Future<int> totalPartidas() async {
    final r = await _db.from('partidas').select('id').eq('user_id', uid!).count();
    return r.count;
  }

  // ---------------- Fissura (SOS) ----------------
  static Future<void> registrarFissura({
    required int intensidade,
    String? gatilho,
    required bool superou,
    required int duracaoSeg,
  }) async {
    await _db.from('fissuras').insert({
      'intensidade': intensidade,
      'gatilho': gatilho,
      'superou': superou,
      'duracao_seg': duracaoSeg,
    });
    await log('fissura', {
      'intensidade': intensidade,
      'gatilho': gatilho,
      'superou': superou,
    });
  }

  static Future<int> fissurasVencidas() async {
    final r = await _db
        .from('fissuras')
        .select('id')
        .eq('user_id', uid!)
        .eq('superou', true)
        .count();
    return r.count;
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
