//+------------------------------------------------------------------+
//|                                   FlexibleRejectionIndicator.mq5 |
//|                                      Copyright 2025, Google Gemini |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Google Gemini"
#property link      ""
#property version   "1.20"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Buffers
double DummyBuffer[];

//--- Enums for readability
enum ETimePattern
  {
   GMT_PLUS_2, // 00:00 / 04:00
   GMT_PLUS_3  // 01:00 / 05:00
  };

//--- Input Parameters
input int          lookbackDays = 20;        // Lookback Period in Days
input ETimePattern TimePattern  = GMT_PLUS_3; // Broker Time Pattern

//--- String constants for object names
#define HIGH_REJ_PREFIX "HighRejArrow_"
#define LOW_REJ_PREFIX  "LowRejArrow_"
#define RANGE_BOX_PREFIX "RangeBox_"

//--- Global variables for candle hours
int range_candle_hour;
int confirmation_candle_hour;
int end_range_candle_hour;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
//--- Set up a dummy buffer
   SetIndexBuffer(0, DummyBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);

//--- Set the candle hours based on user input
   switch(TimePattern)
     {
      case GMT_PLUS_2:
         range_candle_hour = 0;
         confirmation_candle_hour = 4;
         end_range_candle_hour = 8;
         Print("Rejection Indicator: Using 00:00 and 04:00 candle pattern.");
         break;

      case GMT_PLUS_3:
         range_candle_hour = 1;
         confirmation_candle_hour = 5;
         end_range_candle_hour = 9;
         Print("Rejection Indicator: Using 01:00 and 05:00 candle pattern.");
         break;
     }

//--- Clean up objects on startup
   OnDeinit(REASON_PROGRAM);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(reason == REASON_REMOVE || reason == REASON_PROGRAM || reason == REASON_RECOMPILE || reason == REASON_CHARTCHANGE)
     {
      string timeframeStr = PeriodToString((ENUM_TIMEFRAMES)_Period);
      ObjectsDeleteAll(0, HIGH_REJ_PREFIX + timeframeStr);
      ObjectsDeleteAll(0, LOW_REJ_PREFIX + timeframeStr);
      ObjectsDeleteAll(0, RANGE_BOX_PREFIX + timeframeStr);
     }
}

//+------------------------------------------------------------------+
//| Converts ENUM_TIMEFRAMES to string representation                |
//+------------------------------------------------------------------+
string PeriodToString(ENUM_TIMEFRAMES period)
  {
   string str = EnumToString(period);
   StringReplace(str, "PERIOD_", "");
   return(str);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // --- Only recalculate when a new H4 bar is formed to improve performance on lower timeframes
   static int h4_bars_last_run = 0;
   int h4_bars_current = (int)SeriesInfoInteger(_Symbol, PERIOD_H4, SERIES_BARS_COUNT);
   if(h4_bars_current == h4_bars_last_run && prev_calculated > 0)
     {
      return(rates_total); // No new H4 bar, no need to recalculate
     }
   h4_bars_last_run = h4_bars_current;

   // --- Ensure we have enough H4 history
   int lookback_h4_bars = lookbackDays * 6; // Approx 6 H4 bars per day
   if(h4_bars_current < lookback_h4_bars)
     {
      //Print("Not enough H4 history available.");
      return(0);
     }

   // --- Get H4 data
   MqlRates h4_rates[];
   if(CopyRates(_Symbol, PERIOD_H4, 0, lookback_h4_bars, h4_rates) < lookback_h4_bars)
     {
      //Print("Failed to copy H4 rates history.");
      return(0);
     }
   ArraySetAsSeries(h4_rates, false); // Oldest bar is at index 0

//--- Loop through H4 bars from past to present
   for(int i = 0; i < ArraySize(h4_rates); i++)
     {
      // We need at least 2 future bars to complete the pattern
      if(i >= ArraySize(h4_rates) - 2)
         break;

      MqlDateTime time_struct;
      TimeToStruct(h4_rates[i].time, time_struct);

      // 1. Find the "Range Candle"
      if(time_struct.hour == range_candle_hour)
        {
         // Identify the candles we need from H4 data
         int range_candle_idx = i;
         int confirmation_candle_idx = i + 1;
         int end_range_candle_idx = i + 2;

         // Check if the next candles match our pattern's hours
         MqlDateTime conf_time_struct;
         TimeToStruct(h4_rates[confirmation_candle_idx].time, conf_time_struct);

         MqlDateTime end_range_time_struct;
         TimeToStruct(h4_rates[end_range_candle_idx].time, end_range_time_struct);

         if(conf_time_struct.hour == confirmation_candle_hour && end_range_time_struct.hour == end_range_candle_hour)
           {
            // Store the range high and low from H4 data
            double rangeHigh = h4_rates[range_candle_idx].high;
            double rangeLow  = h4_rates[range_candle_idx].low;
            string timeframeStr = PeriodToString((ENUM_TIMEFRAMES)_Period); // Keep objects specific to the chart TF

            // 2. Perform the rejection check using H4 data
            bool highRejection = h4_rates[confirmation_candle_idx].high > rangeHigh && h4_rates[confirmation_candle_idx].close < rangeHigh;
            bool lowRejection  = h4_rates[confirmation_candle_idx].low < rangeLow && h4_rates[confirmation_candle_idx].close > rangeLow;

            // 3. Draw the visual objects using H4 time coordinates
            datetime objectTime = h4_rates[range_candle_idx].time;

            // Draw Range Box
            string boxName = RANGE_BOX_PREFIX + timeframeStr + (string)objectTime;
            if(ObjectFind(0, boxName) < 0) //Only draw if not already present
              {
               datetime boxEndTime = h4_rates[end_range_candle_idx].time + PeriodSeconds(PERIOD_H4);
               ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, h4_rates[range_candle_idx].time, rangeHigh, boxEndTime, rangeLow);
               ObjectSetInteger(0, boxName, OBJPROP_COLOR, clrSilver);
               ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_SOLID);
               ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
              }


            // Draw Rejection Arrows
            if(highRejection)
              {
               string arrowName = HIGH_REJ_PREFIX + timeframeStr + (string)objectTime;
               if(ObjectFind(0, arrowName) < 0)
                 {
                  ObjectCreate(0, arrowName, OBJ_ARROW_DOWN, 0, h4_rates[confirmation_candle_idx].time, h4_rates[confirmation_candle_idx].high + _Point * 20);
                  ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrRed);
                  ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
                 }
              }
            else if(lowRejection)
              {
               string arrowName = LOW_REJ_PREFIX + timeframeStr + (string)objectTime;
               if(ObjectFind(0, arrowName) < 0)
                 {
                  ObjectCreate(0, arrowName, OBJ_ARROW_UP, 0, h4_rates[confirmation_candle_idx].time, h4_rates[confirmation_candle_idx].low - _Point * 20);
                  ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrGreen);
                  ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
                 }
              }
           }
        }
     }
   return(rates_total);
} 