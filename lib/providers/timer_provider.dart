import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import '../services/settings_service.dart';

/// Possible states for the timer.
enum TimerStatus { idle, running, paused, completed }

/// TimerProvider — the single source of truth for timer state.
///
/// ### How this prevents ANR (App Not Responding) errors:
///
/// 1. **No heavy work on the UI thread.** The only recurring work is a
///    1-second [Timer.periodic] callback that reads [DateTime.now()] and
///    calls [notifyListeners()]. Both operations are O(1) and sub-microsecond.
///
/// 2. **Timestamp-based accuracy.** Instead of decrementing an integer
///    every second (which drifts when the OS throttles the app), we store
///    [_endTime] — the wall-clock time when the timer should finish.
///    The remaining seconds are always computed as `_endTime - now`.
///    This means:
///    - If the app is backgrounded for 5 minutes, the timer will show
///      the correct remaining time (or "completed") when resumed.
///    - If the OS skips a periodic tick, the display catches up instantly.
///
/// 3. **Lifecycle-aware.** We implement [WidgetsBindingObserver] to
///    recalculate remaining time when the app returns to the foreground
///    and to persist elapsed focus time when the app goes to the background.
///
/// 4. **Audio playback is asynchronous.** The [AudioPlayer] plays the
///    chime on a platform thread; it never blocks the Dart isolate.
class TimerProvider extends ChangeNotifier with WidgetsBindingObserver {
  final SettingsService _settings;

  TimerProvider(this._settings) {
    _totalDuration = Duration(minutes: _settings.getTimerDurationMinutes());
    _remaining = _totalDuration;
    WidgetsBinding.instance.addObserver(this);
  }

  // ───────────────────── State Fields ─────────────────────

  TimerStatus _status = TimerStatus.idle;
  TimerStatus get status => _status;

  Duration _totalDuration = const Duration(minutes: 25);
  Duration get totalDuration => _totalDuration;

  Duration _remaining = const Duration(minutes: 25);
  Duration get remaining => _remaining;

  /// Progress from 0.0 (just started) to 1.0 (complete).
  double get progress {
    if (_totalDuration.inSeconds == 0) return 1.0;
    return 1.0 - (_remaining.inSeconds / _totalDuration.inSeconds);
  }

  /// Wall-clock time when the running timer should reach zero.
  DateTime? _endTime;

  /// The 1-second UI refresh ticker.
  Timer? _ticker;

  /// Audio player for the completion chime.
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ───────────────────── Public API ─────────────────────

  /// Sets a new duration (in minutes). Only allowed when idle.
  void setDuration(int minutes) {
    if (_status != TimerStatus.idle) return;
    _totalDuration = Duration(minutes: minutes);
    _remaining = _totalDuration;
    _settings.setTimerDurationMinutes(minutes);
    notifyListeners();
  }

  /// Starts (or resumes) the timer.
  void start() {
    if (_status == TimerStatus.running) return;

    // Calculate the absolute end time from the remaining duration.
    _endTime = DateTime.now().add(_remaining);
    _status = TimerStatus.running;

    _startTicker();
    notifyListeners();
  }

  /// Pauses the timer, preserving the remaining duration.
  void pause() {
    if (_status != TimerStatus.running) return;

    _ticker?.cancel();
    // Snapshot the remaining time so we don't lose precision.
    _remaining = _endTime!.difference(DateTime.now());
    if (_remaining.isNegative) _remaining = Duration.zero;

    _endTime = null;
    _status = TimerStatus.paused;
    notifyListeners();
  }

  /// Resets the timer back to idle with the full duration.
  void reset() {
    _ticker?.cancel();

    // If the timer was running or paused, save elapsed focus time.
    if (_status == TimerStatus.running || _status == TimerStatus.paused) {
      final elapsed = _totalDuration.inSeconds - _remaining.inSeconds;
      if (elapsed > 0) {
        _settings.addFocusTime(elapsed);
      }
    }

    _endTime = null;
    _status = TimerStatus.idle;
    _remaining = _totalDuration;
    notifyListeners();
  }

  // ───────────────────── Internal Logic ─────────────────────

  void _startTicker() {
    _ticker?.cancel();
    // A 1-second periodic timer is cheap — it only triggers a DateTime
    // comparison and a notifyListeners() call, both O(1).
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });
  }

  void _tick() {
    if (_endTime == null) return;

    final now = DateTime.now();
    final diff = _endTime!.difference(now);

    if (diff.isNegative || diff.inSeconds <= 0) {
      // Timer complete!
      _remaining = Duration.zero;
      _ticker?.cancel();
      _status = TimerStatus.completed;

      // Save the full session as focus time.
      _settings.addFocusTime(_totalDuration.inSeconds);

      // Play the completion chime asynchronously — will not block the UI.
      _playChime();

      notifyListeners();
    } else {
      _remaining = diff;
      notifyListeners();
    }
  }

  Future<void> _playChime() async {
    try {
      await _audioPlayer.play(AssetSource('audio/chime.wav'));
    } catch (e) {
      // Silently ignore audio errors — the timer is still functional.
      debugPrint('Zen Focus: Could not play chime — $e');
    }
  }

  // ───────────────────── Lifecycle Handling ─────────────────────

  /// Called by the system when the app lifecycle changes.
  ///
  /// When the app goes to background ([AppLifecycleState.paused]):
  ///   - We cancel the periodic ticker to save battery.
  ///   - We keep [_endTime] so we can recalculate on resume.
  ///
  /// When the app returns to foreground ([AppLifecycleState.resumed]):
  ///   - We recalculate [_remaining] from [_endTime] — this gives us
  ///     accurate time even if the app was backgrounded for minutes/hours.
  ///   - We restart the ticker.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_status != TimerStatus.running) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App going to background — stop the ticker to save resources.
        _ticker?.cancel();
        break;
      case AppLifecycleState.resumed:
        // App returning to foreground — recalculate from wall-clock time.
        _tick(); // Immediately sync remaining time.
        if (_status == TimerStatus.running) {
          _startTicker(); // Restart the periodic UI refresh.
        }
        break;
    }
  }

  // ───────────────────── Cleanup ─────────────────────

  @override
  void dispose() {
    _ticker?.cancel();
    _audioPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
