import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/timer_provider.dart';
import '../services/settings_service.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';

/// HomeScreen — the main UI for Zen Focus.
///
/// ANR Prevention Notes:
/// - The widget tree rebuilds only when [TimerProvider] calls
///   notifyListeners() — at most once per second.
/// - We use [Consumer] to scope rebuilds to only the widgets that
///   actually depend on timer state, avoiding full-tree rebuilds.
/// - No synchronous file I/O or heavy computation happens in build().
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final settings = Provider.of<SettingsService>(context, listen: false);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final timer = Provider.of<TimerProvider>(context, listen: false);
        if (timer.isActive) {
          // Timer is running/paused — minimize app instead of closing.
          // Timer state is persisted and will resume on reopen.
          SystemNavigator.pop();
        } else {
          // Timer idle — allow normal back behavior (close app).
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        // ─── App Bar with navigation icons ───
        appBar: AppBar(
          title: Text(
            'Zen Focus',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Statistics',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              );
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Consumer<TimerProvider>(
                builder: (context, timer, _) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ─── Daily Stats Badge ───
                      _DailyStatsChip(
                        settings: settings,
                        timer: timer,
                        textTheme: textTheme,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 12),

                      // ─── Session Type Indicator ───
                      _SessionTypeChip(timer: timer, colorScheme: colorScheme),
                      const SizedBox(height: 32),

                      // ─── Circular Timer ───
                      _CircularTimer(
                        timer: timer,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 24),

                      // ─── Status Label ───
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _statusLabel(timer.status, timer.sessionType),
                          key: ValueKey('${timer.status}_${timer.sessionType}'),
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── Session Label Input (only while idle, focus mode) ───
                      if (timer.status == TimerStatus.idle &&
                          timer.sessionType == SessionType.focus)
                        _SessionLabelInput(
                          timer: timer,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                      if (timer.status == TimerStatus.idle &&
                          timer.sessionType == SessionType.focus)
                        const SizedBox(height: 20),

                      // ─── Duration Presets (only idle + focus) ───
                      if (timer.status == TimerStatus.idle &&
                          timer.sessionType == SessionType.focus)
                        _DurationPresets(
                          timer: timer,
                          colorScheme: colorScheme,
                        ),
                      if (timer.status == TimerStatus.idle &&
                          timer.sessionType == SessionType.focus)
                        const SizedBox(height: 28),

                      // ─── Controls ───
                      _Controls(timer: timer, colorScheme: colorScheme),

                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(TimerStatus status, SessionType sessionType) {
    if (sessionType == SessionType.breakTime) {
      switch (status) {
        case TimerStatus.idle:
          return 'BREAK TIME';
        case TimerStatus.running:
          return 'TAKING A BREAK';
        case TimerStatus.paused:
          return 'BREAK PAUSED';
        case TimerStatus.completed:
          return 'BREAK OVER';
      }
    }
    switch (status) {
      case TimerStatus.idle:
        return 'READY TO FOCUS';
      case TimerStatus.running:
        return 'FOCUSING';
      case TimerStatus.paused:
        return 'PAUSED';
      case TimerStatus.completed:
        return 'SESSION COMPLETE';
    }
  }
}

// ══════════════════════════════════════════════════════════
//  Private Sub-Widgets
// ══════════════════════════════════════════════════════════

/// Shows today's stats and completed pomodoro count.
class _DailyStatsChip extends StatelessWidget {
  const _DailyStatsChip({
    required this.settings,
    required this.timer,
    required this.textTheme,
    required this.colorScheme,
  });

  final SettingsService settings;
  final TimerProvider timer;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final totalSeconds = settings.getTotalFocusTodaySeconds();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final pomodoros = timer.completedPomodoros;

    String focusText;
    if (hours > 0) {
      focusText = '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      focusText = '${minutes}m';
    } else {
      focusText = '0m';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 18,
            color: colorScheme.secondary,
          ),
          const SizedBox(width: 6),
          Text(
            '$focusText focused',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (pomodoros > 0) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 1,
              height: 14,
              color: colorScheme.onSecondaryContainer.withValues(alpha: 0.3),
            ),
            Icon(
              Icons.check_circle_outline_rounded,
              size: 16,
              color: colorScheme.secondary,
            ),
            const SizedBox(width: 4),
            Text(
              '$pomodoros',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shows whether we're in focus or break mode.
class _SessionTypeChip extends StatelessWidget {
  const _SessionTypeChip({required this.timer, required this.colorScheme});

  final TimerProvider timer;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final isFocus = timer.sessionType == SessionType.focus;
    final color = isFocus ? colorScheme.primary : colorScheme.tertiary;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(timer.sessionType),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFocus ? Icons.psychology_rounded : Icons.coffee_rounded,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              isFocus ? 'Focus' : 'Break',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optional label like "Study", "Work", etc.
class _SessionLabelInput extends StatelessWidget {
  const _SessionLabelInput({
    required this.timer,
    required this.colorScheme,
    required this.textTheme,
  });

  final TimerProvider timer;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final labels = ['Study', 'Work', 'Read', 'Exercise', 'Code', 'Create'];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: labels.map((label) {
        final isSelected = timer.sessionLabel == label;
        return GestureDetector(
          onTap: () {
            timer.setSessionLabel(isSelected ? '' : label);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// The main circular progress indicator with the countdown digits.
class _CircularTimer extends StatelessWidget {
  const _CircularTimer({
    required this.timer,
    required this.colorScheme,
    required this.textTheme,
  });

  final TimerProvider timer;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final minutes = timer.remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = timer.remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    final isFocus = timer.sessionType == SessionType.focus;

    Color ringColor;
    switch (timer.status) {
      case TimerStatus.running:
        ringColor = isFocus ? colorScheme.primary : colorScheme.tertiary;
        break;
      case TimerStatus.paused:
        ringColor = colorScheme.secondary;
        break;
      case TimerStatus.completed:
        ringColor = isFocus ? colorScheme.primary : colorScheme.tertiary;
        break;
      case TimerStatus.idle:
        ringColor = colorScheme.surfaceContainerHighest;
        break;
    }

    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          SizedBox(
            width: 260,
            height: 260,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
          ),
          // Progress ring
          SizedBox(
            width: 260,
            height: 260,
            child: CircularProgressIndicator(
              value: timer.status == TimerStatus.idle ? 0.0 : timer.progress,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              color: ringColor,
              backgroundColor: Colors.transparent,
            ),
          ),
          // Inner content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Session label
              if (timer.sessionLabel.isNotEmpty &&
                  timer.sessionType == SessionType.focus)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    timer.sessionLabel,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              Text(
                '$minutes:$seconds',
                style: textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w200,
                  fontSize: 64,
                  letterSpacing: 4,
                  color: colorScheme.onSurface,
                ),
              ),
              if (timer.status == TimerStatus.completed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    color: isFocus ? colorScheme.primary : colorScheme.tertiary,
                    size: 28,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Row of preset duration chips.
class _DurationPresets extends StatelessWidget {
  const _DurationPresets({required this.timer, required this.colorScheme});

  final TimerProvider timer;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    const presets = [5, 15, 25, 30, 45, 60];
    final currentMinutes = timer.totalDuration.inMinutes;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: presets.map((m) {
        final isSelected = m == currentMinutes;
        return ChoiceChip(
          label: Text('$m min'),
          selected: isSelected,
          onSelected: (_) => timer.setFocusDuration(m),
          selectedColor: colorScheme.primaryContainer,
          labelStyle: TextStyle(
            color: isSelected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side: BorderSide(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.3)
                : colorScheme.outlineVariant,
          ),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        );
      }).toList(),
    );
  }
}

/// Start, Pause, Resume, Reset, Break controls.
class _Controls extends StatelessWidget {
  const _Controls({required this.timer, required this.colorScheme});

  final TimerProvider timer;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final isFocus = timer.sessionType == SessionType.focus;

    switch (timer.status) {
      case TimerStatus.idle:
        return _PrimaryButton(
          label: isFocus ? 'Start Focus' : 'Start Break',
          icon: Icons.play_arrow_rounded,
          onPressed: timer.start,
          colorScheme: colorScheme,
          isFocus: isFocus,
        );

      case TimerStatus.running:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SecondaryButton(
              label: 'Reset',
              icon: Icons.refresh_rounded,
              onPressed: timer.reset,
              colorScheme: colorScheme,
            ),
            const SizedBox(width: 16),
            _PrimaryButton(
              label: 'Pause',
              icon: Icons.pause_rounded,
              onPressed: timer.pause,
              colorScheme: colorScheme,
              isFocus: isFocus,
            ),
          ],
        );

      case TimerStatus.paused:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SecondaryButton(
              label: 'Reset',
              icon: Icons.refresh_rounded,
              onPressed: timer.reset,
              colorScheme: colorScheme,
            ),
            const SizedBox(width: 16),
            _PrimaryButton(
              label: 'Resume',
              icon: Icons.play_arrow_rounded,
              onPressed: timer.start,
              colorScheme: colorScheme,
              isFocus: isFocus,
            ),
          ],
        );

      case TimerStatus.completed:
        if (isFocus) {
          // Focus done → offer break or new session
          return Column(
            children: [
              _PrimaryButton(
                label: 'Take a Break',
                icon: Icons.coffee_rounded,
                onPressed: timer.startBreak,
                colorScheme: colorScheme,
                isFocus: false,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: timer.reset,
                icon: const Icon(Icons.skip_next_rounded, size: 20),
                label: const Text('Skip Break'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        } else {
          // Break done → new focus session
          return _PrimaryButton(
            label: 'New Focus Session',
            icon: Icons.psychology_rounded,
            onPressed: () {
              timer.reset(); // Goes back to focus idle
            },
            colorScheme: colorScheme,
            isFocus: true,
          );
        }
    }
  }
}

/// Filled button — primary action.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.colorScheme,
    this.isFocus = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final bool isFocus;

  @override
  Widget build(BuildContext context) {
    final bgColor = isFocus ? colorScheme.primary : colorScheme.tertiary;
    final fgColor = isFocus ? colorScheme.onPrimary : colorScheme.onTertiary;

    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    );
  }
}

/// Outlined button — secondary action.
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.colorScheme,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    );
  }
}
