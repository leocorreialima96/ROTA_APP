import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/firebase_setup.dart';
import 'services/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');
  await setupFirebase();
  final services = await Services.create();
  // Para testes automáticos no navegador: expõe a árvore de acessibilidade.
  if (kIsWeb && const bool.fromEnvironment('SEMANTICS')) SemanticsBinding.instance.ensureSemantics();
  runApp(Provider<Services>.value(value: services, child: const RotaApp()));
}
