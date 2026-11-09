import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/category.dart';
import '../models/expense.dart';

class Splash extends StatelessWidget {
  const Splash({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: RotaLogo(big: true)));
}

/// Logo do protótipo: o caminho entre dois pontos.
class RotaLogo extends StatelessWidget {
  const RotaLogo({super.key, this.big = false, this.showSlogan = false});

  final bool big;
  final bool showSlogan;

  @override
  Widget build(BuildContext context) {
    final size = big ? 56.0 : 42.0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: RotaColors.sun, borderRadius: BorderRadius.circular(size * 0.29)),
        child: CustomPaint(painter: _LogoPainter()),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('Rota', style: display(big ? 30 : 24)),
        if (showSlogan)
          const Text('seus relatórios feitos em poucos cliques', style: TextStyle(fontSize: 12, color: RotaColors.muted)),
      ]),
    ]);
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final p = Paint()
      ..color = RotaColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * s
      ..strokeCap = StrokeCap.round;
    final o = Offset(size.width * 0.5 - 12 * s, size.height * 0.5 - 12 * s);
    canvas.drawCircle(o + Offset(6 * s, 18 * s), 2.5 * s, p);
    canvas.drawCircle(o + Offset(18 * s, 6 * s), 2.5 * s, p);
    final path = Path()
      ..moveTo(o.dx + 8 * s, o.dy + 16.5 * s)
      ..cubicTo(o.dx + 12 * s, o.dy + 14 * s, o.dx + 10 * s, o.dy + 9 * s, o.dx + 15.8 * s, o.dy + 7.4 * s);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cartão branco arredondado.
class RotaCard extends StatelessWidget {
  const RotaCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color, this.border});

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: border == null ? null : Border.all(color: border!, width: 1.5),
        ),
        child: child,
      );
}

/// Ícone da categoria com as iniciais e o ponto de status no canto.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.category, this.flag});

  final ExpenseCategory? category;
  final Color? flag;

  @override
  Widget build(BuildContext context) {
    final c = category;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c?.softColor ?? RotaColors.band, borderRadius: BorderRadius.circular(12)),
          child: Text(c?.initials ?? '?',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c?.colorValue ?? RotaColors.muted)),
        ),
        if (flag != null)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(color: flag, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            ),
          ),
      ]),
    );
  }
}

/// "Salva no celular" / "Salva na nuvem".
class SyncLabel extends StatelessWidget {
  const SyncLabel({super.key, required this.expense, this.compact = false});

  final Expense expense;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cloud = expense.savedInCloud;
    final color = cloud ? RotaColors.okText : RotaColors.muted;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(cloud ? Icons.cloud_done_outlined : Icons.phone_iphone, size: 14, color: color),
      if (!compact) ...[
        const SizedBox(width: 4),
        Text(cloud ? 'Salva na nuvem' : 'Salva no celular', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    ]);
  }
}

/// Linha de despesa usada no Início, em Despesas e no fechamento.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({super.key, required this.expense, required this.category, this.onTap});

  final Expense expense;
  final ExpenseCategory? category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final missing = !e.hasReceipt;
    final sub = missing
        ? 'Sem comprovante · toque para anexar'
        : [dm(e.day), if (e.client.isNotEmpty) e.client].join(' · ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            CategoryBadge(category: category, flag: missing ? RotaColors.alert : (e.savedInCloud ? const Color(0xFF3BE38C) : RotaColors.sun)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  e.activity.isNotEmpty ? e.activity : (category?.name ?? 'Despesa'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: missing ? RotaColors.alertText : RotaColors.muted, fontWeight: missing ? FontWeight.w600 : FontWeight.w400)),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(brl(e.amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              SyncLabel(expense: e, compact: true),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Faixa colorida com a divisão do gasto por categoria.
class CategorySplitBar extends StatelessWidget {
  const CategorySplitBar({super.key, required this.parts});

  final List<(ExpenseCategory, double)> parts;

  @override
  Widget build(BuildContext context) {
    final total = parts.fold(0.0, (s, p) => s + p.$2);
    if (total <= 0) {
      return Container(height: 12, decoration: BoxDecoration(color: RotaColors.lineSoft, borderRadius: BorderRadius.circular(6)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 12,
          child: Row(children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                flex: (parts[i].$2 / total * 1000).round().clamp(1, 1000),
                child: Container(color: parts[i].$1.colorValue),
              ),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 12, runSpacing: 6, children: [
        for (final p in parts)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: p.$1.colorValue, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(p.$1.name, style: const TextStyle(fontSize: 11, color: RotaColors.inkSoft)),
          ]),
      ]),
    ]);
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Cabeçalho de passos do cadastro ("Passo 1 de 3").
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.step, required this.total, required this.title, required this.subtitle});

  final int step;
  final int total;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        for (var i = 1; i <= total; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(color: i <= step ? RotaColors.sun : const Color(0xFFDCD5C6), borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 12),
      Text('Passo $step de $total', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: RotaColors.muted)),
      const SizedBox(height: 8),
      Text(title, style: display(26)),
      const SizedBox(height: 8),
      Text(subtitle, style: const TextStyle(fontSize: 15, height: 1.45, color: RotaColors.muted)),
    ]);
  }
}
