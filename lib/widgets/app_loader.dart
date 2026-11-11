import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/glass.dart';

/// Shared full-screen loading indicator — the LazyTax sloth Lottie (the same
/// `loading.json` argon uses). Centered, looping; a drop-in replacement for
/// `Center(child: CircularProgressIndicator())` on page-level loads.
class AppLoader extends StatelessWidget {
  final double size;
  const AppLoader({super.key, this.size = 140});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        'assets/animations/loading.json',
        width: size,
        height: size,
        repeat: true,
      ),
    );
  }
}

/// The launch loading screen: [AppLoader] on the glass backdrop, the same as
/// Today's own loading state. Auth restore, session bootstrap and Today's
/// first load all use it, so launch shows one continuous screen.
class GlassLoadingScreen extends StatelessWidget {
  const GlassLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => const AmbientBackdrop(
    child: Scaffold(backgroundColor: Colors.transparent, body: AppLoader()),
  );
}
