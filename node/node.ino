//LoRa Node Code
//ENPH 479
//2468 LoRa Pet Tracker

#include <Adafruit_GPS.h>
#include <SPI.h>
#include <RH_RF95.h>
#include <Wire.h>
#include <Adafruit_I2CDevice.h>
#include <LSM6DS.h>

const uint8_t ACK = 0;
const uint8_t SEND_GPS = 1;
const uint8_t REQUEST_GPS = 2;
const uint8_t MODE_TOGGLE = 3;
const uint8_t SPEAKER_ON = 4;
const uint8_t SPEAKER_OFF = 5;
const uint8_t SEND_BATTERY = 6;
const uint8_t REQUEST_BATTERY = 7;
const uint8_t SLEEP = 8;

uint32_t timer = millis();
int period = 30;  // 5 minutes

// LoRa setup
// We need to provide the RFM95 module's chip select and interrupt pins to the
// rf95 instance below.On the SparkFun ProRF those pins are 12 and 6 respectively.
RH_RF95 rf95(12, 6);

int packetCounter = 0;         //Counts the number of packets sent
long timeSinceLastPacket = 0;  //Tracks the time stamp of last packet received
float frequency = 902.5;       //Broadcast frequency
int TX_PIN = 13;

volatile int messageID = 0;

// GPS setup
Adafruit_GPS GPS(&Wire);
#define GPS_SLEEP_PIN 5
#define GPS_SIZE 16

// IMU setup
LSM6DS sox;
// Define the interrupt pin (connected to the IMU's interrupt pin)
// #define IMU_INT_PIN 4 // ? check pin
// // Flag to indicate a wake event ""
// volatile bool activityEventDetected = false;

// Buzzer setup
#define BUZZER_PIN 2
int buzzLength = 800;

// toggles (should write these states to memory in case node turns off/gets disconnected (same on base side))
bool buzzerToggle = false;
bool searchToggle = false;
bool sleep = false;

void pollIMU(int dataIMU[3][3]) {
  sensors_event_t accel;
  sensors_event_t temp;
  sox.getEvent(&accel, &temp);

  dataIMU[0][0] = temp.temperature;
  /* acceleration is measured in m/s^2 */
  dataIMU[1][0] = accel.acceleration.x;
  dataIMU[1][1] = accel.acceleration.y;
  dataIMU[1][2] = accel.acceleration.z;
}
// message datatype
// uint8_t message{
//   uint8_t messageID;
//   uint8_t messageType;}
// arr[0]
// message.type()
void getGPS(uint8_t dataGPS[]) {
  // wake up gps
  digitalWrite(GPS_SLEEP_PIN, HIGH);
  // wait for fix (but don't actually)

  // const char *wait = "$GPRMC";
  // if (GPS.waitForSentence(wait))
  const char* wait = "$GNRMC";
  while (!GPS.waitForSentence(wait)) {}
  while (!GPS.parse(GPS.lastNMEA())) {  // NMEA sentence may start correctly but be truncated due to corrupted data
    while (!GPS.waitForSentence(wait)) {}
  }

  // put GPS back to sleep
  digitalWrite(GPS_SLEEP_PIN, LOW);
  GPS.sendCommand("$PMTK225,4*2F");

  uint8_t lat = (GPS.lat == 'S');  // 0 if N, 1 if S
  uint8_t lon = (GPS.lon == 'W');  // 0 if E, 1 if W

  // uint8_t dataGPS[GPS_SIZE];

  // format gps data
  dataGPS[0] = 20;
  dataGPS[1] = GPS.year;
  dataGPS[2] = GPS.month;
  dataGPS[3] = GPS.day;
  dataGPS[4] = GPS.hour;
  dataGPS[5] = GPS.minute;
  dataGPS[6] = GPS.seconds;
  dataGPS[7] = (int(GPS.latitudeDegrees) << 7) | lat;
  uint32_t latDD = int(GPS.latitudeDegrees * 1000000) % 1000000;  // fractional degrees (up to 20 bits), 6 digits
  dataGPS[8] = (latDD >> 16) & 0xFF;
  dataGPS[9] = (latDD >> 8) & 0xFF;
  dataGPS[10] = latDD & 0xFF;
  dataGPS[11] = (int(GPS.longitudeDegrees) << 7) | lon;
  uint32_t lonDD = int(GPS.longitudeDegrees * 1000000) % 1000000;  // fractional degrees (up to 20 bits), 6 digits
  dataGPS[12] = (lonDD >> 16) & 0xFF; 
  dataGPS[13] = (lonDD >> 8) & 0xFF;
  dataGPS[14] = lonDD & 0xFF;
  dataGPS[15] = 100;  // battery status
}

void buzz() {
  uint32_t buzzTimer = millis();
  digitalWrite(BUZZER_PIN, HIGH);
  delayMicroseconds(500);
  digitalWrite(BUZZER_PIN, LOW);
  delayMicroseconds(500);
}

bool sendSingleBattery(int timeout = 2000) {
  uint8_t message[3];
  message[0] = messageID;
  message[1] = SEND_BATTERY;
  message[2] = 52; // dummy value for now

  rf95.send(message, 3);
  rf95.waitPacketSent();
  // SerialUSB.print("Sent: ");
  // for (uint8_t x : message) {
  //   SerialUSB.print(x);
  //   SerialUSB.print(' ');
  // }
  // SerialUSB.println();
  digitalWrite(TX_PIN, LOW);

  messageID++;

  return waitForACK();
}

bool sendSingleGPS(int timeout = 2000) {
  uint8_t message[18];
  message[0] = messageID;
  message[1] = SEND_GPS;
  uint8_t dataGPS[GPS_SIZE];
  getGPS(dataGPS);
  memcpy(&message[2], dataGPS, GPS_SIZE);
  digitalWrite(TX_PIN, HIGH);
  rf95.send(message, 18);
  rf95.waitPacketSent();
  // SerialUSB.print("Sent: ");
  // for (uint8_t x : message) {
  //   SerialUSB.print(x);
  //   SerialUSB.print(' ');
  // }
  // SerialUSB.println();
  digitalWrite(TX_PIN, LOW);

  messageID++;

  return waitForACK();
}

bool sendSleep(int timeout = 2000) {
  uint8_t message[2];
  message[0] = messageID;
  message[1] = SLEEP;
  message[2] = sleep ? 1 : 0; // convert bool to uint8_t

  digitalWrite(TX_PIN, HIGH);
  rf95.send(message, 2);
  rf95.waitPacketSent();
  // SerialUSB.print("Sent: ");
  // for (uint8_t x : message) {
  //   SerialUSB.print(x);
  //   SerialUSB.print(' ');
  // }
  // SerialUSB.println();
  digitalWrite(TX_PIN, LOW);

  messageID++;

  return waitForACK();
}

void parseMessage(int messageType) {
  if (messageType == SPEAKER_ON || messageType == SPEAKER_OFF){
    // SerialUSB.println("Buzz");
    buzzerToggle = !buzzerToggle;
  } else if (messageType == MODE_TOGGLE){
    // SerialUSB.println("Toggle mode");
    searchToggle = !searchToggle;
    // Set Tx Power and SF based on mode
    int new_tx;
    int new_sf;
    int old_sf;
    if (searchToggle) {
      new_tx = 22; // max power
      new_sf = 12;
      old_sf = 9;
    } else {
      new_tx = 17; // normal power
      new_sf = 9;
      old_sf = 12;
    }
    rf95.setTxPower(new_tx, false); // normal power
    rf95.setSpreadingFactor(new_sf);
    delay(10); // just to make sure base has enough time to change sf
    sendACK(); // let base station know sf has changed
    // can assume that if we got command from base, we are still in range for base to get ack
    // if(!waitForACK()) { // wait to make sure base station sf has changed
    //   rf95.setSpreadingFactor(old_sf); // revert spread factor if no ack received
    // }
  } else if (messageType == REQUEST_GPS){
    // SerialUSB.println("Send GPS");
    bool sent = sendSingleGPS();
    int i = 1;
    while (!sent) {
      // SerialUSB.println("Retransmitting...");
      // SerialUSB.println(i);
      sent = sendSingleGPS(i);
      i++;
  }
  }  else if (messageType == REQUEST_BATTERY){
    // SerialUSB.println("Send Battery");
    // move this stuff to function so we don't have to repeat it
    // delay(500);
    bool sent = sendSingleBattery();
    int i = 1;
    while (!sent) {
      // SerialUSB.println("Retransmitting...");
      // SerialUSB.println(i);
      sent = sendSingleBattery(i);
      i++;
  }
  }
}

bool sendACK() {
  digitalWrite(TX_PIN, HIGH);
  uint8_t toSend[] = {messageID, ACK}; 
  rf95.send(toSend, sizeof(toSend));
  rf95.waitPacketSent();
  // SerialUSB.println("Sent ACK");
  digitalWrite(TX_PIN, LOW);

  messageID++;

  return true;
}

bool waitForACK() {
  uint8_t buf[RH_RF95_MAX_MESSAGE_LEN];
  uint8_t len = sizeof(buf);

  if (rf95.waitAvailableTimeout(2000)) {
    if (rf95.recv(buf, &len)) {
      // SerialUSB.print("Got reply: ");
      // SerialUSB.print(buf[0]);
      // SerialUSB.println(buf[1]);
      if (buf[1] == ACK) {
        // SerialUSB.println("Success: Got ACK");
        return true;
      }
      return false;
    } else {
      // SerialUSB.println("Receive failed");
      return false;
    }
  } else {
    // SerialUSB.println("No reply");
    return false;
  }
}

void setup() {
  pinMode(BUZZER_PIN, OUTPUT);

  // while (!SerialUSB);

  // SerialUSB.begin(115200);
  // SerialUSB.println("Starting setup...");

  // GPS setup
  pinMode(GPS_SLEEP_PIN, OUTPUT);
  digitalWrite(GPS_SLEEP_PIN, HIGH);
  GPS.begin(9600);
  GPS.sendCommand(PMTK_SET_NMEA_OUTPUT_RMCGGA);
  GPS.sendCommand(PMTK_SET_NMEA_UPDATE_1HZ);  // 1 Hz update rate
  GPS.sendCommand(PGCMD_ANTENNA);
  digitalWrite(GPS_SLEEP_PIN, LOW);
  GPS.sendCommand("$PMTK225,4*2F");

  // IMU setup
  if (!sox.begin_I2C()) {
    // SerialUSB.println("Failed to find LSM6DSOX chip");
    while (1) {
      delay(10);
    }
  }
  // SerialUSB.println("LSM6DSOX Found!");
  sox.setAccelDataRate(LSM6DS_RATE_12_5_HZ);
  uint8_t wakeup_duration = 1;
  uint8_t thresh = 2;   // Example threshold (adjust as needed)
  uint8_t sleep_duration = 1;
  sox.enableActivityInactivity(true, true, wakeup_duration, thresh, sleep_duration, false);
  sox.configInt1(false, false, false, false, true);
  // Configure the interrupt pin
  // pinMode(IMU_INT_PIN, INPUT);
  // Attach the interrupt
  // attachInterrupt(digitalPinToInterrupt(IMU_INT_PIN), handleActivityInterrupt, CHANGE);

  //LoRa setup
  pinMode(TX_PIN, OUTPUT);
  if (rf95.init() == false) {
    // SerialUSB.println("Radio Init Failed - Freezing");
    while (1);
  } else {
    //An LED inidicator to let us know radio initialization has completed.
    // SerialUSB.println("Transmitter up!");
    digitalWrite(TX_PIN, HIGH);
    delay(500);
    digitalWrite(TX_PIN, LOW);
    delay(500);
  }

  rf95.setFrequency(frequency);
  rf95.setTxPower(22, false);
  rf95.setSpreadingFactor(9);

  delay(1000);
}


void loop() {
  if (millis() - timer > ((period - (4*60*searchToggle)) * 1000)) {
  // Verify the activity status using the 'activityStatus()` function, can also read pin 
    if (!sox.activityStatus()){ // if active

      timer = millis();  // reset the timer

      bool sent = sendSingleGPS();
      int i = 1;
      while (!sent) {
        // SerialUSB.println("Retransmitting...");
        // SerialUSB.println(i);
        sent = sendSingleGPS(i);
        i++;
      }

      if (sleep) {
        sendSleep();
        sleep = !sleep;
      }
    } else {
      if (!sleep) {
        // SerialUSB.println("Sleeping...");
        sendSleep();
        sleep = !sleep;
      }
    } 
  }

  if (rf95.available()) {
    uint8_t buf[RH_RF95_MAX_MESSAGE_LEN];
    uint8_t len = sizeof(buf);

    if (rf95.recv(buf, &len)){
      // timeSinceLastPacket = millis(); //Timestamp this packet/
      // SerialUSB.print("Got message: ");
      // SerialUSB.print(buf[0]);
      // SerialUSB.print(buf[1]);
      // SerialUSB.println();

      sendACK();

      parseMessage(buf[1]);
    } else {
      // SerialUSB.println("Recieve failed");
    }
  }

  if (buzzerToggle) {
    buzz();
  }

  
}