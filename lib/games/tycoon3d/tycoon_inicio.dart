import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repo.dart';
import 'rede_suco.dart';
import 'tycoon3d_screen.dart';

const _ouro = Color(0xFFFFC23D);

/// Tela de entrada do Império do Suco: jogar sozinho (com ajudantes) ou em grupo (mesmo progresso).
class TycoonInicio extends StatefulWidget {
  const TycoonInicio({super.key});

  @override
  State<TycoonInicio> createState() => _TycoonInicioState();
}

class _TycoonInicioState extends State<TycoonInicio> {
  final _codigo = TextEditingController();
  List<ImperioInfo> _meus = const [];
  bool _carregando = true, _criando = false;

  @override
  void initState() {
    super.initState();
    _carregarLista();
  }

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _carregarLista() async {
    final lista = <String, ImperioInfo>{};
    try {
      final p = await SharedPreferences.getInstance();
      for (final e in p.getStringList('suco_grupos') ?? const <String>[]) {
        final partes = e.split('|');
        final c = codigoImperio(partes.first);
        if (c != null) lista[c] = ImperioInfo(c, partes.length > 1 ? partes.sublist(1).join('|') : 'Império', 0);
      }
    } catch (_) {}
    try {
      for (final i in await RedeSuco.meus()) {
        lista[i.codigo] = i;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _meus = lista.values.toList();
        _carregando = false;
      });
    }
  }

  Future<void> _abrir(Widget tela) async {
    await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => tela));
    _carregarLista();
  }

  void _entrarComCodigo() {
    final c = codigoImperio(_codigo.text);
    if (c == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('O código do império tem 8 letras/números (ex.: K7Q2PMNX).')));
      return;
    }
    Repo.log('tycoon_grupo', {'acao': 'entrar_codigo'});
    _abrir(Tycoon3dScreen(codigoGrupo: c));
  }

  Future<void> _criar() async {
    final nome = TextEditingController(text: 'Sucos da Galera');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('👥 Novo império em grupo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nome,
              maxLength: 30,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome do império'),
            ),
            const Text(
              'Todo mundo que entrar com o código joga no MESMO império: o dinheiro, as barracas e as '
              'missões são do grupo. Em grupo não tem ajudante.',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _criando = true);
    try {
      final c = await RedeSuco.criar(nome.text.trim().isEmpty ? 'Império' : nome.text.trim());
      Repo.log('tycoon_grupo', {'acao': 'criar'});
      if (mounted) _abrir(Tycoon3dScreen(codigoGrupo: c));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Não deu para criar agora. Confira a internet e tente de novo.')));
      }
    } finally {
      if (mounted) setState(() => _criando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2A44),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('🧃 Império do Suco 3D', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _Cartao(
            cor: const Color(0xFFFF9F1C),
            emoji: '🧃',
            titulo: 'Jogar sozinho',
            texto: 'Seu império só seu, com ajudantes que vendem até com o app fechado.',
            botao: 'Jogar',
            aoTocar: () => _abrir(const Tycoon3dScreen()),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF3A86FF), Color(0xFF7B2FF7)]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '👥 Império em grupo',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Jogue com amigos no MESMO império, ao vivo. O progresso fica salvo para todos. '
                  'Sem ajudantes: quem trabalha é a galera!',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _ouro, foregroundColor: Colors.black),
                  onPressed: _criando ? null : _criar,
                  icon: _criando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add),
                  label: const Text('Criar império em grupo', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codigo,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 8,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 3),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'CÓDIGO',
                          hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 3),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => _entrarComCodigo(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(96, 52), backgroundColor: const Color(0xFF1FAF7A)),
                      onPressed: _entrarComCodigo,
                      child: const Text('Entrar', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                if (_carregando)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  )
                else if (_meus.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Meus impérios em grupo',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  for (final i in _meus)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  i.nome,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  '${i.codigo}${i.membros > 0 ? ' · ${i.membros} ${i.membros == 1 ? 'pessoa' : 'pessoas'}' : ''}',
                                  style: const TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 1),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(88, 42),
                              backgroundColor: _ouro,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () => _abrir(Tycoon3dScreen(codigoGrupo: i.codigo)),
                            child: const Text('Jogar', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cartao extends StatelessWidget {
  final Color cor;
  final String emoji, titulo, texto, botao;
  final VoidCallback aoTocar;
  const _Cartao({
    required this.cor,
    required this.emoji,
    required this.titulo,
    required this.texto,
    required this.botao,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [cor, Color.lerp(cor, Colors.red, 0.35)!]),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 44)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              Text(texto, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(88, 46),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          onPressed: aoTocar,
          child: Text(botao, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    ),
  );
}
