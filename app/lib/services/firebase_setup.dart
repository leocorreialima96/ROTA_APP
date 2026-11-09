import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Região das funções: São Paulo.
const functionsRegion = 'southamerica-east1';

Future<void> setupFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Offline primeiro: tudo é gravado antes no aparelho. No celular isso já é
  // o padrão; na versão web precisa ser ligado.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Uma foto que não consegue subir (sem sinal) desiste rápido e tenta de
  // novo depois, em vez de ficar presa por 10 minutos.
  FirebaseStorage.instance.setMaxUploadRetryTime(const Duration(seconds: 45));
  FirebaseStorage.instance.setMaxOperationRetryTime(const Duration(seconds: 45));

  if (DefaultFirebaseOptions.useEmulators) {
    const host = DefaultFirebaseOptions.emulatorHost;
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    FirebaseFunctions.instanceFor(region: functionsRegion).useFunctionsEmulator(host, 5001);
    debugPrint('Rota: usando o simulador do Firebase em $host');
  }
}
