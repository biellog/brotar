// Prévia dos jogos no navegador (sem Supabase), usada só para testes visuais.
import 'package:fica_sobrio/games/bolhas.dart';
import 'package:fica_sobrio/games/memoria.dart';
import 'package:fica_sobrio/games/tempestade.dart';
import 'package:fica_sobrio/screens/jogos_tab.dart';
import 'package:fica_sobrio/theme.dart';
import 'package:flutter/material.dart';

void main() {
  final tela = Uri.base.queryParameters['tela'] ?? 'lista';
  final Widget home = switch (tela) {
    'tempestade' => const TempestadeScreen(),
    'bolhas' => const BolhasScreen(),
    'memoria' => const MemoriaScreen(),
    _ => const Scaffold(body: SafeArea(child: JogoTab())),
  };
  runApp(MaterialApp(debugShowCheckedModeBanner: false, theme: temaApp(), home: home));
}
