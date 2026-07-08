import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_service.dart';
import 'config/app_config.dart';
import 'features/root/root_view.dart';
import 'session/session_controller.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService(AppConfig.current)),
        // Built once from AuthService; owns the zinc repositories + bootstrap state.
        ChangeNotifierProxyProvider<AuthService, SessionController>(
          create: (ctx) => SessionController(ctx.read<AuthService>()),
          update: (ctx, auth, previous) => previous ?? SessionController(auth),
        ),
      ],
      child: const AlcoholNeonApp(),
    ),
  );
}

class AlcoholNeonApp extends StatefulWidget {
  const AlcoholNeonApp({super.key});

  @override
  State<AlcoholNeonApp> createState() => _AlcoholNeonAppState();
}

class _AlcoholNeonAppState extends State<AlcoholNeonApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  AuthService? _auth;
  AuthStatus? _lastStatus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthService>();
    if (identical(auth, _auth)) return;
    _auth?.removeListener(_onAuthChanged);
    _auth = auth..addListener(_onAuthChanged);
    _lastStatus = auth.status;
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// When the session ends, RootView swaps to the signed-out shell — but that
  /// swap happens *underneath* any routes pushed on the root navigator (profile,
  /// habit editor, vacations, …). Pop back to the first route so the signed-out
  /// experience is actually visible, whatever screen the user was on.
  void _onAuthChanged() {
    final status = _auth!.status;
    if (_lastStatus == AuthStatus.authenticated &&
        status != AuthStatus.authenticated) {
      _navigatorKey.currentState?.popUntil((r) => r.isFirst);
    }
    _lastStatus = status;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LazyTax',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const RootView(),
    );
  }
}
