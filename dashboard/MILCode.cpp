
#include "MILCode.h"

#include <cstdio>

void MILCode::print()
{
	printf("%c%X%X%X%X\n", letter, chars[0], chars[1], chars[2], chars[3]);
}
