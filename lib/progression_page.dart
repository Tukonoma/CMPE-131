import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'nutrition_models.dart';

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

  List<WeeklyAverageData> _buildWeeklyAverages() {
    final now = DateTime.now();
    final currentWeekStart = startOfWeek(now);
    final windowStart =
    currentWeekStart.subtract(Duration(days: windowOffset * 35 + 28));

    return List.generate(5, (i) {
      final start = windowStart.add(Duration(days: i * 7));
      final end = start.add(const Duration(days: 6));

      final Map<DateTime, double> totalsByDay = {};

      for (final meal in meals) {
        final day = dateOnly(meal.addedAt);
        if (day.isBefore(start) || day.isAfter(end)) continue;
        totalsByDay[day] =
            (totalsByDay[day] ?? 0.0) + selectedMetric.valueFromMeal(meal);
      }

      double weekTotal = 0.0;
      for (int d = 0; d < 7; d++) {
        final day = start.add(Duration(days: d));
        weekTotal += totalsByDay[dateOnly(day)] ?? 0.0;
      }

      return WeeklyAverageData(
        weekStart: start,
        weekEnd: end,
        average: weekTotal / 7.0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _buildWeeklyAverages();
    final maxY = data.fold(0.0, (max, e) => math.max(max, e.average));
    final chartMaxY = maxY <= 0.0 ? 10.0 : maxY * 1.25;

    final newestWeekStart =
    startOfWeek(DateTime.now()).subtract(Duration(days: windowOffset * 35));
    final oldestWeekStart = newestWeekStart.subtract(const Duration(days: 28));
    final rangeText =
        '${DateFormat('MMM d').format(oldestWeekStart)} - ${DateFormat('MMM d, y').format(newestWeekStart.add(const Duration(days: 6)))}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                DropdownButton<ProgressMetric>(
                  value: selectedMetric,
                  onChanged: (value) {
                    if (value != null) onMetricChanged(value);
                  },
                  items: ProgressMetric.values
                      .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                      .toList(),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onPreviousWindow,
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Previous 5 weeks',
                    ),
                    Text(
                      rangeText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      onPressed: windowOffset == 0 ? null : onNextWindow,
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Next 5 weeks',
                    ),
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
                      ? Center(
                    child: Text(
                      'No data for this 5-week window.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  )
                      : BarChart(
                    BarChartData(
                      maxY: chartMaxY,
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: chartMaxY / 5.0,
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            interval: chartMaxY / 5.0,
                            getTitlesWidget: (value, meta) => Text(
                              formatNumber(value, decimals: 0),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 48,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= data.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat('MMM d')
                                      .format(data[index].weekStart),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem:
                              (group, groupIndex, rod, rodIndex) {
                            final item = data[group.x.toInt()];
                            return BarTooltipItem(
                              '${DateFormat('MMM d').format(item.weekStart)} - ${DateFormat('MMM d').format(item.weekEnd)}\nAvg: ${formatNumber(item.average)} ${selectedMetric.unit}',
                              const TextStyle(color: Colors.white),
                            );
                          },
                        ),
                      ),
                      barGroups: List.generate(
                        data.length,
                            (index) => BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: data[index].average,
                              width: 26.0,
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.teal,
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}