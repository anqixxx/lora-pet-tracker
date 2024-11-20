//LoRa Server Code
//ENPH 479
//2468 LoRa Pet Tracker

#include <SPI.h>

#include <RH_RF95.h> //radio head library

// We need to provide the RFM95 module's chip select and interrupt pins to the 
// rf95 instance below. On the SparkFun ProRF those pins are 12 and 6 respectively.
RH_RF95 rf95(12, 6);
bool messageToSend = false;
String message = "";

int LED = 13; //Status LED on pin 13

int packetCounter = 0; //Counts the number of packets sent
long timeSinceLastPacket = 0; //Tracks the time stamp of last packet received
// The broadcast frequency is set to 921.2, but the SADM21 ProRf operates
// anywhere in the range of 902-928MHz in the Americas.
// Europe operates in the frequencies 863-870, center frequency at 
// 868MHz.This works but it is unknown how well the radio configures to this frequency:
//float frequency = 864.1; //europe
float frequency = 921.2; //americas

void setup()
{
  pinMode(LED, OUTPUT);

  SerialUSB.begin(9600);
  // It may be difficult to read serial messages on startup. The following
  // line will wait for serial to be ready before continuing. Comment out if not needed.
  while(!SerialUSB);
  SerialUSB.println("RFM Server!");

  //Initialize the Radio. 
  if (rf95.init() == false){
    SerialUSB.println("Radio Init Failed - Freezing");
    while (1);
  }
  else{
  // An LED indicator to let us know radio initialization has completed.
    SerialUSB.println("Receiver up!");
    digitalWrite(LED, HIGH);
    delay(500);
    digitalWrite(LED, LOW);
    delay(500);
  }

  rf95.setFrequency(frequency); 

  SerialUSB.println("Type 'n' to activate normal mode.");
  SerialUSB.println("Type 's' to activate search mode.");
  SerialUSB.println("Type 'b' to activate buzzer.");
  SerialUSB.println("Type 'g' to get GPS data.");


 // The default transmitter power is 13dBm, using PA_BOOST.
 // If you are using RFM95/96/97/98 modules which uses the PA_BOOST transmitter pin, then 
 // you can set transmitter powers from 5 to 23 dBm:
 rf95.setTxPower(14, false); //this is from the client code ******
}

void loop()
{
  if (rf95.available()){
    // Should be a message for us now
    uint8_t buf[RH_RF95_MAX_MESSAGE_LEN];
    uint8_t len = sizeof(buf);

    if (rf95.recv(buf, &len)){
      digitalWrite(LED, HIGH); //Turn on status LED
      timeSinceLastPacket = millis(); //Timestamp this packet

      SerialUSB.print("Got message: ");
      SerialUSB.print((char*)buf);
      //SerialUSB.print(" RSSI: ");
      //SerialUSB.print(rf95.lastRssi(), DEC);
      SerialUSB.println();

      // Send a reply
      uint8_t toSend[] = "Hello Back!"; 
      rf95.send(toSend, sizeof(toSend));
      rf95.waitPacketSent();
      SerialUSB.println("Sent a reply");
      digitalWrite(LED, LOW); //Turn off status LED

    }
    else
      SerialUSB.println("Recieve failed");
  }
  //Turn off status LED if we haven't received a packet after 1s
  if(millis() - timeSinceLastPacket > 1000){
    digitalWrite(LED, LOW); //Turn off status LED
    timeSinceLastPacket = millis(); //Don't write LED but every 1s
  }

  if (messageToSend){
    SerialUSB.println("sending message.....");
    uint8_t toSend[4];
    rf95.send(toSend, sizeof(toSend));
    rf95.waitPacketSent();

    //wait for reply
    byte buf[RH_RF95_MAX_MESSAGE_LEN];
    byte len = sizeof(buf);
    if (rf95.waitAvailableTimeout(2000)){
      if (rf95.recv(buf, &len)){
        SerialUSB.print("got reply: ");
        SerialUSB.println((char*)buf);

        uint8_t toSend[] = "ACK"; 
        rf95.send(toSend, sizeof(toSend));
        rf95.waitPacketSent();
      
      } else{
        SerialUSB.println("receiver didn't receive :(");
      }
    } else {
      SerialUSB.println("no reply... is the receiver running?");
    }
    messageToSend = false;

  }

  if (SerialUSB.available() > 0) {
    //check if any commands have been sent
    SerialUSB.println("serial input detected");
    handleSerialCommand();
  }
}

void handleSerialCommand(){
  String serialCommand = SerialUSB.readStringUntil('\n'); // read input until newline
  serialCommand.trim();
  SerialUSB.print("serial data Received: ");
  SerialUSB.println(serialCommand);
  if (serialCommand == "b"){
      message = "buzz";
      messageToSend = true;
      SerialUSB.println("'buzzer' message locked and loaded");
  } else if (serialCommand == "s"){
      message = "search";
      messageToSend = true;
      SerialUSB.println("'search mode' message locked and loaded");
  } else if (serialCommand == "n"){
      message = "normal";
      messageToSend = true;
      SerialUSB.println("'normal mode' message locked and loaded");
  } else if (serialCommand == "g"){
      message = "gps";
      messageToSend = true;
      SerialUSB.println("'gps request' message locked and loaded");
  } else{
      SerialUSB.println("command not recognized");
  }
}

