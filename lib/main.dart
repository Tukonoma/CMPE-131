import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'home_page.dart';
import 'add_meal_page.dart';
import 'progression_page.dart';
import 'nutrition_models.dart';
import 'app_theme.dart';

void main() => runApp(const NavigationBarApp());

class NavigationExample extends StatefulWidget {
  final AppThemeMode selectedTheme;
  final ValueChanged<AppThemeMode> onThemeChanged;

  const NavigationExample({
    super.key,
    required this.selectedTheme,
    required this.onThemeChanged,
  });

  @override
  State<NavigationExample> createState() => _NavigationExampleState();
}

class NavigationBarApp extends StatefulWidget {
  const NavigationBarApp({super.key});

  @override
  State<NavigationBarApp> createState() => _NavigationBarAppState();
}

class _NavigationBarAppState extends State<NavigationBarApp> {
  AppThemeMode _selectedTheme = AppThemeMode.teal;

  void _changeTheme(AppThemeMode newTheme) {
    setState(() {
      _selectedTheme = newTheme;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppThemes.getTheme(_selectedTheme),
      home: NavigationExample(
        selectedTheme: _selectedTheme,
        onThemeChanged: _changeTheme,
      ),
    );
  }
}

class _NavigationExampleState extends State<NavigationExample> {

  int currentPageIndex = 0;

  final List<Meal> _meals = [];
  DateTime _selectedDay = DateTime.now();

  GoalInfo _goalInfo = const GoalInfo(
    calories: 2000,
    carbsMin: 225,
    carbsMax: 325,
    proteinMin: 50,
    proteinMax: 175,
    fatMin: 44,
    fatMax: 78,
  );

  ProgressMetric _selectedHomeMetric = ProgressMetric.calories;
  ProgressMetric _selectedMetric = ProgressMetric.calories;
  int _progressWindowOffset = 0;

  String _displayName = 'Guest';
  String _displayEmail = 'guest@example.com';
  Uint8List? _avatarBytes;

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    final profile = await ProfileManager.create();

    setState(() {
      _displayName = profile.name.isNotEmpty ? profile.name : 'Guest';
      _displayEmail =
      profile.email.isNotEmpty ? profile.email : 'guest@example.com';
      _avatarBytes = profile.profileImageBytes;
      _goalInfo = buildGoalsFromProfile(profile);
    });
  }

  void _openProfile(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    ).then((_) => _refreshProfile());
  }

  void _addMeal(Meal meal) {
    setState(() => _meals.insert(0, meal));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added: ${meal.name} (${formatNumber(meal.grams)}g)'),
      ),
    );
  }

  void _deleteMeal(Meal meal) => setState(() => _meals.remove(meal));

  void _updateMeal(Meal oldMeal, Meal updatedMeal) {
    setState(() {
      final idx = _meals.indexOf(oldMeal);
      if (idx != -1) _meals[idx] = updatedMeal;
    });
  }

  void _clearMealsForSelectedDay() {
    setState(
          () => _meals.removeWhere((m) => isSameDay(m.addedAt, _selectedDay)),
    );
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked != null) {
      setState(() => _selectedDay = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mealsForDay =
    _meals.where((m) => isSameDay(m.addedAt, _selectedDay)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Tracker'),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              accountName: Text(
                _displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(_displayEmail),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage:
                _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                child: _avatarBytes == null
                    ? const Icon(Icons.person, size: 36, color: Colors.grey)
                    : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_2_outlined),
              title: const Text('Profile'),
              onTap: () => _openProfile(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(
                      selectedTheme: widget.selectedTheme,
                      onThemeChanged: widget.onThemeChanged,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Logout'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log Out?'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Log out'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (index) =>
            setState(() => currentPageIndex = index),
        indicatorColor: Colors.amber,
        selectedIndex: currentPageIndex,
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.add),
            label: 'Add a meal',
          ),
          NavigationDestination(
            icon: Icon(Icons.data_thresholding_outlined),
            label: 'Progression',
          ),
        ],
      ),
      body: <Widget>[
        HomePage(
          mealsForDay: mealsForDay,
          theme: theme,
          selectedDay: _selectedDay,
          goalInfo: _goalInfo,
          selectedMetric: _selectedHomeMetric,
          onMetricChanged: (metric) =>
              setState(() => _selectedHomeMetric = metric),
          onPickDay: _pickDay,
          onDeleteMeal: _deleteMeal,
          onEditMeal: _updateMeal,
          onClearAllForDay: _clearMealsForSelectedDay,
        ),
        AddMealPage(
          onAddMeal: _addMeal,
          selectedDay: _selectedDay,
        ),
        ProgressionPage(
          meals: _meals,
          selectedMetric: _selectedMetric,
          windowOffset: _progressWindowOffset,
          onMetricChanged: (metric) => setState(() => _selectedMetric = metric),
          onPreviousWindow: () => setState(() => _progressWindowOffset++),
          onNextWindow: () {
            if (_progressWindowOffset > 0) {
              setState(() => _progressWindowOffset--);
            }
          },
        ),
      ][currentPageIndex],
    );
  }
}