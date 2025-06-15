#!/bin/bash

echo "🔧 IoT Gas Leak Monitor - Flutter Setup Script"
echo "=============================================="

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first:"
    echo "   https://docs.flutter.dev/get-started/install"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -n 1)"

# Check Flutter doctor
echo ""
echo "🔍 Running Flutter doctor..."
flutter doctor

# Install dependencies
echo ""
echo "📦 Installing Flutter dependencies..."
flutter pub get

# Check if Supabase is configured
if grep -q "YOUR_SUPABASE_URL_HERE" lib/config/supabase_config.dart; then
    echo ""
    echo "⚠️  CONFIGURATION REQUIRED"
    echo "=========================="
    echo "Please configure your Supabase credentials:"
    echo "1. Edit lib/config/supabase_config.dart"
    echo "2. Replace YOUR_SUPABASE_URL_HERE with your Supabase URL"
    echo "3. Replace YOUR_SUPABASE_ANON_KEY_HERE with your anon key"
    echo ""
    echo "Get your credentials from: https://supabase.com/dashboard"
    echo "Navigate to: Settings → API"
else
    echo "✅ Supabase configuration detected"
fi

echo ""
echo "🚀 Setup complete! To run the app:"
echo "   flutter run"
echo ""
echo "📱 Available commands:"
echo "   flutter run          - Run in debug mode"
echo "   flutter run --release - Run in release mode"
echo "   flutter build apk    - Build Android APK"
echo "   flutter build ios    - Build iOS app" 