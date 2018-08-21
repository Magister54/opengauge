#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "OBDIIWorker.h"

static OBDIIWorker* data = nullptr;

void aboutToQuit()
{
	data->stop();
	data->wait();
}

int main(int argc, char *argv[])
{
	QGuiApplication app(argc, argv);

	data = new OBDIIWorker;

	QQmlApplicationEngine engine;
	engine.rootContext()->setContextProperty("applicationData", data);
	engine.load(QUrl(QStringLiteral("qrc:/main.qml")));

	QObject::connect(&app, &QGuiApplication::aboutToQuit, aboutToQuit);
	data->start();

	return app.exec();
}
