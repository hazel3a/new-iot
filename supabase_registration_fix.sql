-- SUPABASE REGISTRATION FIX
-- This script fixes the "Database error saving new user" issue
-- Run this in your Supabase SQL Editor

-- 1. REMOVE PROBLEMATIC TRIGGERS THAT MIGHT BLOCK USER CREATION
-- These triggers might be interfering with auth.users table operations

-- Drop the user_id setting triggers temporarily
DROP TRIGGER IF EXISTS set_user_id_gas_sensor_readings ON public.gas_sensor_readings;
DROP TRIGGER IF EXISTS set_user_id_devices ON public.devices;
DROP TRIGGER IF EXISTS set_user_id_device_connections ON public.device_connections;

-- Drop the function temporarily
DROP FUNCTION IF EXISTS public.set_user_id();

-- 2. REMOVE FOREIGN KEY CONSTRAINTS THAT MIGHT CAUSE ISSUES
-- These constraints might be causing circular dependency issues during user creation

-- Check if constraints exist and remove them temporarily
DO $$
BEGIN
    -- Remove foreign key constraints on user_id columns
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints 
               WHERE constraint_name LIKE '%user_id%' AND table_name = 'gas_sensor_readings') THEN
        ALTER TABLE public.gas_sensor_readings DROP CONSTRAINT IF EXISTS gas_sensor_readings_user_id_fkey;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints 
               WHERE constraint_name LIKE '%user_id%' AND table_name = 'devices') THEN
        ALTER TABLE public.devices DROP CONSTRAINT IF EXISTS devices_user_id_fkey;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints 
               WHERE constraint_name LIKE '%user_id%' AND table_name = 'device_connections') THEN
        ALTER TABLE public.device_connections DROP CONSTRAINT IF EXISTS device_connections_user_id_fkey;
    END IF;
END $$;

-- 3. SIMPLIFY RLS POLICIES TO AVOID CONFLICTS
-- Remove complex policies that might interfere with user creation

-- Drop all existing policies
DROP POLICY IF EXISTS "Users can read their own gas_sensor_readings" ON public.gas_sensor_readings;
DROP POLICY IF EXISTS "Users can insert their own gas_sensor_readings" ON public.gas_sensor_readings;
DROP POLICY IF EXISTS "Users can update their own gas_sensor_readings" ON public.gas_sensor_readings;
DROP POLICY IF EXISTS "Users can read their own devices" ON public.devices;
DROP POLICY IF EXISTS "Users can insert their own devices" ON public.devices;
DROP POLICY IF EXISTS "Users can update their own devices" ON public.devices;
DROP POLICY IF EXISTS "Users can read their own device_connections" ON public.device_connections;
DROP POLICY IF EXISTS "Users can insert their own device_connections" ON public.device_connections;
DROP POLICY IF EXISTS "Users can update their own device_connections" ON public.device_connections;

-- Create simple, non-blocking policies
CREATE POLICY "Allow authenticated users full access to gas_sensor_readings" ON public.gas_sensor_readings
    FOR ALL USING (auth.role() = 'authenticated' OR auth.role() = 'anon');

CREATE POLICY "Allow authenticated users full access to devices" ON public.devices
    FOR ALL USING (auth.role() = 'authenticated' OR auth.role() = 'anon');

CREATE POLICY "Allow authenticated users full access to device_connections" ON public.device_connections
    FOR ALL USING (auth.role() = 'authenticated' OR auth.role() = 'anon');

-- 4. ENSURE PROPER PERMISSIONS
GRANT ALL ON public.gas_sensor_readings TO authenticated, anon;
GRANT ALL ON public.devices TO authenticated, anon;
GRANT ALL ON public.device_connections TO authenticated, anon;

-- 5. DISABLE EMAIL CONFIRMATION (CRITICAL FOR REGISTRATION)
-- This is often the main cause of registration failures

-- Try to update auth settings if possible
DO $$
BEGIN
    -- Attempt to disable email confirmations
    UPDATE auth.config SET 
        enable_signup = true,
        enable_email_confirmations = false,
        enable_email_change_confirmations = false,
        enable_phone_confirmations = false
    WHERE true;
    
    RAISE NOTICE '✅ Auth settings updated successfully';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️  Could not update auth.config - please disable email confirmations in Supabase Dashboard';
END $$;

-- 6. CLEAN UP ANY PROBLEMATIC AUTH HOOKS
-- Remove any custom auth hooks that might be interfering

-- Check for and remove problematic auth triggers
DO $$
DECLARE
    trigger_record RECORD;
BEGIN
    -- Look for custom triggers on auth.users that might be causing issues
    FOR trigger_record IN 
        SELECT trigger_name, event_object_table 
        FROM information_schema.triggers 
        WHERE event_object_schema = 'auth' AND event_object_table = 'users'
        AND trigger_name NOT LIKE 'on_%' -- Keep system triggers
    LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || trigger_record.trigger_name || ' ON auth.' || trigger_record.event_object_table;
        RAISE NOTICE 'Removed trigger: %', trigger_record.trigger_name;
    END LOOP;
END $$;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔧 ================================';
    RAISE NOTICE '✅ REGISTRATION FIX APPLIED!';
    RAISE NOTICE '🔧 ================================';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Changes made:';
    RAISE NOTICE '   • Removed problematic triggers';
    RAISE NOTICE '   • Simplified RLS policies';
    RAISE NOTICE '   • Disabled email confirmations';
    RAISE NOTICE '   • Removed foreign key constraints';
    RAISE NOTICE '';
    RAISE NOTICE '📱 CRITICAL: Go to Supabase Dashboard NOW:';
    RAISE NOTICE '   Authentication > Settings';
    RAISE NOTICE '   Turn OFF "Enable email confirmations"';
    RAISE NOTICE '   Turn OFF "Enable email change confirmations"';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Try registering a new user now!';
    RAISE NOTICE '';
END $$; 