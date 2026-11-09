import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/formatters.dart';

/// Status de um relatório. No modo individual (fase 1) o relatório nasce
/// "issued" (emitido). Os demais entram com a empresa, na fase 3.
enum ReportStatus { issued, submitted, rejected, approved, paid }

class Report {
  const Report({
    required this.id,
    required this.ownerId,
    required this.periodStart,
    required this.periodEnd,
    required this.expenseIds,
    required this.subtotal,
    required this.advances,
    required this.status,
    required this.fileBaseName,
    required this.createdAt,
    this.hasPendingWrites = false,
  });

  final String id;
  final String ownerId;
  final String periodStart;
  final String periodEnd;
  final List<String> expenseIds;
  final double subtotal;
  final double advances;
  final ReportStatus status;
  final String fileBaseName;
  final DateTime createdAt;
  final bool hasPendingWrites;

  double get total => cents(subtotal - advances);
  DateTime get start => parseIsoDay(periodStart);
  DateTime get end => parseIsoDay(periodEnd);

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'companyId': null,
        'mode': 'period',
        'periodStart': periodStart,
        'periodEnd': periodEnd,
        'expenseIds': expenseIds,
        'subtotal': subtotal,
        'advances': advances,
        'total': total,
        'status': status.name,
        'fileBaseName': fileBaseName,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Report.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return Report(
      id: doc.id,
      ownerId: m['ownerId'] as String? ?? '',
      periodStart: m['periodStart'] as String,
      periodEnd: m['periodEnd'] as String,
      expenseIds: List<String>.from(m['expenseIds'] as List? ?? const []),
      subtotal: (m['subtotal'] as num?)?.toDouble() ?? 0,
      advances: (m['advances'] as num?)?.toDouble() ?? 0,
      status: ReportStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => ReportStatus.issued),
      fileBaseName: m['fileBaseName'] as String? ?? 'Relatório',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasPendingWrites: doc.metadata.hasPendingWrites,
    );
  }
}
