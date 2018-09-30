
#pragma once

#include <QGuiApplication>

#include "OBDIIWorker.h"

class DashboardApplication: public QGuiApplication
{
	Q_OBJECT
public:
	DashboardApplication(OBDIIWorker* worker, int &argc, char **argv);

	void killWorker();

public slots:
	void handleCheckForUpdates();
	void handleKillApplication();

private:
	OBDIIWorker* worker;
};
