// comment to use MC33290 ISO K line chip
// uncomment to use ELM327
#define ELM

/* OBDuino
 
 Copyright (C) 2008
 
 Main coding/ISO/ELM: Frédéric (aka Magister on ecomodder.com)
 LCD part: Dave (aka dcb on ecomodder.com), optimized by Frédéric
 
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

#include <stdio.h>
#include <avr/eeprom.h>
#include <avr/pgmspace.h>

//LCD Pins from mpguino
#define DIPin 4 // register select RS
#define DB4Pin 7
#define DB5Pin 8
#define DB6Pin 12
#define DB7Pin 13
#define ContrastPin 6
#define EnablePin 5
#define BrightnessPin 9

//LCD prototype
void lcd_gotoXY(byte x, byte y);
void lcd_print_P(char *string);  // to work with string in flash and PSTR()
void lcd_print(char *string);
void lcd_cls();
void lcd_init();
void lcd_tickleEnable();
void lcd_CommandWriteSet();
void lcd_CommandWrite(byte value);
void lcd_DataWrite(byte value);
void lcd_pushNibble(byte value);

byte brightness[]={
  0,42,85,128}; // right button cycles through these brightness settings
#define brightnessLength 4 //array size
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

// for the 4 display corners
#define TOPLEFT  0
#define TOPRIGHT 1
#define BOTTOMLEFT  2
#define BOTTOMRIGHT 3
#define NBCORNER 4   // with a 16x4 display you can use 8 'corners'
#define NBSCREEN  3  // 12 PIDs should be enough for everyone
byte active_screen;  // 0,1,2,... selected by left button
prog_char blkstr[] PROGMEM="        "; // 8 spaces, used to clear part of screen

// parameters
#define BUTTON_DELAY  250
// each screen contains n corners
typedef struct
{
  byte corner[NBCORNER];
} screen_t;

typedef struct
{
  byte contrast;  // we only use 0-100 value in step 20
  byte useMetric;
  byte perHourSpeed;
  float trip_dist;  // trip distance in km
  float trip_fuel;  // trip fuel used in L
  screen_t screen[NBSCREEN];
} params_t;

// global
params_t params;

#define STRLEN  40

#ifdef ELM
#define NUL     '\0'
#define CR      '\r'  // carriage return = 0x0d = 13
#define PROMPT  '>'
#define DATA    1  // data with no cr/prompt
#else
/*
 * for ISO9141-2 Protocol
 */
#define K_IN    2
#define K_OUT   3
// bit period for 10400 bauds = 1000000/10400 = 96
#define _bitPeriod 1000000L/10400L
#endif

/* PID stuff */

unsigned long  pid01to20_support=0;
unsigned long  pid21to40_support=0;
unsigned long  pid41to60_support=0;
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
#define B1S1_O2_V     0x14
#define B1S2_O2_V     0x15
#define B1S3_O2_V     0x16
#define B1S4_O2_V     0x17
#define B2S1_O2_V     0x18
#define B2S2_O2_V     0x19
#define B2S3_O2_V     0x1A
#define B2S4_O2_V     0x1B
#define OBD_STD       0x1C
#define OXY_SENSORS2  0x1D
#define AUX_INPUT     0x1E
#define RUNTIME_START 0x1F
#define PID_SUPPORT40 0x20
#define DIST_MIL      0x21
#define FUEL_RAIL_P   0x22
#define FUEL_RAIL_DIESEL 0x23
#define O2S1_WR1_V   0x24
#define O2S2_WR1_V   0x25
#define O2S3_WR1_V   0x26
#define O2S4_WR1_V   0x27
#define O2S5_WR1_V   0x28
#define O2S6_WR1_V   0x29
#define O2S7_WR1_V   0x2A
#define O2S8_WR1_V   0x2B
#define EGR          0x2C
#define EGR_ERROR    0x2D
#define EVAP_PURGE   0x2E
#define FUEL_LEVEL   0x2F
#define WARM_UPS     0x30
#define DIST_CLEARED 0x31
#define EVAP_PRESSURE 0x32
#define BARO_PRESSURE 0x33
#define O2S1_WR1_C    0x34
#define O2S2_WR1_C    0x35
#define O2S3_WR1_C    0x36
#define O2S4_WR1_C    0x37
#define O2S5_WR1_C    0x38
#define O2S6_WR1_C    0x39
#define O2S7_WR1_C    0x3A
#define O2S8_WR1_C    0x3B
#define CAT_TEMP_B1S1 0x3C
#define CAT_TEMP_B2S1 0x3D
#define CAT_TEMP_B1S2 0x3E
#define CAT_TEMP_B2S2 0x3F
#define PID_SUPPORT60 0x40
#define MONITOR_STAT  0x41
#define CTRL_MOD_V    0x42
#define ABS_LOAD_VAL  0x43
#define CMD_EQUIV_R   0x44
#define REL_THR_POS   0x45
#define AMBIENT_TEMP  0x46
#define ABS_THR_POS_B 0x47
#define ABS_THR_POS_C 0x48
#define ACCEL_PEDAL_D 0x49
#define ACCEL_PEDAL_E 0x4A
#define ACCEL_PEDAL_F 0x4B
#define CMD_THR_ACTU  0x4C
#define TIME_MIL_ON   0x4D
#define TIME_MIL_CLR  0x4E

#define LAST_PID      0x4E  // same as the last one defined above

/* our internal fake PIDs */
#define NO_DISPLAY    0xF0
#define FUEL_CONS     0xF1
#define TRIP_CONS     0xF2
#define TRIP_DIST     0xF3

// returned length of the PID response.
// constants so put in flash
prog_uchar pid_reslen[] PROGMEM=
{
  // pid 0x00 to 0x1F
  4,4,8,2,1,1,1,1,1,1,1,1,2,1,1,1,
  2,1,1,1,2,2,2,2,2,2,2,2,1,1,1,2,

  // pid 0x20 to 0x3F
  4,2,2,2,4,4,4,4,4,4,4,4,1,1,1,1,
  1,2,2,1,4,4,4,4,4,4,4,4,2,2,2,2,
  
  // pid 0x40 to 0x4E
  4,8,2,2,2,1,1,1,1,1,1,1,1,2,2
};

// for trip calculation
unsigned long old_time;

// flag used to save distance/average consumption in eeprom only if required
byte engine_started;
byte param_saved;

//attach the buttons interrupt
ISR(PCINT1_vect)
{
  byte p = PINC;  // bypassing digitalRead for interrupt performance

  buttonState &= p;
}

#ifdef ELM
/* each ELM response ends with '\r' followed at the end by the prompt
 so read com port until we find a prompt */
byte elm_read(char *str, byte size)
{
  int b;
  byte i;

  // wait for something on com port
  i=0;
  while((b=serialRead())!=PROMPT && i<size)
  {
    if(/*b!=-1 &&*/ b>=' ')
      str[i++]=b;
  }

  if(i!=size)  // we got a prompt
  {
    str[i]=NUL;  // replace CR by NUL
    return PROMPT;
  }
  else
    return DATA;
}

// buf must be ASCIIZ
void elm_write(char *str)
{
  while(*str!=NUL)
    serialWrite(*str++);
}

// check header byte
byte elm_check_response(char *cmd, char *str)
{
  // cmd is something like "010D"
  // str should be "41 0D blabla"
  if(cmd[0]+4 != str[0]
    || cmd[1]!=str[1]
    || cmd[2]!=str[3]
    || cmd[3]!=str[4])
    return 1;

  return 0;  // no error
}

byte elm_compact_response(byte *buf, char *str)
{
  byte i;

  // start at 6 which is the first hex byte after header
  // ex: "41 0C 1A F8"
  // return buf: 0x1AF8

  i=0;
  str+=6;
  while(*str!=NUL)
    buf[i++]=strtoul(str, &str, 16);  // 16 = hex

  return i;
}

// write simple string to ELM and return read result
// cmd is a PSTR !!
byte elm_command(char *str, char *cmd)
{
  sprintf_P(str, cmd);
  elm_write(str);
  return elm_read(str, STRLEN);
}

int elm_init()
{
  char str[STRLEN];

  beginSerial(9600);
  serialFlush();

  // reset, wait for something and display it
  elm_command(str, PSTR("ATWS\r")); 
  lcd_gotoXY(0,1);
  lcd_print_P(blkstr);
  lcd_print_P(blkstr);
  lcd_gotoXY(0,1);
  if(strncmp(str,"ATWS",4)==0)
    lcd_print(str+4);
  else
    lcd_print(str);
  delay(1000);

  // turn echo off
  elm_command(str, PSTR("ATE0\r"));

  // send 01 00 to see if we are connected or not
  do
  {
    elm_command(str, PSTR("0100\r"));
    delay(1000);
} while(elm_check_response("0100", str)!=0);

  // ask protocol, if it's CAN 11 bit, set header to 7e0
  // if it's 29 bits set it to da 01 f1
  // if it's ISO (or others?) set to 10?

  // talk directly to ECU#1
  elm_command(str, PSTR("ATSH7E0\r"));

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
  char cmd_str[6];   // to send to ELM
  char str[STRLEN];   // to receive from ELM
#endif
  byte buf[10];   // to receive the result
  long ret;       // return value
  byte reslen;
  char decs[16];

  // check if PID is supported
  if( pid!=PID_SUPPORT20 )
  {
    if( (pid<=0x20 && ( 1L<<(0x20-pid) & pid01to20_support ) == 0 )
    ||  (pid>0x20 && pid<=0x40 && ( 1L<<(0x40-pid) & pid21to40_support ) == 0 )
    ||  (pid>0x40 && pid<=0x60 && ( 1L<<(0x60-pid) & pid41to60_support ) == 0 )
    ||  (pid>LAST_PID) )
    {
      // nope
      sprintf_P(retbuf, PSTR("%02X N/A"), pid);
      return -1;
    }
  }

  cmd[0]=0x01;    // ISO cmd 1, get PID
  cmd[1]=pid;

#ifdef ELM
  sprintf_P(cmd_str, PSTR("01%02X\r"), pid);
  elm_write(cmd_str);
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
  elm_read(str, STRLEN);
  if(elm_check_response(cmd_str, str)!=0)
  {
    sprintf_P(retbuf, PSTR("ERROR"));
    return -255;
  }
  // first 2 bytes are 0x41 and command, skip them
  // convert response in hex and return in buf
  elm_compact_response(buf, str);
#else
  // read requested length, n bytes received in buf
  iso_read_data(buf, reslen);
#endif

  // formula and unit
  switch(pid)
  {
  case ENGINE_RPM:
    ret=(buf[0]*256+buf[1])/4;
    sprintf_P(retbuf, PSTR("%ld RPM"), ret);
    break;
  case FUEL_STATUS:
    ret=buf[0]*256+buf[1];
    switch(buf[0])
    {
    case 0x80:
      sprintf_P(retbuf, PSTR("OPENLOWT"));  // open due to insufficient engine temperature
      break;
    case 0x40:
      sprintf_P(retbuf, PSTR("CLSEOXYS"));  // Closed loop, using oxygen sensor feedback to determine fuel mix
      break;
    case 0x20:
      sprintf_P(retbuf, PSTR("OPENLOAD"));  // Open loop due to engine load
      break;
    case 0x10:
      sprintf_P(retbuf, PSTR("OPENFAIL"));  // Open loop due to system failure
      break;
    case 0x08:
      sprintf_P(retbuf, PSTR("CLSEBADF"));  // Closed loop, using at least one oxygen sensor but there is a fault in the feedback system
      break;
    default:
      sprintf_P(retbuf, PSTR("%04lX"), ret);
      break;
    }
    break;
  case MAF_AIR_FLOW:
    ret=buf[0]*256+buf[1];
    // not divided by 100 for return value!!
    int_to_dec_str(ret, decs, 2);
    sprintf_P(retbuf, PSTR("%s g/s"), decs);
    break;
  case LOAD_VALUE:
  case THROTTLE_POS:
  case REL_THR_POS:
  case EGR:
  case EGR_ERROR:
  case FUEL_LEVEL:
  case ABS_THR_POS_B:
  case ABS_THR_POS_C:
  case ACCEL_PEDAL_D:
  case ACCEL_PEDAL_E:
  case ACCEL_PEDAL_F:
  case CMD_THR_ACTU:
    ret=(buf[0]*100)/255;
    sprintf_P(retbuf, PSTR("%ld %%"), ret);
    break;
  case COOLANT_TEMP:
  case INT_AIR_TEMP:
  case AMBIENT_TEMP:
    ret=buf[0]-40;
    sprintf_P(retbuf, PSTR("%ld C"), ret);
    break;
  case CAT_TEMP_B1S1:
  case CAT_TEMP_B2S1:
  case CAT_TEMP_B1S2:
  case CAT_TEMP_B2S2:
    ret=(buf[0]*256+buf[1])/10 - 40;
    sprintf_P(retbuf, PSTR("%ld C"), ret);
    break;
  case STF_BANK1:
  case LTR_BANK1:
  case STF_BANK2:
  case LTR_BANK2:
    ret=(buf[0]-128)*7812;  // not divided by 10000
    int_to_dec_str(ret/100, decs, 2);
    sprintf_P(retbuf, PSTR("%s %%"), decs);
    break;
  case FUEL_PRESSURE:
  case MAN_PRESSURE:
  case BARO_PRESSURE:
    ret=buf[0];
    if(pid==FUEL_PRESSURE)
      ret*=3;
    sprintf_P(retbuf, PSTR("%ld kPa"), ret);
    break;
  case VEHICLE_SPEED:
    ret=buf[0];
    if(params.useMetric==0)  // convert to MPH for display
    {
      ret=(ret*621L)/1000L;
      sprintf_P(retbuf, PSTR("%ld mph"), ret);
    }
    else
      sprintf_P(retbuf, PSTR("%ld \003\004"), ret);
    break;
  case TIMING_ADV:
    ret=(buf[0]/2)-64;
    sprintf_P(retbuf, PSTR("%ld deg"), ret);
    break;
  case OBD_STD:
    ret=buf[0];
    switch(buf[0])
    {
    case 0x01:
      sprintf_P(retbuf, PSTR("OBD2CARB"));
      break;
    case 0x02:
      sprintf_P(retbuf, PSTR("OBD2EPA"));
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
    case 0x07:
      sprintf_P(retbuf, PSTR("EOBD&2"));
      break;
    case 0x08:
      sprintf_P(retbuf, PSTR("EOBD&1"));
      break;
    case 0x09:
      sprintf_P(retbuf, PSTR("EOBD&1&2"));
      break;
    case 0x0a:
      sprintf_P(retbuf, PSTR("JOBD"));
      break;
    case 0x0b:
      sprintf_P(retbuf, PSTR("JOBD&2"));
      break;
    case 0x0c:
      sprintf_P(retbuf, PSTR("JOBD&1"));
      break;
    case 0x0d:
      sprintf_P(retbuf, PSTR("JOBD&1&2"));
      break;
    default:
      sprintf_P(retbuf, PSTR("OBD:%02X"), buf[0]);
      break;
    }
    break;
    // for the moment, everything else, display the raw answer  
  default:
    // transform buffer to an integer value
    ret=0;
    for(i=0; i<reslen; i++)
    {
      ret*=256L;
      ret+=buf[i];
    }
    sprintf_P(retbuf, PSTR("%08lX"), ret);
    break;
  }

  return ret;
}

// ex: get a long as 687 with prec 2 and output the string "6.87"
// precision is 1 or 2
void int_to_dec_str(long value, char *decs, byte prec)
{
  byte pos;

  // sprintf_P does not allow * for the width ?!?
  if(prec==1)
    sprintf_P(decs, PSTR("%02ld"), value);
  else if(prec==2)
    sprintf_P(decs, PSTR("%03ld"), value);

  pos=strlen(decs)+1;  // move the \0 too
  // a simple loop takes less space than memmove()
  for(byte i=0; i<=prec; i++)
  {
    decs[pos]=decs[pos-1];
    pos--;
  }
  decs[pos]='.';  
}

void get_cons(char *retbuf)
{
  long maf, vss, cons;
  char decs[16];

  // check if MAF is supported
  if((1L<<(32-MAF_AIR_FLOW) & pid01to20_support) == 0)
  {
    // nope, lets approximate it with MAP and IAT
    // later :-/
    sprintf_P(retbuf, PSTR("NO MAF"));
    return;
  }
  else // request it
    maf=get_pid(MAF_AIR_FLOW, retbuf);

  // retbuf will be scrapped and re-used to display fuel consumption
  vss=get_pid(VEHICLE_SPEED, retbuf);

  // divide MAF by 100 because our function return MAF*100
  // but multiply by 100 for double digits precision
  // divide MAF by 14.7 air/fuel ratio to have g of fuel/s
  // divide by 730 (g/L) according to Canadian Gov to have L/s
  // multiply by 3600 to get litre per hour
  // formula: (3600 * MAF) / (14.7 * 730 * VSS)
  // = maf*0.3355/vss L/km
  // mul by 100 to have L/100km

  if(params.useMetric==1)
  {
    if(vss<params.perHourSpeed)
      cons=(maf*3355L)/10000L;  // do not use float so mul first then divide
    else
      cons=(maf*3355L)/(vss*100L); // 100 comes from the /10000*100
    int_to_dec_str(cons, decs, 2);
    sprintf_P(retbuf, PSTR("%s %s"), decs, (vss<params.perHourSpeed)?"L\004":"\001\002" );
  }
  else
  {
    // MPG
    // 6.17 pounds per gallon
    // 454 g in a pound
    // 14.7 * 6.17 * 454 * (VSS * 0.621371) / (3600 * MAF / 100)
    // multipled by 10 for single digit precision
    if(vss<(params.perHourSpeed*1609L)/1000L)
      cons=maf/124L; // gallon per hour
    else if(maf!=0)
      cons=(vss*7107L)/maf;
    else
      cons=0;
    int_to_dec_str(cons, decs, 1);
    sprintf_P(retbuf, PSTR("%s %s"), decs, (vss<(params.perHourSpeed*1609L)/1000L)?"GPH":"MPG" );
  }
}

void get_trip_cons(char *retbuf)
{
  float trip_cons;  // takes same size if I use long, so keep precision
  char decs[16];

  if(params.useMetric==1)
  {
    // from L/km to L/100 so mul by 100 for km
    // multiply by 100 to have 2 digits precision
    if(params.trip_dist<0.001)
      trip_cons=0.0;
    else
      trip_cons=(params.trip_fuel/params.trip_dist)*10000.0;
    int_to_dec_str((long)trip_cons, decs, 2);
    sprintf_P(retbuf, PSTR("%s \001\002"), decs);
  }
  else
  {
    // from km/L to MPG so * by 3.78 to have gallon and * by 0.621371 for mile
    // multiply by 10 to have a digit precision
    if(params.trip_fuel<0.001)
      trip_cons=0.0;
    else
      trip_cons=(params.trip_dist/params.trip_fuel)*23.49;
    int_to_dec_str((long)trip_cons, decs, 1);
    sprintf_P(retbuf, PSTR("%s MPG"), decs);
  }
}

void get_trip_dist(char *retbuf)
{
  float cdist;  // takes 20 bytes more if I use unsigned long
  char decs[16];

  // convert from meters to hundreds of meter
  cdist=params.trip_dist/100.0;

  // convert in miles if requested
  if(params.useMetric==0)
    cdist*=0.621731;

  int_to_dec_str((long)cdist, decs, 1);
  sprintf_P(retbuf, PSTR("%s %s"), decs, (params.useMetric==0)?"mi":"\003" );
}

void accu_trip(void)
{
  long vss;
  long maf;
  char str[STRLEN];
  unsigned long time_now, delta_time;

  vss=get_pid(VEHICLE_SPEED, str);
  maf=get_pid(MAF_AIR_FLOW, str);

  // acumulate for this trip
  time_now = millis();
  delta_time = time_now - old_time;
  old_time = time_now;
  // distance in km
  params.trip_dist+=((float)vss*(float)delta_time)/36.0;
  // fuel used in L
  // maf gives grams of air per second
  // divide by 14.7 (a/f ratio) to have grams of fuel
  // divide by 100 because our MAF return is not divided!
  // divide by 1000 because delta_time is in ms
  // div by 730 to have L
  params.trip_fuel+=((float)maf*(float)delta_time)/1073100000.0;
}

void display(byte corner, byte pid)
{
  char str[STRLEN];

  /* check if it's a real PID or our internal one */
  switch(pid)
  {
  case NO_DISPLAY:
    return;
  case FUEL_CONS:
    get_cons(str);
    break;
  case TRIP_CONS:
    get_trip_cons(str);
    break;
  case TRIP_DIST:
    get_trip_dist(str);
    break;
  default:
    (void)get_pid(pid, str);
    break;
  }

  // left corners are left aligned
  // right corners are right aligned
  switch(corner)
  {
  case TOPLEFT:
    lcd_gotoXY(0,0);
    lcd_print_P(blkstr);
    lcd_gotoXY(0,0);
    break;
  case TOPRIGHT:
    lcd_gotoXY(8, 0);
    lcd_print_P(blkstr);
    lcd_gotoXY(16-strlen(str), 0);  // 16 = screen width
    break;
  case BOTTOMLEFT:
    lcd_gotoXY(0,1);
    lcd_print_P(blkstr);
    lcd_gotoXY(0,1);
    break;
  case BOTTOMRIGHT:
    lcd_gotoXY(8, 1);
    lcd_print_P(blkstr);
    lcd_gotoXY(16-strlen(str), 1);
    break;
  }

  lcd_print(str);
}

void check_supported_pid(void)
{
  unsigned long n;
  char str[STRLEN];

  pid01to20_support=get_pid(PID_SUPPORT20, str);
  
  pid21to40_support=get_pid(PID_SUPPORT40, str);
  // if not supported, get_pid return -1
  if(pid21to40_support==-1)
    pid21to40_support=0;
    
  pid41to60_support=get_pid(PID_SUPPORT60, str);
  if(pid41to60_support==-1)
    pid41to60_support=0;
}

// might be incomplete

void check_mil_code(void)
{
  unsigned long n;
  char str[STRLEN];
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
    lcd_cls();
    lcd_print_P(PSTR("CHECK ENGINE ON"));
    lcd_gotoXY(0,1);
    sprintf_P(str, PSTR("%d CODE(S) IN ECU"), nb);
    lcd_print(str);
    delay(2000);

    // retrieve code
    cmd[0]=0x03;
#ifdef ELM
    sprintf_P(str, PSTR("03\r"));
    elm_write(str);
#else
    iso_write_data(cmd, 1);
#endif

    // we display only the first 6 codes
    // if you have more than 6 in your ECU
    // your car is obviously wrong :-/
    for(i=0;i<nb/3;i++)  // each received packet contain 3 codes
    {
#ifdef ELM
      elm_read(str, STRLEN);
      elm_compact_response(buf, str);
#else
      iso_read_data(buf, 6);
#endif

// must rewrite so just display and quit for the moment
lcd_gotoXY(0,1);
lcd_print(str);
delay(5000);
return;

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
      lcd_print(str);
      lcd_gotoXY(0, 1);  // go to next line to display the 3 next
    }
  }
}

void config_menu(void)
{
  char str[STRLEN];
  byte p;
  
  // go through all the configurable items
  
  // first one is contrast
  lcd_cls();
  lcd_print_P(PSTR("LCD Contrast"));
  // set value with left/right and set with middle
  do
  {
    if(!(buttonState&lbuttonBit) && params.contrast!=0)
      params.contrast-=20;
    else if(!(buttonState&rbuttonBit) && params.contrast!=100)
      params.contrast+=20;
      
    lcd_gotoXY(5,1);
    sprintf_P(str, PSTR("- %d + "), params.contrast);
    lcd_print(str);
    analogWrite(ContrastPin, params.contrast);  // change dynamicaly
    buttonState=buttonsUp;
    delay(BUTTON_DELAY);
  } while(buttonState&mbuttonBit);

  // then the use of metric
  lcd_cls();
  lcd_print_P(PSTR("Use metric unit"));
  // set value with left/right and set with middle
  do
  {
    if(!(buttonState&lbuttonBit))
      params.useMetric=0;
    else if(!(buttonState&rbuttonBit))
      params.useMetric=1;

    lcd_gotoXY(4,1);
    if(params.useMetric==0)
      lcd_print_P(PSTR("(NO) YES"));
    else
      lcd_print_P(PSTR("NO (YES)"));
    buttonState=buttonsUp;
    delay(BUTTON_DELAY);
  } while(buttonState&mbuttonBit);

  // speed from which we toggle to fuel/hour
  lcd_cls();
  lcd_print_P(PSTR("Fuel/hour speed"));
  // set value with left/right and set with middle
  do
  {
    if(!(buttonState&lbuttonBit) && params.perHourSpeed!=0)
      params.perHourSpeed--;
    else if(!(buttonState&rbuttonBit) && params.perHourSpeed!=255)
      params.perHourSpeed++;
      
    lcd_gotoXY(5,1);
    sprintf_P(str, PSTR("- %d + "), params.perHourSpeed);
    lcd_print(str);
    buttonState=buttonsUp;
    delay(BUTTON_DELAY);
  } while(buttonState&mbuttonBit);

  // to reset trip
  lcd_cls();
  lcd_print_P(PSTR("Reset trip data"));
  p=0;
  // set value with left/right and set with middle
  do
  {
    if(!(buttonState&lbuttonBit))
      p=0;
    else if(!(buttonState&rbuttonBit))
      p=1;

    lcd_gotoXY(4,1);
    if(p==0)
      lcd_print_P(PSTR("(NO) YES"));
    else
      lcd_print_P(PSTR("NO (YES)"));
    buttonState=buttonsUp;
    delay(BUTTON_DELAY);
  } while(buttonState&mbuttonBit);
  if(p==1)
  {
    params.trip_dist=0.0;
    params.trip_fuel=0.0;
  }

  // pid for the 4 corners, and for the n screen
  for(byte cur_screen=0; cur_screen<NBSCREEN; cur_screen++)
  {
    for(byte cur_corner=0; cur_corner<NBCORNER; cur_corner++)
    {
      lcd_cls();
      sprintf_P(str, PSTR("Scr %d Corner %d"), cur_screen+1, cur_corner+1);
      lcd_print(str);
      p=params.screen[cur_screen].corner[cur_corner];

      // set value with left/right and set with middle
      do
      {
        if(!(buttonState&lbuttonBit))
          p--;
        else if(!(buttonState&rbuttonBit))
          p++;
      
        lcd_gotoXY(5,1);
        sprintf_P(str, PSTR("- %02X +"), p);
        lcd_print(str);
        buttonState=buttonsUp;
        delay(BUTTON_DELAY);
      } while(buttonState&mbuttonBit);
      // PID is choosen, set it
      params.screen[cur_screen].corner[cur_corner]=p;
    }
  }

  // save params in EEPROM
  save();
}

void test_buttons(void)
{
  // left is cycle through active screen
  if(!(buttonState&lbuttonBit))
  {
    active_screen = (active_screen+1) % NBSCREEN;
  }
  // right is cycle through brightness settings
  else if(!(buttonState&rbuttonBit))
  {
    brightnessIdx = (brightnessIdx + 1) % brightnessLength;
    analogWrite(BrightnessPin, 255-brightness[brightnessIdx]);
  }
  // middle is go into menu
  else if(!(buttonState&mbuttonBit))
    config_menu();

  buttonState=buttonsUp;
}

/****************\
* Initialization *
\****************/

void setup()                    // run once, when the sketch starts
{
  byte r;
  char str[STRLEN];

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
  PCMSK1 |= (1 << PCINT11) | (1 << PCINT12) | (1 << PCINT13);
  PCICR |= (1 << PCIE1);       

  // default parameters
  params.contrast=20;
  params.useMetric=1;
  params.perHourSpeed=10;
  params.trip_dist=0.0;
  params.trip_fuel=0.0;
  params.screen[0].corner[TOPLEFT]=0xf1;
  params.screen[0].corner[TOPRIGHT]=0x0d;
  params.screen[0].corner[BOTTOMLEFT]=0x0c;
  params.screen[0].corner[BOTTOMRIGHT]=0x04;
  params.screen[1].corner[TOPLEFT]=0xf2;
  params.screen[1].corner[TOPRIGHT]=0xf3;
  params.screen[1].corner[BOTTOMLEFT]=0x0f;
  params.screen[1].corner[BOTTOMRIGHT]=0x46;
  params.screen[2].corner[TOPLEFT]=0x1f;
  params.screen[2].corner[TOPRIGHT]=0x31;
  params.screen[2].corner[BOTTOMLEFT]=0x2f;
  params.screen[2].corner[BOTTOMRIGHT]=0x41;

  // load parameters
  load();
  
  // LCD pin init
  analogWrite(BrightnessPin,255-brightness[brightnessIdx]);      
  pinMode(EnablePin,OUTPUT);       
  pinMode(DIPin,OUTPUT);       
  pinMode(DB4Pin,OUTPUT);       
  pinMode(DB5Pin,OUTPUT);       
  pinMode(DB6Pin,OUTPUT);       
  pinMode(DB7Pin,OUTPUT);       
  delay(500);      

  analogWrite(ContrastPin, params.contrast);
  lcd_init();

  lcd_print_P(PSTR(" ** OBDuino **"));

  do // init loop
  {
#ifdef ELM
    lcd_gotoXY(0,1);
    lcd_print_P(PSTR("ELM Init"));
    r=elm_init();
#else
    lcd_gotoXY(0,1);
    lcd_print_P(PSTR("ISO9141 Init"));
    r=iso_init();
#endif   
    lcd_gotoXY(0,1);
    if(r==0)
      lcd_print_P(PSTR("Successful!"));
    else
      lcd_print_P(PSTR("Failed!"));

    delay(1000);
  } 
  while(r!=0); // end init loop

  // check supported PIDs
  check_supported_pid();

  // check if we have MIL code
  //check_mil_code();

  active_screen=0;
  engine_started=0;
  param_saved=0;

  lcd_cls();
  
  old_time=millis();  // epoch
}

/***********\
* Main loop *
\***********/

void loop()                     // run over and over again
{
  byte has_rpm;
  char str[STRLEN];

  // test if engine has started
  has_rpm=(get_pid(ENGINE_RPM, str)>0)?1:0;
  if(engine_started==0 && has_rpm!=0)
  {
    engine_started=1;
    param_saved=0;
  }

  // if engine was started but RPM is now 0
  // save param only once, by flopping param_saved
  if(param_saved==0 && engine_started!=0 && has_rpm==0)
  {
    save();
    param_saved=1;
    engine_started=0;
    lcd_cls();
    lcd_print_P(PSTR("TRIP SAVED!"));
    delay(5000);
  }

  if(has_rpm!=0)
    accu_trip();

  // display on LCD
  for(byte cur_corner=0; cur_corner<NBCORNER; cur_corner++)
    display(cur_corner, params.screen[active_screen].corner[cur_corner]);

  // test buttons
  test_buttons();
}

/**************************\
* Memory related functions *
\**************************/

// we have 512 bytes of EEPROM
void save(void)
{
  uint16_t crc;
  byte *p;
  
  // start at address 0
  eeprom_write_block((const void*)&params, (void*)0, sizeof(params_t));
  
  // CRC at the end
  crc=0;
  p=(byte*)&params;
  for(byte i=0; i<sizeof(params_t); i++)
    crc+=p[i];
    
  eeprom_write_word((uint16_t*)sizeof(params_t), crc);
 }

//return 1 if loaded ok
byte load(void)
{
  params_t  params_temp;
  uint16_t crc, crc_calc;
  byte *p;
  
  // read params in a temp struct
  eeprom_read_block((void*)&params_temp, (void*)0, sizeof(params_t));

  // read crc
  crc=eeprom_read_word((const uint16_t*)sizeof(params_t));

  // calculate crc from read stuff
  crc_calc=0;
  p=(byte*)&params_temp;
  for(byte i=0; i<sizeof(params_t); i++)
    crc_calc+=p[i];

  // compare CRC
  if(crc!=crc_calc)
    return 0;
  else
  {
    memcpy((void*)&params, (const void*)&params_temp, sizeof(params_t));
    return 1;
  }
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

/***************\
* LCD functions *
\***************/
//x=0..16, y= 0..1
void lcd_gotoXY(byte x, byte y)
{
  byte dr=0x80+x;
  if(y!=0)    // save 2 bytes compared to "if(y==1)"
    dr+=0x40;
  lcd_CommandWrite(dr);
}

void lcd_print_P(char *string)
{
  char str[STRLEN];

  sprintf_P(str, string);
  lcd_print(str);
}

void lcd_print(char *string)
{
  while(*string != 0)
    lcd_DataWrite(*string++);
}

// do the lcd initialization voodoo
// thanks to Yoshi "SuperMID" for tips :)
void lcd_init()
{
  delay(16);                    // wait for more than 15 msec
  lcd_pushNibble(B00110000);  // send (B0011) to DB7-4
  lcd_commandWriteSet();
  delay(5);                     // wait for more than 4.1 msec
  lcd_pushNibble(B00110000);  // send (B0011) to DB7-4
  lcd_commandWriteSet();
  delay(1);                     // wait for more than 100 usec
  lcd_pushNibble(B00110000);  // send (B0011) to DB7-4
  lcd_commandWriteSet();
  delay(1);                     // wait for more than 100 usec
  lcd_pushNibble(B00100000);  // send (B0010) to DB7-4 for 4bit
  lcd_commandWriteSet();
  delay(1);                     // wait for more than 100 usec
  // ready to use normal CommandWrite() function now!

  lcd_CommandWrite(B00101000);   // 4-bit interface, 2 display lines, 5x8 font
  lcd_CommandWrite(B00001100);   // display control on, no cursor, no blink
  lcd_CommandWrite(B00000110);   // entry mode set: increment automatically, no display shift

  //creating the custom fonts (8 char max)
  // char 0 is not used
  // 1&2 is the L/100 datagram in 2 chars only
  // 3&4 is the km/h datagram in 2 chars only
#define NB_CHAR  4
  // set cg ram to address 0x08 (B001000) to skip the
  // first 8 rows as we do not use char 0
  lcd_CommandWrite(B01001000);
  static byte chars[] PROGMEM ={
    B10000,B00000,B10000,B00010,
    B10000,B00000,B10100,B00100,
    B11001,B00000,B11000,B01000,
    B00010,B00000,B10100,B10000,
    B00100,B00000,B00000,B00100,
    B01001,B11011,B11111,B00100,
    B00001,B11011,B10101,B00111,
    B00001,B11011,B10101,B00101              };

  for(byte x=0;x<NB_CHAR;x++)
    for(byte y=0;y<8;y++)  // 8 rows
      lcd_DataWrite(pgm_read_byte(&chars[y*NB_CHAR+x])); //write the character data to the character generator ram

  lcd_cls();
  lcd_CommandWrite(B10000000);  // set dram to zero
}

void lcd_cls()
{
  lcd_CommandWrite(B00000001);  // Clear Display
  lcd_CommandWrite(B00000010);  // Return Home
}

void lcd_tickleEnable()
{
  // send a pulse to enable
  digitalWrite(EnablePin,HIGH);
  delayMicroseconds(1);  // pause 1 ms according to datasheet
  digitalWrite(EnablePin,LOW);
  delayMicroseconds(1);  // pause 1 ms according to datasheet
}

void lcd_commandWriteSet()
{
  digitalWrite(EnablePin,LOW);
  delayMicroseconds(1);  // pause 1 ms according to datasheet
  digitalWrite(DIPin,0);
  lcd_tickleEnable();
}

void lcd_pushNibble(byte value)
{
  digitalWrite(DB7Pin, value & 128);
  digitalWrite(DB6Pin, value & 64);
  digitalWrite(DB5Pin, value & 32);
  digitalWrite(DB4Pin, value & 16);
}

void lcd_CommandWrite(byte value)
{
  lcd_pushNibble(value);
  lcd_commandWriteSet();
  value<<=4;
  lcd_pushNibble(value);
  lcd_commandWriteSet();
  delay(5);
}

void lcd_DataWrite(byte value)
{
  digitalWrite(DIPin, HIGH);
  lcd_pushNibble(value);
  lcd_tickleEnable();
  value<<=4;
  lcd_pushNibble(value);
  lcd_tickleEnable();
  delay(5);
}
