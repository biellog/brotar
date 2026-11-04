import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Efeitos sonoros disponíveis (arquivos em assets/sons/).
enum Efeito {
  erro('sons/erro.ogg'), // Desvia da Tempestade: bateu numa tempestade
  carta('sons/carta.ogg'), // Memória Zen: virou uma carta
  bolhaCerta('sons/bolha_certa.ogg'), // Bolhas da Calma: bolha boa
  bolhaErrada('sons/bolha_errada.ogg'), // Bolhas da Calma: nuvem
  plastico('sons/plastico.ogg'), // Plástico Bolha: estourou
  plantar('sons/plantar.ogg'); // Jardim Mágico: plantou

  final String arquivo;
  const Efeito(this.arquivo);
}

/// Música de fundo do app inteiro + efeitos sonoros, com volumes ajustáveis.
///
/// A música é o trecho calmo (assets/musica/), tocando em loop. Ela pausa
/// quando o app vai para segundo plano e volta quando a pessoa retorna.
class Musica {
  static final _player = AudioPlayer(playerId: 'musica');

  /// Música ligada/desligada.
  static final mudo = ValueNotifier<bool>(false);

  /// Volumes de 0 a 1. A música começa baixinha.
  static final volumeMusica = ValueNotifier<double>(0.3);
  static final volumeEfeitos = ValueNotifier<double>(0.8);

  static List<String>? _faixas;
  static bool _tocando = false;
  static bool _emSegundoPlano = false;

  // 3 "vozes" por efeito para sons rápidos em sequência não se cortarem
  static final _vozes = <Efeito, List<AudioPlayer>>{};
  static final _proxima = <Efeito, int>{};

  static Future<void> iniciar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      mudo.value = prefs.getBool('musica_mudo') ?? false;
      volumeMusica.value = prefs.getDouble('volume_musica') ?? 0.3;
      volumeEfeitos.value = prefs.getDouble('volume_efeitos') ?? 0.8;

      // Música e efeitos tocam JUNTOS (um não interrompe o outro)
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(volumeMusica.value);
      // carrega os efeitos sem atrasar a abertura do app
      unawaited(_prepararEfeitos().catchError((Object e) => debugPrint('Efeitos indisponíveis: $e')));
    } catch (e) {
      debugPrint('Som indisponível: $e');
    }
  }

  static Future<void> _prepararEfeitos() async {
    for (final e in Efeito.values) {
      final lista = <AudioPlayer>[];
      for (var i = 0; i < 3; i++) {
        final p = AudioPlayer(playerId: '${e.name}_$i');
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource(e.arquivo));
        lista.add(p);
      }
      _vozes[e] = lista;
      _proxima[e] = 0;
    }
  }

  /// Toca um efeito sonoro (no volume de efeitos escolhido).
  static Future<void> efeito(Efeito e) async {
    final vol = volumeEfeitos.value;
    if (vol <= 0) return;
    final lista = _vozes[e];
    if (lista == null || lista.isEmpty) return;
    final i = _proxima[e]!;
    _proxima[e] = (i + 1) % lista.length;
    try {
      final p = lista[i];
      await p.stop();
      await p.play(AssetSource(e.arquivo), volume: vol, mode: PlayerMode.lowLatency);
    } catch (err) {
      debugPrint('Falha no efeito ${e.name}: $err');
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

  /// Liga a música de fundo (se não estiver desligada nas configurações).
  static Future<void> tocar() async {
    if (mudo.value || _tocando || _emSegundoPlano) return;
    final faixas = await _listar();
    if (faixas.isEmpty) return;
    try {
      _tocando = true;
      await _player.setVolume(volumeMusica.value);
      await _player.play(AssetSource(faixas.first.replaceFirst('assets/', '')));
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

  /// App foi para segundo plano / voltou.
  static Future<void> segundoPlano(bool sim) async {
    _emSegundoPlano = sim;
    try {
      if (sim) {
        if (_tocando) await _player.pause();
      } else if (_tocando) {
        await _player.resume();
      } else {
        await tocar();
      }
    } catch (_) {}
  }

  static Future<void> alternarMudo() => definirMudo(!mudo.value);

  static Future<void> definirMudo(bool valor) async {
    mudo.value = valor;
    await _salvar('musica_mudo', valor);
    if (valor) {
      await parar();
    } else {
      await tocar();
    }
  }

  static Future<void> definirVolumeMusica(double v) async {
    volumeMusica.value = v;
    try {
      await _player.setVolume(v);
    } catch (_) {}
  }

  static Future<void> definirVolumeEfeitos(double v) async => volumeEfeitos.value = v;

  /// Grava os volumes (chamado quando a pessoa solta o controle deslizante).
  static Future<void> salvarVolumes() async {
    await _salvar('volume_musica', volumeMusica.value);
    await _salvar('volume_efeitos', volumeEfeitos.value);
  }

  static Future<void> _salvar(String chave, Object valor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (valor is bool) await prefs.setBool(chave, valor);
      if (valor is double) await prefs.setDouble(chave, valor);
    } catch (_) {}
  }
}
