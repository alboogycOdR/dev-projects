//+------------------------------------------------------------------+
//|                                    Supertrend_KivancOzbilgic.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                               Author: GenAI 2023 |
//|                         Complete and Corrected Version (v. 2.0)  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 9
#property indicator_plots   4
//--- plot UpLine
#property indicator_label1  "UpLine"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
//--- plot DnLine
#property indicator_label2  "DnLine"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2
//--- plot UpArrow
#property indicator_label3  "UpArrow"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrGreen
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2
//--- plot DnArrow
#property indicator_label4  "DnArrow"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

//+------------------------------------------------------------------+
//| Global Variables and Inputs                                      |
//+------------------------------------------------------------------+
//--- Alert control
static datetime lastTimeAlert=0;

//--- Source price enumeration for the input
enum ENUM_SOURCE
  {
   OPEN,
   CLOSE,
   HIGH,
   LOW,
   HL2,   // (High+Low)/2
   HLC3,  // (High+Low+Close)/3
   OHLC4, // (Open+High+Low+Close)/4
   HLCC4  // (High+Low+Close+Close)/4
  };

//--- User Inputs
input int          Periods     = 10;     //ATR Period
input ENUM_SOURCE  src         = HL2;    //Source
input double       Multiplier  = 3;      //ATR Multiplier
input bool         changeATR   = true;   //Change ATR Calculation Method ?
input bool         enable_alerts=false; //Enable Alerts

//--- Indicator Buffers
double         UpLineBuffer[];
double         DnLineBuffer[];
double         UpArrowBuffer[];
double         DnArrowBuffer[];
//--- Calculation Buffers
double         trBuffer[];
double         atrBuffer[];
double         upBuffer[];
double         downBuffer[];
double         trendBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0, UpLineBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, DnLineBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, UpArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, DnArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, trBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, atrBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, upBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, downBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, trendBuffer, INDICATOR_CALCULATIONS);

//--- Set arrays as time series. Crucial for using [1] to access previous value.
   ArraySetAsSeries(UpLineBuffer, true);
   ArraySetAsSeries(DnLineBuffer, true);
   ArraySetAsSeries(UpArrowBuffer, true);
   ArraySetAsSeries(DnArrowBuffer, true);
   ArraySetAsSeries(trBuffer, true);
   ArraySetAsSeries(atrBuffer, true);
   ArraySetAsSeries(upBuffer, true);
   ArraySetAsSeries(downBuffer, true);
   ArraySetAsSeries(trendBuffer, true);

//--- Set empty values for plotting gaps
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Arrow styling for up/down signals
   PlotIndexSetInteger(2, PLOT_ARROW, 233); // Up Arrow
   PlotIndexSetInteger(3, PLOT_ARROW, 234); // Down Arrow

//--- Set plot labels that will appear in the Data Window
   PlotIndexSetString(0, PLOT_LABEL, "Supertrend Up");
   PlotIndexSetString(1, PLOT_LABEL, "Supertrend Down");

//--- Set the shortname for the indicator
   IndicatorSetString(INDICATOR_SHORTNAME, "Supertrend("+(string)Periods+","+(string)Multiplier+")");

   return(INIT_SUCCEEDED);
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
//--- Check for enough bars to calculate
   if(rates_total < Periods + 1)
      return(0);

//--- Calculate the starting point for the main loop
   int start_bar;
   if(prev_calculated == 0)
     {
      // First run, calculate everything, leaving space for ATR period.
      start_bar = rates_total - Periods - 1;
     }
   else
     {
      // On subsequent calls, only calculate new bars.
      start_bar = rates_total - prev_calculated;
     }

//--- The main calculation loop (runs backwards, from present to past)
   for(int i = start_bar; i >= 0; i--)
     {
      //--- 1. Calculate Source Price
      double src_price=0;
      switch(src)
        {
         case OPEN:  src_price=open[i];   break;
         case CLOSE: src_price=close[i];  break;
         case HIGH:  src_price=high[i];   break;
         case LOW:   src_price=low[i];    break;
         case HL2:   src_price=(high[i]+low[i])/2.0; break;
         case HLC3:  src_price=(high[i]+low[i]+close[i])/3.0; break;
         case OHLC4: src_price=(open[i]+high[i]+low[i]+close[i])/4.0; break;
         case HLCC4: src_price=(high[i]+low[i]+close[i]+close[i])/4.0; break;
        }

      //--- 2. Calculate True Range and ATR
      trBuffer[i] = MathMax(high[i], (i+1 < rates_total) ? close[i+1] : high[i]) - MathMin(low[i], (i+1 < rates_total) ? close[i+1] : low[i]);

      if(changeATR)
        {
         // Pine 'atr(Periods)' is an RMA (a type of smoothed MA). Replicating it.
         if(i == rates_total - Periods -1) // On the first bar we can calculate
           {
            // For the first calculation, it's just a SMA of TR
            double first_atr_sum = 0;
            for(int j=0; j < Periods; j++) { first_atr_sum += trBuffer[i+j]; }
            atrBuffer[i] = first_atr_sum / Periods;
           }
         else
           {
            atrBuffer[i] = (atrBuffer[i+1] * (Periods - 1) + trBuffer[i]) / Periods;
           }
        }
      else
        {
         // Pine `sma(tr, Periods)`. Simple moving average of our TR buffer.
         double sum_tr = 0;
         for(int j=0; j<Periods; j++) { sum_tr += trBuffer[i+j]; }
         atrBuffer[i] = sum_tr/Periods;
        }

      //--- 3. Calculate Bands
      upBuffer[i] = src_price - (Multiplier * atrBuffer[i]);
      downBuffer[i] = src_price + (Multiplier * atrBuffer[i]);
      
      //--- 4. Trend state logic. Crucial to do this *before* band adjustment.
      if(i == rates_total-1)
         trendBuffer[i] = 1; // Default to uptrend on very first bar
      else
         trendBuffer[i] = trendBuffer[i+1]; // Carry over trend state from previous bar
         
      if(trendBuffer[i+1] == -1 && close[i] > downBuffer[i+1])
         trendBuffer[i] = 1;
      else if(trendBuffer[i+1] == 1 && close[i] < upBuffer[i+1])
         trendBuffer[i] = -1;
         
      //--- 5. Adjust Bands based on trend and previous *band* values. This is the 'stairstep' logic.
      if(trendBuffer[i] == 1) // In an uptrend...
        {
         //...the UP band can only rise or stay flat.
         if (upBuffer[i] < upBuffer[i+1])
            upBuffer[i] = upBuffer[i+1];
        }
      else // In a downtrend...
        {
         //...the DOWN band can only fall or stay flat.
         if (downBuffer[i] > downBuffer[i+1])
            downBuffer[i] = downBuffer[i+1];
        }

      //--- 6. Populate Plot Buffers for trend lines
      if(trendBuffer[i] == 1)
        {
         UpLineBuffer[i] = upBuffer[i];
         DnLineBuffer[i] = EMPTY_VALUE;
        }
      else
        {
         DnLineBuffer[i] = downBuffer[i];
         UpLineBuffer[i] = EMPTY_VALUE;
        }

      //--- 7. Generate Buy/Sell Signals & Arrows
      bool buySignal = (trendBuffer[i] == 1 && (i+1 < rates_total) && trendBuffer[i+1] == -1);
      bool sellSignal = (trendBuffer[i] == -1 && (i+1 < rates_total) && trendBuffer[i+1] == 1);

      UpArrowBuffer[i] = buySignal ? low[i] - (SymbolInfoDouble(_Symbol, SYMBOL_POINT)*15) : EMPTY_VALUE;
      DnArrowBuffer[i] = sellSignal ? high[i] + (SymbolInfoDouble(_Symbol, SYMBOL_POINT)*15) : EMPTY_VALUE;

      //--- 8. Handle Alerts
      if((buySignal || sellSignal) && i == 0 && time[i] != lastTimeAlert && enable_alerts)
        {
         Alert(_Symbol, " ", EnumToString(_Period), ": SuperTrend has changed to ", (buySignal ? "UP" : "DOWN"));
         lastTimeAlert = time[i];
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+