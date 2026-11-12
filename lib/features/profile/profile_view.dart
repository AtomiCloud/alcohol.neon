import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/app_loader.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';
import '../dev/dev_config_view.dart';
import '../../core/problem.dart';
import '../../generated/zinc/models/user_principal_res.dart';
import '../../session/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_modal.dart';
import '../../widgets/glass_page.dart';
import '../charity/charity_picker.dart';
import '../dashboard/today_layout.dart';
import '../friends/friends_view.dart';
import '../nfc/tag_inspector_view.dart';
import '../settings/settings_view.dart';
import '../strava/strava_view.dart';
import '../subscription/subscription_view.dart';
import '../vacation/vacation_list_view.dart';

/// Profile: who you are, the Today layout choice, and the places Profile
/// opens, grouped by what they do. Name and email come from the id-token
/// claims; verified and active come from `GET /User/Me/All`. Seven taps on the
/// name open the developer menu (which also has "Send test notification").
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  UserClaims? _claims;
  UserPrincipalRes? _user;
  bool _loading = true;
  Problem? _error;

  // Account-deletion action state (separate from the page-load _error above).
  bool _deleting = false;
  Problem? _deleteError;

  // Secret dev-menu entry: 7 taps on the name, then the dev password.
  int _nameTaps = 0;
  Timer? _tapReset;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tapReset?.cancel();
    super.dispose();
  }

  void _onNameTap() {
    _tapReset?.cancel();
    _tapReset = Timer(const Duration(seconds: 2), () => _nameTaps = 0);
    if (++_nameTaps >= 7) {
      _nameTaps = 0;
      _tapReset?.cancel();
      openDevConfig(context);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthService>();
    final session = context.read<SessionController>();

    final claims = await auth.claims();
    final meRes = await session.users.me();
    if (!mounted) return;

    switch (meRes) {
      case Ok(:final value):
        setState(() {
          _claims = claims;
          _user = value.principal;
          _loading = false;
        });
      case Err(:final problem):
        setState(() {
          _claims = claims;
          _loading = false;
          _error = problem;
        });
    }
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  // AuthService is a ChangeNotifier and RootView reacts to its status — just sign
  // out and let the shell swap to the signed-out experience (no manual nav).
  void _signOut() => context.read<AuthService>().signOut();

  /// Permanently deletes the account after an explicit irreversible confirmation.
  /// On success we sign out — RootView reacts to the status change and swaps to the
  /// signed-in/locked-out shell. A 409 means deletion is blocked by outstanding debt;
  /// we surface the server's message inline rather than a raw error.
  Future<void> _deleteAccount() async {
    final confirmed = await showGlassConfirm(
      context,
      title: 'Delete account?',
      message:
          'This permanently deletes your account and sign-in: your profile, '
          'habits, history, vacations, freeze balances, payment details and '
          'settings. It can’t be undone.\n\nPast charity-donation records are '
          'kept for accounting, with your personal details removed.',
      confirmLabel: 'Delete account',
    );
    if (!confirmed || !mounted) return;

    final session = context.read<SessionController>();
    final auth = context.read<AuthService>();
    setState(() {
      _deleting = true;
      _deleteError = null;
    });

    final res = await session.users.deleteMe();
    if (!mounted) return;

    switch (res) {
      case Ok():
        // Account + Logto identity are gone server-side; clear the local session.
        // signOut() flips to unauthenticated up front (its network revocation is
        // best-effort and benign here — the identity is already purged), which
        // pops the navigator back to the signed-out shell and disposes this
        // screen. Deliberately not awaited so the confirmation never stalls
        // behind the network; the messenger is app-level and outlives this route.
        showGlassToast(context, 'Your account has been deleted.');
        auth.signOut();
      case Err(:final problem):
        setState(() {
          _deleting = false;
          _deleteError = problem;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const GlassLoadingScreen();
    }
    return GlassPage(
      title: 'Profile',
      children: _error != null
          ? [
              GlassBanner(
                icon: Icons.error_outline_rounded,
                title: _error!.title,
                body: _error!.detail,
                error: true,
                action: GlassTextButton(label: 'Retry', onPressed: _load),
              ),
            ]
          : _content(context),
    );
  }

  List<Widget> _content(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final user = _user;
    final displayName =
        _claims?.name ??
        user?.username ??
        _claims?.email ??
        user?.email ??
        'User';
    final email = _claims?.email ?? user?.email ?? '';
    final handle = (user?.username ?? email).trim();
    final initial = handle.isEmpty ? 'U' : handle[0].toUpperCase();
    final session = context.read<SessionController>();

    return [
      if (user != null && !user.active)
        const GlassBanner(
          icon: Icons.block_rounded,
          title: 'Your account is inactive',
          error: true,
        ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Glass(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: t.accent,
                child: Text(
                  initial,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: t.onAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _onNameTap,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        displayName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: t.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (user?.emailVerified ?? false) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: t.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: t.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const _LayoutChoice(),
      GlassSection(
        title: 'Checking off',
        dividerIndent: 60,
        children: [
          GlassRow(
            leading: const IconTile(Icons.directions_run_rounded, stravaOrange),
            title: 'Strava',
            subtitle: 'Habits tick themselves off from your activities',
            onTap: () => _push(const StravaView()),
          ),
          GlassRow(
            leading: const IconTile(Icons.nfc_rounded, Color(0xFF6366F1)),
            title: 'NFC tags',
            subtitle: 'See which habit a tag ticks off',
            onTap: () => _push(const TagInspectorView()),
          ),
        ],
      ),
      GlassSection(
        title: 'Stakes',
        dividerIndent: 60,
        children: [
          GlassRow(
            leading: const IconTile(Icons.group_rounded, Color(0xFF0EA5E9)),
            title: 'Friends',
            subtitle: 'Who hears when you miss',
            onTap: () => _push(const FriendsView()),
          ),
          GlassRow(
            leading: const IconTile(Icons.favorite_rounded, Color(0xFFE11D48)),
            title: 'Charities',
            subtitle: 'Where money stakes go',
            onTap: () => _push(
              CharityBrowse(
                repository: session.charities,
                causeRepository: session.causes,
                selectionMode: false,
              ),
            ),
          ),
        ],
      ),
      GlassSection(
        title: 'Breaks',
        dividerIndent: 60,
        children: [
          GlassRow(
            leading: const IconTile(
              Icons.beach_access_rounded,
              AppColors.vacation,
            ),
            title: 'Vacations',
            subtitle: 'Pause every habit for a date range',
            onTap: () => _push(const VacationListView()),
          ),
        ],
      ),
      GlassSection(
        title: 'Account',
        dividerIndent: 60,
        children: [
          GlassRow(
            leading: const IconTile(Icons.settings_rounded, Color(0xFF71717A)),
            title: 'Settings',
            subtitle: 'Timezone, default charity and card',
            onTap: () => _push(const SettingsView()),
          ),
          GlassRow(
            leading: const IconTile(
              Icons.workspace_premium_rounded,
              Color(0xFFF59E0B),
            ),
            title: 'Plan',
            subtitle: 'See or change your plan',
            onTap: () => _push(const SubscriptionView()),
          ),
        ],
      ),
      GlassSection(
        children: [
          GlassRow(
            title: 'Sign out',
            centered: true,
            destructive: true,
            chevron: false,
            onTap: _deleting ? null : _signOut,
          ),
        ],
      ),
      if (_deleteError != null)
        GlassBanner(
          icon: Icons.error_outline_rounded,
          title:
              _deleteError!.status == 409 &&
                  (_deleteError!.detail?.trim().isEmpty ?? true)
              ? 'You have an outstanding debt. Please settle it before '
                    'deleting your account.'
              : _deleteError!.displayMessage,
          error: true,
        ),
      const SizedBox(height: 8),
      Center(
        child: GlassTextButton(
          label: _deleting ? 'Deleting…' : 'Delete account',
          destructive: true,
          onPressed: _deleting ? null : _deleteAccount,
        ),
      ),
    ];
  }
}

/// "Next up" or "Progress list" for Today, saved as soon as it is picked.
class _LayoutChoice extends StatelessWidget {
  const _LayoutChoice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    return ValueListenableBuilder<TodayLayout>(
      valueListenable: TodayLayoutSetting.instance,
      builder: (_, layout, _) {
        Widget option(TodayLayout value, String label) {
          final on = layout == value;
          return Expanded(
            child: Semantics(
              selected: on,
              button: true,
              child: Pressable(
                onTap: () => TodayLayoutSetting.instance.set(value),
                child: AnimatedContainer(
                  duration: GlassMotion.of(context, GlassMotion.fast),
                  curve: GlassMotion.curve,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    shape: const StadiumBorder(),
                    color: on ? t.accent : Colors.transparent,
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: on ? t.onAccent : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'Today layout',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: t.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Glass(
              radius: const BorderRadius.all(Radius.circular(22)),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  option(TodayLayout.nextUp, 'Next up'),
                  option(TodayLayout.progressList, 'Progress list'),
                ],
              ),
            ),
            GlassFooter(
              layout == TodayLayout.nextUp
                  ? 'Today leads with the next habit to do.'
                  : 'Today leads with the whole day’s progress.',
            ),
          ],
        );
      },
    );
  }
}
