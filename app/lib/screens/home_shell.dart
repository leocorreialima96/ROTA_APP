import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../models/report.dart';
import '../models/user_profile.dart';
import '../services/services.dart';
import 'expenses_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';

/// Despesas do usuário, compartilhadas pelas abas.
class ExpenseList {
  const ExpenseList(this.all, {this.loaded = true});

  final List<Expense> all;
  final bool loaded;

  List<Expense> get open => all.where((e) => !e.isClosed).toList();
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  late final Stream<List<Expense>> _expenses;
  late final Stream<List<Report>> _reports;

  @override
  void initState() {
    super.initState();
    final s = context.read<Services>();
    final uid = context.read<UserProfile>().uid;
    _expenses = s.expenses.watchAll(uid);
    _reports = s.reports.watch(uid);
  }

  void go(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Expense>>(
      stream: _expenses,
      builder: (context, es) => StreamBuilder<List<Report>>(
        stream: _reports,
        builder: (context, rs) => MultiProvider(
          providers: [
            Provider<ExpenseList>.value(value: ExpenseList(es.data ?? const [], loaded: es.hasData)),
            Provider<List<Report>>.value(value: rs.data ?? const []),
            Provider<void Function(int)>.value(value: go),
          ],
          child: Scaffold(
            body: IndexedStack(index: _tab, children: const [
              HomeScreen(),
              ExpensesScreen(),
              ReportsScreen(),
              ProfileScreen(),
            ]),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: go,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Despesas'),
                NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'Relatórios'),
                NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
