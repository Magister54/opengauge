
#include <iostream>

#include <QKeyEvent>
#include <QGridLayout>
#include <QLabel>

#include "SkinnyQGridLayout.h"
#include "MainWindow.h"

using namespace std;


MainWindow::MainWindow(QWidget *parent) : QWidget(parent)
{
	setupUI();
}

void MainWindow::setupUI()
{
	SkinnyQGridLayout* mainLayout = new SkinnyQGridLayout(this);

	SkinnyQGridLayout* layoutLeft = new SkinnyQGridLayout();
	SkinnyQGridLayout* layoutRight = new SkinnyQGridLayout();

	mainLayout->addLayout(layoutLeft, 0, 0);
	mainLayout->addLayout(layoutRight, 0, 1);

	SkinnyQGridLayout* layoutTopLeft = new SkinnyQGridLayout();
	SkinnyQGridLayout* layoutBottomLeft = new SkinnyQGridLayout();

	layoutLeft->addLayout(layoutTopLeft, 0, 0);
	layoutLeft->addLayout(layoutBottomLeft, 1, 0);

	speedLabel = new QLabel("0 km/h");
	speedLabel->setObjectName("speedLabel");
	layoutLeft->addWidget(speedLabel);
	speedLabel->setAlignment(Qt::AlignCenter);

	QLabel* label1 = new QLabel("0 L/100km");
	layoutLeft->addWidget(label1);
	label1->setAlignment(Qt::AlignCenter);

	QLabel* label2 = new QLabel("0 RPM");
	layoutLeft->addWidget(label2);
	label2->setAlignment(Qt::AlignCenter);

	QLabel* label3 = new QLabel("music");
	layoutRight->addWidget(label3);
	label3->setAlignment(Qt::AlignCenter);

	QFile stylesheet("../style.css");
	stylesheet.open(QFile::ReadOnly);
	setStyleSheet(stylesheet.readAll());
}

void MainWindow::keyPressEvent(QKeyEvent* e)
{
	// Toggle full screen
	if(e->key() == Qt::Key_F11)
	{
		isFullScreen() ? showNormal() : showFullScreen();
	}
}

void MainWindow::updateSpeedLabel(const QString str)
{
	speedLabel->setText(str);
}
