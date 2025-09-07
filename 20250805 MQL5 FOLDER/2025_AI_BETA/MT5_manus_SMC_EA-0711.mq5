//+------------------------------------------------------------------+
//|                                                  MT5_SMC_EA.mq5 |
//|                                                     Manus Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Manus Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "MT5 Expert Advisor based on Smart Money Concept strategy"
#property strict
//MT5 Expert Advisor coded based on a Smart Money Concept strategy that uses the sweep of the Asia high/low, followed by a break of structure (BOS), and an entry on the fair value gap (FVG).
//
//Strategy Parameters:
//- Timeframe: M5
//- Pairs: EURUSD, GBPJPY, XAUUSD
//- Trading hours:
// - London: 07:30–09:30 (London time)
// - New York: 12:30–15:00 (London time)
//- Entry Logic:
// 1. Sweep of Asia high/low
// 2. BOS confirmation
// 3. Entry on return to FVG
//- Risk: 0.5–1% per trade
//- Max trades per day: 2
//- Do not open trades on Saturday or Sunday


//--- Input parameters
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M5;        // Timeframe for the EA to operate on
input string          InpPairs     = "EURUSD,GBPJPY,XAUUSD"; // Comma-separated list of currency pairs to trade
input double          InpRiskPerTrade = 0.5;          // Risk percentage per trade (e.g., 0.5 for 0.5%)
input int             InpMaxTradesPerDay = 2;         // Maximum number of trades allowed per day
input bool            InpBOSCandleClose = true;       // Break of Structure confirmation: true for candle close, false for wick break

//--- Session Time Parameters (Broker Time)
input int             inpAsiaStartHour    = 0;        // Asia session start hour
input int             inpAsiaEndHour      = 7;        // Asia session end hour
input int             inpTradingStartHour = 8;        // Trading session start hour
input int             inpTradingEndHour   = 16;       // Trading session end hour

//--- Visualization Parameters
input bool            inpDrawAsiaLines    = true;     // Draw Asia Session High/Low
input bool            inpDrawBOSLine      = true;     // Draw BOS Line
input bool            inpDrawFVGBox       = true;     // Draw FVG Box
input bool            inpDebugMessages    = true;     // Enable debug messages

//--- Global variables
int      g_daily_trades   = 0;  // Counter for daily trades
datetime g_last_trade_day = 0;  // Stores the last day a trade was opened for daily reset
string   g_obj_prefix;          // Unique prefix for chart objects

#include <Trade/Trade.mqh>
#include <Charts/Chart.mqh>

CTrade trade; // CTrade object for sending trading orders

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Initialize a unique prefix for chart objects to avoid conflicts
   g_obj_prefix = "SMC_EA_" + Symbol() + "_" + EnumToString(InpTimeframe) + "_";

//--- Clean up objects from a previous run
   DeleteAllObjects();
   
   if(inpDebugMessages)
     {
      Print("EA Initializing...");
      Print("Asia Session: ", inpAsiaStartHour, ":00 - ", inpAsiaEndHour, ":00");
      Print("Trading Session: ", inpTradingStartHour, ":00 - ", inpTradingEndHour, ":00");
     }

//--- Initialize CTrade object (no explicit Init() call needed in MQL5)

//--- Check for valid timeframe
   if(InpTimeframe != PERIOD_M5)
     {
      Print("Error: Only M5 timeframe is supported. Please set the EA to M5.");
      return(INIT_FAILED);
     }

//--- Check for valid risk percentage
   if(InpRiskPerTrade <= 0 || InpRiskPerTrade > 100)
     {
      Print("Error: Risk per trade must be between 0 and 100.");
      return(INIT_FAILED);
     }

//--- Check for valid max trades per day
   if(InpMaxTradesPerDay < 0)
     {
      Print("Error: Maximum trades per day cannot be negative.");
      return(INIT_FAILED);
     }

//--- Initialization successful
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Deinitialization logic can be added here if needed
   DeleteAllObjects();
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(inpDebugMessages) Print("--- New Tick ---");
//--- Delete previous chart objects to avoid clutter
   DeleteAllObjects();

//--- Get current time
   MqlDateTime current_time;
   TimeCurrent(current_time);

//--- Check if it\'s Saturday or Sunday (no trading on weekends)
   if(current_time.day_of_week == SATURDAY || current_time.day_of_week == SUNDAY)
     {
      if(inpDebugMessages) Print("Weekend. No trading.");
      return;
     }

   // Reset daily trade count at the start of a new day
   if(current_time.day != g_last_trade_day)
     {
      g_daily_trades = 0;
      g_last_trade_day = current_time.day;
     }

   if(g_daily_trades >= InpMaxTradesPerDay)
     {
      if(inpDebugMessages) Print("Max trades per day reached (", g_daily_trades, "/", InpMaxTradesPerDay, ").");
      return; // Max trades per day reached
     }

   // Check trading hours
   bool is_trading_session = (current_time.hour >= inpTradingStartHour && current_time.hour < inpTradingEndHour);

   if(!is_trading_session)
     {
      if(inpDebugMessages) Print("Outside trading hours. Current broker hour: ", current_time.hour);
      return; // Outside trading hours, stop processing for this tick
     }
   if(inpDebugMessages) Print("Inside trading hours. Proceeding with checks...");

   //--- Get Asia session high/low
   datetime asia_start_time, asia_end_time;
   double asia_high = 0, asia_low = 999999;
   GetAsiaSessionHighLow(asia_start_time, asia_end_time, asia_high, asia_low);

   if(asia_high == 0)
     {
      if(inpDebugMessages) Print("Could not determine Asia session range. Waiting for data...");
      return;
     }

   if(inpDebugMessages) Print("Asia Session Range: High=", DoubleToString(asia_high, _Digits), ", Low=", DoubleToString(asia_low, _Digits));

   if(inpDrawAsiaLines && asia_high > 0)
     {
      DrawHorizontalLine("AsiaHigh", asia_high, clrGreen, STYLE_DOT, 1, "Asia High");
      DrawHorizontalLine("AsiaLow", asia_low, clrRed, STYLE_DOT, 1, "Asia Low");
     }

   // Refined Sweep Detection
   // A true sweep involves price taking out a high/low and then reversing.
   // For simplicity and as a starting point, let\'s define a sweep as:
   // For bullish setup: price goes below Asia low and then closes above it within a few candles.
   // For bearish setup: price goes above Asia high and then closes below it within a few candles.

   bool swept_asia_low = false;
   bool swept_asia_high = false;

   MqlRates rates_tick[];
   int copied_tick = CopyRates(Symbol(), InpTimeframe, 0, 5, rates_tick); // Get last 5 candles for sweep detection

   if(copied_tick < 5)
     {
      if(inpDebugMessages) Print("Not enough bars to detect sweep. Bars copied: ", copied_tick);
      return;
     }

   if(inpDebugMessages) Print("Checking for sweep of Asia High/Low...");

   // Check for sweep of Asia low (bullish setup)
   for(int i = 1; i < 5; i++) // Look back 5 candles for a sweep, starting from closed candle
     {
      if(rates_tick[i].low < asia_low && rates_tick[i].close > asia_low)
        {
         swept_asia_low = true;
         if(inpDebugMessages) Print("Sweep of Asia LOW detected on candle at ", TimeToString(rates_tick[i].time));
         break;
        }
     }

   // Check for sweep of Asia high (bearish setup)
   for(int i = 1; i < 5; i++) // Look back 5 candles for a sweep, starting from closed candle
     {
      if(rates_tick[i].high > asia_high && rates_tick[i].close < asia_high)
        {
         swept_asia_high = true;
         if(inpDebugMessages) Print("Sweep of Asia HIGH detected on candle at ", TimeToString(rates_tick[i].time));
         break;
        }
     }


   // If Asia low was swept, look for bullish BOS and FVG
   if(swept_asia_low)
     {
      if(inpDebugMessages) Print("Bullish setup active: Asia Low swept. Looking for BOS...");
      // Identify the most recent swing high for bullish BOS
      double structure_level_bullish = FindSwingHigh(20); // Look back 20 candles for swing high

      if(structure_level_bullish > 0 && CheckBOS(ORDER_TYPE_BUY, structure_level_bullish, InpBOSCandleClose))
        {
         if(inpDebugMessages) Print("Bullish BOS confirmed above level: ", structure_level_bullish, ". Searching for FVG...");
         if(inpDrawBOSLine)
            DrawHorizontalLine("BOS_Bullish", structure_level_bullish, clrDodgerBlue, STYLE_SOLID, 2, "Bullish BOS");
         // BOS confirmed, now look for FVG for entry

         // Search for a recent FVG (e.g., in the last 10 candles)
         bool fvg_found = false;
         for(int i = 1; i <= 10; i++)
           {
            double fvg_high, fvg_low;
            datetime fvg_start_time, fvg_end_time;
            if(CheckFVG(i, fvg_high, fvg_low, fvg_start_time, fvg_end_time)) // Check FVG on current/recent candles
              {
               // Check if it's a valid bullish FVG
               MqlRates fvg_rates[];
               CopyRates(Symbol(), InpTimeframe, i, 3, fvg_rates);
               if(fvg_rates[2].high < fvg_rates[0].low) // Bullish FVG pattern
                 {
                  fvg_found = true;
                  if(inpDebugMessages) Print("Bullish FVG found. High: ", DoubleToString(fvg_high, _Digits), ", Low: ", DoubleToString(fvg_low, _Digits));
                  if(inpDrawFVGBox)
                     DrawRectangle("FVG_Bullish", fvg_start_time, fvg_high, fvg_end_time, fvg_low, clrLightGreen, true);
                  // Entry logic: price returns to FVG
                  if(SymbolInfoDouble(Symbol(), SYMBOL_BID) >= fvg_low && SymbolInfoDouble(Symbol(), SYMBOL_BID) <= fvg_high) // For buy, price returns to FVG
                    {
                     if(inpDebugMessages) Print("Price entered Bullish FVG. Preparing to BUY.");
                     // Calculate lot size based on risk percentage
                     // WARNING: Simplified lot calculation. Does not account for stop loss distance or currency conversion.
                     double lot_size = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPerTrade / 100 / (SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE) * 100000), 2); // Simplified lot calculation
                     double stop_loss = fvg_low - 10 * _Point; // Example SL below FVG (adjust as needed)
                     double take_profit = SymbolInfoDouble(Symbol(), SYMBOL_BID) + (SymbolInfoDouble(Symbol(), SYMBOL_BID) - stop_loss) * 2; // Example TP 2 times SL (adjust as needed)
               
               // Send buy order
               if(trade.Buy(lot_size, Symbol(), 0, 0, 0, "SMC_EA_Buy"))
                 {
                  Print("Buy order sent successfully!");
                  g_daily_trades++; // Increment daily trade count
                 }
               else
                 {
                  Print("Failed to send buy order. Error: ", GetLastError());
                 }
               Print("Bullish setup: Swept Asia Low, BOS, FVG found. Ready to buy.");
                    }
                  else
                    {
                     if(inpDebugMessages) Print("Price is not in FVG range. Current Bid: ", SymbolInfoDouble(Symbol(), SYMBOL_BID));
                    }
                  break; // Exit loop once FVG is found and processed
                 }
              }
           }
         if(!fvg_found && inpDebugMessages) Print("No recent Bullish FVG found after BOS.");
        }
      else
        {
         if(inpDebugMessages) Print("No bullish BOS confirmed yet.");
        }
     }

   // If Asia high was swept, look for bearish BOS and FVG
   if(swept_asia_high)
     {
      if(inpDebugMessages) Print("Bearish setup active: Asia High swept. Looking for BOS...");
      // Identify the most recent swing low for bearish BOS
      double structure_level_bearish = FindSwingLow(20); // Look back 20 candles for swing low

      if(structure_level_bearish > 0 && CheckBOS(ORDER_TYPE_SELL, structure_level_bearish, InpBOSCandleClose))
        {
         if(inpDebugMessages) Print("Bearish BOS confirmed below level: ", structure_level_bearish, ". Searching for FVG...");
         if(inpDrawBOSLine)
            DrawHorizontalLine("BOS_Bearish", structure_level_bearish, clrHotPink, STYLE_SOLID, 2, "Bearish BOS");
         // BOS confirmed, now look for FVG for entry

         // Search for a recent FVG (e.g., in the last 10 candles)
         bool fvg_found = false;
         for(int i = 1; i <= 10; i++)
           {
            double fvg_high, fvg_low;
            datetime fvg_start_time, fvg_end_time;
            if(CheckFVG(i, fvg_high, fvg_low, fvg_start_time, fvg_end_time)) // Check FVG on current/recent candles
              {
               // Check if it's a valid bearish FVG
               MqlRates fvg_rates[];
               CopyRates(Symbol(), InpTimeframe, i, 3, fvg_rates);
               if(fvg_rates[2].low > fvg_rates[0].high) // Bearish FVG pattern
                 {
                  fvg_found = true;
                  if(inpDebugMessages) Print("Bearish FVG found. High: ", DoubleToString(fvg_high, _Digits), ", Low: ", DoubleToString(fvg_low, _Digits));
                  if(inpDrawFVGBox)
                     DrawRectangle("FVG_Bearish", fvg_start_time, fvg_high, fvg_end_time, fvg_low, clrMistyRose, true);
                  // Entry logic: price returns to FVG
                  if(SymbolInfoDouble(Symbol(), SYMBOL_ASK) <= fvg_high && SymbolInfoDouble(Symbol(), SYMBOL_ASK) >= fvg_low) // For sell, price returns to FVG
                    {
                     if(inpDebugMessages) Print("Price entered Bearish FVG. Preparing to SELL.");
                     // Calculate lot size based on risk percentage
                     // WARNING: Simplified lot calculation. Does not account for stop loss distance or currency conversion.
                     double lot_size = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPerTrade / 100 / (SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE) * 100000), 2); // Simplified lot calculation
                     double stop_loss = fvg_high + 10 * _Point; // Example SL above FVG (adjust as needed)
                     double take_profit = SymbolInfoDouble(Symbol(), SYMBOL_ASK) - (stop_loss - SymbolInfoDouble(Symbol(), SYMBOL_ASK)) * 2; // Example TP 2 times SL (adjust as needed)

               // Send sell order
               if(trade.Sell(lot_size, Symbol(), 0, 0, 0, "SMC_EA_Sell"))
                 {
                  Print("Sell order sent successfully!");
                  g_daily_trades++; // Increment daily trade count
                 }
               else
                 {
                  Print("Failed to send sell order. Error: ", GetLastError());
                 }
               Print("Bearish setup: Swept Asia High, BOS, FVG found. Ready to sell.");
                    }
                  else
                    {
                     if(inpDebugMessages) Print("Price is not in FVG range. Current Ask: ", SymbolInfoDouble(Symbol(), SYMBOL_ASK));
                    }
                  break; // Exit loop once FVG is found and processed
                 }
              }
           }
         if(!fvg_found && inpDebugMessages) Print("No recent Bearish FVG found after BOS.");
        }
      else
        {
         if(inpDebugMessages) Print("No bearish BOS confirmed yet.");
        }
     }

  }
//+------------------------------------------------------------------+
//| Drawing Functions                                                |
//+------------------------------------------------------------------+
void DeleteAllObjects()
  {
   ObjectsDeleteAll(0, g_obj_prefix);
  }

void DrawHorizontalLine(string name, double price, color line_color, ENUM_LINE_STYLE style, int width = 1, string text = "")
  {
   string obj_name = g_obj_prefix + name;
   if(ObjectFind(0, obj_name) < 0)
     {
      ObjectCreate(0, obj_name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, obj_name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, width);
      ObjectSetString(0, obj_name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
     }
  }

void DrawRectangle(string name, datetime time1, double price1, datetime time2, double price2, color rect_color, bool fill)
  {
   string obj_name = g_obj_prefix + name;
   if(ObjectFind(0, obj_name) < 0)
     {
      ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, time1, price1, time2, price2);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, rect_color);
      ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
      ObjectSetInteger(0, obj_name, OBJPROP_FILL, fill);
     }
  }

//+------------------------------------------------------------------+
//| Get Asia Session High/Low                                        |
//+------------------------------------------------------------------+
void GetAsiaSessionHighLow(datetime &asia_start_time, datetime &asia_end_time, double &asia_high, double &asia_low)
  {
   // Look back 2 days of data to be safe
   MqlRates rates[];
   // Correctly calculate bars to copy: (seconds in 2 days) / (seconds per bar)
   int bars_to_copy = (2 * 24 * 60 * 60) / (int)PeriodSeconds(InpTimeframe);
   int copied = CopyRates(Symbol(), InpTimeframe, 0, bars_to_copy, rates);

   if(copied <= 0)
     {
      if(inpDebugMessages) Print("Error: Could not get historical data for Asia session.");
      return;
     }

   asia_high = 0;
   asia_low  = 999999;

   // Define Asia session based on input hours
   datetime current_chart_time = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(current_chart_time, dt);

   dt.hour = inpAsiaStartHour;
   dt.min = 0;
   dt.sec = 0;
   asia_start_time = StructToTime(dt);

   dt.hour = inpAsiaEndHour;
   dt.min = 0;
   dt.sec = 0;
   asia_end_time = StructToTime(dt);

   // If the defined Asia session for today has not started yet, use yesterday's session
   if(current_chart_time < asia_start_time)
     {
      asia_start_time -= 24 * 60 * 60; // Go back one day
      asia_end_time   -= 24 * 60 * 60; // Go back one day
     }

   for(int i = copied - 1; i >= 0; i--)
     {
      if(rates[i].time >= asia_start_time && rates[i].time < asia_end_time)
        {
         if(rates[i].high > asia_high)
            asia_high = rates[i].high;
         if(rates[i].low < asia_low)
            asia_low = rates[i].low;
        }
     }
  }


//+------------------------------------------------------------------+
//| Check for Break of Structure (BOS)                               |
//+------------------------------------------------------------------+
bool CheckBOS(ENUM_ORDER_TYPE order_type, double level, bool use_candle_close)
  {
   MqlRates rates[];
   int      copied = CopyRates(Symbol(), InpTimeframe, 0, 3, rates); // Get last 3 candles

   if(copied < 2)
     {
      if(inpDebugMessages) Print("Error: Not enough historical data for BOS check.");
      return(false);
     }

   // Check the most recently closed candle (index 1)
   if(order_type == ORDER_TYPE_BUY) // Looking for bullish BOS (break above level)
     {
      if(use_candle_close)
        {
         if(rates[1].close > level)
            return(true);
        }
      else // Wick break
        {
         if(rates[1].high > level)
            return(true);
        }
     }
   else if(order_type == ORDER_TYPE_SELL) // Looking for bearish BOS (break below level)
     {
      if(use_candle_close)
        {
         if(rates[1].close < level)
            return(true);
        }
      else // Wick break
        {
         if(rates[1].low < level)
            return(true);
        }
     }
   return(false);
  }


//+------------------------------------------------------------------+
//| Check for Fair Value Gap (FVG)                                   |
//+------------------------------------------------------------------+
bool CheckFVG(int index, double &fvg_high, double &fvg_low, datetime &fvg_start_time, datetime &fvg_end_time)
  {
   MqlRates rates[];
   int      copied = CopyRates(Symbol(), InpTimeframe, index, 3, rates); // Get 3 candles starting from index

   if(copied < 3)
     {
      // This can happen normally when checking near the start of history, so no error print
      return(false);
     }

   // FVG is identified by a 3-candle pattern where the first and third candles do not overlap
   // Bullish FVG: rates[2].high < rates[0].low (gap between first and third candle)
   // Bearish FVG: rates[2].low > rates[0].high (gap between first and third candle)

   // Bullish FVG
   if(rates[2].high < rates[0].low)
     {
      fvg_high = rates[0].low;
      fvg_low  = rates[2].high;
      fvg_start_time = rates[2].time;
      fvg_end_time   = rates[0].time;
      return(true);
     }

   // Bearish FVG
   if(rates[2].low > rates[0].high)
     {
      fvg_high = rates[2].low;
      fvg_low  = rates[0].high;
      fvg_start_time = rates[2].time;
      fvg_end_time   = rates[0].time;
      return(true);
     }

   return(false);
  }


//+------------------------------------------------------------------+
//| Find Swing High/Low                                              |
//+------------------------------------------------------------------+
double FindSwingHigh(int lookback_period)
  {
   double swing_high = 0;
   for(int i = 0; i < lookback_period; i++)
     {
      double current_high = iHigh(Symbol(), InpTimeframe, i);
      if(current_high > swing_high)
         swing_high = current_high;
     }
   return(swing_high);
  }

double FindSwingLow(int lookback_period)
  {
   double swing_low = 999999;
   for(int i = 0; i < lookback_period; i++)
     {
      double current_low = iLow(Symbol(), InpTimeframe, i);
      if(current_low < swing_low)
         swing_low = current_low;
     }
   return(swing_low);
  }


