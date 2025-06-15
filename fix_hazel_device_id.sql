-- FIX HAZEL'S KITCHEN DEVICE ID TO ESP32_002
-- Update the database to match the Arduino code which uses ESP32_002

-- First, check current status
SELECT 'BEFORE UPDATE - Current device records:' as status;
SELECT device_id, device_name, status, created_at 
FROM public.devices 
WHERE device_name = 'Hazel''s Kitchen' OR device_id IN ('ESP_002', 'ESP32_002');

-- Update the devices table
UPDATE public.devices 
SET device_id = 'ESP32_002'
WHERE device_id = 'ESP_002' AND device_name = 'Hazel''s Kitchen';

-- Update the device_connections table  
UPDATE public.device_connections 
SET device_id = 'ESP32_002'
WHERE device_id = 'ESP_002' AND device_name = 'Hazel''s Kitchen';

-- Verify the changes
SELECT 'AFTER UPDATE - Updated device records:' as status;
SELECT device_id, device_name, status, created_at 
FROM public.devices 
WHERE device_name = 'Hazel''s Kitchen' OR device_id IN ('ESP_002', 'ESP32_002');

-- Check if there are any recent gas sensor readings with ESP32_002
SELECT 'Recent gas readings for ESP32_002:' as status;
SELECT device_id, device_name, gas_level, created_at
FROM public.gas_sensor_readings 
WHERE device_id = 'ESP32_002' 
ORDER BY created_at DESC 
LIMIT 5;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Device ID updated successfully!';
    RAISE NOTICE 'Changed Hazel''s Kitchen from ESP_002 to ESP32_002';
    RAISE NOTICE 'Now matches the Arduino code device ID';
    RAISE NOTICE 'The app should now show Hazel''s Kitchen as ONLINE!';
END $$; 