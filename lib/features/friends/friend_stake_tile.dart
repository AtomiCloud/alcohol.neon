import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/problem.dart';
import '../../data/friend_repository.dart';
import '../../data/friend_stake_repository.dart';
import '../../session/session_controller.dart';
import 'friends_view.dart';
import '../../widgets/compact_buttons.dart';

/// Habit editor card: "Tell my friends if I miss". Saves on its own (not
/// with "Save changes"). Hidden when zinc has no FriendStake route (404).
class FriendStakeTile extends StatefulWidget {
  final String habitId;
  const FriendStakeTile({super.key, required this.habitId});

  @override
  State<FriendStakeTile> createState() => _FriendStakeTileState();
}

enum _Phase { loading, hidden, ready, error }

class _FriendStakeTileState extends State<FriendStakeTile> {
  late final SessionController _session;
  late final FriendStakeRepository _stakes;
  late final FriendRepository _friends;

  _Phase _phase = _Phase.loading;
  Problem? _error;
  List<FriendWatcherRes> _watchers = const [];
  bool _saving = false;
  Problem? _saveError;

  @override
  void initState() {
    super.initState();
    _session = context.read<SessionController>();
    final api = _session.auth.makeApiClient();
    _stakes = FriendStakeRepository(api);
    _friends = FriendRepository(api);
    _load();
  }

  Future<void> _load() async {
    final uid = _session.userId;
    if (uid == null) return;
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    final res = await _stakes.get(uid, widget.habitId);
    if (!mounted) return;
    setState(() {
      switch (res) {
        case Ok(:final value):
          _watchers = value.friends;
          _phase = _Phase.ready;
        case Err(:final problem) when problem.status == 404:
          _phase = _Phase.hidden;
        case Err(:final problem):
          _error = problem;
          _phase = _Phase.error;
      }
    });
  }

  Future<void> _edit() async {
    final uid = _session.userId;
    if (uid == null) return;
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _WatcherSheet(
        load: () => _friends.friends(uid),
        initial: {for (final w in _watchers) w.userId},
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final res = await _stakes.set(uid, widget.habitId, picked);
    if (!mounted) return;
    setState(() {
      _saving = false;
      switch (res) {
        case Ok(:final value):
          _watchers = value.friends;
        case Err(:final problem):
          _saveError = problem;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const title = Text('Tell my friends if I miss');
    const icon = Icon(Icons.campaign_outlined);
    switch (_phase) {
      case _Phase.hidden:
        return const SizedBox.shrink();
      case _Phase.loading:
        return const Card(
          child: ListTile(
            leading: icon,
            title: title,
            subtitle: LinearProgressIndicator(),
          ),
        );
      case _Phase.error:
        return Card(
          child: ListTile(
            leading: icon,
            title: title,
            subtitle: Text(_error?.displayMessage ?? 'Could not load'),
            trailing: TextButton(onPressed: _load, child: const Text('Retry')),
          ),
        );
      case _Phase.ready:
        break;
    }
    final names = _watchers.map((w) => w.username).join(', ');
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: icon,
            title: title,
            subtitle: Text(
              _watchers.isEmpty
                  ? 'Off'
                  : 'Telling ${_watchers.length == 1 ? names : '${_watchers.length} friends: $names'}',
            ),
            trailing: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _saving ? null : _edit,
          ),
          if (_saveError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                _saveError!.displayMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pick up to [FriendStakeRepository.maxWatchers] friends; pops their ids
/// (empty turns it off), or null when dismissed.
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
      color: theme.colorScheme.onSurfaceVariant,
    );
    final Widget list = switch (_friends) {
      null => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      Err(:final problem) => ListTile(
        title: Text(problem.displayMessage),
        trailing: TextButton(onPressed: _fetch, child: const Text('Retry')),
      ),
      Ok(:final value) when value.isEmpty => ListTile(
        leading: const Icon(Icons.group_add_outlined),
        title: const Text('Add friends first'),
        subtitle: const Text('Only friends can be told.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const FriendsView()));
        },
      ),
      Ok(:final value) => ListView(
        shrinkWrap: true,
        children: [
          for (final f in value)
            CheckboxListTile(
              value: _picked.contains(f.userId),
              title: Text(f.username),
              onChanged: !_picked.contains(f.userId) && _picked.length >= max
                  ? null
                  : (on) => setState(
                      () => on == true
                          ? _picked.add(f.userId)
                          : _picked.remove(f.userId),
                    ),
            ),
        ],
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
                style: theme.textTheme.titleLarge,
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
              CompactButtons(
                child: Row(
                  children: [
                    if (widget.initial.isNotEmpty)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(<String>[]),
                        child: const Text('Turn off'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _friends is Ok
                          ? () => Navigator.of(context).pop(_picked.toList())
                          : null,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
