import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/expense.dart';
import '../models/user_profile.dart';
import '../widgets/common.dart';
import 'add_expense.dart';
import 'home_screen.dart';
import 'home_shell.dart';

/// Tela 13: Despesas do período aberto, agrupadas por dia.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  bool _onlyMissing = false;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<UserProfile>();
    final list = context.watch<ExpenseList>();
    var open = list.open;
    final missing = open.where((e) => !e.hasReceipt).length;
    if (_onlyMissing) open = open.where((e) => !e.hasReceipt).toList();
    final unsynced = list.open.where((e) => !e.savedInCloud).length;

    final groups = <String, List<Expense>>{};
    for (final e in open) {
      groups.putIfAbsent(e.date, () => []).add(e);
    }
    final weekday = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');

    return Scaffold(
      appBar: AppBar(title: const Text('Despesas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddExpense(context),
        backgroundColor: RotaColors.sun,
        foregroundColor: RotaColors.ink,
        icon: const Icon(Icons.add),
        label: const Text('Incluir', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 96), children: [
        Row(children: [
          FilterChip(
            label: Text('Sem comprovante ($missing)'),
            selected: _onlyMissing,
            onSelected: missing == 0 && !_onlyMissing ? null : (v) => setState(() => _onlyMissing = v),
            selectedColor: RotaColors.alertSoft,
            labelStyle: TextStyle(color: missing > 0 ? RotaColors.alertText : RotaColors.muted, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Icon(unsynced == 0 ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined, size: 18, color: unsynced == 0 ? RotaColors.okText : RotaColors.muted),
          const SizedBox(width: 4),
          Text(unsynced == 0 ? 'Tudo na nuvem' : '$unsynced no celular',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: unsynced == 0 ? RotaColors.okText : RotaColors.muted)),
        ]),
        const SizedBox(height: 8),
        if (open.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: Text('Nenhuma despesa aberta.', style: TextStyle(color: RotaColors.muted))),
          ),
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
            child: Row(children: [
              Expanded(
                child: Text(_cap(weekday.format(parseIsoDay(entry.key))),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: RotaColors.inkSoft)),
              ),
              Text(brl(entry.value.fold(0.0, (s, e) => s + e.amount)),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: RotaColors.inkSoft)),
            ]),
          ),
          for (final e in entry.value) ...[
            ExpenseTile(expense: e, category: p.settings.byId(e.categoryId), onTap: () => openExpense(context, e)),
            const SizedBox(height: 6),
          ],
        ],
      ]),
    );
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
