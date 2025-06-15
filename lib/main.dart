import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/supabase_config.dart';
import 'services/supabase_service.dart';
import 'services/auth_service.dart';
import 'services/gas_notification_service.dart';
import 'screens/gas_monitor_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: GasLeakMonitorApp(),
    ),
  );
}

class GasLeakMonitorApp extends StatefulWidget {
  const GasLeakMonitorApp({super.key});

  @override
  State<GasLeakMonitorApp> createState() => _GasLeakMonitorAppState();
}

class _GasLeakMonitorAppState extends State<GasLeakMonitorApp> {
  bool _isDarkMode = false;

  void _updateTheme(bool isDarkMode) {
    setState(() {
      _isDarkMode = isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gas Leak Monitor',
      theme: _isDarkMode ? _darkTheme : _lightTheme,
      home: AppInitializer(
        isDarkMode: _isDarkMode,
        onThemeChanged: _updateTheme,
      ),
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData get _lightTheme => ThemeData(
    primarySwatch: Colors.teal,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: Colors.grey[50],
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.teal,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, color: Colors.black87, fontFamily: 'Roboto'),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
      headlineSmall: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600),
      headlineLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
      bodySmall: TextStyle(fontFamily: 'Roboto'),
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  ThemeData get _darkTheme => ThemeData(
    primarySwatch: Colors.teal,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: Colors.grey[900],
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.teal,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, color: Colors.white70, fontFamily: 'Roboto'),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
      headlineSmall: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600),
      headlineLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
      bodySmall: TextStyle(fontFamily: 'Roboto'),
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitializing = true;
  String? _initError;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Check if Supabase is configured
      if (!SupabaseConfig.isConfigured) {
        setState(() {
          _initError =
              'Supabase not configured. Please update lib/config/supabase_config.dart with your credentials.';
          _isInitializing = false;
        });
        return;
      }

      // Initialize Supabase
      await SupabaseService.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );

      // Initialize local authentication session
      final authService = AuthService.instance;
      await authService.initializeLocalSession();

      // Check authentication status (both Supabase and local)
      final isLoggedIn = authService.isLoggedIn;

      // 🔔 CONDITIONAL NOTIFICATIONS: Only start if user is authenticated
      if (isLoggedIn) {
        await _autoStartNotifications();
        if (kDebugMode) print('🔐 USER AUTHENTICATED: Gas notifications enabled');
      } else {
        if (kDebugMode) print('🔒 USER NOT AUTHENTICATED: Gas notifications blocked until login');
      }

      setState(() {
        _isAuthenticated = isLoggedIn;
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _initError = 'Failed to initialize: $e';
        _isInitializing = false;
      });
    }
  }

  /// Automatically start INSTANT notification monitoring for real ESP32 gas alerts
  Future<void> _autoStartNotifications() async {
    try {
      if (kDebugMode) print('🔔 INITIALIZING INSTANT GAS NOTIFICATION SERVICE...');
      
      final gasNotificationService = GasNotificationService.instance;
      await gasNotificationService.initialize();
      
      // Start instant monitoring immediately
      await gasNotificationService.startMonitoring();
      
      if (kDebugMode) {
        print('✅ INSTANT GAS NOTIFICATION SERVICE ACTIVE');
        print('⚡ REAL-TIME monitoring: WARNING(100+ PPM), DANGER(300+ PPM), CRITICAL(600+ PPM)');
        print('🚨 Instant gas alerts - notifications fire in <500ms');
        print('🔄 Checking every 500ms + real-time stream monitoring');
      }
    } catch (e) {
      if (kDebugMode) print('❌ INSTANT GAS NOTIFICATION ERROR: $e');
      // Don't fail app startup if notifications fail
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Gas Leak Monitor'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // Add refresh functionality here
              },
            ),
            IconButton(
              icon: Icon(
                widget.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              ),
              onPressed: () => widget.onThemeChanged(!widget.isDarkMode),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      isDarkMode: widget.isDarkMode,
                      onDarkModeChanged: widget.onThemeChanged,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Initializing Gas Leak Monitor...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (_initError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuration Error')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 24),
              Text(
                'Configuration Required',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _initError!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              const SetupInstructions(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isInitializing = true;
                        _initError = null;
                      });
                      _initializeApp();
                    },
                    child: const Text('Retry'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to test screen
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GasMonitorScreen(
                            isDarkMode: widget.isDarkMode,
                            onDarkModeChanged: widget.onThemeChanged,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Skip & Continue'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Show login screen if not authenticated, otherwise show main screen
    if (!_isAuthenticated) {
      return LoginScreen(
        isDarkMode: widget.isDarkMode,
        onDarkModeChanged: widget.onThemeChanged,
      );
    }

    return GasMonitorScreen(
      isDarkMode: widget.isDarkMode,
      onDarkModeChanged: widget.onThemeChanged,
    );
  }
}

class SetupInstructions extends StatelessWidget {
  const SetupInstructions({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Setup Instructions:',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Go to your Supabase project dashboard\n'
              '2. Navigate to Settings → API\n'
              '3. Copy your Project URL and anon/public key\n'
              '4. Update lib/config/supabase_config.dart with your credentials\n'
              '5. Restart the app',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
