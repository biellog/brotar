import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Música de fundo. Toca qualquer arquivo de áudio colocado em assets/musica/.
/// Sem arquivos, simplesmente fica em silêncio.
class Musica {
  static final _player = AudioPlayer();
  static final mudo = ValueNotifier<bool>(false);
  static List<String>? _faixas;
  static bool _tocando = false;
  static final _rnd = Random();

  static Future<void> iniciar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      mudo.value = prefs.getBool('musica_mudo') ?? false;
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(0.45);
    } catch (e) {
      debugPrint('Música indisponível: $e');
    }
  }

  static Future<List<String>> _listar() async {
    if (_faixas != null) return _faixas!;
    try {
      final manifesto = await AssetManifest.loadFromAssetBundle(rootBundle);
      _faixas = manifesto
          .listAssets()
          .where((a) => a.startsWith('assets/musica/'))
          .where((a) => RegExp(r'\.(mp3|ogg|m4a|wav|aac)$', caseSensitive: false).hasMatch(a))
          .toList()
        ..sort();
    } catch (_) {
      _faixas = [];
    }
    return _faixas!;
  }

  static bool get temMusica => (_faixas ?? []).isNotEmpty;

  /// Começa a tocar (uma faixa sorteada, em loop).
  static Future<void> tocar() async {
    if (mudo.value || _tocando) return;
    final faixas = await _listar();
    if (faixas.isEmpty) return;
    try {
      final f = faixas[_rnd.nextInt(faixas.length)];
      _tocando = true;
      await _player.play(AssetSource(f.replaceFirst('assets/', '')));
    } catch (e) {
      _tocando = false;
      debugPrint('Falha ao tocar música: $e');
    }
  }

  static Future<void> parar() async {
    _tocando = false;
    try {
      await _player.stop();
    } catch (_) {}
  }

  static Future<void> alternarMudo() async {
    mudo.value = !mudo.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('musica_mudo', mudo.value);
    } catch (_) {}
    if (mudo.value) {
      await parar();
    } else {
      await tocar();
    }
  }
}
