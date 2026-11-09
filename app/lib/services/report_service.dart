import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../core/formatters.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/report.dart';
import '../models/user_profile.dart';
import '../parsing/nfe_parser.dart';
import '../reports/report_data.dart';
import '../reports/report_pdf.dart';
import '../reports/report_xlsx.dart';
import 'expense_repository.dart';

class GeneratedReport {
  const GeneratedReport({required this.baseName, required this.pdf, required this.xlsx, required this.data});

  final String baseName;
  final Uint8List pdf;
  final Uint8List xlsx;
  final ReportData data;
}

/// Fecha o período e gera o PDF e a planilha no celular (sem precisar de sinal).
class ReportService {
  ReportService(this._db, this._storage, this._expenses);

  static const xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final ExpenseRepository _expenses;

  /// Guarda o PDF e a planilha também na nuvem (cópia de segurança). Sem
  /// sinal, ficam só no celular e podem ser gerados de novo a qualquer hora.
  Future<void> uploadFiles(Report report, GeneratedReport g) async {
    try {
      final pdfPath = 'users/${report.ownerId}/reports/${report.id}.pdf';
      final xlsxPath = 'users/${report.ownerId}/reports/${report.id}.xlsx';
      await _storage.ref(pdfPath).putData(g.pdf, SettableMetadata(contentType: 'application/pdf'));
      await _storage.ref(xlsxPath).putData(g.xlsx, SettableMetadata(contentType: xlsxMime));
      _db.doc('reports/${report.id}').update({
        'files': {'pdf': pdfPath, 'xlsx': xlsxPath},
        'updatedAt': FieldValue.serverTimestamp(),
      }).ignore();
    } catch (e) {
      debugPrint('Rota: arquivos do relatório ficaram só no celular por enquanto: $e');
    }
  }

  Stream<List<Report>> watch(String uid) => _db
      .collection('reports')
      .where('ownerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.docs.map(Report.fromDoc).toList());

  /// Grava o relatório e marca as despesas como fechadas, num único lote.
  Report close({
    required UserProfile profile,
    required List<Expense> expenses,
    required DateTime start,
    required DateTime end,
    required double advances,
  }) {
    final ref = _db.collection('reports').doc();
    final subtotal = cents(expenses.fold(0.0, (s, e) => s + e.amount));
    final report = Report(
      id: ref.id,
      ownerId: profile.uid,
      periodStart: isoDay(start),
      periodEnd: isoDay(end),
      expenseIds: expenses.map((e) => e.id).toList(),
      subtotal: subtotal,
      advances: cents(advances),
      status: ReportStatus.issued,
      fileBaseName: reportFileBaseName(start, end, profile.name),
      createdAt: DateTime.now(),
    );
    final batch = _db.batch();
    batch.set(ref, report.toMap()..['updatedAt'] = FieldValue.serverTimestamp());
    for (final e in expenses) {
      batch.update(_db.collection('expenses').doc(e.id), {
        'reportId': ref.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.commit().catchError((Object err) => debugPrint('Rota: fechamento recusado: $err'));
    return report;
  }

  Future<GeneratedReport> generate({
    required UserProfile profile,
    required Report report,
    List<Expense>? expenses,
    void Function(String step)? onProgress,
  }) async {
    final list = expenses ?? await _expenses.byReport(report.ownerId, report.id);
    final settings = profile.settings;
    final lines = <ReportLine>[];
    var i = 0;
    for (final e in list) {
      i++;
      onProgress?.call('Preparando comprovante $i de ${list.length}');
      final cat = settings.byId(e.categoryId);
      final (pages, summary) = await _receiptPages(e);
      lines.add(ReportLine(
        date: e.day,
        activity: e.activity.isNotEmpty ? e.activity : e.merchant,
        client: e.client,
        column: cat?.column ?? ReportColumn.outros,
        categoryName: cat?.name ?? 'Outros',
        amount: e.amount,
        notes: e.reportNotes,
        receiptPages: pages,
        receiptSummary: summary,
        receiptMissing: !e.hasReceipt,
      ));
    }
    final data = ReportData(
      ownerName: profile.name,
      ownerCpfMasked: profile.cpfMasked,
      ownerPlate: profile.plate,
      start: report.start,
      end: report.end,
      lines: lines,
      advances: report.advances,
    );
    onProgress?.call('Montando o PDF');
    final regular = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
    final pdf = await ReportPdf.build(data, regular: regular, bold: bold);
    onProgress?.call('Montando a planilha');
    final xlsx = ReportXlsx.build(data);
    return GeneratedReport(baseName: report.fileBaseName, pdf: pdf, xlsx: xlsx, data: data);
  }

  /// Imagens do comprovante para o PDF. PDFs viram uma imagem por página;
  /// o XML da NF-e vira uma página com o resumo da nota.
  Future<(List<Uint8List>, List<String>)> _receiptPages(Expense e) async {
    if (!e.hasReceipt) return (const <Uint8List>[], const <String>[]);
    final r = await _expenses.receipt(e).catchError((Object _) => null);
    if (r == null) return (const <Uint8List>[], const <String>[]);
    if (r.contentType == 'application/pdf') {
      final out = <Uint8List>[];
      await for (final page in Printing.raster(r.bytes, dpi: 130)) {
        out.add(await page.toPng());
      }
      return (out, const <String>[]);
    }
    if (r.contentType.contains('xml')) {
      try {
        final n = NfeParser.parse(utf8.decode(r.bytes, allowMalformed: true));
        return (const <Uint8List>[], <String>[
          'NF-e importada do XML',
          'Emitente: ${n.issuerName}',
          if (n.issuerCnpj.isNotEmpty) 'CNPJ: ${n.issuerCnpj}',
          'Emissão: ${dmy(n.date)}',
          if (n.accessKey.isNotEmpty) 'Chave de acesso: ${n.accessKey}',
          if (n.items.isNotEmpty) 'Itens: ${n.items.take(12).join('; ')}',
          'Valor total: ${brl(n.total)}',
        ]);
      } catch (_) {
        return (const <Uint8List>[], const <String>[]);
      }
    }
    return (<Uint8List>[r.bytes], const <String>[]);
  }
}

