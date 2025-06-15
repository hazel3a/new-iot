#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// WiFi credentials
const char* ssid = "ZTE_2.4G_LNZh9p";        // Replace with your WiFi SSID
const char* password = "WUFT9tZ5"; // Replace with your WiFi password

// Pin definitions
const int GAS_SENSOR_PIN = 4;    // Analog pin for MQ-5 sensor

// Calibration variables
int baselineReading = 0;         // Baseline reading in clean air
const int CALIBRATION_SAMPLES = 50; // Number of samples for calibration

// Threshold levels (based on deviation from baseline)
const int SAFE_THRESHOLD = 100;      // Below this deviation = Safe
const int WARNING_THRESHOLD = 300;   // Warning threshold
const int DANGER_THRESHOLD = 600;    // Danger threshold
const int CRITICAL_THRESHOLD = 1000; // Critical threshold

// Supabase configuration
const char* supabaseUrl = "https://yqoenpsoluwmjrlliwdo.supabase.co";
const char* supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlxb2VucHNvbHV3bWpybGxpd2RvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk0NTgzNDEsImV4cCI6MjA2NTAzNDM0MX0.YQx7Qjw7gJD5Vv7_Z3LCQLaCACsLvfvW2IR7YIpAps0";
const String supabaseTable = "gas_sensor_readings"; // Table name

// Variables
int gasValue = 0;
int gasDeviation = 0;            // Deviation from baseline
String gasLevel = "";
unsigned long lastReadTime = 0;
unsigned long lastUploadTime = 0;
const unsigned long READ_INTERVAL = 1000;     // Read every 1 second
const unsigned long UPLOAD_INTERVAL = 30000;  // Upload every 30 seconds

void setup() {
  // Initialize serial communication
  Serial.begin(115200);
  Serial.println("=================================");
  Serial.println("ESP32 MQ-5 Gas Sensor Monitor");
  Serial.println("=================================");
  
  // Set ADC resolution (ESP32 default is 12-bit = 0-4095)
  analogReadResolution(12);
  
  // Scan for available networks first
  scanWiFiNetworks();
  
  // Connect to WiFi
  connectToWiFi();
  
  Serial.println("System initialized!");
  Serial.println("Warming up sensor... (60 seconds)");
  
  // Sensor warm-up period (MQ sensors need time to stabilize)
  for(int i = 60; i > 0; i--) {
    Serial.print("Warm-up: ");
    Serial.print(i);
    Serial.println(" seconds remaining");
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
  // Smart WiFi connection monitoring
  checkWiFiConnection();
  
  // Check if it's time to read the sensor
  if (millis() - lastReadTime >= READ_INTERVAL) {
    readGasSensor();
    lastReadTime = millis();
  }
  
  // Check if it's time to upload data (only if WiFi is connected)
  if (WiFi.status() == WL_CONNECTED && millis() - lastUploadTime >= UPLOAD_INTERVAL) {
    sendDataToSupabase();
    lastUploadTime = millis();
  }
  
  delay(100); // Small delay to prevent excessive CPU usage
}

void connectToWiFi() {
  // Optimize WiFi settings for faster connection
  WiFi.mode(WIFI_STA);                    // Set to station mode only
  WiFi.setAutoReconnect(true);            // Enable auto-reconnect
  WiFi.setSleep(false);                   // Disable power saving for stability
  
  // Set static IP (optional - uncomment and configure if needed for faster connection)
  // IPAddress local_IP(192, 168, 1, 100);
  // IPAddress gateway(192, 168, 1, 1);
  // IPAddress subnet(255, 255, 255, 0);
  // WiFi.config(local_IP, gateway, subnet);
  
  Serial.println("Connecting to WiFi: " + String(ssid));
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  const int maxAttempts = 30; // 15 seconds timeout
  
  while (WiFi.status() != WL_CONNECTED && attempts < maxAttempts) {
    delay(500);
    Serial.print(".");
    attempts++;
    
    // Print connection status every 5 attempts
    if (attempts % 5 == 0) {
      Serial.println();
      Serial.print("Attempt " + String(attempts) + "/" + String(maxAttempts) + " - Status: ");
      printWiFiStatus();
    }
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.println("✓ WiFi connected successfully!");
    Serial.println("IP address: " + WiFi.localIP().toString());
    Serial.println("Signal strength: " + String(WiFi.RSSI()) + " dBm");
    Serial.println("Gateway: " + WiFi.gatewayIP().toString());
    Serial.println("DNS: " + WiFi.dnsIP().toString());
  } else {
    Serial.println();
    Serial.println("✗ WiFi connection failed!");
    Serial.println("Please check your WiFi credentials and network availability.");
    printWiFiStatus();
    
    // Try to reconnect after a short delay
    Serial.println("Retrying in 5 seconds...");
    delay(5000);
    connectToWiFi(); // Recursive retry
  }
}

void printWiFiStatus() {
  switch (WiFi.status()) {
    case WL_IDLE_STATUS:
      Serial.print("IDLE");
      break;
    case WL_NO_SSID_AVAIL:
      Serial.print("NO_SSID_AVAILABLE");
      break;
    case WL_SCAN_COMPLETED:
      Serial.print("SCAN_COMPLETED");
      break;
    case WL_CONNECTED:
      Serial.print("CONNECTED");
      break;
    case WL_CONNECT_FAILED:
      Serial.print("CONNECT_FAILED");
      break;
    case WL_CONNECTION_LOST:
      Serial.print("CONNECTION_LOST");
      break;
    case WL_DISCONNECTED:
      Serial.print("DISCONNECTED");
      break;
    default:
      Serial.print("UNKNOWN");
      break;
  }
}

void checkWiFiConnection() {
  static unsigned long lastCheck = 0;
  const unsigned long checkInterval = 10000; // Check every 10 seconds
  
  if (millis() - lastCheck >= checkInterval) {
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("WiFi disconnected. Signal strength before disconnect: " + String(WiFi.RSSI()) + " dBm");
      Serial.println("Attempting to reconnect...");
      connectToWiFi();
    } else {
      // Optionally print signal strength for monitoring
      int rssi = WiFi.RSSI();
      if (rssi < -70) {
        Serial.println("⚠ Weak WiFi signal: " + String(rssi) + " dBm");
      }
    }
    lastCheck = millis();
  }
}

void scanWiFiNetworks() {
  Serial.println("Scanning for WiFi networks...");
  int numNetworks = WiFi.scanNetworks();
  
  if (numNetworks == 0) {
    Serial.println("No networks found");
  } else {
    Serial.println("Found " + String(numNetworks) + " networks:");
    bool targetFound = false;
    
    for (int i = 0; i < numNetworks; i++) {
      String currentSSID = WiFi.SSID(i);
      int currentRSSI = WiFi.RSSI(i);
      String encryption = (WiFi.encryptionType(i) == WIFI_AUTH_OPEN) ? "Open" : "Secured";
      
      Serial.print(String(i + 1) + ": " + currentSSID);
      Serial.print(" (" + String(currentRSSI) + " dBm) ");
      Serial.println("[" + encryption + "]");
      
      // Check if our target network is available
      if (currentSSID == ssid) {
        targetFound = true;
        Serial.println("   ✓ Target network found! Signal: " + String(currentRSSI) + " dBm");
      }
    }
    
    if (!targetFound) {
      Serial.println("⚠ WARNING: Target network '" + String(ssid) + "' not found!");
      Serial.println("Please check your SSID or move closer to the router.");
    }
  }
  
  // Clean up
  WiFi.scanDelete();
  Serial.println("Network scan complete.\n");
}

void sendDataToSupabase() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    
    // Construct the URL for the REST API
    String url = String(supabaseUrl) + "/rest/v1/" + supabaseTable;
    
    http.begin(url);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("Prefer", "return=minimal");
    http.addHeader("apikey", supabaseKey);
    http.addHeader("Authorization", "Bearer " + String(supabaseKey));
    
    // Create JSON payload
    DynamicJsonDocument doc(1024);
    doc["gas_value"] = gasValue;
    doc["gas_level"] = gasLevel;
    doc["deviation"] = gasDeviation;
    doc["baseline"] = baselineReading;
    
    String jsonString;
    serializeJson(doc, jsonString);
    
    Serial.println("Sending data to Supabase...");
    Serial.println("Payload: " + jsonString);
    
    int httpResponseCode = http.POST(jsonString);
    
    if (httpResponseCode > 0) {
      String response = http.getString();
      Serial.println("HTTP Response Code: " + String(httpResponseCode));
      Serial.println("Response: " + response);
      
      if (httpResponseCode == 201) {
        Serial.println("✓ Data successfully sent to Supabase!");
      } else {
        Serial.println("⚠ Warning: Unexpected response code");
      }
    } else {
      Serial.println("✗ Error sending data to Supabase");
      Serial.println("Error: " + String(httpResponseCode));
    }
    
    http.end();
  } else {
    Serial.println("✗ WiFi not connected. Cannot send data.");
  }
}

void readGasSensor() {
  // Read analog value from MQ-5 sensor
  gasValue = analogRead(GAS_SENSOR_PIN);
  
  // Calculate deviation from baseline
  gasDeviation = abs(gasValue - baselineReading);
  
  // Determine gas level based on thresholds
  determineGasLevel();
  
  // Print readings to serial monitor
  printGasReading();
  
  // Handle alerts
  handleAlerts();
}

void determineGasLevel() {
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
  // Create formatted output
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
  if (gasLevel == "WARNING") {
    Serial.println(">>> WARNING: Gas levels elevated! Check ventilation.");
  } else if (gasLevel == "DANGER") {
    Serial.println(">>> DANGER: High gas levels detected! Take immediate action!");
  } else if (gasLevel == "CRITICAL") {
    Serial.println(">>> CRITICAL ALERT: Extremely high gas levels! EVACUATE AREA!");
    Serial.println(">>> Turn off gas sources and ensure proper ventilation!");
  }
}

// Calibration function - establishes baseline in clean air
void calibrateSensor() {
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

// Function to get gas percentage (optional - for calibrated sensors)
float getGasPercentage() {
  // This is a basic conversion - you may need to calibrate for your specific sensor
  // MQ-5 detects LPG, natural gas, town gas
  float voltage = (gasValue / 4095.0) * 3.3; // Convert to voltage
  float percentage = (voltage / 3.3) * 100;  // Simple percentage calculation
  return percentage;
}

// Function to print detailed sensor information (call this in setup for debugging)
void printSensorInfo() {
  Serial.println("\n--- Sensor Information ---");
  Serial.println("Sensor: MQ-5 (LPG, Natural Gas, Town Gas)");
  Serial.println("ADC Resolution: 12-bit (0-4095)");
  Serial.println("Supply Voltage: 3.3V");
  Serial.println("Pin: GPIO 4");
  Serial.println("-------------------------\n");
}