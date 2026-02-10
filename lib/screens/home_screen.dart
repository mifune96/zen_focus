import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/timer_provider.dart';
import '../services/settings_service.dart';

/// HomeScreen — the single-screen UI for Zen Focus.
///
/// Layout:
///   ┌───────────────────────────────┐
///   │        Daily Focus Stats      │
///   │                               │
///   │     ╭───────────────────╮     │
///   │     │                   │     │
///   │     │  Circular Timer   │     │
///   │     │    MM : SS        │     │
///   │     │                   │     │
///   │     ╰───────────────────╯     │
///   │                               │
///   │    Duration Preset Chips      │
///   │                               │
///   │    [ Start / Pause / Reset ]  │
///   └───────────────────────────────┘
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Consumer<TimerProvider>(
              builder: (context, timer, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ─── Daily Stats Badge ───
                    _DailyStatsChip(
                      settings: settings,
                      textTheme: textTheme,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 48),

                    // ─── Circular Timer ───
                    _CircularTimer(
                      timer: timer,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: 40),

                    // ─── Status Label ───
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _statusLabel(timer.status),
                        key: ValueKey(timer.status),
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── Duration Presets ───
                    if (timer.status == TimerStatus.idle)
                      _DurationPresets(timer: timer, colorScheme: colorScheme),
                    if (timer.status == TimerStatus.idle)
                      const SizedBox(height: 32),

                    // ─── Controls ───
                    _Controls(timer: timer, colorScheme: colorScheme),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(TimerStatus status) {
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

/// Displays today's total focus time as a subtle chip at the top.
class _DailyStatsChip extends StatelessWidget {
  const _DailyStatsChip({
    required this.settings,
    required this.textTheme,
    required this.colorScheme,
  });

  final SettingsService settings;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final totalSeconds = settings.getTotalFocusTodaySeconds();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

    String focusText;
    if (hours > 0) {
      focusText = '${hours}h ${minutes}m focused today';
    } else if (minutes > 0) {
      focusText = '${minutes}m focused today';
    } else {
      focusText = 'Start your first session';
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
          const SizedBox(width: 8),
          Text(
            focusText,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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

    // Determine the ring color based on status.
    Color ringColor;
    switch (timer.status) {
      case TimerStatus.running:
        ringColor = colorScheme.primary;
        break;
      case TimerStatus.paused:
        ringColor = colorScheme.tertiary;
        break;
      case TimerStatus.completed:
        ringColor = colorScheme.secondary;
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: CircularProgressIndicator(
                value: timer.status == TimerStatus.idle ? 0.0 : timer.progress,
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
                color: ringColor,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
          // Inner content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    color: colorScheme.secondary,
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

/// Row of preset duration chips (15, 25, 30, 45, 60 minutes).
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
          onSelected: (_) => timer.setDuration(m),
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

/// Start, Pause, Resume, Reset buttons.
class _Controls extends StatelessWidget {
  const _Controls({required this.timer, required this.colorScheme});

  final TimerProvider timer;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    switch (timer.status) {
      case TimerStatus.idle:
        return _PrimaryButton(
          label: 'Start Focus',
          icon: Icons.play_arrow_rounded,
          onPressed: timer.start,
          colorScheme: colorScheme,
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
            ),
          ],
        );

      case TimerStatus.completed:
        return _PrimaryButton(
          label: 'New Session',
          icon: Icons.replay_rounded,
          onPressed: timer.reset,
          colorScheme: colorScheme,
        );
    }
  }
}

/// Filled button with an icon — used for the primary action.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
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
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label),
      style: FilledButton.styleFrom(
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

/// Outlined button — used for secondary actions (Reset).
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
