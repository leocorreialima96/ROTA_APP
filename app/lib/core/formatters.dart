import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'cpf.dart';

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);
final _dmy = DateFormat('dd/MM/yyyy');
final _dm = DateFormat('dd/MM');

/// R$ 1.284,50
String brl(num value) => _brl.format(value).replaceAll(' ', ' ');

/// 05/11/2026
String dmy(DateTime d) => _dmy.format(d);

/// 05/11
String dm(DateTime d) => _dm.format(d);

/// Datas de despesa são guardadas como texto "AAAA-MM-DD" para não sofrer
/// com fuso horário e para ordenar direto no banco.
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseIsoDay(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// Converte "1.284,50", "1284.50", "R$ 12,4" em double. Retorna null se não der.
double? parseMoney(String input) {
  var s = input.replaceAll(RegExp(r'[^\d,.\-]'), '');
  if (s.isEmpty) return null;
  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma > lastDot) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (lastDot > lastComma && lastComma >= 0) {
    s = s.replaceAll(',', '');
  } else if (lastDot >= 0 && lastComma < 0) {
    // "1.284" (milhar) vs "12.40" (decimal): decimal só com 1 ou 2 casas.
    final decimals = s.length - lastDot - 1;
    if (decimals == 3 && RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
      s = s.replaceAll('.', '');
    }
  }
  return double.tryParse(s);
}

/// Arredonda para centavos.
double cents(double v) => (v * 100).roundToDouble() / 100;

/// Máscara de CPF para TextField.
class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final f = Cpf.format(newValue.text);
    return TextEditingValue(text: f, selection: TextSelection.collapsed(offset: f.length));
  }
}

/// Máscara de moeda que trata a digitação como centavos: "1", "12", "1250" -> 12,50.
class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return const TextEditingValue(text: '');
    final v = int.parse(d.length > 12 ? d.substring(0, 12) : d) / 100;
    final f = NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: 2).format(v);
    return TextEditingValue(text: f, selection: TextSelection.collapsed(offset: f.length));
  }
}

String moneyField(double v) =>
    NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: 2).format(v);
