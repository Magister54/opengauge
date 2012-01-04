// LCD LiquidCrystal library for OBDuino
// Version 1.0 2012.01.04 
// Eimantas e.jatkonis@teja.lt

#ifndef _OBDUINOLiquidCrystal_H_INCLUDED
#define _OBDUINOLiquidCrystal_H_INCLUDED

#include <LiquidCrystal.h>

#include <stdio.h>
#include <WProgram.h>
#include <avr/pgmspace.h>

#define LCD_RS 4
#define LCD_ENABLE 5

#define LCD_DATA1 7
#define LCD_DATA2 8
#define LCD_DATA3 12
#define LCD_DATA4 13
  
/* LCD Display parameters */
/* Adjust LCD_COLS or LCD_ROWS if LCD is different than 16 characters by 2 rows*/
// Note: Not currently tested on display larger than 16x2

// How many rows of characters for the LCD (must be at least two)
#define LCD_ROWS      2
// How many characters across for the LCD (must be at least sixteen)
#define LCD_COLS      16
// Calculate the middle point of the LCD display width
#define LCD_SPLIT    (LCD_COLS / 2)
//Calculate how many PIDs fit on a data screen (two per line)
#define LCD_PID_COUNT  (LCD_ROWS * 2)

#define ContrastPin 6
#define BrightnessPin 9  

#define BIGFontFontCount 3
#define BIGFontSymbolCount 8

class OBDuinoLCD 
{
  public:
    // Same function list in all display H files
    OBDuinoLCD(void);
    void InitOBDuinoLCD(void);

    void LCDInitChar(void);

    void SetCursor(byte Position, byte Row);

    void PrintWarningChar(char c);
    void PrintWarning(char *string);
    void PrintWarning_P(char *string);

    void ClearPrintWarning_P(char *string);
    void ClearWarning(void);

    // Additional functions
    void LCDBigNumCharInit(byte Type);
    void BigNum(char *txt, char *txt1);
	    
  private: 
    byte BigFontType;
};

#endif

