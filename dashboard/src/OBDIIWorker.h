
#pragma once

#include <QThread>
#include <QVariant>
#include "PID.h"

class OBDIIWorker : public QThread
{
	Q_OBJECT
public:

	OBDIIWorker();

	void run() override;
	void stop();

	Q_PROPERTY(float rpm MEMBER rpm NOTIFY RPMChanged)
	Q_PROPERTY(int speed MEMBER speed NOTIFY SpeedChanged)
	Q_PROPERTY(float ic MEMBER ic NOTIFY IcChanged)

signals:
	void RPMChanged();
	void SpeedChanged();
	void IcChanged();
	void checkErrorCodesDone(QVariant text);
	void clearErrorCodesDone(QVariant text);
	
public slots:
	void handleCheckErrorCodes();
	void handleClearErrorCodes();

private:
	float rpm;
	int speed;
	float ic;
	bool mustStop;
	bool checkErrorCodes;
	bool clearErrorCodes;

private:
	void setup();
};
