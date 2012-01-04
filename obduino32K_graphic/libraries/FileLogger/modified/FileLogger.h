//
// Title        : FileLogger library for Arduino
// Author       : Eduardo García (egarcia@stream18.com)
// Date         : April 2009
// Id			: $Id: FileLogger.h 20 2009-04-23 00:03:12Z stream18 $
//
// CREDITS:
//
// DESCRIPTION:
// This Arduino library provides minimal functionallity to log data into a file in the
// root folder of a microSD memory card attached to Arduino.
//
// DISCLAIMER:
// The author is in no way responsible for any problems or damage caused by
// using this code. Use at your own risk.
//
// LICENSE:
// This code is distributed under the GNU Public License
// which can be found at http://www.gnu.org/licenses/gpl.txt
//

#include "mmc.h"
#include "nanofat.h"
#include <WProgram.h>

#ifndef FileLogger_h
#define FileLogger_h

namespace FileLogger {
  
	// append - appends a data buffer to the file
	int append(const char* filename, byte* buffer, unsigned long length);
};

#endif

