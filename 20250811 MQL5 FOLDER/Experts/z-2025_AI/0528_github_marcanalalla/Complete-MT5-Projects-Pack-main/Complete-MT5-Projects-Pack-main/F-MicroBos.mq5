//+------------------------------------------------------------------+
//|                                                      MicroBos.mq5|
//|                        Copyright 2025, YourName                   |
//|                        https://github.com/YourRepo               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, YourName"
#property link      "https://github.com/YourRepo"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

#property indicator_label1  "Dummy"
#property indicator_type1   DRAW_NONE
#property indicator_color1  clrNONE

// Input parameters
input int XDISTANCE = 10;           // Label X Distance
input int YDISTANCE = 110;          // Label Y Distance
input int FontSize = 12;            // Font Size
input color BullishColor = clrLime; // Color for Buy signal
input color BearishColor = clrRed;  // Color for Sell signal

// Buffers
double DummyBuffer[];

// Global
string label_name = "MicroBosSignalLabel";
datetime last_update = 0;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, DummyBuffer, INDICATOR_DATA); // Dummy buffer
   
   // Create label
   if(!ObjectCreate(0, label_name, OBJ_LABEL, 0, 0, 0))
   {
      Print("Failed to create label!");
      return(INIT_FAILED);
   }
   ObjectSetInteger(0, label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, label_name, OBJPROP_XDISTANCE, XDISTANCE);
   ObjectSetInteger(0, label_name, OBJPROP_YDISTANCE, YDISTANCE);
   ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, FontSize);
   ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrYellow);
   ObjectSetString(0, label_name, OBJPROP_TEXT, "Waiting for signal...");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, label_name);
}

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
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
   datetime current_time = TimeCurrent();
   datetime last_candle_time = time[rates_total - 1]; // Use latest candle time
   int seconds_to_next_candle = (int)(PeriodSeconds() - (current_time - last_candle_time));

   // Update when a new candle forms
   if(seconds_to_next_candle <= 5 && last_update != last_candle_time)
   {
      string signal_message = GetMicroBosSignal(close, rates_total);
      color label_color = clrWhite;

      // Set signal colors based on the message
      if(signal_message == "Strong Bullish Signal")
         label_color = BullishColor;
      else if(signal_message == "Strong Bearish Signal")
         label_color = BearishColor;

      // Update label with new signal
      ObjectSetString(0, label_name, OBJPROP_TEXT, signal_message);
      ObjectSetInteger(0, label_name, OBJPROP_COLOR, label_color);

      last_update = last_candle_time;
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Micro BOS Logic                                                  |
//+------------------------------------------------------------------+
string GetMicroBosSignal(const double &close[], int rates_total)
{
   if(rates_total < 4) return "No data";  // Ensure we have enough data for the logic

   // Check if current close > previous close to determine bullish/bearish signal
   if(close[rates_total - 2] > close[rates_total - 3])
      return "Strong Bullish Signal";
   else if(close[rates_total - 2] < close[rates_total - 3])
      return "Strong Bearish Signal";
   else
      return "No Signal";
}
