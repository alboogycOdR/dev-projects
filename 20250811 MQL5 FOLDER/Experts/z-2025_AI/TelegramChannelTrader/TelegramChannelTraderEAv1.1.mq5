//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                       TelegramSignalTrader_V1.mq5|
//|                      Copyright 2023, Your Name/Company           |
//|                                              https://www.xxxx.com|
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name/Company"
#property link      "https://www.xxxx.com"
#property version   "1.00"
#property description "Connects to a local web service to fetch Telegram signals"
#property description "and execute trades. Requires external script."
#property strict

#include <Trade\Trade.mqh> // Standard trading class
/*
todo:
   issue still with receive and act on CLOSE instructions




v1.1
New Logic Summary:
BUY Signal:
SKIP if Current Ask < Signal Open Price.
SKIP if Current Ask >= Signal Take Profit Price.
SKIP if Current Ask < Signal Stop Loss Price (Implied, good to keep this check).
If NONE of the above skip conditions are met, place a MARKET BUY order.
SELL Signal:
SKIP if Current Bid > Signal Open Price.
SKIP if Current Bid <= Signal Take Profit Price.
SKIP if Current Bid > Signal Stop Loss Price (Implied, good to keep this check).
If NONE of the above skip conditions are met, place a MARKET SELL order.


Key Changes:
Removed Pending Order Logic: The entire block related to priceDifference, tolerancePoints, and trade.OrderOpen for pending orders has been removed.
Removed Pending Price Adjustments: The code checking Buy Stop / Sell Limit placement relative to Ask/Bid and adjusting entryPrice is removed.
New Skip Logic: Added explicit if/else if blocks for both BUY and SELL actions to check the three skip conditions:
Price worse than signal open (ask < open for BUY, bid > open for SELL).
Price already beyond TP (ask >= tp for BUY, bid <= tp for SELL).
Price already beyond SL (ask < sl for BUY, bid > sl for SELL) - kept for safety.
Clear Logging: Added specific PrintFormat messages to explain why a signal is being skipped based on the new rules, including relevant prices.
Direct Market Execution: If none of the skip conditions are met, the code proceeds directly to calculate volume and execute trade.Buy or trade.Sell.
InpPipsTolerance Ignored: Note that the InpPipsTolerance input parameter is no longer used by this function's logic. You might want to add a comment to the input definition or remove it in a future version.
*/
//--- Input Parameters
// Telegram Settings
input string InpWebServerUrl = "http://127.0.0.1:5000/get_signal"; // URL for the Python signal server
input int    InpPollingIntervalSeconds = 300;    // How often to check for signals (300s = 5 mins)
input int    InpSignalExpiryMinutes = 60;        // Ignore signals older than this (minutes)
input int    InpMaxConnectionRetries = 3;        // Max retries if web request fails

// Symbol Matching
input string InpSymbolPrefix = "";               // Prefix for symbols (e.g., "fx.")
input string InpSymbolSuffix = "";               // Suffix for symbols (e.g., ".pro")

// Trade Execution Settings
input double InpPipsTolerance = 50.0;             // Max pips difference from signal open price for Market Order
enum         EnumVolumeType {
   SignalVolume, // Use volume from Telegram signal
   FixedVolume,  // Use fixed volume below
   RiskPercent   // Calculate volume based on risk % of Balance
};
input EnumVolumeType InpVolumeType = SignalVolume; // Volume calculation mode
input double InpFixedVolume = 0.10;            // Fixed lot size if FixedVolume selected
input double InpRiskPercent = 1.0;              // Risk percentage if RiskPercent selected
input ulong  InpMagicNumber = 123456;           // Magic number for EA's trades
input uint   InpSlippage = 3;                   // Slippage in points for Market Orders
input double InpClosePriceTolerancePips = 1.0;  // Max pips diff. for matching CLOSE signal open price

// Notification Settings
input bool   InpSendEmailAlerts = false;         // Enable email alerts on critical errors
input bool   InpSendPushAlerts = true;           // Enable push notification alerts on critical errors

//--- Global Variables
CTrade      trade;                        // Trading object
string      g_web_service_url;          // Store the input URL
int         g_poll_interval_millis;       // Polling interval in milliseconds
long        g_expiry_seconds;           // Signal expiry in seconds
int         g_conn_retry_count = 0;     // Web request retry counter
long        g_last_processed_message_id = -1; // Initialize to -1 to process first valid signal
datetime    g_last_error_notify_time = 0; // To avoid spamming notifications
MqlTick     g_latest_tick;              // To store latest tick info
//int         g_digits;                     // Symbol digits
//double      g_point;                      // Symbol point size

//--- Signal Data Structure
struct SignalData {
   long     message_id;
   long     timestamp;
   string   action;     // "BUY", "SELL", "CLOSE"
   string   symbol;     // e.g., "AUDUSD"
   double   volume;
   double   open_price;
   double   stop_loss;
   double   take_profit;
   bool     is_valid;   // Was parsing successful?
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Check URL setting in MT5 options
   if (!IsUrlAllowed(InpWebServerUrl)) {
      Alert("Error: URL '", InpWebServerUrl, "' is not added to the list of allowed URLs in Tools -> Options -> Expert Advisors!");
      ExpertRemove(); // Stop the EA
      return (INIT_FAILED);
   }
   //--- Initialize global variables
   g_web_service_url = InpWebServerUrl;
   g_poll_interval_millis = InpPollingIntervalSeconds * 1000;
   g_expiry_seconds = InpSignalExpiryMinutes * 60;
   if(g_poll_interval_millis < 1000) { // Minimum reasonable interval
      Print("Error: Polling interval too short. Setting to 5 seconds.");
      g_poll_interval_millis = 5000;
   }
   //--- Setup trading object
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   //--- Set timer
   if(!EventSetMillisecondTimer(g_poll_interval_millis)) {
      Print("Error setting timer! Code: ", GetLastError());
      return(INIT_FAILED);
   }
   Print("Telegram Signal Trader V1 Initialized. Polling URL: ", g_web_service_url, ", Interval: ", InpPollingIntervalSeconds, "s");
   //--- Get symbol properties (can be done here or symbol-specifically later)
   //--- OK
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Check if URL is allowed                                          |
//+------------------------------------------------------------------+
bool IsUrlAllowed(string url)
{
   // This is a rudimentary check. A more robust check might parse the URL better.
   // MT5 doesn't provide a direct function to verify against the list.
   // We rely on WebRequest failing later if it's not allowed.
   // For now, just return true and let WebRequest handle the security restriction.
   return true;
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Kill timer
   EventKillTimer();
   Print("Telegram Signal Trader V1 Deinitialized. Reason: ", reason);
   // Optional: Save g_last_processed_message_id to GlobalVariable or File
}

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   FetchAndProcessSignal();
}
//+------------------------------------------------------------------+
//| Fetch data from the web service and start processing             |
//+------------------------------------------------------------------+
void FetchAndProcessSignal()
{
   // --- CORRECTED APPROACH: Use char[] for response data ---
   char              post_data[];      // For GET request, the body data is empty
   char              result[];         // char array to receive response body
   string            result_headers;   // string for response headers
   int               timeout_ms = 5000; // 5 second timeout for web request
   // We are sending GET, so request body ('data[]') is empty.
   ArrayResize(post_data, 0);
   // Set appropriate headers for a simple GET request (optional but good practice)
   // If your Python server requires specific headers, add them here.
   string headers = "Content-Type: application/json\r\nAccept: application/json\r\nConnection: Close\r\n";
   ResetLastError(); // Reset last error before WebRequest
   int res = WebRequest("GET",
                        g_web_service_url,
                        headers,            // Custom headers
                        timeout_ms,         // Timeout
                        post_data,          // Empty request body data for GET
                        result,             // <<< char[] array to STORE the RESPONSE BODY
                        result_headers);    // string to store response headers
   //--- Check result
   if(res == -1) {
      Print("WebRequest Error: ", GetLastError());
      g_conn_retry_count++;
      if(g_conn_retry_count > InpMaxConnectionRetries) {
         // Avoid spamming notifications, e.g., only notify once every 15 mins
         if(TimeCurrent() - g_last_error_notify_time > 900) {
            NotifyUser("CRITICAL: Failed to connect to signal server " + g_web_service_url + " after " + (string)InpMaxConnectionRetries + " retries. Error: " + (string)GetLastError());
            g_last_error_notify_time = TimeCurrent();
            // Optionally reset counter to try again later, or keep it high to stop trying for a while
            // g_conn_retry_count = 0; // To retry again later
         }
      }
      return; // Exit this timer event
   }
   else if (res != 200) { // Check for HTTP success code
      PrintFormat("WebRequest failed: HTTP Code %d received from %s", res, g_web_service_url);
      // Treat non-200 also as a retry scenario potentially
      g_conn_retry_count++;
      if(g_conn_retry_count > InpMaxConnectionRetries) {
         if(TimeCurrent() - g_last_error_notify_time > 900) {
            NotifyUser("CRITICAL: Received HTTP non-OK response (" + (string)res +") from signal server " + g_web_service_url + " after " + (string)InpMaxConnectionRetries + " retries.");
            g_last_error_notify_time = TimeCurrent();
         }
      }
      return;
   }
   //--- Success - Reset retry counter
   g_conn_retry_count = 0;
   //--- Convert response data to string
   //string jsonResponse = CharArrayToString(data);
   //Print("Received response: ", jsonResponse); // Log raw response
   //--- Check if the response result array is actually populated ---
   int result_size = ArraySize(result);
   if(result_size <= 0) {
      Print("WebRequest successful (Code 200) but received empty response body (result array size is 0).");
      return; // Nothing to parse
   }
   //--- Convert response char array to string --- CORRECTED LINE
   string jsonResponse = CharArrayToString(result); // Convert the 'result' array now
   Print("Received response: ", jsonResponse); // Log raw response string
   //--- Parse and Execute
   SignalData signal;
   if(ParseSimpleJson(jsonResponse, signal)) {
      if(signal.is_valid) {
         ProcessSignal(signal);
      }
      // Else: Parsing worked, but it wasn't a valid/complete signal (e.g., empty {}), do nothing.
   }
   else {
      Print("Failed to parse JSON response."); // Parsing function will print details
   }
}
//+------------------------------------------------------------------+
//| Very Basic & Fragile JSON Parser                                 |
//| IMPORTANT: Assumes specific structure and order! V2 should use   |
//| a proper JSON library.                                          |
//+------------------------------------------------------------------+
bool ParseSimpleJson(const string json, SignalData &signal)
{
   signal.is_valid = false; // Assume invalid until all fields are found (for OPEN/CLOSE)
   signal.message_id = -1;
   signal.timestamp = 0;
   signal.volume = 0;
   signal.open_price = 0;
   signal.stop_loss = 0;
   signal.take_profit = 0;
   signal.action = "";
   signal.symbol = "";
   // Basic checks for empty or malformed json
   if(StringLen(json) < 10 || StringFind(json, "{") == -1 || StringFind(json, "}") == -1) {
      Print("Parse Error: JSON too short or missing braces.");
      return false;
   }
   // Use a helper to extract values - this is SUPER basic
   signal.message_id = StringToInteger(GetJsonValue(json, "message_id"));
   signal.timestamp = StringToInteger(GetJsonValue(json, "timestamp"));
   signal.action = GetJsonValue(json, "action");
   signal.symbol = GetJsonValue(json, "symbol"); // Remove '#' later if present
   signal.volume = StringToDouble(GetJsonValue(json, "volume"));
   signal.open_price = StringToDouble(GetJsonValue(json, "open_price"));
   signal.stop_loss = StringToDouble(GetJsonValue(json, "stop_loss"));
   signal.take_profit = StringToDouble(GetJsonValue(json, "take_profit"));
   // --- Validation ---
   if(signal.message_id <= 0 || signal.timestamp <= 0 || signal.action == "" || signal.symbol == "") {
      // Not enough core info to be a valid signal
      if(StringLen(json) > 2) // If it wasn't just "{}"
         Print("Parse Warning: Core fields missing (id, timestamp, action, symbol) in JSON:", json);
      return true; // Parsing technically "worked" but resulted in invalid signal struct
   }
   // Check action type validity
   /*string upperAction = */StringToUpper(signal.action);
   string upperAction=signal.action;
   if(upperAction != "BUY" && upperAction != "SELL" && upperAction != "CLOSE") {
      Print("Parse Error: Unknown action '", signal.action, "'");
      return false;
   }
   //signal.action = upperAction; // Standardize
   // Check minimum fields based on action
   if((signal.action == "BUY" || signal.action == "SELL")) {
      if(signal.open_price <= 0 || signal.stop_loss <= 0 || signal.take_profit <= 0) {
         Print("Parse Error: Missing/Invalid prices (Open, SL, TP) for OPEN signal.");
         return false; // Indicate parse failure for essential fields
      }
      // Volume check will happen later during calculation/execution
   }
   else if(signal.action == "CLOSE") {
      if(signal.open_price <= 0) { // Essential for matching the trade
         Print("Parse Error: Missing/Invalid 'open_price' for CLOSE signal.");
         return false;
      }
   }
   // If we got here, the essential fields for the action type are present and superficially valid
   signal.is_valid = true;
   return true; // Parsing successful
}
//+------------------------------------------------------------------+
//| Helper to find value for a key in simple JSON (Very Fragile)     |
//| UPDATED TO REMOVE QUOTES FROM STRING VALUES                      |
//+------------------------------------------------------------------+
string GetJsonValue(const string json, const string key)
{
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   if(keyPos == -1) return ""; // Key not found
   int valueStart = keyPos + StringLen(searchKey);
   // Trim leading spaces
   while (StringGetCharacter(json, valueStart) == ' ' && valueStart < StringLen(json)) valueStart++;
   char firstChar = StringGetCharacter(json, valueStart);
   int valueEnd = -1;
   bool isString = false; // Flag to track if it's a string
   if(firstChar == '\"') { // It's a string
      isString = true; // Mark as string
      valueStart++; // Move past the opening quote
      valueEnd = StringFind(json, "\"", valueStart);
      if(valueEnd == -1) return ""; // Closing quote not found
   }
   else { // Assume it's a number or boolean (basic)
      valueEnd = StringFind(json, ",", valueStart);
      int braceEnd = StringFind(json, "}", valueStart);
      if(valueEnd == -1 && braceEnd == -1) return ""; // Neither comma nor brace found
      if(valueEnd == -1) valueEnd = braceEnd;          // Use brace if comma not found
      else if(braceEnd != -1) valueEnd = MathMin(valueEnd, braceEnd); // Use whichever comes first
      // Trim trailing spaces before comma/brace
      int tempEnd = valueEnd - 1;
      while(StringGetCharacter(json, tempEnd) == ' ' && tempEnd > valueStart) tempEnd--;
      valueEnd = tempEnd + 1;
   }
   if(valueEnd <= valueStart) return "";
   // Extract the raw value
   string rawValue = StringSubstr(json, valueStart, valueEnd - valueStart);
   // --- NEW: If it was detected as a string, trim quotes (ALTHOUGH SUBSTR SHOULD ALREADY DO IT) ---
   // It seems StringSubstr ALREADY extracts *without* the surrounding characters at start/end
   // BUT let's double check - sometimes JSON parsers need explicit handling.
   // However, the issue might be MORE basic: the current parser might include the closing "
   // if it immediately followed by , or } if isString path wasn't taken correctly or if spaces were missed.
   // LET'S SIMPLIFY the extraction and make it more robust for V1:
   // We extracted the 'rawValue'. If it starts/ends with quotes, trim them.
   // This isn't perfect JSON parsing, but should fix this specific case.
   if(isString) { // Trim only if we explicitly detected quotes initially
      // No trimming needed as StringSubstr excludes end delimiter
      // Check if StringFind found the correct valueEnd ?
      // If valueEnd = StringFind(json, "\"", valueStart); was correct, rawValue IS already BUY
   }
   // It's more likely the StringSubstr captured the closing " somehow OR the later comparisons fail.
   // Let's try explicitly removing quotes *after* extraction for any text-like value:
   StringTrimRight(rawValue);
   StringTrimLeft(rawValue);
   string trimmedValue = rawValue; // Remove leading/trailing spaces
   if(StringLen(trimmedValue) > 1 && StringGetCharacter(trimmedValue,0) == '"' && StringGetCharacter(trimmedValue, StringLen(trimmedValue)-1)=='"') {
      trimmedValue = StringSubstr(trimmedValue, 1, StringLen(trimmedValue)-2);
   }
   // return rawValue; // Original return
   return trimmedValue; // Return the potentially quote-trimmed value
}

//+------------------------------------------------------------------+
//| Process a Validated Signal                                       |
//+------------------------------------------------------------------+
void ProcessSignal(const SignalData &signal)
{
   PrintFormat("Processing Signal ID: %d, Action: %s, Symbol: %s", signal.message_id, signal.action, signal.symbol);
   //--- Check if already processed
   if(signal.message_id <= g_last_processed_message_id) {
      Print("Signal ID ", signal.message_id, " already processed or older. Skipping.");
      return;
   }
   //--- Check expiry
   datetime signalTime = (datetime)signal.timestamp; // Convert Unix timestamp
   if(TimeCurrent() - signalTime > g_expiry_seconds) {
      Print("Signal ID ", signal.message_id, " expired (Timestamp: ", TimeToString(signalTime), "). Skipping.");
      g_last_processed_message_id = signal.message_id; // Mark as processed even if expired
      return;
   }
   //--- Handle Symbol
   string brokerSymbol = HandleSymbol(signal.symbol);
   //TODO:  WE WILL ASSUME THE SYMBOL BEING SENT IN IS CORRECT OTHER THAN THE # THAT IT HAS
   //WE WILL FIX THIS LATER
   if(brokerSymbol == "") {
      Print("Signal ID ", signal.message_id, " skipped. Symbol '", signal.symbol, "' (adjusted: '", InpSymbolPrefix + signal.symbol + InpSymbolSuffix, "') not found or invalid on broker.");
      g_last_processed_message_id = signal.message_id; // Mark as processed
      return;
   }
   Print("symbol : "+brokerSymbol);
   // Refresh symbol properties for the specific symbol
   int g_digits = (int)SymbolInfoInteger(brokerSymbol, SYMBOL_DIGITS);
   double g_point = SymbolInfoDouble(brokerSymbol, SYMBOL_POINT);
   //--- Handle based on Action
   bool action_taken = false; // Track if we actually attempted a trade action
   if(signal.action == "BUY" || signal.action == "SELL") {
      action_taken = HandleOpenSignal(signal, brokerSymbol);
   }
   else if(signal.action == "CLOSE") {
      action_taken = HandleCloseSignal(signal, brokerSymbol);
   }
   // --- Update last processed ID *if* the signal was valid and processed (even if trade execution failed/skipped)
   g_last_processed_message_id = signal.message_id;
   Print("Updated last processed Message ID to: ", g_last_processed_message_id);
   // Optional: Save g_last_processed_message_id periodically or on successful action
}

//+------------------------------------------------------------------+
//| Cleans symbol, applies prefix/suffix, and validates existence    |
//+------------------------------------------------------------------+
string HandleSymbol(string signalSymbol)
{
   /*string cleanedSymbol = */StringReplace(signalSymbol, "#", ""); // Remove # if present
   string potentialSymbol = InpSymbolPrefix + signalSymbol + InpSymbolSuffix;
   return potentialSymbol;
   // Check if symbol exists and is usable
   if(!SymbolSelect(potentialSymbol, true)) {
      Print("Failed to select symbol: ", potentialSymbol, " Error: ", GetLastError());
      // Attempt to refresh symbols and try again once - broker might need it
      //SymbolsRefresh(); //todo
      Sleep(500); // Brief pause
      if(!SymbolSelect(potentialSymbol, true)) {
         Print("Failed to select symbol ", potentialSymbol, " even after refresh.");
         return "";
      }
   }
   if(SymbolInfoInteger(potentialSymbol, SYMBOL_SELECT) == 0) { // Check if it's truly available in MarketWatch
      Print("Symbol ", potentialSymbol, " not visible in Market Watch. Please add it.");
      // Attempt to select it one more time
      if(!SymbolSelect(potentialSymbol, true)) {
         return ""; // Still failed
      }
      // Recheck visibility after selection attempt
      if(SymbolInfoInteger(potentialSymbol, SYMBOL_SELECT) == 0) {
         return ""; // If still not visible, give up.
      }
   }
   // Further check if trade is allowed
   ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(potentialSymbol, SYMBOL_TRADE_MODE);
   if(tradeMode == SYMBOL_TRADE_MODE_DISABLED || tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY) { // Cannot open new trades
      Print("Symbol ", potentialSymbol, " exists but trading is disabled or close-only.");
      return "";
   }
   // Return the normalized symbol name from broker (handles case sensitivity etc.)
   //return SymbolInfoString(potentialSymbol, SYMBOL_NAME);  //TODO
   return potentialSymbol;
}

//+------------------------------------------------------------------+
//| Handle OPEN BUY/SELL Signal -- REVISED MARKET-ONLY LOGIC         |
//+------------------------------------------------------------------+
bool HandleOpenSignal(const SignalData &signal, const string brokerSymbol)
{
   // --- Get Debug Symbol ---
   // PrintFormat("Debug HandleOpenSignal: Received Symbol = '%s'", brokerSymbol); // Keep if needed
   //--- Get current market prices ---
   if(!SymbolInfoTick(brokerSymbol, g_latest_tick)) {
      PrintFormat("Error getting tick for '%s'. Error: %d", brokerSymbol, GetLastError());
      return false;
   }
   double ask = g_latest_tick.ask;
   double bid = g_latest_tick.bid;
   // Check for valid market prices
   if (ask <= 0 || bid <= 0) {
      Print("Invalid current market prices (<=0) for ", brokerSymbol," Ask:", ask, " Bid:", bid);
      return false;
   }
   int g_digits = (int)SymbolInfoInteger(brokerSymbol, SYMBOL_DIGITS);
   double g_point = SymbolInfoDouble(brokerSymbol, SYMBOL_POINT);
   //--- Normalize signal prices according to broker symbol digits ---
   double signal_open_norm = NormalizeDouble(signal.open_price, (int)SymbolInfoInteger(brokerSymbol, SYMBOL_DIGITS));
   double signal_sl_norm = NormalizeDouble(signal.stop_loss, (int)SymbolInfoInteger(brokerSymbol, SYMBOL_DIGITS));
   double signal_tp_norm = NormalizeDouble(signal.take_profit, (int)SymbolInfoInteger(brokerSymbol, SYMBOL_DIGITS));
   //--- Validate signal prices make logical sense (SL/TP relative to Open) ---
   // (Keeping this basic check is still good practice)
   if (signal.action == "BUY") {
      if (signal_sl_norm >= signal_open_norm || signal_tp_norm <= signal_open_norm) {
         PrintFormat("Invalid Buy signal structure for %s: Open=%.*f, SL=%.*f, TP=%.*f",
                     brokerSymbol, g_digits, signal_open_norm, g_digits, signal_sl_norm, g_digits, signal_tp_norm);
         return false; // Signal structure is invalid
      }
   }
   else {   // SELL
      if (signal_sl_norm <= signal_open_norm || signal_tp_norm >= signal_open_norm) {
         PrintFormat("Invalid Sell signal structure for %s: Open=%.*f, SL=%.*f, TP=%.*f",
                     brokerSymbol, g_digits, signal_open_norm, g_digits, signal_sl_norm, g_digits, signal_tp_norm);
         return false; // Signal structure is invalid
      }
   }
   //--- NEW Market-Only Entry Logic ---
   bool execute_market_order = false;
   string skip_reason = "";
   if (signal.action == "BUY") {
      // Conditions to SKIP the BUY trade
      if (ask < signal_open_norm) {
         skip_reason = "Current Ask is below Signal Open Price.";
      }
      else if (ask >= signal_tp_norm) {
         skip_reason = "Current Ask is at or beyond Signal TP.";
      }
      else if (ask < signal_sl_norm) {
         // Although likely covered by 'ask < signal_open_norm', keep for explicit safety
         skip_reason = "Current Ask is below Signal SL.";
      }
      else {
         // If none of the skip conditions are met, proceed with Market Buy
         execute_market_order = true;
      }
      // Log Skip reason or Intent to trade
      if (!execute_market_order) {
         PrintFormat("Skipping BUY Signal ID %d (%s): %s (Ask: %.*f, Signal Open: %.*f, SL: %.*f, TP: %.*f)",
                     signal.message_id, brokerSymbol, skip_reason,
                     g_digits, ask, g_digits, signal_open_norm, g_digits, signal_sl_norm, g_digits, signal_tp_norm);
         return false; // Indicate processed but skipped
      }
      else {
         PrintFormat("Proceeding with MARKET BUY for Signal ID %d (%s). (Ask: %.*f >= Signal Open: %.*f AND Ask < Signal TP: %.*f)",
                     signal.message_id, brokerSymbol, g_digits, ask, g_digits, signal_open_norm, g_digits, signal_tp_norm);
      }
   }
   else { // Action == SELL
      // Conditions to SKIP the SELL trade
      if (bid > signal_open_norm) {
         skip_reason = "Current Bid is above Signal Open Price.";
      }
      else if (bid <= signal_tp_norm) {
         skip_reason = "Current Bid is at or beyond Signal TP.";
      }
      else if (bid > signal_sl_norm) {
         // Although likely covered by 'bid > signal_open_norm', keep for explicit safety
         skip_reason = "Current Bid is above Signal SL.";
      }
      else {
         // If none of the skip conditions are met, proceed with Market Sell
         execute_market_order = true;
      }
      // Log Skip reason or Intent to trade
      if (!execute_market_order) {
         PrintFormat("Skipping SELL Signal ID %d (%s): %s (Bid: %.*f, Signal Open: %.*f, SL: %.*f, TP: %.*f)",
                     signal.message_id, brokerSymbol, skip_reason,
                     g_digits, bid, g_digits, signal_open_norm, g_digits, signal_sl_norm, g_digits, signal_tp_norm);
         return false; // Indicate processed but skipped
      }
      else {
         PrintFormat("Proceeding with MARKET SELL for Signal ID %d (%s). (Bid: %.*f <= Signal Open: %.*f AND Bid > Signal TP: %.*f)",
                     signal.message_id, brokerSymbol, g_digits, bid, g_digits, signal_open_norm, g_digits, signal_tp_norm);
      }
   }
   // --- If we reached here, execute_market_order must be true ---
   //--- Calculate Volume ---
   double volume = CalculateVolume(signal, brokerSymbol);
   if(volume <= 0) {
      Print("Invalid volume calculated (", volume, ") for ", brokerSymbol, ". Skipping trade.");
      return false;
   }
   //--- Prepare for Market Execution ---
   string orderComment = "TG_SigID_" + (string)signal.message_id + "_Mkt"; // Append Mkt
   bool result = false;
   trade.SetTypeFillingBySymbol(brokerSymbol); // Ensure correct filling mode
   //--- Execute Market Order ---
   PrintFormat("Attempting Market %s for %s @ Market, Vol: %.2f, SL: %.*f, TP: %.*f",
               signal.action, brokerSymbol, volume, g_digits, signal_sl_norm, g_digits, signal_tp_norm);
   trade.SetTypeFillingBySymbol(brokerSymbol); // Set filling mode based on symbol
   if (signal.action == "BUY") {
      result = trade.Buy(volume, brokerSymbol, ask, signal_sl_norm, signal_tp_norm, orderComment);
   }
   else {   // SELL
      result = trade.Sell(volume, brokerSymbol, bid, signal_sl_norm, signal_tp_norm, orderComment);
   }
   //--- Log Result ---
   if(result) {
      PrintFormat("Market %s Order successful. Deal: %d, Order: %d", signal.action, (int)trade.ResultDeal(), (int)trade.ResultOrder());
   }
   else {
      PrintFormat("Market %s Order FAILED. Error code: %d. Reason: %s", signal.action, (int)trade.ResultRetcode(), trade.ResultComment());
   }
   return result; // Return true if trade was attempted (succeeded or failed), false if validation stopped it before attempt
}
//+------------------------------------------------------------------+
//| Handle CLOSE Signal                                              |
//+------------------------------------------------------------------+
bool HandleCloseSignal(const SignalData &signal, const string brokerSymbol)
{
   int g_digits = (int)SymbolInfoInteger(brokerSymbol, SYMBOL_DIGITS);
   double g_point = SymbolInfoDouble(brokerSymbol, SYMBOL_POINT);
   PrintFormat("Attempting CLOSE for %s matching Open Price ~%.5f", brokerSymbol, signal.open_price);
   bool position_found = false;
   bool close_attempted = false;
   int closed_count = 0;
   double closePriceTolerancePoints = InpClosePriceTolerancePips * g_point;
   double signal_open_norm = NormalizeDouble(signal.open_price, g_digits);

   trade.SetTypeFillingBySymbol(brokerSymbol); // Set fill type just in case

   // Iterate through all open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--) { // Loop backwards when potentially closing
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
   
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
            PositionGetString(POSITION_SYMBOL) == brokerSymbol) {
         position_found = true; // Found a position managed by this EA for this symbol
         // Get position details
         double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   
         // Compare open prices within tolerance
         if(MathAbs(positionOpenPrice - signal_open_norm) <= closePriceTolerancePoints) {
            PrintFormat("Found matching position Ticket: %d, Symbol: %s, Open: %.5f. Attempting to close.",
                        ticket, brokerSymbol, positionOpenPrice);
   
            // Close the position by ticket
            bool close_result = trade.PositionClose(ticket, InpSlippage);
            close_attempted = true;
            if(close_result) {
               PrintFormat("PositionClose successful for ticket %d. Deal: %d", ticket, (int)trade.ResultDeal());
               closed_count++;
               // V1 assumes one close signal = one position. If multiple might match, decide if you need to break or continue.
               break; // Stop after closing the first match found for this CLOSE signal
            }
            else {
               PrintFormat("PositionClose FAILED for ticket %d. Error code: %d. Reason: %s",
                           ticket, (int)trade.ResultRetcode(), trade.ResultComment());
               // Decide if you should break even on failure, or continue checking other positions (if expecting duplicates)
               break; // Stop after first *attempt* for V1
            }
         }
         else {
            PrintFormat("Position Ticket %d for %s matches Magic#, but Open Price %.5f does not match signal's required Open Price %.5f (Tolerance: %.5f)",
                        ticket, brokerSymbol, positionOpenPrice, signal_open_norm, closePriceTolerancePoints);
         }
      }
   } // End loop through positions
   if(close_attempted) {
      // We attempted a close based on this signal ID
      return true; // Signal was acted upon (attempted close)
   }
   else if (position_found) {
      // Positions existed but none matched the open price
      Print("No open positions for ", brokerSymbol," matched the required Open Price ", signal_open_norm," from CLOSE signal ID ", signal.message_id);
      return true; // Processed signal, but no match
   }
   else {
      Print("No open positions found with Magic# ", InpMagicNumber, " for symbol ", brokerSymbol);
      return true; // Processed signal, but nothing to close
   }
}
//+------------------------------------------------------------------+
//| Calculate Volume based on Input Settings                         |
//+------------------------------------------------------------------+
double CalculateVolume(const SignalData &signal, const string brokerSymbol)
{
   double volume = 0.0;
   double lot_min = SymbolInfoDouble(brokerSymbol, SYMBOL_VOLUME_MIN);
   double lot_max = SymbolInfoDouble(brokerSymbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(brokerSymbol, SYMBOL_VOLUME_STEP);
   switch(InpVolumeType) {
   case SignalVolume:
      volume = signal.volume; // Assume volume from signal is valid (V1)
      if(volume <= 0) {
         Print("Signal volume is zero or negative: ", volume);
         return 0.0;
      }
      break;
   case FixedVolume:
      volume = InpFixedVolume;
      if(volume <= 0) {
         Print("Fixed volume setting is zero or negative: ", volume);
         return 0.0;
      }
      break;
   case RiskPercent: {
      if (InpRiskPercent <= 0) {
         Print("Risk Percent setting is zero or negative: ", InpRiskPercent);
         return 0.0;
      }
      // Get account info
      double balance = AccountInfoDouble(ACCOUNT_BALANCE); // Or ACCOUNT_EQUITY
      double riskAmount = balance * (InpRiskPercent / 100.0);
      double slPoints = MathAbs(signal.open_price - signal.stop_loss) / SymbolInfoDouble(brokerSymbol, SYMBOL_POINT);
      if(slPoints <= 0) {
         Print("Stop Loss distance is zero or negative. Cannot calculate risk-based volume.");
         return 0.0;
      }
      // Get tick value
      double tickValue = SymbolInfoDouble(brokerSymbol, SYMBOL_TRADE_TICK_VALUE);
      double contractSize = SymbolInfoDouble(brokerSymbol, SYMBOL_TRADE_CONTRACT_SIZE); // Needed if tick value isn't per lot per point in account currency
      // Check tick value - calculation might need adjustment based on SYMBOL_TRADE_TICK_VALUE_PROFIT/LOSS and account currency
      if (tickValue <= 0 || contractSize <=0) {
         Print("Tick value (",tickValue,") or Contract Size (", contractSize,") invalid for risk calculation on ", brokerSymbol);
         return 0.0;
      }
      // Formula depends slightly on what tickValue represents. Common formula:
      // Loss per Lot = SL points * Tick Value * (Lots * Contract Size if tick value isn't per lot) - Check Tick value documentation or broker specs!
      // Assuming Tick Value IS the value per 1 lot per point change in account currency:
      double lossPerLot = slPoints * tickValue;
      if(lossPerLot <= 0) {
         Print("Calculated loss per lot is zero or negative. Cannot calculate risk-based volume.");
         return 0.0;
      }
      volume = riskAmount / lossPerLot;
      PrintFormat("Risk Calc: Balance=%.2f, Risk%%=%.2f, RiskAmt=%.2f, SL Pts=%.1f, TickVal=%.5f, LossPerLot=%.2f -> Prelim Vol=%.4f",
                  balance, InpRiskPercent, riskAmount, slPoints, tickValue, lossPerLot, volume);
      break;
   }
   default:
      Print("Unknown volume calculation type!");
      return 0.0;
   }
   //--- Normalize and constrain volume
   volume = NormalizeDouble(volume, 2); // Normalize to standard lot precision first
   // Apply step: volume = floor(volume / lot_step) * lot_step; - This truncates down. Rounding might be better.
   volume = round(volume / lot_step) * lot_step;
   volume = NormalizeDouble(volume, 2); // Re-normalize after step calc
   if(volume < lot_min && lot_min > 0) {
      PrintFormat("Calculated volume %.4f is below minimum %.4f. Using minimum.", volume, lot_min);
      volume = lot_min;
   }
   if(volume > lot_max && lot_max > 0) {
      PrintFormat("Calculated volume %.4f is above maximum %.4f. Using maximum.", volume, lot_max);
      volume = lot_max;
   }
   PrintFormat("Final Calculated Volume for %s: %.2f", brokerSymbol, volume);
   return volume;
}
//+------------------------------------------------------------------+
//| Sends Notifications                                              |
//+------------------------------------------------------------------+
void NotifyUser(string message)
{
   Print(message); // Always print to journal
   if(InpSendPushAlerts) {
      SendNotification(message);
   }
   if(InpSendEmailAlerts) {
      SendMail("Telegram EA Alert: " + _Symbol, message);
   }
}
//+------------------------------------------------------------------+
//| Helper Needed for MT5 Order Placement Adj.                       |
//+------------------------------------------------------------------+
// Adjusted and required code snippet as per MQ5 forum standards/practices for OrderSend compatibility.
// Note: Added normalization here
// double AdjustPriceToSymbolSpecification(const string symbol_name, double price, ENUM_ORDER_TYPE order_type)
// {
//    int     stops_level     = (int)SymbolInfoInteger(symbol_name,SYMBOL_TRADE_STOPS_LEVEL);
//    int     digits          = (int)SymbolInfoInteger(symbol_name,SYMBOL_DIGITS);
//    double  point           = SymbolInfoDouble(symbol_name,SYMBOL_POINT);
//    //--- get current prices
//    MqlTick mql_tick;
//    SymbolInfoTick(symbol_name,mql_tick);
//    //--- check pending order price and correct it if necessary
//    double adjusted_price=price;
//    //--- check buy orders
//    if(order_type==ORDER_TYPE_BUY || order_type==ORDER_TYPE_BUY_LIMIT || order_type==ORDER_TYPE_BUY_STOP) {
//       if(order_type==ORDER_TYPE_BUY) // market order is simpler - might not need this level check
//          adjusted_price=mql_tick.ask;
//       else if(order_type==ORDER_TYPE_BUY_LIMIT) { // Limit order must be below current market
//          if(price > mql_tick.bid - stops_level*point) // Check against BID for buy limit validity
//             adjusted_price = NormalizeDouble(mql_tick.bid - stops_level*point, digits);
//       }
//       else if(order_type==ORDER_TYPE_BUY_STOP) { // Stop order must be above current market
//          if(price < mql_tick.ask + stops_level*point) // Check against ASK for buy stop validity
//             adjusted_price = NormalizeDouble(mql_tick.ask + stops_level*point, digits);
//       }
//    }
//    //--- check sell orders
//    else if(order_type==ORDER_TYPE_SELL || order_type==ORDER_TYPE_SELL_LIMIT || order_type==ORDER_TYPE_SELL_STOP) {
//       if(order_type==ORDER_TYPE_SELL) // Market order
//          adjusted_price=mql_tick.bid;
//       else if(order_type==ORDER_TYPE_SELL_LIMIT) { // Limit order must be above current market
//          if(price < mql_tick.ask + stops_level*point) // Check against ASK for sell limit validity
//             adjusted_price = NormalizeDouble(mql_tick.ask + stops_level*point, digits);
//       }
//       else if(order_type==ORDER_TYPE_SELL_STOP) { // Stop order must be below current market
//          if(price > mql_tick.bid - stops_level*point) // Check against BID for sell stop validity
//             adjusted_price = NormalizeDouble(mql_tick.bid - stops_level*point, digits);
//       }
//    }
//    //--- return price (adjusted if needed)
//    return NormalizeDouble(adjusted_price, digits);
// }
//+------------------------------------------------------------------+
////+------------------------------------------------------------------+
////| Helper to find value for a key in simple JSON (Very Fragile)     |
////+------------------------------------------------------------------+
//string GetJsonValue(const string json, const string key)
//{
//   string searchKey = "\"" + key + "\":";
//   int keyPos = StringFind(json, searchKey);
//   if(keyPos == -1) return ""; // Key not found
//   int valueStart = keyPos + StringLen(searchKey);
//   // Trim leading spaces
//   while (StringGetCharacter(json, valueStart) == ' ' && valueStart < StringLen(json)) valueStart++;
//   char firstChar = StringGetCharacter(json, valueStart);
//   int valueEnd = -1;
//   if(firstChar == '\"') { // It's a string
//      valueStart++; // Move past the opening quote
//      valueEnd = StringFind(json, "\"", valueStart);
//      if(valueEnd == -1) return ""; // Closing quote not found
//   }
//   else { // Assume it's a number or boolean (basic)
//      valueEnd = StringFind(json, ",", valueStart);
//      int braceEnd = StringFind(json, "}", valueStart);
//      if(valueEnd == -1 && braceEnd == -1) return ""; // Neither comma nor brace found
//      if(valueEnd == -1) valueEnd = braceEnd;          // Use brace if comma not found
//      else if(braceEnd != -1) valueEnd = MathMin(valueEnd, braceEnd); // Use whichever comes first
//      // Trim trailing spaces before comma/brace
//      int tempEnd = valueEnd - 1;
//      while(StringGetCharacter(json, tempEnd) == ' ' && tempEnd > valueStart) tempEnd--;
//      valueEnd = tempEnd + 1;
//   }
//   if(valueEnd <= valueStart) return "";
//   return StringSubstr(json, valueStart, valueEnd - valueStart);
//}


//+------------------------------------------------------------------+
//| Handle OPEN BUY/SELL Signal    (OLD)                                  |
//+------------------------------------------------------------------+
// bool HandleOpenSignal(const SignalData &signal, const string brokerSymbol)
// {
//    Print(__FUNCTION__);
//    Print("broker symbol:"+brokerSymbol);
//    //--- Get current market prices
//    if(!SymbolInfoTick(brokerSymbol, g_latest_tick)) {
//       Print("Error getting tick for ", brokerSymbol, ". Error: ", GetLastError());
//       return false;
//    }
//    double ask = NormalizeDouble(g_latest_tick.ask,SymbolInfoInteger(brokerSymbol,SYMBOL_DIGITS));
//    double bid = NormalizeDouble(g_latest_tick.bid,SymbolInfoInteger(brokerSymbol,SYMBOL_DIGITS));
//    double currentPrice = (signal.action == "BUY") ? ask : bid;


//    // Check for valid prices
//    if (currentPrice <= 0 || ask <=0 || bid <= 0) {
//       Print("Invalid current market price (<=0) for ", brokerSymbol," Ask:", ask, " Bid:", bid);
//       return false; // Cannot proceed without valid current price
//    }
//    //--- Normalize signal prices according to broker symbol digits
//    double signal_open_norm = NormalizeDouble(signal.open_price, g_digits);
//    double signal_sl_norm = NormalizeDouble(signal.stop_loss, g_digits);
//    double signal_tp_norm = NormalizeDouble(signal.take_profit, g_digits);
//    //--- Validate prices make sense
//    if (signal.action == "BUY") {
//       if (signal_sl_norm >= signal_open_norm || signal_tp_norm <= signal_open_norm) {
//          PrintFormat("Invalid Buy signal prices for %s: Open=%.5f, SL=%.5f, TP=%.5f", brokerSymbol, signal_open_norm, signal_sl_norm, signal_tp_norm);
//          return false;
//       }
//       // Ensure SL/TP are valid distances from current price if Market Order
//       if (signal_sl_norm >= bid) { // Stop Loss must be below current Bid
//          PrintFormat("Buy SL %.5f is not below current Bid %.5f. Adjusting may be needed by broker or invalid.", signal_sl_norm, bid);
//          // Could potentially adjust SL here slightly down if broker allows minimal distance, but V1 keeps it simple
//       }
//       if (signal_tp_norm <= ask) { // Take Profit must be above current Ask
//          PrintFormat("Buy TP %.5f is not above current Ask %.5f. Adjusting may be needed by broker or invalid.", signal_tp_norm, ask);
//       }
//    }
//    else {   // SELL
//       if (signal_sl_norm <= signal_open_norm || signal_tp_norm >= signal_open_norm) {
//          PrintFormat("Invalid Sell signal prices for %s: Open=%.5f, SL=%.5f, TP=%.5f", brokerSymbol, signal_open_norm, signal_sl_norm, signal_tp_norm);
//          return false;
//       }
//       // Ensure SL/TP are valid distances from current price if Market Order
//       if (signal_sl_norm <= ask) { // Stop Loss must be above current Ask
//          PrintFormat("Sell SL %.5f is not above current Ask %.5f. Adjusting may be needed by broker or invalid.", signal_sl_norm, ask);
//       }
//       if (signal_tp_norm >= bid) { // Take Profit must be below current Bid
//          PrintFormat("Sell TP %.5f is not below current Bid %.5f. Adjusting may be needed by broker or invalid.", signal_tp_norm, bid);
//       }
//    }
//    //--- Check if market moved significantly past SL/TP already (Skip trade)
//    if (signal.action == "BUY") {
//       if (currentPrice < signal_sl_norm || currentPrice > signal_tp_norm ) {
//          Print("Skipping BUY on ", brokerSymbol, ". Current Ask ", currentPrice, " already beyond SL ", signal_sl_norm, " or TP ", signal_tp_norm);
//          return false; // Indicates we processed but skipped
//       }
//    }
//    else {   // SELL
//       if (currentPrice > signal_sl_norm || currentPrice < signal_tp_norm) {
//          Print("Skipping SELL on ", brokerSymbol, ". Current Bid ", currentPrice, " already beyond SL ", signal_sl_norm, " or TP ", signal_tp_norm);
//          return false; // Indicates we processed but skipped
//       }
//    }
//    //--- Calculate Volume
//    double volume = CalculateVolume(signal, brokerSymbol);
//    if(volume <= 0) {
//       Print("Invalid volume calculated (", volume, ") for ", brokerSymbol, ". Skipping trade.");
//       return false;
//    }
//    //--- Determine Market or Pending based on Tolerance
//    double priceDifference = MathAbs(currentPrice - signal_open_norm);
//    Print("priceDifference: "+DoubleToString(priceDifference,Digits()));
//    double tolerancePoints = InpPipsTolerance * g_point;
//    Print("tolerancePoints: "+DoubleToString(tolerancePoints,Digits()));
//    string orderComment = "TG_SigID_" + (string)signal.message_id; // Basic comment
//    Print("orderComment: "+orderComment);
//    //--- Execute Trade
//    bool result = false;
//    trade.SetTypeFillingBySymbol(brokerSymbol); // Ensure correct filling mode

//    if (priceDifference <= tolerancePoints) {
//       Print("priceDifference <= tolerancePoints: "+DoubleToString(priceDifference <= tolerancePoints,Digits()));
//       // Market Order
//       PrintFormat("Attempting Market %s for %s @ Market (Signal Open: %.5f, Current: %.5f, Diff: %.1f pips, Tol: %.1f pips), Vol: %.2f, SL: %.5f, TP: %.5f",
//                   signal.action, brokerSymbol, signal_open_norm, currentPrice, priceDifference / g_point, InpPipsTolerance, volume, signal_sl_norm, signal_tp_norm);
//       if (signal.action == "BUY") {
//          result = trade.Buy(volume, brokerSymbol, ask, signal_sl_norm, signal_tp_norm, orderComment);
//       }
//       else {   // SELL
//          result = trade.Sell(volume, brokerSymbol, bid, signal_sl_norm, signal_tp_norm, orderComment);
//       }
//       if(result) {
//          PrintFormat("Market %s Order successful. Deal: %d, Order: %d", signal.action, (int)trade.ResultDeal(), (int)trade.ResultOrder());
//       }
//       else {
//          PrintFormat("Market %s Order FAILED. Error code: %d. Reason: %s", signal.action, (int)trade.ResultRetcode(), trade.ResultComment());
//       }
//    }
//    else {
//       // Pending Order
//       ENUM_ORDER_TYPE orderType;
//       double entryPrice = signal_open_norm;
//       if(signal.action == "BUY") {
//          orderType = (currentPrice < entryPrice) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_BUY_STOP;
//          if(orderType == ORDER_TYPE_BUY_STOP && entryPrice <= ask) {
//             PrintFormat("Cannot place Buy Stop at "+entryPrice+" when Ask is "+ask+". Price needs adjustment by broker.");
//             // entryPrice = ask + g_point * SymbolInfoInteger(brokerSymbol, SYMBOL_TRADE_STOPS_LEVEL); // Minimal adjustment - potentially complex
//             entryPrice = SymbolInfoDouble(brokerSymbol, SYMBOL_ASK) + SymbolInfoInteger(brokerSymbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point; // Required MT5 adjustment
//             Print("Adjusted Buy Stop price to: "+entryPrice);
//          }
//          if(orderType == ORDER_TYPE_BUY_LIMIT && entryPrice >= bid) {
//             PrintFormat("Cannot place Buy Limit at "+entryPrice+" when Bid is "+bid+". Price needs adjustment by broker.");
//             // entryPrice = bid - g_point * SymbolInfoInteger(brokerSymbol, SYMBOL_TRADE_STOPS_LEVEL); // Minimal adjustment
//             entryPrice = SymbolInfoDouble(brokerSymbol, SYMBOL_BID) - SymbolInfoInteger(brokerSymbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point; // Required MT5 adjustment
//             Print("Adjusted Buy Limit price to: "+entryPrice);
//          }
//       }
//       else { // SELL
//          orderType = (currentPrice > entryPrice) ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_SELL_STOP;
//          if(orderType == ORDER_TYPE_SELL_STOP && entryPrice >= bid) {
//             PrintFormat("Cannot place Sell Stop at "+entryPrice+" when Bid is "+bid+". Price needs adjustment by broker.");
//             // entryPrice = bid - g_point * SymbolInfoInteger(brokerSymbol, SYMBOL_TRADE_STOPS_LEVEL); // Minimal adjustment
//             entryPrice = SymbolInfoDouble(brokerSymbol, SYMBOL_BID) - SymbolInfoInteger(brokerSymbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point; // Required MT5 adjustment
//             Print("Adjusted Sell Stop price to: "+entryPrice);
//          }
//          if(orderType == ORDER_TYPE_SELL_LIMIT && entryPrice <= ask) {
//             PrintFormat("Cannot place Sell Limit at "+entryPrice+" when Ask is "+ask+". Price needs adjustment by broker.");
//             // entryPrice = ask + g_point * SymbolInfoInteger(brokerSymbol, SYMBOL_TRADE_STOPS_LEVEL); // Minimal adjustment
//             entryPrice = SymbolInfoDouble(brokerSymbol, SYMBOL_ASK) + SymbolInfoInteger(brokerSymbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point; // Required MT5 adjustment
//             Print("Adjusted Sell Limit price to: "+entryPrice);
//          }
//       }
//       entryPrice = NormalizeDouble(entryPrice, g_digits); // Re-normalize adjusted price
//       PrintFormat("Attempting Pending %s (%s) for %s @ %.5f (Current: %.5f, Diff: %.1f pips, Tol: %.1f pips), Vol: %.2f, SL: %.5f, TP: %.5f",
//                   signal.action, EnumToString(orderType), brokerSymbol, entryPrice, currentPrice, priceDifference/g_point, InpPipsTolerance, volume
//                   , signal_sl_norm, signal_tp_norm);
//       result = trade.OrderOpen(brokerSymbol,
//                                orderType,
//                                volume,
//                                entryPrice, // profit limit price - not needed for pending order setup
//                                signal_sl_norm, // stop loss
//                                signal_tp_norm, // take profit
//                                ORDER_TIME_GTC, // Expiration type
//                                0,             // Expiration date
//                                orderComment);
//       if(result) {
//          PrintFormat("Pending Order (%s) Placement successful. Order: %d", EnumToString(orderType), (int)trade.ResultOrder());
//       }
//       else {
//          PrintFormat("Pending Order (%s) Placement FAILED. Error code: %d. Reason: %s", EnumToString(orderType), (int)trade.ResultRetcode(), trade.ResultComment());
//       }
//    }
//    return result; // Return true if trade was attempted (succeeded or failed), false if validation stopped it before attempt
// }
