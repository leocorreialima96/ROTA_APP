import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/category.dart';
import '../models/user_profile.dart';
import '../services/services.dart';
import '../widgets/common.dart';

/// Tela 5: categorias do modo individual (ordem, cores, coluna no relatório
/// e limite por despesa). Pode pular e usar o padrão.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.profile, this.onboarding = false});

  final UserProfile profile;
  final bool onboarding;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late List<ExpenseCategory> _cats = widget.profile.settings.sorted;

  void _save({bool skip = false}) {
    final list = skip ? ExpenseCategory.defaults : [for (var i = 0; i < _cats.length; i++) _cats[i].copyWith(order: i)];
    context.read<Services>().profiles.saveSettings(
          widget.profile,
          IndividualSettings(categories: list, byProject: widget.profile.settings.byProject),
        );
    if (!widget.onboarding) {
      Navigator.pop(context);
      showMessage(context, 'Categorias salvas.');
    }
  }

  Future<void> _edit([ExpenseCategory? cat]) async {
    final result = await showModalBottomSheet<ExpenseCategory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RotaColors.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CategoryEditor(category: cat, order: _cats.length),
    );
    if (result == null) return;
    setState(() {
      final i = _cats.indexWhere((c) => c.id == result.id);
      if (i >= 0) {
        _cats[i] = result;
      } else {
        _cats = [..._cats, result];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.onboarding ? null : const Text('Categorias'),
        automaticallyImplyLeading: !widget.onboarding,
        actions: [
          if (widget.onboarding) TextButton(onPressed: () => _save(skip: true), child: const Text('Pular')),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(children: [
              Expanded(
                child: ReorderableListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  header: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: widget.onboarding
                        ? const StepHeader(
                            step: 3,
                            total: 3,
                            title: 'Suas categorias',
                            subtitle: 'Arraste para mudar a ordem. Cada categoria cai numa coluna do relatório no modelo DJ PRIMUS. Pode pular e usar o padrão.',
                          )
                        : const Text('Arraste para mudar a ordem. Toque para editar.', style: TextStyle(color: RotaColors.muted)),
                  ),
                  onReorderItem: (from, to) => setState(() {
                    final list = [..._cats];
                    final item = list.removeAt(from);
                    list.insert(to, item);
                    _cats = list;
                  }),
                  children: [
                    for (final c in _cats)
                      Padding(
                        key: ValueKey(c.id),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: CategoryBadge(category: c),
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              [c.column.label, if (c.maxPerExpense != null) 'até ${brl(c.maxPerExpense!)} por despesa'].join(' · '),
                              style: const TextStyle(fontSize: 12, color: RotaColors.muted),
                            ),
                            trailing: const Icon(Icons.drag_handle, color: RotaColors.muted),
                            onTap: () => _edit(c),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(children: [
                  OutlinedButton.icon(
                    onPressed: _cats.length >= 40 ? null : () => _edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nova categoria'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: _save, child: Text(widget.onboarding ? 'Começar a usar' : 'Salvar')),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({required this.category, required this.order});

  final ExpenseCategory? category;
  final int order;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  late final _limit = TextEditingController(
      text: widget.category?.maxPerExpense == null ? '' : moneyField(widget.category!.maxPerExpense!));
  late int _color = widget.category?.color ?? ExpenseCategory.palette[5];
  late ReportColumn _column = widget.category?.column ?? ReportColumn.outros;

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    super.dispose();
  }

  void _done() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final limit = parseMoney(_limit.text);
    final id = widget.category?.id ?? 'c_${DateTime.now().millisecondsSinceEpoch}';
    Navigator.pop(
      context,
      ExpenseCategory(
        id: id,
        name: name,
        color: _color,
        order: widget.category?.order ?? widget.order,
        column: _column,
        maxPerExpense: (limit == null || limit <= 0) ? null : limit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.category == null ? 'Nova categoria' : 'Editar categoria', style: display(22)),
        const SizedBox(height: 14),
        TextField(controller: _name, maxLength: 40, decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Consumo')),
        const SizedBox(height: 6),
        const Text('Cor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: RotaColors.muted)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final c in ExpenseCategory.palette)
            Semantics(
              button: true,
              selected: c == _color,
              label: 'Cor',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(color: c == _color ? RotaColors.ink : Colors.transparent, width: 3),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        DropdownButtonFormField<ReportColumn>(
          initialValue: _column,
          decoration: const InputDecoration(labelText: 'Coluna no relatório'),
          items: [for (final c in ReportColumn.values) DropdownMenuItem(value: c, child: Text(c.label))],
          onChanged: (v) => setState(() => _column = v ?? _column),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _limit,
          keyboardType: TextInputType.number,
          inputFormatters: [MoneyInputFormatter()],
          decoration: const InputDecoration(labelText: 'Limite por despesa (opcional)', prefixText: 'R\$ '),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _done, child: const Text('Pronto')),
      ]),
    );
  }
}
