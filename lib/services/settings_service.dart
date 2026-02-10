import 'package:shared_preferences/shared_preferences.dart';

/// SettingsService — a thin abstraction over SharedPreferences.
///
/// Design decisions that prevent ANR errors:
/// 1. All disk I/O is asynchronous (await-based), so the UI thread
///    is never blocked.
/// 2. We cache the SharedPreferences instance so we only perform
///    the expensive [SharedPreferences.getInstance] call once.
/// 3. Write operations (setXxx) are fire-and-forget by default in
///    SharedPreferences, so they never block the UI.
class SettingsService {
  static const String _keyTimerDuration = 'timer_duration_minutes';
  static const String _keyThemeMode = 'theme_mode'; // 'system', 'light', 'dark'
  static const String _keyTotalFocusToday = 'total_focus_today_seconds';
  static const String _keyLastFocusDate = 'last_focus_date';

  SharedPreferences? _prefs;

  /// Initialize the SharedPreferences instance.
  /// Should be called once at app startup (in main()) so that
  /// subsequent reads are synchronous from the in-memory cache.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    assert(_prefs != null, 'SettingsService.init() must be called first.');
    return _prefs!;
  }

  // ───────────────────── Timer Duration ─────────────────────

  /// Returns the saved timer duration in minutes. Defaults to 25 (Pomodoro).
  int getTimerDurationMinutes() {
    return _p.getInt(_keyTimerDuration) ?? 25;
  }

  /// Persists the user's chosen timer duration.
  Future<void> setTimerDurationMinutes(int minutes) async {
    await _p.setInt(_keyTimerDuration, minutes);
  }

  // ───────────────────── Theme Mode ─────────────────────

  /// Returns the saved theme mode string. Defaults to 'system'.
  String getThemeMode() {
    return _p.getString(_keyThemeMode) ?? 'system';
  }

  /// Persists the user's theme choice.
  Future<void> setThemeMode(String mode) async {
    await _p.setString(_keyThemeMode, mode);
  }

  // ───────────────────── Daily Focus Statistics ─────────────────────

  /// Returns the total focus time today in seconds.
  /// Automatically resets if the date has changed since the last session.
  int getTotalFocusTodaySeconds() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = _p.getString(_keyLastFocusDate) ?? '';
    if (lastDate != today) {
      // New day → reset the counter
      _p.setInt(_keyTotalFocusToday, 0);
      _p.setString(_keyLastFocusDate, today);
      return 0;
    }
    return _p.getInt(_keyTotalFocusToday) ?? 0;
  }

  /// Adds [seconds] to today's total focus time.
  Future<void> addFocusTime(int seconds) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = _p.getString(_keyLastFocusDate) ?? '';
    int current = 0;
    if (lastDate == today) {
      current = _p.getInt(_keyTotalFocusToday) ?? 0;
    }
    await _p.setInt(_keyTotalFocusToday, current + seconds);
    await _p.setString(_keyLastFocusDate, today);
  }
}
