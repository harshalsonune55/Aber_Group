import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'shared/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AberApp()));
}

class AberApp extends StatefulWidget {
  const AberApp({super.key});

  @override
  State<AberApp> createState() => _AberAppState();
}

class _AberAppState extends State<AberApp> {
  // Built once and held: recreating the router on rebuild resets navigation
  // state, which shows up as an agent losing their place mid-form.
  late final _router = createRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Aber Group',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
