
#define HIGH	1
#define LOW		0

#define OUTPUT		1
#define INPUT		0

#define K_OUT_Pin			1
#define K_OUT_GPIO_Port		1
#define K_IN_Pin			1
#define K_IN_GPIO_Port		1

#define GPIO_PIN_SET		1
#define GPIO_PIN_RESET		0

void digitalWrite(int port, int pin, int state);
void pinMode(int port, int pin, int mode);
void serial_rx_on();
void serial_rx_off();
void serial_tx_off();
uint8_t serialRead();
void serialWrite(uint8_t data);
void serial_on();
void delay(uint32_t delay);
