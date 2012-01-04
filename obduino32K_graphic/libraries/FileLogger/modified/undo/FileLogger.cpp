//
// Title        : FileLogger library for Arduino
// Author       : Eduardo García (egarcia@stream18.com)
// Date         : April 2009
// Id			: $Id: FileLogger.cpp 20 2009-04-23 00:03:12Z stream18 $
//
// See header for credits

#include "FileLogger.h"

static byte sdBuffer[512]; // Block size for  512 bytes
static bool nanofat_initialized = false;


bool initializeNanoFAT() {
  if(!nanofat_initialized) {
	if (nanofat::initialize(sdBuffer)) {
		nanofat_initialized = true;
	} else {
		return false;
	}
  }
  return true;
}

//
// This library will just append a data buffer to a file
//
int FileLogger::append(const char* filename, byte buffer[], unsigned long length) {
  if (initializeNanoFAT()) {
	if( nanofat::append(filename, buffer, length)) {
	} else return 2;
  } else return 1;
  return 0;
}
