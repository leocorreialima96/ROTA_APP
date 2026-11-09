import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/formatters.dart';

enum ExpenseSource { camera, gallery, manual, pdf, nfe }

/// Onde está o comprovante.
enum ReceiptState {
  /// Despesa sem comprovante: alerta vermelho em todas as telas e no relatório.
  none,

  /// Guardado só no celular, esperando sinal para subir.
  local,

  /// Já está no Cloud Storage.
  uploaded,
}

class Expense {
  const Expense({
    required this.id,
    required this.ownerId,
    required this.date,
    required this.client,
    required this.activity,
    required this.categoryId,
    required this.noteAmount,
    required this.amount,
    required this.notes,
    required this.receiptState,
    required this.source,
    required this.localCreatedAt,
    this.vehicleNotes = '',
    this.merchant = '',
    this.receiptPath,
    this.receiptContentType,
    this.reportId,
    this.projectId,
    this.splitPeople = 1,
    this.hasPendingWrites = false,
  });

  final String id;
  final String ownerId;

  /// Dia da despesa ("AAAA-MM-DD").
  final String date;
  final String client;

  /// "Conta" no modelo DJ PRIMUS: fornecedor e motivo da visita.
  final String activity;
  final String categoryId;

  /// Valor total da nota.
  final double noteAmount;

  /// Valor que vai no relatório (pode ser menor, se a conta foi dividida).
  final double amount;
  final String notes;

  /// Observação opcional do veículo (combustível): km de início e fim, trajeto.
  final String vehicleNotes;
  final String merchant;
  final ReceiptState receiptState;
  final String? receiptPath;
  final String? receiptContentType;
  final ExpenseSource source;
  final String? reportId;
  final String? projectId;
  final int splitPeople;
  final DateTime localCreatedAt;

  /// Verdadeiro enquanto a gravação ainda não chegou ao servidor.
  final bool hasPendingWrites;

  DateTime get day => parseIsoDay(date);
  bool get isClosed => reportId != null;
  bool get hasReceipt => receiptState != ReceiptState.none;
  bool get isAdjusted => (noteAmount - amount).abs() >= 0.005;

  /// "Salva na nuvem" só quando os dados e a foto já subiram.
  bool get savedInCloud => !hasPendingWrites && receiptState != ReceiptState.local;

  /// Observação que vai no relatório. Quando o valor foi dividido ou ajustado,
  /// o total da nota fica registrado aqui, como pede a especificação.
  String get reportNotes {
    final parts = <String>[
      if (notes.trim().isNotEmpty) notes.trim(),
      if (vehicleNotes.trim().isNotEmpty) vehicleNotes.trim(),
      if (isAdjusted)
        splitPeople > 1
            ? 'Nota de ${brl(noteAmount)} dividida entre $splitPeople pessoas'
            : 'Valor total da nota: ${brl(noteAmount)}',
    ];
    return parts.join(' · ');
  }

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'companyId': null,
        'date': date,
        'client': client,
        'activity': activity,
        'categoryId': categoryId,
        'noteAmount': noteAmount,
        'amount': amount,
        'splitPeople': splitPeople,
        'notes': notes,
        'vehicleNotes': vehicleNotes,
        'merchant': merchant,
        'receipt': {
          'state': receiptState.name,
          'path': receiptPath,
          'contentType': receiptContentType,
        },
        'source': source.name,
        'reportId': reportId,
        'projectId': projectId,
        'localCreatedAt': Timestamp.fromDate(localCreatedAt),
      };

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    final r = Map<String, dynamic>.from((m['receipt'] as Map?) ?? const {});
    return Expense(
      id: doc.id,
      ownerId: m['ownerId'] as String? ?? '',
      date: m['date'] as String? ?? isoDay(DateTime.now()),
      client: m['client'] as String? ?? '',
      activity: m['activity'] as String? ?? '',
      categoryId: m['categoryId'] as String? ?? 'outros',
      noteAmount: (m['noteAmount'] as num?)?.toDouble() ?? 0,
      amount: (m['amount'] as num?)?.toDouble() ?? 0,
      splitPeople: (m['splitPeople'] as num?)?.toInt() ?? 1,
      notes: m['notes'] as String? ?? '',
      vehicleNotes: m['vehicleNotes'] as String? ?? '',
      merchant: m['merchant'] as String? ?? '',
      receiptState: ReceiptState.values.firstWhere((s) => s.name == r['state'], orElse: () => ReceiptState.none),
      receiptPath: r['path'] as String?,
      receiptContentType: r['contentType'] as String?,
      source: ExpenseSource.values.firstWhere((s) => s.name == m['source'], orElse: () => ExpenseSource.manual),
      reportId: m['reportId'] as String?,
      projectId: m['projectId'] as String?,
      localCreatedAt: (m['localCreatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasPendingWrites: doc.metadata.hasPendingWrites,
    );
  }

  Expense copyWith({
    String? date,
    String? client,
    String? activity,
    String? categoryId,
    double? noteAmount,
    double? amount,
    int? splitPeople,
    String? notes,
    String? vehicleNotes,
    String? merchant,
    ReceiptState? receiptState,
    String? receiptPath,
    String? receiptContentType,
    ExpenseSource? source,
  }) =>
      Expense(
        id: id,
        ownerId: ownerId,
        date: date ?? this.date,
        client: client ?? this.client,
        activity: activity ?? this.activity,
        categoryId: categoryId ?? this.categoryId,
        noteAmount: noteAmount ?? this.noteAmount,
        amount: amount ?? this.amount,
        splitPeople: splitPeople ?? this.splitPeople,
        notes: notes ?? this.notes,
        vehicleNotes: vehicleNotes ?? this.vehicleNotes,
        merchant: merchant ?? this.merchant,
        receiptState: receiptState ?? this.receiptState,
        receiptPath: receiptPath ?? this.receiptPath,
        receiptContentType: receiptContentType ?? this.receiptContentType,
        source: source ?? this.source,
        reportId: reportId,
        projectId: projectId,
        localCreatedAt: localCreatedAt,
        hasPendingWrites: hasPendingWrites,
      );
}
