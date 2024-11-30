#include <Adafruit_GPS.h>
#include <Adafruit_LSM6DSOX.h>
#include <SPI.h>
#include <RH_RF95.h>
#include <Wire.h>
#include <Adafruit_I2CDevice.h>

uint32_t timer = millis();
int period = 30;  // seconds

// LoRa setup
// We need to provide the RFM95 module's chip select and interrupt pins to the
// rf95 instance below.On the SparkFun ProRF those pins are 12 and 6 respectively.
RH_RF95 rf95(12, 6);
int packetCounter = 0;         //Counts the number of packets sent
long timeSinceLastPacket = 0;  //Tracks the time stamp of last packet received
float frequency = 921.2;       //Broadcast frequency
int transmitting = 13;

// GPS setup
Adafruit_GPS GPS(&Wire);
#define GPS_SLEEP_PIN 5

// IMU setup
Adafruit_LSM6DSOX sox;
// Define the interrupt pin (connected to the IMU's interrupt pin)
#define IMU_INT_PIN 4 // ? check pin
// Flag to indicate a wake event
volatile bool wakeEventDetected = false;

// Buzzer setup
#define BUZZER_PIN 2
int buzzLength = 500;

// toggles (should write these states to memory in case node turns off/gets disconnected (same on base side))
bool buzzerToggle = false;
bool searchToggle = false;


void setRanges() {
  // sox.setAccelRange(LSM6DS_ACCEL_RANGE_2_G);
  SerialUSB.print("Accelerometer range set to: ");
  switch (sox.getAccelRange()) {
    case LSM6DS_ACCEL_RANGE_2_G:
      SerialUSB.println("+-2G");
      break;
    case LSM6DS_ACCEL_RANGE_4_G:
      SerialUSB.println("+-4G");
      break;
    case LSM6DS_ACCEL_RANGE_8_G:
      SerialUSB.println("+-8G");
      break;
    case LSM6DS_ACCEL_RANGE_16_G:
      SerialUSB.println("+-16G");
      break;
  }

  // sox.setGyroRange(LSM6DS_GYRO_RANGE_250_DPS );
  SerialUSB.print("Gyro range set to: ");
  switch (sox.getGyroRange()) {
    case LSM6DS_GYRO_RANGE_125_DPS:
      SerialUSB.println("125 degrees/s");
      break;
    case LSM6DS_GYRO_RANGE_250_DPS:
      SerialUSB.println("250 degrees/s");
      break;
    case LSM6DS_GYRO_RANGE_500_DPS:
      SerialUSB.println("500 degrees/s");
      break;
    case LSM6DS_GYRO_RANGE_1000_DPS:
      SerialUSB.println("1000 degrees/s");
      break;
    case LSM6DS_GYRO_RANGE_2000_DPS:
      SerialUSB.println("2000 degrees/s");
      break;
    case ISM330DHCX_GYRO_RANGE_4000_DPS:
      break;  // unsupported range for the DSOX
  }

  // sox.setAccelDataRate(LSM6DS_RATE_12_5_HZ);
  SerialUSB.print("Accelerometer data rate set to: ");
  switch (sox.getAccelDataRate()) {
    case LSM6DS_RATE_SHUTDOWN:
      SerialUSB.println("0 Hz");
      break;
    case LSM6DS_RATE_12_5_HZ:
      SerialUSB.println("12.5 Hz");
      break;
    case LSM6DS_RATE_26_HZ:
      SerialUSB.println("26 Hz");
      break;
    case LSM6DS_RATE_52_HZ:
      SerialUSB.println("52 Hz");
      break;
    case LSM6DS_RATE_104_HZ:
      SerialUSB.println("104 Hz");
      break;
    case LSM6DS_RATE_208_HZ:
      SerialUSB.println("208 Hz");
      break;
    case LSM6DS_RATE_416_HZ:
      SerialUSB.println("416 Hz");
      break;
    case LSM6DS_RATE_833_HZ:
      SerialUSB.println("833 Hz");
      break;
    case LSM6DS_RATE_1_66K_HZ:
      SerialUSB.println("1.66 KHz");
      break;
    case LSM6DS_RATE_3_33K_HZ:
      SerialUSB.println("3.33 KHz");
      break;
    case LSM6DS_RATE_6_66K_HZ:
      SerialUSB.println("6.66 KHz");
      break;
  }

  // sox.setGyroDataRate(LSM6DS_RATE_12_5_HZ);
  SerialUSB.print("Gyro data rate set to: ");
  switch (sox.getGyroDataRate()) {
    case LSM6DS_RATE_SHUTDOWN:
      SerialUSB.println("0 Hz");
      break;
    case LSM6DS_RATE_12_5_HZ:
      SerialUSB.println("12.5 Hz");
      break;
    case LSM6DS_RATE_26_HZ:
      SerialUSB.println("26 Hz");
      break;
    case LSM6DS_RATE_52_HZ:
      SerialUSB.println("52 Hz");
      break;
    case LSM6DS_RATE_104_HZ:
      SerialUSB.println("104 Hz");
      break;
    case LSM6DS_RATE_208_HZ:
      SerialUSB.println("208 Hz");
      break;
    case LSM6DS_RATE_416_HZ:
      SerialUSB.println("416 Hz");
      break;
    case LSM6DS_RATE_833_HZ:
      SerialUSB.println("833 Hz");
      break;
    case LSM6DS_RATE_1_66K_HZ:
      SerialUSB.println("1.66 KHz");
      break;
    case LSM6DS_RATE_3_33K_HZ:
      SerialUSB.println("3.33 KHz");
      break;
    case LSM6DS_RATE_6_66K_HZ:
      SerialUSB.println("6.66 KHz");
      break;
  }
}

void pollIMU(int dataIMU[3][3]) {
  sensors_event_t accel;
  sensors_event_t gyro;
  sensors_event_t temp;
  sox.getEvent(&accel, &gyro, &temp);

  dataIMU[0][0] = temp.temperature;
  /* acceleration is measured in m/s^2 */
  dataIMU[1][0] = accel.acceleration.x;
  dataIMU[1][1] = accel.acceleration.y;
  dataIMU[1][2] = accel.acceleration.z;
  /* rotation is measured in rad/s */
  dataIMU[2][0] = gyro.gyro.x;
  dataIMU[2][1] = gyro.gyro.x;
  dataIMU[2][2] = gyro.gyro.x;
}

uint8_t* getGPS() {
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

  uint8_t dataGPS[16];

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
  // dataGPS[15] = (lat << 1) | lon; // most of the byte will be 0
  dataGPS[15] = 100;  // battery status

  return dataGPS;
}

void buzz() {
  uint32_t buzzTimer = millis();
  while (millis() - buzzTimer < buzzLength) {
    digitalWrite(BUZZER_PIN, HIGH);
    delayMicroseconds(500);
    digitalWrite(BUZZER_PIN, LOW);
    delayMicroseconds(500);
  }
}

bool sendSingleGPS(int timeout = 2000) {
  uint8_t* toSend = getGPS();
  digitalWrite(transmitting, HIGH);
  rf95.send(toSend, sizeof(toSend));
  rf95.waitPacketSent();
  SerialUSB.println("Sent");
  digitalWrite(transmitting, LOW);

  // wait for ack
  uint8_t buf[RH_RF95_MAX_MESSAGE_LEN];
  uint8_t len = sizeof(buf);

  if (rf95.waitAvailableTimeout(timeout)) {
    if (rf95.recv(buf, &len)) {
      SerialUSB.print("Got reply: ");
      SerialUSB.println((char*)buf);
      if ((char*)buf == "ACK") {
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

void parseMessage(int messageID) {
  switch (messageID) {
    case 0:  // buzz
      buzzerToggle = !buzzerToggle;
      break;
    case 1:  // toggle frequency
      searchToggle = !searchToggle;
      break;
    case 2:  // send 1000 gps (1 for now)
      // move this stuff to function so we don't have to repeat it
      bool sent = sendSingleGPS();
      while (!sent) {
        SerialUSB.println("Retransmitting...");
        sent = sendSingleGPS();
      }
      break;
      // case 3: // change SF and BW

      //   break;
  }
}

void handleWakeInterrupt() {
  wakeEventDetected = true;
}


void setup() {
  pinMode(BUZZER_PIN, OUTPUT);

  while (!SerialUSB);

  SerialUSB.begin(115200);
  SerialUSB.println("Starting setup...");

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
  if (!sox.begin_I2C(0x6B)) {
    SerialUSB.println("Failed to find LSM6DSOX chip");
    while (1) {
      delay(10);
    }
  }
  SerialUSB.println("LSM6DSOX Found!");
  setRanges();
  uint8_t duration = 50;
  uint8_t thresh = 5;   // Example threshold (adjust as needed)
  sox.enableWakeup(true, duration, thresh);
  // Configure the interrupt pin
  pinMode(IMU_INT_PIN, INPUT);
  // Attach the interrupt
  attachInterrupt(digitalPinToInterrupt(IMU_INT_PIN), handleWakeInterrupt, RISING);

  //LoRa setup
  pinMode(transmitting, OUTPUT);
  if (rf95.init() == false) {
    SerialUSB.println("Radio Init Failed - Freezing");
    while (1)
      ;
  } else {
    //An LED inidicator to let us know radio initialization has completed.
    SerialUSB.println("Transmitter up!");
    digitalWrite(transmitting, HIGH);
    delay(500);
    digitalWrite(transmitting, LOW);
    delay(500);
  }

  rf95.setFrequency(frequency);
  rf95.setTxPower(14, false);

  delay(1000);
}


void loop() {
  // Check if the interrupt detected a wake event
  if (wakeEventDetected) {
    wakeEventDetected = false; // Clear the flag

    // Verify the wake event using the `awake()` function
    if (sox.awake()) {
      SerialUSB.println("Wake event detected!");
      // Perform additional actions here
        int dataIMU[3][3] = {};
        pollIMU(dataIMU);
        SerialUSB.println(dataIMU[0][0]);
    }
  }

  if (rf95.available()) {
    uint8_t buf[RH_RF95_MAX_MESSAGE_LEN];
    uint8_t len = sizeof(buf);

    if (rf95.recv(buf, &len)){
      timeSinceLastPacket = millis(); //Timestamp this packet/
      SerialUSB.print("Got message: ");
      SerialUSB.print((char*)buf);
      SerialUSB.println();

      // Send a reply
      digitalWrite(transmitting, HIGH);
      uint8_t toSend[] = "ACK"; 
      rf95.send(toSend, sizeof(toSend));
      rf95.waitPacketSent();
      digitalWrite(transmitting, LOW);

      parseMessage(buf[0]);
    } else {
      SerialUSB.println("Recieve failed");
    }
  }

  if (millis() - timer > ((period - 20 * searchToggle) * 1000)) {
    timer = millis();  // reset the timer

    if (buzzerToggle) buzz();

    bool sent = sendSingleGPS();
    while (!sent) {
      SerialUSB.println("Retransmitting...");
      sent = sendSingleGPS();
    }
  }
}