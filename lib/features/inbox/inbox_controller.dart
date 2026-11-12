import 'package:flutter/foundation.dart';

import '../../core/problem.dart';
import '../../data/friend_repository.dart';
import '../../data/inbox_repository.dart';

enum InboxPhase { loading, ready, error }

/// How the user answered a friend request from the inbox.
enum RequestAnswer { accepted, declined }

/// State for the inbox screen: newest-first pages, mark read, and the inline
/// friend-request answers.
class InboxController extends ChangeNotifier {
  final InboxRepository _inbox;
  final FriendRepository _friends;
  final String _userId;

  static const pageSize = 20;

  InboxController(this._inbox, this._friends, this._userId);

  InboxPhase _phase = InboxPhase.loading;
  Problem? _error;
  Problem? _actionError;
  List<InboxNotificationRes> _items = const [];
  bool _hasMore = false;
  bool _loadingMore = false;
  final _busy = <String>{};
  final _answers = <String, RequestAnswer>{};
  bool _disposed = false;

  InboxPhase get phase => _phase;
  Problem? get error => _error;
  Problem? get actionError => _actionError;
  List<InboxNotificationRes> get items => _items;
  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;
  bool get hasUnread => _items.any((n) => !n.read);
  bool isBusy(String id) => _busy.contains(id);
  RequestAnswer? answerFor(String id) => _answers[id];

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void clearActionError() {
    _actionError = null;
    _notify();
  }

  Future<void> load() async {
    _error = null;
    _notify();
    final res = await _inbox.list(_userId, limit: pageSize, skip: 0);
    switch (res) {
      case Ok(:final value):
        _items = value;
        _hasMore = value.length == pageSize;
        _phase = InboxPhase.ready;
      case Err(:final problem):
        if (_phase == InboxPhase.ready) {
          _actionError = problem;
        } else {
          _phase = InboxPhase.error;
          _error = problem;
        }
    }
    _notify();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    _notify();
    final res = await _inbox.list(
      _userId,
      limit: pageSize,
      skip: _items.length,
    );
    _loadingMore = false;
    switch (res) {
      case Ok(:final value):
        final seen = {for (final n in _items) n.id};
        _items = [..._items, ...value.where((n) => !seen.contains(n.id))];
        _hasMore = value.length == pageSize;
      case Err(:final problem):
        _actionError = problem;
    }
    _notify();
  }

  void _setRead(String id) {
    final now = DateTime.now().toUtc();
    _items = [
      for (final n in _items)
        n.id == id && !n.read
            ? InboxNotificationRes(
                id: n.id,
                kind: n.kind,
                title: n.title,
                body: n.body,
                actorUserId: n.actorUserId,
                data: n.data,
                createdAtUtc: n.createdAtUtc,
                readAtUtc: now,
              )
            : n,
    ];
  }

  Future<void> markRead(InboxNotificationRes n) async {
    if (n.read) return;
    _setRead(n.id);
    _notify();
    final res = await _inbox.markRead(_userId, n.id);
    if (res case Err(:final problem)) {
      _actionError = problem;
      _notify();
    }
  }

  Future<void> markAllRead() async {
    final res = await _inbox.markAllRead(_userId);
    switch (res) {
      case Ok():
        for (final n in _items) {
          _setRead(n.id);
        }
      case Err(:final problem):
        _actionError = problem;
    }
    _notify();
  }

  /// Accepts or declines the request behind notification [n].
  Future<void> answer(
    InboxNotificationRes n,
    String fromUserId, {
    required bool accept,
  }) async {
    _busy.add(n.id);
    _actionError = null;
    _notify();
    final Result<Object?> res = accept
        ? await _friends.accept(_userId, fromUserId)
        : await _friends.deleteRequest(_userId, fromUserId);
    _busy.remove(n.id);
    switch (res) {
      case Ok():
        _answers[n.id] = accept
            ? RequestAnswer.accepted
            : RequestAnswer.declined;
        await markRead(n);
      case Err(:final problem):
        // 404: the request is gone (answered elsewhere or cancelled).
        _actionError = problem.status == 404
            ? Problem.local('That request is no longer open.')
            : problem;
    }
    _notify();
  }
}
