/*
 * TODO
 *
 * Test it!
 * Implement buttons/menu configuration
 * read/save params from the EEPROM
 *
 */

// comment to use MC33290 ISO K line chip
// uncomment to use ELM327
#define ELM 0

/* OBDuino

 Copyright (C) 2008

 Main coding/ISO/ELM: Frédéric (aka Magister on ecomodder.com)
 Buttons/LCD/params: Dave (aka dcb on ecomodder.com)
 Soon:
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

#undef int    // bug from Arduino IDE 0011
#include <stdio.h>
#include <avr/eeprom.h>
#include <avr/pgmspace.h>

#define obduinosig B11001100

// buttons/contrast/brightness management from mpguino.pde
//LCD Pins
#define DIPin 4 // register select RS
#define DB4Pin 7
#define DB5Pin 8
#define DB6Pin 12
#define DB7Pin 13
#define ContrastPin 6
#define EnablePin 5
#define BrightnessPin 9

//LCD prototype
class LCD
{
public:
  LCD();
  void gotoXY(byte x, byte y);
  void print(char *string);
  void cls();
  void init();
  void tickleEnable();
  void cmdWriteSet();
  void LcdCommandWrite(byte value);
  void LcdDataWrite(byte value);
  void pushNibble(byte value);
};

// main object to play with
LCD lcd;

byte brightness[]={
  0,42,85,128}; //middle button cycles through these brightness settings
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
#define useMetricIdx 1
char *parmLabels[]={
  "Contrast", "Use Metric"};
unsigned long  parms[]={
  15UL, 1UL};  //default values
#define parmsLength (sizeof(parms)/sizeof(unsigned long)) //array size

#ifdef ELM
#define NUL     '\0'
#define CR      '\r'  // carriage return = 0x0d = 13
#define PROMPT  '>'
#else
/*
 * OBD-II ISO9141-2 Protocol
 */
#define K_IN    2
#define K_OUT   3
// bit period for 10400 bauds = 1000000/10400 = 96
#define _bitPeriod 1000000L/10400L
#endif

/* PID stuff */

unsigned long  pid01to20_support=0;
unsigned long  pid21to40_support=0;
#define PID_SUPPORT20 0x00
#define MIL_CODE      0x01
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
#define THROTTLE_POS  0x11
#define SEC_AIR_STAT  0x12
#define OXY_SENSORS1  0x13
#define B1S1OXY_SENS_SFT 0x14
#define B1S2OXY_SENS_SFT 0x15
#define B1S3OXY_SENS_SFT 0x16
#define B1S4OXY_SENS_SFT 0x17
#define B2S1OXY_SENS_SFT 0x18
#define B2S2OXY_SENS_SFT 0x19
#define B2S3OXY_SENS_SFT 0x1A
#define B2S4OXY_SENS_SFT 0x1B
#define OBD_STD       0x1C
#define OXY_SENSORS2  0x1D
#define AUX_INPUT     0x1E
#define RUNTIME_START 0x1F
#define PID_SUPPORT40 0x20

#define LAST_PID      0x20  // same as the last one defined above

/* our internal fake PIDs */
#define NO_DISPLAY    0xF0
#define FUEL_CONS     0xF1
#define TANK_DIST     0xF2

// returned length of the PID response.
// constants so put in flash
prog_uchar pid_reslen[] PROGMEM=
{
  // pid 0x00 to 0x1F
  4,4,8,2,1,1,1,1,1,1,1,1,2,1,1,1,
  2,1,1,1,2,2,2,2,2,2,2,2,1,1,1,2,

  // pid 0x20 to whatever
  4
};

// for the 4 display corners
byte topleft;
byte topright;
byte bottomleft;
byte bottomright;

// for distance
unsigned long delta_time;
unsigned long tank_dist=0UL;  // in cm, need to be read/write in the eeprom

//attach the buttons interrupt
ISR(PCINT1_vect)
{
  byte p = PINC;  // bypassing digitalRead for interrupt performance

  buttonState &= p;
}

#ifdef ELM
/* each ELM response ends with '\r' followed at the end by the prompt
so read com port until we find a prompt */
void elm_read(char *buf, byte size)
{
  int b;
  byte i;
  
  // wait for something on com port
  while(Serial.available()==0)
  {
     // nothing, maybe we should sleep?
  }

  i=0;
  while((b=Serial.read())!=PROMPT && i<size)
  {
    if(b!=-1)
      buf[i++]=b;
  }
    
  // replace CR/prompt by 0 to make the string ASCIIZ
  buf[i-1]=NUL;
}

byte elm_compact_response(char *buf)
{
    byte i;
    char *newb=buf;
    char c;
    
    // start at 6 which is the first hex byte after header
    // ex: 41 0C 1A F8
    // return string: 1AF8
    
    i=0;
    buf+=6;
    while((c=*buf++)!=NUL)
      if(c!=' ')
        newb[i++]=c;
    
    newb[i]=NUL;
    
    return 0;
}

int elm_init()
{
#define BUFLEN  16
  char buf[BUFLEN];
  
  Serial.begin(9600);
  
  // wait for something, at least a prompt
  elm_read(buf, BUFLEN);
  Serial.print("ATI\r");
  elm_read(buf, BUFLEN);
  lcd.gotoXY(0,1);
  lcd.print(buf);
  delay(1000);
  
  /*
  send ATI1 or AT@1 or whatever string to get some info
  send ATDPN to get protocol number
  if connected return 0
  */

  return 0;
}
#else
int iso_read_byte()
{
  int val = 0;
  int bitDelay = _bitPeriod - clockCyclesToMicroseconds(50);
  unsigned long timeout;
  
  // one byte of serial data (LSB first)
  // ...--\    /--\/--\/--\/--\/--\/--\/--\/--\/--...
  //	 \--/\--/\--/\--/\--/\--/\--/\--/\--/
  //	start  0   1   2   3   4   5   6   7 stop

  timeout=millis();
  while (digitalRead(K_IN))    // wait for start bit
  {
      if((millis()-timeout) > 300L)  // timeout after 300ms
        return -1;
  }

  // confirm that this is a real start bit, not line noise
  if (digitalRead(K_IN) == LOW)
  {
    // frame start indicated by a falling edge and low start bit
    // jump to the middle of the low start bit
    delayMicroseconds(bitDelay / 2 - clockCyclesToMicroseconds(50));
	
    // offset of the bit in the byte: from 0 (LSB) to 7 (MSB)
    for (int offset = 0; offset < 8; offset++)
    {
	// jump to middle of next bit
	delayMicroseconds(bitDelay);
	// read bit
	val |= digitalRead(K_IN) << offset;
    }
    delayMicroseconds(_bitPeriod);
    return val;
  }
  return -1;
} 

void iso_write_byte(byte b)
{
  int bitDelay = _bitPeriod - clockCyclesToMicroseconds(50); // a digitalWrite is about 50 cycles

  digitalWrite(K_OUT, LOW);
  delayMicroseconds(bitDelay);

  for (byte mask = 0x01; mask; mask <<= 1)
  {
    if (b & mask) // choose bit
      digitalWrite(K_OUT, HIGH); // send 1
    else
      digitalWrite(K_OUT, LOW); // send 0
    delayMicroseconds(bitDelay);
  }
  digitalWrite(K_OUT, HIGH);
  delayMicroseconds(bitDelay); 
}
  
// inspired by SternOBDII\code\checksum.c
byte iso_checksum(byte *data, byte len)
{
  byte i;
  byte crc;

  crc=0;
  for(i=0; i<len; i++)
    crc=crc+data[i];

  return crc;
}

// inspired by SternOBDII\code\iso.c
byte iso_write_data(byte *data, byte len)
{
  byte i, n;
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
  buf[i]=iso_checksum(buf, i);

  // send char one by one
  n=i+1;
  for(i=0; i<n; i++)
  {
    iso_write_byte(buf[i]);
    delay(20);	// inter character delay
  }

  return 0;
}

// read n byte of data (+ header + cmd and crc)
// return the result only in data
byte iso_read_data(byte *data, byte len)
{
  byte i;
  byte buf[20];

  // header 3 bytes: [80+datalen] [destination=f1] [source=01]
  // data 1+len bytes: [40+cmd0] [result0]
  // checksum 1 bytes: [sum(header)+sum(data)]

  for(i=0; i<3+1+1+len; i++)
    buf[i]=iso_read_byte();

  // test, skip header comparison
  // ignore failure for the moment (0x7f)
  // ignore crc for the moment

  // we send only one command, so result start at buf[4];
  memcpy(data, buf+4, len);

  return len;
}

/* ISO 9141 init */
byte iso_init()
{
  byte b;

  // drive K line high for 300ms
  digitalWrite(K_OUT, HIGH);
  delay(300);

  // send 0x33 at 5 bauds
  // start bit
  digitalWrite(K_OUT, LOW);
  delay(200);
  // data
  b=0x33;
  for (byte mask = 0x01; mask; mask <<= 1)
  {
    if (b & mask) // choose bit
      digitalWrite(K_OUT, HIGH); // send 1
    else
      digitalWrite(K_OUT, LOW); // send 0
    delay(200);
  }
  // stop bit
  digitalWrite(K_OUT, HIGH);
  delay(200); 

  // pause between 60 ms and 300ms (from protocol spec)
  delay(60);

  // switch now to 10400 bauds

  // wait for 0x55 from the ECU
  b=iso_read_byte();
  if(b!=0x55)
    return -1;

  delay(5);

  // wait for 0x08 0x08
  b=iso_read_byte();
  if(b!=0x08)
    return -1;

  delay(20);

  b=iso_read_byte();
  if(b!=0x08)
    return -1;

  delay(25);

  // sent 0xF7 (which is ~0x08)
  iso_write_byte(0xF7);
  
  delay(25);

  // ECU answer by 0xCC
  b=iso_read_byte();
  if(b!=0xCC)
    return -1;

  // init OK!
  return 0;
}
#endif

// get value of a PID, return as a long value
// and also formatted for output in the return buffer
long get_pid(byte pid, char *retbuf)
{
  byte i;
  byte cmd[2];    // to send the command
#ifdef ELM
  char buf[40];   // to receive the result
#else
  byte buf[10];   // to receive the result
#endif
  long ret;       // return value
  byte reslen;

  // check if PID is supported
  if( (1L<<(pid-1) & pid01to20_support) == 0)
  {
    // nope
    retbuf[0]='\0';
    return -1;
  }

  cmd[0]=0x01;    // ISO cmd 1, get PID
  cmd[1]=pid;

#ifdef ELM
  // use retbuf to send the command
  // it will be scrapped after
  sprintf_P(retbuf, PSTR("%02x%02x\r"), cmd[0], cmd[1]);
  Serial.print(retbuf);
#else
  // send command, length 2
  iso_write_data(cmd, 2);
#endif

  // receive length depends on pid
  if(pid<=LAST_PID)
    reslen=pgm_read_byte_near(pid_reslen+pid);
  else
    reslen=0;

#ifdef ELM
  elm_read(buf, 40);
  // first 2 bytes should be 0x41 and command, skip them
  // and remove spaces by calling a function
  elm_compact_response(buf);
  Serial.print("(");
  Serial.print(buf[0], HEX);
  if(buf[1]!=NUL)
    Serial.print(buf[1], HEX);
  Serial.print(")");
#else
  // read requested length, n bytes received in buf
  iso_read_data(buf, reslen);
#endif

  // formula and unit
  switch(pid)
  {
  case ENGINE_RPM:
    ret=(buf[0]<<8L + buf[1])/4L;
    sprintf_P(retbuf, PSTR("%ld RPM"), ret);
    break;
  case MAF_AIR_FLOW:
    ret=(buf[0]<<8 + buf[1]);  // not divided by 100 for return value!!
    sprintf_P(retbuf, PSTR("%ld.%ld g/s"), ret/100, ret - ((ret/100)*100));
    break;
  case LOAD_VALUE:
  case THROTTLE_POS:
    ret=(buf[0]*100)/255;
    sprintf_P(retbuf, PSTR("%ld %%"), ret);
    break;
  case COOLANT_TEMP:
  case INT_AIR_TEMP:
    ret=buf[0]-40;
    sprintf_P(retbuf, PSTR("%ld °C"), ret);
    break;
  case STF_BANK1:
  case LTR_BANK1:
  case STF_BANK2:
  case LTR_BANK2:
    ret=(buf[0]-128)*7812L;  // not divided by 10000
    sprintf_P(retbuf, PSTR("%ld.%ld %%"), ret/10000, ret-((ret/10000)*10000));
    break;
  case FUEL_PRESSURE:
    ret=buf[0]*3;
    sprintf_P(retbuf, PSTR("%ld kPa"), ret);
    break;
  case MAN_PRESSURE:
    ret=buf[0];
    sprintf_P(retbuf, PSTR("%ld kPa"), ret);
    break;
  case VEHICLE_SPEED:
    ret=buf[0];
    if(parms[useMetricIdx]==0)  // convert to MPH for display
    {
      ret=(ret*621L)/1000L;
      sprintf_P(retbuf, PSTR("%ld mph"), ret);
    }
    else
      sprintf_P(retbuf, PSTR("%ld km/h"), ret);
    break;
  case TIMING_ADV:
    ret=(buf[0]/2)-64;
    sprintf_P(retbuf, PSTR("%ld °"), ret);
    break;
  case OBD_STD:
    ret=buf[0];
    switch(buf[0])
    {
      case 0x01:
        sprintf_P(retbuf, PSTR("OBD2-CARB"));
        break;
      case 0x02:
        sprintf_P(retbuf, PSTR("OBD2-EPA"));
        break;
      case 0x03:
        sprintf_P(retbuf, PSTR("OBD1&2"));
        break;
      case 0x04:
        sprintf_P(retbuf, PSTR("OBD1"));
        break;
      case 0x05:
        sprintf_P(retbuf, PSTR("NOT OBD"));
        break;
      case 0x06:
        sprintf_P(retbuf, PSTR("EOBD"));
        break;
      default:
        sprintf_P(retbuf, PSTR("OBD:%02X"), buf[0]);
        break;
    }
    break;
  // for the moment, everything else, display the raw answer
  case PID_SUPPORT20:
  case MIL_CODE:
  case FREEZE_DTC:
  case FUEL_STATUS:
  case PID_SUPPORT40:
  default:
    switch(reslen)
    {
        case 4:
          ret=buf[0]<<24+buf[1]<<16+buf[2]<<8+buf[3];
        case 3:
          ret=buf[0]<<16+buf[1]<<8+buf[2];
        case 2:
          ret=buf[0]<<8+buf[1];
        case 1:
          ret=buf[0];
    }
    sprintf_P(retbuf, PSTR("%2X:0x%08X"), pid, buf);
    break;
  }

  return ret;
}

void get_cons(char *retbuf)
{
  long maf, vss, cons;

  // check if MAF is supported
  if((1L<<(MAF_AIR_FLOW-1) & pid01to20_support) == 0)
  {
    // nope, lets approximate it with MAP and IAT
    // later :-/
    sprintf_P(retbuf, PSTR("NO MAF"));
    return;
  }
  else  // request it
    maf=get_pid(MAF_AIR_FLOW, retbuf);

  // retbuf will be scrapped and re-used to display fuel consumption
  vss=get_pid(VEHICLE_SPEED, retbuf);

  // 14.7 air/fuel ratio
  // 730 g/L according to Canadian Gov
  // divide MAF by 100 because our function return MAF*100
  // formula: (3600 * MAF/100) / (14.7 * 730 * VSS)
  // multipled by 100 for double digits precision
  
  if(parms[useMetricIdx]==1)
  {
    if(vss==0)
      cons=(maf*3355L)/100L;
    else
      cons=(maf*3355L)/(vss*100L);
    sprintf_P(retbuf, PSTR("%ld.%02ld %s"), cons/100L, cons-((cons/100L)*100L), (vss==0)?"L/h":"\001\002" );
  }
  else
  {
    // single digit precision for MPG
    if(vss==0)
      cons=maf/7107L;  // gallon per hour
    else
      cons=(vss*7107L)/maf;
    sprintf_P(retbuf, PSTR("%ld.%ld %s"), cons/10, (cons - ((cons/10)*10)), (vss==0)?"GPH":"MPG" );
  }
}

void get_dist(char *retbuf)
{
  unsigned long  cdist;

  // convert in hundreds of meter
  cdist=tank_dist/10000UL;

  // convert in miles if requested
  if(parms[useMetricIdx]==0)
    cdist=(cdist*621UL)/1000UL;

  sprintf_P(retbuf, PSTR("DIST:%lu.%lu"), cdist/10L, (cdist - ((cdist/10L)*10L)) );
}

void accu_dist(void)
{
  long vss;
  char str[16];

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
  tank_dist+=(vss*delta_time)/36UL;
}

// we have 512 bytes of EEPROM
void save(void)
{
  // signature at address 0x00
  eeprom_write_byte((uint8_t*)0, obduinosig);
  
  // parameters are all long, align and start at address 0x04
  eeprom_write_block(parms, (void*)0x04, sizeof(parms));
}

//return 1 if loaded ok
byte load(void)
{
  byte b = eeprom_read_byte((const uint8_t*)0);
  if(b==obduinosig)
  {
    eeprom_read_block(parms, (void*)0x04, sizeof(parms));
    return 1;
  }
  return 0;
}

void display(byte pid)
{
  long n;
  char str[16];

  /* check if it's a real PID or our internal one */
  switch(pid)
  {
  case NO_DISPLAY:
    return;
  case FUEL_CONS:
    get_cons(str);
    break;
  case TANK_DIST:
    get_dist(str);
    break;
  default:
    (void)get_pid(pid, str);
    break;
  }

  lcd.print(str);
}

void check_supported_pid(void)
{
  unsigned long n;
  char str[16];

  n=get_pid(PID_SUPPORT20, str);
  pid01to20_support=n;

  // do we support pid 21 to 40?
  if( (1L<<(PID_SUPPORT40-1) & pid01to20_support) == 0)
    return;  //nope

  n=get_pid(PID_SUPPORT40, str);
  pid21to40_support=n;
}

void check_mil_code(void)
{
  unsigned long n;
  char str[16];
  byte nb;
  byte cmd[2];
  byte buf[6];
  byte i, j, k;

  n=get_pid(MIL_CODE, str);

  /* A request for this PID returns 4 bytes of data. The first byte contains
   two pieces of information. Bit A7 (the seventh bit of byte A, the first byte)
   indicates whether or not the MIL (check engine light) is illuminated. Bits A0
   through A6 represent the number of diagnostic trouble codes currently flagged
   in the ECU. The second, third, and fourth bytes give information about the
   availability and completeness of certain on-board tests. Note that test
   availability signified by set (1) bit; completeness signified by reset (0)
   bit. (from Wikipedia)
   */
  if( (1L<<31 & n) !=0)  // test bit A7
  {
    // we have MIL on
    nb=(n>>24) & 0x7F;
    sprintf_P(str, PSTR("CHECK ENGINE ON"));
    lcd.print(str);
    lcd.gotoXY(0,1);
    sprintf_P(str, PSTR("%d CODE(S) IN ECU"), nb);
    lcd.print(str);
    delay(2000);

    // retrieve code
    cmd[0]=0x03;
#ifdef ELM
    Serial.print(cmd[0], HEX);
#else
    iso_write_data(cmd, 1);
#endif

    // we display only the first 6 codes
    // if you have more than 6 in your ECU
    // your car is obviously wrong :-/
    for(i=0;i<nb/3;i++)  // each received packet contain 3 codes
    {
#ifdef ELM
#else
      iso_read_data(buf, 6);
#endif
      k=0;  // to build the string
      for(j=0;j<3;j++)  // the 3 codes
      {
        switch(buf[j*2] & 0xC0)
        {
          case 0x00:
            str[k]='P';  // powertrain
            break;
          case 0x40:
            str[k]='C';  // chassis
            break;
          case 0x80:
            str[k]='B';  // body
            break;
          case 0xC0:
            str[k]='U';  // network
            break;
        }
        k++;
        str[k++]='0' + (buf[j*2] & 0x30)>>4;   // first digit is 0-3 only
        str[k++]='0' + (buf[j*2] & 0x0F);
        str[k++]='0' + (buf[j*2 +1] & 0xF0)>>4;
        str[k++]='0' + (buf[j*2 +1] & 0x0F);
      }
      str[k]='\0';  // make asciiz
      lcd.print(str);
      lcd.gotoXY(0, 1);  // go to next line to display the 3 next
    }
  }
}

void setup()                    // run once, when the sketch starts
{
  byte r;
  char str[20];

#ifndef ELM
  // init pinouts
  pinMode(K_OUT, OUTPUT);
  pinMode(K_IN, INPUT);
#endif

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

  // LCD init
  analogWrite(BrightnessPin,255-brightness[brightnessIdx]);      
  pinMode(EnablePin,OUTPUT);       
  pinMode(DIPin,OUTPUT);       
  pinMode(DB4Pin,OUTPUT);       
  pinMode(DB5Pin,OUTPUT);       
  pinMode(DB6Pin,OUTPUT);       
  pinMode(DB7Pin,OUTPUT);       
  delay(500);      

  analogWrite(ContrastPin,parms[contrastIdx]);
  lcd.init();
  sprintf_P(str, PSTR("Initialization"));
  lcd.print(str);

  do // init loop
  {
#ifdef ELM
    sprintf_P(str, PSTR("ELM Init"));
    lcd.gotoXY(0,1);
    lcd.print(str);
    r=elm_init();
#else
    sprintf_P(str, PSTR("ISO9141 Init"));
    lcd.gotoXY(0,1);
    lcd.print(str);
    r=iso_init();
#endif   
    if(r==0)
      sprintf_P(str, PSTR("Successful!"));
    else
      sprintf_P(str, PSTR("Failed! "));

    lcd.gotoXY(0,1);
    lcd.print(str);
    delay(1000);
  } while(r!=0); // end init loop

  // check supported PIDs
  check_supported_pid();

  // check if we have MIL code
//  check_mil_code();

  topleft=ENGINE_RPM;
  topright=VEHICLE_SPEED;
  bottomleft=FUEL_CONS;
  bottomright=LOAD_VALUE;

  delta_time=millis();
  
  lcd.cls();
}

void loop()                     // run over and over again
{
  long n;
  char str[16];

#if 0
  // if RPM are 0 then the engine is shutdowned
  n=get_pid(ENGINE_RPM, str);
  if(n==0)
  {
      // test if it was running before
      
      // calculate that if we are at 0 for x seconds then
      // save current data (especially distance) in eeprom ONCE
      // and shutdown brightness?
  }
#endif

  // display on LCD
  lcd.gotoXY(0,0);
  display(topleft);
  lcd.gotoXY(8,0);
  display(topright);
  lcd.gotoXY(0,1);
  display(bottomleft);
  lcd.gotoXY(8,1);
  display(bottomright);

  accu_dist();    // accumulate distance

  // test buttons
  // need a button command to reset distance trip (tank)
  // need to save in eeprom one day :)
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

//LCD functions
LCD::LCD()
{
    // nothing here, move along
}
//x=0..16, y= 0..1
void LCD::gotoXY(byte x, byte y)
{
  byte dr=0x80+x;
  if(y!=0)    // save 2 bytes compared to "if(y==1)"
    dr+=0x40;
  lcd.LcdCommandWrite(dr);
}

void LCD::print(char *string)
{
  while(*string != 0)
    lcd.LcdDataWrite(*string++);
}

// do the lcd initialization voodoo
// thanks to Yoshi "SuperMID" for tips :)
void LCD::init()
{
  delay(16);                    // wait for more than 15 msec
  pushNibble(B00110000);  // send (B0011) to DB7-4
  cmdWriteSet();
  delay(5);                     // wait for more than 4.1 msec
  pushNibble(B00110000);  // send (B0011) to DB7-4
  cmdWriteSet();
  delay(1);                     // wait for more than 100 usec
  pushNibble(B00110000);  // send (B0011) to DB7-4
  cmdWriteSet();
  delay(1);                     // wait for more than 100 usec
  pushNibble(B00100000);  // send (B0010) to DB7-4 for 4bit
  cmdWriteSet();
  delay(1);                     // wait for more than 100 usec
  // ready to use normal LcdCommandWrite() function now!

  LcdCommandWrite(B00101000);   // 4-bit interface, 2 display lines, 5x8 font
  LcdCommandWrite(B00001100);   // display control on, no cursor, no blink
  LcdCommandWrite(B00000110);   // entry mode set: increment automatically, no display shift

  //creating the custom fonts (8 char max)
  // char 0 is not used
  // 1&2 is the L/100 datagram in 2 chars only
#define NB_CHAR  2
  // set cg ram to address 0x08 (B001000) to skip the
  // first 8 rows as we do not use char 0
  LcdCommandWrite(B01001000);
  static byte chars[] PROGMEM ={
    B10000,B00000,
    B10000,B00000,
    B11001,B00000,
    B00010,B00000,
    B00100,B00000,
    B01001,B11011,
    B00001,B11011,
    B00001,B11011};

  for(byte x=0;x<NB_CHAR;x++)
    for(byte y=0;y<8;y++)  // 8 rows
        LcdDataWrite(pgm_read_byte(&chars[y*NB_CHAR+x])); //write the character data to the character generator ram

  cls();
  LcdCommandWrite(B10000000);  // set dram to zero
}

void LCD::cls()
{
  LcdCommandWrite(B00000001);  // Clear Display
  LcdCommandWrite(B00000010);  // Return Home
 }

void LCD::tickleEnable()
{
  // send a pulse to enable
  digitalWrite(EnablePin,HIGH);
  delayMicroseconds(1);  // pause 1 ms according to datasheet
  digitalWrite(EnablePin,LOW);
  delayMicroseconds(1);  // pause 1 ms according to datasheet
}

void LCD::cmdWriteSet()
{
  digitalWrite(EnablePin,LOW);
  delayMicroseconds(1);  // pause 1 ms according to datasheet
  digitalWrite(DIPin,0);
  tickleEnable();
}

void LCD::pushNibble(byte value)
{
  digitalWrite(DB7Pin, value & 128);
  value <<= 1;
  digitalWrite(DB6Pin, value & 128);
  value <<= 1;
  digitalWrite(DB5Pin, value & 128);
  value <<= 1;
  digitalWrite(DB4Pin, value & 128);
}

void LCD::LcdCommandWrite(byte value)
{
  pushNibble(value);
  cmdWriteSet();
  value<<=4;
  pushNibble(value);
  cmdWriteSet();
  delay(5);
}

void LCD::LcdDataWrite(byte value)
{
  digitalWrite(DIPin, HIGH);
  pushNibble(value);
  tickleEnable();
  value<<=4;
  pushNibble(value);
  tickleEnable();
  delay(5);
}
