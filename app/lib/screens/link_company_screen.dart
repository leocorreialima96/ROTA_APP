import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/user_profile.dart';
import '../services/services.dart';
import '../widgets/common.dart';

/// Tela 4: vincular empresa ou usar o modo individual.
class LinkCompanyScreen extends StatelessWidget {
  const LinkCompanyScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final s = context.read<Services>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 28), children: [
              const StepHeader(
                step: 2,
                total: 3,
                title: 'Para quem você presta contas?',
                subtitle: 'Se a sua empresa usa a Rota, o relatório vai direto para ela. Se não, use o modo individual: você gera o PDF e envia como quiser.',
              ),
              const SizedBox(height: 20),
              _Option(
                icon: Icons.person_outline,
                color: RotaColors.sun,
                title: 'Modo individual',
                text: 'Lance as despesas, feche o período e compartilhe o PDF com os comprovantes e a planilha.',
                onTap: () => s.profiles.chooseIndividual(profile),
              ),
              const SizedBox(height: 12),
              _Option(
                icon: Icons.apartment_outlined,
                color: RotaColors.violet,
                title: 'Vincular empresa',
                text: 'Pelo CNPJ ou código de convite. Chega numa próxima versão.',
                badge: 'Em breve',
                onTap: () => showMessage(context, 'O vínculo com empresas chega numa próxima versão. Use o modo individual por enquanto.'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.icon, required this.color, required this.title, required this.text, required this.onTap, this.badge});

  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: RotaColors.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: RotaColors.band, borderRadius: BorderRadius.circular(6)),
                        child: Text(badge!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: RotaColors.muted)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(fontSize: 13, height: 1.4, color: RotaColors.muted)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: RotaColors.muted),
            ]),
          ),
        ),
      );
}
