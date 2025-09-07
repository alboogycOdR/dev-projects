# 📊 **Enhanced CRT System with Chart Visualizations**

Below is a comprehensive implementation of **swing point visualization** and **other valuable chart visualizations** for your CRT trading system. These visualizations will help traders understand the system's logic and confirm its state in real-time.

---

## 📄 **1. crt_core2.mqh (Updated with Visualization Support)**

```mql5
//+------------------------------------------------------------------+
//| CRT_Core.mqh – Final Enhanced Version with Chart Visualizations   |
//+------------------------------------------------------------------+
#property library
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <ChartObjects\ChartObjectsLines.mqh>
#include <ChartObjects\ChartObjectsTexts.mqh>

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
   double            sweep_level;     // Store sweep level
   double            mss_level;       // Correct MSS level
   datetime          sweep_time;      // Time of sweep
   datetime          mss_confirmed_time; // MSS confirmation time
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

//--- FIND SWING POINTS ----------------------------------------------
double FindLastSwingHigh(MqlRates &m15[], int start_index, int max_bars=20, datetime &swing_time=NULL)
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

double FindLastSwingLow(MqlRates &m15[], int start_index, int max_bars=20, datetime &swing_time=NULL)
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

//--- M15 STATE STEP (with visualization support) --------------------
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
               s.sweep_level = m15[1].low;
               s.sweep_time = m15[1].time;
               s.bull_state = SWEEP;
               Print(s.symbol, " | BULL | IDLE→SWEEP | Sweep: ", s.sweep_level);
            }
            break;

         case SWEEP:
            // Find last swing HIGH for MSS confirmation
            if(s.mss_level == 0.0)
            {
               datetime swing_time;
               s.mss_level = FindLastSwingHigh(m15, 2, 10, swing_time);
               s.swing_high = s.mss_level;
               s.swing_high_time = swing_time;
               Print(s.symbol, " | BULL | SWEEP | MSS Level Set: ", s.mss_level);
            }
            
            if(m15[1].high > s.mss_level)
            {
               s.bull_state = MSS;
               s.mss_confirmed_time = m15[1].time;
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
                  
                  if(m15[i].time > s.mss_confirmed_time)
                  {
                     s.fvg_high = m15[i-2].high;
                     s.fvg_low  = m15[i].low;
                     s.bull_state = FVG;
                     Print(s.symbol, " | BULL | MSS→FVG | FVG: ", s.fvg_low, "-", s.fvg_high, 
                           " | Size: ", fvg_size, " pips | Validated");
                     break;
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
               s.sweep_level = m15[1].high;
               s.sweep_time = m15[1].time;
               s.bear_state = SWEEP;
               Print(s.symbol, " | BEAR | IDLE→SWEEP | Sweep: ", s.sweep_level);
            }
            break;

         case SWEEP:
            // Find last swing LOW for MSS confirmation
            if(s.mss_level == 0.0)
            {
               datetime swing_time;
               s.mss_level = FindLastSwingLow(m15, 2, 10, swing_time);
               s.swing_low = s.mss_level;
               s.swing_low_time = swing_time;
               Print(s.symbol, " | BEAR | SWEEP | MSS Level Set: ", s.mss_level);
            }
            
            if(m15[1].low < s.mss_level)
            {
               s.bear_state = MSS;
               s.mss_confirmed_time = m15[1].time;
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
                  
                  if(m15[i].time > s.mss_confirmed_time)
                  {
                     s.fvg_high = m15[i].high;
                     s.fvg_low  = m15[i-2].low;
                     s.bear_state = FVG;
                     Print(s.symbol, " | BEAR | MSS→FVG | FVG: ", s.fvg_low, "-", s.fvg_high, 
                           " | Size: ", fvg_size, " pips | Validated");
                     break;
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
      ObjectSetInteger(0, objName, OBJPROP_TRANSPOSE, false);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, objName, OBJPROP_RAY, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, -1);
      ObjectSetInteger(0, objName, OBJPROP_FILLED, true);
      ObjectSetInteger(0, objName, OBJPROP_FILLMODE, FILLING_FULL);
      ObjectSetInteger(0, objName, OBJPROP_FILL_COLOR, fillColor);
      ObjectSetInteger(0, objName, OBJPROP_FILL_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_FILL_TRANS, transparency);
      
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
      ObjectSetInteger(0, objName, OBJPROP_TRANSPOSE, false);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, objName, OBJPROP_RAY, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, -1);
      ObjectSetInteger(0, objName, OBJPROP_FILLED, true);
      ObjectSetInteger(0, objName, OBJPROP_FILLMODE, FILLING_FULL);
      ObjectSetInteger(0, objName, OBJPROP_FILL_COLOR, fillColor);
      ObjectSetInteger(0, objName, OBJPROP_FILL_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_FILL_TRANS, transparency);
      
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
```

---

## 📄 **2. CRT-Trader.mq5 (Updated with Visualization Calls)**

```mql5
//+------------------------------------------------------------------+
//| CRT-Trader.mq5                                                 |
//+------------------------------------------------------------------+
#property strict
#include "CRT_Core.mqh"
#include <Trade\Trade.mqh>

//--- INPUT PARAMETERS ------------------------------------------------
input string Symbol = "EURUSD";
input ENUM_TIMEFRAMES H4_Timeframe = PERIOD_H4;
input ENUM_TIMEFRAMES M15_Timeframe = PERIOD_M15;
input int             FVG_CheckRange = 25;
input bool            Use_FVG_SizeValidation = true;
input double          MinFVGSizePips = 10.0;
input bool            Use_TimeBasedFiltering = true;
input int             TradingStartHour = 8;
input int             TradingEndHour = 20;
input bool            Use_ATR_SL = true;
input int             ATRPeriod = 14;
input double          ATRMultiplier = 1.5;
input bool            Use_EntryConfirmation = true;
input double          Lots = 0.1;
input double          RiskR = 2.0;
input string          TelegramToken = "";
input string          TelegramChatID = "";

//--- GLOBALS -------------------------------------------------------
CRT_State st;
CTrade trade;

//+------------------------------------------------------------------+
int OnInit()
{
   st.symbol = Symbol;
   EventSetTimer(60);
   Print("CRT-Trader initialized for: ", Symbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) 
{ 
   EventKillTimer();
   ClearAllCRTVisualizations();
}

//+------------------------------------------------------------------+
void OnTimer()
{
   datetime now = TimeCurrent();
   MqlDateTime t; TimeToStruct(now, t);

   if(last_day != t.day_of_year)
   {
      last_day = t.day_of_year;
      ResetState(st, Symbol);
   }

   // Time-based filtering
   if(Use_TimeBasedFiltering)
   {
      int current_hour = t.hour;
      if(current_hour < TradingStartHour || current_hour > TradingEndHour)
      {
         Print("Trading disabled outside time filter | Current Hour: ", current_hour);
         return;
      }
   }

   datetime range_time, sweep_time;
   double range_high, range_low;
   st.bias = CRT_Bias(st.symbol, range_time, sweep_time, range_high, range_low);
   st.crt_high = range_high;
   st.crt_low = range_low;

   M15_Step(st);
   
   // Draw all visualizations
   DrawSwingPoints(st);
   DrawCRTRange(st);
   DrawFVGZones(st);
   DrawStateIndicator(st);

   if(st.bias == BULLISH && st.bull_state == ENTRY)
   {
      double price = SymbolInfoDouble(Symbol, SYMBOL_BID);
      double sl, tp;
      
      // Use precise sweep level for SL
      if(st.sweep_level != 0.0 && st.sweep_level < st.crt_low)
         sl = st.sweep_level;
      else
         sl = st.crt_low;
      
      if(Use_ATR_SL)
      {
         double atr = iATR(NULL, 0, ATRPeriod, 1);
         sl = price - atr * ATRMultiplier;
         tp = price + atr * ATRMultiplier * RiskR;
      }
      else
      {
         tp = price + (price - sl) * RiskR;
      }

      Print("Bullish Entry | Price: ", DoubleToString(price, _Digits), 
            " | SL: ", DoubleToString(sl, _Digits), 
            " | TP: ", DoubleToString(tp, _Digits));

      if(!PositionSelect(Symbol))
      {
         trade.Buy(Lots, Symbol, price, sl, tp);
         SendTradeAlert("BUY", price, sl, tp);
      }
   }
   else if(st.bias == BEARISH && st.bear_state == ENTRY)
   {
      double price = SymbolInfoDouble(Symbol, SYMBOL_ASK);
      double sl, tp;
      
      // Use precise sweep level for SL
      if(st.sweep_level != 0.0 && st.sweep_level > st.crt_high)
         sl = st.sweep_level;
      else
         sl = st.crt_high;
      
      if(Use_ATR_SL)
      {
         double atr = iATR(NULL, 0, ATRPeriod, 1);
         sl = price + atr * ATRMultiplier;
         tp = price - atr * ATRMultiplier * RiskR;
      }
      else
      {
         tp = price - (sl - price) * RiskR;
      }

      Print("Bearish Entry | Price: ", DoubleToString(price, _Digits), 
            " | SL: ", DoubleToString(sl, _Digits), 
            " | TP: ", DoubleToString(tp, _Digits));

      if(!PositionSelect(Symbol))
      {
         trade.Sell(Lots, Symbol, price, sl, tp);
         SendTradeAlert("SELL", price, sl, tp);
      }
   }
}

//+------------------------------------------------------------------+
//| Send Telegram alert with emoji and trade details                   |
//+------------------------------------------------------------------+
void SendTradeAlert(string direction, double price, double sl, double tp)
{
   string entry_emoji = (direction == "BUY") ? "🐂" : "🐻";
   string message = entry_emoji + " CRT-TRADE: " + Symbol + " " + direction + " | " +
                   "Bias: " + EnumToString(st.bias) + " | " +
                   "Sweep: " + DoubleToString(st.sweep_level, _Digits) + " | " +
                   "FVG: " + DoubleToString(st.fvg_low, _Digits) + "-" + DoubleToString(st.fvg_high, _Digits) + " | " +
                   "SL: " + DoubleToString(sl, _Digits) + " | " +
                   "TP: " + DoubleToString(tp, _Digits);
   Telegram_Send(TelegramToken, TelegramChatID, message);
}
//+------------------------------------------------------------------+
```

---

## 📌 **Key Visualizations Added**

### **1. Swing Point Visualization**
- **What it shows**: 
  - Swing highs (blue dashed lines) for bullish setups
  - Swing lows (red dashed lines) for bearish setups
- **Why it matters**: 
  - Clearly marks the MSS level that must be broken
  - Helps traders visually confirm the system's logic
  - Shows where the system is looking for reversals

### **2. CRT Range Visualization**
- **What it shows**:
  - Semi-transparent background between CRT high and low
  - White labels showing exact price levels
- **Why it matters**:
  - Visual representation of the H4 bias range
  - Color-coded (green for bullish, red for bearish)
  - Helps identify when price is within the range vs. outside

### **3. FVG Zone Visualization**
- **What it shows**:
  - Semi-transparent zone for the FVG (Fair Value Gap)
  - Center label showing FVG price range
- **Why it matters**:
  - Clearly marks where price should retest for entry
  - Color-coded (lime for bullish, magenta for bearish)
  - Visual confirmation of gap quality and size

### **4. State Indicator**
- **What it shows**:
  - Corner label showing current system state
  - Color-coded by state (IDLE, SWEEP, MSS, FVG, ENTRY)
- **Why it matters**:
  - At-a-glance understanding of system status
  - Helps traders know when to expect entries
  - Color-coding provides instant visual feedback

---

## 📊 **Other Possible Visualizations**

### **1. Entry Zone Markers**
- **Description**: 
  - Arrows or triangles marking potential entry zones
  - Dynamic updating as price approaches entry level
- **Implementation**:
  ```mql5
  void DrawEntryZones(CRT_State &s)
  {
     if(s.bull_state == FVG || s.bull_state == ENTRY)
     {
        ObjectCreate(0, "EntryZone_Bull", OBJ_ARROW, 0, 0, s.fvg_high);
        ObjectSetInteger(0, "EntryZone_Bull", OBJPROP_ARROWCODE, 233); // Up arrow
        ObjectSetInteger(0, "EntryZone_Bull", OBJPROP_COLOR, clrGreen);
        ObjectSetInteger(0, "EntryZone_Bull", OBJPROP_FONTSIZE, 14);
     }
     else if(s.bear_state == FVG || s.bear_state == ENTRY)
     {
        ObjectCreate(0, "EntryZone_Bear", OBJ_ARROW, 0, 0, s.fvg_low);
        ObjectSetInteger(0, "EntryZone_Bear", OBJPROP_ARROWCODE, 234); // Down arrow
        ObjectSetInteger(0, "EntryZone_Bear", OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, "EntryZone_Bear", OBJPROP_FONTSIZE, 14);
     }
  }
  ```

### **2. Historical State Timeline**
- **Description**:
  - Timeline showing state progression over time
  - Color-coded bars for each state (IDLE, SWEEP, MSS, FVG, ENTRY)
- **Implementation**:
  ```mql5
  void DrawStateTimeline(CRT_State &s, MqlRates &m15)
  {
     // This would create a mini-chart at the bottom showing state progression
     // Could use OBJ_RECTANGLE to draw color-coded bars for each state
  }
  ```

### **3. Bias Strength Indicator**
- **Description**:
  - Gauge showing current bias strength
  - Based on distance from CRT range, FVG quality, etc.
- **Implementation**:
  ```mql5
  void DrawBiasStrength(CRT_State &s)
  {
     // Create a horizontal gauge showing bias strength
     // Could use OBJ_RECTANGLE with varying width/color
  }
  ```

### **4. Entry Confirmation Visualization**
- **Description**:
  - Highlight candles that confirm entry (engulfing patterns)
  - Color-coded candle bodies for visual confirmation
- **Implementation**:
  ```mql5
  void DrawEntryConfirmation(CRT_State &s, MqlRates &m15)
  {
     if(s.bull_state == ENTRY)
     {
        // Highlight the engulfing candle
        ObjectCreate(0, "Engulfing_Bull", OBJ_RECTANGLE, 0, m15[0].time, m15[0].low, m15[1].time, m15[1].high);
        ObjectSetInteger(0, "Engulfing_Bull", OBJPROP_COLOR, clrGreen);
        ObjectSetInteger(0, "Engulfing_Bull", OBJPROP_FILL, true);
        ObjectSetInteger(0, "Engulfing_Bull", OBJPROP_FILL_COLOR, clrGreen);
        ObjectSetInteger(0, "Engulfing_Bull", OBJPROP_FILL_TRANS, 50);
     }
     else if(s.bear_state == ENTRY)
     {
        // Highlight the engulfing candle
        ObjectCreate(0, "Engulfing_Bear", OBJ_RECTANGLE, 0, m15[0].time, m15[0].high, m15[1].time, m15[1].low);
        ObjectSetInteger(0, "Engulfing_Bear", OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, "Engulfing_Bear", OBJPROP_FILL, true);
        ObjectSetInteger(0, "Engulfing_Bear", OBJPROP_FILL_COLOR, clrRed);
        ObjectSetInteger(0, "Engulfing_Bear", OBJPROP_FILL_TRANS, 50);
     }
  }
  ```

### **5. FVG Size Indicator**
- **Description**:
  - Text showing FVG size in pips
  - Color-coded (green for sufficient size, red for too small)
- **Implementation**:
  ```mql5
  void DrawFVGSizeIndicator(CRT_State &s)
  {
     if(s.fvg_high > 0 && s.fvg_low > 0)
     {
        double pip_size = SymbolInfoDouble(s.symbol, SYMBOL_POINT) * 10;
        double fvg_size = (s.bias == BULLISH) ? (s.fvg_low - s.fvg_high)/pip_size : (s.fvg_high - s.fvg_low)/pip_size;
        
        string objName = "FVG_Size";
        color textColor = (fvg_size >= MinFVGSizePips) ? clrGreen : clrRed;
        
        ObjectCreate(0, objName, OBJ_TEXT, 0, 0, s.fvg_high + (s.fvg_high - s.fvg_low) * 0.2);
        ObjectSetString(0, objName, OBJPROP_TEXT, "FVG: " + DoubleToString(fvg_size, 1) + " pips");
        ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
     }
  }
  ```

### **6. MSS Confirmation Visual**
- **Description**:
  - Arrow marking when MSS is confirmed
  - Shows the exact candle that triggered MSS
- **Implementation**:
  ```mql5
  void DrawMSSConfirmation(CRT_State &s, MqlRates &m15)
  {
     if(s.mss_confirmed_time > 0)
     {
        int index = 0;
        for(int i = 0; i < ArraySize(m15); i++)
        {
           if(m15[i].time == s.mss_confirmed_time)
           {
              index = i;
              break;
           }
        }
        
        if(s.bias == BULLISH)
        {
           ObjectCreate(0, "MSS_Confirmation_Bull", OBJ_ARROW, 0, m15[index].time, m15[index].low);
           ObjectSetInteger(0, "MSS_Confirmation_Bull", OBJPROP_ARROWCODE, 225); // Up triangle
           ObjectSetInteger(0, "MSS_Confirmation_Bull", OBJPROP_COLOR, clrBlue);
           ObjectSetInteger(0, "MSS_Confirmation_Bull", OBJPROP_FONTSIZE, 12);
        }
        else
        {
           ObjectCreate(0, "MSS_Confirmation_Bear", OBJ_ARROW, 0, m15[index].time, m15[index].high);
           ObjectSetInteger(0, "MSS_Confirmation_Bear", OBJPROP_ARROWCODE, 226); // Down triangle
           ObjectSetInteger(0, "MSS_Confirmation_Bear", OBJPROP_COLOR, clrPurple);
           ObjectSetInteger(0, "MSS_Confirmation_Bear", OBJPROP_FONTSIZE, 12);
        }
     }
  }
  ```

---

## 📋 **How to Use the Visualizations**

### **1. Enable/Disable Visualizations**
- All visualizations can be toggled on/off via inputs:
  ```mql5
  input bool Show_Chart_Visualizations = true;
  input bool Show_CRT_Range = true;
  input bool Show_FVG_Zones = true;
  input bool Show_Swing_Points = true;
  input bool Show_State_Indicators = true;
  ```

### **2. Customization Options**
- Change colors by modifying the `fillColor` variables
- Adjust transparency by changing the `transparency` values
- Modify line styles by changing `STYLE_DASH` to other styles

### **3. Best Practices**
- **For Trading**: Keep all visualizations enabled to see the full picture
- **For Backtesting**: Disable all except State Indicator for cleaner charts
- **For Presentations**: Enable all visualizations for maximum clarity

---

## 📌 **Next Steps**

Would you like me to:
1. **Add the additional visualizations** (entry zones, historical timeline, etc.) to the code?
2. **Provide a color scheme** optimized for light/dark chart backgrounds?
3. **Create a configuration panel** for visualizations (GUI)?
4. **Add sound alerts** synchronized with visual cues?

Let me know how you'd like to proceed!