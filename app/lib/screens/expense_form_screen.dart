import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/user_profile.dart';
import '../services/services.dart';
import '../widgets/common.dart';
import 'add_expense.dart';
import 'home_screen.dart';
import 'home_shell.dart';

/// Telas 9 e 14: despesa preenchida / editar despesa (dividir a conta).
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key, this.existing, this.draft});

  final Expense? existing;
  final ExpenseDraft? draft;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Expense? _e = widget.existing;
  late final _note = TextEditingController();
  late final _custom = TextEditingController();
  late final _client = TextEditingController(text: _e?.client ?? '');
  late final _activity = TextEditingController(text: _e?.activity ?? '');
  late final _notes = TextEditingController(text: _e?.notes ?? '');
  late final _vehicle = TextEditingController(text: _e?.vehicleNotes ?? '');
  late DateTime _date;
  late String _categoryId;
  late String _merchant;
  bool _split = false;
  int _people = 2;
  bool _customValue = false;

  Uint8List? _receipt;
  String? _receiptType;
  bool _receiptChanged = false;
  bool _loadingReceipt = false;

  bool get _readOnly => _e?.isClosed ?? false;

  @override
  void initState() {
    super.initState();
    final p = context.read<UserProfile>();
    final d = widget.draft;
    final e = _e;
    if (e != null) {
      _date = e.day;
      _categoryId = e.categoryId;
      _merchant = e.merchant;
      _note.text = moneyField(e.noteAmount);
      if (e.isAdjusted) {
        _split = true;
        if (e.splitPeople > 1 && (cents(e.noteAmount / e.splitPeople) - e.amount).abs() < 0.01) {
          _people = e.splitPeople;
        } else {
          _customValue = true;
          _custom.text = moneyField(e.amount);
        }
      }
      _loadReceipt(e);
    } else {
      final parsed = d?.parsed;
      _date = parsed?.date ?? DateTime.now();
      _merchant = parsed?.merchant ?? '';
      final guess = parsed?.categoryId;
      _categoryId = (guess != null && p.settings.byId(guess) != null) ? guess : p.settings.sorted.first.id;
      if (parsed?.total != null) _note.text = moneyField(parsed!.total!);
      _receipt = d?.bytes;
      _receiptType = d?.contentType;
      _receiptChanged = d?.bytes != null;
      if (_merchant.isNotEmpty && _activity.text.isEmpty) _activity.text = _merchant;
    }
    for (final c in [_note, _custom]) {
      c.addListener(() => setState(() {}));
    }
  }

  Future<void> _loadReceipt(Expense e) async {
    if (!e.hasReceipt) return;
    setState(() => _loadingReceipt = true);
    try {
      final r = await context.read<Services>().expenses.receipt(e);
      if (mounted && r != null) {
        setState(() {
          _receipt = r.bytes;
          _receiptType = r.contentType;
        });
      }
    } catch (_) {
      // Sem sinal e sem cópia local: mostra só o aviso de "na nuvem".
    } finally {
      if (mounted) setState(() => _loadingReceipt = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_note, _custom, _client, _activity, _notes, _vehicle]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _noteValue => parseMoney(_note.text) ?? 0;

  double get _finalValue {
    if (!_split) return cents(_noteValue);
    if (_customValue) return cents(parseMoney(_custom.text) ?? 0);
    return cents(_noteValue / _people);
  }

  Future<void> _attach() async {
    final source = await showModalBottomSheet<ExpenseSource>(
      context: context,
      backgroundColor: RotaColors.paper,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Fotografar'), onTap: () => Navigator.pop(context, ExpenseSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Galeria'), onTap: () => Navigator.pop(context, ExpenseSource.gallery)),
          ListTile(leading: const Icon(Icons.upload_file_outlined), title: const Text('PDF ou NF-e (XML)'), onTap: () => Navigator.pop(context, ExpenseSource.pdf)),
        ]),
      ),
    );
    if (source == null || !mounted) return;
    final d = await captureDraft(context, source);
    if (d?.bytes == null || !mounted) return;
    setState(() {
      _receipt = d!.bytes;
      _receiptType = d.contentType;
      _receiptChanged = true;
      if (_noteValue == 0 && d.parsed?.total != null) _note.text = moneyField(d.parsed!.total!);
      if (_merchant.isEmpty && d.parsed?.merchant != null) _merchant = d.parsed!.merchant!;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save({required bool next}) async {
    if (!_form.currentState!.validate()) return;
    if (_finalValue <= 0) {
      showMessage(context, 'Informe o valor da nota.');
      return;
    }
    if (_finalValue > _noteValue + 0.005 && _split) {
      showMessage(context, 'O valor do relatório não pode ser maior que o total da nota.');
      return;
    }
    final s = context.read<Services>();
    final p = context.read<UserProfile>();
    final isNew = _e == null;
    final base = _e ??
        Expense(
          id: s.expenses.newId(),
          ownerId: p.uid,
          date: isoDay(_date),
          client: '',
          activity: '',
          categoryId: _categoryId,
          noteAmount: 0,
          amount: 0,
          notes: '',
          receiptState: ReceiptState.none,
          source: widget.draft?.source ?? ExpenseSource.manual,
          localCreatedAt: DateTime.now(),
        );
    final cat = p.settings.byId(_categoryId);
    final e = base.copyWith(
      date: isoDay(_date),
      client: _client.text.trim(),
      activity: _activity.text.trim(),
      categoryId: _categoryId,
      noteAmount: cents(_noteValue),
      amount: _finalValue,
      splitPeople: _split && !_customValue ? _people : 1,
      notes: _notes.text.trim(),
      vehicleNotes: cat?.column == ReportColumn.combustivel ? _vehicle.text.trim() : '',
      merchant: _merchant,
    );
    await s.expenses.save(
      e,
      receipt: _receiptChanged ? _receipt : null,
      receiptType: _receiptType,
      isNew: isNew,
    );
    if (!mounted) return;
    final limit = cat?.maxPerExpense;
    final over = limit != null && e.amount > limit;
    final message = [
      isNew ? 'Despesa salva' : 'Alterações salvas',
      if (!e.hasReceipt && !_receiptChanged) 'sem comprovante',
      if (over) 'acima do limite de ${brl(limit)} para ${cat!.name}',
    ].join(' · ');
    final messenger = ScaffoldMessenger.of(context);
    void done() => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

    if (next) {
      done();
      final draft = await chooseDraft(context);
      if (!mounted) return;
      if (draft != null) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (_) => providersFor(context, ExpenseFormScreen(draft: draft))),
        );
        return;
      }
    }
    if (mounted) Navigator.pop(context);
    if (!next) done();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir despesa?'),
        content: const Text('A despesa e o comprovante serão apagados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: RotaColors.alertText),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<Services>().expenses.delete(_e!);
    if (mounted) {
      Navigator.pop(context);
      showMessage(context, 'Despesa excluída.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<UserProfile>();
    final cats = p.settings.sorted;
    final cat = p.settings.byId(_categoryId);
    final all = context.watch<ExpenseList>().all;
    final recentClients = _recent(all.map((e) => e.client));
    final recentActivities = _recent(all.map((e) => e.activity));
    final limit = cat?.maxPerExpense;
    final over = limit != null && _finalValue > limit;

    return Scaffold(
      appBar: AppBar(
        title: Text(_e == null ? 'Nova despesa' : (_readOnly ? 'Despesa fechada' : 'Editar despesa')),
        actions: [
          if (_e != null && !_readOnly)
            IconButton(tooltip: 'Excluir', onPressed: _delete, icon: const Icon(Icons.delete_outline, color: RotaColors.alertText)),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _form,
              child: AbsorbPointer(
                absorbing: _readOnly,
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
                  if (_readOnly)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: RotaCard(
                        color: RotaColors.band,
                        child: Text('Esta despesa já está num relatório emitido e não pode mais ser alterada.',
                            style: TextStyle(fontSize: 13, color: RotaColors.inkSoft)),
                      ),
                    ),
                  _receiptCard(),
                  if (_e != null) Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: SyncLabel(expense: _e)),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _note,
                    keyboardType: TextInputType.number,
                    inputFormatters: [MoneyInputFormatter()],
                    style: display(22),
                    decoration: InputDecoration(
                      labelText: 'Total da nota${_merchant.isNotEmpty ? ' · $_merchant' : ''}',
                      prefixText: 'R\$ ',
                    ),
                    validator: (v) => (parseMoney(v ?? '') ?? 0) > 0 ? null : 'Informe o valor.',
                  ),
                  const SizedBox(height: 12),
                  _splitCard(over: over, limit: limit, cat: cat),
                  const SizedBox(height: 16),
                  const Text('Categoria', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: RotaColors.muted)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final c in cats)
                      ChoiceChip(
                        selected: c.id == _categoryId,
                        onSelected: (_) => setState(() => _categoryId = c.id),
                        showCheckmark: false,
                        avatar: CircleAvatar(radius: 5, backgroundColor: c.colorValue),
                        label: Text(c.name),
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: RotaColors.ink),
                        backgroundColor: Colors.white,
                        selectedColor: c.softColor,
                        side: BorderSide(color: c.id == _categoryId ? RotaColors.ink : RotaColors.line, width: 2),
                        shape: const StadiumBorder(),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Data da despesa', suffixIcon: Icon(Icons.calendar_today_outlined)),
                      child: Text(dmy(_date), style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _client,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Cliente *'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'O cliente é obrigatório.' : null,
                  ),
                  _Suggestions(values: recentClients, onPick: (v) => setState(() => _client.text = v)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _activity,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Atividade', hintText: 'Ex.: Visita técnica · linha de solda'),
                  ),
                  _Suggestions(values: recentActivities, onPick: (v) => setState(() => _activity.text = v)),
                  if (cat?.column == ReportColumn.combustivel) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _vehicle,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Observação do veículo (opcional)',
                        hintText: 'Ex.: km 45.210 a 45.398 · Santo André até Cliente A e volta',
                        helperText: 'Km de início e fim, trajeto ou outras informações do uso do veículo.',
                        helperMaxLines: 2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Observação')),
                  const SizedBox(height: 20),
                  if (!_readOnly)
                    Row(children: [
                      if (_e == null) ...[
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: RotaColors.mint),
                            onPressed: () => _save(next: true),
                            child: const Text('Salvar e próxima'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(child: FilledButton(onPressed: () => _save(next: false), child: const Text('Salvar'))),
                    ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptCard() {
    final has = _receipt != null || (_e?.hasReceipt ?? false);
    final isImage = _receiptType?.startsWith('image/') ?? false;
    Widget thumb;
    if (_loadingReceipt) {
      thumb = const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    } else if (_receipt != null && isImage) {
      thumb = Image.memory(_receipt!, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (has) {
      thumb = Icon(_receiptType == 'application/pdf' ? Icons.picture_as_pdf_outlined : Icons.description_outlined, color: RotaColors.link, size: 30);
    } else {
      thumb = const Icon(Icons.receipt_long_outlined, color: RotaColors.alert, size: 30);
    }
    return RotaCard(
      border: has ? null : RotaColors.alertLine,
      color: has ? Colors.white : RotaColors.alertSoft,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        GestureDetector(
          onTap: _receipt != null && isImage ? () => _preview() : null,
          child: Container(
            width: 58,
            height: 76,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: const Color(0xFFFFF8E6), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFF3E2B5))),
            child: thumb,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: has ? RotaColors.okSoft : RotaColors.alert, borderRadius: BorderRadius.circular(8)),
              child: Text(has ? 'Comprovante anexado' : 'Sem comprovante',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: has ? RotaColors.ink : Colors.white)),
            ),
            const SizedBox(height: 6),
            Text(
              has
                  ? (_receiptType == 'application/xml' ? 'NF-e importada do XML' : 'Vai numa página própria do PDF.')
                  : 'O relatório marca esta despesa em vermelho.',
              style: const TextStyle(fontSize: 12, color: RotaColors.muted),
            ),
            if (!_readOnly)
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                onPressed: _attach,
                child: Text(has ? 'Trocar comprovante' : 'Anexar comprovante'),
              ),
          ]),
        ),
      ]),
    );
  }

  void _preview() {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(child: Image.memory(_receipt!)),
      ),
    );
  }

  Widget _splitCard({required bool over, required double? limit, required ExpenseCategory? cat}) {
    return RotaCard(
      border: _split ? RotaColors.mint : null,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _split,
          onChanged: (v) => setState(() => _split = v),
          title: const Text('Dividir a conta ou ajustar valor', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          subtitle: const Text('O total da nota fica registrado na observação.', style: TextStyle(fontSize: 12)),
        ),
        if (_split) ...[
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Dividir'), icon: Icon(Icons.group_outlined)),
              ButtonSegment(value: true, label: Text('Ajustar valor'), icon: Icon(Icons.tune)),
            ],
            selected: {_customValue},
            onSelectionChanged: (s) => setState(() => _customValue = s.first),
          ),
          const SizedBox(height: 10),
          if (!_customValue)
            Row(children: [
              const Text('Dividir entre', style: TextStyle(fontSize: 14)),
              const Spacer(),
              _Round(color: const Color(0xFFFFB4A2), label: 'Menos uma pessoa', icon: Icons.remove, onTap: () => setState(() => _people = (_people - 1).clamp(2, 50))),
              SizedBox(width: 96, child: Text('$_people pessoas', textAlign: TextAlign.center, style: display(17))),
              _Round(color: const Color(0xFF99F6E4), label: 'Mais uma pessoa', icon: Icons.add, onTap: () => setState(() => _people = (_people + 1).clamp(2, 50))),
            ])
          else
            TextField(
              controller: _custom,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              decoration: const InputDecoration(labelText: 'Valor que vai no relatório', prefixText: 'R\$ '),
            ),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: over ? RotaColors.alertSoft : (_split ? RotaColors.mintSoft : RotaColors.band), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(
              child: Text(
                over ? 'Acima do limite de ${brl(limit!)} (${cat!.name})' : 'Vai no relatório',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: over ? RotaColors.alertText : RotaColors.ink),
              ),
            ),
            Text(brl(_finalValue), style: display(22)),
          ]),
        ),
      ]),
    );
  }

  static List<String> _recent(Iterable<String> values) {
    final seen = <String>{};
    final out = <String>[];
    for (final v in values) {
      final t = v.trim();
      if (t.isEmpty || !seen.add(t.toLowerCase())) continue;
      out.add(t);
      if (out.length == 4) break;
    }
    return out;
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.color, required this.label, required this.icon, required this.onTap});

  final Color color;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: label,
        style: IconButton.styleFrom(backgroundColor: color, minimumSize: const Size(44, 44)),
        onPressed: onTap,
        icon: Icon(icon, color: RotaColors.ink),
      );
}

/// Atalhos com os clientes e atividades mais recentes (um toque preenche).
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.values, required this.onPick});

  final List<String> values;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final v in values)
          ActionChip(
            label: Text(v, overflow: TextOverflow.ellipsis),
            onPressed: () => onPick(v),
            backgroundColor: RotaColors.band,
            side: BorderSide.none,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: RotaColors.ink),
            shape: const StadiumBorder(),
          ),
      ]),
    );
  }
}
