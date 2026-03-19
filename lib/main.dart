import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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

/// Meal entry
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

  double? get kcal => _actualFrom100g(kcal100g);
  double? get protein => _actualFrom100g(protein100g);
  double? get carbs => _actualFrom100g(carbs100g);
  double? get fat => _actualFrom100g(fat100g);
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatNumber(double value, {int decimals = 1}) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(decimals);
}

class NavigationExample extends StatefulWidget {
  const NavigationExample({super.key});

  @override
  State<NavigationExample> createState() => _NavigationExampleState();
}

class _NavigationExampleState extends State<NavigationExample> {
  int currentPageIndex = 0;

  final List<Meal> _meals = [];
  DateTime _selectedDay = DateTime.now();

  final double _calorieGoal = 2000;

  void _addMeal(Meal meal) {
    setState(() => _meals.insert(0, meal));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added: ${meal.name} (${_formatNumber(meal.grams)}g)'),
      ),
    );
  }

  void _deleteMeal(Meal meal) {
    setState(() => _meals.remove(meal));
  }

  void _updateMeal(Meal oldMeal, Meal updatedMeal) {
    setState(() {
      final idx = _meals.indexOf(oldMeal);
      if (idx != -1) _meals[idx] = updatedMeal;
    });
  }

  void _clearMealsForSelectedDay() {
    setState(() {
      _meals.removeWhere((m) => _isSameDay(m.addedAt, _selectedDay));
    });
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
    final ThemeData theme = Theme.of(context);

    final mealsForDay =
    _meals.where((m) => _isSameDay(m.addedAt, _selectedDay)).toList();

    return Scaffold(
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() => currentPageIndex = index);
        },
        indicatorColor: Colors.amber,
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(child: Icon(Icons.add)),
            label: 'Add a meal',
          ),
          NavigationDestination(
            icon: Icon(Icons.data_thresholding_outlined),
            label: 'Progression',
          ),
        ],
      ),
      appBar: AppBar(
        title: const Text('Nutrient and Calorie Tracker'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
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
        AddMealPage(onAddMeal: _addMeal),
        const Center(
          child: Text(
            'Progression page placeholder',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ][currentPageIndex],
    );
  }
}

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
    double total = 0;
    for (final m in mealsForDay) {
      final v = pick(m);
      if (v != null) total += v;
    }
    return total;
  }

  String _getFormattedDate() {
    return DateFormat('EEEE, MMMM d').format(selectedDay);
  }

  Future<void> _showEditDialog(BuildContext context, Meal meal) async {
    final nameCtrl = TextEditingController(text: meal.name);
    final gramsCtrl = TextEditingController(text: _formatNumber(meal.grams));
    final kcalCtrl =
    TextEditingController(text: meal.kcal100g?.toString() ?? '');
    final proteinCtrl =
    TextEditingController(text: meal.protein100g?.toString() ?? '');
    final carbsCtrl =
    TextEditingController(text: meal.carbs100g?.toString() ?? '');
    final fatCtrl =
    TextEditingController(text: meal.fat100g?.toString() ?? '');

    double? parseOrNull(String s) {
      final t = s.trim();
      if (t.isEmpty) return null;
      return double.tryParse(t);
    }

    final updated = await showDialog<Meal>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: gramsCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Grams eaten',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: kcalCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Calories (kcal per 100g)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: proteinCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Protein (g per 100g)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: carbsCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Carbs (g per 100g)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fatCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Fat (g per 100g)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              final grams = double.tryParse(gramsCtrl.text.trim());

              if (newName.isEmpty || grams == null || grams <= 0) return;

              Navigator.pop(
                ctx,
                meal.copyWith(
                  name: newName,
                  grams: grams,
                  kcal100g: parseOrNull(kcalCtrl.text),
                  protein100g: parseOrNull(proteinCtrl.text),
                  carbs100g: parseOrNull(carbsCtrl.text),
                  fat100g: parseOrNull(fatCtrl.text),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != null) {
      onEditMeal(meal, updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalKcal = _sum((m) => m.kcal);
    final totalProtein = _sum((m) => m.protein);
    final totalCarbs = _sum((m) => m.carbs);
    final totalFat = _sum((m) => m.fat);

    final double progress = (totalKcal / calorieGoal).clamp(0.0, 1.0);
    final double remaining = calorieGoal - totalKcal;

    return Column(
      children: [
        Card(
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
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.calendar_month_outlined),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Today\'s Calories',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 16,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.teal,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatNumber(totalKcal, decimals: 0),
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'calories consumed',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Goal: ${_formatNumber(calorieGoal, decimals: 0)}',
                          style: const TextStyle(fontSize: 14),
                        ),
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
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    StatChip(
                      label: 'Calories',
                      value: totalKcal,
                      unit: 'kcal',
                    ),
                    StatChip(
                      label: 'Protein',
                      value: totalProtein,
                      unit: 'g',
                    ),
                    StatChip(
                      label: 'Carbs',
                      value: totalCarbs,
                      unit: 'g',
                    ),
                    StatChip(
                      label: 'Fat',
                      value: totalFat,
                      unit: 'g',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('${mealsForDay.length} item(s)'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: mealsForDay.isEmpty
                          ? null
                          : () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Clear this day?'),
                            content: Text(
                              'This will delete all entries for ${DateFormat('EEEE, MMMM d').format(selectedDay)}.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, true),
                                child: const Text('Delete all'),
                              ),
                            ],
                          ),
                        ) ??
                            false;

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
        Expanded(
          child: mealsForDay.isEmpty
              ? Center(
            child: Text(
              'No meals for this date.\nAdd meals in "Add a meal".',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: mealsForDay.length,
            itemBuilder: (context, i) {
              final m = mealsForDay[i];

              return Dismissible(
                key: ValueKey('${m.name}-${m.addedAt.toIso8601String()}-$i'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: Colors.red.shade100,
                  child: const Icon(Icons.delete),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete entry?'),
                      content: Text("Delete '${m.name}'?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ) ??
                      false;
                },
                onDismissed: (_) => onDeleteMeal(m),
                child: Card(
                  child: ListTile(
                    onTap: () => _showEditDialog(context, m),
                    title: Text(m.name),
                    subtitle: Text([
                      if (m.brand != null && m.brand!.trim().isNotEmpty)
                        'Brand: ${m.brand}',
                      'Grams: ${_formatNumber(m.grams)}g',
                      if (m.kcal != null)
                        'Calories: ${_formatNumber(m.kcal!, decimals: 0)}',
                      if (m.protein != null)
                        'P: ${m.protein!.toStringAsFixed(1)}g',
                      if (m.carbs != null)
                        'C: ${m.carbs!.toStringAsFixed(1)}g',
                      if (m.fat != null)
                        'F: ${m.fat!.toStringAsFixed(1)}g',
                      'Tap to edit',
                    ].join(' • ')),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => onDeleteMeal(m),
                      tooltip: 'Delete',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class StatChip extends StatelessWidget {
  final String label;
  final double value;
  final String unit;

  const StatChip({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: ${value.toStringAsFixed(1)} $unit'),
    );
  }
}

// ---------------------------------------------------------------------------
// Add Meal Page — powered by USDA FoodData Central API
// ---------------------------------------------------------------------------

class AddMealPage extends StatefulWidget {
  final void Function(Meal) onAddMeal;

  const AddMealPage({super.key, required this.onAddMeal});

  @override
  State<AddMealPage> createState() => _AddMealPageState();
}

class _AddMealPageState extends State<AddMealPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  List<_UsdaFood> _results = const [];

  static const _apiKey = 'ZrNhpjOTyWKFMWxLIp4f0mCz0gAqG0bPBRjRq24Z';

  static final List<int> _gramOptions =
  List<int>.generate(200, (index) => (index + 1) * 10);

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _results = const [];
    });

    try {
      final uri =
      Uri.parse('https://api.nal.usda.gov/fdc/v1/foods/search').replace(
        queryParameters: <String, String>{
          'query': q,
          'api_key': _apiKey,
          'pageSize': '20',
        },
      );

      final resp = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final foods = (decoded['foods'] as List?) ?? const [];

      final parsed = foods
          .map((f) => _UsdaFood.fromJson(f as Map<String, dynamic>))
          .where((f) => f.description.trim().isNotEmpty)
          .toList();

      setState(() => _results = parsed);
    } catch (e) {
      setState(() => _error = 'Search failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addFromResult(_UsdaFood f) async {
    final grams = await _showGramPicker(context, food: f);
    if (grams == null) return;

    final meal = Meal(
      name: f.description,
      brand: f.brandOwner,
      barcode: f.gtinUpc,
      grams: grams,
      kcal100g: f.kcal100g,
      protein100g: f.protein100g,
      carbs100g: f.carbs100g,
      fat100g: f.fat100g,
      addedAt: DateTime.now(),
    );

    widget.onAddMeal(meal);
  }

  Future<double?> _showGramPicker(
      BuildContext context, {
        required _UsdaFood food,
      }) async {
    int selectedIndex = 9;
    final manualCtrl = TextEditingController(text: '100');

    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  food.description,
                  style: Theme.of(sheetCtx).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose grams',
                  style: Theme.of(sheetCtx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                      initialItem: selectedIndex,
                    ),
                    itemExtent: 36,
                    useMagnifier: true,
                    magnification: 1.05,
                    onSelectedItemChanged: (index) {
                      selectedIndex = index;
                      manualCtrl.text = _gramOptions[index].toString();
                    },
                    children: _gramOptions
                        .map((g) => Center(child: Text('$g g')))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: manualCtrl,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Or type grams',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final grams =
                          double.tryParse(manualCtrl.text.trim());
                          if (grams == null || grams <= 0) return;
                          Navigator.pop(sheetCtx, grams);
                        },
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Search food (e.g., "oreo", "greek yogurt")',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _loading ? null : _search,
                child: _loading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (!_loading && _error == null && _results.isEmpty)
            const Text('Search for something to see results.'),
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
                      if (f.brandOwner != null && f.brandOwner!.trim().isNotEmpty)
                        'Brand: ${f.brandOwner}',
                      if (f.kcal100g != null)
                        'kcal/100g: ${f.kcal100g!.toStringAsFixed(0)}',
                      if (f.protein100g != null)
                        'P/100g: ${f.protein100g!.toStringAsFixed(1)}g',
                      if (f.carbs100g != null)
                        'C/100g: ${f.carbs100g!.toStringAsFixed(1)}g',
                      if (f.fat100g != null)
                        'F/100g: ${f.fat100g!.toStringAsFixed(1)}g',
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
    );
  }
}

// ---------------------------------------------------------------------------
// USDA FoodData Central data model
// ---------------------------------------------------------------------------

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

      final nutrientName =
      (n['nutrientName'] ?? n['name'])?.toString().toLowerCase();

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
      fdcId: json['fdcId'] as int? ?? 0,
      description: json['description']?.toString() ?? '',
      brandOwner: json['brandOwner']?.toString(),
      gtinUpc: json['gtinUpc']?.toString(),
      kcal100g: _nutrientByName(
        nutrients,
        ['energy', 'energy (kcal)'],
      ),
      protein100g: _nutrientByName(
        nutrients,
        ['protein'],
      ),
      carbs100g: _nutrientByName(
        nutrients,
        ['carbohydrate, by difference', 'carbohydrate'],
      ),
      fat100g: _nutrientByName(
        nutrients,
        ['total lipid (fat)', 'total fat'],
      ),
    );
  }
}