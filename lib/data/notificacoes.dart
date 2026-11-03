import 'dart:io' show Platform;
import 'dart:ui' show Color, DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'atualizacao.dart';

const _tarefaAtualizacao = 'verificar-atualizacao';

/// Executado pelo Android em segundo plano (mesmo com o app fechado).
@pragma('vm:entry-point')
void tarefaSegundoPlano() {
  Workmanager().executeTask((tarefa, dados) async {
    DartPluginRegistrant.ensureInitialized();
    try {
      final nova = await Atualizacao.verificar();
      if (nova != null) {
        await Notificacoes.iniciar(pedirPermissao: false);
        await Notificacoes.avisarAtualizacao(nova);
      }
    } catch (e) {
      debugPrint('Falha na verificação em segundo plano: $e');
    }
    return true;
  });
}

class Notificacoes {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _iniciado = false;
  static bool get _suportado => !kIsWeb && Platform.isAndroid;

  static const _canal = AndroidNotificationDetails(
    'atualizacoes',
    'Atualizações do app',
    channelDescription: 'Avisa quando há uma versão nova do Fica Sóbrio',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_notificacao',
    color: Color(0xFF1FAF7A),
  );

  static Future<void> iniciar({bool pedirPermissao = true, void Function()? aoTocar}) async {
    if (!_suportado) return;
    try {
      if (!_iniciado) {
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_notificacao'),
          ),
          onDidReceiveNotificationResponse: (_) => aoTocar?.call(),
        );
        _iniciado = true;
      }
      if (pedirPermissao) {
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Notificações indisponíveis: $e');
    }
  }

  /// Agenda a verificação de atualização a cada ~4 horas, mesmo com o app fechado.
  static Future<void> agendarVerificacao() async {
    if (!_suportado) return;
    try {
      await Workmanager().initialize(tarefaSegundoPlano);
      await Workmanager().registerPeriodicTask(
        _tarefaAtualizacao,
        _tarefaAtualizacao,
        frequency: const Duration(hours: 4),
        initialDelay: const Duration(minutes: 30),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('Não foi possível agendar a verificação: $e');
    }
  }

  /// Mostra a notificação de nova versão (uma única vez por versão).
  static Future<void> avisarAtualizacao(VersaoApp v) async {
    if (!_suportado) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getInt('versao_notificada') == v.codigo) return;
      await _plugin.show(
        id: 1001,
        title: '🌱 Nova versão do Fica Sóbrio',
        body: 'A versão ${v.nome} chegou. Toque para atualizar.',
        notificationDetails: const NotificationDetails(android: _canal),
        payload: 'atualizar',
      );
      await prefs.setInt('versao_notificada', v.codigo);
    } catch (e) {
      debugPrint('Falha ao notificar: $e');
    }
  }
}
