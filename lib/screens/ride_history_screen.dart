
import 'package:flutter/material.dart';

import '../models/ride_record.dart';
import '../services/app_storage.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() =>
      _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  List<RideRecord> _rides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    final rides = await AppStorage.loadRideHistory();

    if (!mounted) return;

    setState(() {
      _rides = rides;
      _isLoading = false;
    });
  }

  Future<void> _deleteRide(RideRecord ride) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete ride?'),
        content: const Text(
          'This ride will be permanently removed from your history.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text(
              'DELETE',
              style: TextStyle(color: Color(0xFFFF6B35)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await AppStorage.deleteRide(ride.id);
    await _loadRides();
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final remainingSeconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    }

    return '${remainingSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final totalDistance = _rides.fold<double>(
      0,
      (total, ride) => total + ride.distanceKm,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF101114),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101114),
        foregroundColor: Colors.white,
        title: const Text(
          'Ride History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            onPressed: _loadRides,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B35),
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFFFF6B35),
              onRefresh: _loadRides,
              child: _rides.isEmpty
                  ? ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 150),
                        Icon(
                          Icons.route,
                          size: 64,
                          color: Colors.white30,
                        ),
                        SizedBox(height: 16),
                        Center(
                          child: Text(
                            'No rides recorded yet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Your completed rides will appear here.',
                            style: TextStyle(
                              color: Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1D22),
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _summary(
                                  'TOTAL RIDES',
                                  '${_rides.length}',
                                  Icons.two_wheeler,
                                ),
                              ),
                              Expanded(
                                child: _summary(
                                  'TOTAL DISTANCE',
                                  '${totalDistance.toStringAsFixed(1)} km',
                                  Icons.route,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ..._rides.map(
                          (ride) => Card(
                            color: const Color(0xFF1B1D22),
                            margin:
                                const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              leading: const CircleAvatar(
                                backgroundColor:
                                    Color(0x22FF6B35),
                                child: Icon(
                                  Icons.two_wheeler,
                                  color: Color(0xFFFF6B35),
                                ),
                              ),
                              title: Text(
                                ride.motorcycleName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Padding(
                                padding:
                                    const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${ride.startedAt.toLocal()}\n'
                                  '${ride.distanceKm.toStringAsFixed(2)} km'
                                  '  •  ${_formatDuration(ride.durationSeconds)}',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                tooltip: 'Delete ride',
                                onPressed: () =>
                                    _deleteRide(ride),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFFF6B35),
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

  Widget _summary(
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFFF6B35)),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
