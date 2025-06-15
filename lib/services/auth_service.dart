import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  AuthService._();

  SupabaseClient get _client => Supabase.instance.client;
  static final Logger _logger = Logger();

  // Local user tracking
  Map<String, dynamic>? _currentLocalUser;

  /// Get current user (Supabase or local)
  User? get currentUser {
    if (_client.auth.currentUser != null) {
      return _client.auth.currentUser;
    }
    // Return null for local users since we can't create a Supabase User object
    return null;
  }

  /// Check if user is logged in (Supabase or local)
  bool get isLoggedIn => _client.auth.currentUser != null || _currentLocalUser != null;

  /// Get current user email (works for both Supabase and local)
  String? get currentUserEmail {
    if (_client.auth.currentUser != null) {
      return _client.auth.currentUser!.email;
    }
    return _currentLocalUser?['email'];
  }

  /// Initialize local user session on app start
  Future<void> initializeLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserJson = prefs.getString('current_local_user');
      if (currentUserJson != null) {
        _currentLocalUser = jsonDecode(currentUserJson);
        _logger.i('🔄 Local user session restored: ${_currentLocalUser!['email']}');
      }
    } catch (e) {
      _logger.e('❌ Failed to restore local session: $e');
    }
  }

  /// Sign in with email and password (checks both Supabase and local)
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Attempting to sign in user: $email');
      
      // First try Supabase login
      try {
        final response = await _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );

        if (response.user != null) {
          _logger.i('✅ Supabase login successful for user: ${response.user!.email}');
          _currentLocalUser = null; // Clear local user
          return AuthResult.success(
            user: response.user!,
            message: 'LOGIN SUCCESSFUL',
          );
        }
      } on AuthException catch (e) {
        _logger.w('❌ Supabase login failed: ${e.message}');
        // Continue to try local login
      }

      // If Supabase login fails, try local login
      _logger.i('🔄 Trying local authentication for: $email');
      return await _signInLocalUser(email, password);
      
    } catch (e) {
      _logger.e('❌ Unexpected error during login: $e');
      return AuthResult.failure(
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Sign in with local user credentials
  Future<AuthResult> _signInLocalUser(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingUsers = prefs.getStringList('local_users') ?? [];
      
      // Create password hash to compare
      final bytes = utf8.encode(password);
      final digest = sha256.convert(bytes);
      final hashedPassword = digest.toString();
      
      // Find matching user
      for (String userJson in existingUsers) {
        final userData = jsonDecode(userJson);
        if (userData['email'] == email.trim() && 
            userData['password_hash'] == hashedPassword) {
          
          // Set current local user
          _currentLocalUser = userData;
          await prefs.setString('current_local_user', userJson);
          
          _logger.i('✅ Local login successful for user: $email');
          return AuthResult.success(
            message: 'LOGIN SUCCESSFUL (Local Account)',
          );
        }
      }
      
      // No matching user found
      _logger.w('❌ Local login failed: Invalid credentials for $email');
      return AuthResult.failure(
        message: 'Invalid email or password. Please check your credentials.',
      );
      
    } catch (e) {
      _logger.e('❌ Error during local login: $e');
      return AuthResult.failure(
        message: 'Login failed. Please try again.',
      );
    }
  }

  /// Sign up with email and password - with local fallback
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Attempting to sign up user: $email');
      
      // Check if user already exists locally first
      final prefs = await SharedPreferences.getInstance();
      final existingUsers = prefs.getStringList('local_users') ?? [];
      for (String userJson in existingUsers) {
        final userData = jsonDecode(userJson);
        if (userData['email'] == email.trim()) {
          return AuthResult.failure(
            message: 'An account with this email already exists. Please try logging in instead.',
          );
        }
      }
      
      // First try Supabase registration
      try {
        // Check if user already exists in Supabase by trying to sign in
        try {
          final existingUserResponse = await _client.auth.signInWithPassword(
            email: email.trim(),
            password: password,
          );
          
          if (existingUserResponse.user != null) {
            return AuthResult.failure(
              message: 'An account with this email already exists in Supabase. Please try logging in instead.',
            );
          }
        } catch (e) {
          // User doesn't exist in Supabase, continue with registration
          _logger.d('User does not exist in Supabase, proceeding with registration');
        }
        
        // Try Supabase signup
        final response = await _client.auth.signUp(
          email: email.trim(),
          password: password,
        );

        // Handle successful signup
        if (response.user != null) {
          final user = response.user!;
          _logger.i('✅ Supabase signup successful for user: ${user.email}');
          
          return AuthResult.success(
            user: user,
            message: 'Account created successfully! You can now log in.',
          );
        }
        
        // If no user returned, try local fallback
        _logger.w('Supabase signup returned no user, trying local fallback');
        return await _createLocalUser(email, password);
        
      } on AuthException catch (e) {
        _logger.e('❌ Supabase auth exception: ${e.message}');
        
        // If it's a database error, try local fallback
        if (e.message.contains('Database error saving new user') || 
            e.message.contains('unexpected_failure')) {
          _logger.i('🔄 Supabase registration failed, using local fallback');
          return await _createLocalUser(email, password);
        }
        
        // For other auth errors, try local fallback
        _logger.i('🔄 Supabase registration failed, trying local fallback');
        return await _createLocalUser(email, password);
      }
      
    } catch (e) {
      _logger.e('❌ Unexpected error during signup: $e');
      
      // Try local fallback as last resort
      _logger.i('🔄 Unexpected error, trying local fallback');
      return await _createLocalUser(email, password);
    }
  }

  /// Create local user when Supabase fails
  Future<AuthResult> _createLocalUser(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if user already exists locally
      final existingUsers = prefs.getStringList('local_users') ?? [];
      for (String userJson in existingUsers) {
        final userData = jsonDecode(userJson);
        if (userData['email'] == email.trim()) {
          return AuthResult.failure(
            message: 'An account with this email already exists locally. Please try logging in.',
          );
        }
      }
      
      // Create password hash
      final bytes = utf8.encode(password);
      final digest = sha256.convert(bytes);
      final hashedPassword = digest.toString();
      
      // Create local user data
      final localUser = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'email': email.trim(),
        'password_hash': hashedPassword,
        'created_at': DateTime.now().toIso8601String(),
        'is_local': true,
      };
      
      // Save to local storage
      existingUsers.add(jsonEncode(localUser));
      await prefs.setStringList('local_users', existingUsers);
      
      _logger.i('✅ Local user created successfully: $email');
      
      return AuthResult.success(
        message: 'Account created successfully! You can now log in.',
      );
      
    } catch (e) {
      _logger.e('❌ Failed to create local user: $e');
      return AuthResult.failure(
        message: 'Registration failed. Please try again.',
      );
    }
  }

  /// Sign out current user (both Supabase and local)
  Future<void> signOut() async {
    try {
      _logger.i('Signing out current user');
      
      // Sign out from Supabase
      await _client.auth.signOut();
      
      // Clear local user session
      _currentLocalUser = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_local_user');
      
      _logger.i('✅ User signed out successfully');
    } catch (e) {
      _logger.e('❌ Error during sign out: $e');
      rethrow;
    }
  }

  /// Reset password
  Future<AuthResult> resetPassword({required String email}) async {
    try {
      _logger.i('Attempting password reset for: $email');
      
      await _client.auth.resetPasswordForEmail(email.trim());
      
      _logger.i('✅ Password reset email sent to: $email');
      return AuthResult.success(
        message: 'Password reset email sent. Please check your inbox.',
      );
    } on AuthException catch (e) {
      _logger.e('❌ Auth exception during password reset: ${e.message}');
      return AuthResult.failure(
        message: _getAuthErrorMessage(e),
      );
    } catch (e) {
      _logger.e('❌ Unexpected error during password reset: $e');
      return AuthResult.failure(
        message: 'Failed to send password reset email. Please try again.',
      );
    }
  }

  /// Get user-friendly error message from AuthException
  String _getAuthErrorMessage(AuthException e) {
    switch (e.message.toLowerCase()) {
      case 'invalid login credentials':
      case 'invalid email or password':
        return 'Invalid email or password. Please check your credentials.';
      case 'email not confirmed':
        return 'Please verify your email address before signing in.';
      case 'user not found':
        return 'No account found with this email address.';
      case 'wrong password':
        return 'Incorrect password. Please try again.';
      case 'email already registered':
      case 'user already registered':
      case 'email already exists':
      case 'user already exists':
      case 'email address already in use':
        return 'An account with this email already exists. Please use a different email or try logging in instead.';
      case 'weak password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid email':
        return 'Please enter a valid email address.';
      case 'too many requests':
        return 'Too many attempts. Please wait a moment before trying again.';
      case 'database error saving new user':
      case 'unexpected_failure':
        return 'Registration temporarily unavailable. Please try again in a few moments.';
      default:
        return e.message;
    }
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}

/// Result class for authentication operations
class AuthResult {
  final bool isSuccess;
  final String message;
  final User? user;

  AuthResult._({
    required this.isSuccess,
    required this.message,
    this.user,
  });

  factory AuthResult.success({String? message, User? user}) {
    return AuthResult._(
      isSuccess: true,
      message: message ?? 'Operation successful',
      user: user,
    );
  }

  factory AuthResult.failure({required String message}) {
    return AuthResult._(
      isSuccess: false,
      message: message,
    );
  }
} 