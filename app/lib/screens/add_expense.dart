import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/expense.dart';
import '../parsing/nfe_parser.dart';
import '../parsing/receipt_text_parser.dart';
import '../services/services.dart';
import '../widgets/common.dart';
import 'expense_form_screen.dart';
import 'home_screen.dart';

/// O que já sabemos da despesa antes de abrir o formulário.
class ExpenseDraft {
  const ExpenseDraft({required this.source, this.bytes, this.contentType, this.parsed, this.fileName});

  final ExpenseSource source;
  final Uint8List? bytes;
  final String? contentType;
  final ParsedReceipt? parsed;
  final String? fileName;
}

/// Tela 7: Incluir despesa.
Future<void> showAddExpense(BuildContext context) async {
  final draft = await chooseDraft(context);
  if (draft == null || !context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => providersFor(context, ExpenseFormScreen(draft: draft))),
  );
}

/// Mostra as opções (foto, galeria, PDF/NF-e, digitar) e devolve o rascunho.
Future<ExpenseDraft?> chooseDraft(BuildContext context) async {
  final choice = await showModalBottomSheet<ExpenseSource>(
    context: context,
    backgroundColor: RotaColors.paper,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _AddSheet(),
  );
  if (choice == null || !context.mounted) return null;
  return captureDraft(context, choice);
}

/// Pega o comprovante pela opção escolhida e tenta ler os dados da nota.
Future<ExpenseDraft?> captureDraft(BuildContext context, ExpenseSource source) async {
  final s = context.read<Services>();
  switch (source) {
    case ExpenseSource.manual:
      return const ExpenseDraft(source: ExpenseSource.manual);
    case ExpenseSource.camera:
    case ExpenseSource.gallery:
      final XFile? img;
      try {
        img = await ImagePicker().pickImage(
          source: source == ExpenseSource.camera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1800,
          maxHeight: 1800,
          imageQuality: 78,
          requestFullMetadata: false,
        );
      } catch (e) {
        if (context.mounted) showMessage(context, 'Não foi possível abrir a câmera ou a galeria.');
        return null;
      }
      if (img == null) return null;
      final bytes = await img.readAsBytes();
      ParsedReceipt? parsed;
      if (s.ocr.available && context.mounted) {
        parsed = await _withProgress(context, 'Lendo a nota...', () => s.ocr.readFile(img!.path));
      }
      return ExpenseDraft(
        source: source,
        bytes: bytes,
        contentType: img.mimeType ?? (bytes.length > 3 && bytes[0] == 0x89 ? 'image/png' : 'image/jpeg'),
        parsed: parsed,
        fileName: img.name,
      );
    case ExpenseSource.pdf:
    case ExpenseSource.nfe:
      final PlatformFile? f;
      try {
        f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf', 'xml']);
      } catch (e) {
        if (context.mounted) showMessage(context, 'Não foi possível abrir o arquivo.');
        return null;
      }
      if (f == null) return null;
      final bytes = await f.xFile.readAsBytes();
      final isXml = (f.extension ?? '').toLowerCase() == 'xml';
      if (!isXml) {
        return ExpenseDraft(source: ExpenseSource.pdf, bytes: bytes, contentType: 'application/pdf', fileName: f.name);
      }
      try {
        final n = NfeParser.parse(utf8.decode(bytes, allowMalformed: true));
        return ExpenseDraft(
          source: ExpenseSource.nfe,
          bytes: bytes,
          contentType: 'application/xml',
          fileName: f.name,
          parsed: ParsedReceipt(total: n.total, date: n.date, cnpj: n.issuerCnpj, merchant: n.issuerName, categoryId: n.categoryId),
        );
      } on NfeParseException catch (e) {
        if (context.mounted) showMessage(context, e.message);
        return null;
      }
  }
}

Future<T?> _withProgress<T>(BuildContext context, String label, Future<T?> Function() f) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 16),
          Text(label),
        ]),
      ),
    ),
  );
  try {
    return await f();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

class _AddSheet extends StatelessWidget {
  const _AddSheet();

  @override
  Widget build(BuildContext context) {
    final ocr = context.read<Services>().ocr.available;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Incluir despesa', style: display(22)),
          const SizedBox(height: 4),
          const Text('Funciona com ou sem internet.', style: TextStyle(color: RotaColors.muted)),
          const SizedBox(height: 16),
          _Big(
            icon: Icons.photo_camera_outlined,
            color: RotaColors.sun,
            title: 'Fotografar a nota',
            text: ocr ? 'A leitura automática preenche valor, data e categoria.' : 'A foto vai como comprovante.',
            onTap: () => Navigator.pop(context, ExpenseSource.camera),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _Small(icon: Icons.photo_library_outlined, label: 'Galeria', onTap: () => Navigator.pop(context, ExpenseSource.gallery)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Small(icon: Icons.upload_file_outlined, label: 'PDF ou NF-e', onTap: () => Navigator.pop(context, ExpenseSource.pdf)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Small(icon: Icons.edit_outlined, label: 'Digitar', onTap: () => Navigator.pop(context, ExpenseSource.manual)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.icon, required this.color, required this.title, required this.text, required this.onTap});

  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(icon, size: 32, color: RotaColors.ink),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(text, style: const TextStyle(fontSize: 13, color: RotaColors.inkSoft)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _Small extends StatelessWidget {
  const _Small({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(children: [
              Icon(icon, color: RotaColors.ink),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}
