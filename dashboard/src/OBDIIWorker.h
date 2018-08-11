
#pragma once

#include <QThread>
#include "PID.h"

class OBDIIWorker : public QThread
{
	Q_OBJECT
public:

	OBDIIWorker();

	void run() override;
	void stop();

	Q_PROPERTY(int speed MEMBER speed NOTIFY speedChanged)

signals:
	void speedChanged();

private:
	int speed;
	bool mustStop;

private:
	void setup();
};
