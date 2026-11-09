import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme.dart';
import '../models/report.dart';
import '../models/user_profile.dart';
import '../services/profile_repository.dart';
import '../services/services.dart';
import '../widgets/common.dart';
import 'categories_screen.dart';
import 'home_shell.dart';
import 'legal_screen.dart';

/// Tela 15: Perfil. O CPF aparece mascarado e não pode ser editado.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<UserProfile>();
    final s = context.read<Services>();
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: RotaColors.violet, shape: BoxShape.circle, border: Border.all(color: RotaColors.sun, width: 3)),
            child: Text(p.initials, style: display(24, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 10),
        Center(child: Text(p.name, style: display(20), textAlign: TextAlign.center)),
        Center(child: Text(p.email, style: const TextStyle(color: RotaColors.muted))),
        const SizedBox(height: 18),
        RotaCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            _info('CPF', p.cpfMasked, trailing: const Tooltip(message: 'O CPF não pode ser alterado', child: Icon(Icons.lock_outline, size: 18, color: RotaColors.muted))),
            _info('Celular', p.phone.isEmpty ? '-' : p.phone),
            _info('Cargo ou função', p.jobTitle.isEmpty ? '-' : p.jobTitle),
            _info('Placa do veículo', p.plate.isEmpty ? '-' : p.plate, last: true),
          ]),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () => _edit(context, p), icon: const Icon(Icons.edit_outlined), label: const Text('Editar meus dados')),
        const SizedBox(height: 18),
        _section('Relatório'),
        _tile(context, Icons.category_outlined, 'Categorias e limites', () {
          Navigator.push(context, MaterialPageRoute<void>(builder: (_) => CategoriesScreen(profile: p)));
        }),
        _tile(context, Icons.account_balance_outlined, 'Dados bancários e Pix', () {
          showMessage(context, 'Dados bancários e Pix chegam na próxima versão.');
        }, subtitle: 'Em breve'),
        const SizedBox(height: 18),
        _section('Privacidade (LGPD)'),
        _tile(context, Icons.download_outlined, 'Exportar meus dados', () => _export(context, p)),
        _tile(context, Icons.policy_outlined, 'Política de privacidade e termos', () {
          Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LegalScreen()));
        }),
        _tile(context, Icons.delete_forever_outlined, 'Excluir minha conta', () => _delete(context), danger: true),
        const SizedBox(height: 18),
        OutlinedButton(onPressed: () => s.auth.signOut(), child: const Text('Sair')),
      ]),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: RotaColors.muted)),
      );

  Widget _info(String label, String value, {Widget? trailing, bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: RotaColors.lineSoft))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, color: RotaColors.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15)),
            ]),
          ),
          ?trailing,
        ]),
      );

  Widget _tile(BuildContext context, IconData icon, String title, VoidCallback onTap, {String? subtitle, bool danger = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: Icon(icon, color: danger ? RotaColors.alertText : RotaColors.ink),
            title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: danger ? RotaColors.alertText : RotaColors.ink)),
            subtitle: subtitle == null ? null : Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        ),
      );

  Future<void> _edit(BuildContext context, UserProfile p) async {
    final name = TextEditingController(text: p.name);
    final phone = TextEditingController(text: p.phone);
    final job = TextEditingController(text: p.jobTitle);
    final plate = TextEditingController(text: p.plate);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RotaColors.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Meus dados', style: display(22)),
          const SizedBox(height: 14),
          TextField(controller: name, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Nome completo (como sai no relatório)')),
          const SizedBox(height: 10),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Celular')),
          const SizedBox(height: 10),
          TextField(controller: job, decoration: const InputDecoration(labelText: 'Cargo ou função')),
          const SizedBox(height: 10),
          TextField(controller: plate, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Placa do veículo')),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ]),
      ),
    );
    if (ok == true && context.mounted) {
      if (name.text.trim().length < 3) {
        showMessage(context, 'O nome precisa ter pelo menos 3 letras.');
        return;
      }
      await context.read<Services>().profiles.update(p, name: name.text, phone: phone.text, jobTitle: job.text, plate: plate.text);
      if (context.mounted) showMessage(context, 'Dados atualizados.');
    }
  }

  Future<void> _export(BuildContext context, UserProfile p) async {
    final expenses = context.read<ExpenseList>().all;
    final reports = context.read<List<Report>>();
    final data = {
      'exportadoEm': DateTime.now().toIso8601String(),
      'perfil': {
        'nome': p.name,
        'cpf': p.cpfMasked,
        'email': p.email,
        'celular': p.phone,
        'cargo': p.jobTitle,
        'placa': p.plate,
        'categorias': p.settings.toMap()['categories'],
      },
      'despesas': [
        for (final e in expenses)
          {
            'id': e.id,
            'data': e.date,
            'cliente': e.client,
            'atividade': e.activity,
            'categoria': p.settings.byId(e.categoryId)?.name ?? e.categoryId,
            'valorDaNota': e.noteAmount,
            'valorNoRelatorio': e.amount,
            'observacao': e.notes,
            'veiculo': e.vehicleNotes,
            'estabelecimento': e.merchant,
            'comprovante': e.receiptState.name,
            'relatorio': e.reportId,
          },
      ],
      'relatorios': [
        for (final r in reports)
          {'id': r.id, 'inicio': r.periodStart, 'fim': r.periodEnd, 'subtotal': r.subtotal, 'adiantamentos': r.advances, 'total': r.total, 'arquivo': r.fileBaseName},
      ],
    };
    final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'application/json', name: 'rota-meus-dados.json')],
      fileNameOverrides: ['rota-meus-dados.json'],
    ));
  }

  Future<void> _delete(BuildContext context) async {
    final typed = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Excluir conta?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Suas despesas, relatórios, fotos e dados pessoais serão apagados de vez. Isso não pode ser desfeito.\n\nDigite EXCLUIR para confirmar.'),
            const SizedBox(height: 10),
            TextField(controller: typed, onChanged: (_) => set(() {}), textCapitalization: TextCapitalization.characters),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: RotaColors.alertText),
              onPressed: typed.text.trim().toUpperCase() == 'EXCLUIR' ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Excluir'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final s = context.read<Services>();
    try {
      await s.profiles.deleteAccount();
      await s.auth.signOut();
    } catch (e) {
      if (context.mounted) showMessage(context, ProfileRepository.message(e));
    }
  }
}
