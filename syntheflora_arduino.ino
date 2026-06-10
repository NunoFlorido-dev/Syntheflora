#include <CapacitiveSensor.h>

// --- Force Sensor Pins ---
int fsrModule = A1;

// --- DIY Capacitive Pins ---
CapacitiveSensor csSensor = CapacitiveSensor(7, 6);

// --- Button Pin ---
const int buttonPin = 2;
int toggle = 0;
int lastButtonState = LOW;
int lastToggle = -1;

// --- Output ---
int ledPin = 10;

unsigned long lastPrintTime = 0;

void setup() {
  Serial.begin(9600);

  pinMode(touchModule, INPUT);
  pinMode(buttonPin, INPUT_PULLUP);

  diyTouch.set_CS_AutocaL_Millis(0xFFFFFFFF);

  pinMode(ledPin, OUTPUT);
}

void loop() {
  int fsrState = map(analogRead(fsrModule), 0, 1023, 500, 2000);
  int buttonState = digitalRead(buttonPin);
  long csSensor = map(diyTouch.capacitiveSensor(10), 0, 500, 0, 100);
  int knobValue = analogRead(A0);
  float mappedKnob = map(knobValue, 0, 1023, 0, 150);

  if (buttonState != lastButtonState) {
    if (buttonState == LOW) {
      if (toggle == 0) {
        toggle = 1;
      } else {
        toggle = 0;
      }
    }
    delay(50);
  }

  lastButtonState = buttonState;

  digitalWrite(ledPin, toggle == 1 ? HIGH : LOW);

if (millis() - lastPrintTime >= 300) {
    Serial.print("Aluminum: "); Serial.print(csSensor);
    Serial.print(" | FSR: "); Serial.print(fsrState);
    Serial.print(" | Knob: "); Serial.print((int)mappedKnob);
    Serial.print(" | Toggle: "); Serial.println(toggle);
    
    lastPrintTime = millis();
  }
}