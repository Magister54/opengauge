

# Q1: What protocol does my vehicle support #
A good start is to take a look at [this chart](http://www.etools.org/files/public/generic-protocols-02-17-03.htm) to see if your vehicle is listed. Or [Here](http://www.blafusel.de/obd/obd2_scanned.php) or [here](http://www.myscantool.com/vehicles.html)

However, the best way to determine the protocol your vehicle supports is to look at the available pins on the OBD II port of your car.  This is usually located under the steering wheel.

http://www.onboarddiagnostics.com/page03.htm lists the five different protocols and their pin outs as follows:
  * PWM (J1850)
![http://www.onboarddiagnostics.com/images/j1962pwm.gif](http://www.onboarddiagnostics.com/images/j1962pwm.gif)
  * VPW (J1850)
![http://www.onboarddiagnostics.com/images/j1962vpw.gif](http://www.onboarddiagnostics.com/images/j1962vpw.gif)
  * ISO (9141-2)  and  KWP2000
![http://www.onboarddiagnostics.com/images/j1962iso.gif](http://www.onboarddiagnostics.com/images/j1962iso.gif)
  * CAN (ISO 15765)
![http://www.onboarddiagnostics.com/images/j1962can.gif](http://www.onboarddiagnostics.com/images/j1962can.gif)

# Q2: I tried running OBDuino, but all I get is ISO 9141 Init... Failed. What do I do? #
The problem could be in either: Protocol or Wiring.
  1. Protocol
    * Using Question 1, verify that your car is indeed the ISO-9141 protocol.
    * The way each company implements the protocol may differ slightly and the software might not be prepared to handle it.  For example it may not wait long enough for a reply, or it may be getting an unexpected reply it doesn't know how to handle.
  1. Wiring
    * Double check all your connections thoroughly.
    * Try re-soldering each pin to ensure good connections.

# Q3: I have a great idea for this project that I think others would enjoy having, how do I request it, or have it added? #
The best place currently to interact with this project is on the forums at ecomodder.com located [here](http://ecomodder.com/forum/opengauge-mpguino-fe-computer.html).  Look for the thread called OBD mpguino gauge.