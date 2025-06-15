// Supabase Configuration
// Replace these values with your actual Supabase project credentials
class SupabaseConfig {
  // IMPORTANT: Replace these with your actual Supabase project credentials
  // You can find these in your Supabase project settings
  static const String supabaseUrl = 'https://zbtqfdifmvwyvabydbog.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpidHFmZGlmbXZ3eXZhYnlkYm9nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk2NDc3MTYsImV4cCI6MjA2NTIyMzcxNn0.2GX6D42jgxoCLo1H63viR8PE_LPOrtXgXcNzciNBE6s';

  // Example format:
  // static const String supabaseUrl = 'https://yourprojectid.supabase.co';
  // static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';

  // Validate configuration
  static bool get isConfigured {
    return supabaseUrl != 'YOUR_SUPABASE_URL_HERE' && 
           supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY_HERE' &&
           supabaseUrl.isNotEmpty && 
           supabaseAnonKey.isNotEmpty &&
           supabaseUrl.startsWith('https://') &&
           supabaseAnonKey.startsWith('eyJ');
  }
}
