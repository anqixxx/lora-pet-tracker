/*
  loraArduino.h - Test library for Wiring - description
  Copyright (c) 2006 John Doe.  All right reserved.
*/

// ensure this library description is only included once
#ifndef loraArduino_h
#define loraArduino_h

// include
#include "Arduino.h"
#include "RH_RF95.h"
#include "wiring.h"
#include "SPI.h"
#include "stdint.h"

// constants
#define PIN_CHIP_SELECT 12
#define PIN_INTERRUPT 6
#define DEFAULT_CARRIER_FREQUENCY 915
#define DEFAULT_BANDWIDTH 125000
#define DEFAULT_TX 15
#define NORMAL_MODE_PERIOD 300
#define SEARCH_MODE_PERIOD 60
#define GPS_MESSAGE_LENGTH 20

class loraArduino
{
  public:

    typedef enum
    {
      BUZZ,
      SEARCH_MODE,	 
      CURRENT_GPS,	
      CHANGE_SF, 
      ACK,
      HISTORIC_GPS
    } MessageType;

    loraArduino(void);
    bool init(void);
    void receiveMessage(void);
    void sendMessage(void);

  // library-accessible "private" interface
  private:
    RH_RF95 rf95;
    uint8_t searchMode;
    uint8_t GPSupdateTime;

    void sendAck(void);
    void buzz(void);
    void receiveCurrentGPS(void);
    void sendCurrentGPS(void);

    // need to implement batch gps locations 
};

#endif

