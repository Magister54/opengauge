
#include <QThread>

const int serialTimeout = 500; // ms

void digitalWrite(int port, int pin, int state)
{
	
}

void pinMode(int port, int pin, int mode)
{
	
}

void serial_rx_on()
{
	
}

void serial_rx_off()
{
	
}

void serial_tx_off()
{
	
}

uint8_t serialRead()
{
	return 0;
}

void serialWrite(uint8_t data)
{
	
}

void serial_on()
{
	
}

void delay(uint32_t delay)
{
	QThread::msleep(delay);
}
