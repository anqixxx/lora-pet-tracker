/*
  loraArduino.h - Test library for LoRa prototype
*/

// include this library's description file
#include "loraArduino.h"


// Constructor /////////////////////////////////////////////////////////////////
// Function that handles the creation and setup of instances

loraArduino::loraArduino(void):rf95(PIN_CHIP_SELECT, PIN_INTERRUPT)
{
  // start in normal mode with 
  searchMode = false;
  GPSupdateTime = NORMAL_MODE_PERIOD;
}

// Public Methods //////////////////////////////////////////////////////////////
// Functions available in Wiring sketches, this library, and other libraries

bool loraArduino::init(void)
{
  if (rf95.init() == false){
    return false;
  }
  else{
    return true;
  }
  rf95.setFrequency(DEFAULT_CARRIER_FREQUENCY);
}

void loraArduino::receiveMessage(void)
{
  if (rf95.available())
  {
    byte buf[RH_RF95_MAX_MESSAGE_LEN];
    byte len = sizeof(buf);
    byte senderID;
    byte messageType;

    if (rf95.recv(*buf, &len))
    {
      memcpy(*senderID, *buf, 1);
      memcpy(*messageType, *buf + 1, 1);
      switch(messageType)
      {
        case BUZZ:
          break;
        case SEARCH_MODE:
          break;
        case CURRENT_GPS:
          uint8_t output[GPS_MESSAGE_LENGTH];
          memcpy(*output, *buf + 2, GPS_MESSAGE_LENGTH);
          sendAck();
          memcpy
          break;
        case CHANGE_SF:
          byte newFrequency;
          byte newBandwidth;
          memcpy(*newFrequency, *buf + 2, 2); // not sure how long this would be actually
          memcpy(*newBandwidth, *buf + 3, 2);
          sendAck();
          break;
        case ACK:
          break;
        case HISTORIC_GPS:
          break;
      }
    }
  }
}

void loraArduino::sendMessage(void)
{
  
}

// Private Methods /////////////////////////////////////////////////////////////
// Functions only available to other functions in this library

void loraArduino::sendAck(void)
{
  uint8_t ackMessage = 100;
  rf95.send(*ackMessage, sizeof(ackMessage));
  rf95.waitPacketSent();
  return;
}

void loraArduino::buzz(void)
{
  
}

void loraArduino::receiveCurrentGPS(void)
{
  
}

void loraArduino::sendCurrentGPS(void)
{
  
}
