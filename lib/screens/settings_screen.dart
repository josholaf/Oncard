import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_data.dart';
import '../data/reminder_settings.dart';
import '../services/import_export.dart';
import '../services/reminder_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Small uppercase section label, like a grouped settings list header.
  Widget _header(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
      child: Text(text.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1)),
    );
  }

  Future<void> _confirmRestore(BuildContext context, AppData data) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
            'This replaces every deck, card and study history on this device with the contents of the backup file. Export a backup first if you might need the current data.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Choose file')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await restoreBackupFile(context, data);
    }
  }

  Future<void> _setReminderEnabled(
      BuildContext context, AppData data, bool enabled) async {
    if (!enabled) {
      data.setReminder(data.reminder.copyWith(enabled: false));
      await ReminderService.apply(data);
      return;
    }
    final granted = await ReminderService.requestPermission();
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Notification permission is needed for reminders. Enable it in system settings.')));
      }
      return;
    }
    data.setReminder(data.reminder.copyWith(enabled: true));
    await ReminderService.apply(data);
  }

  Future<void> _pickReminderTime(BuildContext context, AppData data) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: data.reminder.hour, minute: data.reminder.minute),
    );
    if (picked == null) return;
    data.setReminder(
        data.reminder.copyWith(hour: picked.hour, minute: picked.minute));
    await ReminderService.apply(data);
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _header(context, 'Study'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  title: const Text('Daily goal'),
                  subtitle: Text('${data.dailyGoal} cards per day'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Slider(
                    value: data.dailyGoal.toDouble(),
                    min: 5,
                    max: 100,
                    divisions: 19,
                    label: '${data.dailyGoal}',
                    onChanged: (v) => data.setDailyGoal(v.round()),
                  ),
                ),
                ListTile(
                  title: const Text('Text to speech'),
                  subtitle: const Text(
                      'Read card answers aloud during study sessions'),
                  trailing: CupertinoSwitch(
                    value: data.ttsEnabled,
                    onChanged: data.setTtsEnabled,
                  ),
                  onTap: () =>
                      data.setTtsEnabled(!data.ttsEnabled),
                ),
              ],
            ),
          ),

          _header(context, 'Reminders'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  title: const Text('Daily revision reminder'),
                  subtitle: const Text(
                      'Remind me to revise my cards every day'),
                  trailing: CupertinoSwitch(
                    value: data.reminder.enabled,
                    onChanged: (v) => _setReminderEnabled(context, data, v),
                  ),
                  onTap: () => _setReminderEnabled(
                      context, data, !data.reminder.enabled),
                ),
                ListTile(
                  title: const Text('Reminder time'),
                  subtitle: Text(data.reminder.enabled
                      ? 'Every day at ${data.reminder.hour.toString().padLeft(2, '0')}:${data.reminder.minute.toString().padLeft(2, '0')}'
                      : 'Turn the reminder on to pick a time'),
                  onTap: data.reminder.enabled
                      ? () => _pickReminderTime(context, data)
                      : null,
                ),
                ListTile(
                  title: const Text('Send test notification'),
                  subtitle: const Text(
                      'Preview what the reminder looks like'),
                  onTap: data.reminder.enabled
                      ? () => ReminderService.showTest(data)
                      : null,
                ),
              ],
            ),
          ),

          _header(context, 'Backup'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.save_rounded),
                  title: const Text('Export backup'),
                  subtitle: const Text('Save all decks and history as JSON'),
                  onTap: () async {
                    final file = await writeBackupFile(data);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Backup saved to ${file.path}')));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Restore backup'),
                  subtitle:
                      const Text('Replace current data with a backup file'),
                  onTap: () => _confirmRestore(context, data),
                ),
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded, color: cs.error),
                  title: const Text('Reset all data'),
                  subtitle:
                      const Text('Delete everything and restore sample decks'),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Reset all data?'),
                        content: const Text(
                            'Every deck, card and statistic will be replaced with the sample decks. This cannot be undone.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Reset')),
                        ],
                      ),
                    );
                    if (ok == true) data.resetAll();
                  },
                ),
              ],
            ),
          ),

          _header(context, 'About'),
          Card(
            margin: EdgeInsets.zero,
            color: cs.surfaceContainerHighest,
            child: const ListTile(
              title: Text('Oncard'),
              subtitle: Text(
                  'Study smarter, remember longer. Offline-first flashcards with spaced repetition. v1.0.10'),
            ),
          ),
        ],
      ),
    );
  }
}
