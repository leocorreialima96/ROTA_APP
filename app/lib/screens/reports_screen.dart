import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/report.dart';
import '../models/user_profile.dart';
import 'report_view_screen.dart';

/// Tela 17 (versão da fase 1): relatórios emitidos.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<List<Report>>();
    final p = context.watch<UserProfile>();
    return Scaffold(
      appBar: AppBar(title: const Text('Meus relatórios')),
      body: reports.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Quando você fechar um período, o relatório aparece aqui.',
                    textAlign: TextAlign.center, style: TextStyle(color: RotaColors.muted)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: reports.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = reports[i];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => Provider<UserProfile>.value(value: p, child: ReportViewScreen(report: r))),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: RotaColors.sunSoft, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.description_outlined, color: RotaColors.link),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${dmy(r.start)} a ${dmy(r.end)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('${r.expenseIds.length} despesas · emitido em ${dmy(r.createdAt)}',
                                style: const TextStyle(fontSize: 12, color: RotaColors.muted)),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(brl(r.total), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          _Status(report: r),
                        ]),
                      ]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final cloud = !report.hasPendingWrites;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: cloud ? RotaColors.okSoft : RotaColors.band, borderRadius: BorderRadius.circular(8)),
      child: Text(cloud ? 'Emitido' : 'No celular', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

