//+------------------------------------------------------------------+
//|                                                   SMC FVG EA.mq5 |
//|                                          Copyright 2024, Usiola. |
//|                                   https://www.trenddaytrader.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Usiola."
#property link      "https://www.trenddaytrader.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
CTrade Trade;

int barsTotal;

input double risk2reward = 2;
input double Lots = 0.01;

input double breakevenTrigger = 10000;
input double breakeven = 2000;


//Swing
double Highs[];
double Lows[];
datetime HighsTime[];
datetime LowsTime[];

int LastSwingMeter = 0;

//FVG
double BuFVGHighs[];
double BuFVGLows[];
datetime BuFVGTime[];

double BeFVGHighs[];
double BeFVGLows[];
datetime BeFVGTime[];


int lastTimeH = 0;
int prevTimeH = 0;
int lastTimeL = 0;
int prevTimeL = 0;

double handlesma;

//Order Block CURRENT

double bullishOrderBlockHigh[];
double bullishOrderBlockLow[];
datetime bullishOrderBlockTime[];


double bearishOrderBlockHigh[];
double bearishOrderBlockLow[];
datetime bearishOrderBlockTime[];


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {



   ArraySetAsSeries(Highs,true);
   ArraySetAsSeries(Lows,true);
   ArraySetAsSeries(HighsTime,true);
   ArraySetAsSeries(LowsTime,true);

   ArraySetAsSeries(BuFVGHighs,true);
   ArraySetAsSeries(BuFVGLows,true);
   ArraySetAsSeries(BuFVGTime,true);

   ArraySetAsSeries(BeFVGHighs,true);
   ArraySetAsSeries(BeFVGLows,true);
   ArraySetAsSeries(BeFVGTime,true);

   ArraySetAsSeries(bullishOrderBlockHigh,true);
   ArraySetAsSeries(bullishOrderBlockLow,true);
   ArraySetAsSeries(bullishOrderBlockTime,true);

   ArraySetAsSeries(bearishOrderBlockHigh,true);
   ArraySetAsSeries(bearishOrderBlockLow,true);
   ArraySetAsSeries(bearishOrderBlockTime,true);


   handlesma = iMA(_Symbol,PERIOD_H1,89,0,MODE_SMA,PRICE_CLOSE);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {


  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

   int bars = iBars(_Symbol, PERIOD_CURRENT);

   if(barsTotal != bars)
     {
      barsTotal = bars;


      //SMA INDICATOR BUFFER

      double sma[];
      ArraySetAsSeries(sma, true);
      CopyBuffer(handlesma,MAIN_LINE,0,9,sma);



      MqlRates rates[];
      ArraySetAsSeries(rates,true);
      int copied = CopyRates(_Symbol,PERIOD_CURRENT,0,50,rates);


      //int SwingSignal = swingPoints();



      //FVG();

      orderBlock();

      //BUY TRADE


      if
      (
         ArraySize(Lows) > 1 &&
         ArraySize(BuFVGHighs) > 0 &&
         ArraySize(HighsTime) > 0 &&

         Lows[1] > sma[1] &&

         Lows[0] < BuFVGHighs[0] &&
         BuFVGTime[0] > LowsTime[1] &&
         BuFVGTime[0] < HighsTime[0] &&

         Lows[0] > Lows[1] &&
         LowsTime[0] > HighsTime[0] &&
         rates[1].close >  rates[1].open //&&
         //SwingSignal > 0
      )
        {
         double entryprice = rates[1].close;
         entryprice = NormalizeDouble(entryprice,_Digits);

         double stoploss = Lows[1];
         stoploss = NormalizeDouble(stoploss,_Digits);

         double riskvalue = entryprice - stoploss;
         riskvalue = NormalizeDouble(riskvalue,_Digits);

         double takeprofit = entryprice + (risk2reward * riskvalue);
         takeprofit = NormalizeDouble(takeprofit,_Digits);

         Trade.PositionOpen(_Symbol,ORDER_TYPE_BUY, Lots,entryprice, stoploss, takeprofit, "Buy Test");

        }



      //SELL TRADE


      if
      (
         ArraySize(Highs) > 1 &&
         ArraySize(BeFVGLows) > 0 &&
         ArraySize(LowsTime) > 0 &&

         Highs[1] < sma[1] &&

         Highs[0] > BeFVGLows[0] &&
         BeFVGTime[0] < LowsTime[0] &&
         BeFVGTime[0] > HighsTime[1] &&

         Highs[0] < Highs[1] &&
         LowsTime[0] < HighsTime[0] &&
         rates[1].close <  rates[1].open //&&
         //SwingSignal < 0
      )
        {
         double entryprice = rates[1].close;
         entryprice = NormalizeDouble(entryprice,_Digits);

         double stoploss = Highs[1];
         stoploss = NormalizeDouble(stoploss,_Digits);

         double riskvalue = stoploss - entryprice;
         riskvalue = NormalizeDouble(riskvalue,_Digits);

         double takeprofit = entryprice - (risk2reward * riskvalue);
         takeprofit = NormalizeDouble(takeprofit,_Digits);

         Trade.PositionOpen(_Symbol,ORDER_TYPE_SELL, Lots,entryprice, stoploss, takeprofit, "Sell Test");

        }



      //BREAKEVEN TRIGGER

      for(int a = PositionsTotal()-1; a >=0; a--)
        {
         ulong positionTicketa = PositionGetTicket(a);
         if(PositionSelectByTicket(positionTicketa))
           {
            double posSL = PositionGetDouble(POSITION_SL);
            double posTP = PositionGetDouble(POSITION_TP);
            double posEntryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double posCurrentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            string tradeSymbol = PositionGetString(POSITION_SYMBOL);

            if
            (
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
              {
               double breakevenTriggerB = (posEntryPrice + breakevenTrigger*_Point);
               breakevenTriggerB = NormalizeDouble(breakevenTriggerB, _Digits);

               double newSlB = (posEntryPrice + breakeven*_Point);
               newSlB = NormalizeDouble(newSlB, _Digits);

               if(
                  tradeSymbol == _Symbol &&
                  posCurrentPrice > breakevenTriggerB &&
                  posSL < posEntryPrice
               )
                 {
                  if(Trade.PositionModify(positionTicketa, newSlB, posTP))
                     Print(__FUNCTION__,"Pos #",positionTicketa, " WAS MODIFIED TO BREAKEVEN FOR BUY");
                 }
              }

            if
            (
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
              {
               double breakevenTriggerS = (posEntryPrice - breakevenTrigger*_Point);
               breakevenTriggerS = NormalizeDouble(breakevenTriggerS, _Digits);

               double newSlS = (posEntryPrice - breakeven*_Point);
               newSlS = NormalizeDouble(newSlS, _Digits);

               if(
                  tradeSymbol == _Symbol &&
                  posCurrentPrice < breakevenTriggerS &&
                  posSL > posEntryPrice
               )
                 {
                  if(Trade.PositionModify(positionTicketa, newSlS, posTP))
                     Print(__FUNCTION__,"Pos #",positionTicketa, " WAS MODIFIED TO BREAKEVEN FOR SELL");
                 }
              }

           }



        }


     }
  }

//+------------------------------------------------------------------+
void createObj(datetime time, double price, int arrowCode, int direction, color clr, string txt)
  {
   string objName ="";
   StringConcatenate(objName, "Signal@", time, "at", DoubleToString(price, _Digits), "(", arrowCode, ")");

   double ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double spread=ask-bid;

   if(direction > 0)
     {
      price += 2*spread * _Point;
     }
   else
      if(direction < 0)
        {
         price -= 2*spread * _Point;
        }

   if(ObjectCreate(0, objName, OBJ_ARROW, 0, time, price))
     {
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      if(direction > 0)
         ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_TOP);
      if(direction < 0)
         ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
     }
   string objNameDesc = objName + txt;
   if(ObjectCreate(0, objNameDesc, OBJ_TEXT, 0, time, price))
     {
      ObjectSetString(0, objNameDesc, OBJPROP_TEXT, "  " + txt);
      ObjectSetInteger(0, objNameDesc, OBJPROP_COLOR, clr);
      if(direction > 0)
         ObjectSetInteger(0, objNameDesc, OBJPROP_ANCHOR, ANCHOR_TOP);
      if(direction < 0)
         ObjectSetInteger(0, objNameDesc, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
     }
  }

//+------------------------------------------------------------------+
//| Function to delete objects created by createObj                   |
//+------------------------------------------------------------------+
void deleteObj(datetime time, double price, int arrowCode, string txt)
  {
// Create the object name using the same format as createObj
   string objName = "";
   StringConcatenate(objName, "Signal@", time, "at", DoubleToString(price, _Digits), "(", arrowCode, ")");

// Delete the arrow object
   if(ObjectFind(0, objName) != -1) // Check if the object exists
     {
      ObjectDelete(0, objName);
     }

// Create the description object name
   string objNameDesc = objName + txt;

// Delete the text object
   if(ObjectFind(0, objNameDesc) != -1) // Check if the object exists
     {
      ObjectDelete(0, objNameDesc);
     }
  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int swingPoints()
  {


   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int copied = CopyRates(_Symbol,PERIOD_CURRENT,0,50,rates);



   int indexLastH = iBarShift(_Symbol,PERIOD_CURRENT,lastTimeH);
   int indexLastL = iBarShift(_Symbol,PERIOD_CURRENT,lastTimeL);
   int indexPrevH = iBarShift(_Symbol,PERIOD_CURRENT,prevTimeH);
   int indexPrevL = iBarShift(_Symbol,PERIOD_CURRENT,prevTimeL);




//Break Of Structure


//Bullish

   if(indexLastH > 0 && indexLastL > 0 && indexPrevH > 0 && indexPrevL > 0)
     {
      if(rates[indexLastL].low > rates[indexPrevL].low &&
         rates[1].close > rates[indexLastH].high &&
         rates[2].close < rates[indexLastH].high
        )
        {
         string objname = "SMC BoS" + TimeToString(rates[indexLastH].time);
         if(ObjectFind(0,objname) < 0)
            ObjectCreate(0,objname,OBJ_TREND,0,rates[indexLastH].time,rates[indexLastH].high,rates[1].time,rates[indexLastH].high);
         ObjectSetInteger(0,objname,OBJPROP_COLOR, clrBlue);
         ObjectSetInteger(0,objname,OBJPROP_WIDTH, 4);

         createObj(rates[indexLastH].time, rates[indexLastH].high, 0, 1, clrBlue, "BoS");
        }

      //BEARISH

      if(rates[indexLastH].high > rates[indexPrevH].high &&
         rates[1].close < rates[indexLastL].low &&
         rates[2].close > rates[indexLastL].low
        )
        {
         string objname = "SMC BoS" + TimeToString(rates[indexLastL].time);
         if(ObjectFind(0,objname) < 0)
            ObjectCreate(0,objname,OBJ_TREND,0,rates[indexLastL].time,rates[indexLastL].low,rates[1].time,rates[indexLastL].low);
         ObjectSetInteger(0,objname,OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0,objname,OBJPROP_WIDTH, 4);

         createObj(rates[indexLastL].time, rates[indexLastL].low, 0, 1, clrRed, "BoS");
        }
     }

//Change of Character

//Bullish

   if(indexLastH > 0 && indexLastL > 0 && indexPrevH > 0 && indexPrevL > 0)
     {
      if(rates[indexLastH].high < rates[indexPrevH].high && rates[indexLastL].low < rates[indexPrevL].low &&
         rates[1].close > rates[indexLastH].high &&
         rates[2].close < rates[indexLastH].high
        )
        {
         string objname = "SMC CHoCH" + TimeToString(rates[indexLastH].time);
         if(ObjectFind(0,objname) < 0)
            ObjectCreate(0,objname,OBJ_TREND,0,rates[indexLastH].time,rates[indexLastH].high,rates[1].time,rates[indexLastH].high);
         ObjectSetInteger(0,objname,OBJPROP_COLOR, clrGreen);
         ObjectSetInteger(0,objname,OBJPROP_WIDTH, 4);

         createObj(rates[indexLastH].time, rates[indexLastH].high, 0, 1, clrGreen, "CHoCH");
        }

      //BEARISH

      if(rates[indexLastH].high > rates[indexPrevH].high && rates[indexLastL].low > rates[indexPrevL].low &&
         rates[1].close < rates[indexLastL].low &&
         rates[2].close > rates[indexLastL].low
        )
        {
         string objname = "SMC CHoCH" + TimeToString(rates[indexLastL].time);
         if(ObjectFind(0,objname) < 0)
            ObjectCreate(0,objname,OBJ_TREND,0,rates[indexLastL].time,rates[indexLastL].low,rates[1].time,rates[indexLastL].low);
         ObjectSetInteger(0,objname,OBJPROP_COLOR, clrDarkOrange);
         ObjectSetInteger(0,objname,OBJPROP_WIDTH, 4);

         createObj(rates[indexLastL].time, rates[indexLastL].low, 0, 1, clrDarkOrange, "CHoCH");
        }


     }

//Swing Detection
//SwingHigh

   if
   (
      rates[2].high > rates[3].high &&
      rates[2].high > rates[1].high
   )
     {
      double highvalue =  rates[2].high;
      datetime hightime = rates[2].time;



      if(
         LastSwingMeter < 0 &&
         highvalue < Highs[0]
      )
        {
         return 0;
        }



      if(
         LastSwingMeter < 0 &&
         highvalue > Highs[0]
      )
        {
         deleteObj(HighsTime[0], Highs[0], 234, "");
         ArrayRemove(Highs, 0, 1);
         ArrayRemove(HighsTime, 0, 1);

         // Store highvalue in Highs[]

         // Shift existing elements in Highs[] to make space for the new value
         ArrayResize(Highs, MathMin(ArraySize(Highs) + 1, 10));
         for(int i = ArraySize(Highs) - 1; i > 0; --i)
           {
            Highs[i] = Highs[i - 1];
           }

         // Store highvalue in Highs[0], the first position
         Highs[0] = highvalue;

         // Store hightime in HighsTime[]

         // Shift existing elements in HighsTime[] to make space for the new value
         ArrayResize(HighsTime, MathMin(ArraySize(HighsTime) + 1, 10));
         for(int i = ArraySize(HighsTime) - 1; i > 0; --i)
           {
            HighsTime[i] = HighsTime[i - 1];
           }

         // Store hightime in HighsTime[0], the first position
         HighsTime[0] = hightime;

         prevTimeH = lastTimeH;
         lastTimeH = hightime;

         //createObj(rates[2].time,rates[2].high, 234, -1, clrGreen, "");
         LastSwingMeter = -1;
         return -1;

        }

      if(LastSwingMeter >= 0)
        {

         // Store highvalue in Highs[]

         // Shift existing elements in Highs[] to make space for the new value
         ArrayResize(Highs, MathMin(ArraySize(Highs) + 1, 10));
         for(int i = ArraySize(Highs) - 1; i > 0; --i)
           {
            Highs[i] = Highs[i - 1];
           }

         // Store highvalue in Highs[0], the first position
         Highs[0] = highvalue;

         // Store hightime in HighsTime[]

         // Shift existing elements in HighsTime[] to make space for the new value
         ArrayResize(HighsTime, MathMin(ArraySize(HighsTime) + 1, 10));
         for(int i = ArraySize(HighsTime) - 1; i > 0; --i)
           {
            HighsTime[i] = HighsTime[i - 1];
           }

         // Store hightime in HighsTime[0], the first position
         HighsTime[0] = hightime;

         prevTimeH = lastTimeH;
         lastTimeH = hightime;

         //createObj(rates[2].time,rates[2].high, 234, -1, clrGreen, "");
         LastSwingMeter = -1;
         return -1;
        }

     }



//SwingLow

   if
   (
      rates[2].low < rates[3].low &&
      rates[2].low < rates[1].low
   )
     {
      double lowvalue = rates[2].low;
      datetime lowtime = rates[2].time;


      if(
         LastSwingMeter > 0 &&
         lowvalue > Lows[0]
      )
        {
         return 0;
        }

      if(
         LastSwingMeter > 0 &&
         lowvalue < Lows[0]
      )
        {
         deleteObj(LowsTime[0], Lows[0], 233, "");
         ArrayRemove(Lows, 0, 1);
         ArrayRemove(LowsTime, 0, 1);

         // Store lowvalue in Lows[]

         // Shift existing elements in Lows[] to make space for the new value
         ArrayResize(Lows, MathMin(ArraySize(Lows) + 1, 10));
         for(int i = ArraySize(Lows) - 1; i > 0; --i)
           {
            Lows[i] = Lows[i - 1];
           }

         // Store lowvalue in Lows[0], the first position
         Lows[0] = lowvalue;


         // Store lowtime in LowsTime[]

         // Shift existing elements in LowsTime[] to make space for the new value
         ArrayResize(LowsTime, MathMin(ArraySize(LowsTime) + 1, 10));
         for(int i = ArraySize(LowsTime) - 1; i > 0; --i)
           {
            LowsTime[i] = LowsTime[i - 1];
           }

         // Store lowtime in LowsTime[0], the first position
         LowsTime[0] = lowtime;

         prevTimeL = lastTimeL;
         lastTimeL = lowtime;

         //createObj(rates[2].time,rates[2].low, 233, 1, clrDarkOrange, "");
         LastSwingMeter = 1;
         return 1;

        }


      if(LastSwingMeter <= 0)
        {
         // Store lowvalue in Lows[]

         // Shift existing elements in Lows[] to make space for the new value
         ArrayResize(Lows, MathMin(ArraySize(Lows) + 1, 10));
         for(int i = ArraySize(Lows) - 1; i > 0; --i)
           {
            Lows[i] = Lows[i - 1];
           }

         // Store lowvalue in Lows[0], the first position
         Lows[0] = lowvalue;


         // Store lowtime in LowsTime[]

         // Shift existing elements in LowsTime[] to make space for the new value
         ArrayResize(LowsTime, MathMin(ArraySize(LowsTime) + 1, 10));
         for(int i = ArraySize(LowsTime) - 1; i > 0; --i)
           {
            LowsTime[i] = LowsTime[i - 1];
           }

         // Store lowtime in LowsTime[0], the first position
         LowsTime[0] = lowtime;

         prevTimeL = lastTimeL;
         lastTimeL = lowtime;

         //createObj(rates[2].time,rates[2].low, 233, 1, clrDarkOrange, "");
         LastSwingMeter = 1;
         return 1;
        }

     }




   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int FVG()
  {


   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int copied = CopyRates(_Symbol,PERIOD_CURRENT,0,50,rates);



//Bullish FVG

   if
   (

      rates[1].low > rates[3].high &&
      rates[2].close > rates[3].high &&
      rates[1].close > rates[1].open &&
      rates[3].close > rates[3].open

   )
     {

      double fvghigh = rates[3].high;
      double fvglow = rates[1].low;
      datetime fvgtime = rates[0].time;


      // Store fvghigh in BuFVGHighs[]

      // Shift existing elements in BuFVGHighs[] to make space for the new value
      ArrayResize(BuFVGHighs, MathMin(ArraySize(BuFVGHighs) + 1, 10));
      for(int i = ArraySize(BuFVGHighs) - 1; i > 0; --i)
        {
         BuFVGHighs[i] = BuFVGHighs[i - 1];
        }

      // Store fvghigh in BuFVGHighs[0], the first position
      BuFVGHighs[0] = fvghigh;

      // Store fvglow in BuFVGLows[]

      // Shift existing elements in BuFVGLows[] to make space for the new value
      ArrayResize(BuFVGLows, MathMin(ArraySize(BuFVGLows) + 1, 10));
      for(int i = ArraySize(BuFVGLows) - 1; i > 0; --i)
        {
         BuFVGLows[i] = BuFVGLows[i - 1];
        }

      // Store fvglow in BuFVGLows[0], the first position
      BuFVGLows[0] = fvglow;

      // Store fvgtime in BuFVGTime[]

      // Shift existing elements in BuFVGTime[] to make space for the new value
      ArrayResize(BuFVGTime, MathMin(ArraySize(BuFVGTime) + 1, 10));
      for(int i = ArraySize(BuFVGTime) - 1; i > 0; --i)
        {
         BuFVGTime[i] = BuFVGTime[i - 1];
        }

      // Store fvgtime in BuFVGTime[0], the first position
      BuFVGTime[0] = fvgtime;

      string objName = " Bu.FVG "+TimeToString(rates[3].time);
      if(ObjectFind(0, objName) < 0)
         ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rates[3].time, rates[3].high, rates[0].time, rates[1].low);
      //--- set line color
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGreen);
      //--- set line display style
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
      //--- set line width
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);

      return 1;

     }



//Bearish FVG


   if
   (

      rates[1].high < rates[3].low &&
      rates[2].close < rates[3].low &&
      rates[1].close < rates[1].open &&
      rates[3].close < rates[3].open

   )
     {
      double fvghigh = rates[3].low;
      double fvglow = rates[1].high;
      datetime fvgtime = rates[0].time;


      // Store fvglow in BeFVGLows[]

      // Shift existing elements in BeFVGLows[] to make space for the new value
      ArrayResize(BeFVGLows, MathMin(ArraySize(BeFVGLows) + 1, 10));
      for(int i = ArraySize(BeFVGLows) - 1; i > 0; --i)
        {
         BeFVGLows[i] = BeFVGLows[i - 1];
        }

      // Store fvglow in BeFVGLows[0], the first position
      BeFVGLows[0] = fvglow;

      // Store fvghigh in BeFVGHighs[]

      // Shift existing elements in BeFVGHighs[] to make space for the new value
      ArrayResize(BeFVGHighs, MathMin(ArraySize(BeFVGHighs) + 1, 10));
      for(int i = ArraySize(BeFVGHighs) - 1; i > 0; --i)
        {
         BeFVGHighs[i] = BeFVGHighs[i - 1];
        }

      // Store fvghigh in BeFVGHighs[0], the first position
      BeFVGHighs[0] = fvghigh;


      // Store fvgtime in BeFVGTime[]

      // Shift existing elements in BeFVGTime[] to make space for the new value
      ArrayResize(BeFVGTime, MathMin(ArraySize(BeFVGTime) + 1, 10));
      for(int i = ArraySize(BeFVGTime) - 1; i > 0; --i)
        {
         BeFVGTime[i] = BeFVGTime[i - 1];
        }

      // Store fvgtime in BeFVGTime[0], the first position
      BeFVGTime[0] = fvgtime;

      string objName = " Be.FVG "+TimeToString(rates[3].time);
      if(ObjectFind(0, objName) < 0)
         ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rates[3].time, rates[3].low, rates[0].time, rates[1].high);
      //--- set line color
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
      //--- set line display style
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
      //--- set line width
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);

      return 1;

     }

   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int orderBlock()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, 50, rates);


// Bullish Order Block
   if(
      rates[3].low < rates[4].low &&
      rates[3].low < rates[2].low &&
      rates[1].low > rates[3].high

   )
     {
      double bullishOrderBlockHighValue = rates[3].open;
      double bullishOrderBlockLowValue = rates[3].low;
      datetime bullishOrderBlockTimeValue = rates[3].time;

      // Store bullishOrderBlockHighValue in bullishOrderBlockHigh[]

      // Shift existing elements in bullishOrderBlockHigh[] to make space for the new value
      ArrayResize(bullishOrderBlockHigh, ArraySize(bullishOrderBlockHigh) + 1);
      for(int i = ArraySize(bullishOrderBlockHigh) - 1; i > 0; --i)
        {
         bullishOrderBlockHigh[i] = bullishOrderBlockHigh[i - 1];
        }

      // Store bullishOrderBlockHighValue in bullishOrderBlockHigh[0], the first position
      bullishOrderBlockHigh[0] = bullishOrderBlockHighValue;

      // Store bullishOrderBlockLowValue in bullishOrderBlockLow[]

      // Shift existing elements in bullishOrderBlockLow[] to make space for the new value
      ArrayResize(bullishOrderBlockLow, ArraySize(bullishOrderBlockLow) + 1);
      for(int i = ArraySize(bullishOrderBlockLow) - 1; i > 0; --i)
        {
         bullishOrderBlockLow[i] = bullishOrderBlockLow[i - 1];
        }

      // Store bullishOrderBlockLowValue in bullishOrderBlockLow[0], the first position
      bullishOrderBlockLow[0] = bullishOrderBlockLowValue;

      // Store bullishOrderBlockTimeValue in bullishOrderBlockTime[]

      // Shift existing elements in bullishOrderBlockTime[] to make space for the new value
      ArrayResize(bullishOrderBlockTime, ArraySize(bullishOrderBlockTime) + 1);
      for(int i = ArraySize(bullishOrderBlockTime) - 1; i > 0; --i)
        {
         bullishOrderBlockTime[i] = bullishOrderBlockTime[i - 1];
        }

      // Store bullishOrderBlockTimeValue in bullishOrderBlockTime[0], the first position
      bullishOrderBlockTime[0] = bullishOrderBlockTimeValue;


      string objName = " Bu.OB "+TimeToString(rates[3].time);
      if(ObjectFind(0, objName) < 0)
         ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rates[3].time, rates[3].low, rates[0].time, rates[3].open);
      //--- set line color
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrTeal);
      //--- set line display style
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
      //--- set line width
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);


      return 1;
     }


// Bearish Order Block
   if(
      rates[3].high > rates[4].low &&
      rates[3].low > rates[2].low &&
      rates[1].high < rates[3].low

   )
     {
      double bearishOrderBlockLowValue = rates[3].close;
      double bearishOrderBlockHighValue = rates[3].high;
      datetime bearishOrderBlockTimeValue = rates[3].time;

      // Store bearishOrderBlockLowValue in bearishOrderBlockLow[]

      // Shift existing elements in bearishOrderBlockLow[] to make space for the new value
      ArrayResize(bearishOrderBlockLow, ArraySize(bearishOrderBlockLow) + 1);
      for(int i = ArraySize(bearishOrderBlockLow) - 1; i > 0; --i)
        {
         bearishOrderBlockLow[i] = bearishOrderBlockLow[i - 1];
        }

      // Store bearishOrderBlockLowValue in bearishOrderBlockLow[0], the first position
      bearishOrderBlockLow[0] = bearishOrderBlockLowValue;

      // Store bearishOrderBlockHighValue in bearishOrderBlockHigh[]

      // Shift existing elements in bearishOrderBlockHigh[] to make space for the new value
      ArrayResize(bearishOrderBlockHigh, ArraySize(bearishOrderBlockHigh) + 1);
      for(int i = ArraySize(bearishOrderBlockHigh) - 1; i > 0; --i)
        {
         bearishOrderBlockHigh[i] = bearishOrderBlockHigh[i - 1];
        }

      // Store bearishOrderBlockHighValue in bearishOrderBlockHigh[0], the first position
      bearishOrderBlockHigh[0] = bearishOrderBlockHighValue;

      // Store bearishOrderBlockTimeValue in bearishOrderBlockTime[]

      // Shift existing elements in bearishOrderBlockTime[] to make space for the new value
      ArrayResize(bearishOrderBlockTime, ArraySize(bearishOrderBlockTime) + 1);
      for(int i = ArraySize(bearishOrderBlockTime) - 1; i > 0; --i)
        {
         bearishOrderBlockTime[i] = bearishOrderBlockTime[i - 1];
        }

      // Store bearishOrderBlockTimeValue in bearishOrderBlockTime[0], the first position
      bearishOrderBlockTime[0] = bearishOrderBlockTimeValue;



      string objName = " Be.OB "+TimeToString(rates[3].time);
      if(ObjectFind(0, objName) < 0)
         ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rates[3].time, rates[3].high, rates[0].time, rates[3].close);
      //--- set line color
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDarkRed);
      //--- set line display style
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
      //--- set line width
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);


      return -1;
     }



//Invalidation Logic

//Bullish

   for(int i = ArraySize(bullishOrderBlockLow) - 1; i >= 0; i--)
     {
      if(
         ArraySize(bullishOrderBlockLow) > i &&
         rates[1].low < bullishOrderBlockLow[i] &&
         rates[1].high > bullishOrderBlockLow[i]
      )
        {

         string objName1 = " Bu.OB " + TimeToString(bullishOrderBlockTime[i]);

         // Check if the rectangle object exists
         if(ObjectFind(0, objName1) >= 0)
           {
            // Attempt to delete the rectangle
            if(ObjectDelete(0, objName1))
              {

               ArrayRemove(bullishOrderBlockLow, i, 1);
               ArrayRemove(bullishOrderBlockHigh, i, 1);
               ArrayRemove(bullishOrderBlockTime, i, 1);
              }
           }
        }
     }
//Bearish

   for(int i = ArraySize(bearishOrderBlockHigh) - 1; i >= 0; i--)
     {
      if(
         ArraySize(bearishOrderBlockHigh) > i &&
         rates[1].low < bearishOrderBlockHigh[i] &&
         rates[1].high > bearishOrderBlockHigh[i]
      )
        {


         string objName2 = " Be.OB " + TimeToString(bearishOrderBlockTime[i]);

         // Check if the rectangle object exists
         if(ObjectFind(0, objName2) >= 0)
           {
            // Attempt to delete the rectangle
            if(ObjectDelete(0, objName2))
              {
               ArrayRemove(bearishOrderBlockLow, i, 1);
               ArrayRemove(bearishOrderBlockHigh, i, 1);
               ArrayRemove(bearishOrderBlockTime, i, 1);
              }
           }
        }
     }
   return 0;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
