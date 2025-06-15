-- RESTORE DEVICES SQL SCRIPT
-- This script restores the wiped out devices to the database
-- Run this in your Supabase SQL Editor

-- Insert the 3 specified devices into the devices table
INSERT INTO public.devices (
    device_id, 
    device_name, 
    device_type, 
    status, 
    first_connected_at, 
    last_connected_at, 
    created_at, 
    updated_at,
    user_id
) VALUES 
-- ESP32_001 - Joylyn's Kitchen
(
    'ESP32_001',
    'Joylyn''s Kitchen',
    'gas_sensor',
    'ACTIVE',
    timezone('utc'::text, now()),
    timezone('utc'::text, now()),
    timezone('utc'::text, now()),
    timezone('utc'::text, now()),
    NULL  -- Will be set by trigger if user is logged in
),
-- ESP32_002 - Marjorie's Kitchen  
(
    'ESP32_002',
    'Marjorie''s Kitchen',
    'gas_sensor',
    'ACTIVE',
    timezone('utc'::text, now()),
    timezone('utc'::text, now()),
    timezone('utc'::text, now()),
    timezone('utc'::text, now()),
    NULL  -- Will be set by trigger if user is logged in
),
-- ESP_002 - Hazel's Kitchen
(
    'ESP_002',
    'Hazel''s Kitchen',
    'gas_sensor', 
    'ACTIVE',
    timezone('utc'::text, now()),
    timezone('utc'::text, now()),
    timezone('utc'::text, now()),
    timezone('utc'::text, now()),
    NULL  -- Will be set by trigger if user is logged in
);

-- Also create initial device connection records for these devices
INSERT INTO public.device_connections (
    device_id,
    device_name,
    connection_type,
    connected_at,
    is_active,
    data_count,
    user_id
) VALUES
-- ESP32_001 - Joylyn's Kitchen
(
    'ESP32_001',
    'Joylyn''s Kitchen',
    'initial_setup',
    timezone('utc'::text, now()),
    true,
    0,
    NULL  -- Will be set by trigger if user is logged in
),
-- ESP32_002 - Marjorie's Kitchen
(
    'ESP32_002',
    'Marjorie''s Kitchen',
    'initial_setup',
    timezone('utc'::text, now()),
    true,
    0,
    NULL  -- Will be set by trigger if user is logged in
),
-- ESP_002 - Hazel's Kitchen
(
    'ESP_002',
    'Hazel''s Kitchen',
    'initial_setup',
    timezone('utc'::text, now()),
    true,
    0,
    NULL  -- Will be set by trigger if user is logged in
);

-- Verify the devices were inserted successfully
SELECT 
    device_id,
    device_name,
    device_type,
    status,
    created_at
FROM public.devices 
WHERE device_id IN ('ESP32_001', 'ESP32_002', 'ESP_002')
ORDER BY device_id;

-- Also verify device connections
SELECT 
    device_id,
    device_name,
    connection_type,
    connected_at,
    is_active
FROM public.device_connections 
WHERE device_id IN ('ESP32_001', 'ESP32_002', 'ESP_002')
ORDER BY device_id;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Successfully restored 3 devices:';
    RAISE NOTICE '- ESP32_001: Joylyn''s Kitchen';
    RAISE NOTICE '- ESP32_002: Marjorie''s Kitchen';
    RAISE NOTICE '- ESP_002: Hazel''s Kitchen';
    RAISE NOTICE '';
    RAISE NOTICE 'These devices should now appear in your mobile app!';
END $$; 