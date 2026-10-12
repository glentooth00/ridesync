
import 'package:flutter/material.dart';

import '../models/motorcycle.dart';
import '../models/user_profile.dart';
import '../services/app_storage.dart';
import 'odometer_screen.dart';
import 'register_motorcycle_screen.dart';

class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  UserProfile? _user;
  List<Motorcycle> _motorcycles = [];
  String? _activeId;
  bool _loading = true;

  static const Color orange = Color(0xFFFF6B35);
  static const Color background = Color(0xFF101114);
  static const Color panel = Color(0xFF1B1D22);

  @override
  void initState() {
    super.initState();
    _loadGarage();
  }

  Future<void> _loadGarage() async {
    try {
      final results = await Future.wait([
        AppStorage.loadUser(),
        AppStorage.loadMotorcycles(),
        AppStorage.loadActiveMotorcycleId(),
      ]);

      if (!mounted) return;

      setState(() {
        _user = results[0] as UserProfile?;
        _motorcycles = results[1] as List<Motorcycle>;
        _activeId = results[2] as String?;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load your garage. Please try again.'),
        ),
      );
    }
  }

  Future<void> _selectMotorcycle(Motorcycle motorcycle) async {
    try {
      await AppStorage.setActiveMotorcycle(motorcycle.id);

      if (!mounted) return;

      setState(() => _activeId = motorcycle.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${motorcycle.displayName} selected.'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to select this motorcycle.'),
        ),
      );
    }
  }

  Future<void> _addMotorcycle() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RegisterMotorcycleScreen(),
      ),
    );

    if (mounted) {
      await _loadGarage();
    }
  }

  void _openOdometer(Motorcycle motorcycle) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OdometerScreen(motorcycle: motorcycle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matchingBikes = _motorcycles
        .where((bike) => bike.id == _activeId)
        .toList();

    final Motorcycle? activeBike =
        matchingBikes.isEmpty ? null : matchingBikes.first;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(
              Icons.two_wheeler,
              color: orange,
              size: 28,
            ),
            SizedBox(width: 10),
            Text(
              'RideSync',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _addMotorcycle,
            tooltip: 'Add motorcycle',
            icon: const Icon(Icons.add_circle_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: orange),
            )
          : RefreshIndicator(
              color: orange,
              backgroundColor: panel,
              onRefresh: _loadGarage,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Welcome, ${_user?.name ?? 'Rider'}',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your ride. Your data.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (activeBike != null) ...[
                    const Text(
                      'ACTIVE MOTORCYCLE',
                      style: TextStyle(
                        color: orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: panel,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: orange.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: orange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.two_wheeler,
                                  color: orange,
                                  size: 34,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: orange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          Text(
                            activeBike.nickname.isEmpty
                                ? activeBike.displayName
                                : activeBike.nickname,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            activeBike.displayName,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 22),

                          Row(
                            children: [
                              Expanded(
                                child: _detail(
                                  'ODOMETER',
                                  '${activeBike.odometerKm} km',
                                ),
                              ),
                              Expanded(
                                child: _detail(
                                  'YEAR',
                                  activeBike.year?.toString() ?? 'Not set',
                                ),
                              ),
                              Expanded(
                                child: _detail(
                                  'TYPE',
                                  activeBike.type,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: () => _openOdometer(activeBike),
                              icon: const Icon(Icons.speed),
                              label: const Text(
                                'OPEN RIDE DASHBOARD',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: panel,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.two_wheeler,
                            color: orange,
                            size: 48,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No active motorcycle',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add a motorcycle to access your ride dashboard.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white60),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _addMotorcycle,
                            icon: const Icon(Icons.add),
                            label: const Text('ADD MOTORCYCLE'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'MY GARAGE',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        '${_motorcycles.length} motorcycle(s)',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_motorcycles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          'No motorcycles registered yet.',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    ),

                  ..._motorcycles.map((bike) {
                    final isActive = bike.id == _activeId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: panel,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isActive
                              ? orange.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF30231F),
                          child: Icon(
                            Icons.two_wheeler,
                            color: orange,
                          ),
                        ),
                        title: Text(
                          bike.nickname.isEmpty
                              ? bike.displayName
                              : bike.nickname,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${bike.displayName} • ${bike.odometerKm} km',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        trailing: isActive
                            ? const Icon(
                                Icons.check_circle,
                                color: orange,
                              )
                            : const Icon(
                                Icons.radio_button_unchecked,
                                color: Colors.white38,
                              ),
                        onTap: () => _selectMotorcycle(bike),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: _addMotorcycle,
                    icon: const Icon(Icons.add),
                    label: const Text('ADD ANOTHER MOTORCYCLE'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: orange,
                      side: const BorderSide(color: orange),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _detail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
