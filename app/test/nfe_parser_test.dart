import 'package:flutter_test/flutter_test.dart';
import 'package:rota/parsing/nfe_parser.dart';

const _nfe = '''<?xml version="1.0" encoding="UTF-8"?>
<nfeProc xmlns="http://www.portalfiscal.inf.br/nfe" versao="4.00">
  <NFe>
    <infNFe Id="NFe35261112345678000195650010000012341000012345" versao="4.00">
      <ide><mod>65</mod><dhEmi>2026-11-05T14:32:10-03:00</dhEmi></ide>
      <emit>
        <CNPJ>12345678000195</CNPJ>
        <xNome>AUTO POSTO EXEMPLO LTDA</xNome>
        <xFant>Posto Exemplo</xFant>
      </emit>
      <det nItem="1"><prod><xProd>GASOLINA COMUM</xProd></prod></det>
      <total><ICMSTot><vProd>150.00</vProd><vNF>150.00</vNF></ICMSTot></total>
    </infNFe>
  </NFe>
</nfeProc>''';

void main() {
  test('lê total, data, emitente e chave de acesso', () {
    final n = NfeParser.parse(_nfe);
    expect(n.total, 150.0);
    expect(n.date, DateTime(2026, 11, 5));
    expect(n.issuerName, 'Posto Exemplo');
    expect(n.issuerCnpj, '12345678000195');
    expect(n.accessKey, '35261112345678000195650010000012341000012345');
    expect(n.items, ['GASOLINA COMUM']);
    expect(n.categoryId, 'combustivel');
  });

  test('erros claros para arquivos que não são NF-e', () {
    expect(() => NfeParser.parse('não é xml'), throwsA(isA<NfeParseException>()));
    expect(() => NfeParser.parse('<a><b/></a>'), throwsA(isA<NfeParseException>()));
  });
}
