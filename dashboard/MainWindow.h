
#pragma once

#include <QWidget>

class MainWindow : public QWidget
{
	Q_OBJECT
	public:
	explicit MainWindow(QWidget *parent = 0);

	protected:
	void keyPressEvent(QKeyEvent* e);

	private:
	void setupUI();
};
