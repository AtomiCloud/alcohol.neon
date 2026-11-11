import 'package:flutter/material.dart';

/// The theme makes filled and outlined buttons full width
/// (`Size.fromHeight`), which has no width limit inside a [Row] or [Wrap].
/// Wrap inline buttons, such as a list row's actions, in this.
class CompactButtons extends StatelessWidget {
  final Widget child;
  const CompactButtons({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const size = WidgetStatePropertyAll(Size(64, 40));
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: (theme.filledButtonTheme.style ?? const ButtonStyle())
              .copyWith(minimumSize: size),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: (theme.outlinedButtonTheme.style ?? const ButtonStyle())
              .copyWith(minimumSize: size),
        ),
      ),
      child: child,
    );
  }
}
