import 'package:flutter/material.dart';
import 'app_theme.dart';

class SettingsPage extends StatelessWidget {
  final AppThemeMode selectedTheme;
  final ValueChanged<AppThemeMode> onThemeChanged;

  const SettingsPage({
    super.key,
    required this.selectedTheme,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a color scheme',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButton<AppThemeMode>(
              value: selectedTheme,
              isExpanded: true,
              items: AppThemeMode.values.map((theme) {
                return DropdownMenuItem(
                  value: theme,
                  child: Text(theme.label),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  onThemeChanged(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}