

# **WHY?** What does it do? #
This instrument will provide real time data of your car's condition and its fuel efficiency.  This directly translates to saving money! How?
The number one cause of low mileage, and the number one means of increasing your mileage are controled by just your right foot.  By providing real time feedback of your driving habits this device will provide hard data and motivation to learn to handle your vehicle in an eco-friendly manner.
With this tool, and your improved driving techniques, some have said these type of devices can pay for themselves in a month or two.

# What does it cost? #
Time and a little money.
Here is a sample list of parts, cost, and possible places to obtain them

|Part|Cost|Buy|
|:---|:---|:--|
|Arduino|$17 - $30 | [Freeduino via SB](http://www.solarbotics.com/products/28920/), [iDuino via FL](http://store.fundamentallogic.com/ecom/index.php?main_page=product_info&cPath=2&products_id=10)|
|HD44780 16X2 LCD Display|$8-$15|[FL](http://store.fundamentallogic.com/ecom/index.php?main_page=index&cPath=4_23), [ebay](http://shop.ebay.ca/i.html?_nkw=HD44780+16x2&_sacat=0&_trksid=p3286.m270.l1313&_odkw=HD44780&_osacat=0)|
|Transistors (2N3906 or NTE159)|nickles|[FL](http://store.fundamentallogic.com/ecom/index.php?main_page=index&cPath=4_5)|
|Three small push buttons|dimes|[FL](http://store.fundamentallogic.com/ecom/index.php?main_page=product_info&cPath=4_18&products_id=35) |
|220ohm & 510ohm resistor|pennies|[ebay](http://shop.ebay.ca/i.html?_nkw=220+resistor+ohms&_sacat=0&_trksid=p3286.m270.l1313&_dmpt=Video_Games_Accessories&_odkw=220+resistor&_osacat=0)|
|Interface Hardware|$5-$30|See Note 1 Below|
|DB9 (Serial) Male Connector|$1|ebay, see Note 2 Below|
|OBD2 Port Connector |$5|[ebay](http://shop.ebay.ca/i.html?_nkw=OBD2+Plug&_sacat=0&_trksid=p3286.m270.l1313&_odkw=j1962&_osacat=0)|
|Protoboard|$1 - $5|See Note 3 Below|
|Total:|$38 - $87|Searching can Save!|

Note 1, Interface hardware:
The ELM, an extra 33 dollar chip, acts as an interpreter between the OBDuino32K and the car, so that the device can, without additional programming, support ALL 1996 and later cars.  If the extra 33 dollars doesn't stop you, also consider that you will need to build additional hardware after the elm chip according to their documentation. See page 56 of their [data sheet](http://www.elmelectronics.com/DSheets/ELM327DS.pdf).

ISO9141-2 and ISO14230-4 (KWP2000) protocols are used commonly for imported cars, such as Toyota and Honda.  This is the most tested interface and accomplishes this with the use of the Freescale MC33290.  Available from [Future Electronics](http://www.futureelectronics.com/en/Search.aspx?dsNav=Ntk:PlainTextSearch|MC33290|3|,Ny:True,Nea:True), [Mouser](http://ca.mouser.com/Search/Refine.aspx?Keyword=mc33290), or [Digi-Key](http://search.digikey.com/scripts/DkSearch/dksus.dll?lang=en&site=CA&WT.z_homepage_link=hp_go_button&KeyWords=MC33290&x=0&y=0).

CAN Protocol is still being finalized and has not been integrated into the code base.  This is used on most newer cars (2008+).  For now, the ELM Chip is the way to go.  While progress is being made, no date is available.

Note 2, Cable Connection:
You will be building a cable that goes from the Car (OBD2 Connection) To your device.  While the Diagrams describe how to use a serial connector for the opposite end, others using just the ISO protocol have found success just using a phone cable.  This limits you to 4 wires, which means you cable will limit your device to only using ISO protocol, which in most cases is fine.

Note 3, Protoboard:
While you will use this as a base for the cable connection for your cable and possibly your MC33290 chip or other supporting hardware, some have chosen to build this device completely on one board.  This means buying an [arduino kit](http://store.fundamentallogic.com/ecom/index.php?main_page=product_info&cPath=4_28&products_id=482) without a base.  Although it means a little more planning on your part, it results in a much smaller device and will save you a few dollars at the same time!  (The kit referenced contains almost everything.  But it is missing a 5 volt regulator)


## What tools and skills will I need to build this? ##
If you have ever soldered or tinkered with electronic projects before, you can most likely build this with careful attention, and minimal bodily harm.
Collect these tools on a nice workspace:
  1. Soldering Iron
  1. Wire, Wire strippers
  1. Pliers
  1. Optionally, a helping hand tool (to help soldering that tiny MC33290 chip)

A Note about cases and construction material:
The project box to enclose your project is up to you.  Some fun choices have been an underarm deodorant container, or even a mini-rice krispy box, or a less fun plastic box.  The size and style are up to you, but keep in mind the temperature of the hot sun on your dash.  The sun _WILL_ re-melt hot glue.  While it might be quick to use to keep things in order, once things are finalized for your design it's best to use real glue or epoxy.

## What protocol does my car use? ##
While no comprehensive database with a fancy search exists, a good start is to take a look at [this chart](http://www.etools.org/files/public/generic-protocols-02-17-03.htm) to see if your vehicle is listed. Or [Here](http://www.blafusel.de/obd/obd2_scanned.php) or [here](http://www.myscantool.com/vehicles.html)
If you can not confidently find the protocol of your car there, please check the [FAQ](http://code.google.com/p/opengauge/wiki/FAQ) for more details.

# Great, I Confirmed the Protocol and Received the parts, Let's Build! #
Congratulations, Lets go to the building page:
  * [Here](http://code.google.com/p/opengauge/wiki/OBDuinoDiagram)
  * [or Here?](http://code.google.com/p/opengauge/wiki/OBDuinoInterface)

# Oh no! it doesn't work for me! #
Please check out the [FAQ](http://code.google.com/p/opengauge/wiki/FAQ) section.  If you are no further ahead, check if your answer is available on the forums at ecomodder.com.