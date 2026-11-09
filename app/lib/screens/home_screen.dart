import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/user_profile.dart';
import '../widgets/common.dart';
import 'add_expense.dart';
import 'close_period_screen.dart';
import 'expense_form_screen.dart';
import 'home_shell.dart';

/// Tela 6: Início. (Nível, XP e sequência entram na fase 4.)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<UserProfile>();
    final list = context.watch<ExpenseList>();
    final open = list.open;
    final total = cents(open.fold(0.0, (s, e) => s + e.amount));
    final missing = open.where((e) => !e.hasReceipt).length;
    final stale = list.all.where((e) => !e.savedInCloud && DateTime.now().difference(e.localCreatedAt).inHours >= 24).length;
    final since = open.isEmpty ? null : open.map((e) => e.day).reduce((a, b) => a.isBefore(b) ? a : b);
    final ready = open.isEmpty ? 0 : ((open.length - missing) / open.length * 100).round();

    final byCat = <String, double>{};
    for (final e in open) {
      byCat[e.categoryId] = (byCat[e.categoryId] ?? 0) + e.amount;
    }
    final parts = <(ExpenseCategory, double)>[
      for (final c in p.settings.sorted)
        if ((byCat[c.id] ?? 0) > 0) (c, byCat[c.id]!),
    ];

    return Scaffold(
      body: Column(children: [
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            _Header(profile: p),
            Transform.translate(
              offset: const Offset(0, -46),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [BoxShadow(color: Color(0x1F0B1730), blurRadius: 30, offset: Offset(0, 12))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              open.isEmpty
                                  ? 'Período aberto · nenhuma despesa ainda'
                                  : 'Período aberto · desde ${dm(since!)} · ${open.length} ${open.length == 1 ? 'despesa' : 'despesas'}',
                              style: const TextStyle(fontSize: 12, color: RotaColors.muted, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(brl(total), style: display(32))),
                          ]),
                        ),
                        if (open.isNotEmpty) _ReadyRing(percent: ready),
                      ]),
                      const SizedBox(height: 12),
                      CategorySplitBar(parts: parts),
                    ]),
                  ),
                  if (missing > 0 || stale > 0) ...[
                    const SizedBox(height: 14),
                    _AlertCard(missing: missing, stale: stale, onTap: () => context.read<void Function(int)>()(1)),
                  ],
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: Text('Últimos lançamentos', style: display(18))),
                    TextButton(onPressed: () => context.read<void Function(int)>()(1), child: const Text('Ver todos')),
                  ]),
                  const SizedBox(height: 4),
                  if (!list.loaded)
                    const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                  else if (open.isEmpty)
                    const _Empty()
                  else
                    for (final e in open.take(5)) ...[
                      ExpenseTile(
                        expense: e,
                        category: p.settings.byId(e.categoryId),
                        onTap: () => openExpense(context, e),
                      ),
                      const SizedBox(height: 6),
                    ],
                ]),
              ),
            ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  onPressed: () => showAddExpense(context),
                  icon: const Icon(Icons.add, size: 22),
                  label: const Text('Incluir despesa'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: RotaColors.violet,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: open.isEmpty
                      ? null
                      : () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => providersFor(context, const ClosePeriodScreen()))),
                  child: const Text('Fechar'),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Repassa os providers da aba para telas abertas por cima.
Widget providersFor(BuildContext context, Widget child) => MultiProvider(providers: [
      Provider<UserProfile>.value(value: context.read<UserProfile>()),
      Provider<ExpenseList>.value(value: context.read<ExpenseList>()),
    ], child: child);

void openExpense(BuildContext context, Expense e) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => providersFor(context, ExpenseFormScreen(existing: e))),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 20, 20, 70),
      decoration: const BoxDecoration(color: RotaColors.ink, borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
      clipBehavior: Clip.antiAlias,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          right: -60,
          top: -70,
          child: Container(width: 160, height: 160, decoration: BoxDecoration(color: RotaColors.violet.withValues(alpha: 0.35), shape: BoxShape.circle)),
        ),
        Positioned(
          right: 70,
          top: 50,
          child: Container(width: 70, height: 70, decoration: BoxDecoration(color: RotaColors.mint.withValues(alpha: 0.25), shape: BoxShape.circle)),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: RotaColors.navy2, borderRadius: BorderRadius.circular(15), border: Border.all(color: RotaColors.navy3)),
            alignment: Alignment.center,
            child: const Text('Modo individual', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: RotaColors.violet, shape: BoxShape.circle, border: Border.all(color: RotaColors.sun, width: 3)),
              child: Text(profile.initials, style: display(18, color: Colors.white)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Olá, ${_cap(profile.firstName)}', style: display(22, color: Colors.white)),
                const SizedBox(height: 4),
                const Text('Fotografe a nota na hora: o relatório se monta sozinho.',
                    style: TextStyle(fontSize: 13, color: RotaColors.onNavyMuted)),
              ]),
            ),
          ]),
        ]),
      ]),
    );
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

class _ReadyRing extends StatelessWidget {
  const _ReadyRing({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Relatório $percent% pronto',
        child: Column(children: [
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: percent / 100,
                  strokeWidth: 6,
                  backgroundColor: RotaColors.alertSoft,
                  color: const Color(0xFF3BE38C),
                ),
              ),
              Text('$percent%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 2),
          const Text('pronto', style: TextStyle(fontSize: 10, color: RotaColors.muted, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.missing, required this.stale, required this.onTap});

  final int missing;
  final int stale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (missing > 0) '$missing ${missing == 1 ? 'despesa' : 'despesas'} sem comprovante',
      if (stale > 0) '$stale há mais de 24 h sem subir para a nuvem: abra o app com internet',
    ];
    return Material(
      color: RotaColors.coral,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: RotaColors.ink, shape: BoxShape.circle),
              child: Text('${missing + stale}', style: display(20, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Pendências', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(parts.join(' · '), style: const TextStyle(fontSize: 12, color: RotaColors.inkSoft)),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const RotaCard(
        padding: EdgeInsets.all(20),
        child: Column(children: [
          Icon(Icons.receipt_long_outlined, size: 36, color: RotaColors.muted),
          SizedBox(height: 8),
          Text('Nenhuma despesa no período.', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Toque em "Incluir despesa" e fotografe a primeira nota.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: RotaColors.muted)),
        ]),
      );
}
