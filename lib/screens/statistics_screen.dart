import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

/// StatisticsScreen — shows daily focus time history and session log.
///
/// ANR Prevention: All data reads are from in-memory SharedPreferences
/// cache — zero disk I/O during build().
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final weekStats = settings.getStatsForLastDays(7);
    final totalToday = settings.getTotalFocusTodaySeconds();
    final pomodorosToday = settings.getCompletedPomodorosToday();
    final sessionHistory = settings.getSessionHistory();

    // Calculate total this week.
    final totalWeekSeconds = weekStats.values.fold<int>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Today's Summary Cards ───
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Today',
                    value: _formatDuration(totalToday),
                    color: colorScheme.primary,
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Sessions',
                    value: '$pomodorosToday',
                    color: colorScheme.secondary,
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.calendar_today_rounded,
                    label: 'This Week',
                    value: _formatDuration(totalWeekSeconds),
                    color: colorScheme.tertiary,
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ─── Weekly Bar Chart ───
            Text(
              'Last 7 Days',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _WeeklyChart(
              weekStats: weekStats,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(height: 28),

            // ─── Session History ───
            Text(
              'Recent Sessions',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            if (sessionHistory.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 48,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No sessions yet.\nComplete a focus session to see it here.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...sessionHistory
                  .take(20)
                  .map(
                    (session) => _SessionTile(
                      session: session,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m';
    return '0m';
  }
}

// ══════════════════════════════════════════════════════════
//  Private Sub-Widgets
// ══════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple bar chart showing the last 7 days of focus time.
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({
    required this.weekStats,
    required this.colorScheme,
    required this.textTheme,
  });

  final Map<String, int> weekStats;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final entries = weekStats.entries.toList().reversed.toList();
    final maxSeconds = entries
        .map((e) => e.value)
        .fold<int>(1, (a, b) => a > b ? a : b);
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: entries.map((entry) {
          final date = DateTime.tryParse(entry.key);
          final dayLabel = date != null ? dayNames[date.weekday - 1] : '?';
          final fraction = entry.value / maxSeconds;
          final minutes = entry.value ~/ 60;
          final isToday =
              entry.key == DateTime.now().toIso8601String().substring(0, 10);

          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  minutes > 0 ? '${minutes}m' : '',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  height: (fraction * 100).clamp(4.0, 100.0),
                  width: 24,
                  decoration: BoxDecoration(
                    color: isToday
                        ? colorScheme.primary
                        : colorScheme.primary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: isToday
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// A single session history tile.
class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.colorScheme,
    required this.textTheme,
  });

  final Map<String, dynamic> session;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final type = session['type'] as String? ?? 'focus';
    final duration = session['duration'] as int? ?? 0;
    final label = session['label'] as String? ?? '';
    final dateStr = session['date'] as String? ?? '';
    final date = DateTime.tryParse(dateStr);

    final isFocus = type == 'focus';
    final icon = isFocus
        ? Icons.local_fire_department_rounded
        : Icons.coffee_rounded;
    final color = isFocus ? colorScheme.primary : colorScheme.tertiary;

    String timeAgo = '';
    if (date != null) {
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) {
        timeAgo = 'Just now';
      } else if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${diff.inDays}d ago';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFocus
                      ? (label.isNotEmpty ? label : 'Focus Session')
                      : 'Break',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${duration}min • $timeAgo',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isFocus ? Icons.check_circle_rounded : Icons.done_rounded,
            color: color.withValues(alpha: 0.5),
            size: 20,
          ),
        ],
      ),
    );
  }
}
