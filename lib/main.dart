import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'profile_page.dart';
import 'settings_page.dart';

void main() => runApp(const NavigationBarApp());

class NavigationBarApp extends StatelessWidget {
  const NavigationBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: NavigationExample(),
    );
  }
}

/// Meal entry.
/// USDA nutrition is stored per 100g, and actual totals are calculated using grams.
class Meal {
  final String name;
  final String? brand;
  final String? barcode;
  final double grams;
  final double? kcal100g;
  final double? protein100g;
  final double? carbs100g;
  final double? fat100g;
  final DateTime addedAt;

  const Meal({
    required this.name,
    required this.addedAt,
    required this.grams,
    this.brand,
    this.barcode,
    this.kcal100g,
    this.protein100g,
    this.carbs100g,
    this.fat100g,
  });

  Meal copyWith({
    String? name,
    String? brand,
    String? barcode,
    double? grams,
    double? kcal100g,
    double? protein100g,
    double? carbs100g,
    double? fat100g,
    DateTime? addedAt,
  }) {
    return Meal(
      name: name ?? this.name,
      brand: brand ?? this.brand,
      barcode: barcode ?? this.barcode,
      grams: grams ?? this.grams,
      kcal100g: kcal100g ?? this.kcal100g,
      protein100g: protein100g ?? this.protein100g,
      carbs100g: carbs100g ?? this.carbs100g,
      fat100g: fat100g ?? this.fat100g,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  double? _actualFrom100g(double? per100g) {
    if (per100g == null) return null;
    return (per100g * grams) / 100.0;
  }

  double? get kcal    => _actualFrom100g(kcal100g);
  double? get protein => _actualFrom100g(protein100g);
  double? get carbs   => _actualFrom100g(carbs100g);
  double? get fat     => _actualFrom100g(fat100g);
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _startOfWeek(DateTime d) {
  final date = _dateOnly(d);
  return date.subtract(Duration(days: date.weekday - 1));
}

String _formatNumber(double value, {int decimals = 1}) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(decimals);
}

enum ProgressMetric { calories, protein, carbs, fat }

extension ProgressMetricX on ProgressMetric {
  String get label => switch (this) {
    ProgressMetric.calories => 'Calories',
    ProgressMetric.protein  => 'Protein',
    ProgressMetric.carbs    => 'Carbs',
    ProgressMetric.fat      => 'Fat',
  };

  String get unit => switch (this) {
    ProgressMetric.calories => 'kcal',
    _                       => 'g',
  };

  double valueFromMeal(Meal meal) => switch (this) {
    ProgressMetric.calories => meal.kcal    ?? 0.0,
    ProgressMetric.protein  => meal.protein ?? 0.0,
    ProgressMetric.carbs    => meal.carbs   ?? 0.0,
    ProgressMetric.fat      => meal.fat     ?? 0.0,
  };
}

// ─────────────────────────────────────────────
// Root navigation widget
// ─────────────────────────────────────────────

class NavigationExample extends StatefulWidget {
  const NavigationExample({super.key});

  @override
  State<NavigationExample> createState() => _NavigationExampleState();
}

class _NavigationExampleState extends State<NavigationExample> {
  int currentPageIndex = 0;

  final List<Meal> _meals = [];
  DateTime _selectedDay = DateTime.now();
  final double _calorieGoal = 2000.0;

  ProgressMetric _selectedMetric    = ProgressMetric.calories;
  int            _progressWindowOffset = 0;

  // Drawer header state — loaded from ProfileManager
  String     _displayName  = 'Guest';
  String     _displayEmail = 'guest@example.com';
  Uint8List? _avatarBytes;

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  // Pulls the latest saved profile and refreshes the drawer header.
  // Called on startup and whenever we return from ProfilePage.
  Future<void> _refreshProfile() async {
    final profile = await ProfileManager.get();
    setState(() {
      _displayName  = profile.name.isNotEmpty  ? profile.name  : 'Guest';
      _displayEmail = profile.email.isNotEmpty ? profile.email : 'guest@example.com';
      _avatarBytes  = profile.profileImageBytes;
    });
  }

  void _openProfile(BuildContext context) {
    Navigator.pop(context); // close drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    ).then((_) => _refreshProfile()); // refresh header when user comes back
  }

  // ── Meal helpers ──────────────────────────

  void _addMeal(Meal meal) {
    setState(() => _meals.insert(0, meal));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added: ${meal.name} (${_formatNumber(meal.grams)}g)')),
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
    setState(() => _meals.removeWhere((m) => _isSameDay(m.addedAt, _selectedDay)));
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked != null) setState(() => _selectedDay = picked);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final mealsForDay =
    _meals.where((m) => _isSameDay(m.addedAt, _selectedDay)).toList();

    return Scaffold(

      // ── App bar ──────────────────────────
      appBar: AppBar(
        title: const Text('Nutrition Tracker'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      // ── Drawer ───────────────────────────
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [

            // Header shows live profile data
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.teal),
              accountName: Text(
                _displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(_displayEmail),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: _avatarBytes != null
                    ? MemoryImage(_avatarBytes!)
                    : null,
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
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
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
                          // TODO: perform actual logout / navigation
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

      // ── Bottom nav ────────────────────────
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) =>
            setState(() => currentPageIndex = index),
        indicatorColor: Colors.amber,
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
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

      // ── Pages ─────────────────────────────
      body: <Widget>[
        HomePage(
          mealsForDay: mealsForDay,
          theme: theme,
          selectedDay: _selectedDay,
          calorieGoal: _calorieGoal,
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

// ─────────────────────────────────────────────
// Home page
// ─────────────────────────────────────────────

class HomePage extends StatelessWidget {
  final List<Meal> mealsForDay;
  final ThemeData theme;
  final DateTime selectedDay;
  final double calorieGoal;
  final VoidCallback onPickDay;
  final void Function(Meal meal) onDeleteMeal;
  final void Function(Meal oldMeal, Meal updatedMeal) onEditMeal;
  final VoidCallback onClearAllForDay;

  const HomePage({
    super.key,
    required this.mealsForDay,
    required this.theme,
    required this.selectedDay,
    required this.calorieGoal,
    required this.onPickDay,
    required this.onDeleteMeal,
    required this.onEditMeal,
    required this.onClearAllForDay,
  });

  double _sum(double? Function(Meal m) pick) {
    double total = 0.0;
    for (final m in mealsForDay) {
      final v = pick(m);
      if (v != null) total += v;
    }
    return total;
  }

  String _getFormattedDate() => DateFormat('EEEE, MMMM d').format(selectedDay);

  Future<void> _showEditDialog(BuildContext context, Meal meal) async {
    final nameCtrl    = TextEditingController(text: meal.name);
    final gramsCtrl   = TextEditingController(text: _formatNumber(meal.grams));
    final kcalCtrl    = TextEditingController(text: meal.kcal100g?.toString()    ?? '');
    final proteinCtrl = TextEditingController(text: meal.protein100g?.toString() ?? '');
    final carbsCtrl   = TextEditingController(text: meal.carbs100g?.toString()   ?? '');
    final fatCtrl     = TextEditingController(text: meal.fat100g?.toString()     ?? '');

    double? parseOrNull(String s) {
      final t = s.trim();
      return t.isEmpty ? null : double.tryParse(t);
    }

    final updated = await showDialog<Meal>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: gramsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Grams eaten', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: kcalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Calories (kcal per 100g)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: proteinCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Protein (g per 100g)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: carbsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Carbs (g per 100g)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: fatCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Fat (g per 100g)', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              final grams   = double.tryParse(gramsCtrl.text.trim());
              if (newName.isEmpty || grams == null || grams <= 0) return;
              Navigator.pop(ctx, meal.copyWith(
                name:        newName,
                grams:       grams,
                kcal100g:    parseOrNull(kcalCtrl.text),
                protein100g: parseOrNull(proteinCtrl.text),
                carbs100g:   parseOrNull(carbsCtrl.text),
                fat100g:     parseOrNull(fatCtrl.text),
              ));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != null) onEditMeal(meal, updated);
  }

  @override
  Widget build(BuildContext context) {
    final totalKcal    = _sum((m) => m.kcal);
    final totalProtein = _sum((m) => m.protein);
    final totalCarbs   = _sum((m) => m.carbs);
    final totalFat     = _sum((m) => m.fat);

    final double progress  = (totalKcal / calorieGoal).clamp(0.0, 1.0);
    final double remaining = calorieGoal - totalKcal;

    return LayoutBuilder(
      builder: (context, constraints) {
        final ringSize = math.min(constraints.maxWidth * 0.55, 220.0);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Card(
                shadowColor: Colors.transparent,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: onPickDay,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  _getFormattedDate(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.calendar_month_outlined),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Today\'s Calories',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: ringSize, height: ringSize,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 16,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatNumber(totalKcal, decimals: 0),
                                style: TextStyle(fontSize: ringSize * 0.19, fontWeight: FontWeight.bold),
                              ),
                              const Text('calories consumed', style: TextStyle(fontSize: 16)),
                              const SizedBox(height: 8),
                              Text('Goal: ${_formatNumber(calorieGoal, decimals: 0)}',
                                  style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        remaining >= 0
                            ? '${_formatNumber(remaining, decimals: 0)} calories remaining'
                            : '${_formatNumber(remaining.abs(), decimals: 0)} calories over goal',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12, runSpacing: 8,
                        children: [
                          StatChip(label: 'Calories', value: totalKcal,    unit: 'kcal'),
                          StatChip(label: 'Protein',  value: totalProtein, unit: 'g'),
                          StatChip(label: 'Carbs',    value: totalCarbs,   unit: 'g'),
                          StatChip(label: 'Fat',      value: totalFat,     unit: 'g'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: Text('${mealsForDay.length} item(s)')),
                          TextButton.icon(
                            onPressed: mealsForDay.isEmpty ? null : () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Clear this day?'),
                                  content: Text(
                                    'This will delete all entries for ${DateFormat('EEEE, MMMM d').format(selectedDay)}.',
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete all')),
                                  ],
                                ),
                              ) ?? false;
                              if (ok) onClearAllForDay();
                            },
                            icon: const Icon(Icons.delete_forever_outlined),
                            label: const Text('Clear day'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (mealsForDay.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No meals for this date.\nAdd meals in "Add a meal".',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, i) {
                    final m = mealsForDay[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Dismissible(
                        key: ValueKey('${m.name}-${m.addedAt.toIso8601String()}-$i'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: Colors.red.shade100,
                          child: const Icon(Icons.delete),
                        ),
                        confirmDismiss: (_) async => await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete entry?'),
                            content: Text("Delete '${m.name}'?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                            ],
                          ),
                        ) ?? false,
                        onDismissed: (_) => onDeleteMeal(m),
                        child: Card(
                          child: ListTile(
                            onTap: () => _showEditDialog(context, m),
                            title: Text(m.name),
                            subtitle: Text([
                              if (m.brand != null && m.brand!.trim().isNotEmpty) 'Brand: ${m.brand}',
                              'Grams: ${_formatNumber(m.grams)}g',
                              if (m.kcal    != null) 'Calories: ${_formatNumber(m.kcal!, decimals: 0)}',
                              if (m.protein != null) 'P: ${m.protein!.toStringAsFixed(1)}g',
                              if (m.carbs   != null) 'C: ${m.carbs!.toStringAsFixed(1)}g',
                              if (m.fat     != null) 'F: ${m.fat!.toStringAsFixed(1)}g',
                              'Tap to edit',
                            ].join(' • ')),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => onDeleteMeal(m),
                              tooltip: 'Delete',
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: mealsForDay.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Stat chip
// ─────────────────────────────────────────────

class StatChip extends StatelessWidget {
  final String label;
  final double value;
  final String unit;

  const StatChip({super.key, required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: ${value.toStringAsFixed(1)} $unit'));
  }
}

// ─────────────────────────────────────────────
// Progression page
// ─────────────────────────────────────────────

class ProgressionPage extends StatelessWidget {
  final List<Meal> meals;
  final ProgressMetric selectedMetric;
  final int windowOffset;
  final ValueChanged<ProgressMetric> onMetricChanged;
  final VoidCallback onPreviousWindow;
  final VoidCallback onNextWindow;

  const ProgressionPage({
    super.key,
    required this.meals,
    required this.selectedMetric,
    required this.windowOffset,
    required this.onMetricChanged,
    required this.onPreviousWindow,
    required this.onNextWindow,
  });

  List<_WeeklyAverageData> _buildWeeklyAverages() {
    final now              = DateTime.now();
    final currentWeekStart = _startOfWeek(now);
    final windowStart      = currentWeekStart.subtract(Duration(days: windowOffset * 35 + 28));

    return List.generate(5, (i) {
      final start = windowStart.add(Duration(days: i * 7));
      final end   = start.add(const Duration(days: 6));

      final Map<DateTime, double> totalsByDay = {};

      for (final meal in meals) {
        final day = _dateOnly(meal.addedAt);
        if (day.isBefore(start) || day.isAfter(end)) continue;
        totalsByDay[day] = (totalsByDay[day] ?? 0.0) + selectedMetric.valueFromMeal(meal);
      }

      double weekTotal = 0.0;
      for (int d = 0; d < 7; d++) {
        final day = start.add(Duration(days: d));
        weekTotal += totalsByDay[_dateOnly(day)] ?? 0.0;
      }

      return _WeeklyAverageData(weekStart: start, weekEnd: end, average: weekTotal / 7.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data       = _buildWeeklyAverages();
    final double maxY     = data.fold(0.0, (max, e) => math.max(max, e.average));
    final double chartMaxY = maxY <= 0.0 ? 10.0 : maxY * 1.25;

    final newestWeekStart = _startOfWeek(DateTime.now()).subtract(Duration(days: windowOffset * 35));
    final oldestWeekStart = newestWeekStart.subtract(const Duration(days: 28));
    final rangeText = '${DateFormat('MMM d').format(oldestWeekStart)} - ${DateFormat('MMM d, y').format(newestWeekStart.add(const Duration(days: 6)))}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 12, runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                DropdownButton<ProgressMetric>(
                  value: selectedMetric,
                  onChanged: (value) { if (value != null) onMetricChanged(value); },
                  items: ProgressMetric.values
                      .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                      .toList(),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(onPressed: onPreviousWindow, icon: const Icon(Icons.chevron_left), tooltip: 'Previous 5 weeks'),
                    Text(rangeText, style: const TextStyle(fontWeight: FontWeight.w600)),
                    IconButton(onPressed: windowOffset == 0 ? null : onNextWindow, icon: const Icon(Icons.chevron_right), tooltip: 'Next 5 weeks'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                  child: data.every((e) => e.average == 0.0)
                      ? Center(child: Text('No data for this 5-week window.',
                      style: Theme.of(context).textTheme.titleMedium))
                      : BarChart(
                    BarChartData(
                      maxY: chartMaxY,
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: chartMaxY / 5.0),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, reservedSize: 50, interval: chartMaxY / 5.0,
                            getTitlesWidget: (value, meta) => Text(_formatNumber(value, decimals: 0), style: const TextStyle(fontSize: 11)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, reservedSize: 48,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= data.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(DateFormat('MMM d').format(data[index].weekStart), style: const TextStyle(fontSize: 11)),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final item = data[group.x.toInt()];
                            return BarTooltipItem(
                              '${DateFormat('MMM d').format(item.weekStart)} - ${DateFormat('MMM d').format(item.weekEnd)}\nAvg: ${_formatNumber(item.average)} ${selectedMetric.unit}',
                              const TextStyle(color: Colors.white),
                            );
                          },
                        ),
                      ),
                      barGroups: List.generate(data.length, (index) => BarChartGroupData(
                        x: index,
                        barRods: [BarChartRodData(
                          toY: data[index].average,
                          width: 26.0,
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.teal,
                        )],
                      )),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Showing weekly average daily ${selectedMetric.label.toLowerCase()} for 5-week windows',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: ListView(
                children: data.map((item) => ListTile(
                  dense: true,
                  title: Text('${DateFormat('MMM d').format(item.weekStart)} - ${DateFormat('MMM d, y').format(item.weekEnd)}'),
                  trailing: Text('${_formatNumber(item.average)} ${selectedMetric.unit}/day',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyAverageData {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double   average;

  const _WeeklyAverageData({
    required this.weekStart,
    required this.weekEnd,
    required this.average,
  });
}

// ─────────────────────────────────────────────
// Add Meal page — powered by USDA FoodData Central API
// ─────────────────────────────────────────────

class AddMealPage extends StatefulWidget {
  final void Function(Meal) onAddMeal;
  final DateTime selectedDay;

  const AddMealPage({super.key, required this.onAddMeal, required this.selectedDay});

  @override
  State<AddMealPage> createState() => _AddMealPageState();
}

class _AddMealPageState extends State<AddMealPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  List<_UsdaFood> _results = const [];

  static const _apiKey    = 'ZrNhpjOTyWKFMWxLIp4f0mCz0gAqG0bPBRjRq24Z';
  static final List<int> _gramOptions = List<int>.generate(200, (i) => (i + 1) * 10);

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() => _error = 'Please enter a search term.');
      return;
    }

    setState(() { _loading = true; _error = null; _results = const []; });

    try {
      final uri = Uri.https('api.nal.usda.gov', '/fdc/v1/foods/search', {'api_key': _apiKey});
      final resp = await http.post(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, Object>{
          'generalSearchInput': q,
          'pageSize': 20,
        }),
      );
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}: ${resp.body}');

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final foods = (decoded['foods'] as List?) ?? const [];

      setState(() => _results = foods
          .map((f) => _UsdaFood.fromJson(f as Map<String, dynamic>))
          .where((f) => f.description.trim().isNotEmpty)
          .toList());
    } catch (e) {
      setState(() => _error = 'Search failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addFromResult(_UsdaFood f) async {
    final grams = await _showGramPicker(context, food: f);
    if (grams == null) return;

    final now = DateTime.now();
    widget.onAddMeal(Meal(
      name:        f.description,
      brand:       f.brandOwner,
      barcode:     f.gtinUpc,
      grams:       grams,
      kcal100g:    f.kcal100g,
      protein100g: f.protein100g,
      carbs100g:   f.carbs100g,
      fat100g:     f.fat100g,
      addedAt: DateTime(
        widget.selectedDay.year, widget.selectedDay.month, widget.selectedDay.day,
        now.hour, now.minute, now.second, now.millisecond, now.microsecond,
      ),
    ));
  }

  Future<double?> _showGramPicker(BuildContext context, {required _UsdaFood food}) async {
    int selectedIndex = 9;
    final manualCtrl = TextEditingController(text: '100');

    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(food.description,
                  style: Theme.of(sheetCtx).textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('Choose grams', style: Theme.of(sheetCtx).textTheme.bodyMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(initialItem: selectedIndex),
                  itemExtent: 36, useMagnifier: true, magnification: 1.05,
                  onSelectedItemChanged: (index) {
                    selectedIndex = index;
                    manualCtrl.text = _gramOptions[index].toString();
                  },
                  children: _gramOptions.map((g) => Center(child: Text('$g g'))).toList(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: manualCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Or type grams', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(sheetCtx), child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: () {
                      final grams = double.tryParse(manualCtrl.text.trim());
                      if (grams == null || grams <= 0) return;
                      Navigator.pop(sheetCtx, grams);
                    },
                    child: const Text('Add'),
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: 'Search food for ${DateFormat('MMM d').format(widget.selectedDay)}',
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _loading ? null : _search,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (!_loading && _error == null && _results.isEmpty)
              Text(
                'Search for something to see results.\nSelected day: ${DateFormat('EEEE, MMMM d').format(widget.selectedDay)}',
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final f = _results[i];
                  return Card(
                    child: ListTile(
                      title: Text(f.description),
                      subtitle: Text([
                        if (f.brandOwner != null && f.brandOwner!.trim().isNotEmpty) 'Brand: ${f.brandOwner}',
                        if (f.kcal100g    != null) 'kcal/100g: ${f.kcal100g!.toStringAsFixed(0)}',
                        if (f.protein100g != null) 'P/100g: ${f.protein100g!.toStringAsFixed(1)}g',
                        if (f.carbs100g   != null) 'C/100g: ${f.carbs100g!.toStringAsFixed(1)}g',
                        if (f.fat100g     != null) 'F/100g: ${f.fat100g!.toStringAsFixed(1)}g',
                      ].join(' • ')),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _addFromResult(f),
                        tooltip: 'Add meal',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// USDA FoodData Central data model
// ─────────────────────────────────────────────

class _UsdaFood {
  final int fdcId;
  final String description;
  final String? brandOwner;
  final String? gtinUpc;
  final double? kcal100g;
  final double? protein100g;
  final double? carbs100g;
  final double? fat100g;

  const _UsdaFood({
    required this.fdcId,
    required this.description,
    this.brandOwner,
    this.gtinUpc,
    this.kcal100g,
    this.protein100g,
    this.carbs100g,
    this.fat100g,
  });

  static double? _readValue(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  static double? _nutrientByName(List<dynamic> nutrients, List<String> names) {
    final lowerNames = names.map((e) => e.toLowerCase()).toList();
    for (final n in nutrients) {
      if (n is! Map) continue;
      final nutrientName = (n['nutrientName'] ?? n['name'])?.toString().toLowerCase();
      if (nutrientName != null && lowerNames.contains(nutrientName)) {
        final value = _readValue(n['value']);
        if (value != null) return value;
      }
    }
    return null;
  }

  factory _UsdaFood.fromJson(Map<String, dynamic> json) {
    final nutrients = (json['foodNutrients'] as List?) ?? const [];
    return _UsdaFood(
      fdcId:       json['fdcId'] as int? ?? 0,
      description: json['description']?.toString() ?? '',
      brandOwner:  json['brandOwner']?.toString(),
      gtinUpc:     json['gtinUpc']?.toString(),
      kcal100g:    _nutrientByName(nutrients, ['energy', 'energy (kcal)']),
      protein100g: _nutrientByName(nutrients, ['protein']),
      carbs100g:   _nutrientByName(nutrients, ['carbohydrate, by difference', 'carbohydrate']),
      fat100g:     _nutrientByName(nutrients, ['total lipid (fat)', 'total fat']),
    );
  }
}
