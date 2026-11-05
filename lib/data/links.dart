import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Links que abrem o app (vindos do site ou do WhatsApp):
///   ficasobrio://brilha?sala=K7Q2P  → entra na sala do Brilha Junto
///   ficasobrio://convite?c=K7Q2ZP   → usa o código de convite (+100 XP)
///   ficasobrio://suco?c=K7Q2PMNX    → entra no Império do Suco em grupo
class LinksApp {
  static final salaPendente = ValueNotifier<String?>(null);
  static final convitePendente = ValueNotifier<String?>(null);
  static final imperioPendente = ValueNotifier<String?>(null);
  static bool _iniciado = false;

  static Future<void> iniciar() async {
    if (_iniciado || kIsWeb) return;
    _iniciado = true;
    try {
      final links = AppLinks();
      tratar(await links.getInitialLink());
      links.uriLinkStream.listen(tratar, onError: (_) {});
    } catch (e) {
      debugPrint('Links indisponíveis: $e');
    }
  }

  static final _codigo = RegExp(r'^[A-Z0-9]{4,12}$');

  /// Valida e guarda o link (o que vem de fora nunca é confiável).
  static void tratar(Uri? u) {
    if (u == null || u.scheme != 'ficasobrio') return;
    switch (u.host) {
      case 'brilha':
        final s = (u.queryParameters['sala'] ?? '').trim().toUpperCase();
        if (s == 'GERAL' || _codigo.hasMatch(s)) salaPendente.value = s == 'GERAL' ? 'geral' : s;
      case 'convite':
        final c = (u.queryParameters['c'] ?? '').trim().toUpperCase();
        if (_codigo.hasMatch(c)) convitePendente.value = c;
      case 'suco':
        final c = (u.queryParameters['c'] ?? '').trim().toUpperCase();
        if (RegExp(r'^[A-Z2-9]{8}$').hasMatch(c)) imperioPendente.value = c;
    }
  }
}
