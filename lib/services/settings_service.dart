import 'dart:convert';
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
  static const String _keyBreakDuration = 'break_duration_minutes';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keyDailyStats = 'daily_stats'; // JSON map
  static const String _keyCompletedPomodoros = 'completed_pomodoros_today';
  static const String _keyLastStatsDate = 'last_stats_date';
  static const String _keySessionHistory = 'session_history'; // JSON list

  SharedPreferences? _prefs;

  /// Initialize the SharedPreferences instance.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    assert(_prefs != null, 'SettingsService.init() must be called first.');
    return _prefs!;
  }

  // ───────────────────── Timer Duration ─────────────────────

  int getTimerDurationMinutes() {
    return _p.getInt(_keyTimerDuration) ?? 25;
  }

  Future<void> setTimerDurationMinutes(int minutes) async {
    await _p.setInt(_keyTimerDuration, minutes);
  }

  // ───────────────────── Break Duration ─────────────────────

  int getBreakDurationMinutes() {
    return _p.getInt(_keyBreakDuration) ?? 5;
  }

  Future<void> setBreakDurationMinutes(int minutes) async {
    await _p.setInt(_keyBreakDuration, minutes);
  }

  // ───────────────────── Theme Mode ─────────────────────

  String getThemeMode() {
    return _p.getString(_keyThemeMode) ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    await _p.setString(_keyThemeMode, mode);
  }

  // ───────────────────── Sound Enabled ─────────────────────

  bool getSoundEnabled() {
    return _p.getBool(_keySoundEnabled) ?? true;
  }

  Future<void> setSoundEnabled(bool enabled) async {
    await _p.setBool(_keySoundEnabled, enabled);
  }

  // ───────────────────── Daily Focus Statistics ─────────────────────

  /// Returns focus time for a specific date (in seconds).
  int getFocusTimeForDate(String dateKey) {
    final stats = _getDailyStatsMap();
    return stats[dateKey] ?? 0;
  }

  /// Returns today's total focus time in seconds.
  int getTotalFocusTodaySeconds() {
    final today = _todayKey();
    return getFocusTimeForDate(today);
  }

  /// Adds [seconds] to a specific date's total focus time.
  Future<void> addFocusTime(int seconds) async {
    final today = _todayKey();
    final stats = _getDailyStatsMap();
    stats[today] = (stats[today] ?? 0) + seconds;

    // Keep only last 30 days to prevent unbounded storage growth.
    _pruneOldEntries(stats, 30);

    await _p.setString(_keyDailyStats, jsonEncode(stats));
  }

  /// Returns a map of the last [days] days: { "YYYY-MM-DD": seconds }.
  Map<String, int> getStatsForLastDays(int days) {
    final stats = _getDailyStatsMap();
    final result = <String, int>{};
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final key = _dateToKey(date);
      result[key] = stats[key] ?? 0;
    }
    return result;
  }

  // ───────────────────── Completed Pomodoros Today ─────────────────────

  int getCompletedPomodorosToday() {
    final today = _todayKey();
    final lastDate = _p.getString(_keyLastStatsDate) ?? '';
    if (lastDate != today) {
      _p.setInt(_keyCompletedPomodoros, 0);
      _p.setString(_keyLastStatsDate, today);
      return 0;
    }
    return _p.getInt(_keyCompletedPomodoros) ?? 0;
  }

  Future<void> incrementCompletedPomodoros() async {
    final today = _todayKey();
    final lastDate = _p.getString(_keyLastStatsDate) ?? '';
    int current = 0;
    if (lastDate == today) {
      current = _p.getInt(_keyCompletedPomodoros) ?? 0;
    }
    await _p.setInt(_keyCompletedPomodoros, current + 1);
    await _p.setString(_keyLastStatsDate, today);
  }

  // ───────────────────── Session History ─────────────────────

  /// Records a completed session with timestamp and duration.
  Future<void> recordSession({
    required int durationMinutes,
    required String type, // 'focus' or 'break'
    String? label,
  }) async {
    final history = getSessionHistory();
    history.insert(0, {
      'date': DateTime.now().toIso8601String(),
      'duration': durationMinutes,
      'type': type,
      'label': label ?? '',
    });

    // Keep only last 100 sessions.
    if (history.length > 100) {
      history.removeRange(100, history.length);
    }

    await _p.setString(_keySessionHistory, jsonEncode(history));
  }

  /// Returns the list of past sessions.
  List<Map<String, dynamic>> getSessionHistory() {
    final raw = _p.getString(_keySessionHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static const String _keyRunningEndTime = 'running_end_time';
  static const String _keyRunningTotalDuration = 'running_total_duration';
  static const String _keyRunningSessionType = 'running_session_type';
  static const String _keyRunningSessionLabel = 'running_session_label';

  // ───────────────────── Timer State Persistence ─────────────────────

  /// Saves the running timer state so it survives app kills.
  Future<void> saveTimerState({
    required String endTimeIso,
    required int totalDurationSeconds,
    required String sessionType,
    required String sessionLabel,
  }) async {
    await _p.setString(_keyRunningEndTime, endTimeIso);
    await _p.setInt(_keyRunningTotalDuration, totalDurationSeconds);
    await _p.setString(_keyRunningSessionType, sessionType);
    await _p.setString(_keyRunningSessionLabel, sessionLabel);
  }

  /// Clears the saved timer state (called when timer completes or resets).
  Future<void> clearTimerState() async {
    await _p.remove(_keyRunningEndTime);
    await _p.remove(_keyRunningTotalDuration);
    await _p.remove(_keyRunningSessionType);
    await _p.remove(_keyRunningSessionLabel);
  }

  /// Returns the saved timer state, or null if none exists.
  Map<String, dynamic>? getSavedTimerState() {
    final endTime = _p.getString(_keyRunningEndTime);
    if (endTime == null) return null;
    return {
      'endTime': endTime,
      'totalDurationSeconds': _p.getInt(_keyRunningTotalDuration),
      'sessionType': _p.getString(_keyRunningSessionType),
      'sessionLabel': _p.getString(_keyRunningSessionLabel),
    };
  }

  // ───────────────────── Helpers ─────────────────────

  String _todayKey() => _dateToKey(DateTime.now());

  String _dateToKey(DateTime date) => date.toIso8601String().substring(0, 10);

  Map<String, int> _getDailyStatsMap() {
    final raw = _p.getString(_keyDailyStats);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  void _pruneOldEntries(Map<String, int> stats, int keepDays) {
    final cutoff = DateTime.now().subtract(Duration(days: keepDays));
    final cutoffKey = _dateToKey(cutoff);
    stats.removeWhere((key, _) => key.compareTo(cutoffKey) < 0);
  }
}
