// Prévia dos jogos no navegador (sem Supabase), usada só para testes visuais.
import 'package:fica_sobrio/data/musica.dart';
import 'package:fica_sobrio/games/bolhas.dart';
import 'package:fica_sobrio/games/brilha/brilha_screen.dart';
import 'package:fica_sobrio/games/comum.dart';
import 'package:fica_sobrio/games/memoria.dart';
import 'package:fica_sobrio/games/jardim_magico.dart';
import 'package:fica_sobrio/games/relaxantes.dart';
import 'package:fica_sobrio/logic/movimento.dart';
import 'package:fica_sobrio/screens/movimento.dart';
import 'package:fica_sobrio/games/tempestade.dart';
import 'package:fica_sobrio/games/tycoon3d/tycoon3d_screen.dart';
import 'package:fica_sobrio/games/tycoon3d/tycoon_inicio.dart';
import 'package:fica_sobrio/web_brilha.dart' as wb;
import 'package:fica_sobrio/screens/jogos_tab.dart';
import 'package:fica_sobrio/theme.dart';
import 'package:fica_sobrio/widgets/cartao_compartilhar.dart';
import 'package:fica_sobrio/widgets/painel_gastos.dart';
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
    'plastico' => const PlasticoBolhaScreen(),
    'jardim' => const JardimMagicoScreen(),
    'mandala' => const MandalaScreen(),
    'tycoon' => const Tycoon3dScreen(),
    'tycoon_inicio' => const TycoonInicio(),
    'suco_web' => const wb.SucoWebInicio(codigo: 'K7Q2PMNX'),
    'suco_erro' => const Tycoon3dScreen(codigoGrupo: 'K7Q2PMNX'),
    'brilha' => const BrilhaScreen(),
    'cartao' => Scaffold(
        backgroundColor: Colors.white,
        body: GridView.count(crossAxisCount: 2, children: [
          for (final (d, h, e, c) in const [(0, 7, 0.0, null), (1, 3, 25.0, null), (43, 5, 1290.0, null), (400, 1, 12000.0, '🏆')])
            FutureBuilder(
              future: gerarCartaoSobriedade(
                  tempo: Duration(days: d, hours: h), economia: e,
                  conquistaEmoji: c, conquistaTitulo: c == null ? null : 'Noventa Dias', codigoConvite: 'K7Q2ZP'),
              builder: (_, s) => s.hasData ? Image.memory(s.data!) : const SizedBox(),
            ),
        ]),
      ),
    'painel' => Scaffold(body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [PainelGastos(gastoDiario: 25, aoSalvar: (_) async {})]))),
    'aquario' => const AquarioScreen(),
    'movimento' => Scaffold(body: SafeArea(child: MovimentoTab(irParaJogos: () {}))),
    'alongamento' => AtividadeGuiadaScreen(atividade: atividades[2]),
    'treino' => AtividadeGuiadaScreen(atividade: atividades[3]),
    'caminhada' => AtividadePassosScreen(atividade: atividades[0]),
    'som' => Scaffold(body: Builder(builder: (c) {
        WidgetsBinding.instance.addPostFrameCallback((_) => abrirConfigSom(c));
        return const SizedBox.expand();
      })),
    _ => const Scaffold(body: SafeArea(child: JogoTab())),
  };
  runApp(MaterialApp(debugShowCheckedModeBanner: false, theme: temaApp(), home: home));
}
