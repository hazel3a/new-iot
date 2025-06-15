@echo off
echo 🔧 IoT Gas Leak Monitor - Flutter Setup Script
echo ==============================================

REM Check if Flutter is installed
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Flutter is not installed. Please install Flutter first:
    echo    https://docs.flutter.dev/get-started/install
    pause
    exit /b 1
)

flutter --version | findstr /C:"Flutter"
echo ✅ Flutter found

REM Check Flutter doctor
echo.
echo 🔍 Running Flutter doctor...
flutter doctor

REM Install dependencies
echo.
echo 📦 Installing Flutter dependencies...
flutter pub get

REM Check if Supabase is configured
findstr /C:"YOUR_SUPABASE_URL_HERE" lib\config\supabase_config.dart >nul 2>&1
if not errorlevel 1 (
    echo.
    echo ⚠️  CONFIGURATION REQUIRED
    echo ==========================
    echo Please configure your Supabase credentials:
    echo 1. Edit lib\config\supabase_config.dart
    echo 2. Replace YOUR_SUPABASE_URL_HERE with your Supabase URL
    echo 3. Replace YOUR_SUPABASE_ANON_KEY_HERE with your anon key
    echo.
    echo Get your credentials from: https://supabase.com/dashboard
    echo Navigate to: Settings → API
) else (
    echo ✅ Supabase configuration detected
)

echo.
echo 🚀 Setup complete! To run the app:
echo    flutter run
echo.
echo 📱 Available commands:
echo    flutter run          - Run in debug mode
echo    flutter run --release - Run in release mode
echo    flutter build apk    - Build Android APK
echo    flutter build ios    - Build iOS app
echo.
pause 