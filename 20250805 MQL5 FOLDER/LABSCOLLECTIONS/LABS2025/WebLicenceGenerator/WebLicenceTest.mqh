/*
   WebLicenceTest
   Copyright 2021, Orchard Forex
   https://www.orchardforex.com
*/
#include "LicenceCheckInclude\LicenceWebCheck.mqh"


input string InpProductName = "product1"; // Product name used in file name
input string InpProductKey  = "key1";     // Secret product key
input int    InpAccount     = 123456;     // Customer Account number
input bool   InpTesting     = false;      // Is this a test [TRUE=Validate, FALSE = Make lic file]

CLicenceWeb *licenceWeb;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void         OnStart()
  {

   licenceWeb = new CLicenceWeb(InpProductName, InpProductKey, "", InpAccount);
   licenceWeb.SetRegistration();
   if(!InpTesting)
     {
      Make();
     }
   else
     {
      Test();
     }
   delete licenceWeb;
  }
/*
The function starts by creating a string data that contains several pieces of information:
A hashed version of the account number (InpAccount)
A hashed version of the product name (InpProductName)
An expiry date (30 days from the current time)
A grace period expiry date (33 days from the current time)
These pieces of information are concatenated with newline characters (\n) between them.
*/
void Make()
  {

// Just making up some data here
// You could use anything that works for you
// Account number, expiry time,
//    grace expiry time
   string data = licenceWeb.Hash(string(InpAccount)) + "\n"
                 + licenceWeb.Hash(InpProductName)
                 + "\n"
                 + TimeToString(TimeCurrent() + (86400 * 30))     //30 days from the current time
                 + "\n"
                 + TimeToString(TimeCurrent() + (86400 * 33));    //33 days from the current time

// Not necessary to do this, just for demonstration
   string signature = licenceWeb.KeyGen(data);
   Print("The signature is " + signature);

// Create the file to ship to the customer
   if(!licenceWeb.FileGen(data))
     {
      Print("Failed to create licence file");
      return;
     }

   Print("Created licence file");
  }

//+------------------------------------------------------------------+
//|                                                                  |
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
   string parts[];
   string licenceData = licenceWeb.GetData();
   StringSplit(licenceData, '\n', parts);

   PrintFormat("Account=%s, %s", parts[0], (parts[0] == licenceWeb.Hash(string(InpAccount))) ? "correct" : "fail");
   PrintFormat("Product=%s, %s", parts[1], (parts[1] == licenceWeb.Hash(InpProductName)) ? "correct" : "fail");
   PrintFormat("Expires at %s", parts[2]);
   PrintFormat("Grace expires at %s", parts[3]);
  }
//+------------------------------------------------------------------+
