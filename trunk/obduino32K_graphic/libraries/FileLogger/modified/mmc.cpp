// see header for credits

#include "mmc.h"

// PORTB pin numbers
//
// arduino D10
#define SS    2

// Macros for setting slave select:
//
#define SlaveSelect()    PORTB &= ~_BV(SS)
#define SlaveDeselect()  PORTB |= _BV(SS)

#define DESELECT_AFTER    	   1
#define DONT_DESELECT_AFTER    0

static volatile diskstates disk_state = DISK_ERROR;

static uint32_t spiTransferLong(const uint32_t data) {
  // It seems to be necessary to use the union in order to get efficient
  // assembler code.
  // Beware, endian unsafe union
  union {
    unsigned long l;
    unsigned char c[4];
  } 
  long2char;

  long2char.l = data;
  
  long2char.c[3] = SPI.transfer(long2char.c[3]);
  long2char.c[2] = SPI.transfer(long2char.c[2]);
  long2char.c[1] = SPI.transfer(long2char.c[1]);
  long2char.c[0] = SPI.transfer(long2char.c[0]);

  return long2char.l;
}


static char sdResponse(byte expected) {
  unsigned short count = 0x0FFF;

  while ((SPI.transfer(0xFF) != expected) && count )
    count--;

  // If count didn't run out, return success
  return (count != 0);
}


static char sdWaitWriteFinish(void) {
  unsigned short count = 0xFFFF; // wait for quite some time

  while ((SPI.transfer(0xFF) == 0) && count )
    count--;

  // If count didn't run out, return success
  return (count != 0);
}


static void deselectCard(void) {
  // Send 8 clock cycles
  SlaveDeselect();
  SPI.transfer(0xff);
}

static byte crc7update(byte crc, const byte data) {
  byte i;
  bool bit;
  byte c;

  c = data;
  for (i = 0x80; i > 0; i >>= 1) {
    bit = crc & 0x40;
    if (c & i) {
      bit = !bit;
    }
    crc <<= 1;
    if (bit) {
      crc ^= 0x09;
    }
  }
  crc &= 0x7f;
  return crc & 0x7f;
}


/**
 * sendCommand - send a command to the SD card
 * @command  : command to be sent
 * @parameter: parameter to be sent
 * @deselect : Flags if the card should be deselected afterwards
 *
 * This function calculates the correct CRC7 for the command and
 * parameter and transmits all of it to the SD card. If requested
 * the card will be deselected afterwards.
 */
int mmc::sendCommand(const byte  command, const uint32_t parameter, const byte  deselect) 
{
  union {
    unsigned long l;
    unsigned char c[4];
  } 
  long2char;

  byte  i,crc,errorcount;
  uint16_t counter;

  long2char.l = parameter;
  crc = crc7update(0  , 0x40+command);
  crc = crc7update(crc, long2char.c[3]);
  crc = crc7update(crc, long2char.c[2]);
  crc = crc7update(crc, long2char.c[1]);
  crc = crc7update(crc, long2char.c[0]);
  crc = (crc << 1) | 1;

  errorcount = 0;
  while (errorcount < CONFIG_SD_AUTO_RETRIES) 
  {
    // Select card
	  SlaveSelect();

    // Transfer command
    SPI.transfer(0x40+command);
    spiTransferLong(parameter);
    SPI.transfer(crc);

    // Wait for a valid response
    counter = 0;
    do {
      i = SPI.transfer(0xff);
      counter++;
    } while (i & 0x80 && counter < 0x1000);

    // Check for CRC error
    // can't reliably retry unless deselect is allowed
    if (deselect && (i & STATUS_CRC_ERROR)) 
    {
      //      uart_putc('x');
      deselectCard();
      errorcount++;
      continue;
    }

    if (deselect) deselectCard();
    break;
  }

  return i;
}

byte mmc::initialize()
{
  // Init in slow clock mode
  SPCR = 0;
  SPCR = (1<<SPE) | (1<<MSTR);
//  SPCR = (SDInitSPISpeed & SPI_CLOCK_MASK) | (1<<SPE) | (1<<MSTR);
  SPI.setClockDivider(SDInitSPISpeed);

	byte result = mmc::initialize_internal();
		
  // Setup is done, could speed up connection (need testing)
//  SPCR = (SDDataSPISpeed & SPI_CLOCK_MASK) | (1<<SPE) | (1<<MSTR);
  SPI.setClockDivider(SDDataSPISpeed);

  return result;
}

byte mmc::initialize_internal() 
{
  byte  i;
  uint16_t counter;
  uint32_t answer;

  disk_state = DISK_ERROR;

//            76543210
//  SPI.mode(B01010011);
//  SPCR = ((B01010011 | SPI_CLOCK_DIV128) & 0x7F) | (1<<SPE) | (1<<MSTR);

  // enable SPI master with configuration byte specified
//  SPCR = 0;
//  SPCR = (SPI_CLOCK_DIV128 & 0x03) | (1<<SPE) | (1<<MSTR);

  SlaveDeselect();

  // Send 80 clks
  for (i=0; i<10; i++)
    SPI.transfer(0xFF);

  // Reset card
  i = sendCommand(GO_IDLE_STATE, 0, DESELECT_AFTER);
  if (i != 1) 
    return STA_NOINIT | STA_NODISK;

  counter = 0xffff;
  // According to the spec READ_OCR should work at this point
  // without retries. One of my Sandisk-cards thinks otherwise.
  do 
  {
    // Send CMD58: READ_OCR
    i = sendCommand(READ_OCR, 0, DONT_DESELECT_AFTER);
    if (i > 1) {
      // kills my Sandisk 1G which requires the retries in the first place
      // deselectCard();
    }
  } while (i > 1 && counter-- > 0);

  if (counter > 0) 
  {
	  answer = spiTransferLong(0);

    // See if the card likes our supply voltage
    if (!(answer & SD_SUPPLY_VOLTAGE)) 
    {
      // The code isn't set up to completely ignore the card,
      // but at least report it as nonworking
      deselectCard();
      return STA_NOINIT | STA_NODISK;
    }
  }

  // Keep sending CMD1 (SEND_OP_COND) command until zero response
  counter = 0xffff;
  do
  {
    i = sendCommand(SEND_OP_COND, 1L<<30, DESELECT_AFTER);
    counter--;
  } while (i != 0 && counter > 0);

  if (counter==0) 
    return STA_NOINIT | STA_NODISK;

  // Send MMC CMD16(SET_BLOCKLEN) to 512 bytes
  i = sendCommand(SET_BLOCKLEN, 512, DESELECT_AFTER);
  if (i != 0) 
    return STA_NOINIT | STA_NODISK;

  // Thats it!
  disk_state = DISK_OK;
  
  // Setup is done, could speed up connection (need testing)
//  SPCR = (SPI_CLOCK_DIV16 & 0x03) | (1<<SPE) | (1<<MSTR);
  
  return RES_OK;
}

byte mmc::readSector(byte *buffer, uint32_t sector) 
{
	byte res,tmp,errorcount;

  errorcount = 0;
  while (errorcount < CONFIG_SD_AUTO_RETRIES) 
  {
    res = sendCommand(READ_SINGLE_BLOCK, (sector) << 9, DONT_DESELECT_AFTER);

    if (res != 0) 
    {
		  SlaveDeselect();
      disk_state = DISK_ERROR;
      return RES_ERROR;
    }

    // Wait for data token
    if (!sdResponse(0xFE)) 
    {
		  SlaveDeselect();
      disk_state = DISK_ERROR;
      return RES_ERROR;
    }

    uint16_t i;

    // Get data
    for (i=0; i<512; i++) {
      tmp = SPI.transfer(0xff);
      *(buffer++) = tmp;
    }

    break;
  }
  deselectCard();

  if (errorcount >= CONFIG_SD_AUTO_RETRIES) 
    return RES_ERROR;

  return RES_OK;
}

byte mmc::writeSector(const byte *buffer, uint32_t sector) 
{
  byte res,errorcount,status;

  errorcount = 0;

  while (errorcount < CONFIG_SD_AUTO_RETRIES) 
  {
    res = sendCommand(WRITE_BLOCK, (sector)<<9, DONT_DESELECT_AFTER);

    if (res != 0) 
   	{
		  SlaveDeselect();
      disk_state = DISK_ERROR;
      return RES_ERROR;
    }

    // Send data token
    SPI.transfer(0xFE);

    uint16_t i;
    const byte *oldbuffer = buffer;

    // Send data
    for (i=0; i<512; i++) {
      SPI.transfer(*(buffer++));
    }

    // Send CRC
    SPI.transfer(0);
    SPI.transfer(0);

    // Get and check status feedback
    status = SPI.transfer(0xFF);

    // Retry if neccessary
    if ((status & 0x0F) != 0x05) {
      //	uart_putc('X');
      errorcount++;
      buffer = oldbuffer;
      continue;
    }

    // Wait for write finish
    if (!sdWaitWriteFinish()) {
  		SlaveDeselect();
      disk_state = DISK_ERROR;
      return RES_ERROR;
    }
    break;
  }
  deselectCard();

  if (errorcount >= CONFIG_SD_AUTO_RETRIES) 
  {
    if (!(status & STATUS_CRC_ERROR))
      disk_state = DISK_ERROR;
    return RES_ERROR;
  }

  return RES_OK;
}

diskstates mmc::checkDiskState() 
{
	return disk_state;
}