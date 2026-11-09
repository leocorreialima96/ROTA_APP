import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Rascunho da política de privacidade e dos termos de uso. Antes do
/// lançamento (fase 5), o texto final precisa ser revisado por um advogado.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  static const _sections = <(String, String)>[
    (
      'Quais dados coletamos',
      'Nome, CPF, e-mail, celular, cargo, placa do veículo, as despesas que você lança (data, cliente, atividade, categoria, valores, observações) e as fotos ou arquivos dos comprovantes.',
    ),
    (
      'Para que usamos',
      'Para montar os seus relatórios de despesas com os comprovantes. O CPF identifica a sua conta (uma por CPF) e não pode ser alterado.',
    ),
    (
      'Quem vê os seus dados',
      'Só você. No modo individual, ninguém mais acessa as suas despesas. Quando houver vínculo com empresa, ela só verá os relatórios que você enviar. Pontos e medalhas são visíveis só para você.',
    ),
    (
      'Como protegemos',
      'Os dados são criptografados no envio e no armazenamento. O CPF recebe uma camada extra de criptografia no servidor e aparece mascarado nas telas. As regras de acesso ficam no servidor, não no app.',
    ),
    (
      'Onde ficam',
      'No Brasil, na região de São Paulo do Google Cloud (Firebase), com backups diários e uma cópia em outra região para desastres.',
    ),
    (
      'Seus direitos (LGPD)',
      'Você pode ver e corrigir seus dados no Perfil, exportar uma cópia (Perfil > Exportar meus dados) e excluir a conta (Perfil > Excluir minha conta). Relatórios já enviados a uma empresa ficam com ela pelo prazo legal de guarda fiscal.',
    ),
    (
      'Termos de uso',
      'Você é responsável pela veracidade das despesas e dos comprovantes lançados. A Rota organiza as informações e gera os arquivos; a aprovação e o reembolso são decisões de quem recebe o relatório.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Privacidade e termos')),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
          const Text('Versão 2026-11 · rascunho', style: TextStyle(fontSize: 12, color: RotaColors.muted)),
          const SizedBox(height: 12),
          for (final (title, body) in _sections) ...[
            Text(title, style: display(17)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(fontSize: 14, height: 1.5, color: RotaColors.inkSoft)),
            const SizedBox(height: 16),
          ],
        ]),
      );
}
