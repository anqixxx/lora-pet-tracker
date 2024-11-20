#include <Adafruit_GPS.h>
#include <Adafruit_LSM6DSOX.h>
#include <SPI.h>
#include <RH_RF95.h> 

uint32_t timer = millis();
int freq = 30; // seconds

// LoRa setup
// We need to provide the RFM95 module's chip select and interrupt pins to the
// rf95 instance below.On the SparkFun ProRF those pins are 12 and 6 respectively.
RH_RF95 rf95(12, 6);
int packetCounter = 0; //Counts the number of packets sent
long timeSinceLastPacket = 0; //Tracks the time stamp of last packet received
float frequency = 921.2; //Broadcast frequency
int transmitting = 13;

// GPS setup
Adafruit_GPS GPS(&Wire);
int sleepGPS = 5;

// IMU setup
Adafruit_LSM6DSOX sox;

// Buzzer setup
int buzzerPin = 2;
int buzzLength = 500;


void setup()
{
  pinMode(buzzerPin, OUTPUT);

  while (!SerialUSB);

  SerialUSB.begin(115200);
  SerialUSB.println("Starting setup...");

  // GPS setup
  pinMode(sleepGPS, OUTPUT);
  digitalWrite(sleepGPS, HIGH);
  GPS.begin(9600);
  GPS.sendCommand(PMTK_SET_NMEA_OUTPUT_RMCGGA);
  GPS.sendCommand(PMTK_SET_NMEA_UPDATE_1HZ); // 1 Hz update rate
  GPS.sendCommand(PGCMD_ANTENNA);
  digitalWrite(sleepGPS, LOW);
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

  //LoRa setup
  pinMode(transmitting, OUTPUT);
  if (rf95.init() == false){
    SerialUSB.println("Radio Init Failed - Freezing");
    while (1);
  }
  else{
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


void loop()
{
  if (rf95.available()){
    uint8_t buf[RH_RF95_MAX_MESSAGE_LEN];
    uint8_t len = sizeof(buf);

    if (rf95.recv(buf, &len)){
      timeSinceLastPacket = millis(); //Timestamp this packet

      SerialUSB.print("Got message: ");
      SerialUSB.print((char*)buf);
      SerialUSB.println();

      // Send a reply
      digitalWrite(transmitting, HIGH);
      uint8_t toSend[] = "ACK"; 
      rf95.send(toSend, sizeof(toSend));
      rf95.waitPacketSent();
      digitalWrite(transmitting, LOW);

      parseMessage((char*)buf);
    }
    else
      SerialUSB.println("Recieve failed");
  }

  if (millis() - timer > freq * 1000) {
    timer = millis(); // reset the timer
    char dataGPS[2][100] = {"",""};
    getGPS(dataGPS);
    SerialUSB.print(dataGPS[0]);
    SerialUSB.println(dataGPS[1]);
    GPSToSend = dataGPS[0] + "," dataGPS[1];

    int dataIMU[3][3] = {};
    pollIMU(dataIMU);
    SerialUSB.println(dataIMU[0][0]);

    sent = sendMessage(GPSToSend);
    while (!sent) {
      SerialUSB.println("Retransmitting...");
      sent = sendMessage(GPSToSend);
    }
  }
}

bool sendMessage(char message, int timeout=2000)
{
  digitalWrite(transmitting, HIGH);
  uint8_t toSend[] = message; 
  rf95.send(toSend, sizeof(toSend));
  rf95.waitPacketSent();
  SerialUSB.println("Sent");
  digitalWrite(transmitting, LOW);

  delay(100);

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
    }
    else {
      SerialUSB.println("Receive failed");
      return false;
    }
  else {
    SerialUSB.println("No reply");
    return false;
  }
}

void parseMessage(char message)
{
  switch (message) {
  case "buzz":
    buzz();
    break;
  case "gps":
    char dataGPS[2][100] = {"",""};
    getGPS(dataGPS);
    GPSToSend = dataGPS[0] + "," dataGPS[1];
    sent = sendMessage(GPSToSend);
    while (!sent) {
      SerialUSB.println("Retransmitting...");
      sent = sendMessage(GPSToSend);
    break;
  case "search":
    freq = 10;
    break;
  case "normal":
    freq = 30;
    break;
  }
}

void setRanges()
{
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
    break; // unsupported range for the DSOX
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

void pollIMU(int dataIMU[3][3])
{
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

void getGPS(char dataGPS[2][100])
{
  // wake up gps
  digitalWrite(sleepGPS, HIGH);
  // wait for fix (but don't actually)
  const char *wait = "$GNGGA";
  if (GPS.waitForSentence(wait))
    strcpy(dataGPS[0], GPS.lastNMEA());
  wait = "$GNRMC";
  if (GPS.waitForSentence(wait))
    strcpy(dataGPS[1], GPS.lastNMEA());

  // put GPS back to sleep
  digitalWrite(sleepGPS, LOW);
  GPS.sendCommand("$PMTK225,4*2F");
}

void buzz()
{
  uint32_t buzzTimer = millis();
  while (millis() - buzzTimer < buzzLength) {
    digitalWrite(buzzerPin, HIGH);
    delayMicroseconds(500);
    digitalWrite(buzzerPin, LOW);
    delayMicroseconds(500);
  }
}