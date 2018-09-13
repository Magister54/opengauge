
#ifndef __arm__


void digitalWrite(int a, int b){(void)a;(void)b;}
int wiringPiSetupGpio(){return 1;}
void pinMode(int a, int b){(void)a;(void)b;}
void pinModeAlt(int a, int b){(void)a;(void)b;}

#endif
