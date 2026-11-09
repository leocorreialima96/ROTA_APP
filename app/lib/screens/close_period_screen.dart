import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/expense.dart';
import '../models/user_profile.dart';
import '../reports/report_data.dart';
import '../services/services.dart';
import '../widgets/common.dart';
import 'home_screen.dart';
import 'home_shell.dart';
import 'report_view_screen.dart';

/// Tela 10: fechar o período e gerar o relatório.
class ClosePeriodScreen extends StatefulWidget {
  const ClosePeriodScreen({super.key});

  @override
  State<ClosePeriodScreen> createState() => _ClosePeriodScreenState();
}

class _ClosePeriodScreenState extends State<ClosePeriodScreen> {
  DateTime? _start;
  DateTime? _end;
  bool _hasAdvance = false;
  final _advance = TextEditingController();

  @override
  void initState() {
    super.initState();
    _advance.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _advance.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start, DateTime current, DateTime first, DateTime last) async {
    final d = await showDatePicker(context: context, initialDate: current, firstDate: first, lastDate: last);
    if (d == null) return;
    setState(() => start ? _start = d : _end = d);
  }

  Future<void> _close(UserProfile p, List<Expense> included, DateTime start, DateTime end, double advance) async {
    final unsaved = included.where((e) => !e.savedInCloud).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fechar o período?'),
        content: Text(
          'As ${included.length} despesas entram no relatório e não poderão mais ser editadas.'
          '${unsaved > 0 ? '\n\n$unsaved ainda estão só no celular: o relatório sai agora mesmo assim, e elas sobem para a nuvem quando houver sinal.' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fechar e gerar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final s = context.read<Services>();
    final report = s.reports.close(profile: p, expenses: included, start: start, end: end, advances: advance);
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Provider<UserProfile>.value(value: p, child: ReportViewScreen(report: report, expenses: included, fresh: true)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<UserProfile>();
    final open = context.watch<ExpenseList>().open;
    if (open.isEmpty) {
      return Scaffold(appBar: AppBar(title: const Text('Fechar período')), body: const Center(child: Text('Nenhuma despesa aberta.')));
    }
    final days = open.map((e) => e.day).toList()..sort();
    final first = days.first;
    final last = days.last;
    final start = _start ?? first;
    final end = _end ?? last;
    final included = open.where((e) => !e.day.isBefore(start) && !e.day.isAfter(end)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final missing = included.where((e) => !e.hasReceipt).toList();
    final subtotal = cents(included.fold(0.0, (s, e) => s + e.amount));
    final advance = _hasAdvance ? (parseMoney(_advance.text) ?? 0) : 0.0;
    final total = cents(subtotal - advance);
    final ready = included.isEmpty ? 0 : ((included.length - missing.length) / included.length * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Fechar período')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Row(children: [
                Expanded(child: _DateBox(label: 'Início do período', date: start, onTap: () => _pick(true, start, DateTime(first.year - 1), end))),
                const SizedBox(width: 10),
                Expanded(child: _DateBox(label: 'Fim do período', date: end, onTap: () => _pick(false, end, start, DateTime.now().add(const Duration(days: 1))))),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: RotaColors.ink, borderRadius: BorderRadius.circular(18)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Relatório $ready% pronto', style: display(18, color: Colors.white)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(value: ready / 100, minHeight: 10, backgroundColor: RotaColors.navy3, color: const Color(0xFF3BE38C)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    missing.isEmpty ? 'Todas as despesas têm comprovante.' : 'Anexe os comprovantes que faltam para fechar sem pendências.',
                    style: const TextStyle(fontSize: 12, color: RotaColors.onNavyMuted),
                  ),
                ]),
              ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: RotaColors.alertSoft, border: Border.all(color: RotaColors.alertLine), borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: RotaColors.alert, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('${missing.length} ${missing.length == 1 ? 'despesa' : 'despesas'} sem comprovante',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: RotaColors.alertDeep)),
                    ]),
                    const SizedBox(height: 8),
                    for (final e in missing)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.only(left: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          Expanded(
                            child: Text('${dm(e.day)} · ${p.settings.byId(e.categoryId)?.name ?? 'Outros'} · ${brl(e.amount)}',
                                style: const TextStyle(fontSize: 13)),
                          ),
                          TextButton(onPressed: () => openExpense(context, e), child: const Text('Anexar')),
                        ]),
                      ),
                  ]),
                ),
              ],
              const SizedBox(height: 14),
              RotaCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(children: [
                  for (final c in p.settings.sorted)
                    _row(
                      c.name,
                      included.where((e) => e.categoryId == c.id).fold(0.0, (s, e) => s + e.amount),
                      included.where((e) => e.categoryId == c.id).isEmpty
                          ? const Color(0xFFCFC7B6)
                          : (included.any((e) => e.categoryId == c.id && !e.hasReceipt) ? RotaColors.alert : RotaColors.ok),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      Expanded(child: Text('Subtotal · ${included.length} despesas', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                      Text(brl(subtotal), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              RotaCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Houve adiantamento no período?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  SegmentedButton<bool>(
                    segments: const [ButtonSegment(value: false, label: Text('Não')), ButtonSegment(value: true, label: Text('Sim'))],
                    selected: {_hasAdvance},
                    onSelectionChanged: (v) => setState(() => _hasAdvance = v.first),
                  ),
                  if (_hasAdvance) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _advance,
                      keyboardType: TextInputType.number,
                      inputFormatters: [MoneyInputFormatter()],
                      decoration: const InputDecoration(labelText: 'Valor recebido', prefixText: 'R\$ '),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: RotaColors.ink, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Expanded(
                    child: Text(total >= 0 ? 'Total a reembolsar' : 'Saldo a devolver',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                  Text(brl(total.abs()), style: display(22, color: Colors.white)),
                ]),
              ),
              const SizedBox(height: 12),
              const Text('Um único PDF: relatório + 1 comprovante por página, em ordem de data',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RotaColors.inkSoft)),
              const SizedBox(height: 2),
              Text('${reportFileBaseName(start, end, p.name)} (.pdf e .xlsx)', style: const TextStyle(fontSize: 12, color: RotaColors.muted)),
              const SizedBox(height: 4),
              const Text('Os dados bancários e o Pix entram no relatório na próxima versão.',
                  style: TextStyle(fontSize: 12, color: RotaColors.muted)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: included.isEmpty ? null : () => _close(p, included, start, end, advance),
                child: const Text('Gerar e compartilhar'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _row(String name, double value, Color flag) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: RotaColors.lineSoft))),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: flag, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14, color: RotaColors.inkSoft))),
          Text(brl(value), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: RotaColors.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: RotaColors.muted)),
              const SizedBox(height: 4),
              Text(dmy(date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}
