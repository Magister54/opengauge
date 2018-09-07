#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>

#include "OBDIIWorker.h"

static OBDIIWorker* worker = nullptr;

void aboutToQuit()
{
	worker->stop();
	worker->wait();
}

int main(int argc, char *argv[])
{
	QGuiApplication app(argc, argv);

	worker = new OBDIIWorker;

	QQmlApplicationEngine engine;
	engine.rootContext()->setContextProperty("applicationData", worker);
	engine.load(QUrl(QStringLiteral("qrc:/main.qml")));
	
	// Establish connections between UI and backend
	QObject* topLevel = engine.rootObjects().value(0);
	QQuickWindow* window = qobject_cast<QQuickWindow*>(topLevel);
	QObject::connect(window, SIGNAL(checkErrorCodes()), worker, SLOT(handleCheckErrorCodes()));
	QObject::connect(window, SIGNAL(clearErrorCodes()), worker, SLOT(handleClearErrorCodes()));
	QObject::connect(worker, SIGNAL(checkErrorCodesDone(QVariant)), window, SLOT(checkErrorCodesDone(QVariant)));
	QObject::connect(worker, SIGNAL(clearErrorCodesDone(QVariant)), window, SLOT(clearErrorCodesDone(QVariant)));

	QObject::connect(&app, &QGuiApplication::aboutToQuit, aboutToQuit);
	worker->start();

	return app.exec();
}
