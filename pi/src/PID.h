
#pragma once

enum PID {
	PID_SUPPORT00,
	MIL_CODE,
	FREEZE_DTC,
	FUEL_STATUS,
	LOAD_VALUE,
	COOLANT_TEMP,
	STFT_BANK1,
	LTFT_BANK1,
	STFT_BANK2,
	LTFT_BANK2,
	FUEL_PRESSURE,
	MAN_PRESSURE,
	ENGINE_RPM,
	VEHICLE_SPEED,
	TIMING_ADV,
	INT_AIR_TEMP,
	MAF_AIR_FLOW,
	THROTTLE_POS,
	SEC_AIR_STAT,
	OXY_SENSORS1,
	B1S1_O2_V,
	B1S2_O2_V,
	B1S3_O2_V,
	B1S4_O2_V,
	B2S1_O2_V,
	B2S2_O2_V,
	B2S3_O2_V,
	B2S4_O2_V,
	OBD_STD,
	OXY_SENSORS2,
	AUX_INPUT,
	RUNTIME_START,
	PID_SUPPORT20,
	DIST_MIL_ON,
	FUEL_RAIL_P,
	FUEL_RAIL_DIESEL,
	O2S1_WR_V,
	O2S2_WR_V,
	O2S3_WR_V,
	O2S4_WR_V,
	O2S5_WR_V,
	O2S6_WR_V,
	O2S7_WR_V,
	O2S8_WR_V,
	EGR,
	EGR_ERROR,
	EVAP_PURGE,
	FUEL_LEVEL,
	WARM_UPS,
	DIST_MIL_CLR,
	EVAP_PRESSURE,
	BARO_PRESSURE,
	O2S1_WR_C,
	O2S2_WR_C,
	O2S3_WR_C,
	O2S4_WR_C,
	O2S5_WR_C,
	O2S6_WR_C,
	O2S7_WR_C,
	O2S8_WR_C,
	CAT_TEMP_B1S1,
	CAT_TEMP_B2S1,
	CAT_TEMP_B1S2,
	CAT_TEMP_B2S2,
	PID_SUPPORT40,
	MONITOR_STAT,
	CTRL_MOD_V,
	ABS_LOAD_VAL,
	CMD_EQUIV_R,
	REL_THR_POS,
	AMBIENT_TEMP,
	ABS_THR_POS_B,
	ABS_THR_POS_C,
	ACCEL_PEDAL_D,
	ACCEL_PEDAL_E,
	ACCEL_PEDAL_F,
	CMD_THR_ACTU,
	TIME_MIL_ON,
	TIME_MIL_CLR,
	N_PIDS
};

#define A			data[0]
#define B			data[1]
#define C			data[2]
#define D			data[3]

class OBDIIPID
{
public:
	OBDIIPID(uint8_t* data) : data(data) {}
	virtual double getEU() = 0;
protected:
	uint8_t* data;
};

class EngineRPM : OBDIIPID
{
public:
	EngineRPM(uint8_t* data) : OBDIIPID(data) {}
	virtual double getEU(){return (256.f * A + B) / 4;}
};

class VehicleSpeed : OBDIIPID
{
public:
	VehicleSpeed(uint8_t* data) : OBDIIPID(data) {}
	virtual double getEU(){return A;}
};

class CoolantTemp : OBDIIPID
{
public:
	CoolantTemp(uint8_t* data) : OBDIIPID(data) {}
	virtual double getEU(){return A - 40;}
};

class FuelTrim : OBDIIPID
{
public:
	FuelTrim(uint8_t* data) : OBDIIPID(data) {}
	virtual double getEU(){return 100.f * A / 128 - 100;}
};

class TimingAdvance : OBDIIPID
{
public:
	TimingAdvance(uint8_t* data) : OBDIIPID(data) {}
	virtual double getEU(){return 0.5f * A - 64;}
};

#define IntakeAirTemp CoolantTemp

class AirFlowRate : OBDIIPID
{
public:
	AirFlowRate(uint8_t* data) : OBDIIPID(data) {}
	virtual double getEU(){return (256.f * A + B) / 100;}
};

class ThrottlePosition : OBDIIPID
{
public:
	ThrottlePosition(uint8_t* data) : OBDIIPID(data) {}
	virtual double getEU(){return 100.f / 255 * A;}
};

class OxySensor : OBDIIPID
{
public:
	OxySensor(uint8_t* data) : OBDIIPID(data) {}
	virtual double getEU(){return 2.0/65536*(256.f*A+B);}
	double getVoltage(){return 8.0/65536*(256.f*C+D);}
};
