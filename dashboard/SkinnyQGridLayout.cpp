
#include "SkinnyQGridLayout.h"

SkinnyQGridLayout::SkinnyQGridLayout(QWidget* parent) : QGridLayout(parent)
{
	setContentsMargins(0, 0, 0, 0);
	setSpacing(0);
}
