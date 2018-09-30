/**
 * Blabla c'est pas moi qui l'ai fait
 *
 */

#include "fixmycar.h"
#include <stdio.h>
#include <string.h>
#include <inttypes.h>

#include "stm32l1xx.h"

#define HIGH	1
#define LOW		0

#define OUTPUT		1
#define INPUT		0

#define K_OUT_Pin			GPIO_PIN_2
#define K_OUT_GPIO_Port		GPIOA
#define K_IN_Pin			GPIO_PIN_3
#define K_IN_GPIO_Port		GPIOA

extern UART_HandleTypeDef huart2;

const int serialTimeout = 500; // ms

void digitalWrite(GPIO_TypeDef* port, uint16_t pin, GPIO_PinState state)
{
	HAL_GPIO_WritePin(port, pin, state);
}

void pinMode(GPIO_TypeDef* port, uint16_t pin, uint32_t mode)
{
	GPIO_InitTypeDef GPIO_InitStruct;
	GPIO_InitStruct.Pin = pin;
	GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
	GPIO_InitStruct.Pull = GPIO_NOPULL;
	GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
	HAL_GPIO_Init(port, &GPIO_InitStruct);
}

void serial_rx_on()
{
	uint8_t dummy;
	HAL_UART_MspInit(&huart2);
	HAL_UART_Receive(&huart2, &dummy, 1, 1); // Flush receive buffer
}

void serial_rx_off()
{
	pinMode(K_IN_GPIO_Port, K_IN_Pin, GPIO_MODE_INPUT);
}

void serial_tx_off()
{
	 // delay for flush?
	pinMode(K_OUT_GPIO_Port, K_OUT_Pin, GPIO_MODE_OUTPUT_PP);
}

uint8_t serialRead()
{
	uint8_t byte;
	if(HAL_UART_Receive(&huart2, &byte, 1, serialTimeout) != HAL_OK)
		return 0;
	else
		return byte;
}

void serialWrite(uint8_t data)
{
	HAL_UART_Transmit(&huart2, &data, 1, serialTimeout);
}

void serial_on()
{
	serial_rx_on();
}

void delay(uint32_t delay)
{
	HAL_Delay(delay);
}

uint32_t millis()
{
	return HAL_GetTick();
}

void long_to_dec_str(long value, char *decs, uint8_t prec);

/* PID stuff */

unsigned long pid01to20_support;  // this one always initialized at setup()
unsigned long pid21to40_support = 0;
unsigned long pid41to60_support = 0;
#define PID_SUPPORT00 0x00
#define MIL_CODE      0x01
#define FREEZE_DTC    0x02
#define FUEL_STATUS   0x03
#define LOAD_VALUE    0x04
#define COOLANT_TEMP  0x05
#define STFT_BANK1     0x06
#define LTFT_BANK1     0x07
#define STFT_BANK2     0x08
#define LTFT_BANK2     0x09
#define FUEL_PRESSURE 0x0A
#define MAN_PRESSURE  0x0B
#define ENGINE_RPM    0x0C
#define VEHICLE_SPEED 0x0D
#define TIMING_ADV    0x0E
#define INT_AIR_TEMP  0x0F
#define MAF_AIR_FLOW  0x10
#define THROTTLE_POS  0x11
#define SEC_AIR_STAT  0x12
#define OXY_SENSORS1  0x13
#define B1S1_O2_V     0x14
#define B1S2_O2_V     0x15
#define B1S3_O2_V     0x16
#define B1S4_O2_V     0x17
#define B2S1_O2_V     0x18
#define B2S2_O2_V     0x19
#define B2S3_O2_V     0x1A
#define B2S4_O2_V     0x1B
#define OBD_STD       0x1C
#define OXY_SENSORS2  0x1D
#define AUX_INPUT     0x1E
#define RUNTIME_START 0x1F
#define PID_SUPPORT20 0x20
#define DIST_MIL_ON   0x21
#define FUEL_RAIL_P   0x22
#define FUEL_RAIL_DIESEL 0x23
#define O2S1_WR_V     0x24
#define O2S2_WR_V     0x25
#define O2S3_WR_V     0x26
#define O2S4_WR_V     0x27
#define O2S5_WR_V     0x28
#define O2S6_WR_V     0x29
#define O2S7_WR_V     0x2A
#define O2S8_WR_V     0x2B
#define EGR           0x2C
#define EGR_ERROR     0x2D
#define EVAP_PURGE    0x2E
#define FUEL_LEVEL    0x2F
#define WARM_UPS      0x30
#define DIST_MIL_CLR  0x31
#define EVAP_PRESSURE 0x32
#define BARO_PRESSURE 0x33
#define O2S1_WR_C     0x34
#define O2S2_WR_C     0x35
#define O2S3_WR_C     0x36
#define O2S4_WR_C     0x37
#define O2S5_WR_C     0x38
#define O2S6_WR_C     0x39
#define O2S7_WR_C     0x3A
#define O2S8_WR_C     0x3B
#define CAT_TEMP_B1S1 0x3C
#define CAT_TEMP_B2S1 0x3D
#define CAT_TEMP_B1S2 0x3E
#define CAT_TEMP_B2S2 0x3F
#define PID_SUPPORT40 0x40
#define MONITOR_STAT  0x41
#define CTRL_MOD_V    0x42
#define ABS_LOAD_VAL  0x43
#define CMD_EQUIV_R   0x44
#define REL_THR_POS   0x45
#define AMBIENT_TEMP  0x46
#define ABS_THR_POS_B 0x47
#define ABS_THR_POS_C 0x48
#define ACCEL_PEDAL_D 0x49
#define ACCEL_PEDAL_E 0x4A
#define ACCEL_PEDAL_F 0x4B
#define CMD_THR_ACTU  0x4C
#define TIME_MIL_ON   0x4D
#define TIME_MIL_CLR  0x4E

#define LAST_PID      0x4E  // same as the last one defined above

/* our internal fake PIDs */
#define NO_DISPLAY    0xF0
#define FUEL_CONS     0xF1    // instant cons
#define TANK_CONS     0xF2    // average cons of tank
#define TANK_FUEL     0xF3    // fuel used in tank
#define TANK_DIST     0xF4    // distance for tank
#define REMAIN_DIST   0xF5    // remaining distance of tank
#define TRIP_CONS     0xF6    // average cons of trip
#define TRIP_FUEL     0xF7    // fuel used in trip
#define TRIP_DIST     0xF8    // distance of trip
#define BATT_VOLTAGE  0xF9
#define OUTING_CONS  0xFA
#define OUTING_FUEL  0xFB
#define OUTING_DIST  0xFC
//#define ECO_VISUAL    0XFC    // Visually dispay relative economy with *'s (too big, not tested)
#define CAN_STATUS    0xFD
#define PID_SEC       0xFE

// returned length of the PID response.
// constants so put in flash
uint8_t pid_reslen[] =
{
		// pid 0x00 to 0x1F
		4, 4, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 2, 1, 1, 1, 2, 2, 2, 2,
		2, 2, 2, 2, 1, 1, 1, 4,

		// pid 0x20 to 0x3F
		4, 2, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 1, 1, 1, 1, 1, 2, 2, 1, 4, 4, 4, 4,
		4, 4, 4, 4, 2, 2, 2, 2,

		// pid 0x40 to 0x4E
		4, 8, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2 };

// for the 4 display corners
char blkstr[] = "        "; // 8 spaces, used to clear part of screen
char pctd[] = "- %d + "; // used in a couple of place
char pctdpctpct[] = "- %d%% + "; // used in a couple of place
char pctspcts[] = "%s %s"; // used in a couple of place
char pctldpcts[] = "%ld %s"; // used in a couple of place
char select_no[] = "(NO) YES"; // for config menu
char select_yes[] = "NO (YES)"; // for config menu

// to differenciate trips
#define TANK			0
#define TRIP			1
#define OUTING_TRIP		2  //Tracks your current outing
#define NBTRIP			3

// parameters
// each trip contains fuel used and distance done
typedef struct
{
	unsigned long dist;		// in cm
	unsigned long fuel;		// in µL
	unsigned long waste;	// in µL
} trip_t;

typedef struct
{
	uint8_t per_hour_speed;		// speed from which we toggle to fuel/hour (km/h)
	uint8_t fuel_adjust;		// because of variation from car to car, temperature, etc
	uint8_t speed_adjust;		// because of variation from car to car, tire size, etc
	uint8_t eng_dis;			// engine displacement in dL
	unsigned int tank_size;		// tank size in dL or dgal depending of unit
	trip_t trip[NBTRIP];        // trip0=tank, trip1=a trip
} params_t;

// parameters default values
params_t params =
{ 20, 100, 100, 16, 450,
{
{ 0, 0 },
{ 0, 0 } } };

#define STRLEN  40

/*
 * for ISO9141-2 Protocol
 */
#define K_IN    0
#define K_OUT   1

// some globals, for trip calculation and others
unsigned long old_time;
uint8_t has_rpm = 0;
long vss = 0;  // speed
long maf = 0;  // MAF

unsigned long getpid_time;
uint8_t nbpid_per_second = 0;

// flag used to save distance/average consumption in eeprom only if required
uint8_t engine_started = 0;
uint8_t param_saved = 0;

int iso_read_byte()
{
	int b;
	uint8_t t = 0;
	while (t != 125 && (b = serialRead()) == -1)
	{
		delay(1);
		t++;
	}
	if (t >= 125)
	{
		b = 0;
	}
	return b;
}

void iso_write_byte(uint8_t b)
{
	serial_rx_off();
	serialWrite(b);
	delay(10);		// ISO requires 5-20 ms delay between bytes.
	serial_rx_on();
}

// inspired by SternOBDII\code\checksum.c
uint8_t iso_checksum(uint8_t *data, uint8_t len)
{
	uint8_t i;
	uint8_t crc;

	crc = 0;
	for (i = 0; i < len; i++)
		crc = crc + data[i];

	return crc;
}

// inspired by SternOBDII\code\iso.c
uint8_t iso_write_data(uint8_t *data, uint8_t len)
{
	uint8_t i, n;
	uint8_t buf[20];

	// ISO header
	buf[0] = 0x68;
	buf[1] = 0x6A;		// 0x68 0x6A is an OBD-II request
	buf[2] = 0xF1;		// our requester's address (off-board tool)
	// append message
	for (i = 0; i < len; i++)
		buf[i + 3] = data[i];

	// calculate checksum
	i += 3;
	buf[i] = iso_checksum(buf, i);

	// send char one by one
	n = i + 1;
	for (i = 0; i < n; i++)
	{
		iso_write_byte(buf[i]);
	}

	return 0;
}

// read n uint8_t of data (+ header + cmd and crc)
// return the result only in data
uint8_t iso_read_data(uint8_t *data, uint8_t len)
{
	uint8_t i;
	uint8_t buf[20];

	// header 3 bytes: [80+datalen] [destination=f1] [source=01]
	// data 1+1+len bytes: [40+cmd0] [cmd1] [result0]
	// checksum 1 bytes: [sum(header)+sum(data)]

	for (i = 0; i < 3 + 1 + 1 + 1 + len; i++)
		buf[i] = iso_read_byte();

	// test, skip header comparison
	// ignore failure for the moment (0x7f)
	// ignore crc for the moment

	// we send only one command, so result start at buf[4] Actually, result starts at buf[5], buf[4] is pid requested...
	memcpy(data, buf + 5, len);

	delay(55);    //guarantee 55 ms pause between requests

	return len;
}

/* ISO 9141 init */
uint8_t iso_init()
{
	uint8_t b;
	uint8_t kw1, kw2;
	serial_tx_off(); //disable UART so we can "bit-Bang" the slow init.
	serial_rx_off();
	delay(3000); //k line should be free of traffic for at least two secconds.
	// drive K line high for 300ms
	digitalWrite(K_OUT_GPIO_Port, K_OUT_Pin, GPIO_PIN_SET);
	delay(300);

	// send 0x33 at 5 bauds
	// start bit
	digitalWrite(K_OUT_GPIO_Port, K_OUT_Pin, GPIO_PIN_RESET);
	delay(200);
	// data
	b = 0x33;
	for (uint8_t mask = 0x01; mask; mask <<= 1)
	{
		if (b & mask) // choose bit
			digitalWrite(K_OUT_GPIO_Port, K_OUT_Pin, GPIO_PIN_SET); // send 1
		else
			digitalWrite(K_OUT_GPIO_Port, K_OUT_Pin, GPIO_PIN_RESET); // send 0
		delay(200);
	}
	// stop bit + 60 ms delay
	digitalWrite(K_OUT_GPIO_Port, K_OUT_Pin, GPIO_PIN_SET);
	delay(260);

	// switch now to 10400 bauds
	serial_on();

	// wait for 0x55 from the ECU (up to 300ms)
	//since our time out for reading is 125ms, we will try it three times
	for (int i = 0; i < 3; i++)
	{
		b = iso_read_byte();
		if (b != 0)
			break;
	}

	if (b != 0x55)
		return -1;

	// wait for kw1 and kw2
	kw1 = iso_read_byte();

	kw2 = iso_read_byte();
//  delay(25);

	// sent ~kw2 (invert of last keyword)
	iso_write_byte(~kw2);

	// ECU answer by 0xCC (~0x33)
	b = iso_read_byte();
	if (b != 0xCC)
		return -1;

	// init OK!
	return 0;
}

// return 0 if pid is not supported, 1 if it is.
// mode is 0 for get_pid() and 1 for menu config to allow pid > 0xF0
uint8_t is_pid_supported(uint8_t pid, uint8_t mode)
{
	// note that pid PID_SUPPORT00 (0x00) is always supported
	if ((pid > 0x00 && pid <= 0x20
			&& (1L << (0x20 - pid) & pid01to20_support) == 0)
			|| (pid > 0x20 && pid <= 0x40
					&& (1L << (0x40 - pid) & pid21to40_support) == 0)
			|| (pid > 0x40 && pid <= 0x60
					&& (1L << (0x60 - pid) & pid41to60_support) == 0)
			|| (pid > LAST_PID && (pid < 0xF0 || mode == 0)))
	{
		return 0;
	}

	return 1;
}

// get value of a PID, return as a long value
// and also formatted for string output in the return buffer
long get_pid(uint8_t pid, char *retbuf)
{
	uint8_t cmd[2];    // to send the command
	uint8_t i;
	uint8_t buf[10];   // to receive the result
	long ret;       // will be the return value
	uint8_t reslen;
	char decs[16];
	unsigned long time_now, delta_time;
	static uint8_t nbpid = 0;

	nbpid++;
	// time elapsed
	time_now = millis();
	delta_time = time_now - getpid_time;
	if (delta_time > 1000)
	{
		nbpid_per_second = nbpid;
		nbpid = 0;
		getpid_time = time_now;
	}

	// check if PID is supported (should not happen except for some 0xFn)
	if (!is_pid_supported(pid, 0))
	{
		// nope
		sprintf(retbuf, "%02X N/A", pid);
		return -1;
	}

	// receive length depends on pid
	reslen = pid_reslen[pid];

	cmd[0] = 0x01;    // ISO cmd 1, get PID
	cmd[1] = pid;
	// send command, length 2
	iso_write_data(cmd, 2);
	// read requested length, n bytes received in buf
	iso_read_data(buf, reslen);

	// a lot of formulas are the same so calculate a default return value here
	// even if it's scrapped after, we still saved 40 bytes!
	ret = buf[0] * 256U + buf[1];

	// formula and unit for each PID
	switch (pid)
	{
	case ENGINE_RPM:
		ret = ret / 4U;
		sprintf(retbuf, "%ld RPM", ret);
		break;
	case MAF_AIR_FLOW:
		// ret is not divided by 100 for return value!!
		long_to_dec_str(ret, decs, 2);
		sprintf(retbuf, "%s g/s", decs);
		break;
	case VEHICLE_SPEED:
		ret = (buf[0] * params.speed_adjust) / 100U;
		sprintf(retbuf, pctldpcts, ret, "\003\004");
		// do not touch vss, it is used by fuel calculation after, so reset it
		ret = (buf[0] * params.speed_adjust) / 100U;
		break;
	case FUEL_STATUS:
		if (buf[0] == 0x01)
			sprintf(retbuf, "OPENLOWT"); // open due to insufficient engine temperature
		else if (buf[0] == 0x02)
			sprintf(retbuf, "CLSEOXYS"); // Closed loop, using oxygen sensor feedback to determine fuel mix. should be almost always this
		else if (buf[0] == 0x04)
			sprintf(retbuf, "OPENLOAD"); // Open loop due to engine load, can trigger DFCO
		else if (buf[0] == 0x08)
			sprintf(retbuf, "OPENFAIL");  // Open loop due to system failure
		else if (buf[0] == 0x10)
			sprintf(retbuf, "CLSEBADF"); // Closed loop, using at least one oxygen sensor but there is a fault in the feedback system
		else
			sprintf(retbuf, "%04lX", ret);
		break;
	case LOAD_VALUE:
	case THROTTLE_POS:
	case REL_THR_POS:
	case EGR:
	case EGR_ERROR:
	case FUEL_LEVEL:
	case ABS_THR_POS_B:
	case ABS_THR_POS_C:
	case ACCEL_PEDAL_D:
	case ACCEL_PEDAL_E:
	case ACCEL_PEDAL_F:
	case CMD_THR_ACTU:
		ret = (buf[0] * 100U) / 255U;
		sprintf(retbuf, "%ld %%", ret);
		break;
	case B1S1_O2_V:
	case B1S2_O2_V:
	case B1S3_O2_V:
	case B1S4_O2_V:
	case B2S1_O2_V:
	case B2S2_O2_V:
	case B2S3_O2_V:
	case B2S4_O2_V:
		ret = buf[0] * 5U;  // not divided by 1000 for return!!
		if (buf[1] == 0xFF)  // not used in trim calculation
			sprintf(retbuf, "%ld mV", ret);
		else
			sprintf(retbuf, "%ldmV/%d%%", ret, ((buf[1] - 128) * 100) / 128);
		break;
	case O2S1_WR_V:
	case O2S2_WR_V:
	case O2S3_WR_V:
	case O2S4_WR_V:
	case O2S5_WR_V:
	case O2S6_WR_V:
	case O2S7_WR_V:
	case O2S8_WR_V:
	case O2S1_WR_C:
	case O2S2_WR_C:
	case O2S3_WR_C:
	case O2S4_WR_C:
	case O2S5_WR_C:
	case O2S6_WR_C:
	case O2S7_WR_C:
	case O2S8_WR_C:
	case CMD_EQUIV_R:
		ret = (ret * 100) / 32768; // not divided by 1000 for return!!
		long_to_dec_str(ret, decs, 2);
		sprintf(retbuf, "l:%s", decs);
		break;
	case DIST_MIL_ON:
	case DIST_MIL_CLR:
		sprintf(retbuf, pctldpcts, ret, "\003");
		break;
	case TIME_MIL_ON:
	case TIME_MIL_CLR:
		sprintf(retbuf, "%ld min", ret);
		break;
	case COOLANT_TEMP:
	case INT_AIR_TEMP:
	case AMBIENT_TEMP:
	case CAT_TEMP_B1S1:
	case CAT_TEMP_B2S1:
	case CAT_TEMP_B1S2:
	case CAT_TEMP_B2S2:
		if (pid >= CAT_TEMP_B1S1 && pid <= CAT_TEMP_B2S2)
			ret = ret / 10U - 40;
		else
			ret = buf[0] - 40;
		sprintf(retbuf, "%ld\005%c", ret, 'C');
		break;
	case STFT_BANK1:
	case LTFT_BANK1:
	case STFT_BANK2:
	case LTFT_BANK2:
		ret = (buf[0] - 128) * 7812;  // not divided by 10000 for return value
		long_to_dec_str(ret / 100, decs, 2);
		sprintf(retbuf, "%s %%", decs);
		break;
	case FUEL_PRESSURE:
	case MAN_PRESSURE:
	case BARO_PRESSURE:
		ret = buf[0];
		if (pid == FUEL_PRESSURE)
			ret *= 3U;
		sprintf(retbuf, "%ld kPa", ret);
		break;
	case TIMING_ADV:
		ret = (buf[0] / 2) - 64;
		sprintf(retbuf, "%ld\005", ret);
		break;
	case CTRL_MOD_V:
		long_to_dec_str(ret / 10, decs, 2);
		sprintf(retbuf, "%s V", decs);
		break;
	case OBD_STD:
		ret = buf[0];
		if (buf[0] == 0x01)
			sprintf(retbuf, "OBD2CARB");
		else if (buf[0] == 0x02)
			sprintf(retbuf, "OBD2EPA");
		else if (buf[0] == 0x03)
			sprintf(retbuf, "OBD1&2");
		else if (buf[0] == 0x04)
			sprintf(retbuf, "OBD1");
		else if (buf[0] == 0x05)
			sprintf(retbuf, "NOT OBD");
		else if (buf[0] == 0x06)
			sprintf(retbuf, "EOBD");
		else if (buf[0] == 0x07)
			sprintf(retbuf, "EOBD&2");
		else if (buf[0] == 0x08)
			sprintf(retbuf, "EOBD&1");
		else if (buf[0] == 0x09)
			sprintf(retbuf, "EOBD&1&2");
		else if (buf[0] == 0x0a)
			sprintf(retbuf, "JOBD");
		else if (buf[0] == 0x0b)
			sprintf(retbuf, "JOBD&2");
		else if (buf[0] == 0x0c)
			sprintf(retbuf, "JOBD&1");
		else if (buf[0] == 0x0d)
			sprintf(retbuf, "JOBD&1&2");
		else
			sprintf(retbuf, "OBD:%02X", buf[0]);
		break;
		// for the moment, everything else, display the raw answer
	default:
		// transform buffer to an hex value
		ret = 0;
		for (i = 0; i < reslen; i++)
		{
			ret *= 256L;
			ret += buf[i];
		}
		sprintf(retbuf, "%08lX", ret);
		break;
	}

	return ret;
}

// ex: get a long as 687 with prec 2 and output the string "6.87"
// precision is 1 or 2
void long_to_dec_str(long value, char *decs, uint8_t prec)
{
	uint8_t pos;

	// sprintf does not allow * for the width ?!?
	if (prec == 1)
		sprintf(decs, "%02ld", value);
	else if (prec == 2)
		sprintf(decs, "%03ld", value);

	pos = strlen(decs) + 1;  // move the \0 too
	// a simple loop takes less space than memmove()
	for (uint8_t i = 0; i <= prec; i++)
	{
		decs[pos] = decs[pos - 1];  // move digit
		pos--;
	}

	// then insert decimal separator
	decs[pos] = '.';
}

// instant fuel consumption
void get_icons(char *retbuf)
{
	long toggle_speed;
	long cons;
	char decs[16];

	toggle_speed = params.per_hour_speed;

	// divide MAF by 100 because our function return MAF*100
	// but multiply by 100 for double digits precision
	// divide MAF by 14.7 air/fuel ratio to have g of fuel/s
	// divide by 730 (g/L at 15°C) according to Canadian Gov to have L/s
	// multiply by 3600 to get litre per hour
	// formula: (3600 * MAF) / (14.7 * 730 * VSS)
	// = maf*0.3355/vss L/km
	// mul by 100 to have L/100km

	// if maf is 0 it will just output 0
	if (vss < toggle_speed)
		cons = (maf * 3355) / 10000; // L/h, do not use float so mul first then divide
	else
		cons = (maf * 3355) / (vss * 100); // L/100kmh, 100 comes from the /10000*100

	long_to_dec_str(cons, decs, 2);
	sprintf(retbuf, pctspcts, decs, (vss < toggle_speed) ? "L\004" : "\001\002");
}

// trip 0 is tank
// trip 1 is trip
void get_cons(char *retbuf, uint8_t ctrip)
{
	unsigned long cfuel;
	unsigned long cdist;
	long trip_cons;
	char decs[16];

	cfuel = params.trip[ctrip].fuel;
	cdist = params.trip[ctrip].dist;

	// the car has not moved yet or no fuel used
	if (cdist < 1000 || cfuel == 0)
	{
		// will display 0.00L/100 or 999.9mpg
		trip_cons = 0;
	}
	else  // the car has moved and fuel used
	{
		// from µL/cm to L/100 so div by 1000000 for L and mul by 10000000 for 100km
		// multiply by 100 to have 2 digits precision
		// we can not mul fuel by 1000 else it can go higher than ULONG_MAX
		// so divide distance by 1000 instead (resolution of 10 metres)

		trip_cons = cfuel / (cdist / 1000); // div by 0 avoided by previous test

		if (trip_cons > 9999)    // SI
			trip_cons = 9999;     // display 99.99 L/100 maximum
	}

	long_to_dec_str(trip_cons, decs, 2);

	sprintf(retbuf, pctspcts, decs, "\001\002");
}

// trip 0 is tank
// trip 1 is trip
// trip 2 is outing trip
void get_fuel(char *retbuf, uint8_t ctrip)
{
	unsigned long cfuel;
	char decs[16];

	// convert from µL to cL
	cfuel = params.trip[ctrip].fuel / 10000;

	long_to_dec_str(cfuel, decs, 2);
	sprintf(retbuf, pctspcts, decs, "L");
}

// trip 0 is tank
// trip 1 is trip
void get_dist(char *retbuf, uint8_t ctrip)
{
	unsigned long cdist;
	char decs[16];

	// convert from cm to hundreds of meter
	cdist = params.trip[ctrip].dist / 10000;

	long_to_dec_str(cdist, decs, 1);
	sprintf(retbuf, pctspcts, decs, "\003");
}

// distance you can do with the remaining fuel in your tank
void get_remain_dist(char *retbuf)
{
	long tank_tmp;
	long remain_dist;
	long remain_fuel;
	long tank_cons;

	tank_tmp = params.tank_size;

	// convert from µL to dL
	remain_fuel = tank_tmp - params.trip[TANK].fuel / 100000;

	// calculate remaining distance using tank cons and remaining fuel
	if (params.trip[TANK].dist < 1000)
		remain_dist = 9999;
	else
	{
		tank_cons = params.trip[TANK].fuel / (params.trip[TANK].dist / 1000);
		remain_dist = remain_fuel * 1000 / tank_cons;
	}

	sprintf(retbuf, pctldpcts, remain_dist, "\003");
}

/*
 * accumulate data for trip, called every loop()
 */
void accu_trip(void)
{
	static uint8_t min_throttle_pos = 255; // idle throttle position, start high
	uint8_t throttle_pos;   // current throttle position
	uint8_t open_load;      // to detect open loop
	char str[STRLEN];
	unsigned long delta_dist, delta_fuel;
	unsigned long time_now, delta_time;

	// time elapsed
	time_now = millis();
	delta_time = time_now - old_time;
	old_time = time_now;

	// distance in cm
	// 3km/h = 83cm/s and we can sample n times per second or so with CAN
	// so having the value in cm is not too large, not too weak.
	// ulong so max value is 4'294'967'295 cm or 42'949 km or 26'671 miles
	vss = get_pid(VEHICLE_SPEED, str);
	if (vss > 0)
	{
		delta_dist = (vss * delta_time) / 36;
		// accumulate for all trips
		for (uint8_t i = 0; i < NBTRIP; i++)
			params.trip[i].dist += delta_dist;
	}

	// if engine is stopped, we can get out now
	if (!has_rpm)
	{
		maf = 0;
		return;
	}

	// accumulate fuel only if not in DFCO
	// if throttle position is close to idle and we are in open loop -> DFCO

	// detect idle pos
	throttle_pos = get_pid(THROTTLE_POS, str);
	if (throttle_pos < min_throttle_pos && throttle_pos != 0) //And make sure its not '0' returned by no response in read uint8_t function
		min_throttle_pos = throttle_pos;

	// get fuel status
	open_load = (get_pid(FUEL_STATUS, str) & 0x0400) ? 1 : 0;

	if (throttle_pos < (min_throttle_pos + 4) && open_load)
		maf = 0;  // decellerate fuel cut-off, fake the MAF as 0 :)
	else
	{
		// check if MAF is supported
		if (is_pid_supported(MAF_AIR_FLOW, 0))
		{
			// yes, just request it
			maf = get_pid(MAF_AIR_FLOW, str);
		}
		else
		{
			/*
			 I just hope if you don't have a MAF, you have a MAP!!

			 No MAF (Uses MAP and Absolute Temp to approximate MAF):
			 IMAP = RPM * MAP / IAT
			 MAF = (IMAP/120)*(VE/100)*(ED)*(MM)/(R)
			 MAP - Manifold Absolute Pressure in kPa
			 IAT - Intake Air Temperature in Kelvin
			 R - Specific Gas Constant (8.314472 J/(mol.K)
			 MM - Average molecular mass of air (28.9644 g/mol)
			 VE - volumetric efficiency measured in percent, let's say 80%
			 ED - Engine Displacement in liters
			 This method requires tweaking of the VE for accuracy.
			 */
			long imap, rpm, map, iat;

			rpm = get_pid(ENGINE_RPM, str);
			map = get_pid(MAN_PRESSURE, str);
			iat = get_pid(INT_AIR_TEMP, str);
			imap = (rpm * map) / (iat + 273);

			// does not divide by 100 because we use (MAF*100) in formula
			// but divide by 10 because engine displacement is in dL
			// 28.9644*100/(80*120*8.314472*10)= about 0.0036 or 36/10000
			// ex: VSS=80km/h, MAP=64kPa, RPM=1800, IAT=21C
			//     engine=2.2L, efficiency=80%
			// maf = ( (1800*64)/(21+273) * 80 * 22 * 29 ) / 10000
			// maf = 1995 or 19.95 g/s which is about right at 80km/h
			maf = (imap * params.eng_dis * 36) / 100; //only need to divide by 100 because no longer multiplying by V.E.
		}
		// add MAF result to trip
		// we want fuel used in µL
		// maf gives grams of air/s
		// divide by 100 because our MAF return is not divided!
		// divide by 14.7 (a/f ratio) to have grams of fuel/s
		// divide by 730 to have L/s
		// mul by 1000000 to have µL/s
		// divide by 1000 because delta_time is in ms

		// at idle MAF output is about 2.25 g of air /s on my car
		// so about 0.15g of fuel or 0.210 mL
		// or about 210 µL of fuel/s so µL is not too weak nor too large
		// as we sample about 4 times per second at 9600 bauds
		// ulong so max value is 4'294'967'295 µL or 4'294 L (about 1136 gallon)
		// also, adjust maf with fuel param, will be used to display instant cons
		maf = (maf * params.fuel_adjust) / 100;
		delta_fuel = (maf * delta_time) / 1073;
		for (uint8_t i = 0; i < NBTRIP; i++)
		{
			params.trip[i].fuel += delta_fuel;
			//code to accumlate fuel wasted while idling
			if (vss == 0)
			{    //car not moving
				params.trip[i].waste += delta_fuel;
			}
		}
	}
}

void display(uint8_t pid)
{
	char str[STRLEN];

	/* check if it's a real PID or our internal one */
	if (pid == NO_DISPLAY)
		return;
	else if (pid == FUEL_CONS)
		get_icons(str);
	else if (pid == TANK_CONS)
		get_cons(str, TANK);
	else if (pid == TANK_FUEL)
		get_fuel(str, TANK);
	else if (pid == TANK_DIST)
		get_dist(str, TANK);
	else if (pid == REMAIN_DIST)
		get_remain_dist(str);
	else if (pid == TRIP_CONS)
		get_cons(str, TRIP);
	else if (pid == TRIP_FUEL)
		get_fuel(str, TRIP);
	else if (pid == TRIP_DIST)
		get_dist(str, TRIP);
	else if (pid == OUTING_CONS)
		get_cons(str, OUTING_TRIP);
	else if (pid == OUTING_FUEL)
		get_fuel(str, OUTING_TRIP);
	else if (pid == OUTING_DIST)
		get_dist(str, OUTING_TRIP);
	else if (pid == PID_SEC)
		sprintf(str, "%d pid/s", nbpid_per_second);
	else
		(void) get_pid(pid, str);

	printf("%s\n", str);
}

void check_supported_pids(void)
{
	char str[STRLEN];

	pid01to20_support = get_pid(PID_SUPPORT00, str);

	if (is_pid_supported(PID_SUPPORT20, 0))
		pid21to40_support = get_pid(PID_SUPPORT20, str);

	if (is_pid_supported(PID_SUPPORT40, 0))
		pid41to60_support = get_pid(PID_SUPPORT40, str);
}

// might be incomplete
void check_mil_code(void)
{
	unsigned long n;
	char str[STRLEN];
	uint8_t nb;
	uint8_t cmd[2];
	uint8_t buf[6];
	uint8_t i, j, k;

	n = get_pid(MIL_CODE, str);

	/* A request for this PID returns 4 bytes of data. The first uint8_t contains
	 two pieces of information. Bit A7 (the seventh bit of uint8_t A, the first byte)
	 indicates whether or not the MIL (check engine light) is illuminated. Bits A0
	 through A6 represent the number of diagnostic trouble codes currently flagged
	 in the ECU. The second, third, and fourth bytes give information about the
	 availability and completeness of certain on-board tests. Note that test
	 availability signified by set (1) bit; completeness signified by reset (0)
	 bit. (from Wikipedia)
	 */
	if (1L << 31 & n)  // test bit A7
	{
		// we have MIL on
		nb = (n >> 24) & 0x7F;
		printf("CHECK ENGINE ON\n");
		printf("%d CODE(S) IN ECU\n", nb);
		delay(2000);

		// we display only the first 6 codes
		// if you have more than 6 in your ECU
		// your car is obviously wrong :-/

		// retrieve code
		cmd[0] = 0x03;
		iso_write_data(cmd, 1);

		for (i = 0; i < nb / 3; i++)  // each received packet contain 3 codes
		for (i = 0; i < (nb + 2) / 3; i++)  // each received packet contain 3 codes
		{
			iso_read_data(buf, 6);

			k = 0;  // to build the string
			for (j = 0; j < 3; j++)  // the 3 codes
			{
				switch (buf[j * 2] & 0xC0)
				{
				case 0x00:
					str[k] = 'P';  // powertrain
					break;
				case 0x40:
					str[k] = 'C';  // chassis
					break;
				case 0x80:
					str[k] = 'B';  // body
					break;
				case 0xC0:
					str[k] = 'U';  // network
					break;
				}
				k++;
				str[k++] = '0' + ((buf[j * 2] & 0x30) >> 4); // first digit is 0-3 only
				str[k++] = '0' + ((buf[j * 2] & 0x0F));
				str[k++] = '0' + ((buf[j * 2 + 1] & 0xF0) >> 4);
				str[k++] = '0' + ((buf[j * 2 + 1] & 0x0F));
			}
			str[k] = '\0';  // make ascii
			printf("%s\n", str);
		}
	}
}

/*
 * Initialization
 */

void setup()                    // run once, when the sketch starts
{
	uint8_t r;

	// init pinouts
	serial_rx_off();
	serial_tx_off();

	printf("CarFixer v0.1\n");

	do // init loop
	{
		printf("ISO9141 Init... ");
		r = iso_init();
		if (r == 0)
			printf("Success!\n");
		else
			printf("Failure!\n");

		delay(1000);
	} while (r != 0); // end init loop

	// check supported PIDs
	check_supported_pids();

	// check if we have MIL code
	check_mil_code();

	old_time = millis();  // epoch
	getpid_time = old_time;
}

/*
 * Main loop
 */

void loop()                     // run over and over again
{
	char str[STRLEN];

	// test if engine is started
	has_rpm = (get_pid(ENGINE_RPM, str) > 0) ? 1 : 0;
	if (engine_started == 0 && has_rpm != 0)
	{
		//Reset the current outing trip from last trip
		params.trip[OUTING_TRIP].dist = 0;
		params.trip[OUTING_TRIP].fuel = 0;
		params.trip[OUTING_TRIP].waste = 0;
		engine_started = 1;
		param_saved = 0;
	}

	// if engine was started but RPM is now 0
	// save param only once, by flipping param_saved
	if (has_rpm == 0 && param_saved == 0 && engine_started != 0)
	{
		param_saved = 1;
		engine_started = 0;
		printf("TRIPS SAVED!\n");
		//Lets Display how much fuel for the tank we wasted.
		char decs[16];
		long_to_dec_str((params.trip[TANK].waste / 10000), decs, 2);
		printf("%sL wasted", decs);
		delay(2000);
	}

	// this read and assign vss and maf and accumulate trip data
	accu_trip();

	display(FUEL_CONS);
}

