import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'auth_service.dart';
import 'expense_repository.dart';
import 'ocr_service.dart';
import 'profile_repository.dart';
import 'receipt_store.dart';
import 'report_service.dart';

/// Tudo o que as telas usam, criado uma vez em main().
class Services {
  Services._(this.auth, this.profiles, this.expenses, this.reports, this.ocr, this.store);

  final AuthService auth;
  final ProfileRepository profiles;
  final ExpenseRepository expenses;
  final ReportService reports;
  final OcrService ocr;
  final ReceiptStore store;

  static Future<Services> create() async {
    final db = FirebaseFirestore.instance;
    final store = await ReceiptStore.open();
    final expenses = ExpenseRepository(db, FirebaseStorage.instance, store);
    return Services._(
      AuthService(FirebaseAuth.instance),
      ProfileRepository(db, null),
      expenses,
      ReportService(db, FirebaseStorage.instance, expenses),
      OcrService(),
      store,
    );
  }
}
