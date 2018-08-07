#include <QApplication>
#include <QPushButton>
#include <QThread>

#include "OBDIIWorker.h"
#include "MainWindow.h"

int main(int argc, char **argv)
{
	QApplication app (argc, argv);

	QThread* thread = new QThread();
	OBDIIWorker* worker = new OBDIIWorker();
	worker->moveToThread(thread);
	thread->start();
	QObject::connect(thread, &QThread::started, worker, &OBDIIWorker::process);
	thread->setPriority(QThread::HighestPriority);

	MainWindow window;
	window.show();
	window.showFullScreen();

	return app.exec();
}
