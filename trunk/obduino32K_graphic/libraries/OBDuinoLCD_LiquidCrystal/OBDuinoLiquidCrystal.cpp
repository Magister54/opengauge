#include "OBDuinoLiquidCrystal.h"

//#include <LiquidCrystal.h>

//--------------------------------------------------------------------------------

LiquidCrystal lcd(LCD_RS, LCD_ENABLE, LCD_DATA1, LCD_DATA2, LCD_DATA3, LCD_DATA4);

//--------------------------------------------------------------------------------

OBDuinoLCD::OBDuinoLCD(void)
{
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::InitOBDuinoLCD(void)
{
  lcd.begin(LCD_COLS, LCD_ROWS);
  LCDInitChar();
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::LCDInitChar(void)
{
  //creating the custom fonts (8 char max)
  // char 0 is not used
  // 1&2 is the L/100 datagram in 2 chars only
  // 3&4 is the km/h datagram in 2 chars only
  // 5 is the � char (degree)
  // 6&7 is the mi/g char
#define NB_CHAR  7
  // set cg ram to address 0x08 (B001000) to skip the
  // first 8 rows as we do not use char 0
  lcd.command(B01001000);
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
      lcd.write(pgm_read_byte(&chars[y*NB_CHAR+x])); //write the character data to the character generator ram  
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::SetCursor(byte Position, byte Row)
{
  lcd.setCursor(Position, Row);
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::PrintWarningChar(char c)
{
	lcd.write(c);
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::PrintWarning(char *string)
{
	lcd.print(string);
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::PrintWarning_P(char *string)
{
  char c;
  while( (c = pgm_read_byte(string++)) )
    PrintWarningChar(c);
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::ClearPrintWarning_P(char *string)
{
  ClearWarning();
  PrintWarning_P(string);	
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::ClearWarning(void)
{
	lcd.clear();
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::LCDBigNumCharInit(byte Type)
{
	BigFontType = Type;
	
  //creating the custom fonts:
  lcd.command(B01001000); // set cgram
  
  static prog_uchar chars[BIGFontFontCount*BIGFontSymbolCount*8] PROGMEM = {
    //2x2_alpha 
    B00000, B11111, B11000, B00011, B11111, B11111, B11111, B11111,
    B00000, B11111, B11000, B00011, B11111, B11111, B11111, B11111,
    B00000, B00011, B11000, B00011, B11000, B00011, B00000, B00000,
    B00000, B00011, B11000, B00011, B11000, B00011, B00000, B00000,
    B00000, B00011, B11000, B00011, B11000, B00011, B00000, B00000,
    B00000, B00011, B11000, B00011, B11000, B00011, B00000, B00000,
    B11111, B00011, B11111, B11111, B11111, B11111, B00000, B11111,
    B11111, B00011, B11111, B11111, B11111, B11111, B00000, B11111,

    //2x2_beta
    B11111, B11111, B11000, B00011, B11111, B11111, B11111, B00000,
    B11111, B11111, B11000, B00011, B11111, B11111, B11111, B00000,
    B11000, B00011, B11000, B00011, B11000, B00011, B00000, B00000,
    B11000, B00011, B11000, B00011, B11000, B00011, B00000, B00000,
    B11000, B00011, B11000, B00011, B11000, B00011, B00000, B00000,
    B11000, B00011, B11000, B00011, B11000, B00011, B00000, B00000,
    B11000, B00011, B11111, B11111, B11111, B11111, B00000, B11111,
    B11000, B00011, B11111, B11111, B11111, B11111, B00000, B11111,

    //2x3
    B11111, B00000, B11111, B11111, B00000, B00000, B00000, B00000,
    B11111, B00000, B11111, B11111, B00000, B00000, B00000, B00000, 
    B00000, B00000, B00000, B11111, B00000, B00000, B00000, B00000, 
    B00000, B00000, B00000, B11111, B00000, B00000, B00000, B00000, 
    B00000, B00000, B00000, B11111, B00000, B00000, B00000, B00000, 
    B00000, B00000, B00000, B11111, B01110, B00000, B00000, B00000, 
    B00000, B11111, B11111, B11111, B01110, B00000, B00000, B00000, 
    B00000, B11111, B11111, B11111, B01110, B00000, B00000, B00000 
  };

  for (byte x = 0; x < BIGFontSymbolCount; x++)
    for (byte y = 0; y < 8; y++)
      PrintWarningChar(pgm_read_byte(&chars[BigFontType*BIGFontSymbolCount*8 + y*BIGFontSymbolCount + x])); //write the character data to the character generator ram
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::BigNum(char *txt, char *txt1)
{
  static prog_char bignumchars1[40*BIGFontFontCount] PROGMEM = { 
                          5,  2, 0, 0,
                          2, 32, 0, 0,
                          8,  6, 0, 0,
                          7,  6, 0, 0,
                          3,  4, 0, 0,
                          5,  8, 0, 0,
                          5,  8, 0, 0,
                          7,  2, 0, 0,
                          5,  6, 0, 0,
                          5,  6, 0, 0,

                          1,  2, 0, 0,
                          2, 32, 0, 0,
                          7,  6, 0, 0,
                          7,  6, 0, 0,
                          3,  4, 0, 0,
                          5,  7, 0, 0,
                          1,  7, 0, 0,
                          7,  2, 0, 0,
                          5,  6, 0, 0,
                          5,  6, 0, 0,

                          4, 1, 4, 0,
                          1, 4, 32, 0,
                          3, 3, 4, 0,
                          1, 3, 4, 0,
                          4, 2, 4, 0,
                          4, 3, 3, 0,
                          4, 3, 3, 0,
                          1, 1, 4, 0,
                          4, 3, 4, 0,
                          4, 3, 4, 0
                        };
  static prog_char bignumchars2[40*BIGFontFontCount] PROGMEM = { 
                          3,  4,  0, 0,
                          4,  1,  0, 0,
                          3,  1,  0, 0,
                          1,  4,  0, 0,
                          32, 2,  0, 0,
                          1,  4,  0, 0,
                          3,  4,  0, 0,
                          32, 2,  0, 0,
                          3,  4,  0, 0,
                          1,  4,  0, 0,

                          3,  4,  0, 0,
                          4,  8,  0, 0,
                          5,  8,  0, 0,
                          8,  4,  0, 0,
                          32, 2,  0, 0,
                          8,  6,  0, 0,
                          5,  6,  0, 0,
                          32, 2,  0, 0,
                          3,  4,  0, 0,
                          8,  4,  0, 0,
                          
                          4, 2, 4, 0,
                          2, 4, 2, 0,
                          4, 2, 2, 0,
                          2, 2, 4, 0,
                          32, 32, 4, 0,
                          2, 2, 4, 0,
                          4, 2, 4, 0,
                          32, 4, 32, 0,
                          4, 2, 4, 0,
                          2, 2, 4, 0
                        };

  //byte DecimalPointSymbols[BIGFontFontCount] = {5, '.', '.'};
  //DecimalPointSymbols[BigFontType]

  byte CharPos = 40*BigFontType;

  for (byte line = 0; line < 2; line++)
  {
    SetCursor(0, line);
    byte pos = 0;
    byte digitcount = 0;
    while (digitcount < 4)
    {
      digitcount++;
      if (txt[pos] >= '0' && txt[pos] <= '9')
      {
        byte address = CharPos + (txt[pos] - '0') * 4;
        PrintWarning_P(line==0?&bignumchars1[address]:&bignumchars2[address]);
        
        char mark = ' ';
        if (txt[pos+1] == '.' || txt[pos+1] == ',')
        {
          if (line == 1)
            mark = txt[pos+1];
          pos++;
        }  
        PrintWarningChar(mark);
        pos++;
      }
      else
        for (byte i=0; i<3; i++)
          PrintWarningChar(' ');
    }

    byte ScreenPos = 12;
    // print units on first row
    if (line == 0)
    {
      // need convert L/KM, MPG, C or F to normal symbols
      pos++; //skip space
      while (pos < 8 && txt[pos] != 0)
      {
        switch (txt[pos])
        {
          case 1 : 
          PrintWarningChar('L');
          ScreenPos+=1;
          break;
          case 2 : 
          PrintWarningChar('/');
          PrintWarningChar('k');
          PrintWarningChar('m');        
          ScreenPos+=3;
          break;
          case 3 : 
          PrintWarningChar('k');
          PrintWarningChar('m');
          ScreenPos+=2;
          break;
          case 4 : 
          PrintWarningChar('/');
          PrintWarningChar('h');
          ScreenPos+=2;
          break;
          case 5 : 
          break;
          case 6 : 
          PrintWarningChar('M');
          ScreenPos+=1;
          break;
          case 7 : 
          PrintWarningChar('P');
          PrintWarningChar('G');
          ScreenPos+=2;
          break;
          default : 
          PrintWarningChar(txt[pos]);
          ScreenPos+=1;
          break;
        }  
        pos++;
      }  
    }      
    else
    {
      // print any text on second row
      PrintWarning(txt1);
    }
    
    // clear end of line  
    for (byte i=ScreenPos; i<LCD_COLS; i++)
      PrintWarningChar(' ');    
  }    
}
//--------------------------------------------------------------------------------
