// PinTest.ino
// Test sketch: receives a pin number over serial from MATLAB,
// sets that pin HIGH for 2 seconds, then sets it LOW.
// Prints status to Serial Monitor so you can confirm which pin fired.

int testPins[] = { 8, 9, 10, 12, 13 };
const int NUM_PINS = 5;

void setup() {
    Serial.begin(9600);
    for (int i = 0; i < NUM_PINS; i++) {
        pinMode(testPins[i], OUTPUT);
        digitalWrite(testPins[i], LOW);
    }
    Serial.println("PinTest ready. Send a pin number (8, 9, 10, 12, or 13) to test.");
}

void loop() {
    if (Serial.available()) {
        int pin = Serial.parseInt();

        // Flush any remaining characters (e.g. newline)
        while (Serial.available()) {
            Serial.read();
        }

        // Validate pin
        bool valid = false;
        for (int i = 0; i < NUM_PINS; i++) {
            if (pin == testPins[i]) {
                valid = true;
                break;
            }
        }

        if (!valid) {
            Serial.print("Invalid pin: ");
            Serial.println(pin);
            return;
        }

        Serial.print("Pin ");
        Serial.print(pin);
        Serial.print(" -> HIGH ... ");

        digitalWrite(pin, HIGH);
        delay(2000);
        digitalWrite(pin, LOW);

        Serial.println("LOW");
    }
}
