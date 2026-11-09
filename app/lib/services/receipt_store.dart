import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Um comprovante guardado no aparelho.
class LocalReceipt {
  const LocalReceipt({required this.bytes, required this.contentType, required this.savedAt, required this.uploaded});

  final Uint8List bytes;
  final String contentType;
  final DateTime savedAt;
  final bool uploaded;
}

/// Guarda as fotos e PDFs das notas no próprio celular antes de qualquer
/// envio (no navegador, no IndexedDB). Assim nada se perde sem sinal: a foto
/// só sai daqui depois que já está na nuvem.
class ReceiptStore {
  ReceiptStore._(this._box);

  final Box<dynamic> _box;

  static Future<ReceiptStore> open() async {
    await Hive.initFlutter('rota');
    return ReceiptStore._(await Hive.openBox<dynamic>('receipts'));
  }

  Future<void> put(String expenseId, Uint8List bytes, String contentType) => _box.put(expenseId, {
        'bytes': bytes,
        'contentType': contentType,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'uploaded': false,
      });

  LocalReceipt? get(String expenseId) {
    final m = _box.get(expenseId);
    if (m is! Map) return null;
    return LocalReceipt(
      bytes: m['bytes'] is Uint8List ? m['bytes'] as Uint8List : Uint8List.fromList(List<int>.from(m['bytes'] as List)),
      contentType: m['contentType'] as String? ?? 'image/jpeg',
      savedAt: DateTime.fromMillisecondsSinceEpoch(m['savedAt'] as int? ?? 0),
      uploaded: m['uploaded'] == true,
    );
  }

  Future<void> markUploaded(String expenseId) async {
    final m = _box.get(expenseId);
    if (m is Map) await _box.put(expenseId, {...m, 'uploaded': true});
  }

  Future<void> remove(String expenseId) => _box.delete(expenseId);

  /// Ids com foto ainda não enviada.
  List<String> get pending => _box.keys
      .cast<String>()
      .where((k) {
        final m = _box.get(k);
        return m is Map && m['uploaded'] != true;
      })
      .toList();

  /// Limpa cópias locais já enviadas há mais de [age] (a nuvem é a fonte).
  Future<void> prune({Duration age = const Duration(days: 120)}) async {
    final limit = DateTime.now().subtract(age).millisecondsSinceEpoch;
    final old = _box.keys.where((k) {
      final m = _box.get(k);
      return m is Map && m['uploaded'] == true && (m['savedAt'] as int? ?? 0) < limit;
    }).toList();
    await _box.deleteAll(old);
  }
}

String receiptExtension(String contentType) {
  switch (contentType) {
    case 'application/pdf':
      return 'pdf';
    case 'application/xml':
    case 'text/xml':
      return 'xml';
    case 'image/png':
      return 'png';
    default:
      return 'jpg';
  }
}
