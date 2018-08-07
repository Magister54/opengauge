
#pragma once

#include <QObject>
#include "PID.h"

class OBDIIWorker : public QObject {
	Q_OBJECT
public:
	OBDIIWorker();
	~OBDIIWorker();

private:
	void setup();
	void loop();
	void display(PID pid);

public slots:
	void process();
};
