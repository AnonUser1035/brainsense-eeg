//ASSR Arduino Code
//The purpose of this code is to send voltage signals to Neuroscan EEG machine for
//EEG timestamps

//Setting parameters equal to 6 and Buffer size = 24 (6 floats x 4 bytes)
#define NUM_PARAMETERS 6
#define BUFFER_SIZE 24

 //Arduino trigger pins remapped to pins 2, 3, 4
 int triggerPins[3] = { 2, 3, 4 }; // for EEG trigger

 //Stimulation pins from Catherine's experiment
 //Consider removing if not used in current ASSR paradigm
 int stimulatorPins[2] = { 12, 13 }; // {left, right}

 //float params[6] creates array of 6 decimal numbers for the parameters
 //float stores number with decimals
 // 1 float equals 4 bytes. So you have 24 bytes in total in params.
 //These 6 parameters are defined in line 63-68
 float params[NUM_PARAMETERS];

 //serialBuffer creates a list of 24 bytes: serialBuffer[0] through serialBuffer[23]
 //1 Byte is digital data storing 8 bits storing 256 possible values
 // 00000000 is 0 and 11111111 is 255. There are 24 of these
 //This is a temporary storage area for incoming serial data from Matlab
 byte serialBuffer[BUFFER_SIZE];

//This is used to calculate time since stimulation: stimulation is not relevant
//*Consider editing
 float t0;


//Void setup is for initializing settings i.e setting pin modes and serial communication with MATLAB
 void setup() {

 //Start serial communication between Arduino and MATLAB at 9600 bits per second (speed)
 //any variable using serial indicates data being sent or received between Matlab and Arduino
 Serial.begin( 9600 );

// set pins 2, 3, 4 as digital output pins for sending EEG trigger...marking its mode as a output
// i++ increases loop by 1 from i = 0 to i=2
 for ( int i = 0; i < 3; i++ ) {
 pinMode( triggerPins[i], OUTPUT );
 }

//Same thing for stimulator pins...not relevant for ASSR
 for ( int i = 0; i < 2; i++ ) { // set pins 12, 13 as digital output pins for stimulators
 pinMode( stimulatorPins[i], OUTPUT );
 }
 }

//void loop after setup, void loop executes code repeatedly in continuous cycle
// only powered down or reset
 void loop() {

 // if data arrived from Matlab
 if (Serial.available() ) {

  //Serial.available, read an entire 24 Bytes from Matlab and store the incoming data in serialBuffer...defined earlier
  //as the temporary storage of 24 bytes
 Serial.readBytes( serialBuffer, BUFFER_SIZE );

//Memory copy
//Structure:   memcpy(destination, source, number_of_bytes);
//Remember param is a float = 4 Bytes so your just taking 4 Bytes from serialBuffer that read MATLAB data and putting it in param

// serialBuffer[0]  serialBuffer[1]  serialBuffer[2]  serialBuffer[3]   -> params[0]
// serialBuffer[4]  serialBuffer[5]  serialBuffer[6]  serialBuffer[7]   -> params[1]
// serialBuffer[8]  serialBuffer[9]  serialBuffer[10] serialBuffer[11]  -> params[2]
// serialBuffer[12] serialBuffer[13] serialBuffer[14] serialBuffer[15]  -> params[3]
// serialBuffer[16] serialBuffer[17] serialBuffer[18] serialBuffer[19]  -> params[4]
// serialBuffer[20] serialBuffer[21] serialBuffer[22] serialBuffer[23]  -> params[5]
 memcpy( &params[0], &serialBuffer[0], 4 ); // stimulation flag
 memcpy( &params[1], &serialBuffer[4], 4 ); // period (in ms)
 memcpy( &params[2], &serialBuffer[8], 4 ); // duration (in ms)
 memcpy( &params[3], &serialBuffer[12], 4 ); // pulsewidth (in ms)
 memcpy( &params[4], &serialBuffer[16], 4 ); // stimulator mode
 memcpy( &params[5], &serialBuffer[20], 4 ); // trigger mode

 //timing
 if ( params[0] == 1.0f ) {
 t0 = millis();
 }
 }

 // set trigger pins LOW
 for ( int i = 0; i < 3; i++ ) {
 digitalWrite( triggerPins[i], LOW );
 }
 delay(1000);

 // set trigger pins HIGH if asked
 switch( int(params[5]) ) {
 case 1:
 digitalWrite( triggerPins[0], HIGH );
 delay(5000);
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
 if ( millis() - t0 > params[2] ) { // if we have surpassed duration, stop everything
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
