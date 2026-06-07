import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

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
