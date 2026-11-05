// Jogos online para navegador (publicados no site em /jogar/):
//   Brilha Junto:             https://biellog.github.io/fica-sobrio/jogar/?sala=K7Q2P
//   Império do Suco em grupo: https://biellog.github.io/fica-sobrio/jogar/?suco=K7Q2PMNX
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'data/musica.dart';
import 'games/brilha/brilha_screen.dart';
import 'games/brilha/rede.dart';
import 'games/tycoon3d/rede_suco.dart';
import 'games/tycoon3d/tycoon3d_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  }
  await Musica.iniciar();
  final suco = codigoImperio(Uri.base.queryParameters['suco']);
  final sala = salaDoLink(Uri.base);
  runApp(
    MaterialApp(
      title: suco != null ? 'Império do Suco · Fica Sóbrio' : 'Brilha Junto · Fica Sóbrio',
      debugShowCheckedModeBanner: false,
      theme: temaApp(),
      home: suco != null ? SucoWebInicio(codigo: suco) : BrilhaWebInicio(sala: sala),
    ),
  );
}

/// Lê e valida a sala do link (?sala=K7Q2P). Retorna null se não houver ou for inválida.
String? salaDoLink(Uri u) {
  final s = (u.queryParameters['sala'] ?? '').trim().toUpperCase();
  if (s == 'GERAL') return 'geral';
  return codigoValido(s) ? s : null;
}

/// Link que abre o app instalado direto na sala (ou o site, se não tiver o app).
String linkAbrirNoApp(String sala) =>
    'intent://brilha?sala=${Uri.encodeComponent(sala)}'
    '#Intent;scheme=ficasobrio;package=$pacoteAndroid;'
    'S.browser_fallback_url=${Uri.encodeComponent(linkSalaBrilha(sala))}%26semapp%3D1;end';

class BrilhaWebInicio extends StatefulWidget {
  final String? sala;
  const BrilhaWebInicio({super.key, this.sala});

  @override
  State<BrilhaWebInicio> createState() => _BrilhaWebInicioState();
}

class _BrilhaWebInicioState extends State<BrilhaWebInicio> {
  final _apelido = TextEditingController();
  bool get _android => defaultTargetPlatform == TargetPlatform.android;
  bool get _voltouSemApp => Uri.base.queryParameters['semapp'] == '1';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final a = p.getString('brilha_apelido');
      if (a != null && mounted) setState(() => _apelido.text = a);
    });
  }

  Future<void> _jogarAqui() async {
    final nome = limparNome(_apelido.text.isEmpty ? 'Vagalume' : _apelido.text);
    try {
      (await SharedPreferences.getInstance()).setString('brilha_apelido', nome);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BrilhaScreen(web: true, salaInicial: widget.sala, nomeInicial: nome),
      ),
    );
  }

  void _jogarNoApp() => launchUrl(Uri.parse(linkAbrirNoApp(widget.sala ?? 'geral')), webOnlyWindowName: '_self');

  @override
  Widget build(BuildContext context) {
    final sala = widget.sala;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1026), Color(0xFF241A4F)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('🌟', textAlign: TextAlign.center, style: TextStyle(fontSize: 64)),
                    ShaderMask(
                      shaderCallback: (r) =>
                          const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFFFC23D), Color(0xFFFF6FA5)]).createShader(r),
                      child: const Text(
                        'Brilha Junto',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sala == null
                          ? 'O jogo online do Fica Sóbrio. Voe, colete luzes e brilhe junto com gente do Brasil todo!'
                          : sala == 'geral'
                          ? 'Você foi chamado para a Arena Geral!'
                          : 'Você foi chamado para brilhar junto! 💚',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    if (sala != null && sala != 'geral') ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFC23D)),
                        ),
                        child: Text(
                          'Sala $sala',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: Color(0xFFFFC23D),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    if (_android && !_voltouSemApp) ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1FAF7A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _jogarNoApp,
                        icon: const Text('📱', style: TextStyle(fontSize: 20)),
                        label: const Text('Jogar pelo aplicativo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Abre o Fica Sóbrio direto nesta sala (e você ganha XP).',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (_voltouSemApp)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: Text(
                          'Parece que o app não está instalado. Jogue aqui mesmo ou baixe grátis!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFFFC23D)),
                        ),
                      ),
                    TextField(
                      controller: _apelido,
                      maxLength: 16,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Seu apelido no jogo', counterText: ''),
                      onSubmitted: (_) => _jogarAqui(),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC23D),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _jogarAqui,
                      child: const Text(
                        '🌐 Jogar aqui no navegador',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse(siteUrl), webOnlyWindowName: '_self'),
                      child: const Text('⬇️ Baixar o app Fica Sóbrio (grátis): ganhe XP, conquistas e mais jogos'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Link que abre o Império do Suco em grupo no app instalado (ou volta para o site).
String linkImperioNoApp(String codigo) =>
    'intent://suco?c=${Uri.encodeComponent(codigo)}'
    '#Intent;scheme=ficasobrio;package=$pacoteAndroid;'
    'S.browser_fallback_url=${Uri.encodeComponent(linkImperio(codigo))}%26semapp%3D1;end';

/// Página do convite para o Império do Suco em grupo (no navegador).
class SucoWebInicio extends StatefulWidget {
  final String codigo;
  const SucoWebInicio({super.key, required this.codigo});

  @override
  State<SucoWebInicio> createState() => _SucoWebInicioState();
}

class _SucoWebInicioState extends State<SucoWebInicio> {
  final _apelido = TextEditingController();
  bool get _android => defaultTargetPlatform == TargetPlatform.android;
  bool get _voltouSemApp => Uri.base.queryParameters['semapp'] == '1';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final a = p.getString('brilha_apelido');
      if (a != null && mounted) setState(() => _apelido.text = a);
    });
  }

  Future<void> _jogarAqui() async {
    final nome = limparNome(_apelido.text.isEmpty ? 'Amigo' : _apelido.text);
    try {
      (await SharedPreferences.getInstance()).setString('brilha_apelido', nome);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Tycoon3dScreen(codigoGrupo: widget.codigo, web: true, nome: nome),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7EC8F2), Color(0xFF3A86FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('🧃', textAlign: TextAlign.center, style: TextStyle(fontSize: 64)),
                    const Text(
                      'Império do Suco 3D',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Você foi chamado para construir um império de sucos junto com os amigos! 💚',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFC23D)),
                      ),
                      child: Text(
                        'Império ${widget.codigo}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: Color(0xFFFFC23D),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (_android && !_voltouSemApp) ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1FAF7A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => launchUrl(Uri.parse(linkImperioNoApp(widget.codigo)), webOnlyWindowName: '_self'),
                        icon: const Text('📱', style: TextStyle(fontSize: 20)),
                        label: const Text('Jogar pelo aplicativo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Abre o Fica Sóbrio direto neste império (e você ganha XP).',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (_voltouSemApp)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: Text(
                          'Parece que o app não está instalado. Jogue aqui mesmo ou baixe grátis!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFFFE08A)),
                        ),
                      ),
                    TextField(
                      controller: _apelido,
                      maxLength: 16,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Seu apelido no jogo', counterText: ''),
                      onSubmitted: (_) => _jogarAqui(),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC23D),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _jogarAqui,
                      child: const Text(
                        '🌐 Jogar aqui no navegador',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse(siteUrl), webOnlyWindowName: '_self'),
                      child: const Text(
                        '⬇️ Baixar o app Fica Sóbrio (grátis): ganhe XP, conquistas e mais jogos',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
