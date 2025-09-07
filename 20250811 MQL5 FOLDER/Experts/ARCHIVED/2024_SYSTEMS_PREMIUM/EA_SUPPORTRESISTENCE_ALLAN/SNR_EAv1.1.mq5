//+------------------------------------------------------------------+
//|                                                       SNR_EA.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
/*
todo:
Early Loop Termination:
https://www.perplexity.ai/search/analyse-the-attached-brAVYa7nQfS6t9WrhYbzoQ
suggestions to improve performance



Once you've found a matching resistance or support level within a bar, there's no need to continue checking further. Use break; statements to exit the loops early when a match is found. This will significantly improve performance when analyzing large numbers of bars.


Additional Enhancements

Trend Filtering:

Incorporate trend analysis to filter out false signals. For example, you could only consider support levels in an uptrend and resistance levels in a downtrend.
Dynamic Levels:

Implement algorithms to dynamically adjust the S/R levels based on changing market conditions. This could involve considering volatility, volume, or other factors.
Multiple Timeframes:

Analyze support and resistance levels on multiple timeframes to get a more comprehensive view of the market.
Alerts and Notifications:

Add the ability to send alerts (e.g., email, push notifications) when trade signals are generated or trades are executed.
Backtesting and Optimization:

Thoroughly backtest the modified EA on historical data to assess its performance. Use optimization tools to fine-tune the parameters for optimal results.

*/
#include <Trade\Trade.mqh>
CTrade obj_Trade;

double pricesHighest[],
       pricesLowest[],
       resistenceLevels[2],
       supportLevels[2];

#define resLine "RESISTANCE LEVEL"
#define colorRes clrRed
#define resline_prefix "R"

#define supLine "SUPPORT LEVEL"
#define colorSup clrBlue
#define supline_prefix "S"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   ArraySetAsSeries(pricesHighest,true);
   ArraySetAsSeries(pricesLowest, true);
   ArrayResize(pricesHighest,50);
   ArrayResize(pricesLowest,50);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   ArrayFree(pricesHighest);
   ArrayFree(pricesLowest);
   ArrayRemove(resistenceLevels,0,WHOLE_ARRAY);
   ArrayRemove(supportLevels,0,WHOLE_ARRAY);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   int currBars = iBars(_Symbol,_Period);
   static int prevBars = currBars;
   if(prevBars == currBars)
      return;
   prevBars = currBars;
   int visible_bars = (int)ChartGetInteger(0,CHART_VISIBLE_BARS);
//===============================
   bool stop_processing = false; // Flag to control outer loop
   bool matchFound_high1 = false, matchFound_low1 = false;
   bool matchFound_high2 = false, matchFound_low2 = false;
   ArrayFree(pricesHighest);
   ArrayFree(pricesLowest);
   int copiedBarsHighs = CopyHigh(_Symbol,_Period,1,visible_bars,pricesHighest);
   int copiedBarsLows = CopyLow(_Symbol,_Period,1,visible_bars,pricesLowest);
   ArraySort(pricesHighest);
   ArraySort(pricesLowest);
   ArrayRemove(pricesHighest, 10,WHOLE_ARRAY);
   ArrayRemove(pricesLowest, 0, visible_bars-10);
//===================
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
   double open1 = iOpen(_Symbol,_Period,1);
   double high1 = iHigh(_Symbol,_Period,1);
   double low1 = iLow(_Symbol,_Period,1);
   double close1 = iClose(_Symbol,_Period,1);
//====================
   for(int i=1; i <= visible_bars-1 && !stop_processing; i++)
     {
      //Print(" :: BAR NO: ",i);
      double open = iOpen(_Symbol,_Period,i);
      double high = iHigh(_Symbol,_Period,i);
      double low = iLow(_Symbol,_Period,i);
      double close = iClose(_Symbol,_Period,i);
      datetime time = iTime(_Symbol,_Period,i);
      //===============================
      int diff_i_j = 10;
      for(int j=i+diff_i_j; j <= visible_bars-1; j++)
        {
         //Print("BAR CHECK NO: ",j);
         double open_j = iOpen(_Symbol,_Period,j);
         double high_j = iHigh(_Symbol,_Period,j);
         double low_j = iLow(_Symbol,_Period,j);
         double close_j = iClose(_Symbol,_Period,j);
         datetime time_j =iTime(_Symbol,_Period,j);
         //check for resistence
         double high_diff = NormalizeDouble((MathAbs(high-high_j)/_Point),0);
         bool is_resistence=high_diff <=10;
         //check for support
         double low_diff = NormalizeDouble((MathAbs(low-low_j)/_Point),0);
         bool is_support=low_diff <=10;
         //===============================
         if(is_resistence)
           {
            for(int k=0; k<ArraySize(pricesHighest); k++)
              {
               if(pricesHighest[k] == high)
                 {
                  matchFound_high1 = true;
                 }
               if(pricesHighest[k] == high_j)
                 {
                  matchFound_high2 = true;
                 }
               if(matchFound_high1 && matchFound_high2)
                 {
                  if(resistenceLevels[0] == high || resistenceLevels[1] == high_j)
                    {
                     Print("CONFIRMED BUT This is the same resistance level, skip update");
                     stop_processing = true; // Set the flag to stop processing
                     break; // stop the inner loop prematurily
                    }
                  else
                    {
                     Print(" ++++++++++ RESISTANCE LEVELS CONFIRMED @ BARS ",i,
                           "(",high,") & ",j,"(",high_j,")");
                     resistenceLevels[0] = high;
                     resistenceLevels[1] = high_j;
                     ArrayPrint(resistenceLevels);
                     draw_S_R_Level(resLine,high, colorRes, 5);
                     draw_S_R_Level(resLine,high,colorRes,5);
                     draw_S_R_Level_Point(resline_prefix,high, time, 218,-1, colorRes, 90);
                     draw_S_R_Level_Point(resline_prefix,high,time_j,218,-1, colorRes, 90);
                     stop_processing = true; // Set the flag to stop processing
                     break;
                    }
                 }
              }//for loop
           }//is reisstence
         else
            if(is_support)
              {
               for(int k=0; k<ArraySize(pricesLowest); k++)
                 {
                  if(pricesLowest[k] == low)
                    {
                     matchFound_low1 = true;
                     if(pricesLowest[k] == low_j)
                       {
                        matchFound_low2 = true;
                        //Print("> SUP L2(",low_j,") FOUND @ ",k," (",pricesLowest[k],")")
                       }
                     if(matchFound_low1 && matchFound_low2)
                       {
                        if(supportLevels[0] == low || supportLevels[1] == low_j)
                          {
                           Print("CONFIRMED BUT This is the same support level, skip updating");
                           stop_processing = true; // Set the flag to stop processing
                           break; // stop the inner loop prematurely
                          }
                        else
                          {
                           Print(" ++++++ SUPPORT LEVELS CONFIRMED @ BARS ",i,
                                 "(",low,") & ",j,"(",low_j,")");
                           supportLevels[0] = low;
                           supportLevels[1] = low_j;
                           ArrayPrint(supportLevels);
                           draw_S_R_Level(supLine, low,colorSup,5);
                           draw_S_R_Level_Point(supline_prefix,low,time, 217,1,colorSup,-90);
                           draw_S_R_Level_Point(supline_prefix,low, time_j, 217,1, colorSup, -90);
                           stop_processing = true; // Set the flag to stop processing
                           break;
                          }
                       }//matchFound_low1 && matchFound_low2
                    }//pricesLowest[k] == low
                 }//for loop
               if(stop_processing)
                 {
                  break;
                 }
              }
         if(stop_processing)
           {
            break;
           }
        }//for loop
      if(ObjectFind(0,resLine) >=0)
        {
         double objPrice = ObjectGetDouble(0,resLine,OBJPROP_PRICE);
         double visibleHighs[];
         ArraySetAsSeries(visibleHighs,true);
         CopyHigh(_Symbol,_Period,1,visible_bars,visibleHighs);
         bool matchHighFound = false;
         for(int i=0; i<ArraySize(visibleHighs); i++)
           {
            if(visibleHighs[i] == objPrice)
              {
               Print("> Match price for resistance found at bar # ",i+1," (", objPrice);
               matchHighFound = true;
               break;
              }
           }
         if(!matchHighFound)
           {
            Print("(",objPrice,") > Match price for the resistance line not found. Delete");
            deleteLevel(resLine);
           }
        }
      if(ObjectFind(0,supLine) >= 0)
        {
         double objPrice = ObjectGetDouble(0,supLine,OBJPROP_PRICE);
         double visibleLows[];
         ArraySetAsSeries(visibleLows, true);
         CopyLow(_Symbol,_Period,1,visible_bars,visibleLows);
         bool matchLowFound = false;
         for(int i=0; i<ArraySize(visibleLows); i++)
           {
            if(visibleLows[i] == objPrice)
              {
               Print("> Match price for support found at bar # ",i+1," (",objPrice,")");
               matchLowFound = true;
               break;
              }
           }
         if(!matchLowFound)
           {
            Print("(",objPrice,") > Match price for the support line not found. Delete!");
            deleteLevel(supLine);
           }
        }
      static double ResistancePriceTrade = 0;
      if(ObjectFind(0,resLine) >=0)
        {
         double ResistancePriceLevel = ObjectGetDouble(0,resLine,OBJPROP_PRICE);
         if(ResistancePriceTrade != ResistancePriceLevel)
           {
            if(open1 > close1 && open1 < ResistancePriceLevel
               && high1 > ResistancePriceLevel && Bid < ResistancePriceLevel)
              {
               Print("$$$$$$$$$$$$ SELL NOW SIGNAL!");
               obj_Trade.Sell(0.01,_Symbol,Bid,Bid+350*5 *_Point,Bid-350 *_Point);
               ResistancePriceTrade = ResistancePriceLevel;
              }
           }
        }
      static double SupportPriceTrade = 0;
      if(ObjectFind(0,supLine) >= 0)
        {
         double SupportPriceLevel = ObjectGetDouble(0,supLine,OBJPROP_PRICE);
         if(SupportPriceTrade != SupportPriceLevel)
           {
            if(open1 < close1 && open1 > SupportPriceLevel
               && low1 < SupportPriceLevel && Ask > SupportPriceLevel)
              {
               Print("$$$$$$$$$$$$ BUY NOW SIGNAL!");
               obj_Trade.Buy(0.01,_Symbol,Ask,Ask-350*5 *_Point,Ask+350 *_Point);
               SupportPriceTrade = SupportPriceLevel;
              }
           }
        }
     }//for loop
  }//end routine

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void draw_S_R_Level(string levelName, double price, color clr,int width)
  {
   if(ObjectFind(0,levelName) <0)
     {
      ObjectCreate(0,levelName, OBJ_HLINE,0,TimeCurrent(),price);
      ObjectSetInteger(0,levelName, OBJPROP_COLOR,clr);
      ObjectSetInteger(0,levelName, OBJPROP_WIDTH,width);
     }
   else
     {
      ObjectSetDouble(0,levelName, OBJPROP_PRICE,price);
     }
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void deleteLevel(string levelName)
  {
   ObjectDelete(0,levelName);
   ChartRedraw(0);
//+------------------------------------------------------------------+
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void draw_S_R_Level_Point(string objName, double price,datetime time,
                          int arrowcode, int direction, color clr, double angle)
  {
   StringConcatenate(objName, objName," @\nTime: ",time,"\nPrice: ",DoubleToString(price));
   if(ObjectCreate(0,objName,OBJ_ARROW,0,time,price))
     {
      ObjectSetInteger(0,objName, OBJPROP_ARROWCODE,arrowcode);
      ObjectSetInteger(0,objName, OBJPROP_COLOR,clr);
      ObjectSetInteger(0,objName,OBJPROP_FONTSIZE,10);
      if(direction > 0)
         ObjectSetInteger(0,objName,OBJPROP_ANCHOR,ANCHOR_TOP);
      if(direction < 0)
         ObjectSetInteger(0,objName, OBJPROP_ANCHOR,ANCHOR_BOTTOM);
     }
   string prefix = resline_prefix;
   string txt = "\n"+prefix+"("+DoubleToString(price,_Digits)+")";
   string objNameDescription = objName + txt;
   if(ObjectCreate(0,objNameDescription,OBJ_TEXT,0,time,price))
     {
      // ObjectSetString(0,objNameDescription,OBJPROP_TEXT, ""+ txt);
      ObjectSetInteger(0,objNameDescription, OBJPROP_COLOR,clr);
      ObjectSetDouble(0,objNameDescription, OBJPROP_ANGLE, angle);
      ObjectSetInteger(0,objNameDescription,OBJPROP_FONTSIZE,10);
      if(direction > 0)
        {
         ObjectSetInteger(0,objNameDescription, OBJPROP_ANCHOR, ANCHOR_LEFT);
         ObjectSetString(0,objNameDescription, OBJPROP_TEXT, "     "+txt);
        }
      if(direction < 0)
        {
         ObjectSetInteger(0,objNameDescription, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
         ObjectSetString(0, objNameDescription, OBJPROP_TEXT, "     "+txt);
        }
     }
   ChartRedraw(0);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
