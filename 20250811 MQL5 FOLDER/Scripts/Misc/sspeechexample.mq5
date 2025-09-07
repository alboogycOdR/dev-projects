#property copyright     "Integer"
#property link          "https://login.mql5.com/ru/users/Integer"
#property description   "http://dmffx.com"
#property description   "mailto:for-good-letters@yandex.ru"

#include <cIntSpeech.mqh>
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Speech.Say("Buy or sell that is the question. "+
              "Whether this deal brings loss or profit? "+
              "It will be gift of smiling fortune. "+
              "Or devil push his hands to our wallet?",
              false);
  }
//+------------------------------------------------------------------+
