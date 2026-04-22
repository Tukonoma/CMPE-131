import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'nutrition_models.dart';

class AddMealPage extends StatefulWidget {
  final void Function(Meal) onAddMeal;
  final DateTime selectedDay;

  const AddMealPage({
    super.key,
    required this.onAddMeal,
    required this.selectedDay,
  });

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
  List<int>.generate(200, (i) => (i + 1) * 10);

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() => _error = 'Please enter a search term.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _results = const [];
    });

    try {
      final uri = Uri.https(
        'api.nal.usda.gov',
        '/fdc/v1/foods/search',
        {'api_key': _apiKey},
      );
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
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final foods = (decoded['foods'] as List?) ?? const [];

      setState(
            () => _results = foods
            .map((f) => _UsdaFood.fromJson(f as Map<String, dynamic>))
            .where((f) => f.description.trim().isNotEmpty)
            .toList(),
      );
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
    widget.onAddMeal(
      Meal(
        name: f.description,
        brand: f.brandOwner,
        barcode: f.gtinUpc,
        grams: grams,
        kcal100g: f.kcal100g,
        protein100g: f.protein100g,
        carbs100g: f.carbs100g,
        fat100g: f.fat100g,
        addedAt: DateTime(
          widget.selectedDay.year,
          widget.selectedDay.month,
          widget.selectedDay.day,
          now.hour,
          now.minute,
          now.second,
          now.millisecond,
          now.microsecond,
        ),
      ),
    );
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
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
          ),
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
                  scrollController:
                  FixedExtentScrollController(initialItem: selectedIndex),
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
                        final grams = double.tryParse(manualCtrl.text.trim());
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
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
                      labelText:
                      'Search food for ${DateFormat('MMM d').format(widget.selectedDay)}',
                      border: const OutlineInputBorder(),
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
                      subtitle: Text(
                        [
                          if (f.brandOwner != null &&
                              f.brandOwner!.trim().isNotEmpty)
                            'Brand: ${f.brandOwner}',
                          if (f.kcal100g != null)
                            'kcal/100g: ${f.kcal100g!.toStringAsFixed(0)}',
                          if (f.protein100g != null)
                            'P/100g: ${f.protein100g!.toStringAsFixed(1)}g',
                          if (f.carbs100g != null)
                            'C/100g: ${f.carbs100g!.toStringAsFixed(1)}g',
                          if (f.fat100g != null)
                            'F/100g: ${f.fat100g!.toStringAsFixed(1)}g',
                        ].join(' • '),
                      ),
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
      kcal100g: _nutrientByName(nutrients, ['energy', 'energy (kcal)']),
      protein100g: _nutrientByName(nutrients, ['protein']),
      carbs100g: _nutrientByName(
        nutrients,
        ['carbohydrate, by difference', 'carbohydrate'],
      ),
      fat100g: _nutrientByName(nutrients, ['total lipid (fat)', 'total fat']),
    );
  }
}