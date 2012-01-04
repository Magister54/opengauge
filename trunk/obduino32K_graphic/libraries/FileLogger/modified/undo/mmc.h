/* 
Original code has been modified to remove SPI functions and
couple to Arduino SPI library instead.
Also, as I'm going to read/write only 1 sector per time,
I have simplified the interface

Eduardo Garcia (egarcia@stream18.com)

contains code from:

sd2iec - SD/MMC to Commodore serial bus interface/controller
   Copyright (C) 2007,2008  Ingo Korb <ingo@akana.de>

   Inspiration and low-level SD/MMC access based on code from MMC2IEC
     by Lars Pontoppidan et al., see sdcard.c|h and config.h.

   sdcard.c: SD/MMC access routines

   Extended, optimized and cleaned version of code from MMC2IEC,
   original copyright header follows:

//
// Title        : SD/MMC Card driver
// Author       : Lars Pontoppidan, Aske Olsson, Pascal Dufour,
// Date         : Jan. 2006
// Version      : 0.42
// Target MCU   : Atmel AVR Series
//
// CREDITS:
// This module is developed as part of a project at the technical univerisity of
// Denmark, DTU.
//
// DESCRIPTION:
// This SD card driver implements the fundamental communication with a SD card.
// The driver is confirmed working on 8 MHz and 14.7456 MHz AtMega32 and has
// been tested successfully with a large number of different SD and MMC cards.
//
// DISCLAIMER:
// The author is in no way responsible for any problems or damage caused by
// using this code. Use at your own risk.
//
// LICENSE:
// This code is distributed under the GNU Public License
// which can be found at http://www.gnu.org/licenses/gpl.txt
//
*/

#ifndef __MMC_H__
#define __MMC_H__

#include <WProgram.h>
#include <inttypes.h>
#include "Spi.h"


const unsigned short BYTESPERSECTOR = 512;

#define CONFIG_SD_AUTO_RETRIES 5
#define SD_SUPPLY_VOLTAGE (1L<<18)

/* Disk Status Bits (byte) */
const byte STA_NOINIT = 0x01; 	/* Drive not initialized */
const byte STA_NODISK = 0x02; 	/* No medium in the drive */
const byte STA_PROTECT = 0x04; 	/* Write protected */

/* Results of Disk Functions */
typedef enum {
  RES_OK = 0,		/* 0: Successful */
  RES_ERROR,		/* 1: R/W Error */
  RES_WRPRT,		/* 2: Write Protected */
  RES_NOTRDY,		/* 3: Not Ready */
  RES_PARERR		/* 4: Invalid Parameter */
} 
DRESULT;



/* Will be set to DISK_ERROR if any access on the card fails */
enum diskstates
{ 
  DISK_CHANGED = 0,
  DISK_REMOVED,
  DISK_OK,
  DISK_ERROR
};


// SD/MMC commands
#define GO_IDLE_STATE           0
#define SEND_OP_COND            1
#define SWITCH_FUNC             6
#define SEND_IF_COND            8
#define SEND_CSD                9
#define SEND_CID               10
#define STOP_TRANSMISSION      12
#define SEND_STATUS            13
#define SET_BLOCKLEN           16
#define READ_SINGLE_BLOCK      17
#define READ_MULTIPLE_BLOCK    18
#define WRITE_BLOCK            24
#define WRITE_MULTIPLE_BLOCK   25
#define PROGRAM_CSD            27
#define SET_WRITE_PROT         28
#define CLR_WRITE_PROT         29
#define SEND_WRITE_PROT        30
#define ERASE_WR_BLK_STAR_ADDR 32
#define ERASE_WR_BLK_END_ADDR  33
#define ERASE                  38
#define LOCK_UNLOCK            42
#define APP_CMD                55
#define GEN_CMD                56
#define READ_OCR               58
#define CRC_ON_OFF             59

// SD ACMDs
#define SD_STATUS                 13
#define SD_SEND_NUM_WR_BLOCKS     22
#define SD_SET_WR_BLK_ERASE_COUNT 23
#define SD_SEND_OP_COND           41
#define SD_SET_CLR_CARD_DETECT    42
#define SD_SEND_SCR               51

// R1 status bits
#define STATUS_IN_IDLE          1
#define STATUS_ERASE_RESET      2
#define STATUS_ILLEGAL_COMMAND  4
#define STATUS_CRC_ERROR        8
#define STATUS_ERASE_SEQ_ERROR 16
#define STATUS_ADDRESS_ERROR   32
#define STATUS_PARAMETER_ERROR 64


namespace mmc {
  /**
   * initialize - prepare system for accessing mmc cards in spi mode
   */
  byte initialize();

  /**
   * readSector - reads 1 sector from the SD card to buffer
   * @buffer: pointer to the buffer
   * @sector: sector to be read
   *
   * This function reads one sectors from the SD card
   * to buffer. Returns RES_ERROR if an error occured or
   * RES_OK if successful. Up to SD_AUTO_RETRIES will be made if
   * the calculated data CRC does not match the one sent by the
   * card. If there were errors during the command transmission
   * disk_state will be set to DISK_ERROR and no retries are made.
   */
  byte readSector(byte *buffer, unsigned long sector);

  /**
   * writeSector - writes one sector from buffer to the SD card
   * @buffer: pointer to the buffer
   * @sector: sector to be written
   *
   * This function writes one sector from buffer to the SD card.
   * Returns RES_ERROR if an error occured,
   * RES_WPRT if the card is currently write-protected or RES_OK
   * if successful. Up to SD_AUTO_RETRIES will be made if the card
   * signals a CRC error. If there were errors during the command
   * transmission disk_state will be set to DISK_ERROR and no retries
   * are made.
   */
  byte writeSector(const byte *buffer, uint32_t sector);

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
  int sendCommand(const uint8_t command, const uint32_t parameter, const uint8_t  deselect);

  diskstates checkDiskState();
};


#endif // __MMC_H__
