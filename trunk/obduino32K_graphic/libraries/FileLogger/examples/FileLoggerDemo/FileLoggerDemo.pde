//
// Title        : FileLogger library for Arduino, example code
// Author       : Eduardo García (egarcia@stream18.com)
// Date         : April 2009
// Id			: $Id: FileLoggerDemo.pde 24 2009-04-23 22:45:13Z stream18 $
//
// DISCLAIMER:
// The author is in no way responsible for any problems or damage caused by
// using this code. Use at your own risk.
//
// LICENSE:
// This code is distributed under the GNU Public License
// which can be found at http://www.gnu.org/licenses/gpl.txt
//


#include "FileLogger.h"

// define the pin that powers up the SD card
#define MEM_PW 8

// variable used when reading from serial
byte inSerByte = 0;

#define MESSAGE "Hello, this is my message. Just testing the FileLogger library.\r\n"
unsigned long length = sizeof(MESSAGE)-1;
byte buffer[] = MESSAGE;

void setup(void) {
  pinMode(MEM_PW, OUTPUT);
  digitalWrite(MEM_PW, HIGH);
  Serial.begin(9600);
}

void loop(void) {
  char command = '0';
  unsigned long t1, t2;

  // Arduino expects one of a series of one-byte commands
  if (Serial.available() > 0) {
    int result;
    inSerByte = Serial.read();
    switch (inSerByte) {
      case 'W':
        result = FileLogger::append("data.log", buffer, length);
        Serial.print(" Result: ");
        if( result == 0) {
          Serial.println("OK");
        } else if( result == 1) {
          Serial.println("Fail initializing");
        } else if( result == 2) {
          Serial.println("Fail appending");
        }
      break;
    case 'T':
	  for(int i=0; i<10; i++) {
	      result = FileLogger::append("data.log", buffer, length);
              Serial.print(" Result: ");
              if( result == 0) {
                Serial.println("OK");
              } else if( result == 1) {
                Serial.println("Fail initializing");
              } else if( result == 2) {
                Serial.println("Fail appending");
              }
	  }
          Serial.print("Done");
      break;
    }
  }
}