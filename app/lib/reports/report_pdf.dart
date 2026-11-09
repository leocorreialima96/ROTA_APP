import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/formatters.dart';
import 'report_data.dart';
import 'report_xlsx.dart';

/// Gera o PDF único do relatório: a tabela no modelo DJ PRIMUS e, em seguida,
/// um comprovante por página, em ordem de data. Despesa sem nota ganha uma
/// página marcada "Comprovante não anexado".
///
/// Roda no próprio celular, sem internet.
class ReportPdf {
  static final _red = PdfColor.fromInt(0xFFB0381C);
  static final _alert = PdfColor.fromInt(0xFFB42318);
  static final _alertSoft = PdfColor.fromInt(0xFFFDECEA);
  static final _ink = PdfColor.fromInt(0xFF0B1730);
  static final _muted = PdfColor.fromInt(0xFF4A5A70);
  static final _line = PdfColor.fromInt(0xFFA6A6A6);
  static final _band = PdfColor.fromInt(0xFFF6F1E7);

  /// [regular] e [bold] são os bytes das fontes TTF (Inter). Sem elas, o
  /// PDF cai na Helvetica, que não tem todos os caracteres.
  static Future<Uint8List> build(ReportData data, {ByteData? regular, ByteData? bold}) async {
    final theme = regular == null
        ? null
        : pw.ThemeData.withFont(base: pw.Font.ttf(regular), bold: pw.Font.ttf(bold ?? regular));
    final doc = pw.Document(
      theme: theme,
      title: data.fileBaseName,
      author: data.ownerName,
      creator: 'Rota',
      subject: 'Relatório de despesas',
    );

    doc.addPage(_reportPage(data));

    final n = data.lines.length;
    for (var i = 0; i < n; i++) {
      final l = data.lines[i];
      final title =
          'Comprovante ${_two(i + 1)}/${_two(n)} - ${dmy(l.date)} - ${l.categoryName} - ${brl(l.amount)} - ${l.client}';
      if (l.receiptPages.isEmpty && l.receiptSummary.isNotEmpty) {
        doc.addPage(_summaryPage(title, l.receiptSummary));
        continue;
      }
      if (l.receiptPages.isEmpty) {
        doc.addPage(_missingPage(title, l));
        continue;
      }
      for (var p = 0; p < l.receiptPages.length; p++) {
        doc.addPage(_receiptPage(p == 0 ? title : '$title (continuação ${p + 1}/${l.receiptPages.length})', l.receiptPages[p]));
      }
    }
    return doc.save();
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static pw.MultiPage _reportPage(ReportData data) {
    final cols = ReportXlsx.columns;
    final headers = ['Data', 'Conta', 'Cliente', ...cols.map((c) => c.label), 'Observação', 'Total'];
    final small = pw.TextStyle(fontSize: 7.5, color: _ink);
    final smallBold = small.copyWith(fontWeight: pw.FontWeight.bold);

    pw.Widget cell(String text, {pw.TextStyle? style, pw.Alignment align = pw.Alignment.centerLeft, PdfColor? bg}) => pw.Container(
          alignment: align,
          color: bg,
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(text, style: style ?? small),
        );

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _red),
        children: headers
            .map((h) => cell(h, style: smallBold.copyWith(color: PdfColors.white), align: pw.Alignment.center))
            .toList(),
      ),
      for (final l in data.lines)
        pw.TableRow(
          decoration: l.receiptMissing ? pw.BoxDecoration(color: _alertSoft) : null,
          children: [
            cell(dmy(l.date), align: pw.Alignment.center),
            cell(l.activity),
            cell(l.client),
            for (final c in cols) cell(c == l.column ? brl(l.amount) : '', align: pw.Alignment.centerRight),
            cell(
              [if (l.receiptMissing) 'SEM COMPROVANTE', if (l.notes.isNotEmpty) l.notes].join(' · '),
              style: l.receiptMissing ? small.copyWith(color: _alert) : small,
            ),
            cell(brl(l.amount), style: smallBold, align: pw.Alignment.centerRight),
          ],
        ),
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _band),
        children: [
          cell('Total', style: smallBold),
          cell(''),
          cell(''),
          for (final c in cols) cell(brl(data.columnTotal(c)), style: smallBold, align: pw.Alignment.centerRight),
          cell(''),
          cell(brl(data.subtotal), style: smallBold, align: pw.Alignment.centerRight),
        ],
      ),
    ];

    final summary = pw.Container(
      width: 230,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _red, width: 1)),
      child: pw.Column(children: [
        _sumRow('Subtotal', brl(data.subtotal)),
        _sumRow('Adiantamentos', data.advances > 0 ? '- ${brl(data.advances)}' : brl(0)),
        pw.Divider(color: _line, height: 8),
        _sumRow('Total a reembolsar', brl(data.total), bold: true),
      ]),
    );

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Container(
          color: _red,
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          alignment: pw.Alignment.center,
          child: pw.Text('RELATÓRIO DE DESPESAS',
              style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 6),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _info('Colaborador', data.ownerName.toUpperCase()),
            _info('Período', '${dmy(data.start)} a ${dmy(data.end)}'),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (data.ownerCpfMasked.isNotEmpty) _info('CPF', data.ownerCpfMasked),
            if (data.ownerPlate.isNotEmpty) _info('Placa', data.ownerPlate.toUpperCase()),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            _info('Despesas', '${data.lines.length}'),
            if (data.missingReceipts > 0)
              pw.Text('${data.missingReceipts} sem comprovante',
                  style: pw.TextStyle(fontSize: 9, color: _alert, fontWeight: pw.FontWeight.bold)),
          ]),
        ]),
        pw.SizedBox(height: 8),
      ]),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Gerado pela Rota em ${dmy(data.generatedAt)}', style: pw.TextStyle(fontSize: 7, color: _muted)),
        pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 7, color: _muted)),
      ]),
      build: (ctx) => [
        pw.Table(
          border: pw.TableBorder(
            left: pw.BorderSide(color: _red, width: 1),
            right: pw.BorderSide(color: _red, width: 1),
            top: pw.BorderSide(color: _red, width: 1),
            bottom: pw.BorderSide(color: _red, width: 1),
            horizontalInside: pw.BorderSide(color: _line, width: 0.4),
            verticalInside: pw.BorderSide(color: _line, width: 0.4),
          ),
          columnWidths: const {
            0: pw.FixedColumnWidth(46),
            1: pw.FlexColumnWidth(2.6),
            2: pw.FlexColumnWidth(1.7),
            3: pw.FixedColumnWidth(52),
            4: pw.FixedColumnWidth(48),
            5: pw.FixedColumnWidth(56),
            6: pw.FixedColumnWidth(56),
            7: pw.FixedColumnWidth(66),
            8: pw.FixedColumnWidth(52),
            9: pw.FlexColumnWidth(2.4),
            10: pw.FixedColumnWidth(56),
          },
          children: rows,
        ),
        pw.SizedBox(height: 12),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [summary]),
      ],
    );
  }

  static pw.Widget _info(String label, String value) => pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(text: '$label: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _ink)),
          pw.TextSpan(text: value, style: pw.TextStyle(fontSize: 9, color: _ink)),
        ]),
      );

  static pw.Widget _sumRow(String label, String value, {bool bold = false}) {
    final st = pw.TextStyle(fontSize: bold ? 11 : 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: _ink);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(label, style: st), pw.Text(value, style: st)]),
    );
  }

  static pw.Page _receiptPage(String title, Uint8List image) => pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink)),
          pw.SizedBox(height: 10),
          pw.Expanded(child: pw.Center(child: pw.Image(pw.MemoryImage(image), fit: pw.BoxFit.contain))),
        ]),
      );

  static pw.Page _summaryPage(String title, List<String> lines) => pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink)),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines.length; i++)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Text(lines[i],
                        style: pw.TextStyle(fontSize: i == 0 ? 13 : 10, fontWeight: i == 0 ? pw.FontWeight.bold : pw.FontWeight.normal, color: _ink)),
                  ),
              ],
            ),
          ),
        ]),
      );

  static pw.Page _missingPage(String title, ReportLine l) => pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink)),
          pw.Expanded(
            child: pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                decoration: pw.BoxDecoration(
                  color: _alertSoft,
                  border: pw.Border.all(color: _alert, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
                  pw.Text('Comprovante não anexado',
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _alert)),
                  pw.SizedBox(height: 8),
                  pw.Text('${dmy(l.date)} · ${l.categoryName} · ${brl(l.amount)}',
                      style: pw.TextStyle(fontSize: 12, color: _ink)),
                  if (l.activity.isNotEmpty)
                    pw.Text(l.activity, style: pw.TextStyle(fontSize: 10, color: _muted)),
                ]),
              ),
            ),
          ),
        ]),
      );
}
