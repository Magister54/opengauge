
#pragma once

#include <QObject>
#include "PID.h"

class OBDIIWorker : public QObject {
	Q_OBJECT
public:
	OBDIIWorker();
	~OBDIIWorker();

public slots:
	void process();

private:
	void setup();
	void loop();
	void display(PID pid);

signals:
	void updateSpeedLabel(const QString str);
};
