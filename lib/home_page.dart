import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'nutrition_models.dart';

class HomePage extends StatelessWidget {
  final List<Meal> mealsForDay;
  final ThemeData theme;
  final DateTime selectedDay;
  final GoalInfo goalInfo;
  final ProgressMetric selectedMetric;
  final ValueChanged<ProgressMetric> onMetricChanged;
  final VoidCallback onPickDay;
  final void Function(Meal meal) onDeleteMeal;
  final void Function(Meal oldMeal, Meal updatedMeal) onEditMeal;
  final VoidCallback onClearAllForDay;

  const HomePage({
    super.key,
    required this.mealsForDay,
    required this.theme,
    required this.selectedDay,
    required this.goalInfo,
    required this.selectedMetric,
    required this.onMetricChanged,
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
    final nameCtrl = TextEditingController(text: meal.name);
    final gramsCtrl = TextEditingController(text: formatNumber(meal.grams));
    final kcalCtrl = TextEditingController(text: meal.kcal100g?.toString() ?? '');
    final proteinCtrl =
    TextEditingController(text: meal.protein100g?.toString() ?? '');
    final carbsCtrl =
    TextEditingController(text: meal.carbs100g?.toString() ?? '');
    final fatCtrl = TextEditingController(text: meal.fat100g?.toString() ?? '');

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

    if (updated != null) onEditMeal(meal, updated);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final totalKcal = _sum((m) => m.kcal);
    final totalProtein = _sum((m) => m.protein);
    final totalCarbs = _sum((m) => m.carbs);
    final totalFat = _sum((m) => m.fat);

    final metricTotals = <ProgressMetric, double>{
      ProgressMetric.calories: totalKcal,
      ProgressMetric.protein: totalProtein,
      ProgressMetric.carbs: totalCarbs,
      ProgressMetric.fat: totalFat,
    };

    final currentValue = metricTotals[selectedMetric] ?? 0.0;
    final currentGoal = goalInfo.targetForMetric(selectedMetric);
    final goalText = goalInfo.goalLabelForMetric(selectedMetric);
    final progress =
    currentGoal <= 0 ? 0.0 : (currentValue / currentGoal).clamp(0.0, 1.0);
    final remaining = currentGoal - currentValue;

    return LayoutBuilder(
      builder: (context, constraints) {
        final ringSize = math.min(constraints.maxWidth * 0.55, 220.0);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Card(
                color: colorScheme.primaryContainer,
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
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.calendar_month_outlined,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<ProgressMetric>(
                          value: selectedMetric,
                          underline: const SizedBox(),
                          dropdownColor: colorScheme.secondaryContainer,
                          iconEnabledColor: colorScheme.onSecondaryContainer,
                          style: TextStyle(
                            color: colorScheme.onSecondaryContainer,
                            fontSize: 16,
                          ),
                          onChanged: (value) {
                            if (value != null) onMetricChanged(value);
                          },
                          items: ProgressMetric.values
                              .map(
                                (m) => DropdownMenuItem(
                              value: m,
                              child: Text(m.label),
                            ),
                          )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Today\'s ${selectedMetric.label}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: ringSize,
                            height: ringSize,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 16,
                              backgroundColor:
                              colorScheme.primary.withOpacity(0.18),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatNumber(
                                  currentValue,
                                  decimals:
                                  selectedMetric == ProgressMetric.calories
                                      ? 0
                                      : 1,
                                ),
                                style: TextStyle(
                                  fontSize: ringSize * 0.19,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                              Text(
                                '${selectedMetric.unit} consumed',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Goal: $goalText',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        remaining >= 0
                            ? '${formatNumber(remaining, decimals: selectedMetric == ProgressMetric.calories ? 0 : 1)} ${selectedMetric.unit} remaining'
                            : '${formatNumber(remaining.abs(), decimals: selectedMetric == ProgressMetric.calories ? 0 : 1)} ${selectedMetric.unit} over midpoint target',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                        textAlign: TextAlign.center,
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
                          Expanded(
                            child: Text(
                              '${mealsForDay.length} item(s)',
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
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
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.onPrimaryContainer,
                            ),
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
                        key: ValueKey(
                          '${m.name}-${m.addedAt.toIso8601String()}-$i',
                        ),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: colorScheme.errorContainer,
                          child: Icon(
                            Icons.delete,
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                        confirmDismiss: (_) async =>
                        await showDialog<bool>(
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
                            false,
                        onDismissed: (_) => onDeleteMeal(m),
                        child: Card(
                          color: colorScheme.surfaceContainerHighest,
                          child: ListTile(
                            onTap: () => _showEditDialog(context, m),
                            title: Text(m.name),
                            subtitle: Text(
                              [
                                if (m.brand != null && m.brand!.trim().isNotEmpty)
                                  'Brand: ${m.brand}',
                                'Grams: ${formatNumber(m.grams)}g',
                                if (m.kcal != null)
                                  'Calories: ${formatNumber(m.kcal!, decimals: 0)}',
                                if (m.protein != null)
                                  'P: ${m.protein!.toStringAsFixed(1)}g',
                                if (m.carbs != null)
                                  'C: ${m.carbs!.toStringAsFixed(1)}g',
                                if (m.fat != null)
                                  'F: ${m.fat!.toStringAsFixed(1)}g',
                                'Tap to edit',
                              ].join(' • '),
                            ),
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