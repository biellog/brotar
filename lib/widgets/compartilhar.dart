import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../data/repo.dart';

/// Trecho do convite: o código fica SOZINHO numa linha (fácil de copiar no WhatsApp)
/// e o link abre uma página com o botão "Copiar código" (ou o app, se instalado).
String blocoConvite(String? codigo) {
  if (codigo == null || codigo.isEmpty) return '';
  return '\n\n🎁 Ganhe +100 XP com meu código de convite:\n'
      '$codigo\n'
      '(toque para copiar: ${linkConvite(codigo)})';
}

/// Compartilhamento viral: todo texto leva o nome do app, o código de convite e o link.
Future<void> compartilhar(String mensagem, {String? codigoConvite, String origem = ''}) async {
  final texto = '$mensagem\n\n#FicaSobrio — $appSlogan${blocoConvite(codigoConvite)}\n\nBaixe grátis: $linkDownload';
  await Repo.log('compartilhou', {'origem': origem});
  await Share.share(texto, subject: appNome);
}
