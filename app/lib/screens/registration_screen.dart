import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/cpf.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../services/profile_repository.dart';
import '../services/services.dart';
import '../widgets/common.dart';
import 'legal_screen.dart';

/// Tela 2: Cadastro. Nome e CPF obrigatórios; o CPF é validado e único.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, required this.user});

  final User user;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: (widget.user.displayName ?? '').toUpperCase());
  final _cpf = TextEditingController();
  late final _email = TextEditingController(text: widget.user.email ?? '');
  final _phone = TextEditingController();
  final _job = TextEditingController();
  final _plate = TextEditingController();
  bool _consent = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cpf.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _cpf, _email, _phone, _job, _plate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_consent) {
      showMessage(context, 'Para continuar, aceite a política de privacidade e os termos de uso.');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<Services>().profiles.completeRegistration(
            name: _name.text.trim(),
            cpf: Cpf.digits(_cpf.text),
            phone: _phone.text.trim(),
            jobTitle: _job.text.trim(),
            plate: _plate.text.trim(),
            email: _email.text.trim(),
          );
    } catch (e) {
      if (mounted) showMessage(context, ProfileRepository.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cpfDigits = Cpf.digits(_cpf.text);
    final cpfOk = cpfDigits.length == 11 && Cpf.isValid(cpfDigits);
    final cpfBad = cpfDigits.length == 11 && !cpfOk;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: () => context.read<Services>().auth.signOut(), child: const Text('Sair')),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
                const StepHeader(
                  step: 1,
                  total: 3,
                  title: 'Seus dados',
                  subtitle: 'Entram no cabeçalho do relatório. Campos com * são obrigatórios.',
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Nome completo (como sai no relatório) *'),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.length < 3 || !t.contains(' ')) return 'Informe nome e sobrenome.';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _cpf,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CpfInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'CPF *',
                    hintText: '000.000.000-00',
                    helperText: cpfOk ? 'CPF válido · não poderá ser alterado depois' : null,
                    helperStyle: const TextStyle(color: RotaColors.okText, fontWeight: FontWeight.w700),
                    errorText: cpfBad ? 'CPF inválido. Confira os números.' : null,
                    enabledBorder: cpfOk
                        ? OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: RotaColors.ok, width: 1.5))
                        : null,
                  ),
                  validator: (v) => Cpf.isValid(v ?? '') ? null : 'CPF inválido.',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  readOnly: (widget.user.email ?? '').isNotEmpty,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail *'),
                  validator: (v) => (v ?? '').contains('@') ? null : 'Informe um e-mail válido.',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Celular', hintText: '(11) 90000-0000'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _job,
                  decoration: const InputDecoration(labelText: 'Cargo ou função', hintText: 'Ex.: Técnico de campo'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _plate,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Placa do veículo', hintText: 'ABC1D23'),
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  value: _consent,
                  onChanged: (v) => setState(() => _consent = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Li e aceito a política de privacidade e os termos de uso.', style: TextStyle(fontSize: 14)),
                  subtitle: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LegalScreen())),
                      child: const Text('Ler a política e os termos'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('Continuar'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
