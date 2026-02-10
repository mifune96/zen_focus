import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/timer_provider.dart';
import '../services/settings_service.dart';

/// SettingsScreen — user preferences and app configuration.
///
/// Features:
/// - Theme mode toggle (System / Light / Dark)
/// - Sound on/off toggle
/// - Focus duration customization
/// - Break duration customization
/// - App info
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _themeMode;
  late bool _soundEnabled;
  late int _focusMinutes;
  late int _breakMinutes;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsService>(context, listen: false);
    _themeMode = settings.getThemeMode();
    _soundEnabled = settings.getSoundEnabled();
    _focusMinutes = settings.getTimerDurationMinutes();
    _breakMinutes = settings.getBreakDurationMinutes();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final settings = Provider.of<SettingsService>(context, listen: false);
    final timer = Provider.of<TimerProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ─── Timer Section ───
          _SectionHeader(title: 'Timer', colorScheme: colorScheme),

          _SettingsTile(
            icon: Icons.timer_outlined,
            title: 'Focus Duration',
            subtitle: '$_focusMinutes minutes',
            colorScheme: colorScheme,
            onTap: () => _showDurationPicker(
              context: context,
              title: 'Focus Duration',
              currentValue: _focusMinutes,
              options: [5, 10, 15, 20, 25, 30, 45, 60, 90, 120],
              onSelected: (val) {
                setState(() => _focusMinutes = val);
                settings.setTimerDurationMinutes(val);
                timer.setFocusDuration(val);
              },
            ),
          ),

          _SettingsTile(
            icon: Icons.coffee_outlined,
            title: 'Break Duration',
            subtitle: '$_breakMinutes minutes',
            colorScheme: colorScheme,
            onTap: () => _showDurationPicker(
              context: context,
              title: 'Break Duration',
              currentValue: _breakMinutes,
              options: [3, 5, 10, 15, 20],
              onSelected: (val) {
                setState(() => _breakMinutes = val);
                settings.setBreakDurationMinutes(val);
                timer.setBreakDuration(val);
              },
            ),
          ),

          const Divider(indent: 16, endIndent: 16, height: 1),

          // ─── Appearance Section ───
          _SectionHeader(title: 'Appearance', colorScheme: colorScheme),

          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: _themeModeLabel(_themeMode),
            colorScheme: colorScheme,
            onTap: () => _showThemePicker(context, settings),
          ),

          const Divider(indent: 16, endIndent: 16, height: 1),

          // ─── Sound Section ───
          _SectionHeader(title: 'Sound', colorScheme: colorScheme),

          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _soundEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: colorScheme.primary,
                size: 22,
              ),
            ),
            title: Text(
              'Completion Sound',
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              _soundEnabled ? 'Play chime when timer ends' : 'Sound disabled',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            value: _soundEnabled,
            onChanged: (val) {
              setState(() => _soundEnabled = val);
              settings.setSoundEnabled(val);
            },
          ),

          const Divider(indent: 16, endIndent: 16, height: 1),

          // ─── About Section ───
          _SectionHeader(title: 'About', colorScheme: colorScheme),

          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Zen Focus',
            subtitle: 'Version 1.0.0',
            colorScheme: colorScheme,
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.self_improvement_rounded,
                          color: colorScheme.primary,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Zen Focus',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version 1.0.0',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'A minimalist Pomodoro-style focus timer.\n\n'
                        '🧘 Focus better. Achieve more.\n\n'
                        'Offline-first. No ads. No tracking.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '© 2026 Ali Imran',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _themeModeLabel(String mode) {
    switch (mode) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      default:
        return 'System default';
    }
  }

  void _showThemePicker(BuildContext context, SettingsService settings) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Choose Theme',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...['system', 'light', 'dark'].map((mode) {
              final isSelected = _themeMode == mode;
              return ListTile(
                leading: Icon(
                  mode == 'system'
                      ? Icons.brightness_auto_rounded
                      : mode == 'light'
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                title: Text(_themeModeLabel(mode)),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: colorScheme.primary,
                      )
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                selected: isSelected,
                selectedTileColor: colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                onTap: () {
                  setState(() => _themeMode = mode);
                  settings.setThemeMode(mode);
                  Navigator.pop(ctx);
                  // Show a snackbar informing restart needed for theme change.
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Restart the app to apply theme changes.',
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDurationPicker({
    required BuildContext context,
    required String title,
    required int currentValue,
    required List<int> options,
    required ValueChanged<int> onSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((val) {
                final isSelected = val == currentValue;
                return ChoiceChip(
                  label: Text('$val min'),
                  selected: isSelected,
                  onSelected: (_) {
                    onSelected(val);
                    Navigator.pop(ctx);
                  },
                  selectedColor: colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Private Sub-Widgets
// ══════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.colorScheme});
  final String title;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colorScheme,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: colorScheme.primary, size: 22),
      ),
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      onTap: onTap,
    );
  }
}
