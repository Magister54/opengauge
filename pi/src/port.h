
#pragma once

#ifdef __arm__
#include <wiringPi.h>
#else
#include "fakeWiringPi.h"
#endif

#include <inttypes.h>

const int txPin = 14;

void portInit();
void serial_rx_on();
void serial_rx_off();
void serial_tx_off();
uint8_t serialRead();
void serialWrite(uint8_t data);
void serial_on();
void delayMs(uint32_t delay);
