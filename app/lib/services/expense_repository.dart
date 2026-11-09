import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import 'receipt_store.dart';

/// Despesas: gravadas antes no aparelho e sincronizadas sozinhas.
class ExpenseRepository {
  ExpenseRepository(this._db, this._storage, this._store);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final ReceiptStore _store;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('expenses');

  String newId() => _col.doc().id;

  /// Todas as despesas do usuário, mais recentes primeiro, com o estado de
  /// sincronização ("salva no celular" / "salva na nuvem").
  Stream<List<Expense>> watchAll(String uid) => _col
      .where('ownerId', isEqualTo: uid)
      .orderBy('date', descending: true)
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.docs.map(Expense.fromDoc).toList());

  Stream<List<Expense>> watchOpen(String uid) =>
      watchAll(uid).map((all) => all.where((e) => !e.isClosed).toList());

  /// Despesas de um relatório (as regras exigem filtrar pelo dono).
  Future<List<Expense>> byReport(String uid, String reportId) async {
    final s = await _col.where('ownerId', isEqualTo: uid).where('reportId', isEqualTo: reportId).get();
    return s.docs.map(Expense.fromDoc).toList();
  }

  /// Grava a despesa e, se houver, o comprovante no aparelho. Volta na hora,
  /// com ou sem internet.
  Future<void> save(Expense e, {Uint8List? receipt, String? receiptType, bool isNew = false}) async {
    var exp = e;
    if (receipt != null) {
      final type = receiptType ?? 'image/jpeg';
      await _store.put(e.id, receipt, type);
      exp = e.copyWith(
        receiptState: ReceiptState.local,
        receiptPath: 'users/${e.ownerId}/receipts/${e.id}.${receiptExtension(type)}',
        receiptContentType: type,
      );
    }
    final data = exp.toMap()..['updatedAt'] = FieldValue.serverTimestamp();
    final ref = _col.doc(e.id);
    final Future<void> write;
    if (isNew) {
      data['createdAt'] = FieldValue.serverTimestamp();
      write = ref.set(data);
    } else {
      // Mantém o createdAt original (as regras exigem).
      write = ref.set(data, SetOptions(mergeFields: data.keys.toList()));
    }
    _report(write);
    if (receipt != null) unawaited(sync.run());
  }

  Future<void> delete(Expense e) async {
    _report(_col.doc(e.id).delete());
    await _store.remove(e.id);
    if (e.receiptState == ReceiptState.uploaded && e.receiptPath != null) {
      _storage.ref(e.receiptPath).delete().ignore();
    }
  }

  /// Bytes do comprovante: do aparelho, ou da nuvem se não estiver aqui.
  Future<LocalReceipt?> receipt(Expense e) async {
    final local = _store.get(e.id);
    if (local != null) return local;
    if (e.receiptState != ReceiptState.uploaded || e.receiptPath == null) return null;
    final bytes = await _storage.ref(e.receiptPath).getData(20 * 1024 * 1024);
    if (bytes == null) return null;
    final type = e.receiptContentType ?? 'image/jpeg';
    await _store.put(e.id, bytes, type);
    await _store.markUploaded(e.id);
    return LocalReceipt(bytes: bytes, contentType: type, savedAt: DateTime.now(), uploaded: true);
  }

  late final sync = ReceiptSync(_col, _storage, _store);

  static void _report(Future<void> f) {
    f.catchError((Object err) {
      debugPrint('Rota: gravação recusada pelo servidor: $err');
    });
  }
}

/// Sobe as fotos que estão só no aparelho, assim que houver sinal.
class ReceiptSync {
  ReceiptSync(this._col, this._storage, this._store);

  final CollectionReference<Map<String, dynamic>> _col;
  final FirebaseStorage _storage;
  final ReceiptStore _store;
  Timer? _timer;
  bool _running = false;

  /// Tenta de novo a cada minuto enquanto o app está aberto.
  void start() {
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => run());
    unawaited(run());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> run() async {
    if (_running) return;
    _running = true;
    try {
      for (final id in _store.pending) {
        final local = _store.get(id);
        if (local == null) continue;
        final snap = await _col.doc(id).get(const GetOptions(source: Source.cache)).catchError(
              (_) => _col.doc(id).get(),
            );
        final m = snap.data();
        if (m == null) continue;
        final r = Map<String, dynamic>.from(m['receipt'] as Map? ?? const {});
        final path = r['path'] as String?;
        if (path == null) continue;
        try {
          await _storage.ref(path).putData(local.bytes, SettableMetadata(contentType: local.contentType));
        } on FirebaseException catch (e) {
          // Se a foto já tinha subido (o app fechou antes de anotar), o
          // servidor recusa a regravação de despesa fechada: confere e segue.
          final already = e.code == 'unauthorized' &&
              await _storage.ref(path).getMetadata().then((_) => true, onError: (_) => false);
          if (!already) {
            debugPrint('Rota: foto $id ainda não subiu (${e.code}).');
            continue;
          }
        }
        await _store.markUploaded(id);
        final f = _col.doc(id).update({
          'receipt': {...r, 'state': ReceiptState.uploaded.name},
          'updatedAt': FieldValue.serverTimestamp(),
        });
        f.ignore();
      }
    } finally {
      _running = false;
    }
  }
}
