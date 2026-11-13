import 'package:flutter/material.dart';

import '../../core/problem.dart';
import '../../data/friend_repository.dart';
import '../../data/friend_stake_repository.dart';
import '../../theme/glass.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_modal.dart';
import 'friends_view.dart';

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 18,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: GlassTokens.of(context).muted,
    ),
  );
}

/// The "Tell my friends if I miss" picker: up to
/// [FriendStakeRepository.maxWatchers] of [load]'s friends, starting from the
/// ids in [initial]. Returns the picked friends (empty turns it off), or null
/// when dismissed.
Future<List<FriendRes>?> pickFriendWatchers(
  BuildContext context, {
  required Future<Result<List<FriendRes>>> Function() load,
  required Set<String> initial,
}) => showGlassSheet<List<FriendRes>>(
  context,
  (_) => _WatcherSheet(load: load, initial: initial),
);

class _WatcherSheet extends StatefulWidget {
  final Future<Result<List<FriendRes>>> Function() load;
  final Set<String> initial;
  const _WatcherSheet({required this.load, required this.initial});

  @override
  State<_WatcherSheet> createState() => _WatcherSheetState();
}

class _WatcherSheetState extends State<_WatcherSheet> {
  late final Set<String> _picked = {...widget.initial};
  Result<List<FriendRes>>? _friends;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _friends = null);
    final res = await widget.load();
    if (mounted) setState(() => _friends = res);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const max = FriendStakeRepository.maxWatchers;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: GlassTokens.of(context).muted,
    );
    final Widget list = switch (_friends) {
      null => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: _Spinner()),
      ),
      Err(:final problem) => GlassBanner(
        icon: Icons.error_outline_rounded,
        title: problem.displayMessage,
        error: true,
        action: GlassTextButton(label: 'Retry', onPressed: _fetch),
      ),
      Ok(:final value) when value.isEmpty => Glass(
        child: GlassRow(
          leading: const Icon(Icons.group_add_outlined),
          title: 'Add friends first',
          subtitle: 'Only friends can be told.',
          chevron: true,
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FriendsView()));
          },
        ),
      ),
      Ok(:final value) => Glass(
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: value.length,
          separatorBuilder: (_, _) => Padding(
            padding: const EdgeInsets.only(left: 66),
            child: Divider(
              height: 0.5,
              color: GlassTokens.of(context).separator,
            ),
          ),
          itemBuilder: (context, i) {
            final f = value[i];
            final on = _picked.contains(f.userId);
            final full = !on && _picked.length >= max;
            return Semantics(
              checked: on,
              child: Opacity(
                opacity: full ? 0.45 : 1,
                child: GlassRow(
                  leading: FriendAvatar(f.username),
                  title: f.username,
                  chevron: false,
                  trailing: Icon(
                    on
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: on
                        ? GlassTokens.of(context).accent
                        : GlassTokens.of(context).muted,
                  ),
                  onTap: full
                      ? null
                      : () => setState(
                          () => on
                              ? _picked.remove(f.userId)
                              : _picked.add(f.userId),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    };
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tell my friends if I miss',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'The friends you pick get a note in their LazyTax inbox only '
                'when a day of this habit ends Missed. They see the habit name '
                'and the day — never your stake or anything from Strava. Up to '
                '$max friends.',
                style: muted,
              ),
              const SizedBox(height: 8),
              Flexible(child: list),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.initial.isNotEmpty) ...[
                    Expanded(
                      child: GlassButton(
                        label: 'Turn off',
                        secondary: true,
                        onPressed: () =>
                            Navigator.of(context).pop(<FriendRes>[]),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: GlassButton(
                      label: 'Save',
                      onPressed: switch (_friends) {
                        Ok(:final value) => () => Navigator.of(context).pop([
                          for (final f in value)
                            if (_picked.contains(f.userId)) f,
                        ]),
                        _ => null,
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
