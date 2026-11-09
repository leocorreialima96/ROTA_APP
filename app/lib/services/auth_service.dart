import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Login com Apple, Google ou e-mail (tela 1).
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> get changes => _auth.authStateChanges();
  User? get user => _auth.currentUser;

  Future<void> signInWithGoogle() => _provider(GoogleAuthProvider()..addScope('email'));

  Future<void> signInWithApple() => _provider(AppleAuthProvider()..addScope('email')..addScope('name'));

  Future<void> _provider(AuthProvider p) async {
    if (kIsWeb) {
      await _auth.signInWithPopup(p);
    } else {
      await _auth.signInWithProvider(p);
    }
  }

  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> createWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  /// Mensagens em português para os erros mais comuns.
  static String message(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'E-mail inválido.';
        case 'user-disabled':
          return 'Esta conta foi desativada.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'E-mail ou senha incorretos.';
        case 'email-already-in-use':
          return 'Já existe uma conta com este e-mail. Use "Entrar".';
        case 'weak-password':
          return 'A senha precisa ter pelo menos 6 caracteres.';
        case 'network-request-failed':
          return 'Sem conexão. O login precisa de internet na primeira vez.';
        case 'popup-closed-by-user':
        case 'web-context-canceled':
        case 'canceled':
          return 'Login cancelado.';
        case 'too-many-requests':
          return 'Muitas tentativas. Espere um pouco e tente de novo.';
        case 'operation-not-allowed':
          return 'Este tipo de login ainda não foi ligado no Firebase.';
      }
      return e.message ?? 'Não foi possível entrar.';
    }
    return 'Não foi possível entrar.';
  }
}
