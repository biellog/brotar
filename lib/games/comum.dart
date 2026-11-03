import 'dart:math';

import 'package:flutter/material.dart';

import '../data/musica.dart';
import '../data/repo.dart';
import '../theme.dart';
import '../widgets/compartilhar.dart';

/// Botão de ligar/desligar a música (aparece em todos os jogos e no SOS).
class BotaoMusica extends StatelessWidget {
  const BotaoMusica({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: Musica.mudo,
        builder: (_, mudo, _) => IconButton(
          tooltip: mudo ? 'Ligar música' : 'Desligar música',
          icon: Icon(mudo ? Icons.music_off : Icons.music_note),
          onPressed: Musica.alternarMudo,
        ),
      );
}

/// Salva a partida, dá XP e mostra o resultado.
/// Retorna true se a pessoa quer jogar de novo.
Future<bool> finalizarPartida(
  BuildContext context, {
  required String jogo,
  required String nomeJogo,
  required int pontos,
  required int duracaoSeg,
  String? mensagemExtra,
}) async {
  var recordeAnterior = 0;
  var xp = 0;
  String? codigo;
  try {
    recordeAnterior = await Repo.recorde(jogo);
    await Repo.salvarPartida(jogo, pontos, duracaoSeg);
    xp = min(pontos ~/ 10, 300);
    if (xp > 0 && Repo.uid != null) await Repo.somarXp(xp);
    codigo = (await Repo.perfil())?['codigo_convite'];
  } catch (_) {}
  if (!context.mounted) return false;
  final novoRecorde = pontos > recordeAnterior && recordeAnterior > 0;
  final denovo = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(novoRecorde ? '🏆 Novo recorde!' : 'Fim de jogo', textAlign: TextAlign.center),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$pontos', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900)),
        const Text('pontos'),
        const SizedBox(height: 8),
        Text('+$xp XP', style: const TextStyle(color: Cores.ouro, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          mensagemExtra ?? 'Foram $duracaoSeg segundos focado em outra coisa. Isso também é vitória. 💚',
          textAlign: TextAlign.center,
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => compartilhar(
            'Fiz $pontos pontos no $nomeJogo do Fica Sóbrio! Consegue me passar? 😎',
            codigoConvite: codigo,
            origem: 'jogo_$jogo',
          ),
          child: const Text('Desafiar amigos'),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Sair')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('De novo')),
      ],
    ),
  );
  return denovo == true;
}

/// Cache simples de emojis desenhados no Canvas.
class PintorEmoji {
  final _cache = <String, TextPainter>{};

  TextPainter emoji(String e, double tamanho) => _cache.putIfAbsent(
        '$e@${tamanho.round()}',
        () => TextPainter(
          text: TextSpan(text: e, style: TextStyle(fontSize: tamanho)),
          textDirection: TextDirection.ltr,
        )..layout(),
      );

  void desenhar(Canvas c, String e, double tamanho, Offset centro) {
    final tp = emoji(e, tamanho);
    tp.paint(c, centro - Offset(tp.width / 2, tp.height / 2));
  }
}

/// Fundo com pontinhos que descem (sensação de movimento).
void desenharCeu(Canvas canvas, Size s, double tempo) {
  final p = Paint()..color = Colors.white10;
  for (var i = 0; i < 40; i++) {
    final x = (i * 97 % 100) / 100 * s.width;
    final y = ((i * 53 % 100) / 100 * s.height + tempo * 40 * (1 + i % 3)) % s.height;
    canvas.drawCircle(Offset(x, y), 1.5 + i % 2, p);
  }
}
