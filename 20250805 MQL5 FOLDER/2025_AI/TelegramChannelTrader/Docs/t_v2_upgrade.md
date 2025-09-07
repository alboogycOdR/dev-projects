Okay, let's recap and pull together the code snippets for the refactored approach where Python handles the complex parsing and MQL5 consumes a simple, delimited string.

**The Agreed-Upon Design (V2/V3 Foundation):**

1.  **Python Script:** Parses the raw Telegram message (using basic methods for now, ideally Regex later). Validates the extracted data. Formats the *valid* signal data into a simple `pipe|delimited` string. Serves this string via Flask. Returns an empty string if no valid signal is ready.
2.  **MQL5 EA:** Fetches the string from the Flask endpoint using `WebRequest`. Uses `StringSplit` to parse the delimited string. Populates the `SignalData` struct from the parts. The rest of the EA logic (`ProcessSignal`, `HandleOpenSignal`, `HandleCloseSignal`, `CalculateVolume`) remains the same as the last working version (using the market-only logic) because it works with the populated `SignalData` struct.

---

**1. Python Script Changes (`TelegramSignalServer_V2.py` - Key Modifications)**

*   Keep the `Telethon` setup, configuration reading, `parse_signal_message` function (though enhancing it with Regex is recommended later), and the main `async` loop.
*   **Modify the Flask `get_signal` endpoint:**

```python
# --- Python Script (Focus on Flask Endpoint Modification) ---

import configparser
import re # Import regex if you plan to use it in parsing
import time
from datetime import datetime, timezone
import logging
import threading

from telethon import TelegramClient, events
from flask import Flask, jsonify # Keep jsonify for now, though we return text

# --- Assume 'latest_signal_data' dictionary and 'data_lock' exist as before ---
# --- Assume 'parse_signal_message' function exists and populates 'latest_signal_data' ---
# Example basic structure of latest_signal_data after successful parsing:
# latest_signal_data = {
#        "message_id": 38,
#        "timestamp": 1744387521,
#        "action": "BUY",  # Already validated/normalized (e.g., uppercase)
#        "symbol": "EURUSD", # Already validated/normalized
#        "volume": 0.02,
#        "open_price": 1.1319,
#        "stop_loss": 1.12142,
#        "take_profit": 1.15867
# }
# Or for CLOSE:
# latest_signal_data = {
#        "message_id": 39,
#        "timestamp": 1744387600,
#        "action": "CLOSE",
#        "symbol": "EURUSD",
#        "open_price": 1.1319
# }


logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

latest_signal_data = {}
data_lock = threading.Lock()
flask_app = Flask(__name__) # Define Flask app

# --- THIS IS THE REFACTORED FLASK ENDPOINT ---
@flask_app.route('/get_signal', methods=['GET'])
def get_signal():
    """Endpoint for MQL5 EA to fetch the latest signal as a delimited string."""
    signal_to_format = None
    with data_lock:
        # Basic check if there's any data to consider
        if latest_signal_data and latest_signal_data.get("message_id"):
             signal_to_format = latest_signal_data.copy()

    if signal_to_format:
        try:
            # --- Data Extraction and Formatting ---
            msg_id = signal_to_format.get("message_id", 0)
            ts = signal_to_format.get("timestamp", 0)
            action = signal_to_format.get("action", "").upper() # Ensure uppercase
            symbol = signal_to_format.get("symbol", "")
            # Optional extra cleaning of symbol in Python:
            # symbol = re.sub(r'[^A-Z0-9]', '', symbol.upper()) # Example: Keep only letters/numbers

            open_price = signal_to_format.get("open_price", 0.0)
            # Set defaults for optional fields if action is CLOSE
            stop_loss = signal_to_format.get("stop_loss", 0.0) if action != "CLOSE" else 0.0
            take_profit = signal_to_format.get("take_profit", 0.0) if action != "CLOSE" else 0.0
            volume = signal_to_format.get("volume", 0.0) if action != "CLOSE" else 0.0

            # --- Basic Validation (Python side) ---
            # Ensure core components required by the format are present
            if not all([msg_id > 0, ts > 0, action in ["BUY", "SELL", "CLOSE"], symbol, open_price > 0]):
                 logging.warning(f"Signal data {msg_id} failed basic validation before formatting string.")
                 return "" # Return empty string for invalid internal data

            # --- Format the pipe-delimited string ---
            # Ensure consistent number formatting (e.g., using f-strings)
            # Adjust precision (.5f for prices, .2f for volume) as appropriate
            signal_string = (
                f"{msg_id}|{ts}|{action}|{symbol}|"
                f"{open_price:.5f}|{stop_loss:.5f}|{take_profit:.5f}|{volume:.2f}"
            )

            logging.info(f"Serving signal data request, formatted string: {signal_string}")
            # --- Return plain text string ---
            # Response mimetype defaults to text/html, which is fine for MQL5
            return signal_string
        except Exception as e:
             logging.error(f"Error formatting signal data: {signal_to_format} - Error: {e}", exc_info=True)
             return "" # Return empty on formatting error
    else:
        logging.info("Serving signal data request: No valid signal data currently available.")
        return "" # Return empty string if no valid signal is stored

# --- Remember to include the rest of your Python script: ---
# - parse_signal_message function (should populate latest_signal_data dictionary)
# - run_flask_server function (unchanged)
# - main_telegram_client async function (unchanged, calls parse_signal_message)
# - if __name__ == "__main__": block (unchanged, starts Flask thread & Telegram client)
# --- Make sure the `parse_signal_message` function correctly sets uppercase actions etc ---

```

---

**2. MQL5 Expert Advisor Changes (`TelegramChannelTraderEA_V2.mq5`)**

*   **Remove:** Delete the entire `ParseSimpleJson` function and the `GetJsonValue` function.
*   **Modify:** Update the `FetchAndProcessSignal` function.
*   **Keep:** The `SignalData` struct, `OnInit`, `OnDeinit`, `OnTimer`, `ProcessSignal`, `HandleSymbol`, `HandleOpenSignal` (with market-only logic), `HandleCloseSignal`, `CalculateVolume`, `NotifyUser`, and `AdjustPriceToSymbolSpecification` should remain mostly unchanged from your *last working V1 version that incorporated the market-only logic*.

```mql5
//+------------------------------------------------------------------+
//|                                       TelegramSignalTrader_V2.mq5|
//|                      ... Properties ...                          |
//+------------------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh>

//--- Input Parameters (Keep as before) ---
// ...

//--- Global Variables (Keep as before) ---
// ... including CTrade trade; MqlTick g_latest_tick; etc.

//--- Function Forward Declarations ---
// REMOVE: string GetJsonValue(const string json, const string key); // No longer needed

//--- Signal Data Structure (Keep as before) ---
struct SignalData {
   long     message_id;
   long     timestamp;
   string   action;     // "BUY", "SELL", "CLOSE"
   string   symbol;     // e.g., "EURUSD" (normalized by Python)
   double   volume;
   double   open_price;
   double   stop_loss;
   double   take_profit;
   bool     is_valid;   // Flag if parsing *this delimited string* succeeded
};


//--- OnInit(), OnDeinit(), OnTimer() (Keep as before) ---
// ... make sure OnTimer calls FetchAndProcessSignal() ...


//+------------------------------------------------------------------+
//| Fetch data from the web service and process delimited string     |
//| REVISED FUNCTION for V2                                          |
//+------------------------------------------------------------------+
void FetchAndProcessSignal()
{
   // --- Variable declarations for WebRequest ---
   char              post_data[];      // Empty for GET
   char              result[];         // Buffer for response body
   string            result_headers;   // Buffer for response headers
   int               timeout_ms = 5000;
   string            headers = "Accept: text/plain\r\nConnection: Close\r\n"; // Changed Accept header slightly

   ArrayResize(post_data, 0);
   ResetLastError();

   //--- Make the Web Request (Keep the robust version) ---
   int res = WebRequest("GET", g_web_service_url, headers, timeout_ms, post_data, result, result_headers);

   //--- Handle WebRequest Errors (Keep robust error checking) ---
   if(res == -1) {
        int err = GetLastError(); String web_err_desc = ""; // ... rest of error handling ...
        PrintFormat("WebRequest Error: %d.%s ...", err, web_err_desc); g_conn_retry_count++; //... etc ...
       return;
   } else if (res != 200) {
        string error_response = CharArrayToString(result, 0, MathMin(ArraySize(result), 500)); // ... rest of error handling ...
        PrintFormat("WebRequest failed: HTTP Code %d ... Response sample: %s", res, error_response); g_conn_retry_count++; // ... etc ...
       return;
   }

   g_conn_retry_count = 0; // Reset counter

   //--- Process the Response String ---
   int result_size = ArraySize(result);
   if(result_size <= 0) {
      // Expected response for "no signal"
      return;
   }

   string signalString = CharArrayToString(result);
   Print("Received signal string: ", signalString);

   // --- NEW StringSplit Parsing Logic ---
   string parts[]; // Dynamic array for split results
   int num_parts = StringSplit(signalString, '|', parts);
   int expected_parts = 8; // Matching Python output format

   if(num_parts != expected_parts) {
      PrintFormat("Error parsing signal string: Expected %d parts, got %d. String: '%s'", expected_parts, num_parts, signalString);
      return; // Cannot process malformed string
   }

   // --- Populate the SignalData Struct from parts ---
   SignalData signal;
   signal.is_valid = false; // Assume invalid until parsed successfully

   // Assign and Convert (Add error checking around conversions if desired)
   signal.message_id = (long)StringToInteger(parts[0]); // Use explicit cast if needed
   signal.timestamp  = (long)StringToInteger(parts[1]); // Use explicit cast if needed
   signal.action     = parts[2]; // Expecting normalized case from Python
   signal.symbol     = parts[3]; // Expecting normalized symbol from Python
   signal.open_price = StringToDouble(parts[4]);
   signal.stop_loss  = StringToDouble(parts[5]);
   signal.take_profit= StringToDouble(parts[6]);
   signal.volume     = StringToDouble(parts[7]);

   // --- Basic Validation (After parsing parts) ---
   // You can add more checks here (e.g., on price values being reasonable)
   if (signal.message_id <= 0 || signal.timestamp <= 0 || signal.action == "" || signal.symbol == "") {
       PrintFormat("Error parsing signal parts: Invalid essential data found (MsgID=%d, TS=%d, Action='%s', Symbol='%s').",
                    signal.message_id, signal.timestamp, signal.action, signal.symbol);
       return;
   }
   // Optional: Re-verify action string
   string upperAction = StringToUpper(signal.action);
   if (upperAction != "BUY" && upperAction != "SELL" && upperAction != "CLOSE") {
        PrintFormat("Error: Invalid action '%s' parsed from signal string part.", signal.action);
        return;
   }
   signal.action = upperAction; // Ensure uppercase just in case

   // Mark as valid *IF* basic parsing succeeded (actual logic happens in ProcessSignal)
   signal.is_valid = true;

   // --- Call the existing processing function ---
   // NO CHANGE HERE: ProcessSignal expects a populated SignalData struct
   if(signal.is_valid) // Pass only if basic parsing looks ok
   {
        ProcessSignal(signal);
   } else {
       Print("Signal marked invalid after parsing delimited string parts.");
   }
}


// --- REMOVED Functions ---
// bool ParseSimpleJson(const string json, SignalData &signal) { ... } // DELETE THIS
// string GetJsonValue(const string json, const string key) { ... }    // DELETE THIS


// --- UNCHANGED Functions (Use your last working versions) ---
// void ProcessSignal(const SignalData &signal) { ... }
// string HandleSymbol(string signalSymbol) { ... } // Keep checks but main logic based on input signal.symbol
// bool HandleOpenSignal(const SignalData &signal, const string brokerSymbol) { ... } // KEEP Market-Only Logic Version
// bool HandleCloseSignal(const SignalData &signal, const string brokerSymbol) { ... } // KEEP
// double CalculateVolume(const SignalData &signal, const string brokerSymbol) { ... } // KEEP
// void NotifyUser(string message) { ... } // KEEP
// double AdjustPriceToSymbolSpecification(...) { ... } // KEEP (Though only Market Orders use it less directly now)

//+------------------------------------------------------------------+

```

Remember to implement the Python changes (especially the `get_signal` function) and the MQL5 changes (deleting old functions, updating `FetchAndProcessSignal`), then recompile and test.