import 'package:flutter_test/flutter_test.dart';
import 'package:rota/parsing/receipt_text_parser.dart';

void main() {
  final parser = ReceiptTextParser(now: () => DateTime(2026, 11, 9));

  test('cupom de posto: total, data, CNPJ, nome e categoria', () {
    const text = '''
AUTO POSTO EXEMPLO LTDA
CNPJ: 12.345.678/0001-95
RUA DAS FLORES, 100 - SANTO ANDRE SP
DOCUMENTO AUXILIAR DA NOTA FISCAL DE CONSUMIDOR ELETRONICA
GASOLINA COMUM 30,000 LT X 5,00 150,00
QTD. TOTAL DE ITENS 1
VALOR TOTAL R\$ 150,00
FORMA PAGAMENTO VALOR PAGO
CARTAO DE CREDITO 150,00
Tributos aprox. Lei 12.741 R\$ 45,30
05/11/2026 14:32:10
''';
    final r = parser.parse(text);
    expect(r.total, 150.00);
    expect(r.date, DateTime(2026, 11, 5));
    expect(r.cnpj, '12345678000195');
    expect(r.merchant, 'Auto Posto Exemplo LTDA');
    expect(r.categoryId, 'combustivel');
  });

  test('restaurante com troco e valor na linha de baixo', () {
    const text = '''
RESTAURANTE SABOR CASEIRO
CNPJ 11.222.333/0001-81
EMISSAO: 04/11/26 12:10
1 PRATO EXECUTIVO 39,90
1 SUCO 9,00
TOTAL A PAGAR
48,90
DINHEIRO 50,00
TROCO 1,10
''';
    final r = parser.parse(text);
    expect(r.total, 48.90);
    expect(r.date, DateTime(2026, 11, 4));
    expect(r.categoryId, 'refeicoes');
  });

  test('valores com milhar e hotel', () {
    const text = '''
HOTEL CENTRAL PARK
Hospedagem 3 diarias
Data 28/10/2026
Valor total: 1.290,00
''';
    final r = parser.parse(text);
    expect(r.total, 1290.00);
    expect(r.categoryId, 'hotel');
    expect(r.date, DateTime(2026, 10, 28));
  });

  test('ignora data no futuro e cai no maior valor sem rótulo', () {
    const text = '''
PRACA DE PEDAGIO 3
VALIDO ATE 31/12/2030
12/11/2026
CAT 1 12,40
''';
    final r = parser.parse(text);
    expect(r.total, 12.40);
    expect(r.date, isNull, reason: '12/11 é depois de hoje (09/11) e 2030 também');
    expect(r.categoryId, 'pedagio');
  });

  test('lava-rápido vem antes de estacionamento', () {
    expect(ReceiptTextParser.guessCategory('Lava Rápido e Estacionamento do Zé'), 'lava_rapido');
    expect(ReceiptTextParser.guessCategory('Estapar estacionamento'), 'estacionamento');
    expect(ReceiptTextParser.guessCategory('Mercadinho'), isNull);
  });

  test('texto vazio', () {
    expect(parser.parse('').isEmpty, isTrue);
  });
}
