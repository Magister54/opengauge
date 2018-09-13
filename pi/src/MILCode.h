
#include <cinttypes>

#include <QString>

class MILCode
{
public:
	void print();
	QString toQString();

	char letter;
	uint8_t chars[4];
};
