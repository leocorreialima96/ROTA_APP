import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/category.dart';
import '../models/user_profile.dart';
import 'firebase_setup.dart';

class ProfileRepository {
  ProfileRepository(this._db, FirebaseFunctions? functions)
      : _fn = functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  final FirebaseFirestore _db;
  final FirebaseFunctions _fn;

  DocumentReference<Map<String, dynamic>> _ref(String uid) => _db.doc('users/$uid');

  /// Emite null enquanto o cadastro (com CPF) não foi concluído.
  Stream<UserProfile?> watch(String uid) => _ref(uid).snapshots().map((s) {
        final m = s.data();
        if (m == null || (m['cpfMasked'] as String? ?? '').isEmpty) return null;
        return UserProfile.fromMap(uid, m);
      });

  /// Cadastro (tela 2). O servidor valida o CPF e garante que é único.
  Future<void> completeRegistration({
    required String name,
    required String cpf,
    required String phone,
    required String jobTitle,
    required String plate,
    required String email,
  }) async {
    await _fn.httpsCallable('completeRegistration').call<Map<String, dynamic>>({
      'name': name,
      'cpf': cpf,
      'phone': phone,
      'jobTitle': jobTitle,
      'plate': plate,
      'email': email,
      'consent': true,
    });
  }

  /// Edição do perfil. Funciona offline (a gravação sobe quando houver sinal).
  Future<void> update(UserProfile p, {String? name, String? phone, String? jobTitle, String? plate}) => _write(p, {
        'name': (name ?? p.name).trim(),
        'phone': (phone ?? p.phone).trim(),
        'jobTitle': (jobTitle ?? p.jobTitle).trim(),
        'plate': (plate ?? p.plate).trim().toUpperCase(),
      });

  Future<void> chooseIndividual(UserProfile p) => _write(p, {'mode': AccountMode.individual.name});

  Future<void> saveSettings(UserProfile p, IndividualSettings s, {bool finishOnboarding = true}) => _write(p, {
        'settings': s.toMap(),
        if (finishOnboarding) 'onboardingDone': true,
      });

  /// As regras do servidor exigem os campos editáveis completos e o carimbo
  /// de hora do servidor.
  Future<void> _write(UserProfile p, Map<String, dynamic> changes) {
    final data = <String, dynamic>{
      'name': p.name,
      'phone': p.phone,
      'jobTitle': p.jobTitle,
      'plate': p.plate,
      'mode': p.mode == AccountMode.company ? AccountMode.individual.name : p.mode.name,
      'settings': p.settings.toMap(),
      'onboardingDone': p.onboardingDone,
      ...changes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    // Sem await no envio: offline, a promessa só resolve quando o servidor
    // confirmar. A tela já recebe a mudança pelo cache local.
    final f = _ref(p.uid).update(data);
    f.ignore();
    return Future.value();
  }

  Future<void> deleteAccount() =>
      _fn.httpsCallable('deleteMyAccount').call<Map<String, dynamic>>({'confirm': 'EXCLUIR'});

  static String message(Object e) {
    if (e is FirebaseFunctionsException) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return 'Sem conexão com o servidor. O cadastro precisa de internet.';
      }
      return e.message ?? 'Não foi possível concluir.';
    }
    return 'Não foi possível concluir.';
  }
}
