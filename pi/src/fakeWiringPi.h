
#pragma once

#ifndef __arm__

#define HIGH		1
#define LOW			0
#define OUTPUT		1

void digitalWrite(int, int);
int wiringPiSetupGpio();
void pinMode(int, int);
void pinModeAlt(int, int);

#endif
