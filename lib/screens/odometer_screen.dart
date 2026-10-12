
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../models/motorcycle.dart';
import '../models/ride_record.dart';
import '../services/app_storage.dart';
import 'ride_history_screen.dart';

class OdometerScreen extends StatefulWidget {
  final Motorcycle motorcycle;

  const OdometerScreen({
    super.key,
    required this.motorcycle,
  });

  @override
  State<OdometerScreen> createState() => _OdometerScreenState();
}

class _OdometerScreenState extends State<OdometerScreen> {
  static const Color orange = Color(0xFFFF6B35);
  static const Color background = Color(0xFF101114);
  static const Color panel = Color(0xFF1B1D22);
  static const Color muted = Color(0xFF9297A1);

  StreamSubscription<Position>? _positionSubscription;
  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();

  DateTime? _rideStartedAt;

  double _speedKmh = 0;
  double _tripDistanceKm = 0;
  double _baseOdometerKm = 0;
  double _averageSpeedKmh = 0;
  double _maxSpeedKmh = 0;

  Duration _elapsed = Duration.zero;
  Position? _lastPosition;

  bool _isRiding = false;
  bool _isLoading = false;
  bool _isStopping = false;
  bool _odometerSaved = false;

  String _gpsStatus = 'GPS not started';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _baseOdometerKm = widget.motorcycle.odometerKm.toDouble();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _startRide() async {
    if (_isLoading || _isRiding || _isStopping) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _gpsStatus = 'Checking GPS...';
    });

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Location is disabled. Turn on your phone GPS and try again.',
        );
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is required. Check your phone settings.',
        );
      }

      await _positionSubscription?.cancel();
      _timer?.cancel();

      _stopwatch
        ..reset()
        ..start();

      if (!mounted) return;

      setState(() {
        _speedKmh = 0;
        _tripDistanceKm = 0;
        _averageSpeedKmh = 0;
        _maxSpeedKmh = 0;
        _elapsed = Duration.zero;
        _lastPosition = null;
        _odometerSaved = false;
        _rideStartedAt = DateTime.now();
        _isRiding = true;
        _gpsStatus = 'Searching for GPS...';
      });

      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (!mounted || !_isRiding) return;

          setState(() {
            _elapsed = _stopwatch.elapsed;

            if (_elapsed.inSeconds > 0) {
              _averageSpeedKmh = _tripDistanceKm /
                  (_elapsed.inSeconds / 3600);
            }
          });
        },
      );

      const settings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        _handlePosition,
        onError: (Object error) {
          if (!mounted) return;

          setState(() {
            _gpsStatus = 'GPS error';
            _errorMessage =
                'Unable to read GPS data. Check your location settings.';
          });
        },
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isRiding = false;
        _gpsStatus = 'GPS unavailable';
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });

      _stopwatch.stop();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handlePosition(Position position) {
    if (!mounted || !_isRiding) return;

    if (position.accuracy > 35) {
      setState(() {
        _gpsStatus = 'GPS accuracy is low';
      });
      return;
    }

    final previous = _lastPosition;
    _lastPosition = position;

    if (previous != null) {
      final distanceMeters = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        position.latitude,
        position.longitude,
      );

      final seconds = position.timestamp
              .difference(previous.timestamp)
              .inMilliseconds /
          1000;

      // Ignore GPS jumps and implausible position changes.
      if (distanceMeters >= 0 &&
          distanceMeters < 250 &&
          seconds > 0 &&
          distanceMeters / seconds < 60) {
        _tripDistanceKm += distanceMeters / 1000;
      }
    }

    setState(() {
      _speedKmh = (position.speed * 3.6)
          .clamp(0, 300)
          .toDouble();

      if (_speedKmh > _maxSpeedKmh) {
        _maxSpeedKmh = _speedKmh;
      }

      _averageSpeedKmh = _elapsed.inSeconds > 0
          ? _tripDistanceKm / (_elapsed.inSeconds / 3600)
          : 0;

      _gpsStatus = 'GPS connected';
      _errorMessage = null;
    });
  }

  Future<void> _stopRide() async {
    if (!_isRiding || _isStopping) return;

    setState(() => _isStopping = true);

    _stopwatch.stop();
    _timer?.cancel();

    await _positionSubscription?.cancel();
    _positionSubscription = null;

    if (!mounted) return;

    final endedAt = DateTime.now();

    setState(() {
      _isRiding = false;
      _speedKmh = 0;
      _elapsed = _stopwatch.elapsed;
      _gpsStatus = 'Ride stopped';
    });

    try {
      await _saveOdometer();
      await _saveRideHistory(endedAt);
    } finally {
      if (mounted) {
        setState(() => _isStopping = false);
      }
    }
  }

  Future<void> _saveOdometer() async {
    if (_odometerSaved || _tripDistanceKm <= 0) return;

    final motorcycles = await AppStorage.loadMotorcycles();

    final index = motorcycles.indexWhere(
      (bike) => bike.id == widget.motorcycle.id,
    );

    if (index == -1) {
      throw Exception('Motorcycle was not found.');
    }

    final bike = motorcycles[index];

    final updatedOdometer =
        bike.odometerKm.toDouble() + _tripDistanceKm;

    motorcycles[index] = Motorcycle(
      id: bike.id,
      nickname: bike.nickname,
      make: bike.make,
      model: bike.model,
      year: bike.year,
      type: bike.type,
      odometerKm: updatedOdometer.toInt(),
      oilChangeIntervalKm: bike.oilChangeIntervalKm,
    );

    await AppStorage.saveMotorcycles(motorcycles);

    if (!mounted) return;

    setState(() {
      _baseOdometerKm = updatedOdometer;
      _odometerSaved = true;
    });
  }

  Future<void> _saveRideHistory(DateTime endedAt) async {
    final startedAt = _rideStartedAt;

    if (startedAt == null) return;

    final ride = RideRecord(
      id: const Uuid().v4(),
      motorcycleId: widget.motorcycle.id,
      motorcycleName: widget.motorcycle.nickname.isNotEmpty
          ? widget.motorcycle.nickname
          : widget.motorcycle.displayName,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: _elapsed.inSeconds,
      distanceKm: _tripDistanceKm,
      averageSpeedKmh: _elapsed.inSeconds > 0
          ? _tripDistanceKm / (_elapsed.inSeconds / 3600)
          : 0,
      maxSpeedKmh: _maxSpeedKmh,
      odometerAfterKm: _odometerSaved
          ? _baseOdometerKm
          : _baseOdometerKm + _tripDistanceKm,
    );

    await AppStorage.saveRide(ride);

    _rideStartedAt = null;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride saved to history.'),
          backgroundColor: panel,
        ),
      );
    }
  }

  Future<void> _openHistory() async {
    if (_isRiding || _isStopping || _isLoading) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RideHistoryScreen(),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes =
        (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds =
        (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  String _formatKm(double distance) => distance.toStringAsFixed(2);

  double get _displayOdometer {
    return _odometerSaved
        ? _baseOdometerKm
        : _baseOdometerKm + _tripDistanceKm;
  }

  double get _serviceRemaining {
    final interval =
        widget.motorcycle.oilChangeIntervalKm.toDouble();

    if (interval <= 0) return 0;

    final remainder = _displayOdometer % interval;
    return remainder == 0 ? interval : interval - remainder;
  }

  @override
  Widget build(BuildContext context) {
    final bike = widget.motorcycle;
    final wide = MediaQuery.sizeOf(context).width >= 650;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'ODOMETER',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Ride history',
            onPressed: _isRiding || _isStopping || _isLoading
                ? null
                : _openHistory,
            icon: const Icon(Icons.history, color: orange),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 9,
                  color: _isRiding ? orange : muted,
                ),
                const SizedBox(width: 7),
                Text(
                  _isStopping
                      ? 'SAVING'
                      : (_isRiding ? 'RECORDING' : 'STANDBY'),
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bike.nickname.isNotEmpty
                    ? bike.nickname.toUpperCase()
                    : bike.displayName.toUpperCase(),
                style: const TextStyle(
                  color: orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                bike.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _speedPanel()),
                    const SizedBox(width: 14),
                    Expanded(flex: 4, child: _statsPanel()),
                  ],
                )
              else
                Column(
                  children: [
                    _speedPanel(),
                    const SizedBox(height: 14),
                    _statsPanel(),
                  ],
                ),
              const SizedBox(height: 14),
              _odometerPanel(),
              const SizedBox(height: 14),
              _maintenancePanel(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFFF8A80),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'Ride safely. Stop before using your phone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _speedPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.speed, color: orange, size: 19),
              const SizedBox(width: 8),
              const Text(
                'LIVE SPEED',
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _isRiding ? orange : muted,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 260,
            height: 245,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SpeedGaugePainter(
                      speed: _speedKmh,
                      active: _isRiding,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 35),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _speedKmh.round().toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 68,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'KM/H',
                        style: TextStyle(
                          color: orange,
                          fontSize: 13,
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.gps_fixed,
                size: 15,
                color: _gpsStatus == 'GPS connected' ? orange : muted,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  _gpsStatus,
                  style: const TextStyle(color: muted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isLoading || _isStopping
                  ? null
                  : (_isRiding ? _stopRide : _startRide),
              icon: Icon(
                _isRiding ? Icons.stop_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(
                _isLoading
                    ? 'CONNECTING TO GPS...'
                    : (_isStopping
                        ? 'SAVING RIDE...'
                        : (_isRiding ? 'STOP RIDE' : 'START RIDE')),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: muted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CURRENT RIDE',
            style: TextStyle(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _statRow(
            Icons.route,
            'TRIP DISTANCE',
            '${_formatKm(_tripDistanceKm)} km',
          ),
          const SizedBox(height: 20),
          _statRow(
            Icons.timer_outlined,
            'RIDE DURATION',
            _formatDuration(_elapsed),
          ),
          const SizedBox(height: 20),
          _statRow(
            Icons.trending_up,
            'AVERAGE SPEED',
            '${_averageSpeedKmh.toStringAsFixed(1)} km/h',
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.10)),
          const SizedBox(height: 8),
          const Text(
            'Distance and speed are estimated from GPS readings.',
            style: TextStyle(
              color: muted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: orange.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: orange, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: muted,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _odometerPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.speed_outlined,
              color: orange,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL ODOMETER',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Motorcycle mileage',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _displayOdometer.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'KILOMETERS',
                style: TextStyle(
                  color: orange,
                  fontSize: 9,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _maintenancePanel() {
    final interval = widget.motorcycle.oilChangeIntervalKm.toDouble();
    final hasInterval = interval > 0;

    final progress = hasInterval
        ? ((_displayOdometer % interval) / interval).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.build_circle_outlined, color: orange),
              SizedBox(width: 9),
              Text(
                'MAINTENANCE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasInterval) ...[
            Text(
              '${_serviceRemaining.toStringAsFixed(0)} km until next oil-change interval',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(orange),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Interval: ${interval.toStringAsFixed(0)} km',
              style: const TextStyle(color: muted, fontSize: 11),
            ),
          ] else
            const Text(
              'Set an oil-change interval in your motorcycle settings.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _SpeedGaugePainter extends CustomPainter {
  final double speed;
  final bool active;

  const _SpeedGaugePainter({
    required this.speed,
    required this.active,
  });

  static const Color orange = Color(0xFFFF6B35);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.43;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const startAngle = 2.35;
    const sweepAngle = 2.77;

    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    final progress = (speed / 180).clamp(0.0, 1.0);

    if (progress > 0) {
      final activePaint = Paint()
        ..color = orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle * progress,
        false,
        activePaint,
      );
    }

    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 2;

    for (int i = 0; i <= 18; i++) {
      final angle = startAngle + sweepAngle * i / 18;

      final outer = Offset(
        center.dx + math.cos(angle) * (radius + 12),
        center.dy + math.sin(angle) * (radius + 12),
      );

      final inner = Offset(
        center.dx + math.cos(angle) * (radius + 19),
        center.dy + math.sin(angle) * (radius + 19),
      );

      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedGaugePainter oldDelegate) {
    return oldDelegate.speed != speed ||
        oldDelegate.active != active;
  }
}
