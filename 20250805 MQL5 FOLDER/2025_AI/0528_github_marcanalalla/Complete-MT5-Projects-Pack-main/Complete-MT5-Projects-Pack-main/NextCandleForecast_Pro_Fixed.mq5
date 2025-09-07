//+------------------------------------------------------------------+
//|                                             NextCandleForecast_Pro.mq5 |
//|               Forecasts next candle breakout with Winrate Display |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   0

#include <ChartObjects\ChartObjectsTxtControls.mqh>

// Input parameters
input int      xDistance = 10;
input int      yDistance = 10;
input int      FontSize  = 12;
input ENUM_TIMEFRAMES HTF = PERIOD_M5;
input ENUM_TIMEFRAMES LTF = PERIOD_M1;
input int      SignalDisplayTime = 60;  // Time in seconds to display signal

string labelName = "NextCandleForecastLabel";
string winrateLabelName = "WinrateLabel";

double dummyBuffer[];

// Tracking
datetime lastSignalTime = 0;
string lastSignal = "";
int totalSignals = 0;
int totalWins = 0;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, dummyBuffer, INDICATOR_DATA);
   CreateLabel();
   CreateWinrateLabel();
   EventSetTimer(1);  // Check every second
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectDelete(0, labelName);
   ObjectDelete(0, winrateLabelName);
  }

//+------------------------------------------------------------------+
//| Timer event                                                      |
//+------------------------------------------------------------------+
void OnTimer()
  {
   datetime currentTime = TimeCurrent();
   datetime candleClose = iTime(_Symbol, LTF, 0) + PeriodSeconds(LTF);

   // Check if within 5 seconds of candle close
   if((candleClose - currentTime) <= 5 && (candleClose - currentTime) > 0)
     {
      string signalText = GetForecastSignal();
      UpdateLabel(signalText);
      lastSignalTime = currentTime;
      lastSignal = signalText;
      if(signalText == "Bullish Breakout Likely" || signalText == "Bearish Breakout Likely")
         totalSignals++;
     }
   
   // After 1 candle closes, check if forecast was correct
   if(currentTime - lastSignalTime >= PeriodSeconds(LTF) && lastSignal != "")
     {
      CheckForecastResult();
      lastSignal = "";
     }

   // Remove signal after timeout
   if(currentTime - lastSignalTime > SignalDisplayTime)
     {
      UpdateLabel("No Clear Breakout");
     }
  }

//+------------------------------------------------------------------+
//| Forecast Signal Based on Enhanced Logic                         |
//+------------------------------------------------------------------+
string GetForecastSignal()
  {
   double ltfHighPrev = iHigh(_Symbol, LTF, 1);
   double ltfLowPrev  = iLow(_Symbol, LTF, 1);
   double ltfClosePrev = iClose(_Symbol, LTF, 1);
   double ltfOpenPrev = iOpen(_Symbol, LTF, 1);

   double htfClosePrev = iClose(_Symbol, HTF, 1);
   double htfCurrentClose = iClose(_Symbol, HTF, 0);
   double ltfCurrentClose = iClose(_Symbol, LTF, 0);

   // Corrected RSI parameters
   double ltfRsi = iRSI(_Symbol, LTF, 14, PRICE_CLOSE, 0); // Correct parameter count
   long ltfVolumePrev = iTickVolume(_Symbol, LTF, 1);
   long ltfVolumeCurrent = iTickVolume(_Symbol, LTF, 0);

   double candleBody = MathAbs(ltfCurrentClose - iOpen(_Symbol, LTF, 0));
   double candleWick = iHigh(_Symbol, LTF, 0) - iLow(_Symbol, LTF, 0);

   bool strongBody = candleBody > (candleWick * 0.5);
   bool strongVolume = ltfVolumeCurrent > (1.5 * ltfVolumePrev);

   // Final Breakout + HTF + RSI + Volume + Body confirmation
   if(ltfCurrentClose > ltfHighPrev && htfCurrentClose > htfClosePrev && ltfRsi > 50 && strongVolume && strongBody)
      return "Bullish Breakout Likely";
   else if(ltfCurrentClose < ltfLowPrev && htfCurrentClose < htfClosePrev && ltfRsi < 50 && strongVolume && strongBody)
      return "Bearish Breakout Likely";
   else
      return "No Clear Breakout";
  }

//+------------------------------------------------------------------+
//| Check if Forecast was correct                                   |
//+------------------------------------------------------------------+
void CheckForecastResult()
  {
   double close0 = iClose(_Symbol, LTF, 0);
   double close1 = iClose(_Symbol, LTF, 1);

   if(lastSignal == "Bullish Breakout Likely" && close0 > close1)
      totalWins++;
   else if(lastSignal == "Bearish Breakout Likely" && close0 < close1)
      totalWins++;

   UpdateWinrateLabel();
  }

//+------------------------------------------------------------------+
//| Create chart label                                               |
//+------------------------------------------------------------------+
void CreateLabel()
  {
   if(!ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0))
      Print("Failed to create label!");
   ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, xDistance);
   ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, yDistance);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, FontSize);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
  }

//+------------------------------------------------------------------+
//| Create Winrate label                                             |
//+------------------------------------------------------------------+
void CreateWinrateLabel()
  {
   if(!ObjectCreate(0, winrateLabelName, OBJ_LABEL, 0, 0, 0))
      Print("Failed to create winrate label!");
   ObjectSetInteger(0, winrateLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, winrateLabelName, OBJPROP_XDISTANCE, xDistance);
   ObjectSetInteger(0, winrateLabelName, OBJPROP_YDISTANCE, yDistance + 20);
   ObjectSetInteger(0, winrateLabelName, OBJPROP_FONTSIZE, FontSize);
   ObjectSetInteger(0, winrateLabelName, OBJPROP_COLOR, clrAqua);
   ObjectSetString(0, winrateLabelName, OBJPROP_FONT, "Arial");
  }

//+------------------------------------------------------------------+
//| Update label with forecast text                                  |
//+------------------------------------------------------------------+
void UpdateLabel(string text)
  {
   ObjectSetString(0, labelName, OBJPROP_TEXT, "Next Candle: " + text);

   if(text == "Bullish Breakout Likely")
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrLime);
   else if(text == "Bearish Breakout Likely")
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrRed);
   else
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrYellow);
  }

//+------------------------------------------------------------------+
//| Update Winrate label                                             |
//+------------------------------------------------------------------+
void UpdateWinrateLabel()
  {
   double winrate = (totalSignals > 0) ? (double(totalWins) / totalSignals) * 100.0 : 0.0;
   string text = StringFormat("Winrate: %.1f%% (%d/%d)", winrate, totalWins, totalSignals);
   ObjectSetString(0, winrateLabelName, OBJPROP_TEXT, text);
  }

//+------------------------------------------------------------------+
//| Mandatory for custom indicator                                   |
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
   return(rates_total);
  }
//+------------------------------------------------------------------+