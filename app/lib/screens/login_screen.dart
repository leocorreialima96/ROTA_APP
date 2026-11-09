import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/services.dart';
import '../widgets/common.dart';

/// Tela 1: Entrar.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) showMessage(context, AuthService.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<Services>().auth;
    final showApple = kIsWeb || defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Align(alignment: Alignment.centerLeft, child: RotaLogo(showSlogan: true)),
                    const SizedBox(height: 18),
                    const _Hero(),
                    const SizedBox(height: 18),
                    Text('Menos tempo com planilha. Mais tempo no seu dia.', style: display(27)),
                    const SizedBox(height: 10),
                    const Text(
                      'Fotografe a nota na hora e receba o relatório pronto, com os comprovantes, no fim do período.',
                      style: TextStyle(fontSize: 16, height: 1.5, color: RotaColors.muted),
                    ),
                    const SizedBox(height: 24),
                    if (showApple) ...[
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: RotaColors.ink, foregroundColor: Colors.white),
                        onPressed: _busy ? null : () => _run(auth.signInWithApple),
                        child: const Text('Continuar com Apple'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                      onPressed: _busy ? null : () => _run(auth.signInWithGoogle),
                      child: const Text('Continuar com Google'),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _busy ? null : () => _emailSheet(context),
                      child: const Text('Entrar com e-mail'),
                    ),
                    const SizedBox(height: 8),
                    _CompanyButton(onTap: () => _companySoon(context)),
                    if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _companySoon(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Acesso da empresa'),
        content: const Text(
          'A ativação da empresa com o código recebido por e-mail chega numa próxima versão. '
          'Por enquanto, a Rota funciona no modo individual: você lança as despesas e gera o relatório com os comprovantes.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi'))],
      ),
    );
  }

  void _emailSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RotaColors.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Provider<Services>.value(value: context.read<Services>(), child: const _EmailSheet()),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(color: RotaColors.ink, borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(right: 22, top: 18, child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: Color(0xFFF2C14E), shape: BoxShape.circle))),
        Positioned(
          left: 34,
          top: 44,
          child: Transform.rotate(angle: -0.2, child: _note(const Color(0xFFF5F2EC), 64, 88)),
        ),
        Positioned(
          left: 70,
          top: 88,
          child: Transform.rotate(angle: 0.14, child: _note(const Color(0xFFE9E4DC), 58, 80)),
        ),
        const Positioned(left: 150, top: 92, child: Icon(Icons.arrow_forward_rounded, color: RotaColors.link, size: 34)),
        Positioned(
          right: 44,
          top: 34,
          child: Container(
            width: 86,
            height: 140,
            decoration: BoxDecoration(color: RotaColors.navy2, borderRadius: BorderRadius.circular(18), border: Border.all(color: RotaColors.navy3, width: 2)),
            padding: const EdgeInsets.fromLTRB(9, 18, 9, 18),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.all(7),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 7, color: RotaColors.sun),
                const SizedBox(height: 8),
                for (var i = 0; i < 4; i++) ...[Container(height: 3, color: const Color(0xFFDCD5C6)), const SizedBox(height: 6)],
                const Spacer(),
                const Align(alignment: Alignment.bottomRight, child: Icon(Icons.check_circle, color: RotaColors.ok, size: 18)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _note(Color c, double w, double h) => Container(
        width: w,
        height: h,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < 3; i++) ...[Container(height: 3, color: const Color(0xFFB3AA98)), const SizedBox(height: 7)],
          const Spacer(),
          Container(height: 8, color: const Color(0xFFF2D36B)),
        ]),
      );
}

class _CompanyButton extends StatelessWidget {
  const _CompanyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: RotaColors.sunSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: RotaColors.ink, width: 1.5)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Icon(Icons.apartment_outlined, color: RotaColors.link),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sou empresa', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('Ativar minha empresa com o código recebido por e-mail', style: TextStyle(fontSize: 12, color: RotaColors.muted)),
                ]),
              ),
              Icon(Icons.chevron_right, color: RotaColors.link),
            ]),
          ),
        ),
      );
}

class _EmailSheet extends StatefulWidget {
  const _EmailSheet();

  @override
  State<_EmailSheet> createState() => _EmailSheetState();
}

class _EmailSheetState extends State<_EmailSheet> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _create = false;
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<Services>().auth;
    setState(() => _busy = true);
    try {
      if (_create) {
        await auth.createWithEmail(_email.text, _pass.text);
      } else {
        await auth.signInWithEmail(_email.text, _pass.text);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, AuthService.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_email.text.contains('@')) {
      showMessage(context, 'Digite seu e-mail para receber o link.');
      return;
    }
    try {
      await context.read<Services>().auth.resetPassword(_email.text);
      if (mounted) showMessage(context, 'Enviamos um link para redefinir a senha.');
    } catch (e) {
      if (mounted) showMessage(context, AuthService.message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_create ? 'Criar conta com e-mail' : 'Entrar com e-mail', style: display(22)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'E-mail'),
            validator: (v) => (v ?? '').contains('@') ? null : 'Informe um e-mail válido.',
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _pass,
            obscureText: _hide,
            autofillHints: [_create ? AutofillHints.newPassword : AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Senha',
              suffixIcon: IconButton(
                tooltip: _hide ? 'Mostrar senha' : 'Esconder senha',
                icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
            validator: (v) => (v ?? '').length >= 6 ? null : 'Mínimo de 6 caracteres.',
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_create ? 'Criar conta' : 'Entrar')),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            TextButton(
              onPressed: () => setState(() => _create = !_create),
              child: Text(_create ? 'Já tenho conta' : 'Criar conta'),
            ),
            if (!_create) TextButton(onPressed: _reset, child: const Text('Esqueci a senha')),
          ]),
        ]),
      ),
    );
  }
}
