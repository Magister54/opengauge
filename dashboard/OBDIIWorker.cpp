
#include "OBDIIWorker.h"

#include <QThread>

#include "ISO9141.h"
#include "MILCode.h"
#include "PID.h"
#include "port.h"

/* PID support */
uint32_t pid01to20_support = 0;
uint32_t pid21to40_support = 0;
uint32_t pid41to60_support = 0;

/* PID query result length */
constexpr size_t PIDResLens[] =
{
	[PID_SUPPORT00]		= 4,
	[MIL_CODE]			= 4,
	[FREEZE_DTC]		= 2,
	[FUEL_STATUS]		= 2,
	[LOAD_VALUE]		= 1,
	[COOLANT_TEMP]		= 1,
	[STFT_BANK1]		= 1,
	[LTFT_BANK1]		= 1,
	[STFT_BANK2]		= 1,
	[LTFT_BANK2]		= 1,
	[FUEL_PRESSURE]		= 1,
	[MAN_PRESSURE]		= 1,
	[ENGINE_RPM]		= 2,
	[VEHICLE_SPEED]		= 1,
	[TIMING_ADV]		= 1,
	[INT_AIR_TEMP]		= 1,
	[MAF_AIR_FLOW]		= 2,
	[THROTTLE_POS]		= 1,
	[SEC_AIR_STAT]		= 1,
	[OXY_SENSORS1]		= 1,
	[B1S1_O2_V]			= 2,
	[B1S2_O2_V]			= 2,
	[B1S3_O2_V]			= 2,
	[B1S4_O2_V]			= 2,
	[B2S1_O2_V]			= 2,
	[B2S2_O2_V]			= 2,
	[B2S3_O2_V]			= 2,
	[B2S4_O2_V]			= 2,
	[OBD_STD]			= 1,
	[OXY_SENSORS2]		= 1,
	[AUX_INPUT]			= 1,
	[RUNTIME_START]		= 2,
	[PID_SUPPORT20]		= 4,
	[DIST_MIL_ON]		= 2,
	[FUEL_RAIL_P]		= 2,
	[FUEL_RAIL_DIESEL]	= 2,
	[O2S1_WR_V]			= 4,
	[O2S2_WR_V]			= 4,
	[O2S3_WR_V]			= 4,
	[O2S4_WR_V]			= 4,
	[O2S5_WR_V]			= 4,
	[O2S6_WR_V]			= 4,
	[O2S7_WR_V]			= 4,
	[O2S8_WR_V]			= 4,
	[EGR]				= 1,
	[EGR_ERROR]			= 1,
	[EVAP_PURGE]		= 1,
	[FUEL_LEVEL]		= 1,
	[WARM_UPS]			= 1,
	[DIST_MIL_CLR]		= 2,
	[EVAP_PRESSURE]		= 2,
	[BARO_PRESSURE]		= 1,
	[O2S1_WR_C]			= 4,
	[O2S2_WR_C]			= 4,
	[O2S3_WR_C]			= 4,
	[O2S4_WR_C]			= 4,
	[O2S5_WR_C]			= 4,
	[O2S6_WR_C]			= 4,
	[O2S7_WR_C]			= 4,
	[O2S8_WR_C]			= 4,
	[CAT_TEMP_B1S1]		= 2,
	[CAT_TEMP_B2S1]		= 2,
	[CAT_TEMP_B1S2]		= 2,
	[CAT_TEMP_B2S2]		= 2,
	[PID_SUPPORT40]		= 4,
	[MONITOR_STAT]		= 4,
	[CTRL_MOD_V]		= 2,
	[ABS_LOAD_VAL]		= 2,
	[CMD_EQUIV_R]		= 2,
	[REL_THR_POS]		= 1,
	[AMBIENT_TEMP]		= 1,
	[ABS_THR_POS_B]		= 1,
	[ABS_THR_POS_C]		= 1,
	[ACCEL_PEDAL_D]		= 1,
	[ACCEL_PEDAL_E]		= 1,
	[ACCEL_PEDAL_F]		= 1,
	[CMD_THR_ACTU]		= 1,
	[TIME_MIL_ON]		= 2,
	[TIME_MIL_CLR]		= 2
};

constexpr size_t maxPIDResLen = *std::max_element(std::begin(PIDResLens), std::end(PIDResLens));


// return 0 if pid is not supported, 1 if it is.
// mode is 0 for get_pid() and 1 for menu config to allow pid > 0xF0
bool is_pid_supported(PID pid)
{
	// note that pid PID_SUPPORT00 (0x00) is always supported
	if ((pid > 0x00 && pid <= 0x20
			&& (1L << (0x20 - pid) & pid01to20_support) == 0)
			|| (pid > 0x20 && pid <= 0x40
					&& (1L << (0x40 - pid) & pid21to40_support) == 0)
			|| (pid > 0x40 && pid <= 0x60
					&& (1L << (0x60 - pid) & pid41to60_support) == 0)
			|| (pid >= PID::N_PIDS))
	{
		return false;
	}

	return true;
}

// get value of a PID, return as a long value
// and also formatted for string output in the return buffer
bool get_pid(PID pid, uint8_t* retbuf)
{
	uint8_t cmd[2];

	// check if PID is supported (should not happen except for some 0xFn)
	if(!is_pid_supported(pid))
	{
		printf("PID %u not supported\n", pid);
		return false;
	}

	cmd[0] = 0x01;			// ISO cmd 1, get PID
	cmd[1] = pid;

	// send command, length 2
	iso_write_data(cmd, sizeof(cmd));

	// read requested length, n bytes received in buf
	iso_read_data(retbuf, PIDResLens[pid]);

	return true;
}

void check_supported_pids(void)
{
	get_pid(PID_SUPPORT00, (uint8_t*)&pid01to20_support);
	pid01to20_support = __builtin_bswap32(pid01to20_support);

	if (is_pid_supported(PID_SUPPORT20))
		get_pid(PID_SUPPORT20, (uint8_t*)&pid21to40_support);
	pid21to40_support = __builtin_bswap32(pid21to40_support);

	if (is_pid_supported(PID_SUPPORT40))
		get_pid(PID_SUPPORT40, (uint8_t*)&pid41to60_support);
	pid41to60_support = __builtin_bswap32(pid41to60_support);
}

// might be incomplete
void check_mil_codes(void)
{
	uint8_t PIDRes[maxPIDResLen];
	char str[16];
	uint8_t cmd[1];
	uint8_t buf[6];

	get_pid(MIL_CODE, PIDRes);

	uint8_t byteA = PIDRes[0];

	/* A request for this PID returns 4 bytes of data. The first uint8_t contains
	 two pieces of information. Bit A7 (the seventh bit of uint8_t A, the first byte)
	 indicates whether or not the MIL (check engine light) is illuminated. Bits A0
	 through A6 represent the number of diagnostic trouble codes currently flagged
	 in the ECU. The second, third, and fourth bytes give information about the
	 availability and completeness of certain on-board tests. Note that test
	 availability signified by set (1) bit; completeness signified by reset (0)
	 bit. (from Wikipedia)
	 */
	if(byteA & 0x80)  // test bit A7
	{
		// we have MIL on
		int nbMILCodes = byteA & 0x7F;
		printf("CHECK ENGINE ON\n");
		printf("%d CODE(S) IN ECU\n", nbMILCodes);
		delay(2000);

		// retrieve code
		cmd[0] = 0x03;
		iso_write_data(cmd, sizeof(cmd));

		int readCodes = 0;
		for (int i = 0; i < (nbMILCodes + 2) / 3; i++)  // each received packet contain 3 codes
		{
			iso_read_data(buf, 6);
			uint8_t* buf_ptr = buf;
			
			for (int j = 0; j < 3; j++)  // the 3 codes
			{
				if(readCodes < nbMILCodes)
				{
					MILCode m;

					switch ((*buf_ptr & 0xC0) >> 6)
					{
					case 0x00:
						m.letter = 'P';  // powertrain
						break;
					case 0x01:
						m.letter = 'C';  // chassis
						break;
					case 0x02:
						m.letter = 'B';  // body
						break;
					case 0x03:
						m.letter = 'U';  // network
						break;
					}

					m.chars[0] = (*buf_ptr & 0x30) >> 4;
					m.chars[1] = (*buf_ptr & 0x0F) >> 0;
					buf_ptr++;
					m.chars[2] = (*buf_ptr & 0xF0) >> 4;
					m.chars[3] = (*buf_ptr & 0x0F) >> 0;
					buf_ptr++;

					m.print();

					readCodes++;
				}
			}
		}
	}
}

OBDIIWorker::OBDIIWorker()
{

}

OBDIIWorker::~OBDIIWorker()
{

}

void OBDIIWorker::setup()
{
	uint8_t r;

	printf("Dashboard v0.1\n");

	// Loop until ISO9141 is initiated
	do
	{
		printf("ISO9141 Init... ");
		r = iso_init();
		if (r == 0)
			printf("Success!\n");
		else
			printf("Failure!\n");

		delay(1000);
	} while (r != 0);

	// check supported PIDs
	check_supported_pids();

	printf("Supported PIDs %X:\n", pid01to20_support);
	for(int i = 0; i < PID::N_PIDS; i++)
	{
		if(is_pid_supported((PID)i))
			printf("%02X\n", i);
	}

	// check if we have MIL codes
	check_mil_codes();
}

void OBDIIWorker::display(PID pid)
{
	uint8_t PIDRes[maxPIDResLen];
	get_pid(pid, PIDRes);
}

void OBDIIWorker::loop()
{
	display(VEHICLE_SPEED);

	printf("Worker loop\n");
	delay(2000);
}

void OBDIIWorker::process()
{
	setup();

	while(true)
		loop();
}