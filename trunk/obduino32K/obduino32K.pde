/* OBDuino32K  (Requres Atmega328 for your Arduino)

 Copyright (C) 2008-2009

 Main coding/ISO/ELM: Frédéric (aka Magister on ecomodder.com)
 LCD part: Dave (aka dcb on ecomodder.com), optimized by Frédéric
 ISO Communication Protocol: Russ, Antony, Mike
 Features: Mike, Antony
 Bugs & Fixes: Antony, Frédéric, Mike

Latest Changes(June 9th, 2009):
 ISO 9141 re-init, ECU polling, Car alarm and other tweaks by Antony
June 24, 1009:
 Added three parameters to the mix, removed unrequired RPM call,
   added off and full to backlight levels, added waste PIDs: Antony
June 25, 2009:
 Use the metric parameter for fuel price and tank size: Antony
June 27, 2009:
 Minor corrections and tweaks: Antony
July 23, 2009:
 New menuing system for parameters, and got rid of display flicker: Antony
Sept 01, 2009:
 Better handling of 14230 protocol. Tweak in clear button routine: Antony

To-Do:
  Bugs:
    Fix code to retrieve stored trouble codes.
    
  Features Requested:
    Aero-Drag calculations?
    SD Card logging    
    Add another Fake PID to track max values ( Speed, RPM, Tank KM's, etc...)
  Other:
    Add a variable for the age of the last reading of a PID, for the chance it 
        could be reused. (Great for RPM, SPEED, since they are used multiple 
        times in one loop of the program) 
    Add a "dirty" flag to tank data when the obduino detects that it has been
        disconnected from the car to indicate that the data may no longer be complete

 
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


// Compilation modifiers:
// The following will cause the compiler to add or remove features from the OBDuino build this keeps the
// build size down, will not allow 'on the fly' changes. Some features are dependant on other features.

// Comment for normal build
// Uncomment for a debug build
//#define DEBUG

// Comment to use MC33290 ISO K line chip
// Uncomment to use ELM327
//#define ELM

// Comment out to use only the ISO 9141 K line
// Uncomment to also use the ISO 9141 L line
// This option requires additional wiring to function!
// Most newer cars do NOT require this
//#define useL_Line

// Uncomment only one of the below init sequences if using ISO
#define ISO_9141
//#define ISO_14230_fast
//#define ISO_14230_slow

// Comment out to just try the PIDs without need to find ECU 
// Uncomment to use ECU polling to see if car is On or Off 
//#define useECUState

// Comment out if ISO 9141 does not need to reinit
// Uncomment define below to force reinitialization of ISO 9141 after no ECU communication
// this requires ECU polling
//#define do_ISO_Reinit 

// Comment out to use the PID screen when the car is off (This will interfere with ISO reinit process)
// Uncomment to use the Car Alarm Screen when the car is off
//#define carAlarmScreen

#undef int
#include <stdio.h>
#include <limits.h>
#include <avr/eeprom.h>
#include <avr/pgmspace.h>

// LCD Pins same as mpguino
#define DIPin 4 // register select RS
#define DB4Pin 7
#define DB5Pin 8
#define DB6Pin 12
#define DB7Pin 13
#define ContrastPin 6
#define EnablePin 5
#define BrightnessPin 9

// LCD prototypes
void lcd_gotoXY(byte x, byte y);
void lcd_print(char *string);
void lcd_print_P(char *string);  // to work with string in flash and PSTR()
void lcd_cls_print_P(char *string);  // clear screen and display string
void lcd_cls();
void lcd_init();
void lcd_tickleEnable();
void lcd_commandWriteSet();
void lcd_commandWrite(byte value);
void lcd_dataWrite(byte value);
void lcd_pushNibble(byte value);

// Memory prototypes
void params_load(void);
void params_save(void);

// Others prototypes
byte menu_selection(char ** menu, byte arraySize);
byte menu_select_yes_no(byte p);
void long_to_dec_str(long value, char *decs, byte prec);
int memoryTest(void);
void test_buttons(void);
void get_cost(char *retbuf, byte ctrip);

#define KEY_WAIT 1000 // Wait for potential other key press
#define ACCU_WAIT 500 // Only accumulate data so often.
#define BUTTON_DELAY  125
// use analog pins as digital pins for buttons
#define lbuttonPin 17 // Left Button, on analog 3
#define mbuttonPin 18 // Middle Button, on analog 4
#define rbuttonPin 19 // Right Button, on analog 5

#define lbuttonBit 8 //  pin17 is a bitmask 8 on port C
#define mbuttonBit 16 // pin18 is a bitmask 16 on port C
#define rbuttonBit 32 // pin19 is a bitmask 32 on port C
#define buttonsUp 0 // start with the buttons in the 'not pressed' state

byte buttonState = buttonsUp;

// Easy to read macros
#define LEFT_BUTTON_PRESSED (buttonState&lbuttonBit)
#define MIDDLE_BUTTON_PRESSED (buttonState&mbuttonBit)
#define RIGHT_BUTTON_PRESSED (buttonState&rbuttonBit)

#define brightnessLength 7 //array size
const byte brightness[brightnessLength]={
   0xFF,
   0xFF/brightnessLength*(brightnessLength-1),
   0xFF/brightnessLength*(brightnessLength-2),
   0xFF/brightnessLength*(brightnessLength-3),
   0xFF/brightnessLength*(brightnessLength-4),
   0xFF/brightnessLength*(brightnessLength-5),
   0x00}; // right button cycles through these brightness settings (off to on full)
byte brightnessIdx=2;

/* LCD Display parameters */
/* Adjust LCD_width or LCD_rows if LCD is different than 16 characters by 2 rows*/
// Note: Not currently tested on display larger than 16x2

// How many rows of characters for the LCD (must be at least two)
#define LCD_ROWS 2 
// How many characters across for the LCD (must be at least sixteen)
const byte LCD_width = 16;
// Calculate the middle point of the LCD display width
const byte LCD_split = LCD_width / 2;
//Calculate how many PIDs fit on a data screen (two per line)
const byte LCD_PID_count = LCD_ROWS * 2;

/* PID stuff */

unsigned long  pid01to20_support;  // this one always initialized at setup()
unsigned long  pid21to40_support=0;
unsigned long  pid41to60_support=0;
#define PID_SUPPORT00 0x00
#define MIL_CODE      0x01
#define FREEZE_DTC    0x02
#define FUEL_STATUS   0x03
#define LOAD_VALUE    0x04
#define COOLANT_TEMP  0x05
#define STFT_BANK1    0x06
#define LTFT_BANK1    0x07
#define STFT_BANK2    0x08
#define LTFT_BANK2    0x09
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
#define PID_SUPPORT20 0x20
#define DIST_MIL_ON   0x21
#define FUEL_RAIL_P   0x22
#define FUEL_RAIL_DIESEL 0x23
#define O2S1_WR_V     0x24
#define O2S2_WR_V     0x25
#define O2S3_WR_V     0x26
#define O2S4_WR_V     0x27
#define O2S5_WR_V     0x28
#define O2S6_WR_V     0x29
#define O2S7_WR_V     0x2A
#define O2S8_WR_V     0x2B
#define EGR           0x2C
#define EGR_ERROR     0x2D
#define EVAP_PURGE    0x2E
#define FUEL_LEVEL    0x2F
#define WARM_UPS      0x30
#define DIST_MIL_CLR  0x31
#define EVAP_PRESSURE 0x32
#define BARO_PRESSURE 0x33
#define O2S1_WR_C     0x34
#define O2S2_WR_C     0x35
#define O2S3_WR_C     0x36
#define O2S4_WR_C     0x37
#define O2S5_WR_C     0x38
#define O2S6_WR_C     0x39
#define O2S7_WR_C     0x3A
#define O2S8_WR_C     0x3B
#define CAT_TEMP_B1S1 0x3C
#define CAT_TEMP_B2S1 0x3D
#define CAT_TEMP_B1S2 0x3E
#define CAT_TEMP_B2S2 0x3F
#define PID_SUPPORT40 0x40
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

#define FIRST_FAKE_PID 0xE9 // same as the first one defined below

#define OUTING_WASTE  0xE9    // fuel wasted since car started
#define TRIP_WASTE    0xEA    // fuel wasted during trip
#define TANK_WASTE    0xEB    // fuel wasted for this tank
#define OUTING_COST   0xEC    // the money spent since car started
#define TRIP_COST     0xED    // money spent since on trip
#define TANK_COST     0xEE    // money spent of current tank
#define ENGINE_ON     0xEF    // The length of time car has been running.
#define NO_DISPLAY    0xF0   
#define FUEL_CONS     0xF1    // instant cons
#define TANK_CONS     0xF2    // average cons of tank
#define TANK_FUEL     0xF3    // fuel used in tank
#define TANK_DIST     0xF4    // distance for tank
#define REMAIN_DIST   0xF5    // remaining distance of tank
#define TRIP_CONS     0xF6    // average cons of trip
#define TRIP_FUEL     0xF7    // fuel used in trip
#define TRIP_DIST     0xF8    // distance of trip
#define BATT_VOLTAGE  0xF9
#define OUTING_CONS   0xFA    // cons since the engine turned on
#define OUTING_FUEL   0xFB    // fuel used since engine turned on
#define OUTING_DIST   0xFC    // distance since engine turned on
#define CAN_STATUS    0xFD
#define PID_SEC       0xFE
#ifdef DEBUG                  //why waste a valueable PID space!!
#define FREE_MEM      0xFF
#else
#define ECO_VISUAL    0xFF   // Visually dispay relative economy with text (at end of program)
#endif

//The Textual Description of each PID
prog_char *PID_Desc[] PROGMEM=
{
"PID00-21", // 0x00   PIDs supported
"Stat DTC", // 0x01   Monitor status since DTCs cleared.
"Frz DTC",  // 0x02   Freeze DTC
"Fuel SS",  // 0x03   Fuel system status
"Eng Load", // 0x04   Calculated engine load value
"CoolantT", // 0x05   Engine coolant temperature
"ST F%T 1", // 0x06   Short term fuel % trim—Bank 1
"LT F%T 1", // 0x07   Long term fuel % trim—Bank 1
"ST F%T 2", // 0x08   Short term fuel % trim—Bank 2
"LT F%T 2", // 0x09   Long term fuel % trim—Bank 2
"Fuel Prs", // 0x0A   Fuel pressure
"  MAP  ",  // 0x0B   Intake manifold absolute pressure
"  RPM  ",  // 0x0C   Engine RPM
" Speed ",  // 0x0D   Vehicle speed
"Timing A", // 0x0E   Timing advance
"Intake T", // 0x0F   Intake air temperature
"MAF rate", // 0x10   MAF air flow rate
"Throttle", // 0x11   Throttle position
"Cmd SAS",  // 0x12   Commanded secondary air status
"Oxy Sens", // 0x13   Oxygen sensors present
"Oxy B1S1", // 0x14   Oxygen Sensor Bank 1, Sensor 1
"Oxy B1S2", // 0x15   Oxygen Sensor Bank 1, Sensor 2
"Oxy B1S3", // 0x16   Oxygen Sensor Bank 1, Sensor 3
"Oxy B1S4", // 0x17   Oxygen Sensor Bank 1, Sensor 4
"Oxy B2S1", // 0x18   Oxygen Sensor Bank 2, Sensor 1
"Oxy B2S2", // 0x19   Oxygen Sensor Bank 2, Sensor 2
"Oxy B2S3", // 0x1A   Oxygen Sensor Bank 2, Sensor 3
"Oxy B2S4", // 0x1B   Oxygen Sensor Bank 2, Sensor 4
"OBD Std",  // 0x1C   OBD standards this vehicle conforms to
"Oxy Sens", // 0x1D   Oxygen sensors present
"AuxInpt",  // 0x1E   Auxiliary input status
"Run Time", // 0x1F   Run time since engine start
"PID21-40", // 0x20   PIDs supported 21-40
"Dist MIL", // 0x21   Distance traveled with malfunction indicator lamp (MIL) on
"FRP RMF",  // 0x22   Fuel Rail Pressure (relative to manifold vacuum)
"FRP Dies", // 0x23   Fuel Rail Pressure (diesel)
"OxyS1 V",  // 0x24   O2S1_WR_lambda(1): ER Voltage
"OxyS2 V",  // 0x25   O2S2_WR_lambda(1): ER Voltage
"OxyS3 V",  // 0x26   O2S3_WR_lambda(1): ER Voltage
"OxyS4 V",  // 0x27   O2S4_WR_lambda(1): ER Voltage
"OxyS5 V",  // 0x28   O2S5_WR_lambda(1): ER Voltage
"OxyS6 V",  // 0x29   O2S6_WR_lambda(1): ER Voltage
"OxyS7 V",  // 0x2A   O2S7_WR_lambda(1): ER Voltage
"OxyS8 V",  // 0x2B   O2S8_WR_lambda(1): ER Voltage
"Cmd EGR",  // 0x2C   Commanded EGR
"EGR Err",  // 0x2D   EGR Error
"Cmd EP",   // 0x2E   Commanded evaporative purge
"Fuel LI",  // 0x2F   Fuel Level Input
"WarmupCC", // 0x30   # of warm-ups since codes cleared
"Dist CC",  // 0x31   Distance traveled since codes cleared
"Evap SVP", // 0x32   Evap. System Vapor Pressure
"Barometr", // 0x33   Barometric pressure
"OxyS1 C",  // 0x34   O2S1_WR_lambda(1): ER Current
"OxyS2 C",  // 0x35   O2S2_WR_lambda(1): ER Current
"OxyS3 C",  // 0x36   O2S3_WR_lambda(1): ER Current
"OxyS4 C",  // 0x37   O2S4_WR_lambda(1): ER Current
"OxyS5 C",  // 0x38   O2S5_WR_lambda(1): ER Current
"OxyS6 C",  // 0x39   O2S6_WR_lambda(1): ER Current
"OxyS7 C",  // 0x3A   O2S7_WR_lambda(1): ER Current
"OxyS8 C",  // 0x3B   O2S8_WR_lambda(1): ER Current
"C T B1S1", // 0x3C   Catalyst Temperature Bank 1 Sensor 1
"C T B1S2", // 0x3D   Catalyst Temperature Bank 1 Sensor 2
"C T B2S1", // 0x3E   Catalyst Temperature Bank 2 Sensor 1
"C T B2S2", // 0x3F   Catalyst Temperature Bank 2 Sensor 2
"PID41-60", // 0x40   PIDs supported 41-60
" MStDC",   // 0x41   Monitor status this drive cycle
"Ctrl M V", // 0x42   Control module voltage
"Abs L V",  // 0x43   Absolute load value
"Cmd E R",  // 0x44   Command equivalence ratio
"R ThrotP", // 0x45   Relative throttle position
"Amb Temp", // 0x46   Ambient air temperature
"Acc PP B", // 0x47   Absolute throttle position B
"Acc PP C", // 0x48   Absolute throttle position C
"Acc PP D", // 0x49   Accelerator pedal position D
"Acc PP E", // 0x4A   Accelerator pedal position E
"Acc PP F", // 0x4B   Accelerator pedal position F
"Cmd T A",  // 0x4C   Commanded throttle actuator
"T MIL On", // 0x4D   Time run with MIL on
"T TC Crl", // 0x4E   Time since trouble codes cleared
"  0x4F",   // 0x4F   Unknown
"  0x50",   // 0x50   Unknown
"Fuel Typ", // 0x51   Fuel Type
"Ethyl F%", // 0x52   Ethanol fuel %
"", // 0x53   
"", // 0x54   
"", // 0x55   
"", // 0x56   
"", // 0x57   
"", // 0x58   
"", // 0x59   
"", // 0x5A   
"", // 0x5B   
"", // 0x5C   
"", // 0x5D   
"", // 0x5E   
"", // 0x5F   
"", // 0x60   
"", // 0x61   
"", // 0x62   
"", // 0x63   
"", // 0x64   
"", // 0x65   
"", // 0x66   
"", // 0x67   
"", // 0x68   
"", // 0x69   
"", // 0x6A   
"", // 0x6B   
"", // 0x6C   
"", // 0x6D   
"", // 0x6E   
"", // 0x6F   
"", // 0x70   
"", // 0x71   
"", // 0x72   
"", // 0x73   
"", // 0x74   
"", // 0x75   
"", // 0x76   
"", // 0x77   
"", // 0x78   
"", // 0x79   
"", // 0x7A   
"", // 0x7B   
"", // 0x7C   
"", // 0x7D   
"", // 0x7E   
"", // 0x7F   
"", // 0x80   
"", // 0x81   
"", // 0x82   
"", // 0x83   
"", // 0x84   
"", // 0x85   
"", // 0x86   
"", // 0x87   
"", // 0x88   
"", // 0x89   
"", // 0x8A   
"", // 0x8B   
"", // 0x8C   
"", // 0x8D   
"", // 0x8E   
"", // 0x8F   
"", // 0x90   
"", // 0x91   
"", // 0x92   
"", // 0x93   
"", // 0x94   
"", // 0x95   
"", // 0x96   
"", // 0x97   
"", // 0x98   
"", // 0x99   
"", // 0x9A   
"", // 0x9B   
"", // 0x9C   
"", // 0x9D   
"", // 0x9E   
"", // 0x9F   
"", // 0xA0   
"", // 0xA1   
"", // 0xA2   
"", // 0xA3   
"", // 0xA4   
"", // 0xA5   
"", // 0xA6   
"", // 0xA7   
"", // 0xA8   
"", // 0xA9   
"", // 0xAA   
"", // 0xAB   
"", // 0xAC   
"", // 0xAD   
"", // 0xAE   
"", // 0xAF   
"", // 0xB0   
"", // 0xB1   
"", // 0xB2   
"", // 0xB3   
"", // 0xB4   
"", // 0xB5   
"", // 0xB6   
"", // 0xB7   
"", // 0xB8   
"", // 0xB9   
"", // 0xBA   
"", // 0xBB   
"", // 0xBC   
"", // 0xBD   
"", // 0xBE   
"", // 0xBF   
"", // 0xC0   
"", // 0xC1   
"", // 0xC2   
"", // 0xC3   Unknown
"", // 0xC4   Unknown
"", // 0xC5   
"", // 0xC6   
"", // 0xC7   
"", // 0xC8   
"", // 0xC9   
"", // 0xCA   
"", // 0xCB   
"", // 0xCC   
"", // 0xCD   
"", // 0xCE   
"", // 0xCF   
"", // 0xD0   
"", // 0xD1   
"", // 0xD2   
"", // 0xD3   
"", // 0xD4   
"", // 0xD5   
"", // 0xD6   
"", // 0xD7   
"", // 0xD8   
"", // 0xD9   
"", // 0xDA   
"", // 0xDB   
"", // 0xDC   
"", // 0xDD   
"", // 0xDE   
"", // 0xDF   
"", // 0xE0   
"", // 0xE1   
"", // 0xE2   
"", // 0xE3   
"", // 0xE4   
"", // 0xE5   
"", // 0xE6   
"", // 0xE7   
"", // 0xE8   
"OutWaste", // 0xE9   outing waste
"TrpWaste", // 0xEA   trip waste
"TnkWaste", // 0xEB   tank waste  
"Out Cost", // 0xEC   outing cost
"Trp Cost", // 0xED   trip cost
"Tnk Cost", // 0xEE   tank cost
"Out Time", // 0xEF   The length of time car has been running
"No Disp",  // 0xF0   No display
"InstCons", // 0xF1   instant cons
"Tnk Cons", // 0xF2   average cons of tank
"Tnk Fuel", // 0xF3   fuel used in tank
"Tnk Dist", // 0xF4   distance for tank
"Dist2MT",  // 0xF5   remaining distance of tank
"Trp Cons", // 0xF6   average cons of trip
"Trp Fuel", // 0xF7   fuel used in trip
"Trp Dist", // 0xF8   distance of trip
"Batt Vlt", // 0xF9   Battery Voltage
"Out Cons", // 0xFA   cons since the engine turned on
"Out Fuel", // 0xFB   fuel used since engine turned on
"Out Dist", // 0xFC   distance since engine turned on
"Can Stat", // 0xFD   Can Status
"PID_SEC",  // 0xFE   
"Eco Vis",  // 0xFF   Visually dispay relative economy with text
};

// returned length of the PID response.
// constants so put in flash
prog_uchar pid_reslen[] PROGMEM=
{
  // pid 0x00 to 0x1F
  4,4,2,2,1,1,1,1,1,1,1,1,2,1,1,1,
  2,1,1,1,2,2,2,2,2,2,2,2,1,1,1,4,

  // pid 0x20 to 0x3F
  4,2,2,2,4,4,4,4,4,4,4,4,1,1,1,1,
  1,2,2,1,4,4,4,4,4,4,4,4,2,2,2,2,

  // pid 0x40 to 0x4E
  4,8,2,2,2,1,1,1,1,1,1,1,1,2,2
};

// Number of screens of PIDs
#define NBSCREEN  3  // 12 PIDs should be enough for everyone
byte active_screen=0;  // 0,1,2,... selected by left button

prog_char pctd[] PROGMEM="- %d + "; // used in a couple of place
prog_char pctdpctpct[] PROGMEM="- %d%% + "; // used in a couple of place
prog_char pctspcts[] PROGMEM="%s %s"; // used in a couple of place
prog_char pctldpcts[] PROGMEM="%ld %s"; // used in a couple of place
prog_char select_no[]  PROGMEM="(NO) YES "; // for config menu
prog_char select_yes[] PROGMEM=" NO (YES)"; // for config menu
prog_char gasPrice[][10] PROGMEM={"-  %s\354 + ", "- $%s +  "}; // dual string for fuel price

// menu items used by menu_selection.
prog_char *topMenu[] PROGMEM = {"Configure menu", "Exit", "Display", "Adjust", "PIDs"};
prog_char *displayMenu[] PROGMEM = {"Display menu", "Exit", "Contrast", "Metric", "Fuel/Hour"};
prog_char *adjustMenu[] PROGMEM = {"Adjust menu", "Exit", "Tank Size", "Fuel Cost", "Fuel %", "Speed %", "Out Wait", "Trip Wait", "Eng Disp"};
prog_char *PIDMenu[] PROGMEM = {"PID Screen menu", "Exit", "Scr 1", "Scr 2", "Scr 3"};

#define ARRAY_SIZE(x) (sizeof(x) / sizeof(*(x)))

// Time information
#define MILLIS_PER_HOUR    3600000L
#define MILLIS_PER_MINUTE    60000L
#define MILLIS_PER_SECOND     1000L

// to differenciate trips
#define TANK         0
#define TRIP         1
#define OUTING       2  //Tracks your current outing 
#define NBTRIP       3

prog_char * tripNames[NBTRIP] PROGMEM =
{
  "Tank",
  "Trip",
  "Outing"
};

// parameters
// each trip contains fuel used and distance done
typedef struct
{
  unsigned long dist;   // in cm
  unsigned long fuel;   // in µL
  unsigned long waste;  // in µL
}
trip_t;

// each screen contains n PIDs (two per line)
typedef struct
{
  byte PID[LCD_PID_count];
}
screen_t;

#define MINUTES_GRANULARITY 10

typedef struct
{
  byte contrast;       // we only use 0-100 value in step 20
  byte use_metric;     // 0=rods and hogshead, 1=SI
  boolean use_comma;   // When using metric, also use the comma decimal separator
  byte per_hour_speed; // speed from which we toggle to fuel/hour (km/h or mph)
  byte fuel_adjust;    // because of variation from car to car, temperature, etc
  byte speed_adjust;   // because of variation from car to car, tire size, etc
  byte eng_dis;        // engine displacement in dL
  unsigned int gas_price; // price per unit of fuel in 10th of cents. 905 = $0.905
  unsigned int  tank_size;   // tank size in dL or dgal depending of unit
  byte OutingStopOver; // Allowable stop over time (in tens of minutes). Exceeding time starts a new outing.
  byte TripStopOver;   // Allowable stop over time (in hours). Exceeding time starts a new outing.
  trip_t trip[NBTRIP];        // trip0=tank, trip1=a trip
  screen_t screen[NBSCREEN];  // screen
}
params_t;

// parameters default values
params_t params=
{
  40,
  1,
  true,
  20,
  100,
  100,
  16,
  905,
  450,
  6, // 60 minutes (6 X 10) stop or less will not cause outing reset
  12, // 12 hour stop or less will not cause trip reset
  {
    { 0,0,0 }, // tank: dist, fuel, waste
    { 0,0,0 }, // trip: dist, fuel, waste 
    { 0,0,0 }  // outing:dist, fuel, waste
  },
  {
    { {FUEL_CONS,LOAD_VALUE,TANK_CONS,OUTING_FUEL
       #if LCD_ROWS == 4
         ,OUTING_WASTE,OUTING_COST,ENGINE_ON,LOAD_VALUE
       #endif
       } },
    { {TRIP_CONS,TRIP_DIST,TRIP_FUEL,COOLANT_TEMP
       #if LCD_ROWS == 4
         ,TRIP_WASTE,TRIP_COST,INT_AIR_TEMP,THROTTLE_POS
       #endif
       } },
    { {TANK_CONS,TANK_DIST,TANK_FUEL,REMAIN_DIST
       #if LCD_ROWS == 4
         ,TANK_WASTE,TANK_COST,ENGINE_RPM,VEHICLE_SPEED
       #endif
       } }
  }
};

prog_char * econ_Visual[] PROGMEM=
{
  "Yuck!!8{",
  "Aweful:(",
  "Poor  :[",
  "OK    :|",
  "Good  :]",
  "Great :)",
  "Adroit:D",
  "HyprM 8D"
};

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
#define K_IN    0
#define K_OUT   1
#ifdef useL_Line
  #define L_OUT 2
#endif
#endif

long tempLong; // Useful for transitory values while getting PID information.

// some globals, for trip calculation and others
unsigned long old_time;
byte has_rpm=0;
long vss=0;  // speed
long maf=0;  // MAF
unsigned long engine_on, engine_off; //used to track time of trip.

unsigned long getpid_time;
byte nbpid_per_second=0;

// flag used to save distance/average consumption in eeprom only if required
byte engine_started=0;
byte param_saved=0;

#ifdef ELM
#if defined do_ISO_Reinit
#error do_ISO_Reinit is ONLY ISO 9141 It is not to be used with ELM!
#endif
#endif

#ifndef useECUState
#if defined do_ISO_Reinit
#error do_ISO_Reinit must have useECUState also defined
#endif
#endif

#ifdef useECUState
boolean oldECUconnection;  // Used to test for change in ECU connection state
#endif

#ifdef carAlarmScreen
boolean refreshAlarmScreen; // Used to cause non-repeating screen data to display
#endif

#ifndef ELM
// ISO 9141 communication variables
byte ISO_InitStep = 0;  // Init is multistage, this is the counter
boolean ECUconnection;  // Have we connected to the ECU or not
#endif  

// the buttons interrupt
// this is the interrupt handler for button presses
ISR(PCINT1_vect)
{
#if 0
  static unsigned long last_millis = 0;
  unsigned long m = millis();

  if (m - last_millis > 20)
  { // do pushbutton stuff
    buttonState |= ~PINC;
  }
  //  else ignore interrupt: probably a bounce problem
  last_millis = m;
#else
  buttonState |= ~PINC;
#endif
}

#ifdef ELM
/* each ELM response ends with '\r' followed at the end by the prompt
 so read com port until we find a prompt */
byte elm_read(char *str, byte size)
{
  int b;
  byte i=0;

  // wait for something on com port
  while((b=Serial.read())!=PROMPT && i<size)
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
    Serial.print(*str++);
}

// check header byte
byte elm_check_response(const char *cmd, char *str)
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
  byte i=0;

  // start at 6 which is the first hex byte after header
  // ex: "41 0C 1A F8"
  // return buf: 0x1AF8

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

void elm_init()
{
  char str[STRLEN];

  Serial.begin(9600);
  Serial.flush();

#ifndef DEBUG
  // reset, wait for something and display it
  elm_command(str, PSTR("ATWS\r"));
  lcd_gotoXY(0,1);
  if(str[0]=='A')  // we have read back the ATWS
    lcd_print(str+4);
  else
    lcd_print(str);
  lcd_print_P(PSTR(" Init"));

  // turn echo off
  elm_command(str, PSTR("ATE0\r"));

  // send 01 00 until we are connected
  do
  {
    elm_command(str, PSTR("0100\r"));
    delay(1000);
  }
  while(elm_check_response("0100", str)!=0);

  // ask protocol
  elm_command(str, PSTR("ATDPN\r"));
  // str[0] should be 'A' for automatic
  // set header to talk directly to ECU#1
  if(str[1]=='1')  // PWM
    elm_command(str, PSTR("ATSHE410F1\r"));
  else if(str[1]=='2')  // VPW
    elm_command(str, PSTR("ATSHA810F1\r"));
  else if(str[1]=='3')  // ISO 9141
    elm_command(str, PSTR("ATSH6810F1\r"));
  else if(str[1]=='6')  // CAN 11 bits
    elm_command(str, PSTR("ATSH7E0\r"));
  else if(str[1]=='7')  // CAN 29 bits
    elm_command(str, PSTR("ATSHDA10F1\r"));
#endif
}
#else

void serial_rx_on() {
//  UCSR0B |= _BV(RXEN0);  //enable UART RX
  Serial.begin(10400);		//setting enable bit didn't work, so do beginSerial
}

void serial_rx_off() {
  UCSR0B &= ~(_BV(RXEN0));  //disable UART RX
}

void serial_tx_off() {

   UCSR0B &= ~(_BV(TXEN0));  //disable UART TX
   delay(20);                 //allow time for buffers to flush
}

#ifdef DEBUG
#define READ_ATTEMPTS 2
#else
#define READ_ATTEMPTS 125
#endif

// User must pass in a pointer to a byte to recieve the data.
// Return value reflects success of the read attempt.
boolean iso_read_byte(byte * b)
{
  int readData;
  boolean success = true;
  byte t=0;

  while(t != READ_ATTEMPTS  && (readData=Serial.read())==-1) {
    delay(1);
    t++;
  }
  if (t>=READ_ATTEMPTS) {
    success = false;
  }
  if (success)
  {
    *b = (byte) readData;
  }

  return success;
}

void iso_write_byte(byte b)
{
  serial_rx_off();
  Serial.print(b);
  delay(10);		// ISO requires 5-20 ms delay between bytes.
  serial_rx_on();
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


  #ifdef ISO_9141
  // ISO header
  buf[0]=0x68;
  buf[1]=0x6A;		// 0x68 0x6A is an OBD-II request
  buf[2]=0xF1;		// our requester’s address (off-board tool)
  #else
  // 14230 protocol header
  buf[0]=0xc2; // Request of 2 bytes
  buf[1]=0x33; // Target address
  buf[2]=0xF1; // our requester’s address (off-board tool)
  #endif

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
  }

  return 0;
}

// read n byte(s) of data (+ header + cmd and crc)
// return the count of bytes of message (includes all data in message)
byte iso_read_data(byte *data, byte len)
{
  byte i;
  byte buf[20];
  byte dataSize = 0;

  // header 3 bytes: [80+datalen] [destination=f1] [source=01]
  // data 1+1+len bytes: [40+cmd0] [cmd1] [result0]
  // checksum 1 bytes: [sum(header)+sum(data)]
  // a total of six extra bytes of data

  for(i=0; i<len+6; i++)
  {
    if (iso_read_byte(buf+i))
    {
      dataSize++;
    }
  }
  
  // test, skip header comparison
  // ignore failure for the moment (0x7f)
  // ignore crc for the moment

  // we send only one command, so result start at buf[4] Actually, result starts at buf[5], buf[4] is pid requested...
  memcpy(data, buf+5, len);

  delay(55);    //guarantee 55 ms pause between requests

  return dataSize;
}

/* ISO 9141 init */
// The init process is done in timed sections now so that during the reinit process
// the user can use the buttons, and the screen can be updated.
// Note: Due to the timed nature of this init process, if the display screen takes up too much CPU time, this will not succeed
void iso_init()
{
  long currentTime = millis();
  static long initTime;
#ifdef ISO_9141
  switch (ISO_InitStep)
  {
    case 0:
      // setup
      ECUconnection = false; 
      serial_tx_off(); //disable UART so we can "bit-Bang" the slow init.
      serial_rx_off();
      initTime = currentTime + 3000;
      ISO_InitStep++;
      break;
    case 1:
      if (currentTime >= initTime)
      {
        // drive K line high for 300ms
        digitalWrite(K_OUT, HIGH);
        #ifdef useL_Line
          digitalWrite(L_OUT, HIGH);
        #endif
        initTime = currentTime + 300;
        ISO_InitStep++;
      }
      break;
    case 2:       
    case 7:
      if (currentTime >= initTime)
      {
        // start or stop bit
        digitalWrite(K_OUT, (ISO_InitStep == 2 ? LOW : HIGH));
        #ifdef useL_Line
          digitalWrite(L_OUT, (ISO_InitStep == 2 ? LOW : HIGH));
        #endif
        initTime = currentTime + (ISO_InitStep == 2 ? 200 : 260);
        ISO_InitStep++;
      }
      break;
    case 3:       
    case 5:       
      if (currentTime >= initTime)
      {
        // two bits HIGH
        digitalWrite(K_OUT, HIGH);
        #ifdef useL_Line
          digitalWrite(L_OUT, HIGH);
        #endif
        initTime = currentTime + 400;
        ISO_InitStep++;
      }
      break;
    case 4:       
    case 6:       
      if (currentTime >= initTime)
      {
        // two bits LOW
        digitalWrite(K_OUT, LOW);
        #ifdef useL_Line
          digitalWrite(L_OUT, LOW);
          // Note: after this do we drive the L line back up high, or just leave it alone???          
        #endif
        initTime = currentTime + 400;
        ISO_InitStep++;
      }
      break;
    case 8:      
      if (currentTime >= initTime)
      {
        #ifdef useL_Line
          digitalWrite(L_OUT, LOW);
        #endif

        // bit banging done, now verify connection at 10400 baud
        byte b = 0;
        // switch now to 10400 bauds
        Serial.begin(10400);

        // wait for 0x55 from the ECU (up to 300ms)
        //since our time out for reading is 125ms, we will try it up to three times
        byte i=0;
        while(i<3 && !iso_read_byte(&b))
        {
          i++;
        }
        
        if(b == 0x55)
        {
          ISO_InitStep++;
        }
        else 
        {
          // oops unexpected data, try again
          ISO_InitStep = 0;
        }
      }
      break;
    case 9:        
      if (currentTime >= initTime)
      {
        byte b;
        iso_read_byte(&b);  // read kw1
        iso_read_byte(&b);  // read kw2
        
        // send ~kw2 (invert of last keyword)
        iso_write_byte(~b);

        // ECU answer by 0xCC (~0x33)
        iso_read_byte(&b);
        if(b == 0xCC)
        {
           ECUconnection = true;
           // update for correct delta time in trip calculations.
           old_time = millis();
        }
        ISO_InitStep = 0;
      }
      break;
  }
#elif defined ISO_14230_fast
  switch (ISO_InitStep)
  {
    case 0:
      // setup
      ECUconnection = false; 
      serial_tx_off(); //disable UART so we can "bit-Bang" the slow init.
      serial_rx_off();
      initTime = currentTime + 3000;
      ISO_InitStep++;
      break;
    case 1:
      if (currentTime >= initTime)
      {
        // drive K line high for 300ms
        digitalWrite(K_OUT, HIGH);
        #ifdef useL_Line
          digitalWrite(L_OUT, HIGH);
        #endif
        initTime = currentTime + 300;
        ISO_InitStep++;
      }
      break;
    case 2:       
    case 3:       
      if (currentTime >= initTime)
      {
        // start or stop bit
        digitalWrite(K_OUT, (ISO_InitStep == 2 ? LOW : HIGH));
        #ifdef useL_Line
          digitalWrite(L_OUT, (ISO_InitStep == 2 ? LOW : HIGH));
        #endif
        initTime = currentTime + (ISO_InitStep == 2 ? 25 : 25);
        ISO_InitStep++;
      }
      break;
    case 4:      
      if (currentTime >= initTime)
      {
        // bit banging done, now verify connection at 10400 baud
        byte dataStream[] = {0xc1, 0x33, 0xf1, 0x81, 0x66};
        byte dataStreamSize = ARRAY_SIZE(dataStream);
        boolean gotData = false;
        const byte dataResponseSize = 10;
        byte dataResponse[dataResponseSize];
        byte responseIndex = 0;
        byte dataCaught = '\0';
           
        // switch now to 10400 bauds
        Serial.begin(10400);

        // Send the message
        for (byte i = 0; i < dataStreamSize; i++)
        {
          iso_write_byte(dataStream[i]);
        }

        // Wait for response for 300 ms
        initTime = currentTime + 300;
        do
        {
           // If we find any data, keep catching it until it ends
           while (iso_read_byte(&dataCaught))
           {
              gotData = true;
              dataResponse[responseIndex] = dataCaught;
              responseIndex++;
           }           
        } while (millis() <= initTime && !gotData);

        if (gotData) // or better yet validate the data...
        {
           ECUconnection = true;
           // update for correct delta time in trip calculations.
           old_time = millis();
           
           // Note: we do not actually validate this connection. It would be best to validate the connection.
           // Can someone validate this with a car that actually uses this connection?
        }
        
        ISO_InitStep = 0;
      }
      break;
  }
#elif defined ISO_14230_slow
  switch (ISO_InitStep)
  {
    case 0:
      // setup
      ECUconnection = false; 
      serial_tx_off(); //disable UART so we can "bit-Bang" the slow init.
      serial_rx_off();
      initTime = currentTime + 3000;
      ISO_InitStep++;
      break;
    case 1:
      if (currentTime >= initTime)
      {
        // drive K line high for 300ms
        digitalWrite(K_OUT, HIGH);
        #ifdef useL_Line
          digitalWrite(L_OUT, HIGH);
        #endif
        initTime = currentTime + 300;
        ISO_InitStep++;
      }
      break;
    case 2:       
    case 7:
      if (currentTime >= initTime)
      {
        // start or stop bit
        digitalWrite(K_OUT, (ISO_InitStep == 2 ? LOW : HIGH));
        #ifdef useL_Line
          digitalWrite(L_OUT, (ISO_InitStep == 2 ? LOW : HIGH));
        #endif
        initTime = currentTime + (ISO_InitStep == 2 ? 200 : 260);
        ISO_InitStep++;
      }
      break;
    case 3:       
    case 5:       
      if (currentTime >= initTime)
      {
        // two bits HIGH
        digitalWrite(K_OUT, HIGH);
        #ifdef useL_Line
          digitalWrite(L_OUT, HIGH);
        #endif
        initTime = currentTime + 400;
        ISO_InitStep++;
      }
      break;
    case 4:       
    case 6:       
      if (currentTime >= initTime)
      {
        // two bits LOW
        digitalWrite(K_OUT, LOW);
        #ifdef useL_Line
          digitalWrite(L_OUT, LOW);
          // Note: after this do we drive the L line back up high, or just leave it alone???          
        #endif
        initTime = currentTime + 400;
        ISO_InitStep++;
      }
      break;
    case 8:      
      if (currentTime >= initTime)
      {
        // bit banging done, now verify connection at 10400 baud
        byte dataStream[] = {0xc1, 0x33, 0xf1, 0x81, 0x66};
        byte dataStreamSize = ARRAY_SIZE(dataStream);
        boolean gotData = false;
        const byte dataResponseSize = 10;
        byte dataResponse[dataResponseSize];
        byte responseIndex = 0;
        byte dataCaught = '\0';
      
        // switch now to 10400 bauds
        Serial.begin(10400);

        // Send the message
        for (byte i = 0; i < dataStreamSize; i++)
        {
          iso_write_byte(dataStream[i]);
        }

        // Wait for response for 300 ms
        initTime = currentTime + 300;

        do
        {
           // If we find any data, keep catching it until it ends
           while (iso_read_byte(&dataCaught))
           {
              gotData = true;
              dataResponse[responseIndex] = dataCaught;
              responseIndex++;
           }           
        } while (millis() <= initTime && !gotData);
 
        if (gotData)
        {
           ECUconnection = true;
           // update for correct delta time in trip calculations.
           old_time = millis();

           // Note: we do not actually validate this connection. It would be best to validate the connection.
           // Can someone validate this with a car that actually uses this connection?
        }
        
        ISO_InitStep = 0;
      }
      break;
  }
#else
#error No ISO protocol defined
#endif // protocol
}
#endif

// return false if pid is not supported, true if it is.
// mode is 0 for get_pid() and 1 for menu config to allow pid > 0xF0
boolean is_pid_supported(byte pid, byte mode)
{
   return !((pid>0x00 && pid<=0x20 && ( 1L<<(0x20-pid) & pid01to20_support ) == 0 ) ||
            (pid>0x20 && pid<=0x40 && ( 1L<<(0x40-pid) & pid21to40_support ) == 0 ) ||
            (pid>0x40 && pid<=0x60 && ( 1L<<(0x60-pid) & pid41to60_support ) == 0 ) ||
            (pid>LAST_PID && (pid<FIRST_FAKE_PID || mode==0)));
 }

// Get value of a PID, and place in long pointer
// and also formatted for string output in the return buffer
// Return value denotes successful retrieval of PID.
// User must pass in a long pointer to get the PID value.
boolean get_pid(byte pid, char *retbuf, long *ret)
{
#ifdef ELM
  char cmd_str[6];   // to send to ELM
  char str[STRLEN];   // to receive from ELM
#else
  byte cmd[2];    // to send the command
#endif
  byte i;
  byte buf[10];   // to receive the result
  byte reslen;
  char decs[16];
  unsigned long time_now, delta_time;
  static byte nbpid=0;

  nbpid++;
  // time elapsed
  time_now = millis();
  delta_time = time_now - getpid_time;
  if(delta_time>1000)
  {
    nbpid_per_second=nbpid;
    nbpid=0;
    getpid_time=time_now;
  }

  // check if PID is supported (should not happen except for some 0xFn)
  if(!is_pid_supported(pid, 0))
  {
    // nope
    sprintf_P(retbuf, PSTR("%02X N/A"), pid);
    return false;
  }

  // receive length depends on pid
  reslen=pgm_read_byte_near(pid_reslen+pid);

#ifdef ELM
  sprintf_P(cmd_str, PSTR("01%02X\r"), pid);
  elm_write(cmd_str);
#ifndef DEBUG
  elm_read(str, STRLEN);
  if(elm_check_response(cmd_str, str)!=0)
  {
    sprintf_P(retbuf, PSTR("ERROR"));
    return false;
  }
  // first 2 bytes are 0x41 and command, skip them,
  // convert response in hex and return in buf
  elm_compact_response(buf, str);
#endif
#else
  cmd[0]=0x01;    // ISO cmd 1, get PID
  cmd[1]=pid;
  // send command, length 2
  iso_write_data(cmd, 2);
  // read requested length, n bytes received in buf
  if (!iso_read_data(buf, reslen))
  {
    #ifndef DEBUG
      sprintf_P(retbuf, PSTR("ERROR"));
      return false;
    #endif     
  }
#endif

  // a lot of formulas are the same so calculate a default return value here
  // even if it's scrapped after, we still saved 40 bytes!
  *ret=buf[0]*256U+buf[1];

  // formula and unit for each PID
  switch(pid)
  {
  case ENGINE_RPM:
#ifdef DEBUG
    *ret=1726;
#else
    *ret=*ret/4U;
#endif
    sprintf_P(retbuf, PSTR("%ld RPM"), *ret);
    break;
  case MAF_AIR_FLOW:
#ifdef DEBUG
    *ret=2048;
#endif
    // ret is not divided by 100 for return value!!
    long_to_dec_str(*ret, decs, 2);
    sprintf_P(retbuf, PSTR("%s g/s"), decs);
    break;
  case VEHICLE_SPEED:
#ifdef DEBUG
    *ret=100;
#else
    *ret=(buf[0] * params.speed_adjust) / 100U;
#endif
    if(!params.use_metric)
      *ret=(*ret*1000U)/1609U;
    sprintf_P(retbuf, pctldpcts, *ret, params.use_metric?"\003\004":"\006\004");
    // do not touch vss, it is used by fuel calculation after, so reset it
#ifdef DEBUG
    *ret=100;
#else
    *ret=(buf[0] * params.speed_adjust) / 100U;
#endif
    break;
  case FUEL_STATUS:
#ifdef DEBUG
    *ret=0x0200;
#endif
    if(buf[0]==0x01)
      sprintf_P(retbuf, PSTR("OPENLOWT"));  // open due to insufficient engine temperature
    else if(buf[0]==0x02)
      sprintf_P(retbuf, PSTR("CLSEOXYS"));  // Closed loop, using oxygen sensor feedback to determine fuel mix. should be almost always this
    else if(buf[0]==0x04)
      sprintf_P(retbuf, PSTR("OPENLOAD"));  // Open loop due to engine load, can trigger DFCO
    else if(buf[0]==0x08)
      sprintf_P(retbuf, PSTR("OPENFAIL"));  // Open loop due to system failure
    else if(buf[0]==0x10)
      sprintf_P(retbuf, PSTR("CLSEBADF"));  // Closed loop, using at least one oxygen sensor but there is a fault in the feedback system
    else
      sprintf_P(retbuf, PSTR("%04lX"), *ret);
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
#ifdef DEBUG
    *ret=17;
#else
    *ret=(buf[0]*100U)/255U;
#endif
    sprintf_P(retbuf, PSTR("%ld %%"), *ret);
    break;
  case B1S1_O2_V:
  case B1S2_O2_V:
  case B1S3_O2_V:
  case B1S4_O2_V:
  case B2S1_O2_V:
  case B2S2_O2_V:
  case B2S3_O2_V:
  case B2S4_O2_V:
    *ret=buf[0]*5U;  // not divided by 1000 for return!!
    if(buf[1]==0xFF)  // not used in trim calculation
      sprintf_P(retbuf, PSTR("%ld mV"), *ret);
    else
      sprintf_P(retbuf, PSTR("%ldmV/%d%%"), *ret, ((buf[1]-128)*100)/128);
    break;
  case O2S1_WR_V:
  case O2S2_WR_V:
  case O2S3_WR_V:
  case O2S4_WR_V:
  case O2S5_WR_V:
  case O2S6_WR_V:
  case O2S7_WR_V:
  case O2S8_WR_V:
  case O2S1_WR_C:
  case O2S2_WR_C:
  case O2S3_WR_C:
  case O2S4_WR_C:
  case O2S5_WR_C:
  case O2S6_WR_C:
  case O2S7_WR_C:
  case O2S8_WR_C:
  case CMD_EQUIV_R:
    *ret=(*ret*100)/32768; // not divided by 1000 for return!!
    long_to_dec_str(*ret, decs, 2);
    sprintf_P(retbuf, PSTR("l:%s"), decs);
    break;
  case DIST_MIL_ON:
  case DIST_MIL_CLR:
    if(!params.use_metric)
      *ret=(*ret*1000U)/1609U;
    sprintf_P(retbuf, pctldpcts, *ret, params.use_metric?"\003":"\006");
    break;
  case TIME_MIL_ON:
  case TIME_MIL_CLR:
    sprintf_P(retbuf, PSTR("%ld min"), *ret);
    break;
  case COOLANT_TEMP:
  case INT_AIR_TEMP:
  case AMBIENT_TEMP:
  case CAT_TEMP_B1S1:
  case CAT_TEMP_B2S1:
  case CAT_TEMP_B1S2:
  case CAT_TEMP_B2S2:
    if(pid>=CAT_TEMP_B1S1 && pid<=CAT_TEMP_B2S2)
#ifdef DEBUG
      *ret=600;
#else
      *ret=*ret/10U - 40;
#endif
    else
#ifdef DEBUG
      *ret=40;
#else
      *ret=buf[0]-40;
#endif
    if(!params.use_metric)
      *ret=(*ret*9)/5+32;
    sprintf_P(retbuf, PSTR("%ld\005%c"), *ret, params.use_metric?'C':'F');
    break;
  case STFT_BANK1:
  case LTFT_BANK1:
  case STFT_BANK2:
  case LTFT_BANK2:
    *ret=(buf[0]-128)*7812;  // not divided by 10000 for return value
    long_to_dec_str(*ret/100, decs, 2);
    sprintf_P(retbuf, PSTR("%s %%"), decs);
    break;
  case FUEL_PRESSURE:
  case MAN_PRESSURE:
  case BARO_PRESSURE:
    *ret=buf[0];
    if(pid==FUEL_PRESSURE)
      *ret*=3U;
    sprintf_P(retbuf, PSTR("%ld kPa"), *ret);
    break;
  case TIMING_ADV:
    *ret=(buf[0]/2)-64;
    sprintf_P(retbuf, PSTR("%ld\005"), *ret);
    break;
  case CTRL_MOD_V:
    long_to_dec_str(*ret/10, decs, 2);
    sprintf_P(retbuf, PSTR("%s V"), decs);
    break;
#ifndef DEBUG  // takes 254 bytes, may be removed if necessary
  case OBD_STD:
    *ret=buf[0];
    if(buf[0]==0x01)
      sprintf_P(retbuf, PSTR("OBD2CARB"));
    else if(buf[0]==0x02)
      sprintf_P(retbuf, PSTR("OBD2EPA"));
    else if(buf[0]==0x03)
      sprintf_P(retbuf, PSTR("OBD1&2"));
    else if(buf[0]==0x04)
      sprintf_P(retbuf, PSTR("OBD1"));
    else if(buf[0]==0x05)
      sprintf_P(retbuf, PSTR("NOT OBD"));
    else if(buf[0]==0x06)
      sprintf_P(retbuf, PSTR("EOBD"));
    else if(buf[0]==0x07)
      sprintf_P(retbuf, PSTR("EOBD&2"));
    else if(buf[0]==0x08)
      sprintf_P(retbuf, PSTR("EOBD&1"));
    else if(buf[0]==0x09)
      sprintf_P(retbuf, PSTR("EOBD&1&2"));
    else if(buf[0]==0x0a)
      sprintf_P(retbuf, PSTR("JOBD"));
    else if(buf[0]==0x0b)
      sprintf_P(retbuf, PSTR("JOBD&2"));
    else if(buf[0]==0x0c)
      sprintf_P(retbuf, PSTR("JOBD&1"));
    else if(buf[0]==0x0d)
      sprintf_P(retbuf, PSTR("JOBD&1&2"));
    else
      sprintf_P(retbuf, PSTR("OBD:%02X"), buf[0]);
    break;
#endif
    // for the moment, everything else, display the raw answer
  default:
    // transform buffer to an hex value
    *ret=0;
    for(i=0; i<reslen; i++)
    {
      *ret*=256L;
      *ret+=buf[i];
    }
    sprintf_P(retbuf, PSTR("%08lX"), *ret);
    break;
  }

  return true;
}

// ex: get a long as 687 with prec 2 and output the string "6.87"
// precision is 1 or 2
void long_to_dec_str(long value, char *decs, byte prec)
{
  byte pos;

  // sprintf_P does not allow * for the width so manually change precision
  sprintf_P(decs, prec==2?PSTR("%03ld"):PSTR("%02ld"), value);

  pos=strlen(decs)+1;  // move the \0 too
  // a simple loop takes less space than memmove()
  for(byte i=0; i<=prec; i++)
  {
    decs[pos]=decs[pos-1];  // move digit
    pos--;
  }

  // then insert decimal separator
  decs[pos] = (params.use_metric && params.use_comma) ? ',' : '.';
}

// instant fuel consumption
void get_icons(char *retbuf)
{
  long cons;
  char decs[16];
  long toggle_speed = params.use_metric ? params.per_hour_speed : (params.per_hour_speed*1609)/1000;

  // divide MAF by 100 because our function return MAF*100
  // but multiply by 100 for double digits precision
  // divide MAF by 14.7 air/fuel ratio to have g of fuel/s
  // divide by 730 (g/L at 15°C) according to Canadian Gov to have L/s
  // multiply by 3600 to get litre per hour
  // formula: (3600 * MAF) / (14.7 * 730 * VSS)
  // = maf*0.3355/vss L/km
  // mul by 100 to have L/100km

  // if maf is 0 it will just output 0
  if(vss<toggle_speed)
    cons=(maf*3355)/10000;  // L/h, do not use float so mul first then divide
  else
    cons=(maf*3355)/(vss*100); // L/100kmh, 100 comes from the /10000*100

  if(params.use_metric)
  {
    long_to_dec_str(cons, decs, 2);
    sprintf_P(retbuf, pctspcts, decs, (vss<toggle_speed)?"L\004":"\001\002" );
  }
  else
  {
    // MPG
    // 6.17 pounds per gallon
    // 454 g in a pound
    // 14.7 * 6.17 * 454 * (VSS * 0.621371) / (3600 * MAF / 100)
    // multipled by 10 for single digit precision

    // new comment: convert from L/100 to MPG

    if(vss<toggle_speed)
        cons=(cons*10)/378;   // convert to gallon, can be 0 G/h
    else
    {
      if(cons==0)             // if cons is 0 (DFCO?) display 999.9MPG
        cons=9999;
      else
        cons=235214/cons;     // convert to MPG
    }

    long_to_dec_str(cons, decs, 1);
    sprintf_P(retbuf, pctspcts, decs, (vss<toggle_speed)?"G\004":"\006\007" );
  }
}

// trip 0 is tank
// trip 1 is trip
// trip 2 is outing
void get_cons(char *retbuf, byte ctrip)
{
  unsigned long cfuel;
  unsigned long cdist;
  long trip_cons;
  char decs[16];

  cfuel=params.trip[ctrip].fuel;
  cdist=params.trip[ctrip].dist;

  // the car has not moved yet or no fuel used
  if(cdist<1000 || cfuel==0)
  {
    // will display 0.00L/100 or 999.9mpg
    trip_cons=params.use_metric?0:9999;
  }
  else  // the car has moved and fuel used
  {
    // from µL/cm to L/100 so div by 1000000 for L and mul by 10000000 for 100km
    // multiply by 100 to have 2 digits precision
    // we can not mul fuel by 1000 else it can go higher than ULONG_MAX
    // so divide distance by 1000 instead (resolution of 10 metres)

    trip_cons=cfuel/(cdist/1000); // div by 0 avoided by previous test

    if(params.use_metric)
    {
      if(trip_cons>9999)    // SI
        trip_cons=9999;     // display 99.99 L/100 maximum
    }
    else
    {
      // it's imperial, convert.
      // from m/mL to MPG so * by 3.78541178 to have gallon and * by 0.621371 for mile
      // multiply by 10 to have a digit precision

      // new comment: convert L/100 to MPG
      trip_cons=235214/trip_cons;
      if(trip_cons<10)
        trip_cons=10;  // display 1.0 MPG min
    }
  }

#if 1
  long_to_dec_str(trip_cons, decs, 1+params.use_metric);  // hack
#else
  if(params.use_metric)
    long_to_dec_str(trip_cons, decs, 2);
  else
    long_to_dec_str(trip_cons, decs, 1);
#endif

  sprintf_P(retbuf, pctspcts, decs, params.use_metric?"\001\002":"\006\007" );
}

// trip 0 is tank
// trip 1 is trip
// trip 2 is outing
void get_fuel(char *retbuf, byte ctrip)
{
  unsigned long cfuel;
  char decs[16];

  // convert from µL to cL
  cfuel=params.trip[ctrip].fuel/10000;

  // convert in gallon if requested
  if(!params.use_metric)
    cfuel = convertToGallons(cfuel);
    
  long_to_dec_str(cfuel, decs, 2);
  sprintf_P(retbuf, pctspcts, decs, params.use_metric?"L":"G" );
}

// trip 0 is tank
// trip 1 is trip
// trip 2 is outing
void get_waste(char *retbuf, byte ctrip)
{
  unsigned long cfuel;
  char decs[16];

  // convert from µL to cL
  cfuel=params.trip[ctrip].waste/10000;

  // convert in gallon if requested
  if(!params.use_metric)
    cfuel = convertToGallons(cfuel);

  long_to_dec_str(cfuel, decs, 2);
  sprintf_P(retbuf, pctspcts, decs, params.use_metric?"L":"G" );
}

// trip 0 is tank
// trip 1 is trip
// trip 2 is outing
void get_dist(char *retbuf, byte ctrip)
{
  unsigned long cdist;
  char decs[16];

  // convert from cm to hundreds of meter
  cdist=params.trip[ctrip].dist/10000;

  // convert in miles if requested
  if(!params.use_metric)
    cdist=(cdist*1000)/1609;

  long_to_dec_str(cdist, decs, 1);
  sprintf_P(retbuf, pctspcts, decs, params.use_metric?"\003":"\006" );
}

// distance you can do with the remaining fuel in your tank
void get_remain_dist(char *retbuf)
{
  long tank_tmp;
  long remain_dist;
  long remain_fuel;
  long tank_cons;

  // tank size is in litres (converted at input time)
  tank_tmp=params.tank_size;

  // convert from µL to dL
  remain_fuel=tank_tmp - params.trip[TANK].fuel/100000;

  // calculate remaining distance using tank cons and remaining fuel
  if(params.trip[TANK].dist<1000)
    remain_dist=9999;
  else
  {
    tank_cons=params.trip[TANK].fuel/(params.trip[TANK].dist/1000);
    remain_dist=remain_fuel*1000/tank_cons;

    if(!params.use_metric)  // convert to miles
      remain_dist=(remain_dist*1000)/1609;
  }

  sprintf_P(retbuf, pctldpcts, remain_dist, params.use_metric?"\003":"\006" );
}

/*
 * accumulate data for trip, called every loop()
 */
void accu_trip(void)
{
  static byte min_throttle_pos=255;   // idle throttle position, start high
  byte throttle_pos;   // current throttle position
  byte open_load;      // to detect open loop
  char str[STRLEN];
  unsigned long delta_dist, delta_fuel;
  unsigned long time_now, delta_time;

  // if we return early set MAF to 0
  maf=0;
  
  // time elapsed
  time_now = millis();
  delta_time = time_now - old_time;
  old_time = time_now;

  // distance in cm
  // 3km/h = 83cm/s and we can sample n times per second or so with CAN
  // so having the value in cm is not too large, not too weak.
  // ulong so max value is 4'294'967'295 cm or 42'949 km or 26'671 miles
  if (!get_pid(VEHICLE_SPEED, str, &vss))
  {
    return; // not valid, exit
  }
  
  if(vss>0)
  {
    delta_dist=(vss*delta_time)/36;
    // accumulate for all trips
    for(byte i=0; i<NBTRIP; i++)
      params.trip[i].dist+=delta_dist;
  }

  // if engine is stopped, we can get out now
  if(!has_rpm)
  {
    return;
  }

  // accumulate fuel only if not in DFCO
  // if throttle position is close to idle and we are in open loop -> DFCO

  // detect idle pos
  if (get_pid(THROTTLE_POS, str, &tempLong))
  {
    throttle_pos = (byte)tempLong;
  
    if(throttle_pos<min_throttle_pos && throttle_pos != 0) //And make sure its not '0' returned by no response in read byte function 
      min_throttle_pos=throttle_pos;
  }
  else
  {
    return;
  }
  
  // get fuel status
  if(get_pid(FUEL_STATUS, str, &tempLong))
  {
    open_load = (tempLong & 0x0400) ? 1 : 0;
  }
  else
  {
    return;
  }
 
  if(throttle_pos<(min_throttle_pos+4) && open_load)
  {
    maf=0;  // decellerate fuel cut-off, fake the MAF as 0 :)
  }
  else
  {
    // check if MAF is supported
    if(is_pid_supported(MAF_AIR_FLOW, 0))
    {
      // yes, just request it
      maf = (get_pid(MAF_AIR_FLOW, str, &tempLong)) ? tempLong : 0;
    }
    else
    {
      /*
      I just hope if you don't have a MAF, you have a MAP!!

       No MAF (Uses MAP and Absolute Temp to approximate MAF):
       IMAP = RPM * MAP / IAT
       MAF = (IMAP/120)*(VE/100)*(ED)*(MM)/(R)
       MAP - Manifold Absolute Pressure in kPa
       IAT - Intake Air Temperature in Kelvin
       R - Specific Gas Constant (8.314472 J/(mol.K)
       MM - Average molecular mass of air (28.9644 g/mol)
       VE - volumetric efficiency measured in percent, let's say 80%
       ED - Engine Displacement in liters
       This method requires tweaking of the VE for accuracy.
       */
      long imap, rpm, manp, iat;

      // get_pid successful, assign variable, otherwise quit
      if (get_pid(ENGINE_RPM, str, &tempLong)) rpm = tempLong;
      else return;
      if (get_pid(MAN_PRESSURE, str, &tempLong)) manp = tempLong;
      else return;
      if (get_pid(INT_AIR_TEMP, str, &tempLong)) iat = tempLong;
      else return;
      
      imap=(rpm*manp)/(iat+273);

      // does not divide by 100 because we use (MAF*100) in formula
      // but divide by 10 because engine displacement is in dL
      // 28.9644*100/(80*120*8.314472*10)= about 0.0036 or 36/10000
      // ex: VSS=80km/h, MAP=64kPa, RPM=1800, IAT=21C
      //     engine=2.2L, efficiency=80%
      // maf = ( (1800*64)/(21+273) * 80 * 22 * 29 ) / 10000
      // maf = 1995 or 19.95 g/s which is about right at 80km/h
      maf=(imap * params.eng_dis * 36) / 100;  //only need to divide by 100 because no longer multiplying by V.E.
    }
    // add MAF result to trip
    // we want fuel used in µL
    // maf gives grams of air/s
    // divide by 100 because our MAF return is not divided!
    // divide by 14.7 (a/f ratio) to have grams of fuel/s
    // divide by 730 to have L/s
    // mul by 1000000 to have µL/s
    // divide by 1000 because delta_time is in ms

    // at idle MAF output is about 2.25 g of air /s on my car
    // so about 0.15g of fuel or 0.210 mL
    // or about 210 µL of fuel/s so µL is not too weak nor too large
    // as we sample about 4 times per second at 9600 bauds
    // ulong so max value is 4'294'967'295 µL or 4'294 L (about 1136 gallon)
    // also, adjust maf with fuel param, will be used to display instant cons
    maf=(maf*params.fuel_adjust)/100;
    delta_fuel=(maf*delta_time)/1073;
    for(byte i=0; i<NBTRIP; i++) {
      params.trip[i].fuel+=delta_fuel;
      //code to accumlate fuel wasted while idling
      if ( vss == 0 )  {//car not moving
        params.trip[i].waste+=delta_fuel;
      }
    }
  }
}

void display(byte location, byte pid)
{
  char str[STRLEN];

  /* check if it's a real PID or our internal one */
  if(pid==NO_DISPLAY)
    return;
  else if(pid==OUTING_COST)
    get_cost(str, OUTING);
  else if(pid==TRIP_COST)
    get_cost(str, TRIP);
  else if(pid==TANK_COST)
    get_cost(str, TANK);
  else if(pid==ENGINE_ON)
    get_engine_on_time(str);
  else if(pid==FUEL_CONS)
    get_icons(str);
  else if(pid==TANK_CONS)
    get_cons(str, TANK);
  else if(pid==TANK_FUEL)
    get_fuel(str, TANK);
  else if (pid==TANK_WASTE)
    get_waste(str,TANK);
  else if(pid==TANK_DIST)
    get_dist(str, TANK);
  else if(pid==REMAIN_DIST)
    get_remain_dist(str);
  else if(pid==TRIP_CONS)
    get_cons(str, TRIP);
  else if(pid==TRIP_FUEL)
    get_fuel(str, TRIP);
  else if (pid==TRIP_WASTE)
    get_waste(str,TRIP);
  else if(pid==TRIP_DIST)
    get_dist(str, TRIP);
#ifdef ELM
  else if(pid==BATT_VOLTAGE)
    elm_command(str, PSTR("ATRV\r"));
  else if(pid==CAN_STATUS)
    elm_command(str, PSTR("ATCS\r"));
#endif
  else if (pid==OUTING_CONS)
    get_cons(str,OUTING);
  else if (pid==OUTING_FUEL)
    get_fuel(str,OUTING);
  else if (pid==OUTING_WASTE)
    get_waste(str,OUTING);
  else if (pid==OUTING_DIST)
    get_dist(str,OUTING);
    
  else if(pid==PID_SEC)
  {
    sprintf_P(str, PSTR("%d pid/s"), nbpid_per_second);
  }
#ifdef DEBUG
  else if(pid==FREE_MEM)
    sprintf_P(str, PSTR("%d free"), memoryTest());
#else
  else if(pid==ECO_VISUAL)
    eco_visual(str);
#endif
  else
    get_pid(pid, str, &tempLong);

  // left locations are left aligned
  // right locations are right aligned
  
  // truncate any string that is too long to display correctly
  str[LCD_split] = '\0';
  
  byte row = location / 2;  // Two PIDs per line
  boolean isLeft = location % 2 == 0; // First PID per line is always left
  byte textPos    = isLeft ? 0 : LCD_width - strlen(str);  
  byte clearStart = isLeft ? strlen(str) : LCD_split; 
  byte clearEnd   = isLeft ? LCD_split : textPos;  
    
  lcd_gotoXY(textPos,row);
  lcd_print(str);

  // clean up any possible leading or trailing data
  lcd_gotoXY(clearStart,row);
  for (byte cleanup = clearStart; cleanup < clearEnd; cleanup++)
  {
    lcd_dataWrite(' ');
  }  
}

void check_supported_pids(void)
{
  char str[STRLEN];

#ifdef DEBUG
  pid01to20_support=0xBE1FA812;
#else
  pid01to20_support  = (get_pid(PID_SUPPORT00, str, &tempLong)) ? tempLong : 0;
#endif

  if(is_pid_supported(PID_SUPPORT20, 0))
    pid21to40_support = (get_pid(PID_SUPPORT20, str, &tempLong)) ? tempLong : 0;

  if(is_pid_supported(PID_SUPPORT40, 0))
    pid41to60_support = (get_pid(PID_SUPPORT40, str, &tempLong)) ? tempLong : 0;
}

// might be incomplete
void check_mil_code(void)
{
  unsigned long n;
  char str[STRLEN];
  byte nb;
#ifndef ELM
  byte cmd[2];
  byte buf[6];
  byte i, j, k;
#endif

  if (!get_pid(MIL_CODE, str, &tempLong))
    return;  // Invalid return so abort 
  
  n = (unsigned long) tempLong;

  /* A request for this PID returns 4 bytes of data. The first byte contains
   two pieces of information. Bit A7 (the seventh bit of byte A, the first byte)
   indicates whether or not the MIL (check engine light) is illuminated. Bits A0
   through A6 represent the number of diagnostic trouble codes currently flagged
   in the ECU. The second, third, and fourth bytes give information about the
   availability and completeness of certain on-board tests. Note that test
   availability signified by set (1) bit; completeness signified by reset (0)
   bit. (from Wikipedia)
   */
  if(1L<<31 & n)  // test bit A7
  {
    // we have MIL on
    nb=(n>>24) & 0x7F;
    lcd_cls_print_P(PSTR("CHECK ENGINE ON"));
    lcd_gotoXY(0,1);
    sprintf_P(str, PSTR("%d CODE(S) IN ECU"), nb);
    lcd_print(str);
    delay(2000);
    lcd_cls();

#ifdef ELM
    // retrieve code
    elm_command(str, PSTR("03\r"));
    // ELM returns something like 43 01 33 00 00 00 00
    if(str[0]!='4' && str[1]!='3')
      return;  // something wrong

    // must convert to P/C/B/U etc
    lcd_print(str+3);
    delay(5000);
#else
    // we display only the first 6 codes
    // if you have more than 6 in your ECU
    // your car is obviously wrong :-/

    // retrieve code
    cmd[0]=0x03;
    iso_write_data(cmd, 1);

    for(i=0;i<nb/3;i++)  // each received packet contain 3 codes
    {
      iso_read_data(buf, 6);

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
#endif
  }
}

/*
 * Configuration menu
 */

void delay_reset_button(void)
{
  // accumulate data for trip while in the menu config, do not pool too often.
  // but anyway you should not configure your OBDuino while driving!
  
  // If there has been a key press, then don't accumulate trip data just yet,
  // wait a little past the last key press before doing trip data.
  // Rapid key presses take priority...
  static unsigned long lastButtonTime = 0;
 
  if (buttonState != buttonsUp)
  {
    lastButtonTime = millis();
    
    buttonState = buttonsUp;
    delay(BUTTON_DELAY);
  }
  else
  {
    if (calcTimeDiff(lastButtonTime, millis()) > KEY_WAIT &&
        calcTimeDiff(old_time, millis()) > ACCU_WAIT)
    {
      accu_trip();
    }
  }
}

// common code used in a couple of menu section
byte menu_select_yes_no(byte p)
{
  boolean exitMenu = false;

  // set value with left/right and set with middle
  delay_reset_button();  // make sure to clear button

  do
  {
    if(LEFT_BUTTON_PRESSED)
      p=0;
    else if(RIGHT_BUTTON_PRESSED)
      p=1;
    else if(MIDDLE_BUTTON_PRESSED)
      exitMenu = true;
  
    lcd_gotoXY(4,1);
    if(p==0)
      lcd_print_P(select_no);
    else
      lcd_print_P(select_yes);

    delay_reset_button();
  }
  while(!exitMenu);
  
  return p;
}

// Menu selection
// 
// This function is passed in a array of strings which comprise of the menu
// The first string is the MENU TITLE,
// The second string is the EXIT option (always first option)
// The following strings are the other options in the menu
//
// The returned value denotes the selection of the user:
// A return of zero represents the exit
// A return of a real number represents the selection from the menu past exit (ie 2 would be the second item past EXIT)
byte menu_selection(char ** menu, byte arraySize)
{
  byte selection = 1; // Menu title takes up the first string in the list so skip it
  byte screenChars = 0;  // Characters currently sent to screen
  byte menuItem = 0;     // Menu items past current selection
  boolean exitMenu = false;

  // Note: values are changed with left/right and set with middle
  // Default selection is always the first selection, which should be 'Exit'
  
  lcd_cls();
  lcd_print((char *)pgm_read_word(&(menu[0])));
  delay_reset_button();  // make sure to clear button

  do
  {
    if(LEFT_BUTTON_PRESSED && selection > 1)
    {
      selection--;
    }
    else if(RIGHT_BUTTON_PRESSED && selection < arraySize - 1)
    {
      selection++;
    }
    else if (MIDDLE_BUTTON_PRESSED)
    {
      exitMenu = true;
    }   

    // Potential improvements:
    // Currently the selection is ALWAYS the first presented menu item.
    // Current selection could be in the middle if possible.
    // If few selections and screen size permits, selections could be centered?
    
    lcd_gotoXY(0,1);
    screenChars = 1;
    lcd_dataWrite('('); // Wrap the current selection with brackets
    menuItem = 0;
    do
    {
      lcd_print((char*)pgm_read_word(&(menu[selection+menuItem])));

      if (menuItem == 0) 
      {
        // include closing bracket
        lcd_dataWrite(')');
        screenChars++;
      }  
      lcd_dataWrite(' ');
      screenChars += (strlen((char*)pgm_read_word(&(menu[selection+menuItem]))) + 1);
      menuItem++;
    }
    while (screenChars < LCD_width && selection + menuItem < arraySize);

    // Do any cover up of old data
    while (screenChars < LCD_width)
    {
      lcd_dataWrite(' ');
      screenChars++;
    }

    // Clean up button presses 
    delay_reset_button();
  }
  while(!exitMenu);

  return selection - 1;
}

void config_menu(void)
{
  char str[STRLEN];
  char decs[16];
  int lastButton = 0;  //we'll use this to speed up button pushes
  unsigned int fuelUnits = 0;
  boolean changed = false;

#ifdef ELM
#ifndef DEBUG  // it takes 98 bytes
  // display protocol, just for fun
  lcd_cls();
  memset(str, 0, STRLEN);
  elm_command(str, PSTR("ATDP\r"));
  if(str[0]=='A')  // string start with "AUTO, ", skip it
  {
    lcd_print(str+6);
    lcd_gotoXY(0,1);
    lcd_print(str+6+16);
  }
  else
  {
    lcd_print(str);
    lcd_gotoXY(0,1);
    lcd_print(str+16);
  }
  delay(2000);
#endif
#endif

  boolean saveParams = false;  // Currently a button press will cause a save, smarter would be to verify a change in value...
  byte selection = 0;
  byte oldByteValue;             // used to determine if new value is different and we need to save the change
  unsigned int oldUIntValue;     // ditto

  do
  {
    selection = menu_selection(topMenu, ARRAY_SIZE(topMenu));

    if (selection == 1) // display
    {
      byte displaySelection = 0;
    
      do
      {
        displaySelection = menu_selection(displayMenu, ARRAY_SIZE(displayMenu));

        if (displaySelection == 1) // Contrast
        {
          lcd_cls_print_P(PSTR("LCD contrast"));
          oldByteValue = params.contrast;
          
          do
          {
            if(LEFT_BUTTON_PRESSED && params.contrast!=0)
              params.contrast-=10;
            else if(RIGHT_BUTTON_PRESSED && params.contrast!=100)
              params.contrast+=10;

            analogWrite(ContrastPin, params.contrast);  // change dynamicaly
            sprintf_P(str, pctd, params.contrast);
            displaySecondLine(5, str);
          } while(!MIDDLE_BUTTON_PRESSED);

          if (oldByteValue != params.contrast)
          {
            saveParams = true;
          }
        }
        else if (displaySelection == 2)  // Metric
        {
          lcd_cls_print_P(PSTR("Use metric unit"));
          oldByteValue = params.use_metric;
          params.use_metric=menu_select_yes_no(params.use_metric);
          if (oldByteValue != params.use_metric)
          {
            saveParams = true;
          }

          // Only if metric do we have the option of using the comma as a decimal
          if(params.use_metric)
          {
            lcd_cls_print_P(PSTR("Use comma format"));
            oldByteValue = (byte) params.use_comma;
            params.use_comma = menu_select_yes_no(params.use_comma);
   
            if (oldByteValue != (byte) params.use_comma)
            {
              saveParams = true;
            }
          }
        }
        else if (displaySelection == 3) // Display speed
        {
          oldByteValue = params.per_hour_speed;

          // speed from which we toggle to fuel/hour
          lcd_cls_print_P(PSTR("Fuel/hour speed"));
          // set value with left/right and set with middle
          do
          {
            if(LEFT_BUTTON_PRESSED && params.per_hour_speed!=0)
              params.per_hour_speed--;
            else if(RIGHT_BUTTON_PRESSED && params.per_hour_speed!=255)
              params.per_hour_speed++;

            sprintf_P(str, pctd, params.per_hour_speed);
            displaySecondLine(5, str);
          } while(!MIDDLE_BUTTON_PRESSED);

          if (oldByteValue != params.per_hour_speed)
          {
            saveParams = true;
          }
        }
      } while (displaySelection != 0); // exit from this menu
    }
    else if (selection == 2) // Adjust
    {
      byte adjustSelection = 0;
      byte count = ARRAY_SIZE(adjustMenu);
      if (is_pid_supported(MAF_AIR_FLOW, 0))
      {
        // Use the "Eng Displ" parameter (the last one) only when MAF_AIR_FLOW is not supported
        count--;
      }
  
      do
      {
        adjustSelection = menu_selection(adjustMenu, count);

        if (adjustSelection == 1) 
        {   
          lcd_cls_print_P(PSTR("Tank size ("));

          oldUIntValue = params.tank_size;

          // convert in gallon if requested
          if(!params.use_metric)
          {
            lcd_print_P(PSTR("G)"));
            fuelUnits = convertToGallons(params.tank_size);
          }  
          else
          {
            lcd_print_P(PSTR("L)"));
            fuelUnits = params.tank_size;
          }
  
          // set value with left/right and set with middle
          do
          {
            if(LEFT_BUTTON_PRESSED)
            {
              changed = true;
              fuelUnits--;
            }
            else if(RIGHT_BUTTON_PRESSED)
            {
              changed = true;
              fuelUnits++;
            }

            long_to_dec_str(fuelUnits, decs, 1);
            sprintf_P(str, PSTR("- %s + "), decs);
            displaySecondLine(4, str);
          } while(!MIDDLE_BUTTON_PRESSED);
   
          if (changed)
          {
            if(!params.use_metric)
            {
              params.tank_size = convertToLitres(fuelUnits);
            }
            else
            {
              params.tank_size = fuelUnits;
            } 
            changed = false;
          }

          if (oldUIntValue != params.tank_size)
          {
            saveParams = true;
          }          
        }
        else if (adjustSelection == 2)  // cost
        {
          int lastButton = 0;
 
          lcd_cls_print_P(PSTR("Fuel Price ("));
          oldUIntValue = params.gas_price;

          // convert in gallons if requested
          if(!params.use_metric)
          {
            lcd_print_P(PSTR("G)"));
            // Convert unit price to litres for the cost per gallon. (ie $1 a litre = $3.785 per gallon)
            fuelUnits = convertToLitres(params.gas_price);
          }
          else
          {
            lcd_print_P(PSTR("L)"));
            fuelUnits = params.gas_price;
          }
  
          // set value with left/right and set with middle
          do
          {
            if(LEFT_BUTTON_PRESSED){
              changed = true;
              lastButton--;      
              if(lastButton >= 0) {
                lastButton = 0;
                fuelUnits--;
              } else if (lastButton < -3 && lastButton > -7) {
                fuelUnits-=2;
              } else if (lastButton <= -7) {
                fuelUnits-=10;
              } else {
                fuelUnits--;
              }
            } else if(RIGHT_BUTTON_PRESSED){
              changed = true;
              lastButton++;      
              if(lastButton <= 0) {
                lastButton = 0;
                fuelUnits++;
              } else if (lastButton > 3 && lastButton < 7) {
                fuelUnits+=2;
              } else if (lastButton >= 7) {
                fuelUnits+=10;
              } else {
                fuelUnits++;
              }      
            }

            long_to_dec_str(fuelUnits, decs, fuelUnits > 999 ? 3 : 1);
            sprintf_P(str, gasPrice[fuelUnits > 999], decs);
            displaySecondLine(3, str);
          } while(!MIDDLE_BUTTON_PRESSED);

          if (changed)
          {
            if(!params.use_metric)
            {
              params.gas_price = convertToGallons(fuelUnits);
            }
            else
            {
              params.gas_price = fuelUnits;
            }
            changed = false;
          }

          if (oldUIntValue != params.gas_price)
          {
            saveParams = true;
          }          
        }
        else if (adjustSelection == 3)
        {
          lcd_cls_print_P(PSTR("Fuel adjust"));
          oldByteValue = params.fuel_adjust;

          do
          {
            if(LEFT_BUTTON_PRESSED)
              params.fuel_adjust--;
            else if(RIGHT_BUTTON_PRESSED)
              params.fuel_adjust++;

            sprintf_P(str, pctdpctpct, params.fuel_adjust);
            displaySecondLine(4, str);
          } while(!MIDDLE_BUTTON_PRESSED);

          if (oldByteValue != params.fuel_adjust)
          {
            saveParams = true;
          }     
        }
        else if (adjustSelection == 4)
        {
          lcd_cls_print_P(PSTR("Speed adjust"));
          oldByteValue = params.speed_adjust;

          do
          { 
            if(LEFT_BUTTON_PRESSED)
              params.speed_adjust--;
            else if(RIGHT_BUTTON_PRESSED)
              params.speed_adjust++;

            sprintf_P(str, pctdpctpct, params.speed_adjust);
            displaySecondLine(4, str);
          } while(!MIDDLE_BUTTON_PRESSED);

          if (oldByteValue != params.fuel_adjust)
          {
            saveParams = true;
          }     
        }
        else if (adjustSelection == 5)
        {
          lcd_cls_print_P(PSTR("Outing stop over"));
          oldByteValue = params.OutingStopOver;

          do
          {
            if(LEFT_BUTTON_PRESSED && params.OutingStopOver > 0)
              params.OutingStopOver--;
            else if(RIGHT_BUTTON_PRESSED && params.OutingStopOver < UCHAR_MAX)
              params.OutingStopOver++;

            sprintf_P(str, PSTR("- %2d Min + "), params.OutingStopOver * MINUTES_GRANULARITY);
            displaySecondLine(3, str);
          } while(!MIDDLE_BUTTON_PRESSED);

          if (oldByteValue != params.OutingStopOver)
          {
            saveParams = true;
          }     

        }
        else if (adjustSelection == 6)
        {
          lcd_cls_print_P(PSTR("Trip stop over"));
          oldByteValue = params.TripStopOver;

          do
          {
            unsigned long TripStopOver;   // Allowable stop over time (in milliseconds). Exceeding time starts a new outing.
  
            if(LEFT_BUTTON_PRESSED && params.TripStopOver > 1)
              params.TripStopOver--;
            else if(RIGHT_BUTTON_PRESSED && params.TripStopOver < UCHAR_MAX)
              params.TripStopOver++;

            sprintf_P(str, PSTR("- %2d Hrs + "), params.TripStopOver);
            displaySecondLine(3, str);
          } while(!MIDDLE_BUTTON_PRESSED);

          if (oldByteValue != params.TripStopOver)
          {
            saveParams = true;
          }     
        }
        else if (adjustSelection == 7)
        {
          lcd_cls_print_P(PSTR("Eng dplcmt (MAP)"));
          oldByteValue = params.eng_dis;

          // the following setting is for MAP only
          // engine displacement

          do
          {
            if(LEFT_BUTTON_PRESSED && params.eng_dis!=0)
              params.eng_dis--;
            else if(RIGHT_BUTTON_PRESSED && params.eng_dis!=100)
              params.eng_dis++;

            long_to_dec_str(params.eng_dis, decs, 1);
            sprintf_P(str, PSTR("- %sL + "), decs);
            displaySecondLine(4, str);
          }
          while(!MIDDLE_BUTTON_PRESSED);

          if (oldByteValue != params.eng_dis)
          {
            saveParams = true;
          }     
        }
      } while (adjustSelection != 0);
    }   
    else if (selection == 3) // PIDs
    { 
      // go through all the configurable items
      byte PIDSelection = 0;
      byte cur_screen;
      byte pid = 0;
     
      // Set PIDs required for the selected screen
      do
      {
        PIDSelection = menu_selection(PIDMenu, ARRAY_SIZE(PIDMenu));
       
        if (PIDSelection != 0 && PIDSelection <= NBSCREEN)
        {
          cur_screen = PIDSelection - 1;
          for(byte current_PID=0; current_PID<LCD_PID_count; current_PID++)
          {
            lcd_cls();
            sprintf_P(str, PSTR("Scr %d      PID %d"), cur_screen+1, current_PID+1);
            lcd_print(str);
            oldByteValue = pid = params.screen[cur_screen].PID[current_PID];

            do
            {
              if(LEFT_BUTTON_PRESSED)
              {
                // while we do not find a supported PID, decrease
                while(!is_pid_supported(--pid, 1));
              }
              else if(RIGHT_BUTTON_PRESSED)
              {
                // while we do not find a supported PID, increase
                while(!is_pid_supported(++pid, 1));
              }
              
              sprintf_P(str, PSTR("- %8s +  "), (char*)pgm_read_word(&(PID_Desc[pid])));
              displaySecondLine(2, str);
            } while(!MIDDLE_BUTTON_PRESSED);
 
            // PID has changed so set it
            if (oldByteValue != pid)
            {
              params.screen[cur_screen].PID[current_PID]=pid;
              saveParams = true;
            }
          }
        }
      } while (PIDSelection != 0);
    }  
  } while (selection != 0);  

  if (saveParams)
  {
    // save params in EEPROM
    lcd_cls_print_P(PSTR("Saving config"));
    lcd_gotoXY(0,1);
    lcd_print_P(PSTR("Please wait..."));
    params_save();
  }
}

// This helps reduce code size by containing repeated functionality.
void displaySecondLine(byte position, char * str)
{
  lcd_gotoXY(position,1);
  lcd_print(str);
  delay_reset_button(); 
}

// Reworked a little to allow all trip types to be reset from one function.
void trip_reset(byte ctrip, boolean ask)
{
  boolean reset = true;
  char str[STRLEN];
 
  // Display the intent
  lcd_cls();
  sprintf_P(str, PSTR("Zero %s data"), (char*)pgm_read_word(&(tripNames[ctrip])));
  lcd_print(str);
  
  if(ask)
  {
    reset=menu_select_yes_no(0);  // init to "no"
  }

  if(reset)
  {
    params.trip[ctrip].dist=0L;
    params.trip[ctrip].fuel=0L;
    params.trip[ctrip].waste=0L;
    
    if (ctrip == OUTING && ask)
    {
      // Reset the start time to now too
      engine_on = millis();
    }
  }
 
  if (!ask)
  {
    delay(750); // let user see (if they are paying attention)
  }  
}

unsigned int convertToGallons(unsigned int litres)
{
  return (unsigned int) ((float) litres / 3.785411);
}

unsigned int convertToLitres(unsigned int gallons)
{
  return (unsigned int) ((float) gallons / 0.264172);
}


void test_buttons(void)
{
  // middle + left = tank reset
  if(MIDDLE_BUTTON_PRESSED && LEFT_BUTTON_PRESSED)
  {
    needBacklight(true);
    trip_reset(TANK, true);
  }
  // middle + right = trip reset
  else if(MIDDLE_BUTTON_PRESSED && RIGHT_BUTTON_PRESSED)
  {
    // Added choice to reset OUTING trip also. We could merge TANK here too, and then just use the menu selection
    // to select the trip type to reset (maybe ask confirmation or not, since the menu has an exit).
    needBacklight(true);    
    trip_reset(TRIP, true);
    trip_reset(OUTING, true);
  }
  // left + right = flash pid info
  else if(LEFT_BUTTON_PRESSED && RIGHT_BUTTON_PRESSED)
  {
    display_PID_names();
  }
  // left is cycle through active screen
  else if(LEFT_BUTTON_PRESSED)
  {
    active_screen = (active_screen+1) % NBSCREEN;
    display_PID_names();
  }
  // right is cycle through brightness settings
  else if(RIGHT_BUTTON_PRESSED)
  {
    char str[STRLEN] = {0};

    brightnessIdx = (brightnessIdx + 1) % brightnessLength;
    analogWrite(BrightnessPin, brightness[brightnessIdx]);

    lcd_cls_print_P(PSTR(" LCD backlight"));
    lcd_gotoXY(6,1);
    sprintf_P(str,PSTR("%d / %d"),brightnessIdx + 1,brightnessLength);
    lcd_print(str);
    delay(500);
  }
  // middle is go into menu
  else if(MIDDLE_BUTTON_PRESSED)
  {
    needBacklight(true);    
    config_menu();
  }
  
  // reset buttons state
  if(buttonState!=buttonsUp)
  {
    #ifdef carAlarmScreen
      refreshAlarmScreen = true;
    #endif
   
    delay_reset_button();
    needBacklight(false);    
  }
}

void display_PID_names(void)
{
  needBacklight(true);    
  lcd_cls();
  // Lets flash up the description of the PID's we use when screen changes
  byte count = 0;
  for (byte row = 0; row < LCD_ROWS; row++)
  {
    for (byte col = 0; col == 0 || col == LCD_split; col+=LCD_split)
    {
      lcd_gotoXY(col,row);  
      lcd_print((char*)pgm_read_word(&(PID_Desc[params.screen[active_screen].PID[count++]])));
    }  
  }
  
  delay(750); // give user some time to see new PID titles
} 

void needBacklight(boolean On)
{
  //only if ECU or engine are off do we need the backlight.
#ifdef useECUState
  if (!ECUconnection)
#else
  if (!engine_started)
#endif
  {
    // Assume backlight is normally off, so set according to input On  
    analogWrite(BrightnessPin, brightness[On ? brightnessIdx : 0]);
  }
}  

/*
 * Initialization
 */

void setup()                    // run once, when the sketch starts
{
#ifndef ELM
  boolean success;

  // init pinouts
  pinMode(K_OUT, OUTPUT);
  pinMode(K_IN, INPUT);
  #ifdef useL_Line
  pinMode(L_OUT, OUTPUT);
  #endif
#endif

  // buttons init
  pinMode(lbuttonPin, INPUT);
  pinMode(mbuttonPin, INPUT);
  pinMode(rbuttonPin, INPUT);
  // "turn on" the internal pullup resistors
  digitalWrite(lbuttonPin, HIGH);
  digitalWrite(mbuttonPin, HIGH);
  digitalWrite(rbuttonPin, HIGH);

  // low level interrupt enable stuff
  // interrupt 1 for the 3 buttons
  PCMSK1 |= (1 << PCINT11) | (1 << PCINT12) | (1 << PCINT13);
  PCICR  |= (1 << PCIE1);

  // load parameters
  params_load();  // if something is wrong, default parms are used

  // LCD pin init
  analogWrite(BrightnessPin,brightness[brightnessIdx]);
  analogWrite(ContrastPin, params.contrast);
  pinMode(EnablePin,OUTPUT);
  pinMode(DIPin,OUTPUT);
  pinMode(DB4Pin,OUTPUT);
  pinMode(DB5Pin,OUTPUT);
  pinMode(DB6Pin,OUTPUT);
  pinMode(DB7Pin,OUTPUT);
  delay(100);

  engine_off = engine_on = millis();

  lcd_init();
  lcd_print_P(PSTR("OBDuino32k  v158"));
#ifndef ELM
  do // init loop
  {
    lcd_gotoXY(2,1);
    #ifdef ISO_9141
      lcd_print_P(PSTR("ISO9141 Init"));
    #elif defined ISO_14230_fast
      lcd_print_P(PSTR("ISO14230 Fast"));
    #elif defined ISO_14230_slow
      lcd_print_P(PSTR("ISO14230 Slow"));
    #endif
    
    
    #ifdef DEBUG // In debug mode we need to skip init.
      success=true;
    #else 
      ISO_InitStep = 0;
      do
      {
        iso_init();
      } while (ISO_InitStep != 0);

      success = ECUconnection;
      #ifdef useECUState
        oldECUconnection != ECUconnection; // force 'turn on' stuff in main loop
      #endif
   #endif
    
    lcd_gotoXY(2,1);
    lcd_print_P(success ? PSTR("Successful!  ") : PSTR("Failed!         "));

    delay(1000);
  }
  while(!success); // end init loop
#else
  elm_init();
#endif

#ifdef carAlarmScreen
   refreshAlarmScreen = true;
#endif      

  // check supported PIDs
  check_supported_pids();

  // check if we have MIL code
  check_mil_code();

  lcd_cls();
  old_time=millis();  // epoch
  getpid_time=old_time;
}

/*
 * Main loop
 */

void loop()                     // run over and over again
{
  #ifdef useECUState
    #ifdef DEBUG
      ECUconnection = true;
      has_rpm = true;  
    #else
      ECUconnection = verifyECUAlive();
    #endif

  if (oldECUconnection != ECUconnection)
  {
    if (ECUconnection)
    {
      unsigned long nowOn = millis();
      unsigned long engineOffPeriod = calcTimeDiff(engine_off, nowOn);
      
      analogWrite(BrightnessPin,brightness[brightnessIdx]);
 
      if (engineOffPeriod > (params.OutingStopOver * MINUTES_GRANULARITY * MILLIS_PER_MINUTE))
      {
        trip_reset(OUTING, false);
        engine_on = nowOn;
      }
      else
      {
        // combine last trip time to this one! Not including the stop over time
        engine_on = nowOn - calcTimeDiff(engine_on, engine_off);
      }  
 
      if (engineOffPeriod > (params.TripStopOver * MILLIS_PER_HOUR))
      {
        trip_reset(TRIP, false);
      }
    }
    else  // Car is off
    {
      #ifdef do_ISO_Reinit
        ISO_InitStep = 0;
      #endif

      engine_off = millis();  //record the time the engine was shut off
      params_save();
      lcd_cls_print_P(PSTR("TRIPS SAVED!"));
      //Lets Display how much fuel for the tank we wasted.
      char str[STRLEN] = {0};
      lcd_gotoXY(0,1);
      lcd_print_P(PSTR("Wasted:"));
      lcd_gotoXY(LCD_split,1);
      get_waste(str,TANK);
      lcd_print(str);

      delay(2000);
      //Turn the Backlight off
      analogWrite(BrightnessPin, brightness[0]);

      #ifdef carAlarmScreen
      refreshAlarmScreen = true;
      #endif
    }  
    oldECUconnection = ECUconnection;
  } 

  if (ECUconnection)
  {
    // this read and assign vss and maf and accumulate trip data
    accu_trip();
  
    // display on LCD
    for(byte current_PID=0; current_PID<LCD_PID_count; current_PID++)
      display(current_PID, params.screen[active_screen].PID[current_PID]);
  }
  else
  {
    #ifdef carAlarmScreen
      // ECU is off so print ready screen instead of PIDS while we wait for ECU action
      displayAlarmScreen();
    #else
    // for some reason the display on LCD
    for(byte current_PID=0; current_PID<LCD_PID_count; current_PID++)
      display(current_PID, params.screen[active_screen].PID[current_PID]);
    #endif

    #ifdef do_ISO_Reinit
      #ifndef carAlarmScreen  
      #error ISO reinit will not function when not displaying the car alarm screen (#define carAlarmScreen)
      #endif
      iso_init();
    #endif
  }    
#else
  char str[STRLEN];

  // test if engine is started
  has_rpm = (get_pid(ENGINE_RPM, str, &tempLong) && tempLong > 0) ? 1 : 0;

  if(engine_started==0 && has_rpm!=0)
  {
    unsigned long nowOn = millis();
    unsigned long engineOffPeriod = calcTimeDiff(engine_off, nowOn);
    engine_started=1;
    param_saved=0;
    analogWrite(BrightnessPin,brightness[brightnessIdx]);

    if (engineOffPeriod > (params.OutingStopOver * MINUTES_GRANULARITY * MILLIS_PER_MINUTE))
    {
      //Reset the current outing trip from last trip
      trip_reset(OUTING, false);
      engine_on = nowOn; //Reset the time at which the car starts at
    }
    else
    {
       // combine last trip time to this one! Not including the stop over time
       engine_on = nowOn - calcTimeDiff(engine_on, engine_off);
    }  
    
    if (engineOffPeriod > (params.TripStopOver * MILLIS_PER_HOUR))
    {
      trip_reset(TRIP, false);
    }
  }

  // if engine was started but RPM is now 0
  // save param only once, by flopping param_saved
  if(has_rpm==0 && param_saved==0 && engine_started!=0)
  {
    engine_off = millis();  //record the time the engine was shut off
    params_save();
    param_saved=1;
    engine_started=0;
    lcd_cls_print_P(PSTR("TRIPS SAVED!"));
    //Lets Display how much fuel for the tank we wasted.
    char str[STRLEN] = {0};
    lcd_gotoXY(0,1);
    lcd_print_P(PSTR("Wasted:"));
    lcd_gotoXY(LCD_split,1);
    get_waste(str,TANK);
    lcd_print(str);
    delay(2000);
    //Turn the Backlight off
    analogWrite(BrightnessPin,brightness[0]);

    #ifdef carAlarmScreen
      refreshAlarmScreen = true;
    #endif
  }

  #ifdef carAlarmScreen
    displayAlarmScreen();
  #else
  
  // this read and assign vss and maf and accumulate trip data
  accu_trip();

  // display on LCD
  for(byte current_PID=0; current_PID<LCD_PID_count; current_PID++)
    display(current_PID, params.screen[active_screen].PID[current_PID]);

  #endif

#endif

  // test buttons
  test_buttons();
}

// Calculate the time difference, and account for roll over too
unsigned long calcTimeDiff(unsigned long start, unsigned long end)
{
  if (start < end)
  {
    return end - start;
  }
  else // roll over
  {
    return ULONG_MAX - start + end;
  }
}    

#ifdef useECUState
boolean verifyECUAlive(void)
{
#ifdef ELM
  char cmd_str[6];   // to send to ELM
  char str[STRLEN];   // to receive from ELM
  sprintf_P(cmd_str, PSTR("01%02X\r"), ENGINE_RPM);
  elm_write(cmd_str);
  elm_read(str, STRLEN);
  return elm_check_response(cmd_str, str) == 0;
#else //ISO
  #ifdef do_ISO_Reinit
  if (!ECUconnection) // only check for off, finding active ECU is handled by successful reiniting 
  {
    return ECUconnection;
  }
  #endif
    // Send command to ECU, if it is active, we will get data back.
    // Set RPM to 1 if ECU active and RPM above 0, otherwise zero.
    char str[STRLEN];
    boolean connected = get_pid(ENGINE_RPM, str, &tempLong);
    has_rpm = (connected && tempLong > 0) ? 1 : 0;

    return connected;
#endif
}
#endif

#ifdef carAlarmScreen
// This screen will display a fake security heading,
// then emulate an array of LED's blinking in Knight Rider style.
// This could be modified to blink a real LED (or maybe a short array depending on available pins)
void displayAlarmScreen(void)
{
  static byte pingPosition;
  static boolean pingDirection;
  static long nextMoveTime;
  const long pingTimeOut = 1000;
  const byte lastLCDChar = 15;
 
  if (refreshAlarmScreen)
  {
    pingPosition = 0;
    pingDirection = 0;

    lcd_cls_print_P(PSTR("OBDuino Security" ));
    lcd_gotoXY(pingPosition,1);
    lcd_dataWrite('*');
    
    refreshAlarmScreen = false;
    nextMoveTime = millis() + pingTimeOut;
  }
  else if (millis() > nextMoveTime)
  {
    lcd_gotoXY(pingPosition,1);
    lcd_dataWrite(' ');

    if(pingPosition == 0 || pingPosition == lastLCDChar)
    {
      // Change direction
      pingDirection = !pingDirection;
    }
    
    // Move the character    
    if(pingDirection)
    {
      pingPosition+= 3;
    }
    else
    {
      pingPosition-=3;
    }
    
    lcd_gotoXY(pingPosition,1);
    lcd_dataWrite('*');
    
    nextMoveTime = millis() + pingTimeOut;
  }
}  
#endif

/*
 * Memory related functions
 */

// we have 512 bytes of EEPROM on the 168P, more than enough
void params_save(void)
{
  uint16_t crc;
  byte *p;

  // CRC will go at the end
  crc=0;
  p=(byte*)&params;
  for(byte i=0; i<sizeof(params_t); i++)
    crc+=p[i];

  // start at address 0
  eeprom_write_block((const void*)&params, (void*)0, sizeof(params_t));
  // write CRC after params struct
  eeprom_write_word((uint16_t*)sizeof(params_t), crc);
}

void params_load(void)
{
  params_t params_tmp;
  uint16_t crc, crc_calc;
  byte *p;

  // read params
  eeprom_read_block((void*)&params_tmp, (void*)0, sizeof(params_t));
  // read crc
  crc=eeprom_read_word((const uint16_t*)sizeof(params_t));

  // calculate crc from read stuff
  crc_calc=0;
  p=(byte*)&params_tmp;
  for(byte i=0; i<sizeof(params_t); i++)
    crc_calc+=p[i];

  // compare CRC
  if(crc==crc_calc)     // good, copy read params to params
    params=params_tmp;
}

#ifdef DEBUG  // how can this takes 578 bytes!!
// this function will return the number of bytes currently free in RAM
// there is about 670 bytes free in memory when OBDuino is running
extern int  __bss_end;
extern int  *__brkval;
int memoryTest(void)
{
  int free_memory;
  if((int)__brkval == 0)
    free_memory = ((int)&free_memory) - ((int)&__bss_end);
  else
    free_memory = ((int)&free_memory) - ((int)__brkval);
  return free_memory;
}
#endif

/*
 * LCD functions
 */
// x=0..16, y=0..1
void lcd_gotoXY(byte x, byte y)
{
  byte dr=0x80+x;
  if(y!=0)    // save 2 bytes compared to "if(y==1)"
    dr+=0x40;
  lcd_commandWrite(dr);
}

void lcd_print(char *string)
{
  while(*string != 0)
    lcd_dataWrite(*string++);
}

void lcd_print_P(char *string)
{
  char str[STRLEN];

  sprintf_P(str, string);
  lcd_print(str);
}

void lcd_cls_print_P(char *string)
{
  lcd_cls();
  lcd_print_P(string);
}

// do the lcd initialization voodoo
// thanks to Yoshi "SuperMID" for tips :)
void lcd_init()
{
  delay(16);                    // wait for more than 15 msec

  for(byte i=0; i<3; i++)
  {
    lcd_pushNibble(B00110000);  // send (B0011) to DB7-4
    lcd_commandWriteSet();
    delay(5);                     // wait for more than 4.1 msec or 100 usec
  }

  lcd_pushNibble(B00100000);  // send (B0010) to DB7-4 for 4bit
  lcd_commandWriteSet();
  delay(1);                     // wait for more than 100 usec
  // ready to use normal CommandWrite() function now!

  lcd_commandWrite(B00101000);   // 4-bit interface, 2 display lines, 5x8 font
  lcd_commandWrite(B00001100);   // display control on, no cursor, no blink
  lcd_commandWrite(B00000110);   // entry mode set: increment automatically, no display shift

  //creating the custom fonts (8 char max)
  // char 0 is not used
  // 1&2 is the L/100 datagram in 2 chars only
  // 3&4 is the km/h datagram in 2 chars only
  // 5 is the ° char (degree)
  // 6&7 is the mi/g char
#define NB_CHAR  7
  // set cg ram to address 0x08 (B001000) to skip the
  // first 8 rows as we do not use char 0
  lcd_commandWrite(B01001000);
  static prog_uchar chars[] PROGMEM ={
    B10000,B00000,B10000,B00010,B00111,B11111,B00010,
    B10000,B00000,B10100,B00100,B00101,B10101,B00100,
    B11001,B00000,B11000,B01000,B00111,B10101,B01000,
    B00010,B00000,B10100,B10000,B00000,B00000,B10000,
    B00100,B00000,B00000,B00100,B00000,B00100,B00111,
    B01001,B11011,B11111,B00100,B00000,B00000,B00100,
    B00001,B11011,B10101,B00111,B00000,B00100,B00101,
    B00001,B11011,B10101,B00101,B00000,B00100,B00111,
  };

  for(byte x=0;x<NB_CHAR;x++)
    for(byte y=0;y<8;y++)  // 8 rows
      lcd_dataWrite(pgm_read_byte(&chars[y*NB_CHAR+x])); //write the character data to the character generator ram

  lcd_cls();
  lcd_commandWrite(B10000000);  // set dram to zero
}

void lcd_cls()
{
  lcd_commandWrite(B00000001);  // Clear Display
  lcd_commandWrite(B00000010);  // Return Home
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

void lcd_commandWrite(byte value)
{
  lcd_pushNibble(value);
  lcd_commandWriteSet();
  value<<=4;
  lcd_pushNibble(value);
  lcd_commandWriteSet();
  delay(5);
}

void lcd_dataWrite(byte value)
{
  digitalWrite(DIPin, HIGH);
  lcd_pushNibble(value);
  lcd_tickleEnable();
  value<<=4;
  lcd_pushNibble(value);
  lcd_tickleEnable();
  delay(5);
}

/*
Adj %
	 0   	 1 	 2 	 3 	 4 	4	5	6	7	8     <==star count
1%	91%	92%	93%	94%	95%	105%	106%	107%	108%	109%
2%	88%	89%	91%	93%	95%	105%	107%	109%	111%	114%
3%	84%	87%	89%	92%	95%	105%	108%	111%	115%	118%
4%	81%	84%	88%	91%	95%	105%	109%	114%	118%	123%
5%	77%	81%	86%	90%	95%	105%	110%	116%	122%	128%
6%	74%	79%	84%	89%	95%	105%	111%	118%	125%	133%
7%	71%	76%	82%	88%	95%	105%	112%	120%	129%	138%
8%	68%	74%	80%	87%	95%	105%	113%	122%	132%	143%
9%	65%	72%	79%	86%	95%	105%	114%	125%	136%	148%
10%	62%	69%	77%	86%	95%	105%	116%	127%	140%	154%
11%	60%	67%	75%	85%	95%	105%	117%	129%	144%	159%
12%	57%	65%	74%	84%	95%	105%	118%	132%	148%	165%
13%	54%	63%	72%	83%	95%	105%	119%	134%	152%	171%
*/
#define PERCENTAGE_RANGE 108  //108 = 8%
void eco_visual(char *retbuf) {
  //enable our varriables
  unsigned long tank_cons, outing_cons;
  unsigned long tfuel, tdist;
  int stars;

  tfuel = params.trip[OUTING].fuel;
  tdist = params.trip[OUTING].dist;
  
  if(tdist > 100 && tfuel!=0) {//Make sure no devisions by Zero.
    outing_cons = tfuel / (tdist / 1000);  //our current trip since engine start
    tfuel = params.trip[TANK].fuel;
    tdist = params.trip[TANK].dist;
    tank_cons = tfuel / (tdist / 1000);  //our results for the current tank of gas
  } else {  //give some dummy numbers to avoid devide by zero numbers
    tank_cons = 100;
    outing_cons = 101;
  }

  //lets start off in the middle
  stars = 3; // 3 = Average.
  if ( outing_cons < tank_cons ) {          //doing good :)
    outing_cons = (outing_cons*105) / 100; //Check if within 5% of TANK for Average result
    //Loop to check how much better we are doing
    //Each time the smaller number will be increased by a set percentage
    //in order to add or subtract from our star count.
    while(outing_cons < tank_cons && stars < 7) {  
      outing_cons = (outing_cons*PERCENTAGE_RANGE) / 100;
      stars++;
    }
    outing_cons=0;
  } else if (outing_cons > tank_cons) {  //doing bad... so far...
    tank_cons = (tank_cons*105) / 100;   //Check if within 5% of TANK for Average result
    while(outing_cons > tank_cons  && stars > 0) {  //Loop to check how much worse we are doing
      tank_cons = (tank_cons*PERCENTAGE_RANGE) / 100;
      stars--;
    } 
  } //else they are equal, do nothing.
 
  //Now we have our star count, use it as an index to access the text
  sprintf_P(retbuf, PSTR("%s"), (char*)pgm_read_word(&(econ_Visual[stars])));
} 

//get_engine_on_time will return the time since the engine has started
void get_engine_on_time(char *retbuf) 
{
  unsigned long run_time;
  int hours, minutes, seconds;  //to store the time
  
#ifdef useECUState
  if (ECUconnection) {//update with current time, if the car is running
#else
  if(has_rpm) {//update with current time, if the car is running
#endif
    run_time = calcTimeDiff(engine_on, millis());    //We now have the number of ms
  } else { //car is not running.  Display final time when stopped.
    run_time = calcTimeDiff(engine_on, engine_off);
  }
  //Lets display the running time
  //hh:mm:ss
  hours =   run_time / MILLIS_PER_HOUR;
  minutes = (run_time % MILLIS_PER_HOUR) / MILLIS_PER_MINUTE;
  seconds = (run_time % MILLIS_PER_MINUTE) / MILLIS_PER_SECOND;
  
  //Now we have our varriables parsed, lets display them
  sprintf_P(retbuf, PSTR("%d:%02d:%02d"), hours, minutes, seconds);
}


void get_cost(char *retbuf, byte ctrip)
{
  unsigned long cents;
  unsigned long fuel;
  char decs[16];
  params.gas_price;  // x/1000 = dollars
  fuel = params.trip[ctrip].fuel / 10000; //cL
  cents =  fuel * params.gas_price / 1000; //now have $$$$cc
  long_to_dec_str(cents, decs, 2);
  sprintf_P(retbuf, PSTR("$%s"), decs);
}
