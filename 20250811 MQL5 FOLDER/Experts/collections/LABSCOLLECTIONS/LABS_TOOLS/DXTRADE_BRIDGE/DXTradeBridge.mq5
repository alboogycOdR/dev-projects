//+------------------------------------------------------------------+
//|                                                DXTradeBridge.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#define BASE_URL "https://demo.dx.trade/dxsca-web/"
 //#define BASE_URL "https://dxtrade.ftmo.com/dxsca-web/"

#define ACCOUNT_FTMO "VRilhF"
#define PASSWD_FTMO "6tcdXIzW"
/*

DXtrade CFD demo
Username:

VRilhF

Password:

6tcdXIzW


*/

string token;
datetime timeout;
string getJsonStringValue(string json, string key) {
   int indexStart = StringFind(json, key) + StringLen(key) + 3;
   int indexEnd = StringFind(json, "\"", indexStart);
   return StringSubstr(json, indexStart, indexEnd - indexStart);
}
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   login();sendOrderDXTRADE();
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int login() {
   string url = BASE_URL + "login";
   char post[], result[];
   string headers = "Content-Type: application/json\r\nAccept: application/json\r\n";
   string resultHeader;
   string json = "{\"username\": \"" + ACCOUNT_FTMO + "\", \"domain\": \"default\", \"password\": \"" + PASSWD_FTMO+ "\"}";
   Print("JSON OUTPUT: "+json);
   
   StringToCharArray(json, post,0,StringLen(json));
   ResetLastError();
   int res = WebRequest("POST", url, headers, 5000, post, result, resultHeader);

   if(res == -1) {
      Print(__FUNCTION__, " > web req failed...code: ,", GetLastError());
   } else if(res != 200) {
      Print(__FUNCTION__, " > server request failed ... code: ", res);
   } else {
      string msg = CharArrayToString(result);
      Print(__FUNCTION__, " > server request success ... ", msg);
      token = getJsonStringValue(msg, "sessionToken");
      timeout = TimeCurrent() + PeriodSeconds(PERIOD_M1) * 30;
      Print(__FUNCTION__, " > token: ", token, ", timeout: ", timeout);
   }
   return res;
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   if(TimeCurrent() > timeout - 300) ping();
   if(TimeCurrent() > timeout - 600) sendOrderDXTRADE();
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int ping() {
   string url = BASE_URL + "ping";
   char post[], result[];
   string headers = "Content-Type: application/json\r\nAccept: application/json\r\nAuthorization: DXAPI " + token + "\r\n";
   string resultHeader;

   string json = "{\"username\": \"" + ACCOUNT_FTMO + "\", \"domain\": \"default\", \"password\": \"" + PASSWD_FTMO+ "\"}";
   StringToCharArray(json, post, 0, StringLen(json));

   ResetLastError();
   int res = WebRequest("POST", url, headers, 5000, post, result, resultHeader);

   if(res == -1) {
      Print(__FUNCTION__, " > web request failed ... code: ", GetLastError());
   } else if(res != 200) {
      Print(__FUNCTION__, " > server request failed ... code: ", res);
   } else {
      string msg = CharArrayToString(result);
      Print(__FUNCTION__ " > server request success ... ", msg);

      timeout = TimeCurrent() + PeriodSeconds(PERIOD_M1) * 30;
      Print(__FUNCTION__, " > token: ", token, ", timeout: ", timeout);

   }
   return res;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int sendOrderDXTRADE() {
   string url = BASE_URL + "accounts/default:" + ACCOUNT_FTMO + "/orders";
   char post[], result[];
   string headers = "Content-Type: application/json\r\nAccept: application/json\r\nAuthorization: DXAPI " + token + "\r\n";
   string resultHeader;
   string json ;

   StringConcatenate(json,
      "{",
      "\"account\": \"default:"+ACCOUNT_FTMO + "\",",
      "\"orderCode\": \"1\",",
      "\"type\": \"MARKET\",",
      "\"instrument\": \"BTC/USD\",",
      "\"quantity\": 10000,",
      "\"positionEffect\": \"OPEN\",",
      "\"side\": \"BUY\",",
      "\"tif\": \"GTC\"", "}");

   //buy==6
   //sell==7
   Print("___________________________");
   Print(json);
   Print("___________________________");
   StringToCharArray(json, post, 0, StringLen(json));
   ResetLastError();
   int res = WebRequest("POST", url, headers, 5000, post, result, resultHeader);

   if(res == -1) {
      Print(__FUNCTION__, " > web req failed...code: ,", GetLastError());
   } else if(res != 200) {
      Print(__FUNCTION__, " > server request failed ... code: ", res);
   } else {
      string msg = CharArrayToString(result);
      Print(__FUNCTION__, " > server request success ... ", msg);
      token = getJsonStringValue(msg, "sessionToken");
      timeout = TimeCurrent() + PeriodSeconds(PERIOD_M1) * 30;
      Print(__FUNCTION__, " > token: ", token, ", timeout: ", timeout);
   }
   return res;
}
