/*
  loraArduino.h - Test library for LoRa prototype
*/

// include this library's description file
#include "loraArduino.h"

#define PIN_CHIP_SELECT 12
#define PIN_INTERRUPT 6

// Constructor /////////////////////////////////////////////////////////////////
// Function that handles the creation and setup of instances

RH_RF95 rf95(PIN_CHIP_SELECT, PIN_INTERRUPT);

loraArduino::loraArduino(int givenValue)
{
  // initialize this instance's variables
  value = givenValue;

  // do whatever is required to initialize the library
  pinMode(13, OUTPUT);
  Serial.begin(9600);
}

// Public Methods //////////////////////////////////////////////////////////////
// Functions available in Wiring sketches, this library, and other libraries

void loraArduino::doSomething(void)
{
  // eventhough this function is public, it can access
  // and modify this library's private variables
  Serial.print("value is ");
  Serial.println(value);

  // it can also call private functions of this library
  doSomethingSecret();
}

// Private Methods /////////////////////////////////////////////////////////////
// Functions only available to other functions in this library

void loraArduino::doSomethingSecret(void)
{
  digitalWrite(13, HIGH);
  delay(200);
  digitalWrite(13, LOW);
  delay(200);
}

