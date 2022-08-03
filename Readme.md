![](https://github.com/Magister54/opengauge/blob/wiki/pictures/idle.jpg)



# Introduction #

The OBDuino is an in-car real-time display of various information, like speed, RPM, instant fuel consumption or average trip fuel consumption as well as others PIDs supported by the car.

# Details #

The name OBDuino comes from OBD which means [On Board Diagnostics](http://en.wikipedia.org/wiki/On_Board_Diagnostics) and from the development board which is an [Arduino](http://arduino.cc) (or a clone).
_Technical info_: It is based on an Atmel AVR ATMEGA168P chip that contains 16K of flash, 1K of RAM and 512bytes of EEPROM, an LCD display, 3 buttons, a few $ of electronics components.

The OBDuino connects to the car on its OBD-II plug which is, in general, under the dash. A lot of signals are on this plug as well as battery voltage and ground. Using a standard OBD-II to DB9F cable brings us what we need.

The [interface](OBDuinoInterface.md) to the car is made with either a Freescale MC33290 for ISO only, a Microchip 2515 for CAN only, or an ELM327 (a third-party pre-programmed PIC) that talks PWM/VPW/ISO/CAN but it is more expensive and can require more hardware work if you want to use all protocols.

OBDuino can display 4 informations at a time, and there is virtual screens to have access to others PIDs. By default there is 3 screens available so it makes 12 PIDs available quickly.

# Main Hardware #

The Arduino or a clone can be purchased assembled, in a kit, or you can even etch it yourself. Take the flavour you want for serial or USB depending on your PC/laptop configuration (you need the port to program the chip). All the clone should work the same, except the very small one that use 3.3V and 8MHz and even there, it should work too with some adaptation. It costs about $15-$33 depending of your choice.

To play with, you can start with a "big" board like an Arduino Diecimila or a Freeduino SB, and to integrate in the car you can use a Boarduino or an iDuino by after.

The LCD screen used is a 2 rows x 16 characters using a standard HD44780 or compatible chipset, they can be found on eBay for $4, and they exist in almost every colours as well as STN, FSTN and even OLED (although more expensive).

The 3 buttons are momentary push button switches, take the one you want. You also need a 220 ohms resistor and a PNP 2N3906 transistor or equivalent like an NTE159 to drive the LCD brightness, as it can take up to 200mA on some LCD and the pin used to drive brightness is limited to about 20mA. radio-shack has them, or online electronic parts seller like Digikey or Mouser.

With this you have the main hardware and now need the car interface.

# Interfaces #

The code can use multiple interface (although one at a time), you will need to make the interface specific for your car, see [Interface](OBDuinoInterface.md). If your car is sold in north-america and is a 2008+ it uses CAN so you can built the interface using Microchip MCP2515 and MCP2551.

Interface connect to the Arduino on a few pins, depending on your choice, the LCD will be connected differently, see [Diagram](OBDuinoDiagram.md).

# Menu Configuration #

## Role of the three buttons ##

|        | realtime display  | menu display |
|:-------|:------------------|:-------------|
| LEFT   |  rotate screen    | decrease, select NO |
| MIDDLE | go into menu      | apply and go to next item |
| RIGHT  | rotate brightness | increase, select YES |
| MIDDLE+RIGHT | trip reset |  |
| MIDDLE+LEFT | tank trip reset |  |


### Reset trip data (NO/YES) ###
When you press middle and right button, a screen appear: Select if you want to reset the data and press middle button to ack.

### Reset tank data (NO/YES) ###
When you press middle and left button, a screen appear: Select if you want to reset the data and press middle button to ack.

## Configuration menu (accessed by middle button) ##

### LCD Contrast (0-100) ###
Set the LCD contrast from 0 to 100 in step 10

### Use Metric units (NO/YES) ###
NO=rods and hogshead, YES=SI

### Fuel/hour speed (0-255) ###
Speed from which the display go from L/100 or MPG, to L/h or GPH

### Tank size (n.m) ###
Size of your tank in litres or gallon

### Volume Efficiency (0-100%) (MAP only) ###
For vehicles with a MAP only we have to emulate the MAF.
This percentage will needs adjustment after you have checked manually a few tank to approximate better the fuel consumption.

### Engine Displacement (0.0-10.0) (MAP only) ###
For vehicles with a MAP only we have to emulate the MAF.
This is the size of the engine, e.g. 2.0 for a 2Liter one.

### Configure PIDs (NO/YES) ###
Choose if you want to configure the PIDs in the various screen.

### Scr 'n' Corner 'm' (0x00-0xFF) ###
(if you have selected YES at the previous item)
Select the PID you want to be displayed on screen 'n' in the corner 'm'.
A good list of PIDs is on Wikipedia [here](http://en.wikipedia.org/wiki/OBD-II_PIDs)
Some specials PIDs you can access (either by decreasing below 0 or by going far up):
  * 0xF0 - no display, meaning this corner will be blank, can be useful if another PID result is more than 8 characters
  * 0xF1 - Instant fuel consumption
  * 0xF2 - Average fuel consumption of the tank (since last tank reset)
  * 0xF3 - Fuel used in the current tank
  * 0xF4 - Distance done on the current tank
  * 0xF5 - Remaining distance that can be done on the current tank
  * 0xF6 - Average fuel consumption of the trip (since last trip reset)
  * 0xF7 - Fuel used for the current trip
  * 0xF8 - Distance of the current trip
  * 0xF9 - Battery voltage
  * 0xFA - CAN status, for CAN protocol only, display TX and RX errors
