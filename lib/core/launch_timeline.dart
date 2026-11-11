import 'package:flutter/foundation.dart';

/// Launch timing: milliseconds since `main()` for each startup step, printed as
/// `neon-perf +<ms> <label>` lines (visible in release builds through the iOS
/// console and Android logcat). [mark] is a no-op once Today has been shown.
class LaunchTimeline {
  LaunchTimeline._();

  static final _clock = Stopwatch();
  static bool _done = false;

  /// Starts the clock; called first thing in `main()`.
  static void start() => _clock.start();

  static int get elapsedMs => _clock.elapsedMilliseconds;

  /// Records a startup step.
  static void mark(String label) {
    if (_done || !_clock.isRunning) return;
    debugPrint('neon-perf +${_clock.elapsedMilliseconds} $label');
  }

  /// Records that Today is on screen and stops further marks.
  static void todayShown(String how) {
    mark('today-shown ($how)');
    _done = true;
  }
}
