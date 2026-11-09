import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rota/core/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  test('moeda em reais', () {
    expect(brl(1284.5), 'R\$ 1.284,50');
    expect(brl(0), 'R\$ 0,00');
  });

  test('lê valores digitados de vários jeitos', () {
    expect(parseMoney('1.284,50'), 1284.50);
    expect(parseMoney('R\$ 12,4'), 12.40);
    expect(parseMoney('1284.50'), 1284.50);
    expect(parseMoney('1.284'), 1284);
    expect(parseMoney('abc'), isNull);
  });

  test('datas ISO sem fuso', () {
    expect(isoDay(DateTime(2026, 3, 7)), '2026-03-07');
    expect(parseIsoDay('2026-03-07'), DateTime(2026, 3, 7));
  });
}
