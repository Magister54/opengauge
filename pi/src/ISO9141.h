
#pragma once

#include <cinttypes>
#include <cstdlib>

class ISO9141
{
public:

	/* ISO 9141 init */
	static int init();

	// inspired by SternOBDII\code\iso.c
	static int write(uint8_t *data, uint8_t len);

	// read n uint8_t of data (+ header + cmd and crc)
	// return the result only in data
	static int read(uint8_t *data, uint8_t len);

private:

	static uint8_t readByte();

	static void writeByte(uint8_t b);

	// inspired by SternOBDII\code\checksum.c
	static uint8_t computeChecksum(uint8_t *data, uint8_t len);
};


