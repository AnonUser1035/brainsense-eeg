#define NUM_PARAMETERS 6
#define BUFFER_SIZE 24  // 6 single-precision floats x 4 bytes each

int triggerPins[3] = { 8, 9, 10 }; // for EEG trigger
int stimulatorPins[2] = { 12, 13 }; // {left, right}

float params[NUM_PARAMETERS];
byte serialBuffer[BUFFER_SIZE];

float t0;

void setup() {
    Serial.begin( 9600 );
    for ( int i = 0; i < 3; i++ ) { // set pins 8, 9, 10 as digital output pins for sending trigger
        pinMode( triggerPins[i], OUTPUT );
    } 
    for ( int i = 0; i < 2; i++ ) { // set pins 12, 13 as digital output pins for stimulators
        pinMode( stimulatorPins[i], OUTPUT );
    }
}

void loop() {
    if ( Serial.available() ) {
        Serial.readBytes( serialBuffer, BUFFER_SIZE );

        memcpy( &params[0], &serialBuffer[0], 4 );      // stimulation flag
        memcpy( &params[1], &serialBuffer[4], 4 );      // period (in ms)
        memcpy( &params[2], &serialBuffer[8], 4 );      // duration (in ms)
        memcpy( &params[3], &serialBuffer[12], 4 );     // pulsewidth (in ms)
        memcpy( &params[4], &serialBuffer[16], 4 );     // stimulator mode
        memcpy( &params[5], &serialBuffer[20], 4 );     // trigger mode

        if ( params[0] == 1.0f ) {
            t0 = millis();
        }
    }

    // set trigger pins LOW
    for ( int i = 0; i < 3; i++ ) {
        digitalWrite( triggerPins[i], LOW );
    }

    // set trigger pins HIGH if asked
    switch( int(params[5]) ) {
        case 1:
            digitalWrite( triggerPins[0], HIGH );
            break;
        case 2:
            digitalWrite( triggerPins[1], HIGH );
            break;
        case 3:
            digitalWrite( triggerPins[2], HIGH );
            break;
        case 4:
            digitalWrite( triggerPins[0], HIGH );
            digitalWrite( triggerPins[1], HIGH );
            break;
        case 5:
            digitalWrite( triggerPins[0], HIGH );
            digitalWrite( triggerPins[2], HIGH );
            break;
        case 6:
            digitalWrite( triggerPins[1], HIGH );
            digitalWrite( triggerPins[2], HIGH );
            break;
        case 7:
            digitalWrite( triggerPins[0], HIGH );
            digitalWrite( triggerPins[1], HIGH );
            digitalWrite( triggerPins[2], HIGH );
            break;
        default:
            break;
    }
    params[5] = 0.0f;
    
    // check if we are stimulating
    if ( params[0] == 1.0f ) {
        if ( millis() - t0 > params[2] ) {  // if we have surpassed duration, stop everything
            params[0] = 0.0f; // reset stimulation flag
            for ( int i = 0; i < 2; i++ ) {
                digitalWrite( stimulatorPins[i], LOW );
            }
        } else {
            switch( int(params[4]) ) { // left or right stimulator
                case 0: // left
                    digitalWrite( stimulatorPins[0], HIGH );
                    busyDelayMicroseconds( 1000 * params[3] );
                    digitalWrite( stimulatorPins[0], LOW );
                    busyDelayMicroseconds( 1000 * ( params[1] - params[3] ) );
                    break;
                case 1: // right
                    digitalWrite( stimulatorPins[1], HIGH );
                    busyDelayMicroseconds( 1000 * params[3] );
                    digitalWrite( stimulatorPins[1], LOW );
                    busyDelayMicroseconds( 1000 * ( params[1] - params[3] ) );
                    break;
                case 2: // both
                    digitalWrite( stimulatorPins[0], HIGH );
                    digitalWrite( stimulatorPins[1], HIGH );
                    busyDelayMicroseconds( 1000 * params[3] );
                    digitalWrite( stimulatorPins[0], LOW );
                    digitalWrite( stimulatorPins[1], LOW );
                    busyDelayMicroseconds( 1000 * ( params[1] - params[3] ) );
                    break;
                default:
                    break;
            }
        }
    } else {
        for ( int i = 0; i < 2; i++ ) {
            digitalWrite( stimulatorPins[i], LOW );
        }
    }
}

void busyDelayMicroseconds( unsigned long wait ) {
    unsigned long t0 = micros();
    while ( micros() - t0 < wait ) {}
}
