
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/garage_screen.dart';
import 'screens/register_motorcycle_screen.dart';
import 'screens/register_user_screen.dart';
import 'services/app_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep RideSync in portrait orientation.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const RideSyncApp());
}

class RideSyncApp extends StatelessWidget {
  const RideSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RideSync',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101114),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B35),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101114),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1B1D22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        useMaterial3: true,
      ),
      home: const StartupScreen(),
    );
  }
}

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late Future<Widget> _initialScreenFuture;

  @override
  void initState() {
    super.initState();
    _initialScreenFuture = _getInitialScreen();
  }

  Future<void> _retry() async {
    setState(() {
      _initialScreenFuture = _getInitialScreen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B35),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFFF6B35),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load RideSync data.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('RETRY'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return snapshot.data ?? const GarageScreen();
      },
    );
  }

  Future<Widget> _getInitialScreen() async {
    final user = await AppStorage.loadUser();

    if (user == null) {
      return const RegisterUserScreen();
    }

    final motorcycles = await AppStorage.loadMotorcycles();

    if (motorcycles.isEmpty) {
      return const RegisterMotorcycleScreen();
    }

    return const GarageScreen();
  }
}
