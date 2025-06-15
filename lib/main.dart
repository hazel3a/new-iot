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

class GasLeakMonitorApp extends StatelessWidget {
  const GasLeakMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gas Leak Monitor',
      theme: _darkTheme,
      home: const AppInitializer(),
      debugShowCheckedModeBanner: false,
    );
  }

  // Bankout-inspired dark theme with exact color system
  ThemeData get _darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF000000), // Pure black background like Bankout
    colorScheme: const ColorScheme.dark(
      background: Color(0xFF000000),
      surface: Color(0xFF1A1A1A), // Dark surface
      primary: Color(0xFF34BB8B), // Exact Bankout mint green
      secondary: Color(0xFF34BBAB), // Bankout secondary mint
      tertiary: Color(0xFFF87171), // Soft red for alerts
      onBackground: Color(0xFFFFFFFF),
      onSurface: Color(0xFFFFFFFF),
      onPrimary: Color(0xFF000000),
      error: Color(0xFFF87171),
      onError: Color(0xFFFFFFFF),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF000000),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'SF Pro Display',
      ),
      iconTheme: IconThemeData(color: Color(0xFF34BB8B)),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.bold,
        color: Color(0xFFFFFFFF),
      ),
      displayMedium: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.bold,
        color: Color(0xFFFFFFFF),
      ),
      displaySmall: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        color: Color(0xFFFFFFFF),
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.bold,
        color: Color(0xFFFFFFFF),
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        color: Color(0xFFFFFFFF),
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        color: Color(0xFFFFFFFF),
      ),
      titleLarge: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        color: Color(0xFFFFFFFF),
      ),
      titleMedium: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
        color: Color(0xFFFFFFFF),
      ),
      titleSmall: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
        color: Color(0xFFE5E7EB),
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        color: Color(0xFFE5E7EB),
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        color: Color(0xFFE5E7EB),
      ),
      bodySmall: TextStyle(
        fontFamily: 'Inter',
        color: Color(0xFF9CA3AF),
      ),
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
        color: Color(0xFFFFFFFF),
      ),
      labelMedium: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
        color: Color(0xFFE5E7EB),
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        color: Color(0xFF9CA3AF),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF111827),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      shadowColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF34BB8B),
        foregroundColor: const Color(0xFF000000),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF34BB8B),
        side: const BorderSide(color: Color(0xFF34BB8B), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF34BB8B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF111827),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF374151)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF374151)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF34BB8B), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFF87171), width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFF87171), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      hintStyle: const TextStyle(
        color: Color(0xFF6B7280),
        fontFamily: 'Inter',
      ),
      labelStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontFamily: 'Inter',
      ),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFF34BB8B),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF374151),
      thickness: 1,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF111827),
      selectedItemColor: Color(0xFF34BB8B),
      unselectedItemColor: Color(0xFF6B7280),
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
  );
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

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
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          title: const Text('Gas Leak Monitor'),
          backgroundColor: Colors.transparent,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF4ADE80)),
                onPressed: () {
                  // Add refresh functionality here
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.settings, color: Color(0xFF4ADE80)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.security,
                    size: 64,
                    color: Color(0xFF4ADE80),
                  ),
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 24),
                Text(
                  'Initializing Gas Leak Monitor...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFE5E7EB),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Setting up secure connections and notifications',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9CA3AF),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_initError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          title: const Text('Configuration Error'),
          backgroundColor: Colors.transparent,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 64,
                  color: const Color(0xFFF87171),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Configuration Required',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFFFFF),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF87171).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  _initError!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SetupInstructions(),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isInitializing = true;
                          _initError = null;
                        });
                        _initializeApp();
                      },
                      child: const Text('Retry'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Navigate to test screen
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GasMonitorScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFF87171)),
                        foregroundColor: const Color(0xFFF87171),
                      ),
                      child: const Text('Skip & Continue'),
                    ),
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
      return const LoginScreen();
    }

    return const GasMonitorScreen();
  }
}

class SetupInstructions extends StatelessWidget {
  const SetupInstructions({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF374151),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFF4ADE80),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Setup Instructions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(5, (index) {
            final instructions = [
              'Go to your Supabase project dashboard',
              'Navigate to Settings → API',
              'Copy your Project URL and anon/public key',
              'Update lib/config/supabase_config.dart with your credentials',
              'Restart the app',
            ];
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Color(0xFF0F0F0F),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      instructions[index],
                      style: const TextStyle(
                        color: Color(0xFFE5E7EB),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
