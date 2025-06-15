import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/gas_sensor_reading.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GasNotificationService {
  static final GasNotificationService _instance = GasNotificationService._internal();
  static GasNotificationService get instance => _instance;
  GasNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final SupabaseService _supabase = SupabaseService.instance;
  
  bool _isInitialized = false;
  bool _isMonitoring = false;
  RealtimeChannel? _subscription;
  Timer? _periodicChecker;
  
  // BULLETPROOF state tracking - device name -> current alert level
  final Map<String, String> _deviceCurrentLevel = {};

  /// Initialize notification service with automatic permissions
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      if (kDebugMode) print('🔔 INITIALIZING BULLETPROOF GAS NOTIFICATION SERVICE...');
      
      // 🔐 AUTHENTICATION CHECK: Only initialize if user is authenticated
      if (!AuthService.instance.isLoggedIn) {
        if (kDebugMode) print('🔒 INIT BLOCKED: User not authenticated - notifications will wait for login');
        return false;
      }
      
      // Initialize notification channels
      await _initializeNotifications();
      
      _isInitialized = true;
      if (kDebugMode) print('✅ BULLETPROOF GAS NOTIFICATION SERVICE READY');
      
      // Auto-start monitoring immediately
      await startMonitoring();
      
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Notification service failed: $e');
      return false;
    }
  }

  /// Initialize notification channels
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notifications.initialize(initSettings);
    
    // Create critical gas alert channel
    const channel = AndroidNotificationChannel(
      'gas_alerts',
      'Gas Leak Alerts',
      description: 'Critical gas leak notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );
    
    await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Process gas reading with BULLETPROOF duplicate prevention
  void _processGasReading(GasSensorReading reading) async {
    final startTime = DateTime.now();
    
    // 🔐 AUTHENTICATION GATE: Block notifications if user is not logged in
    if (!AuthService.instance.isLoggedIn) {
      if (kDebugMode) print('🔒 BLOCKED: User not authenticated - no notifications until login');
      return;
    }
    
    // Skip test devices immediately
    if (_isTestDevice(reading.deviceName)) return;
    
    final currentGasLevel = reading.gasValue;
    final currentAlertLevel = _getAlertLevel(currentGasLevel);
    final deviceName = reading.deviceName;
    
    // ENHANCED debugging - show current state tracking
    final previousLevel = _deviceCurrentLevel[deviceName];
    if (kDebugMode) print('🔄 PROCESSING: $currentGasLevel PPM from $deviceName - Level: $currentAlertLevel | Previous: $previousLevel');
    
    // Get the last known level for this device - IMPORTANT: Only default to SAFE if NO previous state exists
    final lastAlertLevel = _deviceCurrentLevel[deviceName] ?? 'SAFE';
    
    // RULE 1: SAFE THRESHOLD - Update state but DON'T clear existing notifications
    if (currentGasLevel <= 100) {
      // ALWAYS update state to SAFE, regardless of previous state
      _deviceCurrentLevel[deviceName] = 'SAFE';
      if (kDebugMode) print('✅ SAFE LEVEL: $currentGasLevel PPM ≤ 100 - State updated to SAFE, NO new notifications (existing ones stay)');
      return; // Exit immediately - NO new notifications for safe levels
    }
    
    // RULE 2: BULLETPROOF DUPLICATE PREVENTION - Only notify on REAL level changes
    if (currentAlertLevel == lastAlertLevel) {
      if (kDebugMode) print('⏭️ DUPLICATE BLOCKED: $currentAlertLevel = $lastAlertLevel (NO notification sent)');
      return; // Exit immediately - NO notification for same level
    }
    
    // ALLOWED: Level has ACTUALLY changed - send notification
    if (kDebugMode) print('🚨 REAL LEVEL CHANGE: $lastAlertLevel → $currentAlertLevel - SENDING NOTIFICATION');
    
    // Update state BEFORE sending notification to prevent race conditions
    _deviceCurrentLevel[deviceName] = currentAlertLevel;
    
    // INSTANT notification - no delays
    await _sendGasAlertInstant(reading);
    
    final endTime = DateTime.now();
    final processingTime = endTime.difference(startTime);
    if (kDebugMode) print('⚡ NOTIFICATION SENT in ${processingTime.inMilliseconds}ms | State: ${_deviceCurrentLevel[deviceName]}');
  }

  /// Cancel ALL notifications (only used when stopping monitoring)
  Future<void> _cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      if (kDebugMode) print('🛑 ALL notifications cancelled');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to cancel notifications: $e');
    }
  }

  /// Send gas alert notification with SIMPLIFIED content (no PPM values)
  Future<void> _sendGasAlertInstant(GasSensorReading reading) async {
    final ppm = reading.gasValue;
    final alertLevel = _getAlertLevel(ppm);
    
    // CONSISTENT notification IDs for each alert level (prevents spam)
    int notificationId;
    String title, body;
    Color? color;
    bool isOngoing;
    bool fullScreen;
    
    if (ppm >= 601) { // CRITICAL: 601-1000
      notificationId = 1; // Always ID 1 for CRITICAL
      title = '🚨 CRITICAL: Gas Leak!';
      body = ' Leave the area immediately and contact trained professionals for assistance.';
      color = const Color(0xFFFF0000); // Red
      isOngoing = true;
      fullScreen = true;
    } else if (ppm >= 301) { // DANGER: 301-600
      notificationId = 2; // Always ID 2 for DANGER
      title = '⚠️ DANGER: High Gas Level!';
      body = 'High levels of gas have been detected. Please investigate the source of the gas and ensure safety protocols.';
      color = const Color(0xFFFF5722); // Orange-Red
      isOngoing = false;
      fullScreen = false;
    } else { // WARNING: 101-300
      notificationId = 3; // Always ID 3 for WARNING
      title = '⚠️ WARNING: Gas Detected!';
      body = 'Gas has been detected. Please monitor the area and keep it well ventilated.';
      color = const Color(0xFFFF9800); // Orange
      isOngoing = false;
      fullScreen = false;
    }

    try {
      // SIMPLIFIED notification - NO PPM values, NO device names
      await _notifications.show(
        notificationId, // Consistent ID per alert level
        title,
        body, // Clean message without PPM values
        NotificationDetails(
          android: AndroidNotificationDetails(
            'gas_alerts',
            'Gas Leak Alerts',
            channelDescription: 'Critical gas leak notifications',
            importance: Importance.max, // MAXIMUM urgency
            priority: Priority.max,     // MAXIMUM priority
            category: AndroidNotificationCategory.alarm,
            autoCancel: false, // Keep visible
            ongoing: isOngoing, // Only CRITICAL stays ongoing
            showWhen: true,
            when: DateTime.now().millisecondsSinceEpoch,
            enableVibration: true,
            enableLights: true,
            playSound: true,
            icon: '@drawable/ic_notification',
            color: color,
            visibility: NotificationVisibility.public,
            fullScreenIntent: fullScreen, // Only CRITICAL full screen
            styleInformation: BigTextStyleInformation(
              body, // Clean body without PPM
              htmlFormatBigText: true,
              contentTitle: title,
              htmlFormatContentTitle: true,
              summaryText: 'REAL-TIME Gas Alert',
              htmlFormatSummaryText: true,
            ),
            ticker: 'Gas Alert: $alertLevel',
          ),
        ),
      );
      
      if (kDebugMode) print('🔔 SIMPLIFIED NOTIFICATION SENT: $alertLevel (ID: $notificationId) - NO PPM spam');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to send notification: $e');
    }
  }

  /// Check LATEST readings (one per device) to prevent duplicate processing
  Future<void> _checkCurrentDangerousLevels() async {
    try {
      final recentReadings = await _supabase.getRecentReadingsFiltered(limit: 20);
      
      // Group by device name and get only the LATEST reading per device
      final Map<String, GasSensorReading> latestReadings = {};
      for (final reading in recentReadings) {
        if (!_isTestDevice(reading.deviceName)) {
          // Keep only the most recent reading per device
          final deviceName = reading.deviceName;
          if (!latestReadings.containsKey(deviceName) || 
              reading.createdAt.isAfter(latestReadings[deviceName]!.createdAt)) {
            latestReadings[deviceName] = reading;
          }
        }
      }
      
      // Process only ONE reading per device (the latest)
      for (final reading in latestReadings.values) {
        if (kDebugMode) print('🔍 Processing LATEST reading: ${reading.gasValue} PPM from ${reading.deviceName}');
        _processGasReading(reading);
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error checking current levels: $e');
    }
  }

  /// Start monitoring gas readings with INSTANT notifications
  Future<bool> startMonitoring() async {
    if (!_isInitialized) await initialize();
    if (_isMonitoring) return true;

    try {
      // Subscribe to real-time gas readings with IMMEDIATE processing
      _subscription = _supabase.subscribeToReadings(
        onInsert: (reading) {
          // INSTANT processing - no delays
          if (kDebugMode) print('⚡ INSTANT INSERT: ${reading.gasValue} PPM from ${reading.deviceName}');
          _processGasReading(reading);
        },
        onUpdate: (reading) {
          // INSTANT processing - no delays
          if (kDebugMode) print('⚡ INSTANT UPDATE: ${reading.gasValue} PPM from ${reading.deviceName}');
          _processGasReading(reading);
        },
      );

      _isMonitoring = true;
      
      // Check current dangerous readings immediately
      await _checkCurrentDangerousLevels();
      
      // Start FASTER periodic checks every 500ms for maximum responsiveness
      _startFastPeriodicChecks();
      
      if (kDebugMode) print('✅ REAL-TIME gas monitoring started with BULLETPROOF duplicate prevention');
      
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to start monitoring: $e');
      return false;
    }
  }

  /// Start FAST periodic checks for maximum real-time performance
  void _startFastPeriodicChecks() {
    _periodicChecker = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!_isMonitoring) {
        timer.cancel();
        return;
      }
      // Fast checks for any missed updates
      await _checkCurrentDangerousLevels();
    });
  }

  /// Check if device name is a test device
  bool _isTestDevice(String deviceName) {
    final name = deviceName.toLowerCase();
    return name.contains('test') || 
           name.contains('demo') || 
           name.contains('sample') ||
           name.startsWith('test_') ||
           name.startsWith('demo_') ||
           name.startsWith('notification_');
  }

  /// Get alert level based on PPM - EXACT thresholds per user specification
  String _getAlertLevel(int ppm) {
    if (ppm <= 100) return 'SAFE';        // SAFE: ≤100
    if (ppm <= 300) return 'WARNING';     // WARNING: 101-300
    if (ppm <= 600) return 'DANGER';      // DANGER: 301-600
    return 'CRITICAL';                    // CRITICAL: 601-1000
  }

  /// Stop monitoring
  void stopMonitoring() {
    if (_subscription != null) {
      _supabase.unsubscribe(_subscription!);
      _subscription = null;
    }
    _periodicChecker?.cancel();
    _periodicChecker = null;
    _isMonitoring = false;
    _deviceCurrentLevel.clear();
    if (kDebugMode) print('🛑 Gas monitoring stopped');
  }

  /// 🔐 RESTART NOTIFICATIONS after user login
  Future<bool> restartAfterLogin() async {
    if (kDebugMode) print('🔐 RESTARTING NOTIFICATIONS: User authenticated - enabling gas alerts');
    
    // Reset initialization flag to allow restart
    _isInitialized = false;
    _isMonitoring = false;
    
    // Clear any previous state
    _deviceCurrentLevel.clear();
    
    // Initialize and start monitoring
    final success = await initialize();
    if (success) {
      if (kDebugMode) print('✅ NOTIFICATIONS ENABLED: Gas alerts now active for authenticated user');
    } else {
      if (kDebugMode) print('❌ NOTIFICATION RESTART FAILED');
    }
    
    return success;
  }

  /// Get monitoring status
  bool get isMonitoring => _isMonitoring;
  bool get isInitialized => _isInitialized;
} 