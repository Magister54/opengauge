
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

	Q_PROPERTY(int rpm MEMBER rpm NOTIFY RPMChanged)

signals:
	void RPMChanged();

private:
	int rpm;
	bool mustStop;

private:
	void setup();
};
