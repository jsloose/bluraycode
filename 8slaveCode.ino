// Libraries to be used
#include <math.h>
#include <Servo.h>
#include <SPI.h>

#define BAUDRATE 115200
//#############################################################################//
//PIN SETUP                                                                    //
//#############################################################################//

//The Motor PCB from top to bottom: 5V, GND // 30, 28, 36, 34, 32 // 26, 24, 22

//Motor Pins:
#define PULSE 28
#define DIR 30
#define Xmotor 32
#define Ymotor 36
#define Zmotor 34

//The Button PCB from left to right: 31, 33, 35, 37, 39, 41, 43, 45, 47, 49, 44, 46, GND

//Button Pins
#define pFinebutt 31
#define nFinebutt 33
#define fineSwitch 35 
#define pXbutt 37
#define nXbutt 39
#define pYbutt 41
#define nYbutt 43
#define pZbutt 45
#define nZbutt 47
#define servobutt 49
#define LED1 44
#define LED2 46

//Side board for now.
#define ButtScan 48

//Function Generator Pins:
#define SG_fsyncPin 22
#define SG_CLK 24
#define SG_DATA 26
#define FGPIN 4

//Top of Driver Board from left to right: 11, GND, 12, 13, MOSFET(5V), 10

//Blu-Ray Laser Pins:
#define SEL1 13
#define SEL2 12
#define LASER 11
#define LENS 10 // Due to our editing of the registers for fast PWM, this MUST be pin 10, unless you want to play with the registers, which I sure don't. 

//Analog Read Pins:
#define FGout A0
#define FE A3

//Servo Pin:
#define SERV 9

//Error handling function
void error(String msg, String value = "") {
  Serial.print("*****ERROR: ");
  Serial.print(msg);
  Serial.print(" : ");
  Serial.print(value);
  Serial.println(" ******");
  digitalWrite(LED2, HIGH);
}


//#############################################################################//
//Function Generator Functions                                                 //
//#############################################################################//
const byte numberOfDigits = 6; // number of digits in the frequense
byte freqSGLo[numberOfDigits] = {0, 0, 1, 0, 0, 0}; // 100Hz change this one if you want to change the default frequency when it turns on, if using the miniLIA, this needs to be 64x higher than the desired frequency, because minLIA be janky
byte freqSGHi[numberOfDigits] = {0, 0, 0, 0, 2, 0}; // 20kHz 

const int wSine     = 0b0000000000000000;
const int wTriangle = 0b0000000000000010;
const int wSquare   = 0b0000000000101000;

int waveType = wSquare; //This determines the wavetype when you initially turn it on.


//-----------------------------------------------------------------------------
//returns 10^y
//-----------------------------------------------------------------------------
unsigned long Power(int y) {
  unsigned long t = 1;
  for (byte i = 0; i < y; i++)
    t = t * 10;
  return t;
}

//-----------------------------------------------------------------------------
//calculate the frequency from the array.
//-----------------------------------------------------------------------------
unsigned long calcFreq(byte* freqSG) {
  unsigned long i = 0;
  for (byte x = 0; x < numberOfDigits; x++)
    i = i + freqSG[x] * Power(x);
  return i;
}

//-----------------------------------------------------------------------------
// SG_freqReset
//    reset the SG regs then set the frequency and wave type
//-----------------------------------------------------------------------------
void SG_freqReset(long frequency, int wave) {
  long fl = frequency * (0x10000000 / 25000000.0);
  SG_WriteRegister(0x2100);
  SG_WriteRegister((int)(fl & 0x3FFF) | 0x4000);
  SG_WriteRegister((int)((fl & 0xFFFC000) >> 14) | 0x4000);
  SG_WriteRegister(0xC000);
  SG_WriteRegister(wave);
  waveType = wave;
}

//-----------------------------------------------------------------------------
// SG_WriteRegister
//-----------------------------------------------------------------------------
void SG_WriteRegister(word dat) {
  digitalWrite(SG_CLK, LOW);
  digitalWrite(SG_CLK, HIGH);

  digitalWrite(SG_fsyncPin, LOW);
  for (byte i = 0; i < 16; i++) {
    if (dat & 0x8000)
      digitalWrite(SG_DATA, HIGH);
    else
      digitalWrite(SG_DATA, LOW);
    dat = dat << 1;
    digitalWrite(SG_CLK, HIGH);
    digitalWrite(SG_CLK, LOW);
  }
  digitalWrite(SG_CLK, HIGH);
  digitalWrite(SG_fsyncPin, HIGH);
  Serial.println("SG frequency written");
}

//-----------------------------------------------------------------------------
// SG_Reset
//-----------------------------------------------------------------------------
void SG_Reset() {
  delay(100);
  SG_WriteRegister(0x100);
  delay(100);
  Serial.println("SG reset");
}



//************************************************************************
//    Functions to carry out the Matlab Instructions, given a value
//************************************************************************

//Global Varables and definitions used in the functions
    // runServo()
#define SERVO_MIN 8
#define SERVO_MAX 17 // these define the limits of the servo
int servoPosition = SERVO_MIN;
Servo offsetServo;
bool servoButtPressed = false; // to keep track of button state
    // stepper()
int freq = 600;
    //runFine()
int finePos = 0; // initial fine position


// move servo to a specified position. a value of 0 will simply iterate to
// the next servo position
void runServo(int val = 0) {
  //Serial.print("RUN SERVO : ");
  //Serial.println(val);
  if (val == 0) { // if val = 0 then iterate the servo
    if (servoPosition >= SERVO_MAX) { // if above the max then go to the min
      servoPosition = SERVO_MIN;
    } else { // iterate servo position
      servoPosition ++;
    }
  } else { // write the value of val if within set bounds
    if ((val <= SERVO_MAX) && (val >= SERVO_MIN)) {
      servoPosition = val;
    } else {
      error("runServo was passed a value outside the limits of the servo", String(val));
    }
  }
  Serial.print("Servo position to: ");
  Serial.println(servoPosition);
  offsetServo.write(servoPosition); // write the servo
}

// takes the enable pin for the motor to move and the jog (micrometers) ammount
void runStepper(int pin, int jog) {
  jog = convertMicrometersToSteps(jog);
  Serial.print("runStepper pin:");
  Serial.print(pin);
  Serial.print(" jog:");
  Serial.print(jog);
  Serial.print(" DIR: ");
  Serial.println((jog<0));

  if (jog<0) { digitalWrite(DIR, HIGH); }
  else { digitalWrite(DIR, LOW); } //set DIR to 1 if jog is negative and to 0 if positive
  digitalWrite(pin,HIGH); // set the motor to move in move mode 

  jog = abs(jog);
  for (int i = 0; i < jog; i++)
  {
    digitalWrite(PULSE,HIGH);
    delayMicroseconds(freq);
    digitalWrite(PULSE,LOW);
    delayMicroseconds(freq);
  }
  digitalWrite(pin,LOW); // turn off the motor we're moving
}

// takes a value (0,255) and optionally a bool. bool triggers iterative mode
// sets the position of the fine focus of the 
void runFine(int val, bool move = false) {
  //Serial.print("RUN Fine : ");
  //Serial.println(val);
  if(move) { // if we want to iterate value and are within bounds
    if (((finePos+val) <= 255) && ((finePos+val) >= 0)) {
      finePos = finePos + val; // iterate by value
      Serial.println(finePos);
      delay(10); // delay so that a human can set it easily
    }
  } else if((val <= 255) && (val >= 0)) { // not moving and val is within bounds
    finePos = val;
    Serial.println(finePos);
  } else {
    error("Bad Fine focus value (0-255)", String(val)); // throw an error
  }
  OCR2A = finePos; // set the pwm of the fine position. it's an internal register in arduino. Voodoo
}


// turns the IR laser on and off
void irLaserToggle(bool laserOn) {
  if (laserOn) {
    //SG_freqReset(calcFreq(freqSGLo), waveType); // set frequency
    analogWrite(FGPIN,128);
    Serial.println("IR LASER on");
  } else {
    analogWrite(FGPIN,0);
    //SG_Reset(); // reset any previous commands
    Serial.println("IR LASER off");

  }
}

// truns the uv laser on and off
void uvLaserToggle(bool laserOn) {
  if (laserOn) {
    digitalWrite(SEL1, HIGH);
    digitalWrite(SEL2, HIGH);
    Serial.println("UV LASER on");
  } else {
    digitalWrite(SEL1, LOW);
    digitalWrite(SEL2, LOW);
    Serial.println("UV LASER off");

  }
}

//*****************************************************************************
//                     Serial Matlab protocol Functions                                             
//*****************************************************************************
#define parseChar ';'
/*
                  ******PROTOCOL******

         INSTRUCTION:valueInt;
          ^         ^        ^
    instruction     |   semicolon signals end of instruction
             colon seperates      
               instruction  
               from value
  
  Instructions:
    SERVO - actuate servo (14 - 18)
    XMOT - X sample table gantry in micrometers - values are movement not position
              e.g. -5 will move the stepper 5 micometers back
              ACURRACY IS NOT VERIFIED
    YMOT - ditto
    ZMOT - ditto
    FINEPOS - moves the fine focus to a position (0 - 255)
    FINEMOVE - takes a positive or negative number and moves the fine focus
                from where it already is
    IR - turn the IR laser on and off (0 off 1 on)
    UV - ditto
    
*/


/*
String rawSerialData = String(20);

// faster then readString way to read the serial input buffer
void recvWithEndMarker() {
    static byte ndx = 0;
    char endMarker = ';';
    char rc;
    byte numChars = 32;
    char receivedChars[numChars];   // an array to store the received data
    
    while (Serial.available() > 0 && newData == false) {
        rc = Serial.read();

        if (rc != endMarker) {
            receivedChars[ndx] = rc;
            ndx++;
            if (ndx >= numChars) {
                ndx = numChars - 1;
            }
        }
        else {
            receivedChars[ndx] = '\0'; // terminate the string
            ndx = 0;
            
        }
    }
}*/

// takes the raw matlab string e.g. "XMOT:15;SERVO:200;"
//    and parses along the ; and feeds each of those instructions into
//    turnTextIntoInstructions("XMOT:15")
void parseRawMatlabSerialData(String toParse) {
  int newLine;
  String instruction = String(20);
  // For every semicolon
  while(toParse.indexOf(parseChar) > 0) { // runs untill all instructions are parsed  
    newLine = toParse.indexOf(parseChar); // get index of first ;
    instruction = toParse.substring(0,newLine); // save everything to left of ; as an instruction
    toParse.remove(0,(newLine + 1)); // remove everthing to left of ;
    turnTextIntoInstructions(instruction); // run parsed instruction
  }
}


int convertMicrometersToSteps(int um) {
  float conversionFactor = 0.653817508;
  return (um*conversionFactor);
}
// Takes a String of format "INSTRUCTION:Value" Value is an int
// and runs the corresponding instruction with the value
void turnTextIntoInstructions(String toParse) {

  int colonPos = toParse.indexOf(':'); // save position of dividing ':'
    // save the stuff after the ':' as an integer
  int value = toParse.substring(colonPos + 1).toInt(); 
  
  // compare the instruction and run the corresponding function
  if(toParse.substring(0,(colonPos)) == "SERVO") { 
    runServo(value);
  } else if(toParse.substring(0,(colonPos)) == "XMOT") {  
    runStepper(Xmotor, value);
  } else if(toParse.substring(0,(colonPos)) == "YMOT") { 
    runStepper(Ymotor, value);
  } else if(toParse.substring(0,(colonPos)) == "ZMOT") { 
    runStepper(Zmotor, value);   
  } else if(toParse.substring(0,(colonPos)) == "FINEPOS") { 
    runFine(value);
  } else if(toParse.substring(0,(colonPos)) == "IR") { 
    irLaserToggle((value>0));
  } else if(toParse.substring(0,(colonPos)) == "UV") { 
    uvLaserToggle((value>0));
  } else if(toParse.substring(0,(colonPos)) == "FINEMOVE") { 
    runFine(value, true); // fine position in position mode
  } else { // Error message if we couldn't catch the command
    error("unrecognized serial command", toParse.substring(0,colonPos));
  }
}




void setup() {
  // put your setup code here, to run once:
  Serial.begin(BAUDRATE);
  Serial.setTimeout(100);

  //Motors:
  pinMode(Xmotor, OUTPUT);
  pinMode(Ymotor, OUTPUT);
  pinMode(Zmotor, OUTPUT);
  pinMode(DIR, OUTPUT);
  pinMode(PULSE, OUTPUT);

  //Function Generator:
  pinMode(SG_DATA, OUTPUT);
  pinMode(SG_CLK, OUTPUT);
  pinMode(SG_fsyncPin, OUTPUT);
  //digitalWrite(SG_fsyncPin, HIGH);
  //digitalWrite(SG_CLK, HIGH);
  //SG_Reset(); // reset any previous commands
  //SG_freqReset(calcFreq(freqSGLo), waveType); // set frequency

  pinMode(FGPIN, OUTPUT);
  irLaserToggle(false);

  //Blu-ray Laser:
  pinMode(LENS, OUTPUT);
  pinMode(SEL1, OUTPUT);
  pinMode(SEL2, OUTPUT);
  pinMode(LASER, OUTPUT);

  //Buttons:
  pinMode(pXbutt, INPUT_PULLUP);
  pinMode(nXbutt, INPUT_PULLUP);
  pinMode(pYbutt, INPUT_PULLUP);
  pinMode(nYbutt, INPUT_PULLUP);
  pinMode(pZbutt, INPUT_PULLUP);
  pinMode(nZbutt, INPUT_PULLUP);
  
  pinMode(nFinebutt, INPUT_PULLUP);
  pinMode(pFinebutt, INPUT_PULLUP);
  pinMode(fineSwitch, INPUT_PULLUP);
  pinMode(servobutt, INPUT_PULLUP);

  //indicator LEDS
  pinMode(LED1, OUTPUT);
  pinMode(LED2, OUTPUT);

  //These next two lines are kind of weird bits of code that are directly changing the Aruduino's registers. Don't touch unless you feel like you know what you're doing. 
  TCCR2A = _BV(COM2A1) | _BV(COM2B1) | _BV(WGM21) | _BV(WGM20); // see Fast PWM Mode at https://www.arduino.cc/en/pmwiki.php?n=Tutorial/SecretsOfArduinoPWM
  TCCR2B = _BV(CS20); //no prescaler ie. x/1
  
  //FAST PWM for pins 4 and 13 - UNCOMMENT the Frequency you want for the IR Laser
  //TCCR0B = TCCR0B & B11111000 | B00000011; // for PWM frequency of 976.56 Hz (The DEFAULT)

  TCCR0B = TCCR0B & B11111000 | B00000100; // for PWM frequency of 244.14 Hz

  //TCCR0B = TCCR0B & B11111000 | B00000101; // for PWM frequency of 61.04 Hz

  //TCCR5B = TCCR5B & B11111000 | B00000101; // for PWM frequency of 30.64 Hz
  
  // turn on the UV laser
  digitalWrite(LASER, HIGH); //230
  digitalWrite(SEL1, HIGH);
  digitalWrite(SEL2, HIGH);
    //SEL1 High, SEL2 Low - Red Laser
    //SEL1 Low,  SEL2 High - IR Laser
    //SEL1 High, SEL2 High - UV Laser

  // put Servo in default state
  offsetServo.attach(SERV);
  runServo(SERVO_MIN);

  // Set fine focus to default postition
  runFine(125);

}
 
void loop() {
  // wait for an instruction to come thorugh
  if(Serial.available() > 0) {
    digitalWrite(LED1, HIGH); // set processing led on
    parseRawMatlabSerialData(Serial.readString());
    digitalWrite(LED1, LOW); // turn processing led off
  }
  
  int scale = 20;


  // check for buttons 
  if(digitalRead(pXbutt) == LOW) {
    runStepper(Xmotor, scale);
  }
  if(digitalRead(nXbutt) == LOW) {
    runStepper(Xmotor, -1 *scale);
  }
  if(digitalRead(pYbutt) == LOW) {
    runStepper(Ymotor, scale);
  }
  if(digitalRead(nYbutt) == LOW) {
    runStepper(Ymotor, -1 * scale);
  }
  if(digitalRead(pZbutt) == LOW) {
    runStepper(Zmotor, scale);
  }
  if(digitalRead(nZbutt) == LOW) {
    runStepper(Zmotor, -1 * scale);
  }
  if(digitalRead(nFinebutt) == LOW) {
    runFine(-1,true);
  }
  if(digitalRead(pFinebutt) == LOW) {
    runFine(1,true);
  }
  if((digitalRead(servobutt) == LOW) && !servoButtPressed){
    runServo(0);
    servoButtPressed = true;
  }
  if(digitalRead(servobutt) == HIGH) {
    servoButtPressed = false;
  }

 


}
