import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/glass.dart';
import 'glass_page.dart';

/// Presents a task the user finishes or cancels, such as New habit: a page
/// sheet over the current screen on iOS, and a full-screen page rising from
/// the bottom on Android. Build the page with `GlassPage(modal: true)`, which
/// gives it Cancel on iOS and a close icon on Android.
Future<T?> showGlassModal<T>(BuildContext context, WidgetBuilder builder) {
  final navigator = Navigator.of(context);
  if (isCupertino(context)) {
    return navigator.push<T>(
      CupertinoSheetRoute<T>(
        scrollableBuilder: (context, _) => builder(context),
      ),
    );
  }
  return navigator.push<T>(
    MaterialPageRoute<T>(builder: builder, fullscreenDialog: true),
  );
}

/// Asks before an action that can't be taken back, in each platform's form:
/// an action sheet on iOS, a dialog on Android. Returns true only when the
/// user confirms.
Future<bool> showGlassConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final bool? ok;
  if (isCupertino(context)) {
    ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(title),
        message: Text(message),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: destructive,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
      ),
    );
  } else {
    ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: destructive ? scheme.error : scheme.tertiary,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }
  return ok ?? false;
}

/// A short confirmation, such as "Saved", as a frosted pill above the
/// bottom edge instead of a Material snackbar.
void showGlassToast(
  BuildContext context,
  String text, {
  Duration duration = const Duration(seconds: 4),
}) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: duration,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      backgroundColor: dark ? const Color(0xF0242428) : const Color(0xF2FFFFFF),
      shape: StadiumBorder(
        side: BorderSide(color: GlassTokens.of(context).edge, width: 0.5),
      ),
      content: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}

/// A bottom sheet in the glass style, such as the stake keypad: a frosted
/// surface with a grabber, attached to the bottom edge. The surface follows
/// the theme while open, so a switch to dark or light mode repaints it.
Future<T?> showGlassSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    elevation: 0,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SheetSurface(child: builder(ctx)),
  );
}

class _SheetSurface extends StatelessWidget {
  final Widget child;
  const _SheetSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xF51C1C1E) : const Color(0xF7F2F2F7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The same grabber as Material's drag handle.
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 22),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}
