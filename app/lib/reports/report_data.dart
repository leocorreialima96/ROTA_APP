import 'dart:typed_data';

import '../core/formatters.dart';
import '../models/category.dart';

/// Uma linha do relatório, já com o comprovante carregado.
class ReportLine {
  const ReportLine({
    required this.date,
    required this.activity,
    required this.client,
    required this.column,
    required this.categoryName,
    required this.amount,
    required this.notes,
    this.receiptPages = const [],
    this.receiptSummary = const [],
    this.receiptMissing = false,
  });

  final DateTime date;
  final String activity;
  final String client;
  final ReportColumn column;
  final String categoryName;
  final double amount;
  final String notes;

  /// Imagens (JPEG/PNG) do comprovante. Um PDF de várias páginas vira várias imagens.
  final List<Uint8List> receiptPages;

  /// Comprovante em texto (NF-e importada pelo XML), quando não há imagem.
  final List<String> receiptSummary;

  /// A despesa não tem comprovante (alerta vermelho no relatório).
  final bool receiptMissing;
}

class ReportData {
  ReportData({
    required this.ownerName,
    required this.start,
    required this.end,
    required List<ReportLine> lines,
    required this.advances,
    this.ownerCpfMasked = '',
    this.ownerEmail = '',
    this.ownerPlate = '',
    DateTime? generatedAt,
  })  : lines = [...lines]..sort((a, b) => a.date.compareTo(b.date)),
        generatedAt = generatedAt ?? DateTime.now();

  final String ownerName;
  final String ownerCpfMasked;
  final String ownerEmail;
  final String ownerPlate;
  final DateTime start;
  final DateTime end;

  /// Ordenadas por data, como os comprovantes no PDF.
  final List<ReportLine> lines;
  final double advances;
  final DateTime generatedAt;

  double get subtotal => cents(lines.fold(0.0, (s, l) => s + l.amount));
  double get total => cents(subtotal - advances);
  int get missingReceipts => lines.where((l) => l.receiptMissing).length;

  double columnTotal(ReportColumn c) =>
      cents(lines.where((l) => l.column == c).fold(0.0, (s, l) => s + l.amount));

  String get fileBaseName => reportFileBaseName(start, end, ownerName);
}

/// "Relatório de gastos técnicos 24-10-2026_05-11-2026_LEONARDO LIMA",
/// igual ao padrão do modelo DJ PRIMUS.
String reportFileBaseName(DateTime start, DateTime end, String name) {
  String d(DateTime x) =>
      '${x.day.toString().padLeft(2, '0')}-${x.month.toString().padLeft(2, '0')}-${x.year}';
  final safeName = name.trim().toUpperCase().replaceAll(RegExp(r'[\\/:*?"<>|]'), '').replaceAll(RegExp(r'\s+'), ' ');
  return 'Relatório de gastos técnicos ${d(start)}_${d(end)}_$safeName';
}
