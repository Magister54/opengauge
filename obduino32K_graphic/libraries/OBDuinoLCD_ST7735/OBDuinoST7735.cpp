#include "OBDuinoST7735.h"

#include <ST7735.h>
#include <SPI.h> 

#if (sclk == 0)
  ST7735 tft = ST7735(cs, dc, rst); 
#endif

#if (sclk > 0)
  ST7735 tft = ST7735(cs, dc, mosi, sclk, rst); 
#endif

//--------------------------------------------------------------------------------

OBDuinoLCD::OBDuinoLCD(void)
{
  SetCursor(0, 0);
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::InitOBDuinoLCD(void)
{
  SPI.setClockDivider(TFTInitSPISpeed);
  
  tft.initR();               // initialize a ST7735R chip
  tft.writecommand(ST7735_DISPON);

  #if TFTInitSPISpeed != TFTDataSPISpeed
    SPI.setClockDivider(TFTDataSPISpeed);
  #endif
  
  tft.fillScreen(CL_BLACK); 
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::LCDInitChar(void)
{
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::SetCursor(byte Position, byte Row)
{
  tft_row = Row;
  tft_position = Position;
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::PrintWarningChar(char c)
{
  if (tft_position >= LCD_COLS)
    return;

  tft.redrawChar(WarningPosition(tft_position, tft_row), c, CL_MAIN, CL_BLACK);
  tft_position++;
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::PrintWarning(char *string)
{
  while (string[0] != 0)
  {
    PrintWarningChar(string[0]);
    string++;
  }  
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::PrintWarning_P(char *string)
{
  char c;
  while ((c = pgm_read_byte(string++)))
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
  for (tft_row = 0; tft_row < 2; tft_row++)
    for (tft_position = 0; tft_position < LCD_COLS;)
      PrintWarningChar(0x00);
  
  tft_row = 0;
  tft_position = 0;
}
//--------------------------------------------------------------------------------

static uint16_t BarColors[4+8] PROGMEM = {
                                           CL_LIGHT_GREEN, CL_GREEN, CL_YELLOW, CL_RED,
                                           CL_RED, CL_RED, CL_ORANGE, CL_YELLOW, CL_GREEN, CL_GREEN, CL_YELLOW, CL_RED
                                         }; 
//--------------------------------------------------------------------------------

void OBDuinoLCD::LCDBar(byte Position, uint16_t Value, uint16_t MaxValue, char *string)
{
  uint16_t Color;
  byte i;
  byte Left;
  byte Top;
  byte Length = strlen(string);
  
  if (Position & 0x02) //Horizontal
  {
    Left = 6;
    Top  = 111 + 9 * (Position & 0x01);
  
    // Draw bar
    for (i = 0; i < 16; i++)
    {
      Color = CL_BLACK;
    
      if (Value > MaxValue / 16 * i)
        Color = pgm_read_word(BarColors + byte(i / 4));

      Left += tft.redrawChar(Left, Top, 10, Color, Color);
    }
  
    // Draw text
    Left += 6;
  
    for (i = 0; i < Length; i++)
      Left += tft.redrawChar(Left, Top, string[i], CL_MAIN, CL_BLACK);
  }
  else //Vertical
  {
    Left = 154 * (Position & 0x01);
    
    // Draw bar
    for (i = 0; i < 15; i++)
    {
      Color = CL_BLACK;
    
      if (Value > MaxValue / 16 * i)
        Color = pgm_read_word(BarColors + ((Position & 0x04) ? (4 + byte(i / 2)) : byte(i / 4)));

      tft.redrawChar(Left, 120 - i * 8, 10, Color, Color);
    }  

    // Draw text
    Left = (Position & 0x08) ? (tft.width - Length * 6) : 0;
  
    for (i = 0; i < Length + 2; i++)
      Left += tft.redrawChar(Left, 0, (i < Length) ? string[i] : 0x00, CL_MAIN, CL_BLACK);
  }
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::LCDNum(byte Position, char *string)
{ 
  byte Size     =   Position & 0x07;
  byte Top      = ((Position & 0xF0) >> 4) * 9 + 9 + 2;

  char *output_str = string;
  
  if (Size == 6)
  {
    output_str = string + 20;
    sprintf_P(output_str, PSTR("%7s"), string);
  }
  
  byte Length = strlen(output_str);
  
  byte Left = 20 -                           // default
              ((Size == 4) ? 6 : 0);         // for 2-3rd rows (small font)

  for (byte i = 0; i < Length; i++)
    Left += tft.redrawChar(Left, Top, output_str[i], CL_MAIN, CL_BLACK, Size);
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::LCDTime(char *string)
{
  byte Length = strlen(string);
  byte Left = 60;
  for (byte i = 0; i < Length; i++)
    Left += tft.redrawChar(Left, 0, string[i], CL_MAIN, CL_BLACK);  
}
//--------------------------------------------------------------------------------

void OBDuinoLCD::LCDClearBottom(void)
{
  tft.fillRect(6, 107, 148, 3, CL_BLACK);
}
//--------------------------------------------------------------------------------

