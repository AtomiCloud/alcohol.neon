import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/glass.dart';

/// True on iOS (and macOS), where the glass screens use Cupertino conventions:
/// a glass back circle, a centered collapsed title, row chevrons and action
/// sheets. Read from the theme so tests can pick a platform.
bool isCupertino(BuildContext context) => switch (Theme.of(context).platform) {
  TargetPlatform.iOS || TargetPlatform.macOS => true,
  _ => false,
};

/// A screen in Today's glass style: the [AmbientBackdrop], a large title that
/// folds into a frosted top bar as the page scrolls, and [children] as the
/// scrolling content (usually [GlassSection]s).
///
/// iOS shows a glass back circle and centers the folded title. Android shows
/// a back arrow and keeps the title on the left, like a Material top app bar.
///
/// With [modal], the page is a task to finish or cancel (see
/// `showGlassModal`): no large title, and the leading action is Cancel on iOS
/// or a close icon on Android. [dock] floats a primary action at the bottom.
class GlassPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool modal;
  final Widget? dock;
  final Widget? floatingActionButton;
  final List<Widget> actions;

  /// Pull to refresh, when the page shows server data.
  final Future<void> Function()? onRefresh;

  const GlassPage({
    super.key,
    required this.title,
    required this.children,
    this.modal = false,
    this.dock,
    this.floatingActionButton,
    this.actions = const [],
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AmbientBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: dock == null ? null : _Dock(child: dock!),
        body: _refreshable(
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _GlassHeader(
                  title: title,
                  top: MediaQuery.paddingOf(context).top,
                  cupertino: isCupertino(context),
                  modal: modal,
                  actions: actions,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  32 + (dock == null ? bottom : 0),
                ),
                sliver: SliverList.list(children: children),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on GlassPage {
  Widget _refreshable(Widget scroll) {
    final refresh = onRefresh;
    if (refresh == null) return scroll;
    return RefreshIndicator(onRefresh: refresh, child: scroll);
  }
}

class _GlassHeader extends SliverPersistentHeaderDelegate {
  final String title;
  final double top;
  final bool cupertino;
  final bool modal;
  final List<Widget> actions;

  const _GlassHeader({
    required this.title,
    required this.top,
    required this.cupertino,
    required this.modal,
    required this.actions,
  });

  double get _bar => cupertino ? 52 : 56;

  @override
  double get minExtent => top + _bar;

  @override
  double get maxExtent => top + _bar + (modal ? 0 : 56);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final range = maxExtent - minExtent;
    final p = range == 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final folded = ((p - 0.5) / 0.5).clamp(0.0, 1.0);
    // A modal's bar is always solid: the page sits over another screen.
    final barOpacity = modal ? 1.0 : folded;
    final small = theme.textTheme.titleMedium?.copyWith(
      fontWeight: cupertino ? FontWeight.w600 : FontWeight.w400,
      fontSize: cupertino ? 17 : 22,
    );
    final leadingWidth = cupertino ? (modal ? 88.0 : 68.0) : 56.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (barOpacity > 0)
          Opacity(
            opacity: barOpacity,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.strongFill,
                    border: Border(
                      bottom: BorderSide(color: t.separator, width: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: top,
          left: cupertino ? leadingWidth : 72,
          right: cupertino ? leadingWidth : 16 + 48.0 * actions.length,
          height: _bar,
          child: Opacity(
            opacity: modal ? 1 : folded,
            child: Align(
              alignment: cupertino ? Alignment.center : Alignment.centerLeft,
              child: Text(
                title,
                style: small,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        Positioned(
          top: top,
          left: cupertino ? 16 : 4,
          height: _bar,
          child: Center(
            child: _Leading(cupertino: cupertino, modal: modal),
          ),
        ),
        if (actions.isNotEmpty)
          Positioned(
            top: top,
            right: cupertino ? 16 : 4,
            height: _bar,
            child: Row(children: actions),
          ),
        if (!modal)
          Positioned(
            left: 20,
            right: 20,
            bottom: 6,
            // Folded away, the large title still overlaps the bar, so it
            // must not take the back button's taps.
            child: IgnorePointer(
              child: Opacity(
                opacity: (1 - p * 1.8).clamp(0.0, 1.0),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: cupertino ? FontWeight.w700 : FontWeight.w400,
                    fontSize: cupertino ? 34 : 32,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Rebuilt with the page, so it follows theme and platform changes.
  @override
  bool shouldRebuild(_GlassHeader old) => true;
}

/// Back or close, in each platform's form.
class _Leading extends StatelessWidget {
  final bool cupertino;
  final bool modal;
  const _Leading({required this.cupertino, required this.modal});

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    void close() => Navigator.of(context).maybePop();
    if (!cupertino) {
      return IconButton(
        tooltip: modal ? 'Close' : 'Back',
        onPressed: close,
        color: Theme.of(context).colorScheme.onSurface,
        icon: Icon(modal ? Icons.close_rounded : Icons.arrow_back_rounded),
      );
    }
    if (modal) {
      return Pressable(
        onTap: close,
        child: Semantics(
          button: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Cancel',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: t.accent, fontSize: 17),
            ),
          ),
        ),
      );
    }
    return GlassIconButton(
      icon: Icons.chevron_left_rounded,
      label: 'Back',
      size: 26,
      onTap: close,
    );
  }
}

/// The frosted bar that holds a page's primary action above the home
/// indicator or gesture bar.
class _Dock extends StatelessWidget {
  final Widget child;
  const _Dock({required this.child});

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.strongFill,
            border: Border(top: BorderSide(color: t.separator, width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A frosted round button for a top bar, like Today's profile button.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.92,
    child: Semantics(
      button: true,
      label: label,
      child: Glass(
        blur: true,
        radius: const BorderRadius.all(Radius.circular(18)),
        child: SizedBox.square(dimension: 36, child: Icon(icon, size: size)),
      ),
    ),
  );
}
