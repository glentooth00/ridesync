
import 'package:flutter/material.dart';

import '../models/motorcycle.dart';
import '../models/user_profile.dart';
import '../services/app_storage.dart';
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

  static const orange = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    _loadGarage();
  }

  Future<void> _loadGarage() async {
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
  }

  Future<void> _selectMotorcycle(Motorcycle motorcycle) async {
    await AppStorage.setActiveMotorcycle(motorcycle.id);

    if (!mounted) return;

    setState(() => _activeId = motorcycle.id);
  }

  Future<void> _addMotorcycle() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RegisterMotorcycleScreen(),
      ),
    );

    if (mounted) await _loadGarage();
  }

  @override
  Widget build(BuildContext context) {
    final activeBike = _motorcycles.where(
      (bike) => bike.id == _activeId,
    ).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RideSync',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _addMotorcycle,
            tooltip: 'Add motorcycle',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadGarage,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Welcome, ${_user?.name ?? 'Rider'}',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your motorcycles, all in one place.',
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 28),
                  if (activeBike != null) ...[
                    const Text(
                      'ACTIVE MOTORCYCLE',
                      style: TextStyle(
                        color: orange,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1D22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: orange.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.two_wheeler,
                            color: orange,
                            size: 40,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            activeBike.nickname.isEmpty
                                ? activeBike.displayName
                                : activeBike.nickname,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            activeBike.displayName,
                            style: const TextStyle(
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 18),
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
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'The live ride dashboard is our next step.',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.speed),
                              label: const Text('OPEN RIDE DASHBOARD'),
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
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
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
                  const SizedBox(height: 12),
                  if (_motorcycles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('No motorcycles registered yet.'),
                      ),
                    ),
                  ..._motorcycles.map((bike) {
                    final isActive = bike.id == _activeId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: const Color(0xFF1B1D22),
                      child: ListTile(
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${bike.displayName} • ${bike.odometerKm} km',
                        ),
                        trailing: isActive
                            ? const Icon(
                                Icons.check_circle,
                                color: orange,
                              )
                            : const Icon(Icons.radio_button_unchecked),
                        onTap: () => _selectMotorcycle(bike),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _addMotorcycle,
                    icon: const Icon(Icons.add),
                    label: const Text('ADD ANOTHER MOTORCYCLE'),
                  ),
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
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
