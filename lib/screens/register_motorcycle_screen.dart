
import 'package:flutter/material.dart';

import '../models/motorcycle.dart';
import '../services/app_storage.dart';
import 'garage_screen.dart';

class RegisterMotorcycleScreen extends StatefulWidget {
  const RegisterMotorcycleScreen({super.key});

  @override
  State<RegisterMotorcycleScreen> createState() =>
      _RegisterMotorcycleScreenState();
}

class _RegisterMotorcycleScreenState
    extends State<RegisterMotorcycleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _odometer = TextEditingController(text: '0');

  String _type = 'Cafe racer';
  int _oilInterval = 1500;
  bool _saving = false;

  final List<String> _types = [
    'Cafe racer',
    'Standard / naked',
    'Sport bike',
    'Underbone',
    'Scooter',
    'Adventure / touring',
    'Cruiser',
    'Other',
  ];

  @override
  void dispose() {
    _nickname.dispose();
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _odometer.dispose();
    super.dispose();
  }

  Future<void> _saveMotorcycle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final motorcycle = Motorcycle(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        nickname: _nickname.text.trim(),
        make: _make.text.trim(),
        model: _model.text.trim(),
        year: _year.text.trim().isEmpty
            ? null
            : int.parse(_year.text.trim()),
        type: _type,
        odometerKm: int.parse(_odometer.text.trim()),
        oilChangeIntervalKm: _oilInterval,
      );

      await AppStorage.addMotorcycle(motorcycle);

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const GarageScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save motorcycle: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateNumber(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'This field is required' : null;
    }

    final number = int.tryParse(value.trim());

    if (number == null || number < 0) {
      return 'Enter a valid non-negative number';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF6B35);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Motorcycle'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.two_wheeler,
                size: 48,
                color: orange,
              ),
              const SizedBox(height: 20),
              const Text(
                'Add your motorcycle',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the details of the motorcycle you want to track.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _nickname,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nickname (optional)',
                  hintText: 'e.g. My Daily Ride',
                  prefixIcon: Icon(Icons.label_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _make,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Make / brand',
                  hintText: 'e.g. Honda, Yamaha, Keeway',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Enter the motorcycle make'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _model,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'e.g. CR152',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Enter the motorcycle model'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _year,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Model year (optional)',
                  hintText: 'e.g. 2024',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }

                  final year = int.tryParse(value.trim());

                  if (year == null ||
                      year < 1900 ||
                      year > DateTime.now().year + 1) {
                    return 'Enter a valid model year';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Motorcycle type',
                  border: OutlineInputBorder(),
                ),
                items: _types
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _odometer,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Current odometer (km)',
                  helperText: 'Enter the reading shown on your dashboard.',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateNumber(value),
              ),
              const SizedBox(height: 24),
              const Text(
                'ENGINE OIL REMINDER',
                style: TextStyle(
                  color: orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _oilInterval,
                decoration: const InputDecoration(
                  labelText: 'Oil-change interval',
                  border: OutlineInputBorder(),
                ),
                items: [1000, 1500, 2000, 2500, 3000, 5000]
                    .map(
                      (km) => DropdownMenuItem(
                        value: km,
                        child: Text('$km km'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _oilInterval = value);
                  }
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'This is a configurable starting interval. Check your motorcycle manufacturer’s recommended service schedule.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveMotorcycle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _saving ? 'SAVING...' : 'SAVE MOTORCYCLE',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
