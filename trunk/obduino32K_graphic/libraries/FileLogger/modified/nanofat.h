//
// Title        : nanofat driver
// Author       : Eduardo García (egarcia@stream18.com)
// Date         : April 2009
// Id			: $Id: nanofat.h 20 2009-04-23 00:03:12Z stream18 $
//
//
// CREDITS:
// Contains code from the microfat driver developed by David Cuartielles
// and Ino Schlaucher for the SD_uFAT project (http://blushingboy.net/p/SDuFAT/)
//
// DESCRIPTION:
// This FAT16 filesystem driver implements a small part of a full FAT16 driver.
// Only provides minimal functionallity to log data into a pre-existent file in the
// root folder.
//
// DISCLAIMER:
// The author is in no way responsible for any problems or damage caused by
// using this code. Use at your own risk.
//
// LICENSE:
// This code is distributed under the GNU Public License
// which can be found at http://www.gnu.org/licenses/gpl.txt
//


#ifndef __NANOFAT_H__
#define __NANOFAT_H__

#include <inttypes.h>


// Info on FAT16 structure: http://www.beginningtoseethelight.org/fat16/
// More info: http://www.ntfs.com/fat-systems.htm

// This is part of the MBR
// Info on MBR: http://en.wikipedia.org/wiki/Master_boot_record
typedef struct {
  byte bootable;
  byte chsAddrOfFirstSector[3];
  byte partitionType;
  byte chsAddrOfLastSector[3];
  uint32_t lbaAddrOfFirstSector;
  uint32_t partitionLengthSectors;
} partition_record;

// This is a VBR
// Info on VBR: http://en.wikipedia.org/wiki/Volume_boot_record
// more info: http://home.teleport.com/~brainy/fat16.htm
typedef struct {
  byte jump[3];
  char oemName[8];
  uint16_t bytesPerSector;
  byte sectorsPerCluster;
  uint16_t reservedSectors;
  byte fatCopies;
  uint16_t rootDirectoryEntries;
  uint16_t totalFilesystemSectors;
  byte mediaDescriptor;
  uint16_t sectorsPerFAT;
  uint16_t sectorsPerTrack;
  uint16_t headCount;

  uint32_t hiddenSectors;
  uint32_t totalFilesystemSectors2;
  byte logicalDriveNum;
  byte reserved;
  byte extendedSignature;
  uint32_t partitionSerialNum;
  char volumeLabel[11];
  char fsType[8];
  byte bootstrapCode[447];
  byte signature[2];
} boot_sector;

typedef struct {
  char filespec[11];
  byte attributes;
  byte reserved[10];
  uint16_t time;
  uint16_t date;
  uint16_t startCluster;
  uint32_t fileSize;
} directory_entry;


namespace nanofat {
  bool initialize(byte* buffer);
  bool append(const char* filename, byte buffer[], unsigned long length);
};


#endif // __NANOFAT_H__
