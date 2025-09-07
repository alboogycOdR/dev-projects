//+------------------------------------------------------------------+
//|                                      Displacement Signal.mq5     |
//|                        Developed for MT5 by ChatGPT              |
//+------------------------------------------------------------------+

#property indicator_chart_window
#property strict
#property indicator_buffers 0
#property indicator_plots 0

input int XDISTANCE = 10;
input int YDISTANCE = 90;
input int FontSize = 12;
input int MaxCandles = 120;
input ENUM_TIMEFRAMES HTF = PERIOD_M5;

string signalLabel = "NextCandleBias";
datetime lastSignalTime = 0;
int atrHandle;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   atrHandle = iATR(_Symbol, PERIOD_M1, 2);
   if (atrHandle == INVALID_HANDLE)
      return(INIT_FAILED);

   EventSetTimer(1); // 1 second timer
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   if (atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);

   ObjectDelete(0, signalLabel);
}

//+------------------------------------------------------------------+
//| Dummy OnCalculate (required)                                     |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
{
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Safely get ATR value                                             |
//+------------------------------------------------------------------+
double GetATRValue(int shift)
{
   if (atrHandle == INVALID_HANDLE)
      return 0;

   double atrBuffer[];
   if (CopyBuffer(atrHandle, 0, shift, 1, atrBuffer) <= 0)
      return 0;
   return atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Check for displacement candle                                    |
//+------------------------------------------------------------------+
bool IsDisplacementCandle(int shift)
{
   double open = iOpen(_Symbol, PERIOD_M1, shift);
   double close = iClose(_Symbol, PERIOD_M1, shift);
   double high = iHigh(_Symbol, PERIOD_M1, shift);
   double low = iLow(_Symbol, PERIOD_M1, shift);
   double body = MathAbs(close - open);
   double wick = high - low;
   double atr = GetATRValue(shift);
   double bodyRatio = body / (wick + 0.00001);

   return (bodyRatio > 0.4 && body > (0.2 * atr));
}

//+------------------------------------------------------------------+
//| Predict Next Candle Bias                                         |
//+------------------------------------------------------------------+
string PredictNextCandleBias()
{
   int shift = 1;
   if (!IsDisplacementCandle(shift))
      return "No Strong Bias";

   double open = iOpen(_Symbol, PERIOD_M1, shift);
   double close = iClose(_Symbol, PERIOD_M1, shift);
   return (close > open) ? "Bullish Bias" : "Bearish Bias";
}

//+------------------------------------------------------------------+
//| Show Signal Label on Chart                                       |
//+------------------------------------------------------------------+
void ShowSignalLabel(string signal)
{
   string fullLabel = signalLabel;
   ObjectDelete(0, fullLabel);

   ObjectCreate(0, fullLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, fullLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, fullLabel, OBJPROP_XDISTANCE, XDISTANCE);
   ObjectSetInteger(0, fullLabel, OBJPROP_YDISTANCE, YDISTANCE);
   ObjectSetInteger(0, fullLabel, OBJPROP_FONTSIZE, FontSize);

   color labelColor = clrYellow;
   if (signal == "Bullish Bias") labelColor = clrLime;
   else if (signal == "Bearish Bias") labelColor = clrRed;

   ObjectSetInteger(0, fullLabel, OBJPROP_COLOR, labelColor);
   ObjectSetString(0, fullLabel, OBJPROP_TEXT, signal);
}

//+------------------------------------------------------------------+
//| Timer Function - checks every second                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   datetime currentCandleTime = iTime(_Symbol, PERIOD_M1, 0);
   datetime nextCandleTime = currentCandleTime + PeriodSeconds(PERIOD_M1);
   datetime now = TimeCurrent();

   // Only run when within 5 seconds of candle close and no repeat
   if (now >= (nextCandleTime - 5) && currentCandleTime != lastSignalTime)
   {
      string signal = PredictNextCandleBias();
      ShowSignalLabel(signal);
      lastSignalTime = currentCandleTime;
   }
}
