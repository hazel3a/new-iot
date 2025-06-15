#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// WiFi credentials
const char* ssid = "ZTE_2.4G_LNZh9p";
const char* password = "WUFT9tZ5";

// Supabase configuration
const char* supabaseUrl = "https://yqoenpsoluwmjrlliwdo.supabase.co";
const char* supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlxb2VucHNvbHV3bWpybGxpd2RvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk0NTgzNDEsImV4cCI6MjA2NTAzNDM0MX0.YQx7Qjw7gJD5Vv7_Z3LCQLaCACsLvfvW2IR7YIpAps0";

// Device identification
const int deviceId = 1;  // Simple integer device ID
const char* deviceName = "Kitchen Gas Sensor";

// MQ5 Gas Sensor pinf
const int gasSensorPin = 4; // Analog pin for MQ5 sensor

// Gas level thresholds
const int CLEAN_AIR_THRESHOLD = 100;    // Below this value is considered clean air
const int LIGHT_GAS_THRESHOLD = 300;    // Light gas detection threshold
const int WARNING_GAS_THRESHOLD = 600;  // Warning gas level threshold
const int CRITICAL_GAS_THRESHOLD = 1000; // Critical gas level threshold

void setup() {
  Serial.begin(115200);
  delay(1000); // Give time for serial monitor to start
  
  // Connect to WiFi with timeout and retry mechanism
  connectToWiFi();
}

void loop() {
  // Check WiFi connection and reconnect if needed
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected. Reconnecting...");
    connectToWiFi();
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    // Read gas sensor value
    int gasValue = analogRead(gasSensorPin);
    String gasLevel = getGasLevel(gasValue);
    
    // Create JSON payload with device info
    StaticJsonDocument<300> doc;
    doc["gas_value"] = gasValue;
    doc["gas_level"] = gasLevel;
    doc["device_id"] = deviceId;
    doc["device_name"] = deviceName;
    doc["timestamp"] = getTimestamp();
    
    String jsonString;
    serializeJson(doc, jsonString);
    
    // Send data to Supabase
    sendToSupabase(jsonString);
    
    // Print values to Serial Monitor
    Serial.print("Gas Value: ");
    Serial.print(gasValue);
    Serial.print(" | Level: ");
    Serial.print(gasLevel);
    Serial.print(" | Device ID: ");
    Serial.println(deviceId);
  } else {
    Serial.println("WiFi not connected. Skipping data transmission.");
  }
  
  delay(5000); // Wait for 5 seconds before next reading
}

String getGasLevel(int value) {
  if (value < CLEAN_AIR_THRESHOLD) return "clean_air";
  if (value < LIGHT_GAS_THRESHOLD) return "light_gas";
  if (value < WARNING_GAS_THRESHOLD) return "warning_gas";
  if (value < CRITICAL_GAS_THRESHOLD) return "critical_gas";
  return "dangerous";
}

String getTimestamp() {
  HTTPClient http;
  String url = "http://worldtimeapi.org/api/ip";
  http.begin(url);
  
  int httpCode = http.GET();
  String timestamp = "";
  
  if (httpCode == HTTP_CODE_OK) {
    String payload = http.getString();
    StaticJsonDocument<1024> doc;
    deserializeJson(doc, payload);
    timestamp = doc["datetime"].as<String>();
  }
  
  http.end();
  return timestamp;
}

void connectToWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  Serial.print("Connecting to WiFi");
  int attempts = 0;
  const int maxAttempts = 20; // 10 seconds timeout
  
  while (WiFi.status() != WL_CONNECTED && attempts < maxAttempts) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nConnected to WiFi");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    Serial.print("Signal Strength: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
  } else {
    Serial.println("\nFailed to connect to WiFi. Will retry...");
    WiFi.disconnect();
    delay(1000);
  }
}

void sendToSupabase(String jsonData) {
  HTTPClient http;
  String url = String(supabaseUrl) + "/rest/v1/gas_sensor_reading";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Authorization", "Bearer " + String(supabaseKey));
  http.addHeader("Prefer", "return=minimal");
  
  int httpCode = http.POST(jsonData);
  
  if (httpCode > 0) {
    if (httpCode == HTTP_CODE_CREATED || httpCode == HTTP_CODE_OK) {
      Serial.println("Data sent successfully to Supabase");
    } else {
      String response = http.getString();
      Serial.println("HTTP Response code: " + String(httpCode));
      Serial.println("Response: " + response);
    }
  } else {
    Serial.println("Error sending data to Supabase");
    Serial.println("HTTP Error: " + String(httpCode));
  }
  
  http.end();
} 