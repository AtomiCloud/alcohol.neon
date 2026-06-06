import 'package:flutter/foundation.dart';

import '../../core/problem.dart';
import '../../data/protection_repository.dart';
import '../../generated/zinc/models/protection_balance_res.dart';
import '../../session/session_controller.dart';

/// A small, self-contained loader for the live **freeze balance** shown in the
/// dashboard buffers strip (`GET /Protection/{userId}`). Kept separate from the
/// daily-loop [DashboardController] so the habit-overview refresh path stays clean
/// — this only ever fetches the protection balance.
class BuffersController extends ChangeNotifier {
  final String? userId;
  final ProtectionRepository _protections;

  BuffersController(SessionController session)
    : userId = session.userId,
      _protections = session.protections;

  bool _loading = false;
  ProtectionBalanceRes? _balance;
  Problem? _error;

  bool get loading => _loading;

  /// The latest protection balance, or null until first loaded (or on failure).
  ProtectionBalanceRes? get balance => _balance;

  Problem? get error => _error;

  /// Fetches the freeze balance. Best-effort: a failure is recorded in [error] and
  /// leaves the previous balance intact, so the buffers strip can degrade quietly
  /// rather than block the dashboard.
  Future<void> load() async {
    final uid = userId;
    if (uid == null) {
      _error = const Problem(
        type: 'neon:auth',
        title: 'Not signed in',
        status: 401,
      );
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();

    final res = await _protections.balance(uid);
    switch (res) {
      case Ok(:final value):
        _balance = value;
      case Err(:final problem):
        _error = problem;
    }
    _loading = false;
    notifyListeners();
  }
}
