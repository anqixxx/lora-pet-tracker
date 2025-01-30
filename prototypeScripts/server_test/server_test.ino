//LoRa Server Code
//ENPH 479
//2468 LoRa Pet Tracker

#include <SPI.h>
#include <RH_RF95.h> //radio head library

// We need to provide the RFM95 module's chip select and interrupt pins to the 
// rf95 instance below. On the SparkFun ProRF those pins are 12 and 6 respectively.
RH_RF95 rf95(12, 6);
bool messageToSend = false;
uint8_t message[2];

int LED = 13; //Status LED on pin 13

int packetCounter = 0; //Counts the number of packets sent
long timeSinceLastPacket = 0; //Tracks the time stamp of last packet received
// The broadcast frequency is set to 921.2, but the SADM21 ProRf operates
// anywhere in the range of 902-928MHz in the Americas.
// Europe operates in the frequencies 863-870, center frequency at 
// 868MHz.This works but it is unknown how well the radio configures to this frequency:
//float frequency = 864.1; //europe
float frequency = 921.2; //americas

volatile int messageID = 0;


void handleSerialCommand(){
  String serialCommand = SerialUSB.readStringUntil('\n'); // read input until newline
  serialCommand.trim();
  SerialUSB.print("Serial Data Received: ");
  SerialUSB.println(serialCommand);
  if (serialCommand == "b"){
      message[0] = messageID;
      message[1] = 0;
      messageToSend = true;
      SerialUSB.println("'buzzer' message locked and loaded");
  } else if (serialCommand == "s"){
      message[0] = messageID;
      message[1] = 1;
      messageToSend = true;
      SerialUSB.println("'search mode toggle' message locked and loaded");
  } else if (serialCommand == "g"){
      message[0] = messageID;
      message[1] = 2;
      messageToSend = true;
      SerialUSB.println("'gps request' message locked and loaded");
  }
  else if (serialCommand == "l"){ // battery level request
      message[0] = messageID;
      message[1] = 3;
      messageToSend = true;
      SerialUSB.println("'battery request' message locked and loaded");
  }
   else{
      SerialUSB.println("command not recognized");
  }
}

bool sendACK() {
  digitalWrite(LED, HIGH);
  uint8_t toSend[] = {messageID, 4}; 
  rf95.send(toSend, sizeof(toSend));
  rf95.waitPacketSent();
  SerialUSB.println("Sent ACK");
  digitalWrite(LED, LOW);

  messageID++;

  return true;
}

bool waitForACK() {
  uint8_t buf[RH_RF95_MAX_MESSAGE_LEN];
  uint8_t len = sizeof(buf);

  if (rf95.waitAvailableTimeout(2000)) {
    if (rf95.recv(buf, &len)) {
      SerialUSB.print("Got reply: ");
      SerialUSB.print(buf[0]);
      SerialUSB.println(buf[1]);
      if (buf[1] == 4) {
        SerialUSB.println("Success: Got ACK");
        return true;
      }
      return false;
    } else {
      SerialUSB.println("Receive failed");
      return false;
    }
  } else {
    SerialUSB.println("No reply");
    return false;
  }
}

void setup()
{
  pinMode(LED, OUTPUT);

  while(!SerialUSB);
  SerialUSB.begin(115200);

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
  rf95.setTxPower(14, false); 

  SerialUSB.println("Type 's' to toggle search mode.");
  SerialUSB.println("Type 'b' to toggle buzzer.");
  SerialUSB.println("Type 'g' to get GPS data.");
  SerialUSB.println("Type 'l' to get battery level.");
}

void loop()
{
  if (rf95.available()){
    // Should be a message for us now
    uint8_t buf[RH_RF95_MAX_MESSAGE_LEN];
    uint8_t len = sizeof(buf);

    if (rf95.recv(buf, &len)){
      digitalWrite(LED, HIGH); // Turn on status LED
      timeSinceLastPacket = millis(); // Timestamp this packet

      SerialUSB.print("Got message: ");
      // SerialUSB.print((char*)buf);
      if (buf[1] == 5){ // Recieving 1 GPS Reading
        for (int i = 0; i < 18; i++)
        {
          SerialUSB.print(buf[i]);
          SerialUSB.print(" ");
        }
      }
      else { // Control Sequence, TBI
        for (uint8_t x:buf){
          SerialUSB.print(x);
          SerialUSB.print(" ");
        }
      }
      SerialUSB.println();

      sendACK();
    }
    else
      SerialUSB.println("Recieve failed"); // Should we do something here if it doesn't work?
  }
  //Turn off status LED if we haven't received a packet after 1s
  if(millis() - timeSinceLastPacket > 1000){
    digitalWrite(LED, LOW); //Turn off status LED
    timeSinceLastPacket = millis(); //Don't write LED but every 1s
  }

  if (messageToSend){
    SerialUSB.println("sending message.....");
    rf95.send(message, sizeof(message));
    rf95.waitPacketSent();

    messageToSend = !waitForACK();
    messageID++;
  }

  if (SerialUSB.available() > 0) {
    //check if any commands have been sent
    SerialUSB.println("serial input detected");
    handleSerialCommand();
  }

  // Check if any commands from database, maybe check for internet connection on our end
  // Encode that
}

