
#include "DashboardApplication.h"

DashboardApplication::DashboardApplication(OBDIIWorker* worker, int &argc, char **argv) : QGuiApplication(argc, argv), worker(worker)
{

}

void DashboardApplication::killWorker()
{
	worker->stop();
	worker->wait();
}

void DashboardApplication::handleCheckForUpdates()
{
	killWorker();
	system("gnome-terminal -- ../checkForUpdates.sh");
	quit();
}

void DashboardApplication::handleKillApplication()
{
	killWorker();
	quit();
}
