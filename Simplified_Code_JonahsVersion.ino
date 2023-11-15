#include <math.h>
#include <Servo.h>
#include <SPI.h>
#include <SD.h>

const long BAUDRATE  = 115200;

Servo myservo;
File myFile;

//#############################################################################//
//QUICK OPTIONS                                                                //
//#############################################################################//

//Serial Read the function generator:
bool FG_read = true;

//Auto Focusing:
bool AutoFocusing = false;
// Map dimensions and resolution
int sampleAreaSize = 80; // number of measurements on one side of the map square
int stepsize = 150;
int reading = 0;
int xdir = 1;


//#############################################################################//
//PIN SETUP                                                                    //
//#############################################################################//

//The Motor PCB from top to bottom: 5V, GND // 30, 28, 36, 34, 32 // 26, 24, 22

//Motor Pins:
#define PULSE 28
#define DIR 30
#define Xmotor 32
#define Ymotor 34
#define Zmotor 36

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


//-----------------------------------------------------------------------------
// Global Variables
//-----------------------------------------------------------------------------

const byte numberOfDigits = 6; // number of digits in the frequense
byte freqSGLo[numberOfDigits] = {0, 0, 1, 0, 0, 0}; // 100Hz change this one if you want to change the default frequency when it turns on, if using the miniLIA, this needs to be 64x higher than the desired frequency, because minLIA be janky
byte freqSGHi[numberOfDigits] = {0, 0, 0, 0, 2, 0}; // 20kHz 

const int wSine     = 0b0000000000000000;
const int wTriangle = 0b0000000000000010;
const int wSquare   = 0b0000000000101000;

int waveType = wSquare; //This determines the wavetype when you initially turn it on.

int freq = 500;
int i = 0;

int delaytime = 100;
int Fineposition = 200;
int angle = 13;

//#############################################################################//
//#############################################################################//
//Function Generator Functions                                                 //
//#############################################################################//
//#############################################################################//


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
// SerialCommand
//   if a byte is available in the seril input buffer
//   execute it as a command
//-----------------------------------------------------------------------------
void SerialCommand(void) {
  if ( Serial.available() > 0 ) {
    char c = Serial.read();

    if ((c >= '0') && (c <= '9')) {
      for (int i=5; i>0; i--) freqSGLo[i] = freqSGLo[i-1];
      freqSGLo[0] = c - '0';
    } else {
      switch (c) {
        case 'S': waveType = wSine; SG_freqReset(calcFreq(freqSGLo), waveType); break;   // SigGen wave is sine
        case 'T': waveType = wTriangle; SG_freqReset(calcFreq(freqSGLo), waveType); break;   // SigGen wave is triangle
        case 'Q': waveType = wSquare; SG_freqReset(calcFreq(freqSGLo), waveType); break;   // SigGen wave is square

        default: return;  
      }
    }
  }
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
}

//-----------------------------------------------------------------------------
// SG_Reset
//-----------------------------------------------------------------------------
void SG_Reset() {
  delay(100);
  SG_WriteRegister(0x100);
  delay(100);
}

//#############################################################################//
//#############################################################################//
//Motor Functions                                                              //
//#############################################################################//
//#############################################################################//

void xpos(int jog)
{
  digitalWrite(DIR,0); 
  digitalWrite(Xmotor,1);
  for (i = 0; i < jog; i++)
  {
    digitalWrite(PULSE,0);
    delayMicroseconds(freq);
    digitalWrite(PULSE,1);
    delayMicroseconds(freq);
  }
  digitalWrite(Xmotor,0);
}

void xneg(int jog)
{
  digitalWrite(DIR,1);
  digitalWrite(Xmotor,1);
  for (i = 0; i < jog; i++)
  {
    digitalWrite(PULSE,0);
    delayMicroseconds(freq);
    digitalWrite(PULSE,1);
    delayMicroseconds(freq);
  }
  digitalWrite(Xmotor,0);
}

void ypos(int jog)
{
  digitalWrite(DIR,1);
  digitalWrite(Ymotor,1);
  for (i = 0; i < jog; i++)
  {
    digitalWrite(PULSE,0);
    delayMicroseconds(freq);
    digitalWrite(PULSE,1);
    delayMicroseconds(freq);
  }
  digitalWrite(Ymotor,0);
}

void yneg(int jog)
{
  digitalWrite(DIR,0);
  digitalWrite(Ymotor,1);
  for (i = 0; i < jog; i++)
  {
    digitalWrite(PULSE,0);
    delayMicroseconds(freq);
    digitalWrite(PULSE,1);
    delayMicroseconds(freq);
  }
  digitalWrite(Ymotor,0);
}

void zpos(int jog)
{
  digitalWrite(DIR,0);
  digitalWrite(Zmotor,1);
  for (i = 0; i < jog; i++)
  {
    digitalWrite(PULSE,0);
    delayMicroseconds(freq);
    digitalWrite(PULSE,1);
    delayMicroseconds(freq);
  }
  digitalWrite(Zmotor,0);
}

void zneg(int jog)
{
  digitalWrite(DIR,1);
  digitalWrite(Zmotor,1);
  for (i = 0; i < jog; i++)
  {
    digitalWrite(PULSE,0);
    delayMicroseconds(freq);
    digitalWrite(PULSE,1);
    delayMicroseconds(freq);
  }
  digitalWrite(Zmotor,0);
}

//#############################################################################//
//#############################################################################//
//AUTO-FOCUSING FUNCTION                                                       //
//#############################################################################//
//#############################################################################//

void FocusLaser() 
{
  int focusing = 0    ;  // set to 0 to auto focus, 1 to hold steady
  
  if (focusing == 1)
  {
    OCR2A = 250; //130 neutral height
  }
  else
  {
    int sensorMin = 1023;        // minimum sensor value
    int sensorMax = 0;           // maximum sensor value
    int x = 1;
    for (int i = 0; i > -1; i = i + x) //move lens up and down once
    {
      int fe = analogRead(FE);
      
      Serial.print("FE = ");
      Serial.print(fe);
      Serial.print("\n");

      
      OCR2A = i;
      if (i == 255) {
      x = -1;       //switch direction at peak https://www.arduino.cc/en/reference/for
      delay(5);
      }
  
      // record the maximum sensor value see https://www.arduino.cc/en/Tutorial/Calibration
      if (fe > sensorMax) {
        sensorMax = fe;
      }
  
      // record the minimum sensor value
      if (fe < sensorMin) {
        sensorMin = fe;
      }
    }
  
    //if there isn't a max over a certain value generate an error
  
    //determine the amplitue of the S-curve
    int amp = sensorMax - sensorMin;
  
    //calculate a upper and lower acceptable postion for the laser to be focused see http://www.diyouware.com/img/image037.jpg
    int fe_focus_position_pos = 506 + (amp / 16);
    int fe_focus_position_neg = 506 - (amp / 16);
    int motor_pwm_position_value = 0;

    Serial.print("Amp = ");
    Serial.print(amp);
    Serial.print("\n");

    Serial.print("fe_focus_pos = ");
    Serial.print(fe_focus_position_pos);
    Serial.print("\n");

    Serial.print("fe_focus_neg = ");
    Serial.print(fe_focus_position_neg);
    Serial.print("\n");

    Serial.println("Pre-delay");  
    delay(1000);
    
    x = 1;
    int i = 1;
    
    do    //do while loop, moves lens top to bottom while the fe signal is not equal to the upper or lower focus limit(fe_focus_position_pos/neg)
    {
      
      int fe = analogRead(FE);
      Serial.println(fe);
      
      OCR2A = i; //sets lens at top
      i = i + x;
      if (i % 255 == 1) i = 1;    //if its at the bottom it resets to top, ie. if i is divisible exactly by 255 it means the lens is at the bottom
      motor_pwm_position_value = i;
      delayMicroseconds(500);
      
             //   } while (analogRead(FE) > fe_focus_position_pos || analogRead(FE) < fe_focus_position_neg || analogRead(FE) < 510 || analogRead(FE) > 502);
     } 
    while (analogRead(FE) != fe_focus_position_pos && analogRead(FE) != fe_focus_position_neg);   // more consistent but takes longer
    OCR2A = motor_pwm_position_value;

    Serial.println("Did someobody say the Door to Darkness?");
  }
    
}

//#############################################################################//
//#############################################################################//
//Sam's Servos                                                                 //
//#############################################################################//
//#############################################################################//
void servyobutt(){
    digitalWrite(LED2, HIGH);
    
    if (angle == 13) {
      angle = 15;
      myservo.write(angle);
      delay(100);
    }
    else if (angle == 15) {
      angle = 17;
      myservo.write(angle);
      delay(100);
    }
    else if (angle ==17) {
      angle = 19;
      myservo.write(angle);
      delay(100);
    }
    else if (angle == 19){
      angle = 13;
      myservo.write(angle);
      delay(100);
    }
    delay(1000);
    digitalWrite(LED2, LOW);

    Serial.println();

}
    

void scanButt(int cycles){
    // FOCUSING FUNCTION
    // The default finefocus lens position can be found in the SETUP function
    myFile = SD.open("test.txt", FILE_WRITE);
    cycles = 1;
    OCR2A = 250;
    int sampleLength = 300;
    int NumSamp = 24;
    int calstep = 5;
    int ydir = 1;
    int hcor = 0;
    if (myFile) {
      Serial.print("Writing to test.txt...");
      for (int g=0; g< NumSamp; g++) {
          for (int h=0; h< sampleLength; h++) {
            reading = analogRead(FGout);
            if (ydir>0){
              hcor = h;  // moving to bottom to top as normal (1,2,3...)
            }
            else {
              hcor = sampleLength - h - 1;  // scanning down corrected h (3,2,1...)
            }
            myFile.print(reading);
            myFile.print(", ");
            myFile.print(g);
            myFile.print(", ");
            myFile.print(hcor);
            myFile.print("\n");
            reading = 0;
            if (ydir>0){
              ypos(calstep);
            }
            else {
              yneg(calstep);
            }
            //delay(50);

          }
          //turn around
          ydir = -1*ydir;
          xpos(10);
          yneg(50);  // account for drift
          // Change Lens Focus
          OCR2A = OCR2A - 2;
          delay(100);
    }
      // Close the file
      myFile.close();
      Serial.println("done.");
    }
    
    else {
      // If the file didn't open, print an error
      Serial.println("error opening test.txt");
    }

/*  
    // 1 - Open the file we will write to
    // 2 - Read FGout multiple times (TBD) for noise averaging
    // 3 - Change the locations of the sample
    // 4 - Repeat steps 2 and 3 as needed (TBD)
    // 5 - Close the file.
    
    
    // COMMENTED OUT FOR FOCUSING FUNCTION
    myFile = SD.open("test.txt", FILE_WRITE);
    cycles = 1;

    if (myFile) {
      Serial.print("Writing to test.txt...");
      //myFile.println("This is a test file :)");
      //myFile.println("testing 1, 2, 3.");
        int xdir = 1;
        int gcor = 0;
        for (int h=0; h< sampleAreaSize; h++) {
          for (int g=0; g< sampleAreaSize; g++) {
            for (int i = 0; i < 20; i++) {
              reading = reading + analogRead(FGout)/20;
              delay(10);
            }
            if (xdir>0){
              gcor = g;  // moving to the right (read right-to-left as normal)
            }
            else {
              gcor = sampleAreaSize - g  - 1;  // moving to the left (corrected g = taking into account that the values are being read right-to-left)
            }
            myFile.print(reading);
            myFile.print(", ");
            myFile.print(gcor);
            myFile.print(", ");
            myFile.print(h);
            myFile.print("\n");
            reading = 0;
            if (xdir>0){
              xpos(stepsize);
            }
            else {
              xneg(stepsize);
            }
            delay(10);
          }
          ypos(stepsize);
          xdir = -1*xdir;
          delay(10);
        }
        // Close the file
      myFile.close();
      Serial.println("done.");
      // Tell the lazer to go home
      yneg(stepsize*sampleAreaSize);
      }

    else {
      // If the file didn't open, print an error
      Serial.println("error opening test.txt");
    }

  //xpos(20);
  //xneg(20);
  //ypos(20);
  //yneg(20);
   
    */

    
}


//#############################################################################//
//#############################################################################//
//#############################################################################//
//MAIN CODE                                                                    //
//#############################################################################//
//#############################################################################//
//#############################################################################//

void setup() {

  Serial.begin(BAUDRATE);
  OCR2A = 250; // default finefocus position

  // Initialize communication with microSD card
  Serial.print("Initializing SD card...");
  if (!SD.begin(53)) {
    Serial.println("initialization failed!");
    while (1);
  }
  Serial.println("initialization done.");

  //Servo Pin Setup (20 - 30):
  myservo.attach(SERV);
  myservo.write(13);

  //Function Generator:
  pinMode(SG_DATA, OUTPUT);
  pinMode(SG_CLK, OUTPUT);
  pinMode(SG_fsyncPin, OUTPUT);
  digitalWrite(SG_fsyncPin, HIGH);
  digitalWrite(SG_CLK, HIGH);
  SG_Reset();
  SG_freqReset(calcFreq(freqSGLo), waveType);

  //Motors:
  pinMode(Xmotor, OUTPUT);
  pinMode(Ymotor, OUTPUT);
  pinMode(Zmotor, OUTPUT);
  pinMode(DIR, OUTPUT);
  pinMode(PULSE, OUTPUT);

  //Buttons:
  pinMode(pXbutt, INPUT_PULLUP);https://learn.sparkfun.com/tutorials/usb-serial-driver-quick-install-/all#:~:text=The%20Arduino%20Uno%20will%20appear%20as%20a%20ttyACMXX%20device.,see%20our%20in%2Ddepth%20instructions.
  pinMode(nXbutt, INPUT_PULLUP);
  pinMode(pYbutt, INPUT_PULLUP);
  pinMode(nYbutt, INPUT_PULLUP);
  pinMode(pZbutt, INPUT_PULLUP);
  pinMode(nZbutt, INPUT_PULLUP);
  
  pinMode(nFinebutt, INPUT_PULLUP);
  pinMode(pFinebutt, INPUT_PULLUP);
  pinMode(fineSwitch, INPUT_PULLUP);
  pinMode(servobutt, INPUT_PULLUP);

  pinMode(ButtScan, INPUT_PULLUP);

  //indicator LEDS
  pinMode(LED1, OUTPUT);
  pinMode(LED2, OUTPUT);
  
  //Blu-ray Laser:
  pinMode(LENS, OUTPUT);
  pinMode(SEL1, OUTPUT);
  pinMode(SEL2, OUTPUT);
  pinMode(LASER, OUTPUT);
  
  //These next two lines are kind of weird bits of code that are directly changing the Aruduino's registers. Don't touch unless you feel like you know what you're doing. 
  
  TCCR2A = _BV(COM2A1) | _BV(COM2B1) | _BV(WGM21) | _BV(WGM20); // see Fast PWM Mode at https://www.arduino.cc/en/pmwiki.php?n=Tutorial/SecretsOfArduinoPWM
  TCCR2B = _BV(CS20); //no prescaler ie. x/1
  
  analogWrite(LASER, 230); //230
  digitalWrite(SEL1, HIGH);
  digitalWrite(SEL2, HIGH);
    //SEL1 High, SEL2 Low - Red Laser
    //SEL1 Low,  SEL2 High - IR Laser
    //SEL1 High, SEL2 High - UV Laser

    if(AutoFocusing == true){
    Serial.println("Pre Function");
    FocusLaser();
    Serial.println("Hallo Gov'na");
    }
  
}
  

void loop() {
  
  SerialCommand();

   if(digitalRead(servobutt) == LOW){
   servyobutt();
  }

  //Serial.println("Ya' Crackhead");


  if(FG_read == true){
    Serial.println(analogRead(FGout));
    }


  //Serial.println(analogRead(FE));


  if(digitalRead(fineSwitch) == LOW){
    delaytime = 200;
  }
  else{
    delaytime = 20;
  }

  if(digitalRead(nFinebutt) == LOW){
    if(Fineposition > 0){
      Fineposition = Fineposition - 1;
      }
    else{
      Fineposition = Fineposition;
      }
    OCR2A = Fineposition;
    delay(delaytime);
    }

  if(digitalRead(pFinebutt) == LOW){
    if(Fineposition < 255){
      Fineposition = Fineposition + 1;
      }
    else{
      Fineposition = Fineposition;
      }
   OCR2A = Fineposition;
   delay(delaytime);
    }
    

  if(digitalRead(pXbutt) == LOW){
    xpos(20);
    }
  if(digitalRead(nXbutt) == LOW){
    xneg(20);
    }
  if(digitalRead(pYbutt) == LOW){
    ypos(20);
    }
  if(digitalRead(nYbutt) == LOW){
    yneg(20);
    }
  if(digitalRead(pZbutt) == LOW){
    zpos(20);
    }
  if(digitalRead(nZbutt) == LOW){
    zneg(20);
    }


    //Scanning Process

  if(digitalRead(ButtScan) == LOW){
    
    scanButt(sampleAreaSize);
  }

    //Serial.println(Fineposition);

}
