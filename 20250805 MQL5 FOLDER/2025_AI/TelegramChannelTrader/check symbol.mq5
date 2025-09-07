//+------------------------------------------------------------------+
//|                                           check_symbol_fixed.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.01" // Incremented version

// #include <Trade/SymbolInfo.mqh> // Not a standard include and not needed
#include <Trade/Trade.mqh> // Include for potential future use and some enums like ENUM_DAY_OF_WEEK

// Custom Enums are removed - Use standard MQL5 constants/enums

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Print the symbol name first
   Print("--- Symbol Properties for: ", _Symbol, " ---");
Print(Symbol());
//--- String properties (using the bool-returning version for better error checking)
   string string_value; // Reusable variable for string properties

  //  if(SymbolInfoString(_Symbol, SYMBOL_NAME, string_value))
  //     Print("Name: ", string_value);
  //  else
  //     Print("Name: Error retrieving - ", GetLastError());

   if(SymbolInfoString(_Symbol, SYMBOL_DESCRIPTION, string_value))
      Print("Description: ", string_value);
   else
      Print("Description: Error retrieving - ", GetLastError());

   if(SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE, string_value))
      Print("Base Currency: ", string_value);
   else
      Print("Base Currency: Error retrieving - ", GetLastError());

   if(SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT, string_value))
      Print("Profit Currency: ", string_value);
   else
      Print("Profit Currency: Error retrieving - ", GetLastError());

   if(SymbolInfoString(_Symbol, SYMBOL_CURRENCY_MARGIN, string_value))
      Print("Margin Currency: ", string_value);
   else
      Print("Margin Currency: Error retrieving - ", GetLastError());

   if(SymbolInfoString(_Symbol, SYMBOL_PATH, string_value))
      Print("Path: ", string_value);
   else
      Print("Path: Error retrieving - ", GetLastError());

   if(SymbolInfoString(_Symbol, SYMBOL_EXCHANGE, string_value))
      Print("Exchange: ", string_value);
   else
      Print("Exchange: Error retrieving - ", GetLastError());

   if(SymbolInfoString(_Symbol, SYMBOL_ISIN, string_value))
      Print("ISIN: ", string_value);
   else
      Print("ISIN: Error retrieving - ", GetLastError());

   if(SymbolInfoString(_Symbol, SYMBOL_PAGE, string_value))
      Print("Page: ", string_value);
   else
      Print("Page: Error retrieving - ", GetLastError());

   if(SymbolInfoString(_Symbol, SYMBOL_FORMULA, string_value))
      Print("Formula: ", string_value);
   else
      Print("Formula: Error retrieving - ", GetLastError()); // Often empty for non-custom symbols


//--- Integer properties
   Print("Digits: ",             (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)); // Cast for clarity if needed
   Print("Spread: ",             (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
   Print("Spread Float: ",       SymbolInfoInteger(_Symbol, SYMBOL_SPREAD_FLOAT) == 1); // Boolean property
   Print("Ticks Book Depth: ",   (int)SymbolInfoInteger(_Symbol, SYMBOL_TICKS_BOOKDEPTH));
   Print("Trade Calculation Mode: ", EnumToString((ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_CALC_MODE)));
   Print("Trade Execution Mode: ", EnumToString((ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_EXEMODE)));
   Print("Trade Mode: ",         EnumToString((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE)));
   Print("Start Time: ",         (datetime)SymbolInfoInteger(_Symbol, SYMBOL_START_TIME));
   Print("Expiration Time: ",    (datetime)SymbolInfoInteger(_Symbol, SYMBOL_EXPIRATION_TIME)); // Often 0 if not applicable
   Print("Trade Stops Level: ",  (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL));
   Print("Trade Freeze Level: ", (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL));
   Print("Order Fill Policy: ",  EnumToString((ENUM_ORDER_TYPE_FILLING)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE)));
   // SYMBOL_EXPIRATION_MODE returns a bitmask, printing the raw integer might be more informative than trying to EnumToString it directly
   Print("Order Expiration Modes (Bitmask): ", (int)SymbolInfoInteger(_Symbol, SYMBOL_EXPIRATION_MODE));
   // SYMBOL_ORDER_GTC_MODE seems deprecated or less common, might return 0. Check documentation for SYMBOL_EXPIRATION_MODE bits instead.
   // Print("Order GTC Mode: ",     SymbolInfoInteger(_Symbol, SYMBOL_ORDER_GTC_MODE)); // May not be reliable
   Print("Option Mode: ",        EnumToString((ENUM_SYMBOL_OPTION_MODE)SymbolInfoInteger(_Symbol, SYMBOL_OPTION_MODE))); // Only for options
   Print("Option Right: ",       EnumToString((ENUM_SYMBOL_OPTION_RIGHT)SymbolInfoInteger(_Symbol, SYMBOL_OPTION_RIGHT))); // Only for options
   Print("Swap Mode: ",          EnumToString((ENUM_SYMBOL_SWAP_MODE)SymbolInfoInteger(_Symbol, SYMBOL_SWAP_MODE)));
   Print("Swap Rollover 3 Days: ", EnumToString((ENUM_DAY_OF_WEEK)SymbolInfoInteger(_Symbol, SYMBOL_SWAP_ROLLOVER3DAYS)));


//--- Double properties (using the direct-returning version where simpler, bool-version for specific ones)
   Print("Point Size: ",         SymbolInfoDouble(_Symbol, SYMBOL_POINT));

   double double_value; // Reusable variable for double properties retrieved via bool version
 

   

   if(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE, double_value))
      Print("Contract Size: ", double_value);
   else
      Print("Contract Size: Error retrieving - ", GetLastError());

   Print("Margin Initial: ",     SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL));
   Print("Margin Maintenance: ", SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_MAINTENANCE));
   Print("Margin Long: ",        SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_LONG));
   Print("Margin Short: ",       SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_SHORT));
   Print("Margin Limit: ",       SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_LIMIT));
   Print("Margin Stop: ",        SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_STOP));
   Print("Margin Stop Limit: ",  SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_STOPLIMIT));
   Print("Volume Limit: ",       SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT));
   Print("Volume Min: ",         SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
   Print("Volume Max: ",         SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   Print("Volume Step: ",        SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP));
   Print("Swap Long: ",          SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG));
   Print("Swap Short: ",         SymbolInfoDouble(_Symbol, SYMBOL_SWAP_SHORT));
   Print("Session Volume: ",     SymbolInfoDouble(_Symbol, SYMBOL_SESSION_VOLUME)); // Added
   Print("Session Turnover: ",   SymbolInfoDouble(_Symbol, SYMBOL_SESSION_TURNOVER)); // Added
   Print("Session Interest: ",   SymbolInfoDouble(_Symbol, SYMBOL_SESSION_INTEREST)); // Added
   Print("Session Buy Orders Vol: ", SymbolInfoDouble(_Symbol, SYMBOL_SESSION_BUY_ORDERS_VOLUME)); // Added
   Print("Session Sell Orders Vol:", SymbolInfoDouble(_Symbol, SYMBOL_SESSION_SELL_ORDERS_VOLUME)); // Added
   Print("Volume Real: ",        SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_REAL)); // Added - preferred over SYMBOL_VOLUME where available


//--- Current Market Data (using SymbolInfoTick is preferred for real-time)
   Print("--- Current Market Data ---");
   MqlTick latest_tick;
   if(SymbolInfoTick(_Symbol, latest_tick))
     {
      Print("Ask Price (Tick): ", latest_tick.ask);
      Print("Bid Price (Tick): ", latest_tick.bid);
      Print("Last Price (Tick): ", latest_tick.last); // Might be 0 if not applicable
      Print("Volume (Tick): ", (double)latest_tick.volume); // Volume for the last tick
      Print("Volume Real (Tick): ", latest_tick.volume_real); // Precise volume if available
      Print("Time (Tick): ",      (datetime)latest_tick.time); // Seconds resolution
      Print("Time MSC (Tick): ",  latest_tick.time_msc); // Milliseconds resolution
     }
   else
     {
      Print("Could not get latest tick data via SymbolInfoTick. Error: ", GetLastError());
      // Fallback using SymbolInfoDouble (can be less current)
      Print("Ask Price (SymbolInfo): ", SymbolInfoDouble(_Symbol, SYMBOL_ASK));
      Print("Bid Price (SymbolInfo): ", SymbolInfoDouble(_Symbol, SYMBOL_BID));
      Print("Last Price (SymbolInfo): ", SymbolInfoDouble(_Symbol, SYMBOL_LAST));
      Print("Time (SymbolInfo): ",     (datetime)SymbolInfoInteger(_Symbol, SYMBOL_TIME));
      // Fallback Volume - Use SYMBOL_VOLUME (long) or SYMBOL_VOLUME_REAL (double)
      Print("Volume (SymbolInfo - Long): ", (double)SymbolInfoInteger(_Symbol, SYMBOL_VOLUME)); // Total volume for the current session (usually day)
      Print("Volume Real (SymbolInfo - Double): ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_REAL)); // More precise volume if available
     }

   Print("--- End of Symbol Properties ---");

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Clean up resources if any were allocated
   Print("Deinitializing Check Symbol script. Reason code: ", reason);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- This script runs only in OnInit, OnTick is not used.
   
  }
//+------------------------------------------------------------------+