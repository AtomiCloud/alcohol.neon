import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/problem.dart';
import '../../data/friend_repository.dart';

enum FriendsPhase { loading, ready, error }

/// State for the Friends screen: friend list, requests, search and invites.
class FriendsController extends ChangeNotifier {
  final FriendRepository _repo;
  final String _userId;

  FriendsController(this._repo, this._userId);

  FriendsPhase _phase = FriendsPhase.loading;
  Problem? _error;
  Problem? _actionError;
  List<FriendRes> _friends = const [];
  FriendRequestsRes _requests = const FriendRequestsRes(
    incoming: [],
    outgoing: [],
  );
  final _busy = <String>{};
  bool _disposed = false;

  String _query = '';
  bool _searching = false;
  Problem? _searchError;
  List<FriendCandidateRes> _results = const [];
  Timer? _debounce;
  int _searchSeq = 0;

  FriendInviteRes? _invite;
  bool _inviting = false;

  FriendsPhase get phase => _phase;
  Problem? get error => _error;
  Problem? get actionError => _actionError;
  List<FriendRes> get friends => _friends;
  FriendRequestsRes get requests => _requests;
  bool isBusy(String userId) => _busy.contains(userId);

  String get query => _query;
  bool get searching => _searching;
  Problem? get searchError => _searchError;
  List<FriendCandidateRes> get results => _results;

  FriendInviteRes? get invite => _invite;
  bool get inviting => _inviting;

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
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
    if (_phase == FriendsPhase.error) _phase = FriendsPhase.loading;
    _notify();
    final friendsCall = _repo.friends(_userId);
    final requestsCall = _repo.requests(_userId);
    final friends = await friendsCall;
    final requests = await requestsCall;
    switch ((friends, requests)) {
      case (Ok(value: final f), Ok(value: final r)):
        _friends = f;
        _requests = r;
        _phase = FriendsPhase.ready;
      case (Err(:final problem), _) || (_, Err(:final problem)):
        if (_phase == FriendsPhase.loading) {
          _phase = FriendsPhase.error;
          _error = problem;
        } else {
          _actionError = problem;
        }
    }
    _notify();
  }

  /// Debounced username-prefix search; zinc needs 2+ characters.
  void search(String q) {
    _query = q.trim();
    _debounce?.cancel();
    if (_query.length < 2) {
      _searchSeq++;
      _results = const [];
      _searching = false;
      _searchError = null;
      _notify();
      return;
    }
    _searching = true;
    _notify();
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    final seq = ++_searchSeq;
    final res = await _repo.search(_userId, _query);
    if (seq != _searchSeq) return; // a newer query won
    _searching = false;
    switch (res) {
      case Ok(:final value):
        _results = value;
        _searchError = null;
      case Err(:final problem):
        _searchError = problem;
    }
    _notify();
  }

  /// Runs one action for [userId], then reloads lists and the search.
  Future<bool> _act(
    String userId,
    Future<Result<Object?>> Function() call,
  ) async {
    _busy.add(userId);
    _actionError = null;
    _notify();
    final res = await call();
    _busy.remove(userId);
    if (res case Err(:final problem)) {
      _actionError = problem;
      _notify();
      return false;
    }
    await load();
    if (_query.length >= 2) await _runSearch();
    return true;
  }

  Future<bool> sendRequest(String userId) =>
      _act(userId, () => _repo.sendRequest(_userId, userId));

  Future<bool> accept(String userId) =>
      _act(userId, () => _repo.accept(_userId, userId));

  /// Declines an incoming request or cancels an outgoing one.
  Future<bool> deleteRequest(String userId) =>
      _act(userId, () => _repo.deleteRequest(_userId, userId));

  Future<bool> remove(String userId) =>
      _act(userId, () => _repo.remove(_userId, userId));

  Future<Result<FriendInviteRes>> createInvite() async {
    _inviting = true;
    _notify();
    final res = await _repo.createInvite(_userId);
    _inviting = false;
    if (res case Ok(:final value)) _invite = value;
    _notify();
    return res;
  }

  /// Accepts someone's invite code; on success reloads the friend list.
  Future<Result<FriendRes>> acceptInvite(String code) async {
    final res = await _repo.acceptInvite(_userId, code);
    if (res is Ok) await load();
    return res;
  }
}
