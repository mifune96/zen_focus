import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import '../services/settings_service.dart';

/// Possible states for the timer.
enum TimerStatus { idle, running, paused, completed }

/// Whether the current session is a focus or break period.
enum SessionType { focus, breakTime }

/// TimerProvider — the single source of truth for timer state.
///
/// ### How this prevents ANR (App Not Responding) errors:
///
/// 1. **No heavy work on the UI thread.** The only recurring work is a
///    1-second [Timer.periodic] callback that reads [DateTime.now()] and
///    calls [notifyListeners()]. Both operations are O(1).
///
/// 2. **Timestamp-based accuracy.** We store [_endTime] — the wall-clock
///    time when the timer should finish. Remaining seconds are always
///    computed as `_endTime - now`. This stays accurate through backgrounding.
///
/// 3. **Lifecycle-aware.** Implements [WidgetsBindingObserver] to
///    recalculate remaining time when the app returns to foreground.
///
/// 4. **Audio playback is asynchronous.** The [AudioPlayer] plays the
///    chime on a platform thread; it never blocks the Dart isolate.
///
/// 5. **Timer state persisted.** When the timer is running, the endTime
///    is saved to SharedPreferences. If the app is killed and reopened,
///    the timer resumes from where it was.
class TimerProvider extends ChangeNotifier with WidgetsBindingObserver {
  final SettingsService _settings;

  TimerProvider(this._settings) {
    _focusDuration = Duration(minutes: _settings.getTimerDurationMinutes());
    _breakDuration = Duration(minutes: _settings.getBreakDurationMinutes());
    _totalDuration = _focusDuration;
    _remaining = _totalDuration;
    _completedPomodoros = _settings.getCompletedPomodorosToday();
    WidgetsBinding.instance.addObserver(this);

    // Restore timer state if the app was killed while timer was running.
    _restoreTimerState();
  }

  // ───────────────────── State Fields ─────────────────────

  TimerStatus _status = TimerStatus.idle;
  TimerStatus get status => _status;

  SessionType _sessionType = SessionType.focus;
  SessionType get sessionType => _sessionType;

  Duration _focusDuration = const Duration(minutes: 25);
  Duration _breakDuration = const Duration(minutes: 5);

  Duration _totalDuration = const Duration(minutes: 25);
  Duration get totalDuration => _totalDuration;

  Duration _remaining = const Duration(minutes: 25);
  Duration get remaining => _remaining;

  int _completedPomodoros = 0;
  int get completedPomodoros => _completedPomodoros;

  /// Optional label for the current focus session.
  String _sessionLabel = '';
  String get sessionLabel => _sessionLabel;

  /// Progress from 0.0 (just started) to 1.0 (complete).
  double get progress {
    if (_totalDuration.inSeconds == 0) return 1.0;
    return 1.0 - (_remaining.inSeconds / _totalDuration.inSeconds);
  }

  /// Whether the timer is actively counting (running or paused).
  bool get isActive =>
      _status == TimerStatus.running || _status == TimerStatus.paused;

  /// Wall-clock time when the running timer should reach zero.
  DateTime? _endTime;

  /// The 1-second UI refresh ticker.
  Timer? _ticker;

  /// Audio player for the completion chime.
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ───────────────────── State Persistence ─────────────────────

  /// Saves the current timer state to SharedPreferences so it survives
  /// app kills. Only saves when the timer is actively running.
  void _saveTimerState() {
    if (_endTime != null && _status == TimerStatus.running) {
      _settings.saveTimerState(
        endTimeIso: _endTime!.toIso8601String(),
        totalDurationSeconds: _totalDuration.inSeconds,
        sessionType: _sessionType == SessionType.focus ? 'focus' : 'break',
        sessionLabel: _sessionLabel,
      );
    } else {
      _settings.clearTimerState();
    }
  }

  /// Restores timer state from SharedPreferences. Called once during init.
  void _restoreTimerState() {
    final saved = _settings.getSavedTimerState();
    if (saved == null) return;

    final endTimeIso = saved['endTime'] as String?;
    final totalSec = saved['totalDurationSeconds'] as int?;
    final sessionTypeStr = saved['sessionType'] as String?;
    final label = saved['sessionLabel'] as String?;

    if (endTimeIso == null || totalSec == null) {
      _settings.clearTimerState();
      return;
    }

    final endTime = DateTime.tryParse(endTimeIso);
    if (endTime == null) {
      _settings.clearTimerState();
      return;
    }

    final now = DateTime.now();
    final diff = endTime.difference(now);

    _totalDuration = Duration(seconds: totalSec);
    _sessionType = sessionTypeStr == 'break'
        ? SessionType.breakTime
        : SessionType.focus;
    _sessionLabel = label ?? '';

    if (diff.isNegative || diff.inSeconds <= 0) {
      // Timer already completed while app was closed.
      _remaining = Duration.zero;
      _status = TimerStatus.completed;

      if (_sessionType == SessionType.focus) {
        _settings.addFocusTime(_totalDuration.inSeconds);
        _settings.incrementCompletedPomodoros();
        _settings.recordSession(
          durationMinutes: _totalDuration.inMinutes,
          type: 'focus',
          label: _sessionLabel,
        );
        _completedPomodoros++;
      } else {
        _settings.recordSession(
          durationMinutes: _totalDuration.inMinutes,
          type: 'break',
        );
      }

      if (_settings.getSoundEnabled()) {
        _playChime();
      }

      _settings.clearTimerState();
      notifyListeners();
    } else {
      // Timer still has time left — resume it.
      _endTime = endTime;
      _remaining = diff;
      _status = TimerStatus.running;
      _startTicker();
      notifyListeners();
    }
  }

  // ───────────────────── Public API ─────────────────────

  /// Sets the focus duration (in minutes). Only allowed when idle.
  void setFocusDuration(int minutes) {
    if (_status != TimerStatus.idle) return;
    _focusDuration = Duration(minutes: minutes);
    if (_sessionType == SessionType.focus) {
      _totalDuration = _focusDuration;
      _remaining = _totalDuration;
    }
    _settings.setTimerDurationMinutes(minutes);
    notifyListeners();
  }

  /// Sets the break duration (in minutes).
  void setBreakDuration(int minutes) {
    _breakDuration = Duration(minutes: minutes);
    if (_sessionType == SessionType.breakTime && _status == TimerStatus.idle) {
      _totalDuration = _breakDuration;
      _remaining = _totalDuration;
    }
    _settings.setBreakDurationMinutes(minutes);
    notifyListeners();
  }

  /// Sets a label for the current session.
  void setSessionLabel(String label) {
    _sessionLabel = label;
    notifyListeners();
  }

  /// Starts (or resumes) the timer.
  void start() {
    if (_status == TimerStatus.running) return;

    _endTime = DateTime.now().add(_remaining);
    _status = TimerStatus.running;

    _startTicker();
    _saveTimerState(); // Persist so timer survives app kill.
    notifyListeners();
  }

  /// Pauses the timer, preserving the remaining duration.
  void pause() {
    if (_status != TimerStatus.running) return;

    _ticker?.cancel();
    _remaining = _endTime!.difference(DateTime.now());
    if (_remaining.isNegative) _remaining = Duration.zero;

    _endTime = null;
    _status = TimerStatus.paused;
    _saveTimerState(); // Clear persisted running state.
    notifyListeners();
  }

  /// Resets the timer back to idle with the focus duration.
  void reset() {
    _ticker?.cancel();

    // Save any elapsed focus time.
    if ((_status == TimerStatus.running || _status == TimerStatus.paused) &&
        _sessionType == SessionType.focus) {
      final elapsed = _totalDuration.inSeconds - _remaining.inSeconds;
      if (elapsed > 0) {
        _settings.addFocusTime(elapsed);
      }
    }

    _endTime = null;
    _sessionType = SessionType.focus;
    _totalDuration = _focusDuration;
    _remaining = _totalDuration;
    _status = TimerStatus.idle;
    _sessionLabel = '';
    _settings.clearTimerState(); // Clear persisted state.
    notifyListeners();
  }

  /// Skips the current session (break or focus) and moves to the next phase.
  void skipToNext() {
    _ticker?.cancel();
    _settings.clearTimerState();

    if (_sessionType == SessionType.focus) {
      _startBreakSession();
    } else {
      _startFocusIdle();
    }
  }

  /// Starts the break session after a completed focus session.
  void startBreak() {
    _startBreakSession();
    start(); // Auto-start the break timer.
  }

  // ───────────────────── Internal Logic ─────────────────────

  void _startBreakSession() {
    _sessionType = SessionType.breakTime;
    _totalDuration = _breakDuration;
    _remaining = _breakDuration;
    _status = TimerStatus.idle;
    _endTime = null;
    notifyListeners();
  }

  void _startFocusIdle() {
    _sessionType = SessionType.focus;
    _totalDuration = _focusDuration;
    _remaining = _focusDuration;
    _status = TimerStatus.idle;
    _endTime = null;
    _sessionLabel = '';
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
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

      if (_sessionType == SessionType.focus) {
        _settings.addFocusTime(_totalDuration.inSeconds);
        _settings.incrementCompletedPomodoros();
        _settings.recordSession(
          durationMinutes: _totalDuration.inMinutes,
          type: 'focus',
          label: _sessionLabel,
        );
        _completedPomodoros++;
      } else {
        _settings.recordSession(
          durationMinutes: _totalDuration.inMinutes,
          type: 'break',
        );
      }

      if (_settings.getSoundEnabled()) {
        _playChime();
      }

      _settings.clearTimerState(); // Timer done, clear persisted state.
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
      debugPrint('Zen Focus: Could not play chime — $e');
    }
  }

  // ───────────────────── Lifecycle Handling ─────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_status != TimerStatus.running) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _ticker?.cancel();
        _saveTimerState(); // Save state before going to background.
        break;
      case AppLifecycleState.resumed:
        _tick();
        if (_status == TimerStatus.running) {
          _startTicker();
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
