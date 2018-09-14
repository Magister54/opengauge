#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>

#include "DashboardApplication.h"
#include "OBDIIWorker.h"

int main(int argc, char *argv[])
{
	OBDIIWorker* worker = new OBDIIWorker;
	DashboardApplication* app = new DashboardApplication(worker, argc, argv);

	QQmlApplicationEngine engine;
	engine.rootContext()->setContextProperty("applicationData", worker);
	engine.load(QUrl(QStringLiteral("qrc:/main.qml")));
	
	// Establish connections between UI and backend
	QObject* topLevel = engine.rootObjects().value(0);
	QQuickWindow* window = qobject_cast<QQuickWindow*>(topLevel);
	QObject::connect(window, SIGNAL(checkErrorCodes()), worker, SLOT(handleCheckErrorCodes()));
	QObject::connect(window, SIGNAL(clearErrorCodes()), worker, SLOT(handleClearErrorCodes()));
	QObject::connect(window, SIGNAL(checkForUpdates()), app, SLOT(handleCheckForUpdates()));
	QObject::connect(window, SIGNAL(killApplication()), app, SLOT(handleKillApplication()));
	QObject::connect(worker, SIGNAL(checkErrorCodesDone(QVariant)), window, SLOT(checkErrorCodesDone(QVariant)));
	QObject::connect(worker, SIGNAL(clearErrorCodesDone(QVariant)), window, SLOT(clearErrorCodesDone(QVariant)));

	QObject::connect(app, &DashboardApplication::aboutToQuit, app, &DashboardApplication::killWorker);
	worker->start();

	return app->exec();
}
