//LoRa Server Code
//ENPH 479
//2468 LoRa Pet Tracker

#include <SPI.h>
#include <RH_RF95.h> //radio head library

// Define our Message Types
const uint8_t ACK = 0;
const uint8_t SEND_GPS = 1;
const uint8_t REQUEST_GPS = 2;
const uint8_t MODE_TOGGLE = 3;
const uint8_t SPEAKER_ON = 4;
const uint8_t SPEAKER_OFF = 5;
const uint8_t SEND_BATTERY = 6;
const uint8_t REQUEST_BATTERY = 7;
const uint8_t SLEEP = 8;

// We need to provide the RFM95 module's chip select and interrupt pins to the 
// rf95 instance below. On the SparkFun ProRF those pins are 12 and 6 respectively.
RH_RF95 rf95(12, 6);
bool messageToSend = false;
uint8_t message[2];
int LED = 13; // Status LED on pin 13

int packetCounter = 0; //Counts the number of packets sent
long timeSinceLastPacket = 0; //Tracks the time stamp of last packet received
// The broadcast frequency is set to 921.2, but the SADM21 ProRf operates
// anywhere in the range of 902-928MHz in the Americas.
// Europe operates in the frequencies 863-870, center frequency at 
// 868MHz.This works but it is unknown how well the radio configures to this frequency:
//float frequency = 864.1; //europe
float frequency = 912.5; //americas

volatile int messageID = 0;

void sendSerialData(uint8_t message_type, uint8_t* message){
  if (message_type == SEND_GPS){ // Recieving 1 GPS Reading and 1 Battery Level
    SerialUSB.print("SEND_GPS_LAT ");
    SerialUSB.print(message[9]);
    SerialUSB.print('.');
    for (int i = 10; i < 13; i++) // 9 to 16 inclusive is gps, 17 is battery
    {
      // 8 gps coordinates in total, first 4 are lattitude, last 4 are degrees
      SerialUSB.print(message[i]);
    }

    SerialUSB.print("SEND_GPS_LONG ");
    SerialUSB.print(message[13]);
    SerialUSB.print('.');
    for (int i = 14; i < 17; i++) // 9 to 16 inclusive is gps, 17 is battery
    {
      // 8 gps coordinates in total, first 4 are lattitude, last 4 are degrees
      SerialUSB.print(message[i]);
    }

    SerialUSB.println();
    SerialUSB.print("SEND_BATTERY ");
    SerialUSB.print(message[17]);
  }
  else if (message_type == SEND_BATTERY){ // Rec  ieving 1 Battery
    SerialUSB.print("SEND_BATTERY ");
    SerialUSB.print(message[1]); // Double check this
  }
  else if (message_type == SLEEP){ // Sleep Mode on
    SerialUSB.print("SLEEP");
  }
  else {
    SerialUSB.print("Unidentified Message Type: ");

    for (int i = 0; i < RH_RF95_MAX_MESSAGE_LEN; i++){
      SerialUSB.print(message[i]);
      SerialUSB.print(" ");
    }
  }

  SerialUSB.println();
  sendACK();
}

void handleSerialCommand(){
  // we want to get all requests
  String serialCommand = SerialUSB.readStringUntil('\n'); // read input until newline
  serialCommand.trim();
  SerialUSB.print("Serial Data Received: ");
  SerialUSB.println(serialCommand);

  if (serialCommand == "buzzer_on"){
      message[0] = messageID;
      message[1] = SPEAKER_ON; // buzzer
      messageToSend = true;
      SerialUSB.println("'Buzzer on'  message locked and loaded");
  }
  else if (serialCommand == "buzzer_off"){
        message[0] = messageID;
        message[1] = SPEAKER_OFF; // buzzer
        messageToSend = true;
        SerialUSB.println("'Buzzer off'  message locked and loaded");
  } else if (serialCommand == "mode"){
      message[0] = messageID;
      message[1] = MODE_TOGGLE;
      messageToSend = true;
      SerialUSB.println("'search mode toggle' message locked and loaded");
  } else if (serialCommand == "gps"){
      message[0] = messageID;
      message[1] = REQUEST_GPS;
      messageToSend = true;
      SerialUSB.println("'gps request' message locked and loaded");
  }
  else if (serialCommand == "battery"){ // battery level request
      message[0] = messageID;
      message[1] = REQUEST_BATTERY;
      messageToSend = true;
      SerialUSB.println("'battery request' message locked and loaded");
  }
   else{
      SerialUSB.println("command not recognized");
  }
}

bool sendACK() {
  digitalWrite(LED, HIGH);
  uint8_t toSend[] = {messageID, ACK}; 
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
      if (buf[1] == ACK) {
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
  // rf95.setSpreadingFactor(9); // To match node

  rf95.setSpreadingFactor(12); // for testing

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

  SerialUSB.println("Type 'mode' to toggle mode.");
  SerialUSB.println("Type 'speaker' to toggle speaker.");
  SerialUSB.println("Type 'gps' to get GPS data.");
  SerialUSB.println("Type 'battery' to get battery level.");
  SerialUSB.println("Type 'sleep' to test sleep mode.");

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

      sendSerialData(buf[1], buf);
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

