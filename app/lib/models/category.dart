import 'package:flutter/material.dart';

/// Colunas do relatório no modelo DJ PRIMUS. O modelo junta Ferramentas com
/// Outros e Estacionamento com Lava Rápido (decisão em aberto na especificação:
/// por enquanto seguimos o modelo deles).
enum ReportColumn {
  hotel('Hotel'),
  pedagio('Pedágio'),
  combustivel('Combustível'),
  outros('Ferramentas/Outros'),
  estacionamento('Estacionamento/Lava Rápido'),
  refeicoes('Refeições');

  const ReportColumn(this.label);
  final String label;

  static ReportColumn fromName(String? name) =>
      ReportColumn.values.firstWhere((c) => c.name == name, orElse: () => ReportColumn.outros);
}

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.order,
    required this.column,
    this.maxPerExpense,
  });

  final String id;
  final String name;
  final int color;
  final int order;
  final ReportColumn column;

  /// Limite opcional por despesa (as outras formas de limite entram na fase 3).
  final double? maxPerExpense;

  Color get colorValue => Color(color);

  /// Versão clara da cor, usada em fundos de chips e ícones.
  Color get softColor => Color.alphaBlend(Color(color).withValues(alpha: 0.18), Colors.white);

  String get initials {
    final letters = name.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ ]'), '').trim();
    if (letters.isEmpty) return '?';
    final parts = letters.split(RegExp(r'\s+'));
    if (parts.length > 1) return (parts[0][0] + parts[1][0]).toUpperCase();
    return letters.substring(0, letters.length >= 2 ? 2 : 1).toUpperCase();
  }

  ExpenseCategory copyWith({String? name, int? color, int? order, ReportColumn? column, double? maxPerExpense, bool clearMax = false}) =>
      ExpenseCategory(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
        order: order ?? this.order,
        column: column ?? this.column,
        maxPerExpense: clearMax ? null : (maxPerExpense ?? this.maxPerExpense),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'order': order,
        'column': column.name,
        if (maxPerExpense != null) 'maxPerExpense': maxPerExpense,
      };

  factory ExpenseCategory.fromMap(Map<String, dynamic> m) => ExpenseCategory(
        id: m['id'] as String,
        name: m['name'] as String,
        color: (m['color'] as num).toInt(),
        order: (m['order'] as num?)?.toInt() ?? 0,
        column: ReportColumn.fromName(m['column'] as String?),
        maxPerExpense: (m['maxPerExpense'] as num?)?.toDouble(),
      );

  /// Categorias padrão da especificação, com as cores do protótipo.
  static const defaults = <ExpenseCategory>[
    ExpenseCategory(id: 'hotel', name: 'Hotel', color: 0xFF8B5CF6, order: 0, column: ReportColumn.hotel),
    ExpenseCategory(id: 'pedagio', name: 'Pedágio', color: 0xFF14B8A6, order: 1, column: ReportColumn.pedagio),
    ExpenseCategory(id: 'combustivel', name: 'Combustível', color: 0xFFFFB020, order: 2, column: ReportColumn.combustivel),
    ExpenseCategory(id: 'refeicoes', name: 'Refeições', color: 0xFFFF6B4A, order: 3, column: ReportColumn.refeicoes),
    ExpenseCategory(id: 'ferramentas', name: 'Ferramentas', color: 0xFF3B82F6, order: 4, column: ReportColumn.outros),
    ExpenseCategory(id: 'outros', name: 'Outros', color: 0xFF64748B, order: 5, column: ReportColumn.outros),
    ExpenseCategory(id: 'estacionamento', name: 'Estacionamento', color: 0xFFEC4899, order: 6, column: ReportColumn.estacionamento),
    ExpenseCategory(id: 'lava_rapido', name: 'Lava rápido', color: 0xFF06B6D4, order: 7, column: ReportColumn.estacionamento),
  ];

  /// Paleta oferecida ao criar uma categoria nova.
  static const palette = <int>[
    0xFF8B5CF6, 0xFF14B8A6, 0xFFFFB020, 0xFFFF6B4A, 0xFF3B82F6, 0xFF84CC16,
    0xFFEC4899, 0xFF06B6D4, 0xFF64748B, 0xFFB45309, 0xFF2F9E5B, 0xFFE5483A,
  ];
}

/// Configurações do modo individual (tela 5).
class IndividualSettings {
  const IndividualSettings({required this.categories, this.byProject = false});

  final List<ExpenseCategory> categories;
  final bool byProject;

  static IndividualSettings get defaults => const IndividualSettings(categories: ExpenseCategory.defaults);

  List<ExpenseCategory> get sorted => [...categories]..sort((a, b) => a.order.compareTo(b.order));

  ExpenseCategory? byId(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
        'categories': categories.map((c) => c.toMap()).toList(),
        'byProject': byProject,
      };

  factory IndividualSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return defaults;
    final list = (m['categories'] as List?)
            ?.map((e) => ExpenseCategory.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        ExpenseCategory.defaults;
    return IndividualSettings(categories: list.isEmpty ? ExpenseCategory.defaults : list, byProject: m['byProject'] == true);
  }
}
