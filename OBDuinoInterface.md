

# Introduction #

You cannot directly connect pins from the OBD-II plug to the Arduino board. You need a small interface that convert the signal.

Whatever the interface needed, you also need a cable that will bring you the signals from the OBD-II plug to your OBDuino.

For all cases:
The Arduino is powered by the 12V line coming from the cable too so you need to bring some wires from the DB9M to the Arduino like this:
```
Arduino 12V input ------------------ DB9M pin 9 (12V Battery)
Arduino GND input ------------------ DB9M pin 2 (Chassis Ground)
```
**Some cars have only one ground so you may have to use DB9M pin 1 instead of pin 2 to power the board or just solder pin 1 and 2 together**

# Cable #

To keep compatibility with already existing cable, the OBDuino Interface pinout for the OBD-II to DB9F cable is wired like this:

```
DB9F			OBD-II
1---------------5  (Signal ground)
2---------------4  (Chassis ground)
3---------------6  (CAN High)
4---------------7  (ISO K line)
5---------------14 (CAN Low)
6---------------10 (J1850 bus-)
7---------------2  (J1850 bus+)
8---------------15 (ISO L Line)
9---------------16 (Battery)
```
**Do not plug it into a PC!!! This goes to an interface only!!!**

Example of my home made cable:

![](https://github.com/Magister54/opengauge/pictures/obd2_cable.jpg)

A nice place to get OBD-II plugs and already made cable is [Senso](http://www.sensolutions.com/products/browse-products/) which are located in Canada.

You can also find plugs at http://www.carplugs.com/ or http://www.obd2allinone.com/sc/details.asp?item=obd2cable and others.

## CAN only cable ##

A proposed CAN only cable, smaller and thinner, can be wired like this:
```
RJ-10     		OBD-II
1 (black) ------5  (Signal ground)
2 (red)---------14 (CAN Low)
3 (green)-------6  (CAN High)
4 (yellow)------16 (Battery)
```
source http://www.controllerareanetwork.com/CANcables.htm

# Interfaces #

## Interface for ISO ##

This interface converts the ISO signals for the Arduino inputs.
It consists of a small IC ([Freescale MCZ33290EF](http://www.freescale.com/webapp/sps/site/prod_summary.jsp?code=MC33290)), a 510 ohms resistor, a DB9M that will be plugged with the cable mentioned above, and few wires that connect to the Arduino board.

The MC33290 is a small chip, you can solder some wires on it for better handling.
![](https://github.com/Magister54/opengauge/pictures/MC33290.jpg)

Schematic is like this:
```
                             MC33290
                            +-------+
Arduino pin 1 -------------5|TX  ISO|4-----------------+------- DB9M pin 4 (ISO K Line)
                            |       |                  |
Arduino pin 0 -------------6|RX  GND|3--DB9M pin 1     / between MC pin 4 and pin 1
                            |       |                  \ goes a 510 ohms resistor
Arduino 5V pin output -----7|VDD  NC|2--               /
                            |       |                  |
Arduino 5V pin output -----8|CEN VBB|1-----------------+------- DB9M pin 9 (12V Battery)
                            +-------+
```

Interface front:

![](https://github.com/Magister54/opengauge/pictures/iso_interface.jpg)

Interface back:

![](https://github.com/Magister54/opengauge/pictures/iso_interface_back.jpg)


## Interface with ELM ##

CAN protocol is not easy to program so as a phase 1 I am using an [http:http://www.elmelectronics.com/ ELM327] for this. This chip integrates all protocol so it could be used for ISO/VPW/PWM as well, but it's a $32+s/h chip that add to the duino and LCD, plus a few components.

Note that for PWM/VPW it should be possible to use an ELM320 or ELM323 respectively, which is cheaper than the ELM327 and would require almost no change to the code, but you would still need to do some hadware, schematics are avalaible on some web site.

Diagram of the interface (adaptation of the generic diagram found in the PDF of the ELM327):

![](https://github.com/Magister54/opengauge/pictures/CANduino.gif)

On the diagram, note that CAN-L (OBD2 pin 14) go to a DB9M pin 5 and CAN-H (OBD2 pin 6) go to a DB9M pin 3. +5V comes from the Arduino board.

![](https://github.com/Magister54/opengauge/pictures/CAN_Interface_front.jpg)
![](https://github.com/Magister54/opengauge/pictures/CAN_Interface_back.jpg)
