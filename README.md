# IoT Gas Leak Monitoring System - Flutter Mobile App

A Flutter mobile application for real-time gas leak monitoring using Arduino sensors and Supabase backend. This MVP (Phase 1) focuses on displaying gas sensor data with a clean, responsive UI and real-time updates.

## Features

### Current MVP (Phase 1)
- **Real-time Gas Level Display**: Shows current gas readings with color-coded alerts
- **Recent Readings History**: Displays the last 10 sensor readings
- **Live Updates**: Real-time data synchronization using Supabase subscriptions
- **Responsive UI**: Mobile-first design that adapts to different screen sizes
- **Error Handling**: Graceful handling of connection issues and loading states
- **Offline Fallback**: Periodic refresh as backup to real-time subscriptions

### Gas Level Classifications
- 🟢 **SAFE**: Normal gas levels (Green)
- 🟠 **LOW**: Minor gas detection (Orange)
- 🔶 **MEDIUM**: Moderate gas levels (Deep Orange)
- 🔴 **HIGH**: Dangerous gas levels (Red)
- 🟣 **CRITICAL**: Emergency levels (Purple)

## Setup Instructions

### Prerequisites
- Flutter SDK (version 3.8.1 or higher)
- Dart SDK
- Android Studio / Xcode (for device deployment)
- Active Supabase project with gas sensor data

### 1. Clone and Install Dependencies

```bash
# Clone the repository
git clone <your-repository-url>
cd breadwinners_mobile

# Install Flutter dependencies
flutter pub get
```

### 2. Supabase Configuration

#### Step 2.1: Get Supabase Credentials
1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Navigate to **Settings** → **API**
4. Copy the following:
   - **Project URL** (e.g., `https://yourprojectid.supabase.co`)
   - **anon/public key** (starts with `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`)

#### Step 2.2: Update Configuration
Edit `lib/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://yourprojectid.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
}
```

### 3. Database Schema

Ensure your Supabase database has the following tables:

```sql
-- Device table
CREATE TABLE public.device (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  device_name text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT device_pkey PRIMARY KEY (id)
);

-- Gas sensor reading table
CREATE TABLE public.gas_sensor_reading (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  gas_value integer NOT NULL,
  gas_level text NOT NULL,
  timestamp timestamp with time zone NOT NULL,
  device_id uuid,
  device_name text,
  CONSTRAINT gas_sensor_reading_pkey PRIMARY KEY (id),
  CONSTRAINT gas_sensor_reading_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.device(id)
);

-- Enable RLS (Row Level Security) if needed
ALTER TABLE public.gas_sensor_reading ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device ENABLE ROW LEVEL SECURITY;

-- Create policies for read access (adjust as needed)
CREATE POLICY "Enable read access for all users" ON public.gas_sensor_reading FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON public.device FOR SELECT USING (true);
```

### 4. Run the Application

```bash
# Run on connected device or emulator
flutter run

# Or build for release
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

## Project Structure

```
lib/
├── config/
│   └── supabase_config.dart      # Supabase credentials configuration
├── models/
│   └── gas_sensor_reading.dart   # Data model for gas readings
├── services/
│   └── supabase_service.dart     # Database service layer
├── screens/
│   └── gas_monitor_screen.dart   # Main monitoring interface
└── main.dart                     # App entry point
```

## Key Components

### 1. `SupabaseService`
- Handles all database operations
- Provides real-time subscriptions
- Includes error handling and retry logic

### 2. `GasSensorReading` Model
- Represents gas sensor data structure
- Includes helper methods for UI (colors, icons)
- Handles JSON serialization/deserialization

### 3. `GasMonitorScreen`
- Main UI displaying current and recent readings
- Real-time updates with fallback polling
- Responsive design with pull-to-refresh

## Troubleshooting

### Common Issues

#### 1. "Supabase not configured" Error
- Ensure you've updated `lib/config/supabase_config.dart` with valid credentials
- Check that your Supabase URL and anon key are correct

#### 2. No Data Appearing
- Verify your Arduino is sending data to Supabase
- Check Supabase table name matches (`gas_sensor_reading`)
- Ensure RLS policies allow read access

#### 3. Real-time Updates Not Working
- Verify your Supabase project has real-time enabled
- Check network connectivity
- The app includes fallback polling every 30 seconds

#### 4. Build Issues
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

## Future Phases (Roadmap)

### Phase 2: Notification System
- Push notifications for gas level alerts
- Customizable threshold settings
- Emergency contact integration

### Phase 3: Historical Data Visualization
- Charts and graphs for trend analysis
- Export data functionality
- Statistical analysis

### Phase 4: User Authentication & Multi-Device
- User accounts and authentication
- Multiple device management
- Device sharing and permissions

## Dependencies

- `supabase_flutter: ^2.3.4` - Supabase client for Flutter
- `intl: ^0.19.0` - Internationalization and date formatting

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Check the troubleshooting section above
- Review Supabase documentation: https://supabase.com/docs
- Flutter documentation: https://flutter.dev/docs
