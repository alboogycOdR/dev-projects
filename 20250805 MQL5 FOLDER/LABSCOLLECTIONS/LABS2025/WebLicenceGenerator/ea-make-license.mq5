//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property version "1.00"
#property script_show_inputs
#include "LicenceCheckInclude\LicenceWebCheck.mqh"
//===
input string InpProductName = "TELEGRAMTRADERPRO"; // Product name used in file name
string InpProductKey        = "key1";     // Secret product key
input int    InpAccount     = 123456;     // Customer Account number
//===
bool   InpTesting           = false;      // Is this a test [TRUE=Validate, FALSE = Make lic file]

//===
CLicenceWeb *licenceWeb;
//===
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
void         OnStart()
  {

   licenceWeb = new CLicenceWeb(InpProductName, InpProductKey, "", InpAccount);
   licenceWeb.SetRegistration();

   if(!InpTesting)
     {
      Make();
     }

   delete licenceWeb;
  }
//+------------------------------------------------------------------+
//        suggestions and tips
/*
Suggested Additional Features
1. License Validation: Add a function to validate existing licenses, checking expiration dates and authenticity.
Automatic Renewal: Implement a feature to automatically renew licenses before they expire.
Multiple License Tiers: Support different license types (e.g., basic, premium) with varying durations and features.
User Interface: Create a simple UI for license management, displaying status and expiration dates.
Offline Mode: Implement a fallback mechanism for when web requests fail, allowing temporary offline usage.
License Revocation: Add the ability to revoke licenses remotely for security purposes.
Logging: Implement detailed logging for license operations and errors for better troubleshooting.


Possible Issues
1. Security: The product key is stored as an input, which might be vulnerable to reverse engineering.
Single Point of Failure: Relying solely on GitHub for license verification could be problematic if the service is down.
Hardcoded URLs: The GitHub URL is hardcoded, making it difficult to change without modifying the code.
Limited Error Handling: The current error handling is basic and might not cover all possible scenarios.
Time Synchronization: Using local time for license expiration could be manipulated by changing system time.
No License Backup: There's no mechanism to backup or restore licenses if the local file is corrupted or deleted.
Lack of Encryption: The license data is not encrypted, potentially exposing sensitive information.
Fixed License Duration: The 30-day license period is hardcoded, limiting flexibility for different license terms.
To address these issues and enhance the program, consider implementing stronger encryption, using a more robust and distributed license verification system, improving error handling, and adding more flexible configuration options for license terms and server URLs.

*/