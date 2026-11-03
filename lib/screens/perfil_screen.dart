import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/atualizacao.dart';
import '../data/repo.dart';
import '../games/comum.dart';
import '../logic/progresso.dart';
import '../theme.dart';
import '../widgets/compartilhar.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  Map<String, dynamic>? _p;
  Set<String> _conquistas = {};
  List<Map<String, dynamic>> _checkins = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final r = await Future.wait([Repo.perfil(), Repo.conquistas(), Repo.ultimosCheckins(7)]);
      if (!mounted) return;
      setState(() {
        _p = r[0] as Map<String, dynamic>?;
        _conquistas = r[1] as Set<String>;
        _checkins = r[2] as List<Map<String, dynamic>>;
      });
    } catch (_) {}
  }

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _editarTexto(String campo, String titulo, {bool numero = false}) async {
    final c = TextEditingController(text: '${_p?[campo] ?? ''}');
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: numero ? const TextInputType.numberWithOptions(decimal: true) : null,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Salvar')),
        ],
      ),
    );
    if (v == null) return;
    await Repo.salvarPerfil({
      campo: numero ? (double.tryParse(v.replaceAll(',', '.')) ?? 0) : v.trim(),
    });
    _carregar();
  }

  Future<void> _usarConvite() async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Código de convite'),
        content: TextField(controller: c, textCapitalization: TextCapitalization.characters),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Usar')),
        ],
      ),
    );
    if (v == null || v.trim().isEmpty) return;
    final ok = await Repo.usarConvite(v);
    _msg(ok ? 'Convite aceito! +100 XP 🎉' : 'Código inválido ou já usado.');
    _carregar();
  }

  bool _verificando = false;

  Future<void> _verificarAtualizacao() async {
    setState(() => _verificando = true);
    final nova = await Atualizacao.verificar();
    if (!mounted) return;
    setState(() => _verificando = false);
    Repo.log('verificou_atualizacao', {'tem_nova': nova != null});
    if (nova != null) {
      await Atualizacao.mostrarDialogo(context, nova);
    } else {
      _msg('Você já está na versão mais recente. ✅');
    }
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir minha conta?'),
        content: const Text('Todos os seus dados (dias, check-ins, XP, conquistas e histórico) '
            'serão apagados para sempre. Isso não pode ser desfeito.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Cores.perigo),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir tudo'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await Repo.excluirConta();
      } catch (e) {
        _msg('Erro ao excluir: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    if (p == null) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    final nivel = nivelDe((p['xp'] as num?)?.toInt() ?? 0);
    final codigo = (p['codigo_convite'] ?? '') as String;
    final inicio = DateTime.tryParse(p['data_inicio'] ?? '')?.toLocal();

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Cores.verde,
              child: Text('${nivel.numero}',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Cores.ouro)),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text('${p['nome'] ?? ''}', style: t.headlineSmall)),
          Center(child: Text('${nivel.titulo} · ${nivel.xp} XP', style: const TextStyle(color: Cores.ouro))),
          const SizedBox(height: 16),

          // ---------- Convite (marketing de indicação) ----------
          Card(
            color: Cores.verde,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('🤝 Convide e ganhe 200 XP', style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Seu amigo ganha 100 XP ao entrar com seu código. '
                    'Ficar sóbrio acompanhado é mais fácil.'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: SelectableText(codigo,
                        style: const TextStyle(fontSize: 28, letterSpacing: 6, fontWeight: FontWeight.w900)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: codigo));
                      _msg('Código copiado!');
                    },
                  ),
                ]),
                FilledButton.icon(
                  onPressed: () => compartilhar(
                    'Estou usando o Fica Sóbrio pra me manter firme — é um jogo que conta seus dias sóbrio. Bora comigo?',
                    codigoConvite: codigo,
                    origem: 'convite',
                  ),
                  icon: const Icon(Icons.share),
                  label: const Text('Convidar pelo WhatsApp'),
                ),
                if (p['convidado_por'] == null)
                  TextButton(onPressed: _usarConvite, child: const Text('Tenho um código de convite')),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // ---------- Conquistas ----------
          Text('Conquistas (${_conquistas.length}/${conquistasLista.length})', style: t.titleMedium),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: conquistasLista.map((c) {
              final tem = _conquistas.contains(c.codigo);
              return Tooltip(
                message: '${c.titulo}: ${c.descricao}',
                triggerMode: TooltipTriggerMode.tap,
                child: Container(
                  decoration: BoxDecoration(
                    color: tem ? Cores.verde : Cores.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tem ? Cores.ouro : Colors.transparent),
                  ),
                  child: Center(
                    child: Opacity(
                      opacity: tem ? 1 : 0.25,
                      child: Text(tem ? c.emoji : '🔒', style: const TextStyle(fontSize: 30)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ---------- Últimos check-ins ----------
          if (_checkins.isNotEmpty) ...[
            Text('Últimos check-ins', style: t.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: _checkins.map((c) {
                  const h = ['😣', '😕', '😐', '🙂', '😄'];
                  final humor = ((c['humor'] as num).toInt() - 1).clamp(0, 4);
                  return ListTile(
                    dense: true,
                    leading: Text(h[humor], style: const TextStyle(fontSize: 24)),
                    title: Text('${c['data']}'),
                    subtitle: c['nota'] == null ? null : Text('${c['nota']}', maxLines: 2),
                    trailing: Text('vontade ${c['fissura']}/10'),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ---------- Dados ----------
          Text('Meus dados', style: t.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Nome'),
                subtitle: Text('${p['nome'] ?? ''}'),
                onTap: () => _editarTexto('nome', 'Seu nome'),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Sóbrio desde'),
                subtitle: Text(inicio == null
                    ? '-'
                    : '${inicio.day.toString().padLeft(2, '0')}/${inicio.month.toString().padLeft(2, '0')}/${inicio.year}'),
              ),
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Gasto diário'),
                subtitle: Text(dinheiro((p['gasto_diario'] as num?) ?? 0)),
                onTap: () => _editarTexto('gasto_diario', 'Gasto por dia (R\$)', numero: true),
              ),
              ListTile(
                leading: const Icon(Icons.favorite_outline),
                title: const Text('Meu motivo'),
                subtitle: Text('${p['motivo'] ?? ''}'),
                onTap: () => _editarTexto('motivo', 'Seu maior motivo'),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Maior sequência'),
                subtitle: Text('${p['melhor_sequencia_dias']} dias · ${p['recaidas']} recomeços'),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('Som e música'),
              subtitle: const Text('Ligar/desligar a música e ajustar os volumes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => abrirConfigSom(context),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.system_update),
              title: const Text('Verificar atualizações'),
              subtitle: FutureBuilder<String>(
                future: Atualizacao.nomeAtual(),
                builder: (_, s) => Text('Versão instalada: ${s.data ?? '...'}'),
              ),
              trailing: _verificando
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
              onTap: _verificando ? null : _verificarAtualizacao,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: Repo.sair, icon: const Icon(Icons.logout), label: const Text('Sair')),
          TextButton(
            onPressed: _excluir,
            child: const Text('Excluir minha conta e meus dados', style: TextStyle(color: Cores.perigo)),
          ),
        ],
      ),
    );
  }
}
