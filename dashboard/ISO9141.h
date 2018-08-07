
#pragma once

#include <cinttypes>
#include <cstdlib>

// inspired by SternOBDII\code\iso.c
uint8_t iso_write_data(uint8_t *data, uint8_t len);

// read n uint8_t of data (+ header + cmd and crc)
// return the result only in data
uint8_t iso_read_data(uint8_t *data, uint8_t len);

/* ISO 9141 init */
uint8_t iso_init();
