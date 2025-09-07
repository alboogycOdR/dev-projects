//+---------------------------------------------------------------------------------+
//|                                                              VWAP_GMT_Final.mq5 |
//|                                                   Copyright 2025,Shivam Shikhar |
//| https://www.instagram.com/artificialintelligencefacts?igsh=MXZ6YmdpMzVna2QyNQ== |
//+---------------------------------------------------------------------------------+
#property copyright "Exness VWAP Replica"
#property version   "1.5"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   1
#property indicator_label1  "VWAP_Exness"
#property indicator_color1  White
#property indicator_style1  DRAW_LINE
#property indicator_width1  2

// Input parameters
input bool UseSessionBreaks = true;       // Reset VWAP on session break
input int SessionStartHour = 0;           // Session start hour (UTC)
input int SessionStartMinute = 0;         // Session start minute
input bool UseTick = true;                // Use tick volume (true) or real volume (false)

// Buffers
double VwapBuffer[];
double PriceVolumeSum[];
double VolumeSum[];

// Global variables
datetime lastSessionReset = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Indicator buffers mapping
   SetIndexBuffer(0, VwapBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, PriceVolumeSum, INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, VolumeSum, INDICATOR_CALCULATIONS);
   
   // Set the indicator parameters
   PlotIndexSetString(0, PLOT_LABEL, "VWAP_Exness");
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrDodgerBlue);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, STYLE_SOLID);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Get timeframe in minutes                                         |
//+------------------------------------------------------------------+
int TimeframeMinutes(ENUM_TIMEFRAMES timeframe)
{
   switch(timeframe)
   {
      case PERIOD_M1: return 1;
      case PERIOD_M2: return 2;
      case PERIOD_M3: return 3;
      case PERIOD_M4: return 4;
      case PERIOD_M5: return 5;
      case PERIOD_M6: return 6;
      case PERIOD_M10: return 10;
      case PERIOD_M12: return 12;
      case PERIOD_M15: return 15;
      case PERIOD_M20: return 20;
      case PERIOD_M30: return 30;
      case PERIOD_H1: return 60;
      case PERIOD_H2: return 120;
      case PERIOD_H3: return 180;
      case PERIOD_H4: return 240;
      case PERIOD_H6: return 360;
      case PERIOD_H8: return 480;
      case PERIOD_H12: return 720;
      case PERIOD_D1: return 1440;
      case PERIOD_W1: return 10080;
      case PERIOD_MN1: return 43200;
      default: return 0;
   }
}

//+------------------------------------------------------------------+
//| Check if this is a session start bar                             |
//+------------------------------------------------------------------+
bool IsSessionStart(datetime time)
{
   if(!UseSessionBreaks)
      return false;
      
   MqlDateTime dt;
   TimeToStruct(time, dt);
   
   // Check if this is the start of a new trading day (UTC)
   if(dt.hour == SessionStartHour && dt.min < SessionStartMinute + TimeframeMinutes(Period()))
      return true;
      
   return false;
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
   if(rates_total <= 0)
      return(0);
      
   // Determine the starting bar for calculation
   int startBar;
   if(prev_calculated <= 0)
   {
      startBar = 0;
      ArrayInitialize(VwapBuffer, 0.0);
      ArrayInitialize(PriceVolumeSum, 0.0);
      ArrayInitialize(VolumeSum, 0.0);
      lastSessionReset = 0;
   }
   else
   {
      startBar = prev_calculated - 1;
   }
   
   // Loop through all bars
   for(int i = startBar; i < rates_total; i++)
   {
      // Check for session break
      if(i > 0 && IsSessionStart(time[i]) && !IsSessionStart(time[i-1]))
      {
         PriceVolumeSum[i] = 0;
         VolumeSum[i] = 0;
         lastSessionReset = time[i];
      }
      else if(i > 0)
      {
         // Carry over cumulative values from previous bar
         PriceVolumeSum[i] = PriceVolumeSum[i-1];
         VolumeSum[i] = VolumeSum[i-1];
      }
      
      // XAU specific pricing - Exness often uses this weighted price for metals
      double vwapPrice = (high[i] + low[i] + close[i] + close[i]) / 4.0;
      
      // Add this bar's contribution using selected volume type
      double vol;
      if(UseTick)
         vol = (double)tick_volume[i];
      else
         vol = (double)volume[i];
         
      PriceVolumeSum[i] += vwapPrice * vol;
      VolumeSum[i] += vol;
      
      // Calculate VWAP
      if(VolumeSum[i] > 0)
         VwapBuffer[i] = PriceVolumeSum[i] / VolumeSum[i];
      else
         VwapBuffer[i] = close[i];
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // If the chart period or symbol has changed, refresh the indicator
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      ChartRedraw();
   }
}
//+------------------------------------------------------------------+