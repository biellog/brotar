import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/links.dart';
import 'data/musica.dart';
import 'data/repo.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  }
  await Musica.iniciar();
  await LinksApp.iniciar(); // links ficasobrio:// (convites e salas do Brilha Junto)
  runApp(const FicaSobrioApp());
}

class FicaSobrioApp extends StatefulWidget {
  const FicaSobrioApp({super.key});

  @override
  State<FicaSobrioApp> createState() => _FicaSobrioAppState();
}

class _FicaSobrioAppState extends State<FicaSobrioApp> {
  late final AppLifecycleListener _ciclo;

  @override
  void initState() {
    super.initState();
    Musica.tocar(); // música calma em todo o app
    // pausa a música quando o app sai da tela e retoma quando volta
    _ciclo = AppLifecycleListener(
      onHide: () => Musica.segundoPlano(true),
      onShow: () => Musica.segundoPlano(false),
    );
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appNome,
      debugShowCheckedModeBanner: false,
      theme: temaApp(),
      home: supabaseUrl.isEmpty || supabaseAnonKey.isEmpty
          ? const _SemConfiguracao()
          : const PortaoLogin(),
    );
  }
}

/// Mostra login ou o app, conforme a sessão.
class PortaoLogin extends StatelessWidget {
  const PortaoLogin({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        final sessao = auth.currentSession;
        if (sessao == null) return const AuthScreen();
        return PortaoPerfil(key: ValueKey(sessao.user.id));
      },
    );
  }
}

/// Decide entre onboarding e tela inicial.
class PortaoPerfil extends StatefulWidget {
  const PortaoPerfil({super.key});

  @override
  State<PortaoPerfil> createState() => _PortaoPerfilState();
}

class _PortaoPerfilState extends State<PortaoPerfil> {
  late Future<Map<String, dynamic>?> _perfil;

  @override
  void initState() {
    super.initState();
    _perfil = Repo.perfil();
    Repo.log('app_aberto');
  }

  void _recarregar() => setState(() => _perfil = Repo.perfil());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _perfil,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Não foi possível carregar seu perfil.\nVerifique sua internet.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _recarregar, child: const Text('Tentar de novo')),
                  TextButton(onPressed: Repo.sair, child: const Text('Sair')),
                ]),
              ),
            ),
          );
        }
        final p = snap.data;
        if (p == null || p['onboarding_ok'] != true) {
          return OnboardingScreen(perfil: p, aoConcluir: _recarregar);
        }
        return const HomeScreen();
      },
    );
  }
}

class _SemConfiguracao extends StatelessWidget {
  const _SemConfiguracao();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Supabase não configurado.\n\nCadastre os secrets SUPABASE_URL e '
            'SUPABASE_ANON_KEY no GitHub e gere o APK novamente.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
