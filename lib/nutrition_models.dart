import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'profile_page.dart';

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

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime startOfWeek(DateTime d) {
  final date = dateOnly(d);
  return date.subtract(Duration(days: date.weekday - 1));
}

String formatNumber(double value, {int decimals = 1}) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(decimals);
}

enum ProgressMetric { calories, protein, carbs, fat }

extension ProgressMetricX on ProgressMetric {
  String get label => switch (this) {
    ProgressMetric.calories => 'Calories',
    ProgressMetric.protein => 'Protein',
    ProgressMetric.carbs => 'Carbs',
    ProgressMetric.fat => 'Fat',
  };

  String get unit => switch (this) {
    ProgressMetric.calories => 'kcal',
    _ => 'g',
  };

  double valueFromMeal(Meal meal) => switch (this) {
    ProgressMetric.calories => meal.kcal ?? 0.0,
    ProgressMetric.protein => meal.protein ?? 0.0,
    ProgressMetric.carbs => meal.carbs ?? 0.0,
    ProgressMetric.fat => meal.fat ?? 0.0,
  };
}

class GoalInfo {
  final double calories;
  final double carbsMin;
  final double carbsMax;
  final double proteinMin;
  final double proteinMax;
  final double fatMin;
  final double fatMax;

  const GoalInfo({
    required this.calories,
    required this.carbsMin,
    required this.carbsMax,
    required this.proteinMin,
    required this.proteinMax,
    required this.fatMin,
    required this.fatMax,
  });

  double targetForMetric(ProgressMetric metric) {
    switch (metric) {
      case ProgressMetric.calories:
        return calories;
      case ProgressMetric.protein:
        return (proteinMin + proteinMax) / 2.0;
      case ProgressMetric.carbs:
        return (carbsMin + carbsMax) / 2.0;
      case ProgressMetric.fat:
        return (fatMin + fatMax) / 2.0;
    }
  }

  String goalLabelForMetric(ProgressMetric metric) {
    switch (metric) {
      case ProgressMetric.calories:
        return '${formatNumber(calories, decimals: 0)} kcal/day';
      case ProgressMetric.protein:
        return '${formatNumber(proteinMin)}-${formatNumber(proteinMax)} g/day';
      case ProgressMetric.carbs:
        return '${formatNumber(carbsMin)}-${formatNumber(carbsMax)} g/day';
      case ProgressMetric.fat:
        return '${formatNumber(fatMin)}-${formatNumber(fatMax)} g/day';
    }
  }
}

double calculateCalories({
  required Gender gender,
  required ActivityLevel activityLevel,
  required int age,
  required double heightCm,
  required double weightKg,
}) {
  if (gender == Gender.male) {
    switch (activityLevel) {
      case ActivityLevel.inactive:
        return 753.07 - (10.83 * age) + (6.50 * heightCm) + (14.10 * weightKg);
      case ActivityLevel.lowActive:
        return 581.47 - (10.83 * age) + (8.30 * heightCm) + (14.94 * weightKg);
      case ActivityLevel.active:
        return 1004.82 - (10.83 * age) + (6.52 * heightCm) + (15.91 * weightKg);
      case ActivityLevel.veryActive:
        return -517.88 - (10.83 * age) + (15.61 * heightCm) + (19.11 * weightKg);
    }
  } else {
    switch (activityLevel) {
      case ActivityLevel.inactive:
        return 584.90 - (7.01 * age) + (5.72 * heightCm) + (11.71 * weightKg);
      case ActivityLevel.lowActive:
        return 575.77 - (7.01 * age) + (6.60 * heightCm) + (12.14 * weightKg);
      case ActivityLevel.active:
        return 710.25 - (7.01 * age) + (6.54 * heightCm) + (12.34 * weightKg);
      case ActivityLevel.veryActive:
        return 511.83 - (7.01 * age) + (9.07 * heightCm) + (12.56 * weightKg);
    }
  }
}

GoalInfo buildGoalsFromProfile(ProfileManager profile) {
  if (profile.age <= 0 || profile.heightCm <= 0 || profile.weightKg <= 0) {
    return const GoalInfo(
      calories: 2000,
      carbsMin: 225,
      carbsMax: 325,
      proteinMin: 50,
      proteinMax: 175,
      fatMin: 44,
      fatMax: 78,
    );
  }

  final calories = calculateCalories(
    gender: profile.gender,
    activityLevel: profile.activityLevel,
    age: profile.age,
    heightCm: profile.heightCm.toDouble(),
    weightKg: profile.weightKg,
  );

  final carbsMin = (calories * 0.45) / 4.0;
  final carbsMax = (calories * 0.65) / 4.0;
  final proteinMin = (calories * 0.10) / 4.0;
  final proteinMax = (calories * 0.35) / 4.0;
  final fatMin = (calories * 0.20) / 9.0;
  final fatMax = (calories * 0.35) / 9.0;

  return GoalInfo(
    calories: calories,
    carbsMin: carbsMin,
    carbsMax: carbsMax,
    proteinMin: proteinMin,
    proteinMax: proteinMax,
    fatMin: fatMin,
    fatMax: fatMax,
  );
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
    return Chip(label: Text('$label: ${value.toStringAsFixed(1)} $unit'));
  }
}

class WeeklyAverageData {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double average;

  const WeeklyAverageData({
    required this.weekStart,
    required this.weekEnd,
    required this.average,
  });
}