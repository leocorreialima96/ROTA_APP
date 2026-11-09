import 'package:xml/xml.dart';

import 'receipt_text_parser.dart';

/// Dados de uma NF-e/NFC-e importada pelo XML.
class ParsedNfe {
  const ParsedNfe({
    required this.total,
    required this.date,
    required this.issuerName,
    required this.issuerCnpj,
    required this.accessKey,
    required this.items,
    this.categoryId,
  });

  final double total;
  final DateTime date;
  final String issuerName;
  final String issuerCnpj;
  final String accessKey;
  final List<String> items;
  final String? categoryId;
}

class NfeParseException implements Exception {
  NfeParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lê o XML de uma NF-e (modelo 55) ou NFC-e (modelo 65), com ou sem o
/// envelope nfeProc.
class NfeParser {
  static ParsedNfe parse(String xmlText) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xmlText);
    } on XmlException {
      throw NfeParseException('O arquivo não é um XML válido.');
    }
    final inf = _first(doc, 'infNFe');
    if (inf == null) throw NfeParseException('Este XML não é de uma NF-e.');

    final ide = _first(inf, 'ide');
    final emit = _first(inf, 'emit');
    final tot = _first(inf, 'ICMSTot');

    final vNF = _text(tot, 'vNF');
    final total = double.tryParse(vNF ?? '');
    if (total == null) throw NfeParseException('Não encontrei o valor total (vNF) na nota.');

    final dh = _text(ide, 'dhEmi') ?? _text(ide, 'dEmi');
    final date = _parseDate(dh);
    if (date == null) throw NfeParseException('Não encontrei a data de emissão na nota.');

    final name = _text(emit, 'xFant') ?? _text(emit, 'xNome') ?? '';
    final items = inf.findAllElements('xProd').map((e) => e.innerText.trim()).toList();
    final key = (inf.getAttribute('Id') ?? '').replaceFirst('NFe', '');

    return ParsedNfe(
      total: total,
      date: date,
      issuerName: name,
      issuerCnpj: _text(emit, 'CNPJ') ?? '',
      accessKey: key,
      items: items,
      categoryId: ReceiptTextParser.guessCategory('$name ${items.join(' ')}'),
    );
  }

  static XmlElement? _first(XmlNode? node, String name) {
    if (node == null) return null;
    final it = node.findAllElements(name);
    return it.isEmpty ? null : it.first;
  }

  static String? _text(XmlNode? node, String name) {
    final e = _first(node, name);
    final t = e?.innerText.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  /// "2026-11-05T14:32:10-03:00" ou "2026-11-05": usa a data local da nota.
  static DateTime? _parseDate(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (m == null) return null;
    return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }
}
