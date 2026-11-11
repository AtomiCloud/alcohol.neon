import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_service.dart';
import 'config/app_config.dart';
import 'core/launch_timeline.dart';
import 'core/navigation.dart';
import 'features/dashboard/today_layout.dart';
import 'features/nfc/nfc_deep_links.dart';
import 'features/root/root_view.dart';
import 'session/session_controller.dart';
import 'theme/app_theme.dart';

void main() async {
  LaunchTimeline.start();
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await TodayLayoutSetting.instance.load();
  LaunchTimeline.mark('config-loaded');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService(AppConfig.current)),
        // Built once from AuthService; owns the zinc repositories + bootstrap state.
        ChangeNotifierProxyProvider<AuthService, SessionController>(
          create: (ctx) => SessionController(ctx.read<AuthService>()),
          update: (ctx, auth, previous) => previous ?? SessionController(auth),
        ),
        // Parks /t/{tagId} Universal/App Links until the session is ready
        // (consumed by NfcTapListener inside the authed shell).
        ChangeNotifierProvider(
          create: (_) =>
              NfcDeepLinkService()..start(AppConfig.current.nfcTagBaseUrl),
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
  late final AuthService _auth;
  late AuthStatus _lastStatus;

  @override
  void initState() {
    super.initState();
    // One-time attach: the AuthService instance is created once in main() and
    // never replaced, and read() registers no dependency anyway.
    _auth = context.read<AuthService>();
    _auth.addListener(_onAuthChanged);
    _lastStatus = _auth.status;
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// When the session ends, RootView swaps to the signed-out shell — but that
  /// swap happens *underneath* any routes pushed on the root navigator (profile,
  /// habit editor, vacations, …). Pop back to the first route so the signed-out
  /// experience is actually visible, whatever screen the user was on.
  void _onAuthChanged() {
    final status = _auth.status;
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
      navigatorObservers: [routeObserver],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const RootView(),
    );
  }
}
