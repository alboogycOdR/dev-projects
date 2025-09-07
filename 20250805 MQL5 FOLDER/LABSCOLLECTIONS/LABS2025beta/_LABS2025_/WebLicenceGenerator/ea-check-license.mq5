//+------------------------------------------------------------------+
//|                                             ea-check-license.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include "LicenceCheckInclude\LicenceWebCheck.mqh"

input string InpProductName = "TELEGRAMTRADERPRO"; // Product name used in file name
CLicenceWeb *licenceWeb;
int InpAccount ;
string InpProductKey  = "key1";     // Secret product key

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   InpAccount = (int)AccountInfoInteger(ACCOUNT_LOGIN);

   licenceWeb = new CLicenceWeb(InpProductName, InpProductKey, "", InpAccount);
   
   // Debug print
   Print("OnInit: Before SetRegistration");
   Print("OnInit: InpProductName = ", InpProductName);
   Print("OnInit: InpAccount = ", InpAccount);
   
   licenceWeb.SetRegistration();
   
   // Debug print
   Print("OnInit: After SetRegistration");

   Test();

   delete licenceWeb;

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

  }
//+------------------------------------------------------------------+
void Test()
  {
   Print("Now testing licence");
   if(!licenceWeb.Check())
     {
      Print("Oops, problem with the licence");
      return;
     }
   Print("Valid Licence");
//=========
   string parts[];
   string licenceData = licenceWeb.GetData();
   StringSplit(licenceData, '\n', parts);
//=========
   PrintFormat("Account=%s, %s",
               parts[0],
               (parts[0] == licenceWeb.Hash(string(InpAccount))) ? "correct" : "fail");
   PrintFormat("Product=%s, %s",
               parts[1],
               (parts[1] == licenceWeb.Hash(InpProductName)) ? "correct" : "fail");
   PrintFormat("Expires at %s",
               parts[2]);
   PrintFormat("Grace expires at %s",
               parts[3]);
  }
//+------------------------------------------------------------------+
