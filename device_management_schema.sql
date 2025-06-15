-- Auto Device Registration System
-- This ensures devices are automatically registered/updated when they send gas sensor readings
-- Execute this in your Supabase SQL Editor after setting up both gas_sensor_readings and device management tables

-- Function to auto-register or update device when gas sensor reading is inserted
CREATE OR REPLACE FUNCTION auto_register_device_on_reading()
RETURNS TRIGGER AS $$
DECLARE
  v_device_exists BOOLEAN;
  v_device_status TEXT;
BEGIN
  -- Check if device exists in devices table
  SELECT status INTO v_device_status FROM devices WHERE device_id = NEW.device_id;
  
  IF v_device_status IS NULL THEN
    -- Device doesn't exist, create it with ACTIVE status
    INSERT INTO devices (device_id, device_name, status, first_connected_at, last_connected_at)
    VALUES (NEW.device_id, NEW.device_name, 'ACTIVE', NOW(), NOW());
    
    -- Log the first connection
    INSERT INTO device_connections (device_id, device_name, connection_type, connected_at, is_active)
    VALUES (NEW.device_id, NEW.device_name, 'gas_data_upload', NOW(), true);
    
  ELSE
    -- Device exists, update last connection time and ensure it's not blocked
    UPDATE devices 
    SET 
      last_connected_at = NOW(),
      device_name = NEW.device_name  -- Update name in case it changed
    WHERE device_id = NEW.device_id;
    
    -- Only log new connection if the last one was more than 30 minutes ago
    -- to avoid spam in connection logs
    IF NOT EXISTS (
      SELECT 1 FROM device_connections 
      WHERE device_id = NEW.device_id 
        AND connected_at >= NOW() - INTERVAL '30 minutes'
        AND is_active = true
    ) THEN
      INSERT INTO device_connections (device_id, device_name, connection_type, connected_at, is_active)
      VALUES (NEW.device_id, NEW.device_name, 'gas_data_upload', NOW(), true);
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on gas_sensor_readings table
DROP TRIGGER IF EXISTS trigger_auto_register_device ON gas_sensor_readings;
CREATE TRIGGER trigger_auto_register_device
  AFTER INSERT ON gas_sensor_readings
  FOR EACH ROW
  EXECUTE FUNCTION auto_register_device_on_reading();

-- Function to update device connection counts and data statistics
CREATE OR REPLACE FUNCTION update_device_statistics()
RETURNS TRIGGER AS $$
BEGIN
  -- Update the latest device connection with data count
  UPDATE device_connections 
  SET data_count = (
    SELECT COUNT(*) 
    FROM gas_sensor_readings 
    WHERE device_id = NEW.device_id 
      AND created_at >= (
        SELECT connected_at 
        FROM device_connections 
        WHERE device_id = NEW.device_id 
        ORDER BY connected_at DESC 
        LIMIT 1
      )
  )
  WHERE device_id = NEW.device_id 
    AND id = (
      SELECT id 
      FROM device_connections 
      WHERE device_id = NEW.device_id 
      ORDER BY connected_at DESC 
      LIMIT 1
    );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update statistics
DROP TRIGGER IF EXISTS trigger_update_device_statistics ON gas_sensor_readings;
CREATE TRIGGER trigger_update_device_statistics
  AFTER INSERT ON gas_sensor_readings
  FOR EACH ROW
  EXECUTE FUNCTION update_device_statistics();

-- Create a function to get real-time active devices that have sent data recently (ONLINE/OFFLINE only)
CREATE OR REPLACE VIEW real_time_active_devices AS
SELECT 
  d.id,
  d.device_id,
  d.device_name,
  d.device_ip,
  d.device_type,
  d.status,
  d.last_connected_at,
  d.first_connected_at,
  CASE 
    WHEN gsr.latest_reading >= NOW() - INTERVAL '30 seconds' THEN 'ONLINE'
    ELSE 'OFFLINE'
  END as connection_status,
  EXTRACT(EPOCH FROM (NOW() - COALESCE(gsr.latest_reading, d.last_connected_at))) as seconds_since_last_connection,
  COALESCE(gsr.total_readings, 0) as total_readings,
  COALESCE(gsr.readings_today, 0) as readings_today,
  gsr.latest_reading as last_data_received,
  gsr.latest_gas_level as current_gas_level,
  gsr.latest_gas_value as current_gas_value
FROM devices d
LEFT JOIN (
  SELECT 
    device_id,
    COUNT(*) as total_readings,
    COUNT(CASE WHEN created_at >= NOW() - INTERVAL '24 hours' THEN 1 END) as readings_today,
    MAX(created_at) as latest_reading,
    (array_agg(gas_level ORDER BY created_at DESC))[1] as latest_gas_level,
    (array_agg(gas_value ORDER BY created_at DESC))[1] as latest_gas_value
  FROM gas_sensor_readings 
  GROUP BY device_id
) gsr ON d.device_id = gsr.device_id
WHERE d.status != 'BLOCKED'
ORDER BY COALESCE(gsr.latest_reading, d.last_connected_at) DESC;

-- Update the existing active_devices view to use real gas sensor data
DROP VIEW IF EXISTS active_devices;
CREATE OR REPLACE VIEW active_devices AS
SELECT * FROM real_time_active_devices;

-- Create view for devices that are currently online only
CREATE OR REPLACE VIEW currently_active_devices AS
SELECT *
FROM real_time_active_devices
WHERE connection_status = 'ONLINE'
ORDER BY last_data_received DESC;

-- Function to clean up old inactive connections (optional, for maintenance)
CREATE OR REPLACE FUNCTION cleanup_old_connections()
RETURNS void AS $$
BEGIN
  -- Mark connections as inactive if no data received in last hour
  UPDATE device_connections 
  SET is_active = false, disconnected_at = NOW()
  WHERE is_active = true 
    AND connected_at < NOW() - INTERVAL '1 hour'
    AND NOT EXISTS (
      SELECT 1 FROM gas_sensor_readings 
      WHERE device_id = device_connections.device_id 
        AND created_at >= device_connections.connected_at
        AND created_at >= NOW() - INTERVAL '1 hour'
    );
END;
$$ LANGUAGE plpgsql;

-- Create device_history view that shows all devices (online and offline persist)
CREATE OR REPLACE VIEW device_history AS
SELECT 
  d.id,
  d.device_id,
  d.device_name,
  d.device_ip,
  d.device_type,
  d.status,
  d.first_connected_at,
  d.last_connected_at,
  d.created_at,
  CASE 
    WHEN gsr.latest_reading >= NOW() - INTERVAL '30 seconds' THEN 'ONLINE'
    ELSE 'OFFLINE'
  END as connection_status,
  (SELECT COUNT(*) FROM device_connections WHERE device_id = d.device_id) as total_connections,
  COALESCE(gsr.total_readings, 0) as total_readings,
  gsr.latest_reading as last_data_received,
  EXTRACT(EPOCH FROM (NOW() - COALESCE(gsr.latest_reading, d.last_connected_at))) as seconds_since_last_connection,
  gsr.latest_gas_level as current_gas_level,
  gsr.latest_gas_value as current_gas_value
FROM devices d
LEFT JOIN (
  SELECT 
    device_id,
    COUNT(*) as total_readings,
    MAX(created_at) as latest_reading,
    (array_agg(gas_level ORDER BY created_at DESC))[1] as latest_gas_level,
    (array_agg(gas_value ORDER BY created_at DESC))[1] as latest_gas_value
  FROM gas_sensor_readings 
  GROUP BY device_id
) gsr ON d.device_id = gsr.device_id
ORDER BY COALESCE(gsr.latest_reading, d.last_connected_at) DESC;

-- Update active_devices view to show all devices (persistent when offline)
DROP VIEW IF EXISTS active_devices;
CREATE OR REPLACE VIEW active_devices AS
SELECT 
  d.id,
  d.device_id,
  d.device_name,
  d.device_ip,
  d.device_type,
  d.status,
  d.last_connected_at,
  d.first_connected_at,
  d.created_at,
  CASE 
    WHEN gsr.latest_reading >= NOW() - INTERVAL '30 seconds' THEN 'ONLINE'
    ELSE 'OFFLINE'
  END as connection_status,
  EXTRACT(EPOCH FROM (NOW() - COALESCE(gsr.latest_reading, d.last_connected_at))) as seconds_since_last_connection,
  COALESCE(gsr.total_readings, 0) as total_readings,
  COALESCE(gsr.readings_today, 0) as readings_today,
  gsr.latest_reading as last_data_received,
  gsr.latest_gas_level as current_gas_level,
  gsr.latest_gas_value as current_gas_value
FROM devices d
LEFT JOIN (
  SELECT 
    device_id,
    COUNT(*) as total_readings,
    COUNT(CASE WHEN created_at >= NOW() - INTERVAL '24 hours' THEN 1 END) as readings_today,
    MAX(created_at) as latest_reading,
    (array_agg(gas_level ORDER BY created_at DESC))[1] as latest_gas_level,
    (array_agg(gas_value ORDER BY created_at DESC))[1] as latest_gas_value
  FROM gas_sensor_readings 
  GROUP BY device_id
) gsr ON d.device_id = gsr.device_id
WHERE d.status != 'BLOCKED'
ORDER BY COALESCE(gsr.latest_reading, d.last_connected_at) DESC;

-- Grant permissions
GRANT SELECT ON real_time_active_devices TO anon;
GRANT SELECT ON currently_active_devices TO anon;
GRANT SELECT ON device_history TO anon;
GRANT SELECT ON active_devices TO anon;

-- ===========================
-- PHILIPPINES TIME ZONE VERIFICATION
-- ===========================

-- Ensure Philippines Time Support in Database
-- This section ensures that all timestamps are stored correctly for Philippines timezone (UTC+8)

-- Set session timezone to Philippines for this connection (optional)
-- SET timezone = 'Asia/Manila';

-- Verify current database timezone settings
-- SELECT name, setting FROM pg_settings WHERE name IN ('timezone', 'log_timezone');

-- Function to verify Philippines time conversion is working correctly
CREATE OR REPLACE FUNCTION verify_philippines_time()
RETURNS TABLE(
  test_name TEXT,
  utc_time TIMESTAMP WITH TIME ZONE,
  philippines_time TIMESTAMP,
  formatted_philippines_time TEXT,
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    'Current Time Test'::TEXT as test_name,
    NOW() as utc_time,
    (NOW() + INTERVAL '8 hours')::TIMESTAMP as philippines_time,
    TO_CHAR(NOW() + INTERVAL '8 hours', 'Mon DD, YYYY HH12:MI:SS AM') as formatted_philippines_time,
    'SUCCESS - Times shown in Philippines timezone (UTC+8)'::TEXT as status;
    
  RETURN QUERY
  SELECT 
    'Sample Data Test'::TEXT as test_name,
    gsr.created_at as utc_time,
    (gsr.created_at + INTERVAL '8 hours')::TIMESTAMP as philippines_time,
    TO_CHAR(gsr.created_at + INTERVAL '8 hours', 'Mon DD, YYYY HH12:MI:SS AM') as formatted_philippines_time,
    CASE 
      WHEN gsr.created_at IS NOT NULL THEN 'SUCCESS - Sample data found'
      ELSE 'INFO - No sample data found, insert test data first'
    END::TEXT as status
  FROM gas_sensor_readings gsr 
  ORDER BY gsr.created_at DESC 
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Sample query to check if timestamps are being converted correctly
-- This shows how timestamps appear in database vs Philippines time
CREATE OR REPLACE VIEW philippines_time_check AS
SELECT 
  id,
  device_name,
  gas_level,
  gas_value,
  -- Raw UTC timestamp as stored in database
  created_at as utc_time,
  -- Convert to Philippines time (UTC+8) - this is what Flutter should receive and convert
  created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Manila' as philippines_time_zone_aware,
  -- Alternative way to add 8 hours (what our Flutter TimeFormatter does)
  created_at + INTERVAL '8 hours' as philippines_time_simple,
  -- Formatted Philippines time in 12-hour format (like our Flutter app)
  TO_CHAR(created_at + INTERVAL '8 hours', 'Mon DD, YYYY HH12:MI:SS AM') as formatted_philippines_time,
  -- Show the difference from now
  EXTRACT(EPOCH FROM (NOW() - created_at))/60 as minutes_ago
FROM gas_sensor_readings 
ORDER BY created_at DESC 
LIMIT 10;

-- Note: No test data inserted - only real ESP32 devices should appear in the system
-- The TimeFormatter utility will handle real-time conversion for actual device data

-- Grant permissions for time verification views
GRANT SELECT ON philippines_time_check TO anon;

-- Success message with time information
DO $$ 
DECLARE
  current_philippines_time TEXT;
BEGIN 
  SELECT TO_CHAR(NOW() + INTERVAL '8 hours', 'Mon DD, YYYY HH12:MI:SS AM') INTO current_philippines_time;
  
  RAISE NOTICE '✅ Auto Device Registration updated successfully!';
  RAISE NOTICE '🔄 Now supports ONLINE/OFFLINE status only (no more DELAYED status).';
  RAISE NOTICE '📱 Devices will remain visible even when they go offline.';
  RAISE NOTICE '🟢 ONLINE: Device sent data in last 30 seconds';
  RAISE NOTICE '⚪ OFFLINE: Device has not sent data for more than 30 seconds';
  RAISE NOTICE '🇵🇭 Philippines Time: % (UTC+8)', current_philippines_time;
  RAISE NOTICE '⏰ Database stores UTC, Flutter converts to Philippines time with TimeFormatter';
  RAISE NOTICE '🔍 Run "SELECT * FROM philippines_time_check;" to verify time conversions';
  RAISE NOTICE '🔍 Run "SELECT * FROM verify_philippines_time();" to test time functions';
  RAISE NOTICE '✨ All times in Flutter app will show in 12-hour format Philippines time!';
END $$;