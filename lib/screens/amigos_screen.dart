import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../data/amigos.dart';
import '../data/repo.dart';
import '../games/brilha/brilha_screen.dart';
import '../games/tycoon3d/rede_suco.dart';
import '../games/tycoon3d/tycoon3d_screen.dart';
import '../theme.dart';

const _online = Color(0xFF3DDC84);

/// 👥 Painel de amigos: adicionar pelo código, aceitar pedidos, ver quem está online e chamar para jogar.
class AmigosScreen extends StatefulWidget {
  const AmigosScreen({super.key});

  @override
  State<AmigosScreen> createState() => _AmigosScreenState();
}

class _AmigosScreenState extends State<AmigosScreen> {
  final _codigo = TextEditingController();
  String _meuCodigo = '';
  bool _carregando = true, _enviando = false;

  @override
  void initState() {
    super.initState();
    Repo.log('tela', {'nome': 'amigos'});
    _carregar();
  }

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final p = await Repo.perfil();
      _meuCodigo = (p?['codigo_convite'] as String?) ?? '';
      await Amigos.carregar();
    } catch (_) {
      _msg('Sem conexão agora. Puxe para baixo para tentar de novo.');
    }
    if (mounted) setState(() => _carregando = false);
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _adicionar() async {
    final c = _codigo.text.trim();
    if (c.isEmpty) return;
    setState(() => _enviando = true);
    final r = await Amigos.pedir(c);
    if (!mounted) return;
    setState(() => _enviando = false);
    if (r == 'enviado' || r == 'aceito') _codigo.clear();
    Repo.log('amigos', {'acao': 'pedir', 'resultado': r});
    _msg(textoPedido(r));
  }

  Future<void> _compartilharCodigo() async {
    Repo.log('compartilhou', {'origem': 'codigo_amigo'});
    try {
      await Share.share(
        '👥 Me adiciona como amigo no Fica Sóbrio para a gente se apoiar e jogar junto!\n\n'
        'Meu código:\n$_meuCodigo\n\n'
        'Baixe grátis: $siteUrl',
        subject: 'Fica Sóbrio',
      );
    } catch (_) {}
  }

  // ---------------- convidar ----------------
  Future<void> _convidar(Amigo a) async {
    if (!Amigos.online.value.contains(a.id)) {
      _msg('${a.nome} não está com o app aberto agora.');
      return;
    }
    final jogo = await showModalBottomSheet<JogoConvite>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Chamar ${a.nome} para jogar', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final j in JogoConvite.values)
            ListTile(
              leading: Text(j.emoji, style: const TextStyle(fontSize: 30)),
              title: Text(j.nome, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(j == JogoConvite.brilha
                  ? 'Uma sala só de vocês, ao vivo'
                  : 'Construir um império juntos (o progresso fica salvo para os dois)'),
              onTap: () => Navigator.pop(ctx, j),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (jogo == null || !mounted) return;
    switch (jogo) {
      case JogoConvite.brilha:
        final sala = gerarCodigoSala();
        if (await _enviar(a, jogo, sala)) {
          _abrir(BrilhaScreen(salaInicial: sala));
        }
      case JogoConvite.suco:
        final imperio = await _escolherImperio(a);
        if (imperio == null || !mounted) return;
        if (await _enviar(a, jogo, imperio.codigo, detalhe: imperio.nome)) {
          _abrir(Tycoon3dScreen(codigoGrupo: imperio.codigo));
        }
    }
  }

  Future<bool> _enviar(Amigo a, JogoConvite jogo, String codigo, {String detalhe = ''}) async {
    final ok = await Amigos.convidar(a, jogo, codigo, detalhe: detalhe);
    Repo.log('amigos', {'acao': 'convidar', 'jogo': jogo.name, 'ok': ok});
    _msg(ok ? '${jogo.emoji} Convite enviado para ${a.nome}! Entrando...' : 'Não deu para enviar o convite agora. Tente de novo.');
    if (ok) HapticFeedback.mediumImpact();
    return ok;
  }

  void _abrir(Widget tela) => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => tela));

  /// Escolhe um dos impérios em grupo (ou cria um novo) para jogar com o amigo.
  Future<ImperioInfo?> _escolherImperio(Amigo a) async {
    List<ImperioInfo> meus = const [];
    try {
      meus = await RedeSuco.meus();
    } catch (_) {}
    if (!mounted) return null;
    final escolha = await showModalBottomSheet<ImperioInfo>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: [
          const Center(child: Text('🧃 Qual império?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          const SizedBox(height: 6),
          ListTile(
            leading: const Icon(Icons.add_circle, color: Cores.ouro, size: 32),
            title: const Text('Criar um império novo', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Só de você e ${a.nome} (dá para chamar mais gente depois)'),
            onTap: () => Navigator.pop(ctx, const ImperioInfo('', '', 0)),
          ),
          for (final i in meus)
            ListTile(
              leading: const Text('👥', style: TextStyle(fontSize: 26)),
              title: Text(i.nome, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${i.codigo} · ${i.membros} ${i.membros == 1 ? 'pessoa' : 'pessoas'}'),
              onTap: () => Navigator.pop(ctx, i),
            ),
        ]),
      ),
    );
    if (escolha == null || escolha.codigo.isNotEmpty) return escolha;
    try {
      final nome = 'Sucos de ${a.nome}';
      return ImperioInfo(await RedeSuco.criar(nome.length > 30 ? nome.substring(0, 30) : nome), nome, 1);
    } catch (_) {
      _msg('Não deu para criar o império agora.');
      return null;
    }
  }

  Future<void> _opcoes(Amigo a) async {
    final online = Amigos.online.value.contains(a.id);
    final acao = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(a.nome, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text('Nível ${a.nivel.numero} · ${a.nivel.titulo}', style: const TextStyle(color: Cores.ouro)),
          const SizedBox(height: 8),
          if (online)
            ListTile(
              leading: const Icon(Icons.sports_esports, color: _online),
              title: const Text('Chamar para jogar'),
              onTap: () => Navigator.pop(ctx, 'convidar'),
            ),
          ListTile(
            leading: const Icon(Icons.person_remove, color: Cores.perigo),
            title: const Text('Desfazer amizade'),
            onTap: () => Navigator.pop(ctx, 'remover'),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    if (acao == 'convidar') _convidar(a);
    if (acao == 'remover') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Desfazer amizade com ${a.nome}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desfazer')),
          ],
        ),
      );
      if (ok == true) {
        await Amigos.remover(a.id);
        _msg('Amizade desfeita.');
      }
    }
  }

  // ---------------- tela ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('👥 Amigos')),
      body: ValueListenableBuilder<List<Amigo>>(
        valueListenable: Amigos.lista,
        builder: (_, lista, _) => ValueListenableBuilder<Set<String>>(
          valueListenable: Amigos.online,
          builder: (_, online, _) {
            final recebidos = lista.where((a) => a.pedidoRecebido).toList();
            final enviados = lista.where((a) => a.pedidoEnviado).toList();
            final amigos = lista.where((a) => a.aceito).toList()
              ..sort((a, b) {
                final oa = online.contains(a.id), ob = online.contains(b.id);
                return oa != ob ? (oa ? -1 : 1) : a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
              });
            final qtdOnline = amigos.where((a) => online.contains(a.id)).length;
            return RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _cartaoCodigo(),
                const SizedBox(height: 16),
                if (recebidos.isNotEmpty) ...[
                  _titulo('📩 Pedidos para você (${recebidos.length})'),
                  for (final a in recebidos) _pedidoRecebido(a),
                  const SizedBox(height: 12),
                ],
                _titulo('💚 Amigos (${amigos.length})${qtdOnline > 0 ? ' · $qtdOnline online' : ''}'),
                if (_carregando)
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                else if (amigos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Ainda sem amigos por aqui. Mande seu código para alguém de confiança ou adicione o código de um amigo. '
                      'Ficar sóbrio acompanhado é mais leve. 💚',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                else
                  for (final a in amigos) _amigo(a, online.contains(a.id)),
                if (enviados.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _titulo('⏳ Esperando aceitar (${enviados.length})'),
                  for (final a in enviados)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text(a.nome.characters.first.toUpperCase())),
                      title: Text(a.nome),
                      trailing: TextButton(onPressed: () => Amigos.remover(a.id), child: const Text('Cancelar')),
                    ),
                ],
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _titulo(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
  );

  Widget _cartaoCodigo() => Card(
    color: Cores.verde,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Seu código de amigo', style: TextStyle(color: Colors.white70)),
        Row(children: [
          Expanded(
            child: SelectableText(_meuCodigo.isEmpty ? '······' : _meuCodigo,
                style: const TextStyle(fontSize: 28, letterSpacing: 6, fontWeight: FontWeight.w900)),
          ),
          IconButton(
            tooltip: 'Copiar',
            icon: const Icon(Icons.copy),
            onPressed: _meuCodigo.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: _meuCodigo));
                    _msg('Código $_meuCodigo copiado!');
                  },
          ),
          IconButton(tooltip: 'Enviar', icon: const Icon(Icons.share), onPressed: _meuCodigo.isEmpty ? null : _compartilharCodigo),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _codigo,
              textCapitalization: TextCapitalization.characters,
              maxLength: 12,
              decoration: const InputDecoration(hintText: 'Código do amigo', counterText: ''),
              onSubmitted: (_) => _adicionar(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 52), backgroundColor: Cores.ouro, foregroundColor: Colors.black),
            onPressed: _enviando ? null : _adicionar,
            child: _enviando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Adicionar', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ]),
      ]),
    ),
  );

  Widget _pedidoRecebido(Amigo a) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(children: [
        _Avatar(a, false),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.nome, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Text('quer ser seu amigo', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        IconButton(
          tooltip: 'Recusar',
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () => Amigos.responder(a.id, false),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(90, 40)),
          onPressed: () async {
            if (await Amigos.responder(a.id, true)) _msg('Você e ${a.nome} agora são amigos! 🎉');
          },
          child: const Text('Aceitar'),
        ),
      ]),
    ),
  );

  Widget _amigo(Amigo a, bool online) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _opcoes(a),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(children: [
          _Avatar(a, online),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.nome, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(
                online ? '● online agora' : 'Nv ${a.nivel.numero} · ${a.nivel.titulo}',
                style: TextStyle(color: online ? _online : Colors.white60, fontSize: 12, fontWeight: online ? FontWeight.w800 : null),
              ),
            ]),
          ),
          if (online)
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(100, 40), backgroundColor: _online, foregroundColor: Colors.black),
              onPressed: () => _convidar(a),
              icon: const Icon(Icons.sports_esports, size: 18),
              label: const Text('Convidar', style: TextStyle(fontWeight: FontWeight.w900)),
            )
          else
            const Icon(Icons.chevron_right, color: Colors.white38),
        ]),
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  final Amigo a;
  final bool online;
  const _Avatar(this.a, this.online);

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
    CircleAvatar(
      radius: 22,
      backgroundColor: Cores.verde,
      child: Text('${a.nivel.numero}', style: const TextStyle(color: Cores.ouro, fontWeight: FontWeight.w900, fontSize: 18)),
    ),
    Positioned(
      right: -1,
      bottom: -1,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: online ? _online : Colors.grey,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
        ),
      ),
    ),
  ]);
}
