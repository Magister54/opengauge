// LCD TFT ST7735 library for OBDuino
// Version 1.0 2012.01.04 
// Eimantas e.jatkonis@teja.lt

#ifndef _OBDUINOST7735_H_INCLUDED
#define _OBDUINOST7735_H_INCLUDED

#include <ST7735.h>
#include <SPI.h> 

// Init slow SPI_CLOCK_DIV16 or similar
#define TFTInitSPISpeed SPI_CLOCK_DIV8
// Work fast (default), can be used DIV8 or same DIV16 (must be tested in each case)
#define TFTDataSPISpeed SPI_CLOCK_DIV8

// If we are using the hardware SPI interface, these are the pins (for future ref)
// Can be left undefined
#define sclk 0
//13
#define mosi 0
//11

// You can also just connect the reset pin to +5V or Arduino RESET (we do a software reset)
#define rst 7

// these pins are required
#define cs 9
#define dc 6 

// to draw images from the SD card, we will share the hardware SPI interface

#ifndef cbi
#define cbi(sfr, bit) (_SFR_BYTE(sfr) &= ~_BV(bit))
#endif
#ifndef sbi
#define sbi(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit))
#endif 

#define WarningPosition(x, y) 8 + 6 + x * 6, 92 + y * 8

#define LCD_ROWS 2
#define LCD_COLS 22 
#define LCD_SPLIT     (LCD_COLS / 2)
#define LCD_PID_COUNT (LCD_ROWS * 2) 

// Color definitions
#define	CL_BLACK           0x0000
#define	CL_BLUE            0x001F
#define	CL_RED             0xF800
#define	CL_GREEN           0x07E0
#define CL_CYAN            0x07FF
#define CL_MAGENTA         0xF81F
#define CL_YELLOW          0xFFE0  
#define CL_WHITE           0xFFFF 

#define CL_LIGHT_GREEN     0x7FEF
#define CL_DARK_BLUE       0x7BFF
#define CL_BROWN           0xFBE7
#define CL_ORANGE          0xFD20

#define CL_MAIN            0xA3FF 
//0x7BFF

//                    Text   Color  Direction Pos
#define BARLeft      (0x00 + 0x00 + 0x00 +    0x00)
#define BARRight     (0x08 + 0x04 + 0x00 +    0x01)
#define BARBottom1   (0x00 + 0x00 + 0x02 +    0x00)
#define BARBottom2   (0x00 + 0x00 + 0x02 +    0x01)

//                    Top    TextLeft  Size
#define BARNumB00    (0x00 + 0x00 +    0x06)

#define BARNumM11    (0x30 + 0x08 +    0x04)
#define BARNumM12    (0x50 + 0x08 +    0x04)

#define BARNumM13    (0x70 + 0x08 +    0x04)
#define BARNumM14    (0x90 + 0x08 +    0x04)

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
    void LCDBar(byte Position, uint16_t Value, uint16_t MaxValue, char *string);
    void LCDNum(byte Position, char *string);

    void LCDTime(char *string);
    void LCDClearBottom(void);
  
  private:
    byte tft_row;
    byte tft_position;  
};

#endif

