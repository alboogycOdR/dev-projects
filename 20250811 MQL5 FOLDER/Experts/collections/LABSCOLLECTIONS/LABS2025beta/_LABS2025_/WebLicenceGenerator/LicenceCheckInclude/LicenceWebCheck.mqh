/*
   LicenceWebCheck.mqh
   Copyright 2021, Orchard Forex
   https://www.orchardforex.com
*/

#property copyright "Copyright 2013-2020, Orchard Forex"
#property link "https://www.orchardforex.com"
#property version "1.00"

// this is important for MT4
#property strict

#include "LicenceFileCheck.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CLicenceWeb : public CLicenceFile
  {

protected:
   string            mAccount;
   string            mRegistration;

   virtual bool      LoadData(string &data);
   virtual string    LicencePath();

public:
                     CLicenceWeb(string productName, string productKey, string registration, long account = -1);
                    ~CLicenceWeb() {}

   void              SetRegistration();
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CLicenceWeb::CLicenceWeb(string productName, string productKey, string registration, long account = -1) : CLicenceFile(productName, productKey)
  {
   Print(__FUNCTION__);
   mRegistration = registration;
   if(account < 0)
     {
      account = AccountInfoInteger(ACCOUNT_LOGIN);
     }
   mAccount = string(account);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void   CLicenceWeb::SetRegistration()
  {
  Print(__FUNCTION__);
   mRegistration = Hash(mProductName + "_" + mAccount);
   Print("SetRegistration: mRegistration = ", mRegistration);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CLicenceWeb::LicencePath()
  {
   Print(__FUNCTION__);
   return ("License\\" + Hash(mProductName + "_" + mAccount) + ".lic");
  }


bool CLicenceWeb::LoadData(string &data)
{
   Print(__FUNCTION__+" "+__LINE__);
 
   string headers = "";
   char   postData[];
   char   resultData[];
   string resultHeaders;
   int    timeout = 5000; // 5 seconds

   string url     = "https://github.com";

   // Debug print
   Print("LoadData: mRegistration = ", mRegistration);
   Print("LoadData: mProductName = ", mProductName);
   Print("LoadData: mAccount = ", mAccount);

   string api     = StringFormat("https://github.com/alboogycOdR/License/raw/refs/heads/main/%s.lic", mRegistration);
   Print("API CALL to: "+api);
   Print(__FUNCTION__ + " " + __LINE__);
   
    

   ResetLastError();
   int response = WebRequest("GET", api, headers, timeout, postData, resultData, resultHeaders);
   int errorCode = GetLastError();

   // Check for WebRequest errors first
   if (response == -1)
   {
      string errorMessage = "Error in WebRequest. Error code: " + IntegerToString(errorCode);
      errorMessage += "\nAdd the address " + url + " in the list of allowed URLs";
      Print(errorMessage);
      return false;
   }

   // Process the response
   switch(response)
   {
      case 200:
         data = CharArrayToString(resultData);
         if (StringLen(data) == 0)
         {
            Print("Warning: Received empty response data");
            return false;
         }
         return true;

      case 404:
         Print("Error: License file not found. URL: " + api);
         return false;

      case 403:
         Print("Error: Access forbidden. Check your permissions or API rate limits.");
         return false;

      case 500:
      case 502:
      case 503:
      case 504:
         Print("Error: Server error (code " + IntegerToString(response) + "). Please try again later.");
         return false;

      default:
         Print("Unexpected response code: " + IntegerToString(response));
         if (StringLen(resultHeaders) > 0)
         {
            Print("Response headers: " + resultHeaders);
         }
         return false;
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// bool   CLicenceWeb::LoadData(string &data)
//   {
//  Print(__FUNCTION__+" "+__LINE__);
 
//    string headers = "";
//    char   postData[];
//    char   resultData[];
//    string resultHeaders;
//    int    timeout = 5000; // 1 second, may be too short for a slow connection

//    string url     = "https://github.com";
// // string api     = StringFormat( "https://drive.google.com/uc?id=%s&export=download", mRegistration );


//    string api     = StringFormat("https://github.com/alboogycOdR/License/raw/refs/heads/main/%s.lic", mRegistration);
// Print(__FUNCTION__+" "+__LINE__);
// Print("API CALL to: "+api);
//    ResetLastError();
//    int response  = WebRequest("GET", api, headers, timeout, postData, resultData, resultHeaders);
//    int errorCode = GetLastError();

//    data          = CharArrayToString(resultData);

//    switch(response)
//      {
//       case -1:
//          Print("Error in WebRequest. Error code  =", errorCode);
//          Print("Add the address " + url + " in the list of allowed URLs");
//          return false;
//          break;
//       case 200:
//          //--- Success
//          return true;
//          break;
//       default:
//          PrintFormat("Unexpected response code %i", response);
//          return false;
//          break;
//      }

//    return false;
//   }
//+------------------------------------------------------------------+
//removed from loaddata
/*

// Add this code to handle 303 redirect but it creates more problems
// if (response==303) {
// int locStart = StringFind(resultHeaders, "Location: ", 0)+10;
// int locEnd = StringFind(resultHeaders, "\r", locStart);
// api = StringSubstr(resultHeaders, locStart, locEnd-locStart);
// ResetLastError();
// response  = WebRequest( "GET", api, headers, timeout, postData, resultData, resultHeaders );
// errorCode = GetLastError();
//}

*/
//+------------------------------------------------------------------+
