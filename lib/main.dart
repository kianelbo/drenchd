import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/database.dart';
import 'data/repositories.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'ui/root_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await AppDatabase.instance.database;
  final state = AppState(
    substances: SubstanceRepository(db),
    intakes: IntakeRepository(db),
  );
  await state.bootstrap();

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const DrenchdApp(),
    ),
  );
}

class DrenchdApp extends StatelessWidget {
  const DrenchdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drenchd',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const RootPage(),
    );
  }
}
