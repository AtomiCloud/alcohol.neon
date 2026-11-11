import 'package:flutter/foundation.dart';

/// Launch timing: milliseconds since `main()` for each startup step, printed as
/// `neon-perf +<ms> <label>` lines (visible in release builds through the iOS
/// console and Android logcat) for the first 15 s after launch.
class LaunchTimeline {
  LaunchTimeline._();

  static final _clock = Stopwatch();
  static bool _shown = false;

  /// Starts the clock; called first thing in `main()`.
  static void start() => _clock.start();

  static int get elapsedMs => _clock.elapsedMilliseconds;

  /// Records a startup step.
  static void mark(String label) {
    if (!_clock.isRunning || _clock.elapsedMilliseconds > 15000) return;
    debugPrint('neon-perf +${_clock.elapsedMilliseconds} $label');
  }

  /// Records the first time Today is on screen.
  static void todayShown(String how) {
    if (_shown) return;
    _shown = true;
    mark('today-shown ($how)');
  }
}
