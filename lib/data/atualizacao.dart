import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';

class VersaoApp {
  final int codigo;
  final String nome;
  final String url;
  final String notas;
  final bool obrigatoria;
  const VersaoApp(this.codigo, this.nome, this.url, this.notas, this.obrigatoria);

  factory VersaoApp.deJson(Map<String, dynamic> j) => VersaoApp(
        (j['versao_codigo'] as num).toInt(),
        j['versao_nome'] as String,
        j['url'] as String,
        (j['notas'] as String?) ?? '',
        j['obrigatoria'] == true,
      );
}

/// Verifica no Supabase (tabela versoes_app) se existe versão mais nova do app.
/// Usa HTTP puro para funcionar também em segundo plano (sem login).
class Atualizacao {
  static String get _base => supabaseUrl.replaceFirst(RegExp(r'/+(rest/v1/?)?$'), '');

  static Future<VersaoApp?> ultimaPublicada() async {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) return null;
    try {
      final r = await http.get(
        Uri.parse('$_base/rest/v1/versoes_app?select=*&order=versao_codigo.desc&limit=1'),
        headers: {
          'apikey': supabaseAnonKey,
          // chaves antigas (JWT) também vão no Authorization; as novas (sb_...) não
          if (!supabaseAnonKey.startsWith('sb_')) 'Authorization': 'Bearer $supabaseAnonKey',
        },
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final lista = jsonDecode(r.body) as List;
      if (lista.isEmpty) return null;
      return VersaoApp.deJson(lista.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<PackageInfo?> _info() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return null;
    }
  }

  static Future<int> codigoAtual() async => int.tryParse((await _info())?.buildNumber ?? '') ?? 0;

  static Future<String> nomeAtual() async => (await _info())?.version ?? '?';

  /// Retorna a nova versão, ou null se o app já está atualizado.
  static Future<VersaoApp?> verificar() async {
    final ultima = await ultimaPublicada();
    if (ultima == null) return null;
    final atual = await codigoAtual();
    return ultima.codigo > atual ? ultima : null;
  }

  static Future<void> baixar(VersaoApp v) =>
      launchUrl(Uri.parse(v.url), mode: LaunchMode.externalApplication);

  static Future<void> mostrarDialogo(BuildContext context, VersaoApp v) {
    return showDialog(
      context: context,
      barrierDismissible: !v.obrigatoria,
      builder: (ctx) => PopScope(
        canPop: !v.obrigatoria,
        child: AlertDialog(
          title: const Text('🚀 Nova versão disponível'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fica Sóbrio ${v.nome}', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (v.notas.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(v.notas.trim(), maxLines: 8, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 12),
              const Text(
                'Toque em Atualizar, baixe o arquivo e abra para instalar por cima. '
                'Seus dados ficam salvos na sua conta.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          actions: [
            if (!v.obrigatoria)
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Depois')),
            FilledButton.icon(
              onPressed: () => baixar(v),
              icon: const Icon(Icons.system_update),
              label: const Text('Atualizar'),
            ),
          ],
        ),
      ),
    );
  }
}
