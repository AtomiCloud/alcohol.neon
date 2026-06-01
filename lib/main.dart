import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_service.dart';
import 'config/app_config.dart';
import 'features/root/root_view.dart';
import 'session/session_controller.dart';

void main() {
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

class AlcoholNeonApp extends StatelessWidget {
  const AlcoholNeonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LazyTax',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1B5453),
        useMaterial3: true,
      ),
      home: const RootView(),
    );
  }
}
