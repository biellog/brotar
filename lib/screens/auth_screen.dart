import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../data/repo.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _criarConta = true;
  bool _carregando = false;
  bool _consentiu = false;
  bool _verSenha = false;
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  String _traduz(Object e) {
    final m = e is AuthException ? e.message.toLowerCase() : e.toString().toLowerCase();
    if (m.contains('invalid login')) return 'E-mail ou senha incorretos.';
    if (m.contains('already registered')) return 'Este e-mail já tem conta. Toque em "Entrar".';
    if (m.contains('email not confirmed')) return 'Confirme seu e-mail (veja a caixa de entrada).';
    if (m.contains('password')) return 'A senha precisa ter pelo menos 6 caracteres.';
    if (m.contains('socket') || m.contains('network')) return 'Sem internet. Tente de novo.';
    return 'Algo deu errado: ${e is AuthException ? e.message : e}';
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    if (_criarConta && !_consentiu) {
      _msg('Para continuar, aceite o termo de privacidade.');
      return;
    }
    setState(() => _carregando = true);
    try {
      if (_criarConta) {
        final entrou = await Repo.cadastrar(_nome.text, _email.text, _senha.text);
        if (!entrou && mounted) {
          _msg('Conta criada! Confirme pelo link enviado ao seu e-mail e depois entre.');
          setState(() => _criarConta = false);
        }
      } else {
        await Repo.entrar(_email.text, _senha.text);
      }
    } catch (e) {
      _msg(_traduz(e));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _esqueci() async {
    if (!_email.text.contains('@')) {
      _msg('Digite seu e-mail acima primeiro.');
      return;
    }
    try {
      await Repo.recuperarSenha(_email.text);
      _msg('Enviamos um link para redefinir sua senha.');
    } catch (e) {
      _msg(_traduz(e));
    }
  }

  void _verPrivacidade() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Privacidade (LGPD)'),
        content: const SingleChildScrollView(
          child: Text(
            'O $appNome guarda, na sua conta protegida:\n\n'
            '• seu nome e e-mail;\n'
            '• data de início da sobriedade, motivo e gasto diário;\n'
            '• check-ins de humor e fissura, momentos de SOS e recaídas;\n'
            '• partidas do jogo, XP e conquistas;\n'
            '• um histórico das ações feitas no app (telas, botões) e '
            'dados técnicos do aparelho (marca, modelo, versão do Android).\n\n'
            'Esses são dados de saúde (dados sensíveis). Só você tem acesso a eles, '
            'eles não são vendidos nem compartilhados, e você pode excluir tudo '
            'a qualquer momento em Perfil → Excluir minha conta.\n\n'
            'O app NÃO lê outros aplicativos, contatos, mensagens, fotos ou localização.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('🌱', textAlign: TextAlign.center, style: TextStyle(fontSize: 64)),
                    Text(appNome,
                        textAlign: TextAlign.center,
                        style: t.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(appSlogan,
                        textAlign: TextAlign.center,
                        style: t.titleMedium?.copyWith(color: Cores.ouro)),
                    const SizedBox(height: 8),
                    Text(
                      'Conte seus dias, suba de nível, vença a fissura jogando.',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 28),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Criar conta')),
                        ButtonSegment(value: false, label: Text('Entrar')),
                      ],
                      selected: {_criarConta},
                      onSelectionChanged: (s) => setState(() => _criarConta = s.first),
                    ),
                    const SizedBox(height: 20),
                    if (_criarConta) ...[
                      TextFormField(
                        controller: _nome,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Como quer ser chamado?',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Digite um nome ou apelido' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _senha,
                      obscureText: !_verSenha,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_verSenha ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _verSenha = !_verSenha),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Mínimo de 6 caracteres' : null,
                    ),
                    if (_criarConta)
                      CheckboxListTile(
                        value: _consentiu,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) => setState(() => _consentiu = v ?? false),
                        title: Text.rich(
                          TextSpan(
                            text: 'Concordo com o uso dos meus dados conforme o ',
                            children: [
                              TextSpan(
                                text: 'termo de privacidade',
                                style: const TextStyle(
                                  color: Cores.ouro,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()..onTap = _verPrivacidade,
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                          style: t.bodySmall,
                        ),
                      )
                    else
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _esqueci,
                          child: const Text('Esqueci minha senha'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _carregando ? null : _enviar,
                      child: _carregando
                          ? const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_criarConta ? 'Começar minha jornada' : 'Entrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
