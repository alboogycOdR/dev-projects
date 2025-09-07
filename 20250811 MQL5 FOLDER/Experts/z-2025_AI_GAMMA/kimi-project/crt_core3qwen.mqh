//+------------------------------------------------------------------+
//| CRT_Core.mqh – Final Enhanced Version with Chart Visualizations   |
//+------------------------------------------------------------------+
#property library
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <ChartObjects\ChartObjectsLines.mqh>

//--- FEATURE TOGGLES ------------------------------------------------
input bool Use_FVG_SizeValidation = true;      // Validate FVG size
input double MinFVGSizePips = 10.0;           // Minimum FVG size in pips
input bool Use_TimeBasedFiltering = true;     // Trade only during specific hours
input int  TradingStartHour = 8;              // 8 AM
input int  TradingEndHour = 20;               // 8 PM
input bool Use_ATR_SL = true;                 // Use ATR-based SL instead of CRT levels
input int  ATRPeriod = 14;                    // ATR period
input double ATRMultiplier = 1.5;              // ATR multiplier for SL
input bool DebugEngulfing = true;             // Show engulfing pattern detection
input bool Use_EntryConfirmation = true;      // Require candle confirmation
input bool Show_Chart_Visualizations = true;  // Toggle for chart visualizations
input bool Show_CRT_Range = true;             // Show CRT range on chart
input bool Show_FVG_Zones = true;             // Show FVG zones
input bool Show_Swing_Points = true;          // Show swing points
input bool Show_State_Indicators = true;      // Show current state

//--- ENUMS & STRUCT ------------------------------------------------
enum ENUM_SETUP_STATE { IDLE, SWEEP, MSS, FVG, ENTRY };
enum ENUM_BIAS        { NEUTRAL, BULLISH, BEARISH };

struct CRT_State
{
   string            symbol;
   ENUM_BIAS         bias;
   datetime          bias_time;
   double            crt_high;
   double            crt_low;
   double            sweep_level;     // CRITICAL FIX #1: Store sweep level
   double            mss_level;       // Correct MSS level (not sweep level)
   datetime          sweep_time;      // Time of sweep
   datetime          mss_confirmed_time; // CRITICAL FIX #2: MSS confirmation time
   double            fvg_high;
   double            fvg_low;
   ENUM_SETUP_STATE  bull_state;
   ENUM_SETUP_STATE  bear_state;
   
   // For visualization
   double            swing_high;
   double            swing_low;
   datetime          swing_high_time;
   datetime          swing_low_time;
};

//--- STATE HELPERS --------------------------------------------------
void ResetState(CRT_State &s, const string symbol_to_set)
{
   s.bias       = NEUTRAL;
   s.bias_time  = 0;
   s.crt_high   = 0.0;
   s.crt_low    = 0.0;
   s.sweep_level = 0.0;
   s.mss_level  = 0.0;
   s.sweep_time = 0;
   s.mss_confirmed_time = 0;
   s.fvg_high   = 0.0;
   s.fvg_low    = 0.0;
   s.swing_high = 0.0;
   s.swing_low  = 0.0;
   s.swing_high_time = 0;
   s.swing_low_time = 0;
   s.bull_state = IDLE;
   s.bear_state = IDLE;
   s.symbol     = symbol_to_set;
}

//--- HELPER FUNCTIONS -----------------------------------------------
bool IsBullishEngulfing(MqlRates &rates[]) 
{
   bool result = (rates[1].open < rates[1].close && 
                  rates[0].open > rates[1].close && 
                  rates[0].close > rates[1].open);
   if(DebugEngulfing && result)
      Print("ENGULFING BULLISH DETECTED");
   return result;
}

bool IsBearishEngulfing(MqlRates &rates[]) 
{
   bool result = (rates[1].open > rates[1].close && 
                  rates[0].open < rates[1].close && 
                  rates[0].close < rates[1].open);
   if(DebugEngulfing && result)
      Print("ENGULFING BEARISH DETECTED");
   return result;
}

//--- FIND SWING POINTS (CRITICAL FIX #1) ----------------------------
double FindLastSwingHigh(MqlRates &m15[], int start_index, int max_bars/*=20*/, datetime &swing_time)
{
   double high = m15[start_index].high;
   swing_time = m15[start_index].time;
   
   for(int i = start_index+1; i < ArraySize(m15) && i < start_index+max_bars; i++)
   {
      if(m15[i].high > high)
      {
         high = m15[i].high;
         swing_time = m15[i].time;
      }
   }
   return high;
}

double FindLastSwingLow(MqlRates &m15[], int start_index, int max_bars/*=20*/, datetime &swing_time)
{
   double low = m15[start_index].low;
   swing_time = m15[start_index].time;
   
   for(int i = start_index+1; i < ArraySize(m15) && i < start_index+max_bars; i++)
   {
      if(m15[i].low < low)
      {
         low = m15[i].low;
         swing_time = m15[i].time;
      }
   }
   return low;
}

//--- CRT BIAS (with validation) ------------------------------------
ENUM_BIAS CRT_Bias(const string sym, datetime &range_time, datetime &sweep_time,
                   double &range_high, double &range_low)
{
   if(!SymbolSelect(sym, true)) return NEUTRAL;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(sym, PERIOD_H4, 1, 2, r) != 2) return NEUTRAL;

   range_time = r[1].time;
   sweep_time = r[0].time;
   range_high = r[1].high;
   range_low  = r[1].low;

   if(r[0].low < range_low && r[0].close >= range_low) return BULLISH;
   if(r[0].high > range_high && r[0].close <= range_high) return BEARISH;
   return NEUTRAL;
}

//--- M15 STATE STEP (with critical MSS fixes and visualization support) ------
void M15_Step(CRT_State &s)
{
   if(s.bias != BULLISH && s.bias != BEARISH) return;

   MqlRates m15[];
   ArraySetAsSeries(m15, true);
   if(CopyRates(s.symbol, PERIOD_M15, 0, 25, m15) < 3) return;

   double pip_size = SymbolInfoDouble(s.symbol, SYMBOL_POINT) * 10; // 1 pip size
   double fvg_size = (s.bias == BULLISH) ? (s.fvg_low - s.fvg_high)/pip_size : (s.fvg_high - s.fvg_low)/pip_size;

   if(s.bias == BULLISH)
   {
      switch(s.bull_state)
      {
         case IDLE:
            if(m15[1].low < s.crt_low)
            {
               // CRITICAL FIX #1: Store sweep level/time
               s.sweep_level = m15[1].low;
               s.sweep_time = m15[1].time;
               s.bull_state = SWEEP;
               Print(s.symbol, " | BULL | IDLE→SWEEP | Sweep: ", s.sweep_level);
            }
            break;

         case SWEEP:
            // CRITICAL FIX #1: Find the last swing HIGH before sweep
            // This is the level that must be broken for MSS confirmation
            if(s.mss_level == 0.0)
            {
               datetime swing_time;
               s.mss_level = FindLastSwingHigh(m15, 2, 10, swing_time);
               s.swing_high = s.mss_level;
               s.swing_high_time = swing_time;
               Print(s.symbol, " | BULL | SWEEP | MSS Level Set: ", s.mss_level);
            }
            
            // Transition to MSS when price breaks above the swing HIGH
            if(m15[1].high > s.mss_level)
            {
               s.bull_state = MSS;
               s.mss_confirmed_time = m15[1].time; // CRITICAL FIX #2
               Print(s.symbol, " | BULL | SWEEP→MSS | MSS Confirmed: ", s.mss_level, 
                     " | Time: ", TimeToString(s.mss_confirmed_time));
            }
            break;

         case MSS:
            for(int i=2; i<ArraySize(m15); i++)
            {
               if(m15[i-2].high < m15[i].low && 
                  m15[i-1].low > m15[i-2].high && 
                  m15[i-1].high > m15[i].low)
               {
                  if(Use_FVG_SizeValidation)
                  {
                     double detected_fvg_size = (m15[i].low - m15[i-2].high)/pip_size;
                     if(detected_fvg_size < MinFVGSizePips) 
                     {
                        Print(s.symbol, " | BULL | FVG TOO SMALL: ", detected_fvg_size, " pips (min: ", MinFVGSizePips, ")");
                        continue;
                     }
                  }
                  
                  // CRITICAL FIX #2: Validate FVG is after MSS confirmation
                  if(m15[i].time > s.mss_confirmed_time)
                  {
                     s.fvg_high = m15[i-2].high;
                     s.fvg_low  = m15[i].low;
                     s.bull_state = FVG;
                     Print(s.symbol, " | BULL | MSS→FVG | FVG: ", s.fvg_low, "-", s.fvg_high, 
                           " | Size: ", fvg_size, " pips | Validated");
                     break;
                  }
                  else
                  {
                     Print(s.symbol, " | BULL | MSS→FVG | FVG: ", s.fvg_low, "-", s.fvg_high,
                           " | Rejected | Too old: ", TimeToString(m15[i].time), " <= ", TimeToString(s.mss_confirmed_time));
                  }
               }
            }
            break;

         case FVG:
            if(m15[1].low < s.fvg_high)
            {
               if(!Use_EntryConfirmation || IsBullishEngulfing(m15))
               {
                  s.bull_state = ENTRY;
                  Print(s.symbol, " | BULL | FVG→ENTRY | FVG: ", s.fvg_low, "-", s.fvg_high);
               }
            }
            break;
      }
   }
   else // BEARISH
   {
      switch(s.bear_state)
      {
         case IDLE:
            if(m15[1].high > s.crt_high)
            {
               // CRITICAL FIX #1: Store sweep level/time
               s.sweep_level = m15[1].high;
               s.sweep_time = m15[1].time;
               s.bear_state = SWEEP;
               Print(s.symbol, " | BEAR | IDLE→SWEEP | Sweep: ", s.sweep_level);
            }
            break;

         case SWEEP:
            // CRITICAL FIX #1: Find the last swing LOW before sweep
            // This is the level that must be broken for MSS confirmation
            if(s.mss_level == 0.0)
            {
               datetime swing_time;
               s.mss_level = FindLastSwingLow(m15, 2, 10, swing_time);
               s.swing_low = s.mss_level;
               s.swing_low_time = swing_time;
               Print(s.symbol, " | BEAR | SWEEP | MSS Level Set: ", s.mss_level);
            }
            
            // Transition to MSS when price breaks below the swing LOW
            if(m15[1].low < s.mss_level)
            {
               s.bear_state = MSS;
               s.mss_confirmed_time = m15[1].time; // CRITICAL FIX #2
               Print(s.symbol, " | BEAR | SWEEP→MSS | MSS Confirmed: ", s.mss_level, 
                     " | Time: ", TimeToString(s.mss_confirmed_time));
            }
            break;

         case MSS:
            for(int i=2; i<ArraySize(m15); i++)
            {
               if(m15[i-2].low > m15[i].high &&
                  m15[i-1].high < m15[i-2].low &&
                  m15[i-1].low < m15[i].high)
               {
                  if(Use_FVG_SizeValidation)
                  {
                     double detected_fvg_size = (m15[i-2].low - m15[i].high)/pip_size;
                     if(detected_fvg_size < MinFVGSizePips) 
                     {
                        Print(s.symbol, " | BEAR | FVG TOO SMALL: ", detected_fvg_size, " pips (min: ", MinFVGSizePips, ")");
                        continue;
                     }
                  }
                  
                  // CRITICAL FIX #2: Validate FVG is after MSS confirmation
                  if(m15[i].time > s.mss_confirmed_time)
                  {
                     s.fvg_high = m15[i].high;
                     s.fvg_low  = m15[i-2].low;
                     s.bear_state = FVG;
                     Print(s.symbol, " | BEAR | MSS→FVG | FVG: ", s.fvg_low, "-", s.fvg_high, 
                           " | Size: ", fvg_size, " pips | Validated");
                     break;
                  }
                  else
                  {
                     Print(s.symbol, " | BEAR | MSS→FVG | FVG: ", s.fvg_low, "-", s.fvg_high,
                           " | Rejected | Too old: ", TimeToString(m15[i].time), " <= ", TimeToString(s.mss_confirmed_time));
                  }
               }
            }
            break;

         case FVG:
            if(m15[1].high > s.fvg_low)
            {
               if(!Use_EntryConfirmation || IsBearishEngulfing(m15))
               {
                  s.bear_state = ENTRY;
                  Print(s.symbol, " | BEAR | FVG→ENTRY | FVG: ", s.fvg_low, "-", s.fvg_high);
               }
            }
            break;
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Swing Points on Chart                                      |
//+------------------------------------------------------------------+
void DrawSwingPoints(CRT_State &s)
{
   if(!Show_Chart_Visualizations || !Show_Swing_Points) return;
   
   string prefix = "CRT_Swing_";
   string objName;
   double price;
   datetime time;
   color lineColor;
   int width = 1;
   
   // Clear previous swing points
   ObjectsDeleteAll(0, prefix + "High");
   ObjectsDeleteAll(0, prefix + "Low");
   
   // Draw swing high
   if(s.swing_high > 0)
   {
      objName = prefix + "High";
      price = s.swing_high;
      time = s.swing_high_time;
      lineColor = clrBlue;
      
      // Horizontal line for swing high
      ObjectCreate(0, objName, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, "Swing High: " + DoubleToString(price, _Digits));
      
      // Label for swing high
      string labelName = objName + "_Label";
      ObjectCreate(0, labelName, OBJ_TEXT, 0, time, price);
      ObjectSetString(0, labelName, OBJPROP_TEXT, " Swing High");
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   }
   
   // Draw swing low
   if(s.swing_low > 0)
   {
      objName = prefix + "Low";
      price = s.swing_low;
      time = s.swing_low_time;
      lineColor = clrRed;
      
      // Horizontal line for swing low
      ObjectCreate(0, objName, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, "Swing Low: " + DoubleToString(price, _Digits));
      
      // Label for swing low
      string labelName = objName + "_Label";
      ObjectCreate(0, labelName, OBJ_TEXT, 0, time, price);
      ObjectSetString(0, labelName, OBJPROP_TEXT, " Swing Low");
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   }
}

//+------------------------------------------------------------------+
//| Draw CRT Range on Chart                                         |
//+------------------------------------------------------------------+
void DrawCRTRange(CRT_State &s)
{
   if(!Show_Chart_Visualizations || !Show_CRT_Range) return;
   
   string prefix = "CRT_Range_";
   string objName;
   color fillColor;
   int transparency = 70;
   
   // Clear previous CRT range
   ObjectsDeleteAll(0, prefix);
   
   // Draw CRT range
   if(s.crt_high > 0 && s.crt_low > 0)
   {
      // H4 bias range
      objName = prefix + "Background";
      fillColor = (s.bias == BULLISH) ? clrGreen : (s.bias == BEARISH) ? clrRed : clrGray;
      
      // Background rectangle for CRT range
      ObjectCreate(0, objName, OBJ_RECTANGLE, 0, 0, s.crt_low, 0, s.crt_high);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, fillColor);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, objName, OBJPROP_RAY, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, -1);
      
      // Labels for CRT range
      string highLabel = prefix + "High_Label";
      ObjectCreate(0, highLabel, OBJ_TEXT, 0, 0, s.crt_high);
      ObjectSetString(0, highLabel, OBJPROP_TEXT, " CRT High: " + DoubleToString(s.crt_high, _Digits));
      ObjectSetInteger(0, highLabel, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, highLabel, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, highLabel, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      
      string lowLabel = prefix + "Low_Label";
      ObjectCreate(0, lowLabel, OBJ_TEXT, 0, 0, s.crt_low);
      ObjectSetString(0, lowLabel, OBJPROP_TEXT, " CRT Low: " + DoubleToString(s.crt_low, _Digits));
      ObjectSetInteger(0, lowLabel, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, lowLabel, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, lowLabel, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   }
}

//+------------------------------------------------------------------+
//| Draw FVG Zones on Chart                                         |
//+------------------------------------------------------------------+
void DrawFVGZones(CRT_State &s)
{
   if(!Show_Chart_Visualizations || !Show_FVG_Zones) return;
   
   string prefix = "CRT_FVG_";
   string objName;
   color fillColor;
   int transparency = 60;
   
   // Clear previous FVG zones
   ObjectsDeleteAll(0, prefix);
   
   // Draw FVG zone
   if(s.fvg_high > 0 && s.fvg_low > 0)
   {
      objName = prefix + "Zone";
      fillColor = (s.bias == BULLISH) ? clrLime : (s.bias == BEARISH) ? clrMagenta : clrGray;
      
      // Background rectangle for FVG
      ObjectCreate(0, objName, OBJ_RECTANGLE, 0, 0, s.fvg_low, 0, s.fvg_high);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, fillColor);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, objName, OBJPROP_RAY, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, -1);
      
      // Label for FVG zone
      string labelName = prefix + "Label";
      ObjectCreate(0, labelName, OBJ_TEXT, 0, 0, (s.fvg_high + s.fvg_low) / 2);
      ObjectSetString(0, labelName, OBJPROP_TEXT, " FVG Zone: " + DoubleToString(s.fvg_low, _Digits) + "-" + DoubleToString(s.fvg_high, _Digits));
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
   }
}

//+------------------------------------------------------------------+
//| Draw Current State Indicator                                    |
//+------------------------------------------------------------------+
void DrawStateIndicator(CRT_State &s)
{
   if(!Show_Chart_Visualizations || !Show_State_Indicators) return;
   
   string prefix = "CRT_State_";
   string objName;
   string stateText = "";
   color textColor = clrBlack;
   color bgColor = clrYellow;
   
   // Clear previous state indicators
   ObjectsDeleteAll(0, prefix);
   
   // Get current state text
   if(s.bull_state == ENTRY || s.bear_state == ENTRY)
   {
      stateText = "ENTRY: " + (s.bias == BULLISH ? "BUY" : "SELL");
      textColor = clrWhite;
      bgColor = (s.bias == BULLISH) ? clrGreen : clrRed;
   }
   else if(s.bull_state == FVG || s.bear_state == FVG)
   {
      stateText = "FVG: " + (s.bias == BULLISH ? "Bullish" : "Bearish");
      textColor = clrBlack;
      bgColor = (s.bias == BULLISH) ? clrLime : clrMagenta;
   }
   else if(s.bull_state == MSS || s.bear_state == MSS)
   {
      stateText = "MSS: " + (s.bias == BULLISH ? "Bullish" : "Bearish");
      textColor = clrWhite;
      bgColor = (s.bias == BULLISH) ? clrBlue : clrPurple;
   }
   else if(s.bull_state == SWEEP || s.bear_state == SWEEP)
   {
      stateText = "SWEEP: " + (s.bias == BULLISH ? "Bullish" : "Bearish");
      textColor = clrWhite;
      bgColor = (s.bias == BULLISH) ? clrOrange : clrCrimson;
   }
   else
   {
      stateText = "IDLE: " + (s.bias == BULLISH ? "Bullish" : s.bias == BEARISH ? "Bearish" : "Neutral");
      textColor = clrBlack;
      bgColor = clrGray;
   }
   
   // Create state indicator
   objName = prefix + "Indicator";
   ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, objName, OBJPROP_TEXT, stateText);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 12);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 10);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Clear All CRT Visualizations                                    |
//+------------------------------------------------------------------+
void ClearAllCRTVisualizations()
{
   ObjectsDeleteAll(0, "CRT_Swing_");
   ObjectsDeleteAll(0, "CRT_Range_");
   ObjectsDeleteAll(0, "CRT_FVG_");
   ObjectsDeleteAll(0, "CRT_State_");
}
//+------------------------------------------------------------------+