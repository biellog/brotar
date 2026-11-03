// Prévia dos jogos no navegador (sem Supabase), usada só para testes visuais.
import 'package:fica_sobrio/data/musica.dart';
import 'package:fica_sobrio/games/bolhas.dart';
import 'package:fica_sobrio/games/comum.dart';
import 'package:fica_sobrio/games/memoria.dart';
import 'package:fica_sobrio/games/tempestade.dart';
import 'package:fica_sobrio/screens/jogos_tab.dart';
import 'package:fica_sobrio/theme.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Musica.iniciar();
  Musica.tocar();
  final tela = Uri.base.queryParameters['tela'] ?? 'lista';
  final Widget home = switch (tela) {
    'tempestade' => const TempestadeScreen(),
    'bolhas' => const BolhasScreen(),
    'memoria' => const MemoriaScreen(),
    'som' => Scaffold(body: Builder(builder: (c) {
        WidgetsBinding.instance.addPostFrameCallback((_) => abrirConfigSom(c));
        return const SizedBox.expand();
      })),
    _ => const Scaffold(body: SafeArea(child: JogoTab())),
  };
  runApp(MaterialApp(debugShowCheckedModeBanner: false, theme: temaApp(), home: home));
}
