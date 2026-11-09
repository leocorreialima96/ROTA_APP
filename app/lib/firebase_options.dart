import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Configuração do Firebase.
///
/// Fase 1: o app roda no simulador do Firebase (Emulator Suite), com o
/// projeto de demonstração "demo-rota", que não precisa de conta nem de
/// internet. Para apontar para o projeto real (região São Paulo), rode
/// `flutterfire configure` na pasta app/ e passe
/// `--dart-define=USE_EMULATORS=false` (veja docs/fase-1.md).
class DefaultFirebaseOptions {
  /// Liga o simulador. Padrão: ligado, enquanto estamos na fase 1.
  static const useEmulators = bool.fromEnvironment('USE_EMULATORS', defaultValue: true);

  /// Endereço do computador que roda o simulador. No emulador Android use
  /// 10.0.2.2; num celular de verdade, o IP do computador na rede.
  static const emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  // Valores do projeto de demonstração. Substituídos pelo `flutterfire configure`.
  static const web = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-rota',
    authDomain: 'demo-rota.firebaseapp.com',
    storageBucket: 'demo-rota.appspot.com',
  );

  static const android = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-rota',
    storageBucket: 'demo-rota.appspot.com',
  );

  static const ios = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-rota',
    storageBucket: 'demo-rota.appspot.com',
    iosBundleId: 'br.app.rota',
  );
}
