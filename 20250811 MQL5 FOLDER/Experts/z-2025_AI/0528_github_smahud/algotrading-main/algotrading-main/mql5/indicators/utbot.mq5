//+------------------------------------------------------------------+
//|                                                 UT Bot Alerts.mq5 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   4

// Plot settings for ATR Trailing Stop line
#property indicator_label1  "ATR Trailing Stop"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Plot settings for Buy signals
#property indicator_label2  "Buy Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLime
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3

// Plot settings for Sell signals
#property indicator_label3  "Sell Signal"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  3

// Plot settings for EMA line
#property indicator_label4  "EMA(1)"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrWhite
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

// Input parameters
input double KeyValue = 3.0;        // Key Value (Sensitivity)
input int    ATRPeriod = 14;        // ATR Period
input bool   HeikinAshi = false;    // Use Heikin Ashi Candles

// Indicator buffers
double ATRTrailingStopBuffer[];    // ATR Trailing Stop buffer
double BuySignalBuffer[];          // Buy signal buffer
double SellSignalBuffer[];         // Sell signal buffer
double EMABuffer[];                // EMA buffer
double PositionBuffer[];           // Position tracking buffer
double SourceBuffer[];             // Source price buffer

// Global variables
int atr_handle;                    // ATR indicator handle

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator buffers
   SetIndexBuffer(0, ATRTrailingStopBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BuySignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SellSignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, EMABuffer, INDICATOR_DATA);
   SetIndexBuffer(4, PositionBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, SourceBuffer, INDICATOR_CALCULATIONS);
   
   // Set arrow codes for buy and sell signals
   PlotIndexSetInteger(1, PLOT_ARROW, 233);  // Up arrow for buy
   PlotIndexSetInteger(2, PLOT_ARROW, 234);  // Down arrow for sell
   
   // Create ATR indicator handle
   atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   if(atr_handle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator handle");
      return(INIT_FAILED);
   }
   
   // Set indicator name
   string short_name = "UT Bot Alerts";
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Indicator deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release the ATR indicator handle
   if(atr_handle != INVALID_HANDLE)
      IndicatorRelease(atr_handle);
}

//+------------------------------------------------------------------+
//| Calculate Heikin Ashi Close price                                |
//+------------------------------------------------------------------+
double CalculateHAClose(const double open, const double high, const double low, const double close)
{
   return (open + high + low + close) / 4.0;
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
   // Check for minimum number of bars
   if(rates_total < 3)
      return(0);
   
   // Check if ATR handle is valid
   if(atr_handle == INVALID_HANDLE)
      return(0);
      
   // Copy ATR values
   double atr_values[];
   if(CopyBuffer(atr_handle, 0, 0, rates_total, atr_values) <= 0)
   {
      Print("Failed to copy ATR buffer values");
      return(0);
   }
   
   // Calculate the first bar index for calculations
   int limit;
   if(prev_calculated == 0)
   {
      // Initialize buffers
      for(int i = 0; i < rates_total; i++)
      {
         ATRTrailingStopBuffer[i] = 0.0;
         BuySignalBuffer[i] = 0.0;
         SellSignalBuffer[i] = 0.0;
         EMABuffer[i] = 0.0;
         PositionBuffer[i] = 0.0;
         SourceBuffer[i] = 0.0;
      }
      limit = 2; // Start from the third bar (index 2)
   }
   else
   {
      limit = prev_calculated - 1;
   }
   
   // Fill the source price buffer based on Heikin Ashi preference
   for(int i = 0; i < rates_total; i++)
   {
      if(HeikinAshi)
      {
         // Calculate Heikin Ashi close price
         SourceBuffer[i] = CalculateHAClose(open[i], high[i], low[i], close[i]);
      }
      else
      {
         // Use regular close price
         SourceBuffer[i] = close[i];
      }
      
      // EMA(1) is simply the source price
      EMABuffer[i] = SourceBuffer[i];
   }
   
   // Main calculation loop
   for(int i = limit; i < rates_total; i++)
   {
      // Calculate nLoss (KeyValue * ATR)
      double nLoss = KeyValue * atr_values[i];
      
      // Calculate ATR Trailing Stop
      if(i > 0) // Make sure we have a previous bar
      {
         double src = SourceBuffer[i];
         double prev_src = SourceBuffer[i-1];
         double prev_atr_stop = ATRTrailingStopBuffer[i-1];
         
         // Uptrend condition
         if(src > prev_atr_stop && prev_src > prev_atr_stop)
         {
            ATRTrailingStopBuffer[i] = MathMax(prev_atr_stop, src - nLoss);
         }
         // Downtrend condition
         else if(src < prev_atr_stop && prev_src < prev_atr_stop)
         {
            ATRTrailingStopBuffer[i] = MathMin(prev_atr_stop, src + nLoss);
         }
         // Trend change condition
         else
         {
            if(src > prev_atr_stop)
               ATRTrailingStopBuffer[i] = src - nLoss;
            else
               ATRTrailingStopBuffer[i] = src + nLoss;
         }
         
         // Position tracking
         if(prev_src < prev_atr_stop && src > ATRTrailingStopBuffer[i])
         {
            PositionBuffer[i] = 1.0; // Long position
         }
         else if(prev_src > prev_atr_stop && src < ATRTrailingStopBuffer[i])
         {
            PositionBuffer[i] = -1.0; // Short position
         }
         else
         {
            PositionBuffer[i] = PositionBuffer[i-1]; // Maintain previous position
         }
         
         // Signal generation
         bool above = (prev_src < prev_atr_stop && src > ATRTrailingStopBuffer[i]);
         bool below = (prev_src > prev_atr_stop && src < ATRTrailingStopBuffer[i]);
         
         // Buy signal
         if(src > ATRTrailingStopBuffer[i] && above)
         {
            BuySignalBuffer[i] = low[i] - 10 * _Point; // Place arrow below the bar
            SellSignalBuffer[i] = 0.0;
         }
         // Sell signal
         else if(src < ATRTrailingStopBuffer[i] && below)
         {
            SellSignalBuffer[i] = high[i] + 10 * _Point; // Place arrow above the bar
            BuySignalBuffer[i] = 0.0;
         }
         else
         {
            BuySignalBuffer[i] = 0.0;
            SellSignalBuffer[i] = 0.0;
         }
      }
   }
   
   // Return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+