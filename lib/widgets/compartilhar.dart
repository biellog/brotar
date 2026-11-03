import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../data/repo.dart';

/// Compartilhamento viral: todo texto leva o nome do app, o código de convite e o link.
Future<void> compartilhar(String mensagem, {String? codigoConvite, String origem = ''}) async {
  final convite = (codigoConvite == null || codigoConvite.isEmpty)
      ? ''
      : '\nUse meu código $codigoConvite e ganhe +100 XP.';
  final texto = '$mensagem\n\n#FicaSobrio — $appSlogan$convite\nBaixe grátis: $linkDownload';
  await Repo.log('compartilhou', {'origem': origem});
  await Share.share(texto, subject: appNome);
}
