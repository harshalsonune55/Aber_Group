import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router.dart';
import 'features/auth/state/auth_controller.dart';
import 'shared/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AberApp()));
}

class AberApp extends ConsumerStatefulWidget {
  const AberApp({super.key});

  @override
  ConsumerState<AberApp> createState() => _AberAppState();
}

class _AberAppState extends ConsumerState<AberApp> {
  // Built once and held: recreating the router on rebuild resets navigation
  // state, which shows up as an agent losing their place mid-form.
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider);
    // Enters on the splash and moves to Today or sign-in once secure storage
    // answers — see the redirect in `createRouter`.
    _router = createRouter(initialLocation: '/starting', auth: auth);
    auth.restore();
  }

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
