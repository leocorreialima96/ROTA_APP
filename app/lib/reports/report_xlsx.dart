import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/category.dart';
import 'report_data.dart';

/// Gera a planilha no modelo "RELATÓRIO DE DESPESAS" da DJ PRIMUS:
/// cabeçalho na linha 7, despesas a partir da linha 8 nas colunas B a L
/// (Data, Conta, Cliente, Hotel, Pedágio, Combustível, Ferramentas/Outros,
/// Estacionamento/Lava Rápido, Refeições, Observação, Total), com as
/// fórmulas de total, adiantamentos e total a reembolsar.
class ReportXlsx {
  static const sheetName = 'RELATÓRIO DE DESPESAS';
  static const firstDataRow = 8; // linha do Excel (1-based)

  static const _red = 'FFB0381C';
  static const _grey = 'FFA6A6A6';
  static const _money = '"R\$" #,##0.00;-"R\$" #,##0.00';

  static const columns = <ReportColumn>[
    ReportColumn.hotel,
    ReportColumn.pedagio,
    ReportColumn.combustivel,
    ReportColumn.outros,
    ReportColumn.estacionamento,
    ReportColumn.refeicoes,
  ];

  static Uint8List build(ReportData data) {
    final excel = Excel.createExcel();
    final defaultName = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultName, sheetName);
    final s = excel[sheetName];

    CellIndex at(String col, int row) => CellIndex.indexByString('$col$row');
    final thin = Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString(_grey));
    final strong = Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString(_red));
    final moneyFmt = NumFormat.custom(formatCode: _money);
    final dateFmt = NumFormat.custom(formatCode: 'dd/mm/yyyy');

    void put(String col, int row, CellValue? v, CellStyle style) {
      s.updateCell(at(col, row), v, cellStyle: style);
    }

    // Título e dados do colaborador.
    s.merge(at('B', 2), at('L', 2));
    put('B', 2, TextCellValue('RELATÓRIO DE DESPESAS'), CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString(_red),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    ));
    final label = CellStyle(bold: true);
    put('B', 4, TextCellValue('Colaborador:'), label);
    put('C', 4, TextCellValue(data.ownerName.toUpperCase()), CellStyle());
    put('B', 5, TextCellValue('Período:'), label);
    put('C', 5, TextCellValue('${_d(data.start)} a ${_d(data.end)}'), CellStyle());
    if (data.ownerCpfMasked.isNotEmpty) {
      put('E', 4, TextCellValue('CPF:'), label);
      put('F', 4, TextCellValue(data.ownerCpfMasked), CellStyle());
    }
    if (data.ownerPlate.isNotEmpty) {
      put('E', 5, TextCellValue('Placa:'), label);
      put('F', 5, TextCellValue(data.ownerPlate.toUpperCase()), CellStyle());
    }

    // Cabeçalho da tabela.
    const headerRow = 7;
    final headers = <String>[
      'Data',
      'Conta',
      'Cliente',
      ...columns.map((c) => c.label),
      'Observação',
      'Total',
    ];
    const letters = ['B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'];
    for (var i = 0; i < letters.length; i++) {
      put(letters[i], headerRow, TextCellValue(headers[i]), CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.fromHexString(_red),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
        leftBorder: i == 0 ? strong : thin,
        rightBorder: i == letters.length - 1 ? strong : thin,
        topBorder: strong,
        bottomBorder: strong,
      ));
    }

    // Linhas de despesas.
    final lines = data.lines;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final r = firstDataRow + i;
      CellStyle cell({NumFormat? fmt, HorizontalAlign h = HorizontalAlign.Left, bool first = false, bool last = false, bool red = false}) => CellStyle(
            numberFormat: fmt ?? NumFormat.standard_0,
            horizontalAlign: h,
            verticalAlign: VerticalAlign.Center,
            textWrapping: TextWrapping.WrapText,
            fontColorHex: red ? ExcelColor.fromHexString('FFB42318') : ExcelColor.black,
            leftBorder: first ? strong : thin,
            rightBorder: last ? strong : thin,
            topBorder: thin,
            bottomBorder: thin,
          );
      put('B', r, DateCellValue.fromDateTime(l.date), cell(fmt: dateFmt, h: HorizontalAlign.Center, first: true));
      put('C', r, TextCellValue(l.activity), cell());
      put('D', r, TextCellValue(l.client), cell());
      for (var c = 0; c < columns.length; c++) {
        final col = letters[3 + c];
        if (columns[c] == l.column) {
          put(col, r, DoubleCellValue(l.amount), cell(fmt: moneyFmt, h: HorizontalAlign.Right));
        } else {
          put(col, r, null, cell(fmt: moneyFmt));
        }
      }
      final obs = [
        if (l.receiptMissing) 'SEM COMPROVANTE',
        if (l.notes.isNotEmpty) l.notes,
      ].join(' · ');
      put('K', r, TextCellValue(obs), cell(red: l.receiptMissing));
      put('L', r, FormulaCellValue('SUM(E$r:J$r)'), cell(fmt: moneyFmt, h: HorizontalAlign.Right, last: true));
    }

    // Totais por coluna.
    final lastData = firstDataRow + (lines.isEmpty ? 0 : lines.length - 1);
    final totalRow = lastData + 1;
    final totalStyle = CellStyle(
      bold: true,
      numberFormat: moneyFmt,
      horizontalAlign: HorizontalAlign.Right,
      backgroundColorHex: ExcelColor.fromHexString('FFF6F1E7'),
      topBorder: strong,
      bottomBorder: strong,
      leftBorder: thin,
      rightBorder: thin,
    );
    put('B', totalRow, TextCellValue('Total'), CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('FFF6F1E7'), topBorder: strong, bottomBorder: strong, leftBorder: strong));
    put('C', totalRow, null, totalStyle);
    put('D', totalRow, null, totalStyle);
    for (var c = 0; c < columns.length; c++) {
      final col = letters[3 + c];
      put(col, totalRow, FormulaCellValue('SUM($col$firstDataRow:$col$lastData)'), totalStyle);
    }
    put('K', totalRow, null, totalStyle);
    put('L', totalRow, FormulaCellValue('SUM(L$firstDataRow:L$lastData)'), totalStyle.copyWith(rightBorderVal: strong));

    // Subtotal, adiantamentos e total a reembolsar.
    final sub = totalRow + 2;
    final bold = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Right);
    final money = CellStyle(numberFormat: moneyFmt, horizontalAlign: HorizontalAlign.Right);
    put('K', sub, TextCellValue('SUBTOTAL'), bold);
    put('L', sub, FormulaCellValue('L$totalRow'), money);
    put('K', sub + 1, TextCellValue('ADIANTAMENTOS'), bold);
    put('L', sub + 1, DoubleCellValue(data.advances), money);
    put('K', sub + 2, TextCellValue('TOTAL A REEMBOLSAR'), bold);
    put('L', sub + 2, FormulaCellValue('L$sub-L${sub + 1}'), CellStyle(
      bold: true,
      numberFormat: moneyFmt,
      horizontalAlign: HorizontalAlign.Right,
      topBorder: strong,
      bottomBorder: strong,
    ));

    // Larguras parecidas com as do modelo.
    const widths = <int, double>{0: 2, 1: 12, 2: 34, 3: 22, 4: 12, 5: 12, 6: 14, 7: 16, 8: 18, 9: 13, 10: 36, 11: 14};
    widths.forEach(s.setColumnWidth);
    s.setRowHeight(headerRow - 1, 32);

    return Uint8List.fromList(excel.encode()!);
  }

  static String _d(DateTime x) =>
      '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
}
