import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rota/models/category.dart';
import 'package:rota/reports/report_data.dart';
import 'package:rota/reports/report_pdf.dart';
import 'package:rota/reports/report_xlsx.dart';

final _png = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 6)));

ReportData _data() => ReportData(
      ownerName: 'Leonardo Lima',
      ownerCpfMasked: '***.982.247-**',
      start: DateTime(2026, 10, 24),
      end: DateTime(2026, 11, 5),
      advances: 300,
      generatedAt: DateTime(2026, 11, 9),
      lines: [
        ReportLine(
          date: DateTime(2026, 11, 5),
          activity: 'Visita técnica · linha de solda',
          client: 'Cliente A',
          column: ReportColumn.combustivel,
          categoryName: 'Combustível',
          amount: 150,
          notes: 'km 45.210 a 45.398',
          receiptPages: [_png],
        ),
        ReportLine(
          date: DateTime(2026, 10, 24),
          activity: 'Hospedagem',
          client: 'Cliente A',
          column: ReportColumn.hotel,
          categoryName: 'Hotel',
          amount: 490,
          notes: '',
          receiptPages: [_png, _png],
        ),
        ReportLine(
          date: DateTime(2026, 11, 4),
          activity: 'Pedágio ida',
          client: 'Cliente B',
          column: ReportColumn.pedagio,
          categoryName: 'Pedágio',
          amount: 12.4,
          notes: '',
          receiptMissing: true,
        ),
      ],
    );

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  test('nome do arquivo no padrão do modelo', () {
    expect(
      reportFileBaseName(DateTime(2026, 10, 24), DateTime(2026, 11, 5), 'Leonardo  Lima'),
      'Relatório de gastos técnicos 24-10-2026_05-11-2026_LEONARDO LIMA',
    );
  });

  test('ordena por data e soma subtotal e total a reembolsar', () {
    final d = _data();
    expect(d.lines.first.date, DateTime(2026, 10, 24));
    expect(d.subtotal, 652.4);
    expect(d.total, 352.4);
    expect(d.columnTotal(ReportColumn.hotel), 490);
    expect(d.missingReceipts, 1);
  });

  test('planilha no modelo DJ PRIMUS', () {
    final bytes = ReportXlsx.build(_data());
    final x = Excel.decodeBytes(bytes);
    final s = x.tables[ReportXlsx.sheetName]!;
    String txt(String a1) => s.cell(CellIndex.indexByString(a1)).value.toString();
    expect(txt('B2'), 'RELATÓRIO DE DESPESAS');
    expect(txt('B7'), 'Data');
    expect(txt('E7'), 'Hotel');
    expect(txt('H7'), 'Ferramentas/Outros');
    expect(txt('I7'), 'Estacionamento/Lava Rápido');
    expect(txt('L7'), 'Total');
    // Linha 8 = despesa mais antiga (hotel), valor na coluna E.
    expect(txt('C8'), 'Hospedagem');
    expect(num.parse(txt('E8')), 490);
    expect(txt('L8'), contains('SUM(E8:J8)'));
    expect(txt('K9'), contains('SEM COMPROVANTE'));
    // Totais na linha 11, adiantamento na 14.
    expect(txt('L11'), contains('SUM(L8:L10)'));
    expect(txt('K15'), 'TOTAL A REEMBOLSAR');
    expect(num.parse(txt('L14')), 300);
  });

  test('PDF: relatório + 1 página por comprovante (e página de alerta)', () async {
    ByteData font(String f) => ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync());
    final bytes = await ReportPdf.build(_data(), regular: font('Inter-Regular.ttf'), bold: font('Inter-Bold.ttf'));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final text = String.fromCharCodes(bytes);
    // 1 página de relatório + 2 do hotel + 1 do combustível + 1 "não anexado".
    expect(RegExp(r'/Type\s*/Page\b').allMatches(text).length, 5);
  });
}
