//+------------------------------------------------------------------+
//|                                       Wick Liquidity grab.mq5    |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_plots 0

#include <ChartObjects\ChartObjectsTxtControls.mqh>

// Input parameters
input int XDISTANCE = 10;
input int YDISTANCE = 50;
input int FontSize = 12;
input int MaxCandles = 120;
input ENUM_TIMEFRAMES HTF = PERIOD_M5;
input ENUM_TIMEFRAMES LTF = PERIOD_M1;

// Global variables
string signalLabel = "LiquidityGrabSignalLabel";
datetime lastCheckedTime = 0;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   ObjectDelete(0, signalLabel);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Main calculation loop                                            |
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
   datetime now = TimeCurrent();
   datetime candleEndTime = iTime(_Symbol, LTF, 0) + PeriodSeconds(LTF);

   if (now >= (candleEndTime - 5) && now < candleEndTime)
   {
      if (lastCheckedTime != iTime(_Symbol, LTF, 0))
      {
         string signal = DetectLiquidityGrabSignal();
         DisplaySignal(signal);
         lastCheckedTime = iTime(_Symbol, LTF, 0);
      }
   }

   return rates_total;
}

//+------------------------------------------------------------------+
//| Liquidity Grab Detection Logic                                   |
//+------------------------------------------------------------------+
string DetectLiquidityGrabSignal()
{
   for (int i = 1; i < MaxCandles; i++)
   {
      double high = iHigh(_Symbol, LTF, i);
      double low = iLow(_Symbol, LTF, i);
      double open = iOpen(_Symbol, LTF, i);
      double close = iClose(_Symbol, LTF, i);
      long volume = iVolume(_Symbol, LTF, i);

      double body = MathAbs(close - open);
      double wickTop = high - MathMax(open, close);
      double wickBottom = MathMin(open, close) - low;

      double wickTopRatio = body > 0 ? wickTop / body : 0;
      double wickBottomRatio = body > 0 ? wickBottom / body : 0;

      if (wickBottomRatio > 2.0 && volume > iVolume(_Symbol, LTF, i + 1)) // Bullish LG
      {
         if (iClose(_Symbol, HTF, 0) > iOpen(_Symbol, HTF, 0))
            return "BUY";
      }
      else if (wickTopRatio > 2.0 && volume > iVolume(_Symbol, LTF, i + 1)) // Bearish LG
      {
         if (iClose(_Symbol, HTF, 0) < iOpen(_Symbol, HTF, 0))
            return "SELL";
      }
   }
   return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| Draw Signal Text on Chart                                        |
//+------------------------------------------------------------------+
void DisplaySignal(string signalText)
{
   if (ObjectFind(0, signalLabel) < 0)
      ObjectCreate(0, signalLabel, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, signalLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, signalLabel, OBJPROP_XDISTANCE, XDISTANCE);
   ObjectSetInteger(0, signalLabel, OBJPROP_YDISTANCE, YDISTANCE);
   ObjectSetInteger(0, signalLabel, OBJPROP_FONTSIZE, FontSize);
   ObjectSetInteger(0, signalLabel, OBJPROP_COLOR,
      signalText == "BUY" ? clrLime : signalText == "SELL" ? clrRed : clrYellow);
   ObjectSetString(0, signalLabel, OBJPROP_TEXT, "Next Candle: " + signalText);
}
