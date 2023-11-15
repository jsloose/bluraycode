// File to read data from BMP388 and write to microSD card

// Libraries for BMP388
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include "Adafruit_BMP3XX.h"

// Libraries for card reader
#include <SPI.h>
#include <SD.h>

// Objects for BMP388 and card module
#define SEALEVELPRESSURE_HPA (1013.25)
Adafruit_BMP3XX bmp;
File myFile;

// This section runs once. In this section, the text file
// is created and data is written to it.
void setup() {
  // Open serial communications and wait for port to open
  Serial.begin(9600);
  
  while (!Serial) {
    ; // wait for serial port to connect. Needed for native USB port only
  }

  // Initialize communication with microSD card
  Serial.print("Initializing SD card...");
  if (!SD.begin(10)) {
    Serial.println("initialization failed!");
    while (1);
  }
  Serial.println("initialization done.");

  // Check for connection to sensor
  if (!bmp.begin()) {
    Serial.println("BMP388 sensor not found. Check wiring.");
    while (1);
  }

  // Open the file that will be written to. Only one file can be open
  // at a time, so this one would have to be closed before opening another.
  myFile = SD.open("test.txt", FILE_WRITE);

  // Write 100 data points to file. If the file exists, the 100 data points
  // will be appended to the end of the file.
  for (int i = 0; i < 100; i++) {
    // If the file opened okay, write to it
    if (myFile) {
      // Read and print temperature, pressure, and altitude from sensor
      // Check for successful reading
      if (! bmp.performReading()) {
        Serial.println("Failed to perform reading :(");
        return;
      }
      Serial.print(micros()/1e6, 3);
      Serial.print(" ");
      Serial.print(bmp.temperature, 8);
      Serial.print(" C ");
      Serial.print(bmp.pressure, 8);
      Serial.print(" Pa ");
      Serial.print(bmp.readAltitude(SEALEVELPRESSURE_HPA), 8);
      Serial.print(" m");
      Serial.println(" Writing to test.txt...");
      myFile.print(micros()/1e6, 8);
      myFile.print(" ");
      myFile.print(bmp.temperature, 8);
      myFile.print(" ");
      myFile.print(bmp.pressure, 8);
      myFile.print(" ");
      myFile.println(bmp.readAltitude(SEALEVELPRESSURE_HPA), 8);
    }
    else {
      // if the file didn't open, print an error:
      Serial.println("error opening test.txt");
    }
  }
  // Print blank line after 100th data point to make it easier
  // to find where new data sets begin
  myFile.println(" ");

  // close the file:
  myFile.close();
  Serial.println("Done.");
}

// Nothing is needed here.
void loop() {
  // Check for successful reading
}
