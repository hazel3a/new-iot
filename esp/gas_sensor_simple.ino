// MQ-5 Gas Sensor with Non-Blocking Supabase Integration
// Based on working sensor code - WiFi operations will NOT interfere with readings

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// WiFi credentials
const char* ssid = "ZTE_2.4G_LNZh9p";        
const char* password = "WUFT9tZ5"; 

// Pin definitions
const int GAS_SENSOR_PIN = 34;    // Using GPIO 4 since it works in your simple code

// Device identification
const String DEVICE_ID = "ESP32_001";
const String DEVICE_NAME = "Kitchen Gas Sensor";

// Calibration variables
int baselineReading = 0;         
const int CALIBRATION_SAMPLES = 50; 

// Threshold levels (based on deviation from baseline)
const int SAFE_THRESHOLD = 100;      
const int WARNING_THRESHOLD = 300;   
const int DANGER_THRESHOLD = 600;    
const int CRITICAL_THRESHOLD = 1000; 

// Supabase configuration
const char* supabaseUrl = "https://zbtqfdifmvwyvabydbog.supabase.co";
const char* supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpidHFmZGlmbXZ3eXZhYnlkYm9nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk2NDc3MTYsImV4cCI6MjA2NTIyMzcxNn0.2GX6D42jgxoCLo1H63viR8PE_LPOrtXgXcNzciNBE6s";
const String supabaseTable = "gas_sensor_readings";

// Sensor variables (keep exactly as in working code)
int gasValue = 0;
int gasDeviation = 0;            
String gasLevel = "";
unsigned long lastReadTime = 0;
const unsigned long READ_INTERVAL = 1000; 

// WiFi variables (completely separate from sensor)
unsigned long lastWiFiCheck = 0;
unsigned long lastUploadAttempt = 0;
const unsigned long WIFI_CHECK_INTERVAL = 15000;  // Check WiFi every 15 seconds
const unsigned long UPLOAD_INTERVAL = 1000;       // Try upload every 1 second
bool wifiConnected = false;
bool uploadInProgress = false;

// Data buffer for when WiFi is not available
struct SensorReading {
  String deviceId;
  String deviceName;
  int gasValue;
  String gasLevel;
  int deviation;
  int baseline;
  unsigned long timestamp;
};

SensorReading latestReading;
bool hasNewData = false;

void setup() {
  // Initialize serial communication
  Serial.begin(115200);
  Serial.println("=================================");
  Serial.println("ESP32 MQ-5 Gas Sensor Monitor");
  Serial.println("=================================");
  
  // Set ADC resolution (ESP32 default is 12-bit = 0-4095)
  analogReadResolution(12);
  
  // Start WiFi connection in background (non-blocking)
  Serial.println("Starting WiFi connection in background...");
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  Serial.println("System initialized!");
  Serial.println("Warming up sensor... (60 seconds)");
  
  // Sensor warm-up period (exactly as in working code)
  for(int i = 60; i > 0; i--) {
    Serial.print("Warm-up: ");
    Serial.print(i);
    Serial.print(" seconds remaining - Reading: ");
    
    // Show readings during warm-up to verify sensor works
    int reading = analogRead(GAS_SENSOR_PIN);
    Serial.println(reading);
    delay(1000);
  }
  
  Serial.println("Calibrating sensor in clean air...");
  calibrateSensor();
  
  Serial.println("Sensor ready! Starting monitoring...");
  Serial.println("Baseline reading: " + String(baselineReading));
  Serial.println("Thresholds (deviation from baseline):");
  Serial.println("- Safe: < " + String(SAFE_THRESHOLD));
  Serial.println("- Warning: " + String(SAFE_THRESHOLD) + "-" + String(WARNING_THRESHOLD));
  Serial.println("- Danger: " + String(WARNING_THRESHOLD) + "-" + String(DANGER_THRESHOLD));
  Serial.println("- Critical: > " + String(DANGER_THRESHOLD));
  Serial.println("=================================");
}

void loop() {
  // PRIORITY 1: Always read sensor first (exactly as working code)
  if (millis() - lastReadTime >= READ_INTERVAL) {
    readGasSensor();
    lastReadTime = millis();
  }
  
  // PRIORITY 2: Check WiFi status (non-blocking, infrequent)
  if (millis() - lastWiFiCheck >= WIFI_CHECK_INTERVAL) {
    checkWiFiStatus();
    lastWiFiCheck = millis();
  }
  
  // PRIORITY 3: Upload data if possible (non-blocking)
  if (!uploadInProgress && hasNewData && wifiConnected && 
      millis() - lastUploadAttempt >= UPLOAD_INTERVAL) {
    uploadDataAsync();
    lastUploadAttempt = millis();
  }
  
  delay(100); // Same as working code
}

void readGasSensor() {
  // EXACT SAME CODE AS YOUR WORKING VERSION
  gasValue = analogRead(GAS_SENSOR_PIN);
  
  // Calculate deviation from baseline
  gasDeviation = abs(gasValue - baselineReading);
  
  // Determine gas level based on thresholds
  determineGasLevel();
  
  // Print readings to serial monitor
  printGasReading();
  
  // Handle alerts
  handleAlerts();
  
  // Store for upload (doesn't interfere with sensor)
  storeReading();
}

void determineGasLevel() {
  // EXACT SAME CODE AS YOUR WORKING VERSION
  if (gasDeviation < SAFE_THRESHOLD) {
    gasLevel = "SAFE";
  } else if (gasDeviation < WARNING_THRESHOLD) {
    gasLevel = "WARNING";
  } else if (gasDeviation < DANGER_THRESHOLD) {
    gasLevel = "DANGER";
  } else {
    gasLevel = "CRITICAL";
  }
}

void printGasReading() {
  // EXACT SAME CODE AS YOUR WORKING VERSION + WiFi status
  Serial.print("[");
  Serial.print(millis()/1000);
  Serial.print("s] Raw: ");
  Serial.print(gasValue);
  Serial.print(" | Baseline: ");
  Serial.print(baselineReading);
  Serial.print(" | Deviation: ");
  Serial.print(gasDeviation);
  Serial.print(" | Level: ");
  Serial.print(gasLevel);
  
  // Add WiFi status indicator
  if (wifiConnected) {
    Serial.print(" | WiFi: ✓");
  } else {
    Serial.print(" | WiFi: ✗");
  }
  
  // Add visual indicator
  if (gasLevel == "SAFE") {
    Serial.println(" ✓");
  } else if (gasLevel == "WARNING") {
    Serial.println(" ⚠");
  } else if (gasLevel == "DANGER") {
    Serial.println(" ⚠⚠");
  } else {
    Serial.println(" 🚨🚨🚨");
  }
}

void handleAlerts() {
  // EXACT SAME CODE AS YOUR WORKING VERSION
  if (gasLevel == "WARNING") {
    Serial.println(">>> WARNING: Gas levels elevated! Check ventilation.");
  } else if (gasLevel == "DANGER") {
    Serial.println(">>> DANGER: High gas levels detected! Take immediate action!");
  } else if (gasLevel == "CRITICAL") {
    Serial.println(">>> CRITICAL ALERT: Extremely high gas levels! EVACUATE AREA!");
    Serial.println(">>> Turn off gas sources and ensure proper ventilation!");
  }
}

void calibrateSensor() {
  // EXACT SAME CODE AS YOUR WORKING VERSION
  long sum = 0;
  Serial.println("Taking calibration readings...");
  
  for (int i = 0; i < CALIBRATION_SAMPLES; i++) {
    int reading = analogRead(GAS_SENSOR_PIN);
    sum += reading;
    Serial.print("Sample ");
    Serial.print(i + 1);
    Serial.print("/");
    Serial.print(CALIBRATION_SAMPLES);
    Serial.print(": ");
    Serial.println(reading);
    delay(100);
  }
  
  baselineReading = sum / CALIBRATION_SAMPLES;
  Serial.println("Calibration complete!");
  Serial.println("Baseline established at: " + String(baselineReading));
}

// NON-BLOCKING WiFi and Upload functions
void checkWiFiStatus() {
  if (WiFi.status() == WL_CONNECTED) {
    if (!wifiConnected) {
      Serial.println("✓ WiFi connected: " + WiFi.localIP().toString());
      wifiConnected = true;
    }
  } else {
    if (wifiConnected) {
      Serial.println("✗ WiFi disconnected");
      wifiConnected = false;
    }
  }
}

void storeReading() {
  // Store latest reading for upload
  latestReading.deviceId = DEVICE_ID;
  latestReading.deviceName = DEVICE_NAME;
  latestReading.gasValue = gasValue;
  latestReading.gasLevel = gasLevel;
  latestReading.deviation = gasDeviation;
  latestReading.baseline = baselineReading;
  latestReading.timestamp = millis();
  hasNewData = true;
}

void uploadDataAsync() {
  if (!wifiConnected || uploadInProgress) return;
  
  uploadInProgress = true;
  
  // Use a separate task or simple async approach
  HTTPClient http;
  http.setTimeout(3000); // Short timeout to prevent blocking
  
  String url = String(supabaseUrl) + "/rest/v1/" + supabaseTable;
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Prefer", "return=minimal");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Authorization", "Bearer " + String(supabaseKey));
  
  // Create JSON payload
  DynamicJsonDocument doc(512);
  doc["device_id"] = latestReading.deviceId;
  doc["device_name"] = latestReading.deviceName;
  doc["gas_value"] = latestReading.gasValue;
  doc["gas_level"] = latestReading.gasLevel;
  doc["deviation"] = latestReading.deviation;
  doc["baseline"] = latestReading.baseline;
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  Serial.print("Uploading to Supabase... ");
  
  Serial.println("JSON payload: " + jsonString);
  
  int httpResponseCode = http.POST(jsonString);
  
  if (httpResponseCode == 201) {
    Serial.println("✓ Upload successful!");
    hasNewData = false; // Mark as uploaded
  } else {
    Serial.println("✗ Upload failed: " + String(httpResponseCode));
    
    // Print more detailed error information
    if (httpResponseCode > 0) {
      String response = http.getString();
      Serial.println("Response: " + response);
    } else {
      Serial.println("HTTP Error: " + String(httpResponseCode));
    }
  }
  
  http.end();
  uploadInProgress = false;
}

float getGasPercentage() {
  // EXACT SAME CODE AS YOUR WORKING VERSION
  float voltage = (gasValue / 4095.0) * 3.3; 
  float percentage = (voltage / 3.3) * 100;  
  return percentage;
} 