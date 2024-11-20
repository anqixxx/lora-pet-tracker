#include <Adafruit_GPS.h>

#include <Adafruit_LSM6DSOX.h>

#include <SPI.h>

#include <RH_RF95.h> 

// We need to provide the RFM95 module's chip select and interrupt pins to the
// rf95 instance below.On the SparkFun ProRF those pins are 12 and 6 respectively.
RH_RF95 rf95(12, 6);

int packetCounter = 0; //Counts the number of packets sent
long timeSinceLastPacket = 0; //Tracks the time stamp of last packet received

float frequency = 921.2; //Broadcast frequency

int LED = 13;

Adafruit_GPS GPS(&Wire);

Adafruit_LSM6DSOX sox;

#define GPSECHO false

uint32_t timer1 = millis();

int freq = 5000; // milliseconds

int outputPin = 2;

int buzzLength = 500;

int sleepGPS = 5;

void setup()
{
  pinMode(LED, OUTPUT);
  pinMode(sleepGPS, OUTPUT);
  digitalWrite(sleepGPS, HIGH);
  pinMode(outputPin, OUTPUT);

  while (!SerialUSB);

  SerialUSB.begin(115200);
  SerialUSB.println("Starting setup...");

  GPS.begin(9600);

  GPS.sendCommand(PMTK_SET_NMEA_OUTPUT_RMCGGA);

  GPS.sendCommand(PMTK_SET_NMEA_UPDATE_1HZ); // 1 Hz update rate

  GPS.sendCommand(PGCMD_ANTENNA);

  if (!sox.begin_I2C(0x6B)) {
    SerialUSB.println("Failed to find LSM6DSOX chip");
    while (1) {
      delay(10);
    }
  }

  SerialUSB.println("LSM6DSOX Found!");

  setRanges();

  //Initialize the Radio.
  if (rf95.init() == false){
    SerialUSB.println("Radio Init Failed - Freezing");
    while (1);
  }
  else{
    //An LED inidicator to let us know radio initialization has completed. 
    SerialUSB.println("Transmitter up!"); 
    digitalWrite(LED, HIGH);
    delay(500);
    digitalWrite(LED, LOW);
    delay(500);
  }

  rf95.setFrequency(frequency);

  // rf95.setTxPower(14, false);

  delay(1000);
}


void loop() // run over and over again
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
      uint8_t toSend[] = "ACK"; 
      rf95.send(toSend, sizeof(toSend));
      rf95.waitPacketSent();
      SerialUSB.println("Sent a reply");
      digitalWrite(LED, LOW); //Turn off status LED

    }
    else
      SerialUSB.println("Recieve failed");
  }

  // if (millis() - timer1 > freq) {
  //   timer1 = millis(); // reset the timer
  //   char dataGPS[2][100] = {"",""};
  //   getGPS(dataGPS);
  //   SerialUSB.println(dataGPS[0]);
  //   SerialUSB.println(dataGPS[1]);

  //   int dataIMU[3][3] = {};
  //   pollIMU(dataIMU);
  //   SerialUSB.println(dataIMU[0][0]);

  //   buzz();
  // }
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
  // wait for fix (but don't actually)
  const char *wait = "$GNGGA";
  if (GPS.waitForSentence(wait))
    strcpy(dataGPS[0], GPS.lastNMEA());
  wait = "$GNRMC";
  if (GPS.waitForSentence(wait))
    strcpy(dataGPS[1], GPS.lastNMEA());

  // put GPS back to sleep
}

void buzz()
{
  uint32_t buzzTimer = millis();
  // SerialUSB.println(buzzTimer);
  while (millis() - buzzTimer < buzzLength) {
    // SerialUSB.println(millis() - buzzTimer);
    digitalWrite(outputPin, HIGH);
    delayMicroseconds(500);
    digitalWrite(outputPin, LOW);
    delayMicroseconds(500);
    // tone(outputPin, 2000);
  }
}