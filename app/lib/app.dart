import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'models/user_profile.dart';
import 'screens/categories_screen.dart';
import 'screens/home_shell.dart';
import 'screens/link_company_screen.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';
import 'services/services.dart';
import 'widgets/common.dart';

class RotaApp extends StatelessWidget {
  const RotaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rota',
      debugShowCheckedModeBanner: false,
      theme: rotaTheme(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AuthGate(),
    );
  }
}

/// Decide a tela inicial: login, cadastro, vínculo, categorias ou o app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.read<Services>();
    return StreamBuilder<User?>(
      stream: s.auth.changes,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Splash();
        final user = snap.data;
        if (user == null) {
          s.expenses.sync.stop();
          return const LoginScreen();
        }
        return _ProfileGate(key: ValueKey(user.uid), user: user);
      },
    );
  }
}

class _ProfileGate extends StatelessWidget {
  const _ProfileGate({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final s = context.read<Services>();
    return StreamBuilder<UserProfile?>(
      stream: s.profiles.watch(user.uid),
      builder: (context, snap) {
        if (!snap.hasData && snap.connectionState == ConnectionState.waiting) return const Splash();
        final p = snap.data;
        if (p == null) return RegistrationScreen(user: user);
        if (p.mode == AccountMode.undecided) return LinkCompanyScreen(profile: p);
        if (!p.onboardingDone) return CategoriesScreen(profile: p, onboarding: true);
        s.expenses.sync.start();
        return Provider<UserProfile>.value(value: p, child: const HomeShell());
      },
    );
  }
}
