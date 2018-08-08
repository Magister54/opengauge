
#pragma once

#include <QWidget>
#include <QLabel>

class MainWindow : public QWidget
{
	Q_OBJECT
public:
	explicit MainWindow(QWidget *parent = 0);

	QLabel* speedLabel;

public slots:
	void updateSpeedLabel(const QString str);

protected:
	void keyPressEvent(QKeyEvent* e);

private:
	void setupUI();
};
