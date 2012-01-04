//
// Title        : nanofat driver
// Author       : Eduardo García (egarcia@stream18.com)
// Date         : April 2009
// Id			: $Id: nanofat.cpp 25 2009-05-01 12:42:06Z stream18 $
//
// See header for credits

#include <WProgram.h>
#include "nanofat.h"
#include "mmc.h"

static struct{
  word sectorsPerCluster;
  word bytesPerCluster;
  word cluster2;
  word FAT1Sector;
  word rootDirSect;
  directory_entry* de;
  byte* buffer;
  bool isFATLoaded;
} vars;

// Functions to recurse the FAT
// WE WILL ONLY USE 1 SECTOR PER FAT
// THERE WILL BE NO PROBLEM IF WE WORK ONLY WITH ONE FILE
// WE WILL MANAGE ONLY ONE FAT COPY
// Load first sector of FAT1 into the buffer
bool loadFAT1() {
	if( !vars.isFATLoaded) {
		if (RES_OK == mmc::readSector(vars.buffer, vars.FAT1Sector)) {
			vars.isFATLoaded = true;
		} else {
			return false;
		}
	}
	return true;
}

// Given a cluster, find the last cluster in the FAT chain
word findLastCluster(word cluster) {
	if( loadFAT1()) {
		word *clusters = (word *)vars.buffer;
		while( clusters[cluster] != 0xFFFF) {			
			cluster = clusters[cluster];
		}
	}

	return cluster;
}

// Given a cluster, find the next empty cluster in FAT, chain it
// and don't forget to write the changed FAT
word chainNextCluster(word cluster) {
	word newCluster = cluster + 1;

	if( loadFAT1()) {
		word *clusters = (word *)vars.buffer;
		while( clusters[newCluster] != 0x0000) {
			newCluster++;
		}
		clusters[newCluster] = 0xFFFF;
		clusters[cluster] = newCluster;
	}

	if (RES_OK != mmc::writeSector(vars.buffer, vars.FAT1Sector)) {
		return 0xFFFF;
	}

	return newCluster;
}

//
// Find and store some important FAT info
// Receive the buffer to store temporary data
//
bool nanofat::initialize(byte* buffer) {
  vars.buffer = buffer;
  vars.isFATLoaded = false;

  if( mmc::checkDiskState() == DISK_ERROR) {
	if( mmc::initialize() == DISK_ERROR) {
		return false;
	}
  }

  // Read first sector, the MBR, and write it to given buffer
  if (RES_OK != mmc::readSector(vars.buffer, 0)) {
    return false;
  }  

  // Locate the first entry on the table of primary partitions on MBR
  partition_record* p = (partition_record*)&vars.buffer[0x1be];
  unsigned long bootSector = p->lbaAddrOfFirstSector;

  // Read the first sector of first partition on disk (VBR=Volume Boot Record)
  if (RES_OK != mmc::readSector(vars.buffer, bootSector)) {
    return false;
  }

  // boot_sector points to the first sector of first partition on disk
  boot_sector* b = (boot_sector*)vars.buffer;

  if (BYTESPERSECTOR != b->bytesPerSector) {
    return false;
  }

  vars.sectorsPerCluster = b->sectorsPerCluster;
  vars.bytesPerCluster = BYTESPERSECTOR*vars.sectorsPerCluster;

  // Points to the first copy of FAT
  vars.FAT1Sector = bootSector + b->reservedSectors;

  // Calculate the sector where the RootDir is located
  vars.rootDirSect = vars.FAT1Sector + (b->fatCopies * b->sectorsPerFAT);

  // Size of the root directory entries in bytes
  unsigned long dirBytes = b->rootDirectoryEntries * 32;
  // Caculate the root directory entries size in sectors 
  unsigned long dirSects = dirBytes / BYTESPERSECTOR;
  if (dirBytes % BYTESPERSECTOR != 0) {
    ++dirSects;
  }

  // This is the first sector after the root directory,
  // where all other files and dirs reside
  vars.cluster2 = vars.rootDirSect + dirSects;
 
  return true;
}


//
// Find start sector for given filename and fill
// in sector and size variables passed as arguments
// After execution the vars structure is ready to change
// the file size in disk
//
bool locateFileStart(const char* filename,
					 unsigned long &firstSector,
					 unsigned long &size) {

  // Read the root folder's first sector
  if (RES_OK == mmc::readSector(vars.buffer, vars.rootDirSect)) {
	vars.isFATLoaded = false;

    // Pack the file name in "eight-plus-three" format
    char cookedName[11];
    for(int i = 0; i < 12; ++i) {
      cookedName[i] = 0x20;
    }
    for (int i = 0, j = 0; i < 12 && filename[i]; ++i) {
      if (filename[i] != '.') {
        cookedName[j] = filename[i] >= 96 ? filename[i] - 32 : filename[i];
        ++j;
      } else {
        j = 8;
      }
    }

    // The file MUST be located in root folder, and there MUST NOT be a lot of files
    // in the root folder, as we only check first sector of root folder...
    for (unsigned int i = 0; i < BYTESPERSECTOR; i += 32) {
	  vars.de = (directory_entry*)&vars.buffer[i];

      // don't match with deleted, [system/volname/subdir/hidden] files
      if (vars.de->filespec[0] != 0xe5 && (vars.de->attributes & 0x1e) == 0 && memcmp(cookedName, vars.de->filespec, 11) == 0) {
        size = vars.de->fileSize;
		if( size == 0) {
			// Allocate the first sector
			// ToDo: 1. Load FAT to find the first empty cluster
			//		 2. Put an 0xFFFF in this cluster entry to mark as last cluster in file
			//		 3. Write the FAT to disk
			//		 4. Reload the root folder sector
			//		 5. Store the located cluster in the de->startCluster field
			//		 6. Write the root folder to disk
		} else {
			firstSector = vars.cluster2 + ((vars.de->startCluster-2) * vars.sectorsPerCluster);
		}
        return true;
      }
    }
  }

  return false;
}

//
// This function MUST be called, if needed, immediately after calling "locateFileStart()"
// so we don't need to re-read the sector
//
bool incFileSize(unsigned long extraSize) {
    vars.de->fileSize += extraSize;

	// Write rootDir sector
    if (RES_OK != mmc::writeSector(vars.buffer, vars.rootDirSect)) {
		return false;
	}
	
	return true;
}

//
// Appends a data buffer to a file
//
bool nanofat::append(const char* filename, byte buffer[], unsigned long length) {
// This two variables MUST be static, as they are gonna be passed by reference
// Failing to declare them static will make the whole function fail
static unsigned long firstSector;
static unsigned long fileLength;

    if (locateFileStart(filename, firstSector, fileLength)) {

		if( !incFileSize(length)) {
			return false;
		}

		// To append, first find how many sectors in the 
		// last cluster do I have to traverse to get the last one
		word firstCluster = ((firstSector - vars.cluster2)/vars.sectorsPerCluster)+2;
		word bytesInLastCluster = fileLength % vars.bytesPerCluster;
		word sectorsInLastCluster = (bytesInLastCluster/ BYTESPERSECTOR);
		word bytesInLastSector = (bytesInLastCluster% BYTESPERSECTOR);
		
		word lastCluster = findLastCluster(firstCluster);
		unsigned long lastSector = vars.cluster2 + ((lastCluster-2) * vars.sectorsPerCluster) + sectorsInLastCluster;

		// We need to read this sector, as we're trying to append
		if (RES_OK == mmc::readSector(vars.buffer, lastSector)) {
			vars.isFATLoaded = false;
		} else {
			return false;
		}
				
		// To append, copy the input data into the buffer, after the existing data
		word lastSectorFreeBytes = BYTESPERSECTOR - bytesInLastSector;
		word bytesToWrite = length;
		// Maybe we need more sectors to complete the write
		if( bytesToWrite > lastSectorFreeBytes) {
			bytesToWrite = lastSectorFreeBytes;
		}
		for(word i=0, j=bytesInLastSector; i<bytesToWrite; i++, j++) {
			vars.buffer[j] = buffer[i];
		}
		if (RES_OK != mmc::writeSector(vars.buffer, lastSector)) {
			return false;
		}
		buffer += bytesToWrite;
		length -= bytesToWrite;

		// Loop for any reminding data to be written in next sector
		// 1. If no more sectors left on cluster
		// 	2.1. Locate next cluster
		// 	2.2 Chain it in FAT
		// 	2.3 update lastSector var
		// 2. write data in lastSector

		// More sectors needed?
		while(length>0) {
			// If this was last sector in Cluster we need to allocate new cluster
			if( (((lastSector-vars.cluster2)+1) % vars.sectorsPerCluster) == 0) {
				lastCluster = chainNextCluster(lastCluster);
				if( lastCluster == 0xFFFF) {
					return false;
				}
				lastSector = vars.cluster2 + ((lastCluster-2) * vars.sectorsPerCluster) ;
			} else {
				lastSector++;
			}
			// Write data in lastSector
			bytesToWrite = length;
			// Maybe we need more sectors to complete the write
			if( bytesToWrite > BYTESPERSECTOR) {
				bytesToWrite = BYTESPERSECTOR;
			}
			for (unsigned int i = 0; i < bytesToWrite; ++i) {
				vars.buffer[i] = buffer[i];
			}

			if (RES_OK != mmc::writeSector(vars.buffer, lastSector)) {
				return false;
			}

			// Keep going
			buffer += bytesToWrite;
			length -= bytesToWrite;
		}
		return true;
	}
	
	return false;
}
