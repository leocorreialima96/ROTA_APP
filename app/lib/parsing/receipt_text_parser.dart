import 'text_normalize.dart';

/// O que conseguimos tirar do texto de uma nota fotografada.
class ParsedReceipt {
  const ParsedReceipt({this.total, this.date, this.cnpj, this.merchant, this.categoryId});

  final double? total;
  final DateTime? date;
  final String? cnpj;
  final String? merchant;

  /// Id de uma das categorias padrão, se o texto deixar claro.
  final String? categoryId;

  bool get isEmpty => total == null && date == null && merchant == null;
}

/// Lê o texto reconhecido (OCR) de cupons e notas brasileiras.
///
/// Funciona sem internet: o reconhecimento de texto roda no aparelho (ML Kit)
/// e esta classe só interpreta o texto. É Dart puro, coberto por testes.
class ReceiptTextParser {
  ReceiptTextParser({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  static final _money = RegExp(r'(?<![\d,.])(\d{1,3}(?:\.\d{3})+,\d{2}|\d+,\d{2}|\d+\.\d{2})(?![\d])');
  static final _date = RegExp(r'(?<!\d)(\d{2})[/.\-](\d{2})[/.\-](\d{4}|\d{2})(?!\d)');
  static final _cnpj = RegExp(r'(?<!\d)(\d{2}\.?\d{3}\.?\d{3}/?\d{4}-?\d{2})(?!\d)');

  /// Rótulos de total, do mais confiável ao menos confiável.
  static const _totalLabels = [
    'VALOR A PAGAR',
    'TOTAL A PAGAR',
    'VALOR PAGO',
    'VALOR TOTAL',
    'TOTAL R\$',
    'TOTAL GERAL',
    'TOTAL',
    'VALOR',
  ];

  /// Linhas que têm valores mas não são o total.
  static const _ignore = [
    'TROCO',
    'DESCONTO',
    'TRIBUTO',
    'APROX',
    'LEI 12.741',
    'IMPOSTO',
    'SUBTOTAL',
    'QTD',
    'QTDE',
    'ITENS',
    'ACRESCIMO',
    'TAXA DE SERVICO',
    'DINHEIRO',
    'RECEBIDO',
  ];

  static const _categoryKeywords = <String, List<String>>{
    'combustivel': ['POSTO', 'GASOLINA', 'ETANOL', 'DIESEL', 'COMBUSTIVEL', 'ARLA', 'AUTO POSTO', 'GNV', 'LITROS', ' LT '],
    'hotel': ['HOTEL', 'POUSADA', 'HOSPEDAGEM', 'DIARIA', 'MOTEL', 'HOSTEL', 'INN '],
    'pedagio': ['PEDAGIO', 'PRACA', 'CONCESSIONARIA', 'RODOVIA', 'SEM PARAR', 'CONECTCAR', 'VELOE', 'ARTERIS', 'ECOVIAS', 'AUTOBAN', 'VIAOESTE', 'CCR '],
    'lava_rapido': ['LAVA RAPIDO', 'LAVA-RAPIDO', 'LAVAGEM', 'LAVA JATO', 'LAVAJATO', 'ESTETICA AUTOMOTIVA'],
    'estacionamento': ['ESTACIONAMENTO', 'PARKING', 'ESTAPAR', 'ZONA AZUL', 'GARAGEM', 'MULTIPARK', 'INDIGO'],
    'refeicoes': ['RESTAURANTE', 'LANCHONETE', 'PADARIA', 'CAFE', 'REFEICAO', 'PIZZARIA', 'CHURRASCARIA', 'BAR ', 'LANCHE', 'SELF SERVICE', 'BUFFET', 'SORVETERIA', 'PANIFICADORA', 'MARMITA', 'GRILL', 'BURGER'],
    'ferramentas': ['FERRAGENS', 'FERRAMENTA', 'MATERIAIS', 'MATERIAL ELETRICO', 'PARAFUSO', 'LEROY', 'TELHANORTE', 'C&C'],
  };

  ParsedReceipt parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final norm = lines.map(normalize).toList();
    final all = ' ${norm.join(' ')} ';
    return ParsedReceipt(
      total: _findTotal(norm),
      date: _findDate(norm),
      cnpj: _findCnpj(all),
      merchant: _findMerchant(lines, norm),
      categoryId: guessCategory(all),
    );
  }

  /// Sugere a categoria pelo texto da nota (padrões de posto, hotel etc.).
  static String? guessCategory(String text) {
    final t = ' ${normalize(text)} ';
    // Ordem importa: "AUTO POSTO" com lanche ainda é posto; lava-rápido antes
    // de estacionamento.
    for (final entry in _categoryKeywords.entries) {
      for (final k in entry.value) {
        if (t.contains(k)) return entry.key;
      }
    }
    return null;
  }

  double? _findTotal(List<String> lines) {
    for (final label in _totalLabels) {
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (!l.contains(label)) continue;
        if (_ignore.any(l.contains)) continue;
        final here = _moneys(l.substring(l.indexOf(label)));
        if (here.isNotEmpty) return here.last;
        // Valor na linha de baixo (comum em cupons com colunas).
        if (i + 1 < lines.length && !_ignore.any(lines[i + 1].contains)) {
          final next = _moneys(lines[i + 1]);
          if (next.isNotEmpty) return next.first;
        }
      }
    }
    // Sem rótulo: maior valor que não esteja numa linha ignorada.
    double? best;
    for (final l in lines) {
      if (_ignore.any(l.contains)) continue;
      for (final v in _moneys(l)) {
        if (best == null || v > best) best = v;
      }
    }
    return best;
  }

  List<double> _moneys(String line) {
    // Evita confundir CNPJ, datas e horários com dinheiro.
    final cleaned = line.replaceAll(_cnpj, ' ').replaceAll(_date, ' ').replaceAll(RegExp(r'\d{2}:\d{2}(:\d{2})?'), ' ');
    return _money.allMatches(cleaned).map((m) {
      final s = m.group(1)!;
      if (s.contains(',')) return double.parse(s.replaceAll('.', '').replaceAll(',', '.'));
      return double.parse(s);
    }).where((v) => v > 0 && v < 1000000).toList();
  }

  DateTime? _findDate(List<String> lines) {
    final now = _now();
    final limit = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    for (final l in lines) {
      for (final m in _date.allMatches(l)) {
        final d = int.parse(m.group(1)!);
        final mo = int.parse(m.group(2)!);
        var y = int.parse(m.group(3)!);
        if (y < 100) y += 2000;
        if (mo < 1 || mo > 12 || d < 1 || d > 31) continue;
        final date = DateTime(y, mo, d);
        if (date.month != mo) continue; // 31/02 etc.
        if (date.isAfter(limit) || y < now.year - 2) continue;
        return date;
      }
    }
    return null;
  }

  String? _findCnpj(String all) {
    final m = _cnpj.firstMatch(all);
    if (m == null) return null;
    final d = m.group(1)!.replaceAll(RegExp(r'\D'), '');
    return d.length == 14 ? d : null;
  }

  static const _notMerchant = [
    'CNPJ', 'CPF', 'CUPOM', 'DOCUMENTO', 'NFC-E', 'NFCE', 'NOTA FISCAL', 'DANFE', 'EXTRATO',
    'SAT', 'CONSUMIDOR', 'INSCRICAO', 'IE:', 'I.E', 'ENDERECO', 'RUA ', 'AV ', 'AV.', 'TEL', 'FONE',
    'BEM VINDO', 'BEM-VINDO', 'VOLTE SEMPRE',
  ];

  String? _findMerchant(List<String> raw, List<String> norm) {
    for (var i = 0; i < norm.length && i < 8; i++) {
      final l = norm[i];
      if (_notMerchant.any(l.contains)) continue;
      final letters = l.replaceAll(RegExp(r'[^A-Z]'), '');
      if (letters.length < 3) continue;
      if (RegExp(r'\d{5,}').hasMatch(l)) continue;
      return _titleCase(raw[i]);
    }
    return null;
  }

  static String _titleCase(String s) => s
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((w) => w.length <= 2 && w != w.toUpperCase() ? w : (w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)))
      .join(' ')
      .replaceAllMapped(RegExp(r'\b(Ltda|Me|Eireli|Epp|S\/A|Sa)\b'), (m) => m.group(0)!.toUpperCase());
}
