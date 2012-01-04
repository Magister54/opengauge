echo Object sizes > binary-sizes.txt
..\..\tools\avr\bin\avr-size FileLogger.o >> binary-sizes.txt
..\..\tools\avr\bin\avr-size nanofat.o >> binary-sizes.txt
..\..\tools\avr\bin\avr-size mmc.o >> binary-sizes.txt
..\..\tools\avr\bin\avr-size Spi.o >> binary-sizes.txt