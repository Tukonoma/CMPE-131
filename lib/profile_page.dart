import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:convert';

// ─────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────

enum ActivityLevel {
  inactive,
  lowActive,
  active,
  veryActive;

  String get label => switch (this) {
    ActivityLevel.inactive   => 'Inactive',
    ActivityLevel.lowActive  => 'Low Activity',
    ActivityLevel.active     => 'Active',
    ActivityLevel.veryActive => 'Very Active',
  };
}

enum Gender {
  male,
  female;

  String get label => switch (this) {
    Gender.male   => 'Male',
    Gender.female => 'Female',
  };
}

enum MeasurementSystem {
  metric,
  imperial;

  String get label => switch (this) {
    MeasurementSystem.metric   => 'Metric',
    MeasurementSystem.imperial => 'Imperial',
  };

  String get weightUnit  => this == MeasurementSystem.metric ? 'kg'  : 'lbs';
  String get heightUnit  => this == MeasurementSystem.metric ? 'cm'  : 'in';
}

// ─────────────────────────────────────────────
// Profile Manager
// ─────────────────────────────────────────────

class ProfileManager {
  String name     = '';
  String email    = '';
  int    age      = 0;
  int    heightCm = 0;
  double weightKg = 0;

  Gender            gender            = Gender.male;
  ActivityLevel     activityLevel     = ActivityLevel.inactive;
  MeasurementSystem measurementSystem = MeasurementSystem.metric;

  Uint8List? profileImageBytes;

  // Singleton cache — call ProfileManager.get() anywhere in the app
  static ProfileManager? _cached;

  static Future<ProfileManager> get() async {
    if (_cached != null) return _cached!;
    _cached = ProfileManager._();
    await _cached!._load();
    return _cached!;
  }

  ProfileManager._();

  static Future<ProfileManager> create() async {
    final m = ProfileManager._();
    await m._load();
    return m;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    name      = prefs.getString('name')     ?? '';
    email     = prefs.getString('email')    ?? '';
    age       = prefs.getInt('age')         ?? 0;
    heightCm  = prefs.getInt('heightCm')    ?? 0;
    weightKg  = prefs.getDouble('weightKg') ?? 0;

    gender = Gender.values.firstWhere(
          (e) => e.name == prefs.getString('gender'),
      orElse: () => Gender.male,
    );
    activityLevel = ActivityLevel.values.firstWhere(
          (e) => e.name == prefs.getString('activityLevel'),
      orElse: () => ActivityLevel.inactive,
    );
    measurementSystem = MeasurementSystem.values.firstWhere(
          (e) => e.name == prefs.getString('measurementSystem'),
      orElse: () => MeasurementSystem.metric,
    );

    final imgBase64 = prefs.getString('profileImageBase64');
    if (imgBase64 != null) {
      profileImageBytes = base64Decode(imgBase64);
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('name',              name);
    await prefs.setString('email',             email);
    await prefs.setInt('age',                  age);
    await prefs.setInt('heightCm',             heightCm);
    await prefs.setDouble('weightKg',          weightKg);
    await prefs.setString('gender',            gender.name);
    await prefs.setString('activityLevel',     activityLevel.name);
    await prefs.setString('measurementSystem', measurementSystem.name);

    if (profileImageBytes != null) {
      await prefs.setString(
          'profileImageBase64', base64Encode(profileImageBytes!));
    }
  }
}

// ─────────────────────────────────────────────
// Profile Page
// ─────────────────────────────────────────────

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late ProfileManager _profile;
  bool _loading = true;

  final _nameCtr   = TextEditingController();
  final _emailCtr  = TextEditingController();
  final _ageCtr    = TextEditingController();
  final _heightCtr = TextEditingController();
  final _weightCtr = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _picker  = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    _profile = await ProfileManager.create();

    _nameCtr.text  = _profile.name;
    _emailCtr.text = _profile.email;
    _ageCtr.text   = _profile.age == 0 ? '' : '${_profile.age}';
    _updateDisplayUnits();

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    _emailCtr.dispose();
    _ageCtr.dispose();
    _heightCtr.dispose();
    _weightCtr.dispose();
    super.dispose();
  }

  // Reads the internally stored metric values and fills the text fields
  // using the currently selected measurement system.
  // Call this on load and whenever the measurement system changes.
  void _updateDisplayUnits() {
    if (_profile.measurementSystem == MeasurementSystem.imperial) {
      final lbs    = _profile.weightKg * 2.20462;
      final inches = (_profile.heightCm / 2.54).round();
      _weightCtr.text = _profile.weightKg == 0 ? '' : lbs.toStringAsFixed(1);
      _heightCtr.text = _profile.heightCm == 0 ? '' : '$inches';
    } else {
      _weightCtr.text = _profile.weightKg == 0 ? '' : _profile.weightKg.toStringAsFixed(1);
      _heightCtr.text = _profile.heightCm == 0 ? '' : '${_profile.heightCm}';
    }
  }

  Future<void> _pickImage() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() => _profile.profileImageBytes = bytes);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    _profile.name  = _nameCtr.text.trim();
    _profile.email = _emailCtr.text.trim();
    _profile.age   = int.tryParse(_ageCtr.text) ?? 0;

    final enteredWeight = double.tryParse(_weightCtr.text) ?? 0;
    final enteredHeight = int.tryParse(_heightCtr.text)    ?? 0;

    if (_profile.measurementSystem == MeasurementSystem.imperial) {
      // lbs → kg:  divide by 2.20462
      // in  → cm:  multiply by 2.54
      _profile.weightKg = enteredWeight / 2.20462;
      _profile.heightCm = (enteredHeight * 2.54).round();
    } else {
      // Already metric — store as-is
      _profile.weightKg = enteredWeight;
      _profile.heightCm = enteredHeight;
    }

    await _profile.save();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved ✓'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [

            // ── Profile picture ───────────────
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage: _profile.profileImageBytes != null
                        ? MemoryImage(_profile.profileImageBytes!)
                        : null,
                    child: _profile.profileImageBytes == null
                        ? Icon(Icons.person_rounded, size: 64,
                        color: cs.onPrimaryContainer)
                        : null,
                  ),
                  Positioned(
                    bottom: 4, right: 4,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: cs.primary,
                        child: Icon(Icons.camera_alt_rounded, size: 18,
                            color: cs.onPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Personal info ─────────────────
            _sectionLabel('Personal Info'),
            const SizedBox(height: 12),

            _textField(
              controller: _nameCtr,
              label: 'Full Name',
              icon: Icons.badge_rounded,
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),

            _textField(
              controller: _emailCtr,
              label: 'Email',
              icon: Icons.email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),

            _textField(
              controller: _ageCtr,
              label: 'Age',
              icon: Icons.cake_rounded,
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1 || n > 120) return 'Enter a valid age';
                return null;
              },
            ),
            const SizedBox(height: 14),

            _dropdown<Gender>(
              label: 'Gender',
              icon: Icons.people_rounded,
              value: _profile.gender,
              items: Gender.values,
              itemLabel: (e) => e.label,
              onChanged: (e) => setState(() => _profile.gender = e!),
            ),

            const SizedBox(height: 28),

            // ── Body metrics ──────────────────
            _sectionLabel('Body Metrics'),
            const SizedBox(height: 12),

            // Measurement system dropdown first, so the unit labels below update
            _dropdown<MeasurementSystem>(
              label: 'Measurement System',
              icon: Icons.straighten_rounded,
              value: _profile.measurementSystem,
              items: MeasurementSystem.values,
              itemLabel: (e) => e.label,
              onChanged: (e) {
                // Before switching units, convert whatever is currently
                // typed back into the stored metric fields.
                final enteredWeight = double.tryParse(_weightCtr.text) ?? 0;
                final enteredHeight = int.tryParse(_heightCtr.text)    ?? 0;
                if (_profile.measurementSystem == MeasurementSystem.imperial) {
                  _profile.weightKg = enteredWeight / 2.20462;
                  _profile.heightCm = (enteredHeight * 2.54).round();
                } else {
                  _profile.weightKg = enteredWeight;
                  _profile.heightCm = enteredHeight;
                }
                setState(() {
                  _profile.measurementSystem = e!;
                  _updateDisplayUnits();
                });
              },
            ),
            const SizedBox(height: 14),

            // Weight row: [text field] [unit label]
            _metricRow(
              controller: _weightCtr,
              label: 'Weight',
              icon: Icons.monitor_weight_rounded,
              unit: _profile.measurementSystem.weightUnit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return (n == null || n <= 0) ? 'Invalid' : null;
              },
            ),
            const SizedBox(height: 14),

            // Height row: [text field] [unit label]
            _metricRow(
              controller: _heightCtr,
              label: 'Height',
              icon: Icons.height_rounded,
              unit: _profile.measurementSystem.heightUnit,
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n <= 0) ? 'Invalid' : null;
              },
            ),

            const SizedBox(height: 28),

            // ── Activity level ────────────────
            _sectionLabel('Activity Level'),
            const SizedBox(height: 12),

            _dropdown<ActivityLevel>(
              label: 'Activity Level',
              icon: Icons.directions_run_rounded,
              value: _profile.activityLevel,
              items: ActivityLevel.values,
              itemLabel: (e) => e.label,
              onChanged: (e) => setState(() => _profile.activityLevel = e!),
            ),

            const SizedBox(height: 32),

            // ── Save button ───────────────────
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save Profile'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Reusable widgets ────────────────────────

  Widget _sectionLabel(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
    );
  }

  // A text field with a greyed-out unit box on the right: [field] [unit]
  Widget _metricRow({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String unit,
    TextInputType keyboardType = TextInputType.number,
    String? Function(String?)? validator,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The number input takes up most of the width
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon),
              // Square off the right side so it connects visually to the unit box
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                  right: Radius.zero,
                ),
              ),
              filled: true,
            ),
          ),
        ),

        // Unit label box — same height as the field, greyed out
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(12),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            unit,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdown<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(itemLabel(e))))
          .toList(),
      onChanged: onChanged,
    );
  }
}