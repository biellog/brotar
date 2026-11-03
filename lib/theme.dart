import 'package:flutter/material.dart';

class Cores {
  static const verde = Color(0xFF0B3D2E);
  static const verdeClaro = Color(0xFF1FAF7A);
  static const ouro = Color(0xFFFFC23D);
  static const fundo = Color(0xFF07140F);
  static const card = Color(0xFF10261D);
  static const perigo = Color(0xFFFF5A5F);
}

ThemeData temaApp() {
  final base = ColorScheme.fromSeed(
    seedColor: Cores.verdeClaro,
    brightness: Brightness.dark,
  ).copyWith(
    primary: Cores.verdeClaro,
    secondary: Cores.ouro,
    surface: Cores.fundo,
    error: Cores.perigo,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: base,
    scaffoldBackgroundColor: Cores.fundo,
    cardTheme: const CardThemeData(
      color: Cores.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Cores.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
