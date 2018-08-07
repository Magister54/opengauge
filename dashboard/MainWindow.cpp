
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

	QLabel* label0 = new QLabel("label0");
	layoutLeft->addWidget(label0);
	label0->setStyleSheet("QLabel { background-color : red; color : blue; font : 72pt; }");
	label0->setAlignment(Qt::AlignCenter);

	QLabel* label1 = new QLabel("label1");
	layoutLeft->addWidget(label1);
	label1->setStyleSheet("QLabel { background-color : yellow; color : cyan; }");

	QLabel* label2 = new QLabel("label2");
	layoutRight->addWidget(label2);
	label2->setStyleSheet("QLabel { background-color : green; color : magenta; }");
}

void MainWindow::keyPressEvent(QKeyEvent* e)
{
	// Toggle full screen
	if(e->key() == Qt::Key_F11)
	{
		isFullScreen() ? showNormal() : showFullScreen();
	}
}
