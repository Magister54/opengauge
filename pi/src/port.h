
#pragma once

#include <wiringPi.h>
#include <inttypes.h>

const int txPin = 14;

void portInit();
void digitalWrite(int port, int pin, int state);
void pinMode(int port, int pin, int mode);
void serial_rx_on();
void serial_rx_off();
void serial_tx_off();
uint8_t serialRead();
void serialWrite(uint8_t data);
void serial_on();
void delayMs(uint32_t delay);
