import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/expense.dart';
import '../models/report.dart';
import '../models/user_profile.dart';
import '../services/report_service.dart';
import '../services/services.dart';
import '../widgets/common.dart';

/// Telas 11 e 12: relatório emitido, com o PDF (relatório + comprovantes) e a planilha.
class ReportViewScreen extends StatefulWidget {
  const ReportViewScreen({super.key, required this.report, this.expenses, this.fresh = false});

  final Report report;
  final List<Expense>? expenses;

  /// Acabou de ser fechado (mostra a comemoração e guarda cópia na nuvem).
  final bool fresh;

  @override
  State<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends State<ReportViewScreen> {
  GeneratedReport? _g;
  String _step = 'Preparando';
  Object? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _error = null;
      _g = null;
    });
    final s = context.read<Services>();
    final p = context.read<UserProfile>();
    try {
      final g = await s.reports.generate(
        profile: p,
        report: widget.report,
        expenses: widget.expenses,
        onProgress: (step) {
          if (mounted) setState(() => _step = step);
        },
      );
      if (!mounted) return;
      setState(() => _g = g);
      if (widget.fresh) s.reports.uploadFiles(widget.report, g).ignore();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Rect? _origin() {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _sharePdf() async {
    final g = _g!;
    await Printing.sharePdf(bytes: g.pdf, filename: '${g.baseName}.pdf', bounds: _origin());
  }

  Future<void> _shareXlsx() async {
    final g = _g!;
    final name = '${g.baseName}.xlsx';
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(g.xlsx, mimeType: ReportService.xlsxMime, name: name)],
      fileNameOverrides: [name],
      sharePositionOrigin: _origin(),
    ));
  }

  Future<void> _shareBoth() async {
    final g = _g!;
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(g.pdf, mimeType: 'application/pdf', name: '${g.baseName}.pdf'),
        XFile.fromData(g.xlsx, mimeType: ReportService.xlsxMime, name: '${g.baseName}.xlsx'),
      ],
      fileNameOverrides: ['${g.baseName}.pdf', '${g.baseName}.xlsx'],
      subject: g.baseName,
      sharePositionOrigin: _origin(),
    ));
  }

  void _preview() {
    final g = _g!;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('PDF do relatório')),
          body: PdfPreview(
            build: (_) async => g.pdf,
            pdfFileName: '${g.baseName}.pdf',
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final g = _g;
    return Scaffold(
      appBar: AppBar(title: const Text('Relatório emitido')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              if (widget.fresh)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: RotaColors.mint, borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    const Icon(Icons.check_circle, size: 34, color: RotaColors.ink),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Período fechado!', style: display(19)),
                        const Text('Seu relatório está pronto para compartilhar.', style: TextStyle(fontSize: 13)),
                      ]),
                    ),
                  ]),
                ),
              const SizedBox(height: 14),
              RotaCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(r.fileBaseName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  _line('Período', '${dmy(r.start)} a ${dmy(r.end)}'),
                  _line('Despesas', '${r.expenseIds.length}'),
                  _line('Subtotal', brl(r.subtotal)),
                  _line('Adiantamentos', brl(r.advances)),
                  const Divider(height: 16),
                  _line(r.total >= 0 ? 'Total a reembolsar' : 'Saldo a devolver', brl(r.total.abs()), bold: true),
                  if (g != null && g.data.missingReceipts > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${g.data.missingReceipts} sem comprovante, marcadas em vermelho no relatório.',
                          style: const TextStyle(fontSize: 12, color: RotaColors.alertText, fontWeight: FontWeight.w600)),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                RotaCard(
                  color: RotaColors.alertSoft,
                  child: Text('Não foi possível gerar os arquivos: $_error', style: const TextStyle(color: RotaColors.alertDeep)),
                ),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: _generate, child: const Text('Tentar de novo')),
              ] else if (g == null) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 10),
                Center(child: Text(_step, style: const TextStyle(color: RotaColors.muted))),
              ] else ...[
                FilledButton.icon(onPressed: _shareBoth, icon: const Icon(Icons.ios_share), label: const Text('Compartilhar PDF e planilha')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: _sharePdf, icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Só o PDF'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(onPressed: _shareXlsx, icon: const Icon(Icons.table_chart_outlined), label: const Text('Só a planilha'))),
                ]),
                const SizedBox(height: 10),
                TextButton.icon(onPressed: _preview, icon: const Icon(Icons.visibility_outlined), label: const Text('Ver o PDF')),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _line(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(a, style: TextStyle(fontSize: bold ? 15 : 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: RotaColors.inkSoft))),
          Text(b, style: TextStyle(fontSize: bold ? 17 : 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
        ]),
      );
}
