#include "BluetoothSerial.h"
#include "pins_arduino.h"
#include "SPI.h"
char buf [100];
volatile byte pos;
volatile boolean process_it;

#define RXD2 16
#define TXD2 17
#define CLK 14
#define MISO 12
#define MOSI 13
#define SS 15

#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth is not enabled! Please run `make menuconfig` to and enable it
#endif

BluetoothSerial SerialBT;
int received;// received value will be stored in this variable
char receivedChar;// received value will be stored as CHAR in this variable

int timedelay = 100;

const char POWER ='P';
const char NONVAC ='N';
const char DRYING ='D';
const char VAC ='B';
const char START ='S';
const char DOOR ='a';
const int POWERpin = 2;
const int VACpin = 4;
const int DRYINGpin = 19;
const int NONVACpin = 0;
const int STARTpin = 21;
const int DOORpin = 5;

void setup(void) {
  Serial.begin(115200);
  Serial2.begin(9600, SERIAL_8N1, RXD2, TXD2);
  SerialBT.begin("Adv Pro - 18102301"); //Bluetooth device name
  Serial.println("The device started, now you can pair it with bluetooth!");

  //SPI.begin(CLK, MISO, MOSI, SS);
  // have to send on master in, slave out
  pinMode(MISO, OUTPUT);
 
  // turn on SPI in slave mode
  SPCR |= _BV(SPE);
 
  // turn on interrupts
  SPCR |= _BV(SPIE);
 
  pos = 0;
  process_it = false;
  
  pinMode(POWERpin, OUTPUT);
  pinMode(NONVACpin, OUTPUT);
  pinMode(DRYINGpin, OUTPUT);
  pinMode(VACpin, OUTPUT);
  pinMode(STARTpin, OUTPUT);
  pinMode(DOORpin, OUTPUT);
}

// SPI interrupt routine
void ISR(void)
{
byte c = SPDR;
 
  // add to buffer if room
  if (pos < sizeof buf)
    {
    buf [pos++] = c;
   
    // example: newline means time to process buffer
    if (c == '\n')
      process_it = true;
     
    }  // end of room available
}

// main loop - wait for flag set in interrupt routine
void loop(void) {
    receivedChar =(char)SerialBT.read();

  if (Serial.available()) {
    SerialBT.write(Serial.read());
  }
  
  if (SerialBT.available()) {
    
    SerialBT.print("Received:");// write on BT app
    SerialBT.println(receivedChar);// write on BT app      indented items are commented recently
    Serial.print ("Received:");//print on serial monitor
    Serial.println(receivedChar);//print on serial monitor    
    //SerialBT.println(receivedChar);//print on the app    
    //SerialBT.write(receivedChar); //print on serial monitor
    
    if(receivedChar == POWER)
    {
      //SerialBT.println("POWER ON:");// write on BT app
      //Serial.println("POWER ON:");//write on serial monitor
     Serial2.write(0x09); //print to UART2 (control board)
     digitalWrite(POWERpin, HIGH);// turn the LED ON
     delay(timedelay);
     Serial2.write(0x19); //print to UART2 (control board)
     digitalWrite(POWERpin, LOW);// turn the LED OFF  
    }
    
    if(receivedChar == VAC)
    {
      //SerialBT.println("VAC ON:");// write on BT app
      //Serial.println("VAC ON:");//write on serial monitor
     Serial2.write(0x0A); //print to UART2 (control board)
     digitalWrite(VACpin, HIGH);// turn the LED ON
     delay(timedelay);
     Serial2.write(0x1A); //print to UART2 (control board)
     digitalWrite(VACpin, LOW);// turn the LED OFF
    }
    
    if(receivedChar == DRYING)
    {
      //SerialBT.println("DRYING ON:");// write on BT app
      //Serial.println("DRYING ON:");//write on serial monitor
     Serial2.write(0x0B); //print to UART2 (control board)
     digitalWrite(DRYINGpin, HIGH);// turn the LED ON
     delay(timedelay);
     Serial2.write(0x1B); //print to UART2 (control board)
     digitalWrite(DRYINGpin, LOW);// turn the LED OFF   
    }
    
    if(receivedChar == NONVAC)
    {
      //SerialBT.println("NONVAC ON:");// write on BT app
      //Serial.println("NONVAC ON:");//write on serial monitor
     Serial2.write(0x0C); //print to UART2 (control board)
     digitalWrite(NONVACpin, HIGH);// turn the LED ON
     delay(timedelay);
     Serial2.write(0x1C); //print to UART2 (control board)
     digitalWrite(NONVACpin, LOW);// turn the LED OFF
    }
    
    if(receivedChar == START)
    {
      //SerialBT.println("START ON:");// write on BT app
      //Serial.println("START ON:");//write on serial monitor
     Serial2.write(0x0D); //print to UART2 (control board)
     digitalWrite(STARTpin, HIGH);// turn the LED ON
     delay(timedelay);
     Serial2.write(0x1D); //print to UART2 (control board)
     digitalWrite(STARTpin, LOW);// turn the LED OFF  
    }
    
    if(receivedChar == DOOR)
    {
      //SerialBT.println("DOOR ON:");// write on BT app
      //Serial.println("DOOR ON:");//write on serial monitor
     Serial2.write(0x0E); //print to UART2 (control board)
     digitalWrite(DOORpin, HIGH);// turn the LED ON
     delay(timedelay);
     Serial2.write(0x1E); //print to UART2 (control board)
     digitalWrite(DOORpin, LOW);// turn the LED OFF
    }  
  }

  if (process_it)
    {
    buf [pos] = 0;  
    Serial.println (buf);
    pos = 0;
    process_it = false;
    }  // end of flag set
  
  delay(20);
}
