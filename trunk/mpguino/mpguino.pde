#define ver=700
/*

*/
//GPL Software    
//#define debuguino youbetyourbippy  
#include <avr/pgmspace.h>  
byte brightness[]={0,42,85,128}; //middle button cycles through these brightness settings      
#define brightnessLength (sizeof(brightness)/sizeof(byte)) //array size      
byte brightnessIdx=1;      


#define contrastIdx 0  //do contrast first to get display dialed in
#define vssPulsesPerMileIdx 1
#define microSecondsPerGallonIdx 2
#define injPulsesPer2Revolutions 3
#define currentTripResetTimeoutUSIdx 4
#define tankSizeIdx 5 
#define injectorSettleTimeIdx 6
#define weightIdx 7
#define scratchpadIdx 8
char *  parmLabels[]={"Contrast","VSS Pulses/Mile", "MicroSec/Gallon","Pulses/2 revs","Timout(microSec)","Tank Gal * 1000","Injector DelayuS","Weight (lbs)","scratchpad(odo?)"};
//unsigned long  parms[]={15ul,16408ul,684968626ul,3ul,420000000ul,13300ul,500ul};//default values
unsigned long  parms[]={15ul,10000ul,304409714ul,4ul,420000000ul,13300ul,500ul,2400ul,0ul,};//default values
#define parmsLength (sizeof(parms)/sizeof(unsigned long)) //array size      


 
#define guinosig B10100101
#include <EEPROM.h>
//Vehicle Interface Pins      
#define InjectorOpenPin 2      
#define InjectorClosedPin 3      
#define VSSPin 14 //analog 0      
 
//LCD Pins      
#define DIPin 4 // register select RS      
#define DB4Pin 7       
#define DB5Pin 8       
#define DB6Pin 12       
#define DB7Pin 13      
#define ContrastPin 6      
#define EnablePin 5       
#define BrightnessPin 9      
 
#define lbuttonPin 17 // Left Button, on analog 3,        
#define mbuttonPin 18 // Middle Button, on analog 4       
#define rbuttonPin 19 // Right Button, on analog 5       
 
#define vssBit 1     //  pin14 is a bitmask 1 on port C        
#define lbuttonBit 8 //  pin17 is a bitmask 8 on port C        
#define mbuttonBit 16 // pin18 is a bitmask 16 on port C        
#define rbuttonBit 32 // pin19 is a bitmask 32 on port C        
#define loopsPerSecond 2 // how many times will we try and loop in a second     

typedef void (* pFunc)(void);//type for display function pointers      

volatile unsigned long timer2_overflow_count;

/*** Set up the Events ***
We have our own ISR for timer2 which gets called about once a millisecond.
So we define certain event functions that we can schedule by calling addEvent
with the event ID and the number of milliseconds to wait before calling the event. 
The milliseconds is approximate.

Keep the event functions SMALL!!!  This is an interrupt!

*/
//event functions

void enableLButton(){PCMSK1 |= (1 << PCINT11);}
void enableMButton(){PCMSK1 |= (1 << PCINT12);}
void enableRButton(){PCMSK1 |= (1 << PCINT13);}
//array of the event functions
pFunc eventFuncs[] ={enableVSS, enableLButton,enableMButton,enableRButton};
#define eventFuncSize (sizeof(eventFuncs)/sizeof(pFunc)) 
//define the event IDs
#define enableVSSID 0
#define enableLButtonID 1
#define enableMButtonID 2
#define enableRButtonID 3
//ms counters
unsigned int eventFuncCounts[eventFuncSize];

//schedule an event to occur ms milliseconds from now
void addEvent(byte eventID, unsigned int ms){
  eventFuncCounts[eventID]=ms;
}

/* this ISR gets called every 1.024 milliseconds, we will call that a millisecond for our purposes
go through all the event counts, 
  if any are non zero subtract 1 and call the associated function if it just turned zero.  */
ISR(TIMER2_OVF_vect){
  timer2_overflow_count++;
  for(byte eventID = 0; eventID < eventFuncSize; eventID++){
    if(eventFuncCounts[eventID]!= 0){
      eventFuncCounts[eventID]--;
      if(eventFuncCounts[eventID] == 0)
          eventFuncs[eventID](); 
    }  
  }
}

 
 
unsigned long maxLoopLength = 0; //see if we are overutilizing the CPU      
 
 
#define buttonsUp   lbuttonBit + mbuttonBit + rbuttonBit  // start with the buttons in the right state      
byte buttonState = buttonsUp;      
 
 
//overflow counter used by millis2()      
unsigned long lastMicroSeconds=millis2() * 1000;   
unsigned long microSeconds (void){     
  unsigned long tmp_timer2_overflow_count;    
  unsigned long tmp;    
  byte tmp_tcnt2;    
  cli(); //disable interrupts    
  tmp_timer2_overflow_count = timer2_overflow_count;    
  tmp_tcnt2 = TCNT2;    
  sei(); // enable interrupts    
  tmp = ((tmp_timer2_overflow_count << 8) + tmp_tcnt2) * 4;     
  if((tmp<=lastMicroSeconds) && (lastMicroSeconds<4290560000ul))    
    return microSeconds();     
  lastMicroSeconds=tmp;   
  return tmp;     
}    
 
unsigned long elapsedMicroseconds(unsigned long startMicroSeconds, unsigned long currentMicroseconds ){      
  if(currentMicroseconds >= startMicroSeconds)      
    return currentMicroseconds-startMicroSeconds;      
  return 4294967295 - (startMicroSeconds-currentMicroseconds);      
}      

unsigned long elapsedMicroseconds(unsigned long startMicroSeconds ){      
  return elapsedMicroseconds(startMicroSeconds, microSeconds());
}      
 
//Trip prototype      
class Trip{      
public:      
  unsigned long loopCount; //how long has this trip been running      
  unsigned long injPulses; //rpm      
  unsigned long injHiSec;// seconds the injector has been open      
  unsigned long injHius;// microseconds, fractional part of the injectors open       
  unsigned long vssPulses;//from the speedo      
  //these functions actually return in thousandths,       
  unsigned long miles();        
  unsigned long gallons();      
  unsigned long mpg();        
  unsigned long mph();        
  unsigned long time(); //mmm.ss        
  void update(Trip t);      
  void reset();      
  Trip();      
};      
 
//LCD prototype      
namespace LCD{      
  void gotoXY(byte x, byte y);      
  void print(char * string);      
  void init();      
  void tickleEnable();      
  void cmdWriteSet();      
  void LcdCommandWrite(byte value);      
  void LcdDataWrite(byte value);      
  byte pushNibble(byte value);      
};      
 
 
//main objects we will be working with:      
unsigned long injHiStart; //for timing injector pulses      
Trip tmpTrip;      
Trip instant;      
Trip current;      
Trip tank;      
 
void processInjOpen(void){      
  injHiStart = microSeconds();      
}      
 
void processInjClosed(void){      
  long x = elapsedMicroseconds(injHiStart)- parms[injectorSettleTimeIdx];       
  if(x >0)
    tmpTrip.injHius += x;       
  tmpTrip.injPulses++;      
}      

volatile boolean vssFlop = 0;

void enableVSS(){
    tmpTrip.vssPulses++; 
    vssFlop = !vssFlop;
}

unsigned volatile long lastVSS1;
unsigned volatile long lastVSSTime;
unsigned volatile long lastVSS2;

volatile boolean lastVssFlop = vssFlop;

//attach the vss/buttons interrupt      
ISR( PCINT1_vect ){   
  static byte vsspinstate=0;      
  byte p = PINC;//bypassing digitalRead for interrupt performance      
  if ((p & vssBit) != (vsspinstate & vssBit)){      
    addEvent(enableVSSID,2 ); //check back in a couple milli
  }     
  if(lastVssFlop != vssFlop){
    lastVSS1=lastVSS2;
    unsigned long t = microSeconds();
    lastVSS2=elapsedMicroseconds(lastVSSTime,t);
    lastVSSTime=t;
    lastVssFlop = vssFlop;
  }
  vsspinstate = p;      
  buttonState &= p;      
}       
 
 
pFunc displayFuncs[] ={ 
  doDisplayInstantCurrent, 
  doDisplayInstantTank, 
  doDisplayBigInstant, 
  doDisplayBigCurrent, 
  doDisplayBigTank, 
  doDisplay2, 
  doDisplay3, 
  doDisplay4, 
  doDisplay5, 
  doDisplay6, 
  doDisplay7};      
#define displayFuncSize (sizeof(displayFuncs)/sizeof(pFunc)) //array size      
prog_char  * displayFuncNames[displayFuncSize]; 
byte newRun = 0;
void setup (void){
  init2();
  #ifdef debuguino  
  Serial.begin(9600);  
  Serial.println("OpenGauge MPGuino online");  
  #endif      
  newRun = load();//load the default parameters
  displayFuncNames[0]=  PSTR("Instant/Current "); 
  displayFuncNames[1]=  PSTR("Instant/Tank "); 
  displayFuncNames[2]=  PSTR("BIG Instant "); 
  displayFuncNames[3]=  PSTR("BIG Current "); 
  displayFuncNames[4]=  PSTR("BIG Tank "); 
  displayFuncNames[5]=  PSTR("Current "); 
  displayFuncNames[6]=  PSTR("Tank "); 
  displayFuncNames[7]=  PSTR("Instant raw Data"); 
  displayFuncNames[8]=  PSTR("Current raw Data"); 
  displayFuncNames[9]=  PSTR("Tank raw Data "); 
  displayFuncNames[10]= PSTR("CPU Monitor ");      
 
  pinMode(BrightnessPin,OUTPUT);      
  analogWrite(BrightnessPin,255-brightness[brightnessIdx]);      
  pinMode(EnablePin,OUTPUT);       
  pinMode(DIPin,OUTPUT);       
  pinMode(DB4Pin,OUTPUT);       
  pinMode(DB5Pin,OUTPUT);       
  pinMode(DB6Pin,OUTPUT);       
  pinMode(DB7Pin,OUTPUT);       
  delay2(500);      
 
  pinMode(ContrastPin,OUTPUT);      
  analogWrite(ContrastPin,parms[contrastIdx]);  
  LCD::init();      
  LCD::LcdCommandWrite(B00000001);  // clear display, set cursor position to zero         
  LCD::LcdCommandWrite(B10000000);  // set dram to zero
  LCD::gotoXY(0,0); 
  LCD::print(getStr(PSTR("OpenGauge       ")));      
  LCD::gotoXY(0,1);      
  LCD::print(getStr(PSTR("  MPGuino  v0.70")));      

  pinMode(InjectorOpenPin, INPUT);       
  pinMode(InjectorClosedPin, INPUT);       
  pinMode(VSSPin, INPUT);            
  attachInterrupt(0, processInjOpen, FALLING);      
  attachInterrupt(1, processInjClosed, RISING);      
 
  pinMode( lbuttonPin, INPUT );       
  pinMode( mbuttonPin, INPUT );       
  pinMode( rbuttonPin, INPUT );      
 
 
  //"turn on" the internal pullup resistors      
  digitalWrite( lbuttonPin, HIGH);       
  digitalWrite( mbuttonPin, HIGH);       
  digitalWrite( rbuttonPin, HIGH);       
//  digitalWrite( VSSPin, HIGH);       
 
  //low level interrupt enable stuff      
  PCMSK1 |= (1 << PCINT8);
  enableLButton();
  enableMButton();
  enableRButton();
  PCICR |= (1 << PCIE1);       
 
  delay2(1500);       
}       
 
byte screen=0;      
byte holdDisplay = 0; 

#define looptime 1000000ul/loopsPerSecond //1/2 second      
void loop (void){       
  if(newRun !=1)
    initGuino();//go through the initialization screen
  unsigned long lastActivity =microSeconds();
  unsigned long tankHold;      //state at point of last activity
  while(true){      
    unsigned long loopStart=microSeconds();      
    instant.reset();           //clear instant      
    cli();
    instant.update(tmpTrip);   //"copy" of tmpTrip in instant now      
    tmpTrip.reset();           //reset tmpTrip first so we don't lose too many interrupts      
    sei();
    
    #ifdef debuguino  
    Serial.print("instant: ");Serial.print(instant.injHiSec);Serial.print(",");Serial.print(instant.injHius);  
    Serial.print(",");Serial.print(instant.injPulses);Serial.print(",");Serial.println(instant.vssPulses);      
    #endif  
    current.update(instant);   //use instant to update current      
    tank.update(instant);      //use instant to update tank      
    #ifdef debuguino  
    Serial.print("current: ");Serial.print(current.injHiSec);Serial.print(",");Serial.print(current.injHius);  
    Serial.print(",");Serial.print(current.injPulses);Serial.print(",");Serial.println(current.vssPulses);      
    #endif  

//currentTripResetTimeoutUS
    if(instant.vssPulses == 0 && instant.injPulses == 0 && holdDisplay==0){
      if(elapsedMicroseconds(lastActivity) > parms[currentTripResetTimeoutUSIdx] && lastActivity != 3999999999ul){
        analogWrite(BrightnessPin,255-brightness[0]);    //nitey night
        lastActivity = 3999999999ul;
      }
    }else{
      if(lastActivity == 3999999999ul){//wake up!!!
        analogWrite(BrightnessPin,255-brightness[brightnessIdx]);    
        lastActivity=loopStart;
        current.reset();
        tank.loopCount = tankHold;
        current.update(instant); 
        tank.update(instant); 
      }else{
        lastActivity=loopStart;
        tankHold = tank.loopCount;
      }
    }
    


 
 if(holdDisplay==0){
    displayFuncs[screen]();    //call the appropriate display routine      
    LCD::gotoXY(0,0);        
    
//see if any buttons were pressed, display a brief message if so      
      if(!(buttonState&lbuttonBit) && !(buttonState&mbuttonBit)&& !(buttonState&rbuttonBit)){// left and middle and right = initialize      
          LCD::print(getStr(PSTR("Setup ")));    
          initGuino();  
      //}else if(!(buttonState&lbuttonBit) && !(buttonState&rbuttonBit)){// left and right = run lcd init = tank reset      
      //    LCD::print(getStr(PSTR("Init LCD "))); 
      //    LCD::init();
      }else if (!(buttonState&lbuttonBit) && !(buttonState&mbuttonBit)){// left and middle = tank reset      
          tank.reset();      
          LCD::print(getStr(PSTR("Tank Reset ")));      
      }else if(!(buttonState&mbuttonBit) && !(buttonState&rbuttonBit)){// right and middle = current reset      
          current.reset();      
          LCD::print(getStr(PSTR("Current Reset ")));      
      }else if(!(buttonState&lbuttonBit)){ //left is rotate through screeens to the left      
        if(screen!=0)      
          screen=(screen-1);       
        else      
          screen=displayFuncSize-1;      
        LCD::print(getStr(displayFuncNames[screen]));      
      }else if(!(buttonState&mbuttonBit)){ //middle is cycle through brightness settings      
        brightnessIdx = (brightnessIdx + 1) % brightnessLength;      
        analogWrite(BrightnessPin,255-brightness[brightnessIdx]);      
        LCD::print(getStr(PSTR("Brightness ")));      
        LCD::LcdDataWrite('0' + brightnessIdx);      
        LCD::print(" ");      
      }else if(!(buttonState&rbuttonBit)){//right is rotate through screeens to the left      
        screen=(screen+1)%displayFuncSize;      
        LCD::print(getStr(displayFuncNames[screen]));      
      }      
      if(buttonState!=buttonsUp)
         holdDisplay=1;
     }else{
        holdDisplay=0;
    } 
    buttonState=buttonsUp;//reset the buttons      
 
      //keep track of how long the loops take before we go int waiting.      
      unsigned long loopX=elapsedMicroseconds(loopStart);      
      if(loopX>maxLoopLength) maxLoopLength = loopX;      
 
      while (elapsedMicroseconds(loopStart) < (looptime));//wait for the end of a second to arrive      
  }      
 
}       
 
 
char fBuff[7];//used by format      
//format a number into NNN.NN  the number should already be representing thousandths      
char* format(unsigned long num){      
  unsigned long d = 10000;      
  long t;      
  byte dp=3;      
  byte l=6;      
 
  //123456 = 123.46      
  if(num>9999999){      
    d=100000;      
    dp=99;      
    num/=100;      
  }else if(num>999999){      
    dp=4;      
    num/=10;      
  }      
 
  unsigned long val = num/10;      
  if ((num - (val * 10)) >= 5)  //will the first unprinted digit be greater than 4?      
    val += 1;   //round up val      
 
  for(byte x = 0; x < l; x++){      
    if(x==dp)      //time to poke in the decimal point?      
      fBuff[x]='.';      
    else{      
      t = val/d;        
      fBuff[x]= '0' + t%10;//poke the ascii character for the digit.      
      val-= t*d;      
      d/=10;            
    }      
  }      
  fBuff[6]= 0;         //good old zero terminated strings       
  return fBuff;      
}  
 
 
//get a string from flash 
char mBuff[17];//used by getStr 
char * getStr(prog_char * str){ 
  strcpy_P(mBuff, str); 
  return mBuff; 
} 

 

 
 
void doDisplayInstantCurrent(){displayTripCombo('I','M',instant.mpg(),'S',instantmph(),'C','M',current.mpg(),'D',current.miles());}      
 
void doDisplayInstantTank(){displayTripCombo('I','M',instant.mpg(),'S',instantmph(),'T','M',tank.mpg(),'D',tank.miles());}      
 
void doDisplayBigInstant() {bigNum(instant.mpg(),"INST","MPG ");}      
void doDisplayBigCurrent() {bigNum(current.mpg(),"CURR","MPG ");}      
void doDisplayBigTank()    {bigNum(tank.mpg(),"TANK","MPG ");}      
 
void doDisplay2(void){tDisplay(&current);}   //display current trip formatted data.        
void doDisplay3(void){tDisplay(&tank);}      //display tank trip formatted data.        
void doDisplay4(void){rawDisplay(&instant);} //display instant trip "raw" injector and vss data.        
void doDisplay5(void){rawDisplay(&current);} //display current trip "raw" injector and vss data.        
void doDisplay6(void){rawDisplay(&tank);}    //display tank trip "raw" injector and vss data.        
void doDisplay7(void){      
  LCD::gotoXY(0,0);LCD::print("C%");LCD::print(format(maxLoopLength*1000/(looptime/100)));LCD::print(" T"); LCD::print(format(tank.time()));     
  unsigned long mem = memoryTest();      
  mem*=1000;      
  LCD::gotoXY(0,1);LCD::print("FREE MEM: ");LCD::print(format(mem));      
}    //display max cpu utilization and ram.        
 
void displayTripCombo(char t1, char t1L1, unsigned long t1V1, char t1L2, unsigned long t1V2,  char t2, char t2L1, unsigned long t2V1, char t2L2, unsigned long t2V2){ 
  LCD::gotoXY(0,0);LCD::LcdDataWrite(t1);LCD::LcdDataWrite(t1L1);LCD::print(format(t1V1));LCD::LcdDataWrite(' '); 
      LCD::LcdDataWrite(t1L2);LCD::print(format(t1V2)); 
  LCD::gotoXY(0,1);LCD::LcdDataWrite(t2);LCD::LcdDataWrite(t2L1);LCD::print(format(t2V1));LCD::LcdDataWrite(' '); 
      LCD::LcdDataWrite(t2L2);LCD::print(format(t2V2)); 
}      
 
//arduino doesn't do well with types defined in a script as parameters, so have to pass as void * and use -> notation.      
void tDisplay( void * r){ //display trip functions.        
  Trip *t = (Trip *)r;      
  LCD::gotoXY(0,0);LCD::print("MH");LCD::print(format(t->mph()));LCD::print("MG");LCD::print(format(t->mpg()));      
  LCD::gotoXY(0,1);LCD::print("MI");LCD::print(format(t->miles()));LCD::print("GA");LCD::print(format(t->gallons()));      
}      
 
void rawDisplay(void * r){      
  Trip *t = (Trip *)r;      
  LCD::gotoXY(0,0);LCD::print("IJ");LCD::print(format(t->injHiSec*1000));LCD::print("uS");LCD::print(format(t->injHius*1000));      
  LCD::gotoXY(0,1);LCD::print("IC");LCD::print(format(t->injPulses*1000));LCD::print("VC");LCD::print(format(t->vssPulses*1000));      
}      
 
 
    
//x=0..16, y= 0..1      
void LCD::gotoXY(byte x, byte y){      
  byte dr=x+0x80;      
  if (y==1)       
    dr += 0x40;      
  if (y==2)       
    dr += 0x14;      
  if (y==3)       
    dr += 0x54;      
  LCD::LcdCommandWrite(dr);        
}      
 
void LCD::print(char * string){      
  byte x = 0;      
  char c = string[x];      
  while(c != 0){      
    LCD::LcdDataWrite(c);       
    x++;      
    c = string[x];      
  }      
}      
 
 
void LCD::init(){
  delay2(16);                    // wait for more than 15 msec
  pushNibble(B00110000);  // send (B0011) to DB7-4
  cmdWriteSet();
  tickleEnable();
  delay2(5);                     // wait for more than 4.1 msec
  pushNibble(B00110000);  // send (B0011) to DB7-4
  cmdWriteSet();
  tickleEnable();
  delay2(1);                     // wait for more than 100 usec
  pushNibble(B00110000);  // send (B0011) to DB7-4
  cmdWriteSet();
  tickleEnable();
  delay2(1);                     // wait for more than 100 usec
  pushNibble(B00100000);  // send (B0010) to DB7-4 for 4bit
  cmdWriteSet();
  tickleEnable();
  delay2(1);                     // wait for more than 100 usec
  // ready to use normal LcdCommandWrite() function now!
  LcdCommandWrite(B00101000);   // 4-bit interface, 2 display lines, 5x8 font
  LcdCommandWrite(B00001100);   // display control:
  LcdCommandWrite(B00000110);   // entry mode set: increment automatically, no display shift

//creating the custom fonts:
  LcdCommandWrite(B01001000);  // set cgram
  static byte chars[] PROGMEM ={
    B11111,B00000,B11111,B11111,B00000,
    B11111,B00000,B11111,B11111,B00000,
    B11111,B00000,B11111,B11111,B00000,
    B00000,B00000,B00000,B11111,B00000,
    B00000,B00000,B00000,B11111,B00000,
    B00000,B11111,B11111,B11111,B01110,
    B00000,B11111,B11111,B11111,B01110,
    B00000,B11111,B11111,B11111,B01110};

    for(byte x=0;x<5;x++)
      for(byte y=0;y<8;y++)
          LcdDataWrite(pgm_read_byte(&chars[y*5+x])); //write the character data to the character generator ram

  LcdCommandWrite(B00000001);  // clear display, set cursor position to zero
  LcdCommandWrite(B10000000);  // set dram to zero

}

void  LCD::tickleEnable(){       
  // send a pulse to enable       
  digitalWrite(EnablePin,HIGH);       
  delayMicroseconds2(1);  // pause 1 ms according to datasheet       
  digitalWrite(EnablePin,LOW);       
  delayMicroseconds2(1);  // pause 1 ms according to datasheet       
}        
 
void LCD::cmdWriteSet(){       
  digitalWrite(EnablePin,LOW);       
  delayMicroseconds2(1);  // pause 1 ms according to datasheet       
  digitalWrite(DIPin,0);       
}       
 
byte LCD::pushNibble(byte value){       
  digitalWrite(DB7Pin, value & 128);       
  value <<= 1;       
  digitalWrite(DB6Pin, value & 128);       
  value <<= 1;       
  digitalWrite(DB5Pin, value & 128);       
  value <<= 1;       
  digitalWrite(DB4Pin, value & 128);       
  value <<= 1;       
  return value;      
}      
 
void LCD::LcdCommandWrite(byte value){       
  value=pushNibble(value);      
  cmdWriteSet();       
  tickleEnable();       
  value=pushNibble(value);      
  cmdWriteSet();       
  tickleEnable();       
  delay2(5);       
}       
 
void LCD::LcdDataWrite(byte value){       
  digitalWrite(DIPin, HIGH);       
  value=pushNibble(value);      
  tickleEnable();       
  value=pushNibble(value);      
  tickleEnable();       
  delay2(5);       
}       
 
 
 
// this function will return the number of bytes currently free in RAM      
extern int  __bss_end; 
extern int  *__brkval; 
int memoryTest(){ 
  int free_memory; 
  if((int)__brkval == 0) 
    free_memory = ((int)&free_memory) - ((int)&__bss_end); 
  else 
    free_memory = ((int)&free_memory) - ((int)__brkval); 
  return free_memory; 
} 
 
 
Trip::Trip(){      
}      
 
//for display computing
unsigned long tmp1[2];
unsigned long tmp2[2];
unsigned long tmp3[2];

unsigned long instantmph(){      
  cli();
  unsigned long vssPulseTimeuS = (lastVSS1 + lastVSS2) / 2;
  sei();
  init64(tmp1,0,1000000000ul);
  init64(tmp2,0,parms[vssPulsesPerMileIdx]);
  div64(tmp1,tmp2);
  init64(tmp2,0,3600);
  mul64(tmp1,tmp2);
  init64(tmp2,0,vssPulseTimeuS);
  div64(tmp1,tmp2);
  return tmp1[1];
}

unsigned long instantmpg(){      
  cli();
  unsigned long vssPulseTimeuS = (lastVSS1 + lastVSS2) / 2;
  sei();
  init64(tmp1,0,1000000000ul); 
  init64(tmp2,0,parms[vssPulsesPerMileIdx]);
  div64(tmp1,tmp2);
  init64(tmp2,0,3600);
  mul64(tmp1,tmp2);
  init64(tmp2,0,vssPulseTimeuS);
  div64(tmp1,tmp2);
//  return tmp1[1];
  
  
    init64(tmp1,0,instant.injHiSec);
  init64(tmp2,0,1000000);
  mul64(tmp1,tmp2);
  init64(tmp2,0,instant.injHius);
  add64(tmp1,tmp2); 
  init64(tmp2,0,1000);
  mul64(tmp1,tmp2);
  init64(tmp2,0,parms[microSecondsPerGallonIdx]);
  div64(tmp1,tmp2);
  return tmp1[1];      

  
  
}


unsigned long Trip::miles(){      
  init64(tmp1,0,vssPulses);
  init64(tmp2,0,1000);
  mul64(tmp1,tmp2);
  init64(tmp2,0,parms[vssPulsesPerMileIdx]);
  div64(tmp1,tmp2);
  return tmp1[1];      
}      
 
unsigned long Trip::mph(){      
  if(loopCount == 0)     
     return 0;     
  init64(tmp1,0,loopsPerSecond);
  init64(tmp2,0,vssPulses);
  mul64(tmp1,tmp2);
  init64(tmp2,0,3600000);
  mul64(tmp1,tmp2);
  init64(tmp2,0,parms[vssPulsesPerMileIdx]);
  div64(tmp1,tmp2);
  init64(tmp2,0,loopCount);
  div64(tmp1,tmp2);
  return tmp1[1];      
}      
 
unsigned long  Trip::gallons(){      
  init64(tmp1,0,injHiSec);
  init64(tmp2,0,1000000);
  mul64(tmp1,tmp2);
  init64(tmp2,0,injHius);
  add64(tmp1,tmp2);
  init64(tmp2,0,1000);
  mul64(tmp1,tmp2);
  init64(tmp2,0,parms[microSecondsPerGallonIdx]);
  div64(tmp1,tmp2);
  return tmp1[1];      
}      
 
unsigned long  Trip::mpg(){      
  if(vssPulses==0) return 0;      
  if(injPulses==0) return 999999000; //who doesn't like to see 999999?  :)      
 
  init64(tmp1,0,injHiSec);
  init64(tmp3,0,1000000);
  mul64(tmp3,tmp1);
  init64(tmp1,0,injHius);
  add64(tmp3,tmp1);
  init64(tmp1,0,parms[vssPulsesPerMileIdx]);
  mul64(tmp3,tmp1);
 
  init64(tmp1,0,parms[microSecondsPerGallonIdx]);
  init64(tmp2,0,1000);
  mul64(tmp1,tmp2);
  init64(tmp2,0,vssPulses);
  mul64(tmp1,tmp2);
 
  div64(tmp1,tmp3);
  return tmp1[1];      
}      
 
//return the seconds as a time mmm.ss, eventually hhh:mm too      
unsigned long Trip::time(){      
//  return seconds*1000;      
  byte d = 60;      
  unsigned long seconds = loopCount/loopsPerSecond;     
//  if(seconds/60 > 999) d = 3600; //scale up to hours.minutes if we get past 999 minutes      
  return ((seconds/d)*1000) + ((seconds%d) * 10);       
}      
 
 
void Trip::reset(){      
  loopCount=0;      
  injPulses=0;      
  injHius=0;      
  injHiSec=0;      
  vssPulses=0;      
}      
 
void Trip::update(Trip t){     
  loopCount++;  //we call update once per loop     
  vssPulses+=t.vssPulses;      
  if(t.injPulses > 2 && t.injHius<500000){//chasing ghosts      
    injPulses+=t.injPulses;      
    injHius+=t.injHius;      
    if (injHius>=1000000){  //rollover into the injHiSec counter      
      injHiSec++;      
      injHius-=1000000;      
    }      
  }      
}   
 
 
 
 
char bignumchars1[]={4,1,4,0, 1,4,32,0, 3,3,4,0, 1,3,4,0, 4,2,4,0,   4,3,3,0, 4,3,3,0, 1,1,4,0,   4,3,4,0, 4,3,4,0}; 
char bignumchars2[]={4,2,4,0, 2,4,2,0,  4,2,2,0, 2,2,4,0, 32,32,4,0, 2,2,4,0, 4,2,4,0, 32,4,32,0, 4,2,4,0, 2,2,4,0};  
 
void bigNum (unsigned long t, char * txt1, char * txt2){      
//  unsigned long t = 98550ul;//number in thousandths 
//  unsigned long t = 9855ul;//number in thousandths 
//  char * txt1="INST"; 
//  char * txt2="MPG "; 
  char  dp = 32; 
 
  char * r = "009.99"; //"009.99" "000.99" "000.09" 
  if(t<=99500){ 
    r=format(t/10); //009.86 
    dp=5; 
  }else if(t<=999500){ 
    r=format(t/100); //009.86 
  }   
 
  LCD::gotoXY(0,0); 
  LCD::print(bignumchars1+(r[2]-'0')*4); 
  LCD::print(" "); 
  LCD::print(bignumchars1+(r[4]-'0')*4); 
  LCD::print(" "); 
  LCD::print(bignumchars1+(r[5]-'0')*4); 
  LCD::print(" "); 
  LCD::print(txt1); 
 
  LCD::gotoXY(0,1); 
  LCD::print(bignumchars2+(r[2]-'0')*4); 
  LCD::print(" "); 
  LCD::print(bignumchars2+(r[4]-'0')*4); 
  LCD::LcdDataWrite(dp); 
  LCD::print(bignumchars2+(r[5]-'0')*4); 
  LCD::print(" "); 
  LCD::print(txt2); 
}      
 
//the standard 64 bit math brings in  5000+ bytes
//these bring in 1214 bytes, and everything is pass by reference
unsigned long zero64[]={0,0};
 
void init64(unsigned long  an[], unsigned long bigPart, unsigned long littlePart ){
  an[0]=bigPart;
  an[1]=littlePart;
}
 
//left shift 64 bit "number"
void shl64(unsigned long  an[]){
 an[0] <<= 1; 
 if(an[1] & 0x80000000)
   an[0]++; 
 an[1] <<= 1; 
}
 
//right shift 64 bit "number"
void shr64(unsigned long  an[]){
 an[1] >>= 1; 
 if(an[0] & 0x1)
   an[1]+=0x80000000; 
 an[0] >>= 1; 
}
 
//add ann to an
void add64(unsigned long  an[], unsigned long  ann[]){
  an[0]+=ann[0];
  if(an[1] + ann[1] < ann[1])
    an[0]++;
  an[1]+=ann[1];
}
 
//subtract ann from an
void sub64(unsigned long  an[], unsigned long  ann[]){
  an[0]-=ann[0];
  if(an[1] < ann[1]){
    an[0]--;
  }
  an[1]-= ann[1];
}
 
//true if an == ann
boolean eq64(unsigned long  an[], unsigned long  ann[]){
  return (an[0]==ann[0]) && (an[1]==ann[1]);
}
 
//true if an < ann
boolean lt64(unsigned long  an[], unsigned long  ann[]){
  if(an[0]>ann[0]) return false;
  return (an[0]<ann[0]) || (an[1]<ann[1]);
}
 
//divide num by den
void div64(unsigned long num[], unsigned long den[]){
  unsigned long quot[2];
  unsigned long qbit[2];
  unsigned long tmp[2];
  init64(quot,0,0);
  init64(qbit,0,1);
 
  if (eq64(num, zero64)) {  //numerator 0, call it 0
    init64(num,0,0);
    return;        
  }
 
  if (eq64(den, zero64)) { //numerator not zero, denominator 0, infinity in my book.
    init64(num,0xffffffff,0xffffffff);
    return;        
  }
 
  init64(tmp,0x80000000,0);
  while(lt64(den,tmp)){
    shl64(den);
    shl64(qbit);
  } 
 
  while(!eq64(qbit,zero64)){
    if(lt64(den,num) || eq64(den,num)){
      sub64(num,den);
      add64(quot,qbit);
    }
    shr64(den);
    shr64(qbit);
  }
 
  //remainder now in num, but using it to return quotient for now  
  init64(num,quot[0],quot[1]); 
}
 
 
//multiply num by den
void mul64(unsigned long an[], unsigned long ann[]){
  unsigned long p[2] = {0,0};
  unsigned long y[2] = {ann[0], ann[1]};
  while(!eq64(y,zero64)) {
    if(y[1] & 1) 
      add64(p,an);
    shl64(an);
    shr64(y);
  }
  init64(an,p[0],p[1]);
} 
  
void save(){
  EEPROM.write(0,guinosig);
  byte p = 0;
  for(int x=4; p < parmsLength; x+= 4){
    unsigned long v = parms[p];
    EEPROM.write(x ,(v>>24)&255);
    EEPROM.write(x + 1,(v>>16)&255);
    EEPROM.write(x + 2,(v>>8)&255);
    EEPROM.write(x + 3,(v)&255);
    p++;
  }
}

byte load(){ //return 1 if loaded ok
  byte b = EEPROM.read(0);
  if(b == guinosig){
    byte p = 0;

    for(int x=4; p < parmsLength; x+= 4){
      unsigned long v = EEPROM.read(x);
      v = (v << 8) + EEPROM.read(x+1);
      v = (v << 8) + EEPROM.read(x+2);
      v = (v << 8) + EEPROM.read(x+3);
      parms[p]=v;
      p++;
    }
    return 1;
  }
  return 0;
}


char * uformat(unsigned long val){ 
  unsigned long d = 1000000000ul;
  for(byte p = 0; p < 10 ; p++){
    mBuff[p]='0' + (val/d);
    val=val-(val/d*d);
    d/=10;
  }
  mBuff[10]=0;
  return mBuff;
} 

unsigned long rformat(char * val){ 
  unsigned long d = 1000000000ul;
  unsigned long v = 0ul;
  for(byte p = 0; p < 10 ; p++){
    v=v+(d*(val[p]-'0'));
    d/=10;
  }
  return v;
} 



void editParm(byte parmIdx){
  unsigned long v = parms[parmIdx];
  byte p=9;  //right end of 10 digit number
  //display label on top line
  //set cursor visible
  //set pos = 0
  //display v

    LCD::gotoXY(8,0);        
    LCD::print("        ");
    LCD::gotoXY(0,0);        
    LCD::print(parmLabels[parmIdx]);
    LCD::gotoXY(0,1);    
    char * fmtv=    uformat(v);
    LCD::print(fmtv);
    LCD::print(" OK XX");
    LCD::LcdCommandWrite(B00001110);

    for(int x=9 ; x>=0 ;x--){ //do a nice thing and put the cursor at the first non zero number
      if(fmtv[x] != '0')
         p=x; 
    }
  byte keyLock=1;    
  while(true){

    if(p<10)
      LCD::gotoXY(p,1);   
    if(p==10)     
      LCD::gotoXY(11,1);   
    if(p==11)     
      LCD::gotoXY(14,1);   

     if(keyLock == 0){ 
       if(!(buttonState&lbuttonBit)){// left
            p=p-1;
            if(p==255)p=11;
        }else if(!(buttonState&rbuttonBit)){// right
             p=p+1;
            if(p==12)p=0;
        }else if(!(buttonState&mbuttonBit)){// middle
             if(p==11){  //cancel selected
                LCD::LcdCommandWrite(B00001100);
                return;
             }
             if(p==10){  //ok selected
                LCD::LcdCommandWrite(B00001100);
                parms[parmIdx]=rformat(fmtv);
                return;
             }
             
             byte n = fmtv[p]-'0';
             n++;
             if (n > 9) n=0;
             if(p==0 && n > 3) n=0;
             fmtv[p]='0'+ n;
             LCD::gotoXY(0,1);        
             LCD::print(fmtv);
             LCD::gotoXY(p,1);        
             if(parmIdx==contrastIdx)//adjust contrast dynamically
                 analogWrite(ContrastPin,rformat(fmtv));  


        }

      if(buttonState!=buttonsUp)
         keyLock=1;
     }else{
        keyLock=0;
     }
      buttonState=buttonsUp;
      delay2(125);
  }      
  
}

void initGuino(){ //edit all the parameters
  for(int x = 0;x<parmsLength;x++)
    editParm(x);
  save();
  holdDisplay=1;
}  


unsigned long millis2(){
	return timer2_overflow_count * 64UL * 2 / (16000000UL / 128000UL);
}

void delay2(unsigned long ms){
	unsigned long start = millis2();
	while (millis2() - start < ms);
}

/* Delay for the given number of microseconds.  Assumes a 16 MHz clock. 
 * Disables interrupts, which will disrupt the millis2() function if used
 * too frequently. */
void delayMicroseconds2(unsigned int us){
	uint8_t oldSREG;
	if (--us == 0)	return;
	us <<= 2;
	us -= 2;
	oldSREG = SREG;
	cli();
	// busy wait
	__asm__ __volatile__ (
		"1: sbiw %0,1" "\n\t" // 2 cycles
		"brne 1b" : "=w" (us) : "0" (us) // 2 cycles
	);
	// reenable interrupts.
	SREG = oldSREG;
}

void init2(){
	// this needs to be called before setup() or some functions won't
	// work there
	sei();
	
	// timer 0 is used for millis2() and delay2()
	timer2_overflow_count = 0;
	// on the ATmega168, timer 0 is also used for fast hardware pwm
	// (using phase-correct PWM would mean that timer 0 overflowed half as often
	// resulting in different millis2() behavior on the ATmega8 and ATmega168)
        TCCR2A=1<<WGM20|1<<WGM21;
	// set timer 2 prescale factor to 64
        TCCR2B=1<<CS22;


//      TCCR2A=TCCR0A;
//      TCCR2B=TCCR0B;
	// enable timer 2 overflow interrupt
	TIMSK2|=1<<TOIE2;
	// disable timer 0 overflow interrupt
	TIMSK0&=!(1<<TOIE0);
}
