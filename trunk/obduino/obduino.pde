/* OBDuino

   Copyright (C) 2008
   
   Main coding/ISO: Frédéric (aka Magister on ecomodder.com)
   Buttons/LCD/params: Dave (aka dcb on ecomodder.com)
   PWM: Nathan (aka n8thegr8 on ecomodder.com)

   This program is free software; you can redistribute it and/or modify it under
   the terms of the GNU General Public License as published by the Free Software
   Foundation; either version 2 of the License, or (at your option) any later
   version.

   This program is distributed in the hope that it will be useful, but WITHOUT
   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
   FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License along with
   this program; if not, write to the Free Software Foundation, Inc.,
   59 Temple Place, Suite 330, Boston, MA 02111-1307, USA
*/

// uncomment to send debug on serial port at 115200 bauds
#define DEBUG

#undef int    // bug from Arduino IDE 0011
#include <stdio.h>
#include <EEPROM.h>
#include <SoftwareSerial.h>
#include <LCD4Bit.h>
#include <avr/pgmspace.h>

#define obduinosig B11001100

// buttons/contrast/brightness management from mpguino.pde
#define ContrastPin 6      
#define BrightnessPin 9      
byte brightness[]={0,42,85,128}; //middle button cycles through these brightness settings
#define brightnessLength (sizeof(brightness)/sizeof(byte)) //array size
byte brightnessIdx=1;

// use analog pins as digital pins
#define lbuttonPin 17 // Left Button, on analog 3
#define mbuttonPin 18 // Middle Button, on analog 4
#define rbuttonPin 19 // Right Button, on analog 5
 
#define lbuttonBit 8 //  pin17 is a bitmask 8 on port C
#define mbuttonBit 16 // pin18 is a bitmask 16 on port C
#define rbuttonBit 32 // pin19 is a bitmask 32 on port C
#define buttonsUp   lbuttonBit + mbuttonBit + rbuttonBit  // start with the buttons in the right state      
byte buttonState = buttonsUp;      

// parms mngt from mpguino.pde too
#define contrastIdx 0  //do contrast first to get display dialed in
#define useMetric 1
char *parmLabels[]={"Contrast", "Use Metric"};
unsigned long  parms[]={15UL, 1UL};  //default values
#define parmsLength (sizeof(parms)/sizeof(unsigned long)) //array size

LCD4Bit   lcd = LCD4Bit(2);   //create a 2-lines display.

void (*topleft)(void);
void (*topright)(void);
void (*bottomleft)(void);
void (*bottomright)(void);

unsigned long delta_time;
unsigned long tank_dist=0UL;  // in cm, need to be read/write in the eeprom

/*
 * OBD-II ISO9141-2 Protocol
 * Using software serial method, lib claims speed greater
 * than 9600 bauds may be faulty, let's try.
 */

#define K_IN    2
#define K_OUT   3

SoftwareSerial ISOserial =  SoftwareSerial(K_IN, K_OUT);

/* PID stuff */
#define PID_SUPPORTED 0x00
#define NBR_CODE      0x01
#define FREEZE_DTC    0x02
#define FUEL_STATUS   0x03
#define LOAD_VALUE    0x04
#define COOLANT_TEMP  0x05
#define STF_BANK1     0x06
#define LTR_BANK1     0x07
#define STF_BANK2     0x08
#define LTR_BANK2     0x09
#define FUEL_PRESSURE 0x0A
#define MAN_PRESSURE  0x0B
#define ENGINE_RPM    0x0C
#define VEHICLE_SPEED 0x0D
#define TIMING_ADV    0x0E
#define INT_AIR_TEMP  0x0F
#define MAF_AIR_FLOW  0x10

//attach the buttons interrupt      
ISR(PCINT1_vect)
{       
  byte p = PINC;  // bypassing digitalRead for interrupt performance      

  buttonState &= p;      
}       

// inspired by SternOBDII\code\checksum.c
byte checksum(byte *data, int len)
{
  int i;
  byte crc;

  crc=0;
  for(i=0; i<len; i++)
    crc=crc+data[i];

  return crc;
}

// inspired by SternOBDII\code\iso.c
int iso_write_data(byte *data, int len)
{
  int i, n;
  
  byte buf[20];
  
  // ISO header
  buf[0]=0x68;
  buf[1]=0x6A;		// 0x68 0x6A is an OBD-II request
  buf[2]=0xF1;		// our requester’s address (off-board tool)

  // append message
  for(i=0; i<len; i++)
    buf[i+3]=data[i];
	
  // calculate checksum
  i+=3;
  buf[i]=checksum(buf, i);
  
  // send char one by one
  n=i+1;
  for(i=0; i<n; i++)
  {
    ISOserial.print(buf[i]);
    delay(20);	// inter character delay
  }
  
  return 0;
}

// read n byte of data (+ header + cmd and crc)
// return the result only in data
int iso_read_data(byte *data, int len)
{
  int i;
  
  byte buf[20];

// header 3 bytes: [80+datalen] [destination=f1] [source=01]
// data 1+len bytes: [40+cmd0] [result0]
// checksum 1 bytes: [sum(header)+sum(data)]

  for(i=0; i<3+1+1+len; i++)
    buf[i]=ISOserial.read();
  
  // test, skip header comparison
  // ignore failure for the moment (0x7f)
  // ignore crc for the moment
  
  // we send only one command, so result start at buf[4];
  memcpy(data, buf+4, len);

  return len;
}

int iso_init()
{
  byte b;

  // drive K line high for 300ms
  digitalWrite(K_OUT, HIGH);
  delay(300);

  // send 0x33 at 5 bauds
  ISOserial.begin(5);
  ISOserial.print(0x33);
  
  // pause between 60 ms and 300ms (from protocol spec)
  delay(60);

  // switch to 10400 bauds
  ISOserial.begin(10400);

  // wait for 0x55 from the ECU
  b=ISOserial.read();
  if(b!=0x55)
    return -1;

  delay(5);

  // wait for 0x08 0x08
  b=ISOserial.read();
  if(b!=0x08)
    return -1;
  b=ISOserial.read();
  if(b!=0x08)
    return -1;

  delay(25);

  // sent 0xF7 (which is ~0x08)
  ISOserial.print(0xF7);
  delay(25);

  // ECU answer by 0xCC
  b=ISOserial.read();
  if(b!=0xCC)
    return -1;
  
  // init OK!
  return 0;
}

// get value of a PID, return as a long value
// and also formatted for output in the return buffer
long get_pid(byte pid, char *retbuf)
{
  byte cmd[2];    // to send the command
  byte buf[10];   // to receive the result
  long ret;       // return value
  int reslen;
  
  cmd[0]=0x01;    // ISO cmd 1, get PID
  cmd[1]=pid;

  // send command, length 2
  iso_write_data(cmd, 2);
  
  // receive length depends on pid
  switch(pid)
  {
      case PID_SUPPORTED:
      case NBR_CODE:
        reslen=4;
        break;
      case FREEZE_DTC:
        reslen=8;
        break;
      case FUEL_STATUS:
      case ENGINE_RPM:
      case MAF_AIR_FLOW:
        reslen=2;
        break;
      case LOAD_VALUE:
      case COOLANT_TEMP:
      case STF_BANK1:
      case LTR_BANK1:
      case STF_BANK2:
      case LTR_BANK2:
      case FUEL_PRESSURE:
      case MAN_PRESSURE:
      case VEHICLE_SPEED:
      case TIMING_ADV:
      case INT_AIR_TEMP:
        reslen=1;
        break;
      default:
        reslen=0;
        break;
  }

  // read requested length, n bytes received in buf
  iso_read_data(buf, reslen);

  // formula and unit
  switch(pid)
  {
      case PID_SUPPORTED:
        ret=buf[0]<<24 + buf[1]<<16 + buf[2]<<8 + buf[3];
        sprintf_P(retbuf, PSTR("SUP:0x%04X"), ret);
        break;
      case NBR_CODE:
        ret=buf[0]<<24 + buf[1]<<16 + buf[2]<<8 + buf[3];
        sprintf_P(retbuf, PSTR("MIL:0x%04X"), ret);
        break;
      case FREEZE_DTC:
        ret=0;  // freeze DTC, return value has no meaning
        sprintf_P(retbuf, PSTR("DTC:0x%X%X%X%X%X%X%X%X"), buf[0], buf[1], buf[2], buf[3], buf[4], buf[5], buf[6], buf[7]);
        break;
      case FUEL_STATUS:
        ret=buf[0]<<8 + buf[1];
        sprintf_P(retbuf, PSTR("FUEL:0x%02X"), ret);
        break;
      case ENGINE_RPM:
        ret=(buf[0]*256 + buf[1])/4;
        sprintf_P(retbuf, PSTR("%d RPM"), ret);
        break;
      case MAF_AIR_FLOW:
        ret=(buf[0]*256 + buf[1]);  // not divided by 100 for return value!!
        sprintf_P(retbuf, PSTR("%d.%d g/s"), ret/100, ret - ((ret/100)*100));
        break;
      case LOAD_VALUE:
        ret=(buf[0]*100)/255;
        sprintf_P(retbuf, PSTR("%d %%"), ret);
        break;
      case COOLANT_TEMP:
        ret=buf[0]-40;
        sprintf_P(retbuf, PSTR("%d °C"), ret);
        break;
      case STF_BANK1:
      case LTR_BANK1:
      case STF_BANK2:
      case LTR_BANK2:
        ret=(buf[0]-128)*7812L;  // not divided by 10000
        sprintf_P(retbuf, PSTR("%d.%d %%"), ret/10000, ret-((ret/10000)*10000));
        break;
      case FUEL_PRESSURE:
        ret=buf[0]*3;
        sprintf_P(retbuf, PSTR("%d kPa"), ret);
        break;
      case MAN_PRESSURE:
        ret=buf[0];
        sprintf_P(retbuf, PSTR("%d kPa"), ret);
        break;
      case VEHICLE_SPEED:
        ret=buf[0];
        if(parms[useMetric]==0)  // convert to MPH for display
        {
          ret=(ret*621L)/1000L;
          sprintf_P(retbuf, PSTR("%d mph"), ret);
        }
        else
          sprintf_P(retbuf, PSTR("%d km/h"), ret);
        break;
      case TIMING_ADV:
        ret=(buf[0]/2)-64;
        sprintf_P(retbuf, PSTR("%d °"), ret);
        break;
      case INT_AIR_TEMP:
        ret=buf[0]-40;
        sprintf_P(retbuf, PSTR("%d °C"), ret);
        break;
      default:
        ret=0;
        sprintf_P(retbuf, PSTR("ERROR pid %d"), pid);
        break;
  }

#ifdef DEBUG
  Serial.println(retbuf);
#endif

  return ret;
}

void get_vss(void)
{
  long n;
  char str[16];
  n=get_pid(VEHICLE_SPEED, str);
  lcd.printIn(str);
}

void get_rpm(void)
{
  long n;
  char str[16];
  n=get_pid(ENGINE_RPM, str);
  lcd.printIn(str);
}

void get_load(void)
{
  long n;
  char str[16];
  n=get_pid(LOAD_VALUE, str);
  lcd.printIn(str);
}

void get_ect(void)
{
  long n;
  char str[16];
  n=get_pid(COOLANT_TEMP, str);
  lcd.printIn(str);
}

void get_maf(void)
{
  long n;
  char str[16];
  n=get_pid(MAF_AIR_FLOW, str);
  lcd.printIn(str);
}
  
void get_cons(void)
{
  long maf, vss, cons;
  char str[20];
  
  // str will be scrapped and re-used to display fuel consumption
  maf=get_pid(MAF_AIR_FLOW, str);
  vss=get_pid(VEHICLE_SPEED, str);

  // 14.7 air/fuel ratio
  // 730 g/L according to Canadian Gov
  // divide MAF by 100 because our function return MAF*100
  // formula: (3600 * MAF/100) / (14.7 * 730 * VSS)
  // multipled by 100 for double digits precision
  if(parms[useMetric]==1)
  {
    cons=(maf*3355L)/(vss*100L);
    sprintf_P(str, PSTR("%d.%2d L/100"), cons/100, (cons - ((cons/100)*100)) );
  }
  else
  {
    // single digit precision for MPG
    cons=(vss*7107L)/maf;
    sprintf_P(str, PSTR("%d.%d MPG"), cons/10, (cons - ((cons/10)*10)) );
  }

  lcd.printIn(str);
}

void get_dist(void)
{
  unsigned long  cdist;
  char str[20];
  
  // convert in hundreds of meter
  cdist=tank_dist/10000UL;
  
  // convert in miles if requested
  if(parms[useMetric]==0)
    cdist=(cdist*621UL)/1000UL;

  sprintf_P(str, PSTR("DIST:%ul.%ul"), cdist/10L, (cdist - ((cdist/10L)*10L)) );

  lcd.printIn(str);
}

void accu_dist(void)
{
  int vss;
  char str[20];
  
  vss=get_pid(VEHICLE_SPEED, str);

  // acumulate distance for this tank

  // in centimeter because for instance at 3km/h the car does
  // 0.83m/s and as we do not use float, we need to multiply by
  // 100 to have a better approximation, so in this example the
  // car does 83cm/s. As the function can be called more than one
  // time per second, the calculation is done in cm/ms

  // the car do VSS*100'000 cm/hour
  // =(VSS*100'000)/3600 cm/second (or cm/1000ms)
  // =(VSS*100'000)/3600*delta_time/1000 cm/delta_time ms
  // = VSS*delta_time/36

  delta_time = millis() - delta_time;
  tank_dist+=((unsigned long)vss*delta_time)/36UL;
}

void save(void)
{
  EEPROM.write(0, obduinosig);
  byte p = 0;
  for(int x=4; p<parmsLength; x+=4)
  {
    unsigned long v = parms[p];
    EEPROM.write(x,   (v>>24)&255);
    EEPROM.write(x+1, (v>>16)&255);
    EEPROM.write(x+2, (v>>8)&255);
    EEPROM.write(x+3, (v)&255);
    p++;
  }
}

//return 1 if loaded ok
byte load(void)
{ 
  byte b = EEPROM.read(0);
  if(b==obduinosig)
  {
    byte p=0;

    for(int x=4; p<parmsLength; x+=4)
    {
      unsigned long v = EEPROM.read(x);
      v = (v << 8) + EEPROM.read(x+1);
      v = (v << 8) + EEPROM.read(x+2);
      v = (v << 8) + EEPROM.read(x+3);
      parms[p]=v;
      p++;
    }
    return 1;
  }
  return 0;
}

void setup()                    // run once, when the sketch starts
{
  int r;
  
  // init pinouts
  pinMode(K_OUT, OUTPUT);
  pinMode(K_IN, INPUT);

  // buttons init
  pinMode( lbuttonPin, INPUT );       
  pinMode( mbuttonPin, INPUT );       
  pinMode( rbuttonPin, INPUT );      
  // "turn on" the internal pullup resistors      
  digitalWrite( lbuttonPin, HIGH);       
  digitalWrite( mbuttonPin, HIGH);       
  digitalWrite( rbuttonPin, HIGH);       
 
  // low level interrupt enable stuff
  // interrupt 1 for the 3 buttons
  PCICR |= (1 << PCIE1);       
  PCMSK1 |= (1 << PCINT11);       
  PCMSK1 |= (1 << PCINT12);       
  PCMSK1 |= (1 << PCINT13);           

  // LCD contrast/brightness init
  analogWrite(ContrastPin, parms[contrastIdx]);  
  analogWrite(BrightnessPin, 255-brightness[brightnessIdx]);      

  lcd.clear();
  lcd.printIn("OBD-II ISO9141-2");

  r=iso_init();
  if(r==0)
  {
    lcd.printIn("Init ISO Failed!");
    delay(30000);
  }

#ifdef DEBUG
  Serial.begin(115200);  // for debugging
  Serial.println(memoryTest());
  if(r==0)
    Serial.println("Init OK!");
  else
    Serial.println("Init failed!");
#endif
    
  topleft=get_cons;
  topright=get_vss;
  bottomleft=get_rpm;
  bottomright=get_load;
  
  delta_time=millis();
}

void loop()                     // run over and over again
{
  // display on LCD
  lcd.cursorTo(0,0);
  topleft();
  lcd.cursorTo(0,8);
  topright();
  lcd.cursorTo(1,0);
  bottomleft();
  lcd.cursorTo(1,8);
  bottomright();  

  accu_dist();    // accumulate distance
  
  // test buttons
  if(!(buttonState&mbuttonBit))
  {
    //middle is cycle through brightness settings      
    brightnessIdx = (brightnessIdx + 1) % brightnessLength;
    analogWrite(BrightnessPin, 255-brightness[brightnessIdx]);      
  }
  buttonState=buttonsUp;
}

// this function will return the number of bytes currently free in RAM      
extern int  __bss_end; 
extern int  *__brkval; 
int memoryTest()
{ 
  int free_memory; 
  if((int)__brkval == 0) 
    free_memory = ((int)&free_memory) - ((int)&__bss_end); 
  else 
    free_memory = ((int)&free_memory) - ((int)__brkval); 
  return free_memory; 
} 
