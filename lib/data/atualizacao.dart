import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import 'instalador.dart';

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

  /// Plano B: baixar pelo navegador (usado se o download interno falhar).
  static Future<void> baixarNoNavegador(VersaoApp v) =>
      launchUrl(Uri.parse(v.url), mode: LaunchMode.externalApplication);

  static Future<void> mostrarDialogo(BuildContext context, VersaoApp v) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoAtualizacao(v),
    );
  }
}

enum _Etapa { novidades, baixando, permissao, instalando, erro }

class _DialogoAtualizacao extends StatefulWidget {
  final VersaoApp v;
  const _DialogoAtualizacao(this.v);

  @override
  State<_DialogoAtualizacao> createState() => _DialogoAtualizacaoState();
}

class _DialogoAtualizacaoState extends State<_DialogoAtualizacao> with WidgetsBindingObserver {
  _Etapa _etapa = _Etapa.novidades;
  double _progresso = 0;
  String _erro = '';
  File? _apk;

  VersaoApp get v => widget.v;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Voltou da tela de permissão do Android: tenta instalar de novo sozinho.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _etapa == _Etapa.permissao && _apk != null) {
      // só segue se a pessoa autorizou (senão a tela de permissão abriria sem parar)
      Instalador.podeInstalar().then((ok) {
        if (ok && mounted) _instalar();
      });
    }
  }

  Future<void> _atualizar() async {
    if (!Instalador.suportado) {
      await Atualizacao.baixarNoNavegador(v);
      return;
    }
    try {
      _apk = await Instalador.jaBaixado(v.codigo);
      if (_apk == null) {
        setState(() {
          _etapa = _Etapa.baixando;
          _progresso = 0;
        });
        _apk = await Instalador.baixar(v.url, v.codigo, (p) {
          if (mounted) setState(() => _progresso = p);
        });
      }
      await _instalar();
    } catch (e) {
      if (mounted) {
        setState(() {
          _etapa = _Etapa.erro;
          _erro = '$e';
        });
      }
    }
  }

  Future<void> _instalar() async {
    try {
      final r = await Instalador.instalar(_apk!);
      if (!mounted) return;
      setState(() => _etapa =
          r == ResultadoInstalacao.precisaPermissao ? _Etapa.permissao : _Etapa.instalando);
    } catch (e) {
      if (mounted) {
        setState(() {
          _etapa = _Etapa.erro;
          _erro = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final podeFechar = !v.obrigatoria && _etapa != _Etapa.baixando;
    return PopScope(
      canPop: podeFechar,
      child: AlertDialog(
        title: Text(switch (_etapa) {
          _Etapa.novidades => '🚀 Nova versão disponível',
          _Etapa.baixando => '⬇️ Baixando atualização',
          _Etapa.permissao => '🔓 Falta uma permissão',
          _Etapa.instalando => '📲 Quase lá!',
          _Etapa.erro => '⚠️ Não deu certo',
        }),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: switch (_etapa) {
            _Etapa.novidades => [
                Text('Fica Sóbrio ${v.nome}', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (v.notas.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(v.notas.trim(), maxLines: 8, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 12),
                const Text(
                  'A atualização é baixada e instalada aqui mesmo, por cima do app. '
                  'Seus dados ficam salvos na sua conta.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            _Etapa.baixando => [
                LinearProgressIndicator(value: _progresso > 0 ? _progresso : null, minHeight: 10),
                const SizedBox(height: 10),
                Text('${(_progresso * 100).round()}%  ·  não feche o app'),
              ],
            _Etapa.permissao => [
                const Text(
                  'O Android pediu sua autorização. Na tela que abriu, ative '
                  '"Permitir desta fonte" para o Fica Sóbrio e volte aqui: '
                  'a instalação continua sozinha.',
                ),
              ],
            _Etapa.instalando => [
                const Text(
                  'Toque em "Atualizar" (ou "Instalar") na janela do Android. '
                  'O app reabre já na versão nova. 💚',
                ),
              ],
            _Etapa.erro => [
                const Text('A atualização não foi baixada. Verifique a internet e tente de novo.'),
                const SizedBox(height: 8),
                Text(_erro, style: const TextStyle(color: Colors.white38, fontSize: 12), maxLines: 3),
              ],
          },
        ),
        actions: [
          if (podeFechar)
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Depois')),
          ...switch (_etapa) {
            _Etapa.novidades => [
                FilledButton.icon(
                  onPressed: _atualizar,
                  icon: const Icon(Icons.system_update),
                  label: const Text('Atualizar agora'),
                ),
              ],
            _Etapa.baixando => <Widget>[],
            _Etapa.permissao || _Etapa.instalando => [
                FilledButton(onPressed: _instalar, child: const Text('Instalar')),
              ],
            _Etapa.erro => [
                TextButton(
                  onPressed: () => Atualizacao.baixarNoNavegador(v),
                  child: const Text('Pelo navegador'),
                ),
                FilledButton(onPressed: _atualizar, child: const Text('Tentar de novo')),
              ],
          },
        ],
      ),
    );
  }
}
