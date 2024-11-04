/*
  loraArduino.h - Test library for Wiring - description
  Copyright (c) 2006 John Doe.  All right reserved.
*/

// ensure this library description is only included once
#ifndef loraArduino_h
#define loraArduino_h

// include types & constants of Wiring core API
#include "Arduino.h"
#include "RH_RF95.h"
#include "wiring.h"
#include "SPI.h"
#include "stdint.h"

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

    loraArduino(uint8_t csPin, uint8_t intPin);
    void receiveMessage(void);
    void sendMessage(void);

  // library-accessible "private" interface
  private:
    RH_RF95 rf95;
    uint8_t searchMode;
    uint8_t GPSupdateTime;
    float carrierFrequency;

    void sendAck(void);
    void buzz(void);
    void receiveCurrentGPS(void);
    void sendCurrentGPS(void);

    // need to implement batch gps locations 
};

#endif

