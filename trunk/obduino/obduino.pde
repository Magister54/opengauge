/* OBDuino

   Copyright (C) 2008 Frédéric (aka Magister on ecomodder.com)

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
#include <EEPROM.h>
#include <SoftwareSerial.h>
#include <LCD4Bit.h>

/*
 * OBD-II ISO9141-2 Protocol
 */

// change to 0 to have MPH and US MPG
#define USE_METRIC  1

#define K_OUT  2
#define K_IN   3

LCD4Bit   lcd = LCD4Bit(2);   //create a 2-lines display.

void (*topleft)(void);
void (*topright)(void);
void (*bottomleft)(void);
void (*bottomright)(void);

unsigned int baud_speed=0;
#define bit_period  (1000000/baud_speed)

enum
{
  LOAD,
  ECT,
  RPM,
  VSS,
  MAF
};
  
typedef struct PID_S
{
  byte id;
  byte pid;
  byte reslen;
  char format[10];
} PID_T;

PID_T pid_array[]=
{
  { LOAD, 0x04, 1, "%d %%" },
  { ECT, 0x05, 1, "%d C" },
  { RPM, 0x0C, 2, "%d RPM" },
#ifdef USE_METRIC
  { VSS, 0x0D, 1, "%d km/h" },
#else
  { VSS, 0x0D, 1, "%d mph" },
#endif
  { MAF, 0x10, 1, "%d g/s" },
  { 0xff, 0xff, 0xff, NULL }
};

// write a bit using bit bang
void iso_write_byte(byte b)
{
  byte mask;
  unsigned int bit_delay=bit_period-clockCyclesToMicroseconds(50);

  // start bit
  digitalWrite(K_OUT, LOW);
  delayMicroseconds(bit_delay);
  
  mask=0x1;  
  for (mask=0x01; mask; mask <<= 1)
  {
    if(b & mask)
      digitalWrite(K_OUT, HIGH);
    else
      digitalWrite(K_OUT, LOW);

    delayMicroseconds(bit_delay);
  }
  
  // stop bit
  digitalWrite(K_OUT, HIGH);
  delayMicroseconds(bit_delay);
}

byte iso_read_byte(void)
{
  int offset;
  byte b;
  unsigned int bit_delay=bit_period-clockCyclesToMicroseconds(50);

  while (digitalRead(K_IN));

  // confirm that this is a real start bit, not line noise
  if (digitalRead(K_IN) == LOW)
  {
    // frame start indicated by a falling edge and low start bit
    // jump to the middle of the low start bit
    delayMicroseconds(bit_delay / 2 - clockCyclesToMicroseconds(50));
	
    // offset of the bit in the byte: from 0 (LSB) to 7 (MSB)
    for(offset=0; offset<8; offset++)
    {
	// jump to middle of next bit
	delayMicroseconds(bit_delay);
	
	// read bit
	b |= digitalRead(K_IN) << offset;
    }

    delayMicroseconds(bit_period);

    return b;
  }
  
  return -1;
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
    iso_write_byte(data[i]);
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
    buf[i]=iso_read_byte();
  
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
  baud_speed=5;
  iso_write_byte(0x33);
  
  // pause between 60 ms and 300ms (from protocol spec)
  delay(60);

  // switch to 10400 bauds
  baud_speed=10400;

  // wait for 0x55 from the ECU
  b=iso_read_byte();
  if(b!=0x55)
    return -1;

  delay(5);

  // wait for 0x08 0x08
  b=iso_read_byte();
  if(b!=0x08)
    return -1;
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

int get_pid_value(byte mnemo)
{
  byte cmd[2];
  byte buf[20];
  int i, n;
  int index;
  byte match_found;

  i=0;
  match_found=0;
  while(pid_array[i].id!=0xff)
  {
    if(pid_array[i].id==mnemo)
    {
      match_found=1;
      break;
    }
    i++;
  }
  
  if(match_found==0)
    return -1;
  
  index=i;
  
  cmd[0]=0x01;    // ISO cmd 1, get PID
  cmd[1]=pid_array[index].pid;

  // send command
  iso_write_data(cmd, 2);
  
  // receive result
  iso_read_data(buf, pid_array[index].reslen);

  // formula
  switch(pid_array[index].id)
  {
      case VSS:
        n=buf[0];
        break;
      case RPM:
        n=(buf[0]+buf[1]*256)/4;
        break;
      case LOAD:
        n=(buf[0]*100)/255;
        break;
      case ECT:
        n=buf[0]-40;
        break;
      case MAF:
        n=(buf[0]+buf[1]*256)/100;
        break;
      default:
        n=-1;
        break;
  }
  
  return n;
}

int print_pid(byte mnemo, int value)
{
  int i;
  int index;
  byte match_found;
  char str[20];

  i=0;
  match_found=0;
  while(pid_array[i].id!=0xff)
  {
    if(pid_array[i].id==mnemo)
    {
      match_found=1;
      break;
    }
    i++;
  }
  
  if(match_found==0)
    return -1;
  
  index=i;

  sprintf(str, pid_array[index].format, value);

  lcd.printIn(str);
}

void get_vss(void)
{
  int n;
  
  n=get_pid_value(VSS);
#ifndef USE_METRIC
  n=(int)( ((long)n*621L)/1000L );
#endif
  print_pid(VSS, n);
}

void get_rpm(void)
{
  int n;
  
  n=get_pid_value(RPM);
  print_pid(RPM, n);
}

void get_load(void)
{
  int n;
  
  n=get_pid_value(LOAD);
  print_pid(LOAD, n);
}

void get_ect(void)
{
  int n;
  
  n=get_pid_value(ECT);
  print_pid(ECT, n);
}

void get_maf(void)
{
  int n;
  
  n=get_pid_value(MAF);
  print_pid(MAF, n);
}
  
void get_cons(void)
{
  int maf, vss, cons;
  char str[20];
  
  maf=get_pid_value(MAF);
  vss=get_pid_value(VSS);

  // 14.7 air/fuel ratio
  // 730 g/L according to Canadian Gov
  // formula: (3600 * MAF/100) / (14.7 * 730 * VSS)
  // multipled by 100 for double digits precision
#ifdef USE_METRIC  
  cons=(int)( ((long)maf*3355L)/((long)vss*100L) );
  sprintf(str, "%d.%2d L/100", cons/100, (cons - ((cons/100)*100)) );
#else
  // single digit precision for MPG
  cons=(int)( ((long)vss*7107L)/(long)maf );
  sprintf(str, "%d.%d MPG", cons/10, (cons - ((cons/10)*10)) );
#endif

  lcd.printIn(str);
}

void setup()                    // run once, when the sketch starts
{
  // init pinouts
  pinMode(K_OUT, OUTPUT);
  pinMode(K_IN, INPUT);

  Serial.begin(9600);  // for debugging
  Serial.println("Init ISO9141-2 OBD2 Protocol");
  if(iso_init()==0)
    Serial.println("Init OK!");
  else
    Serial.println("Init failed!");
    
  lcd.clear();
  delay(1000);
  lcd.printIn("OBD-II ISO9141-2");
  
  topleft=get_cons;
  topright=get_vss;
  bottomleft=get_rpm;
  bottomright=get_load;
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
  
  delay(100);                  // wait, for what?
}
