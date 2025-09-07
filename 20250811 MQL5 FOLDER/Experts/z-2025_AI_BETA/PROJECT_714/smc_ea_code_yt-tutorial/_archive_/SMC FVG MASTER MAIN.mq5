//+------------------------------------------------------------------+
//|                                         Master SMC EA.mq5        | // Renamed conceptually
//|                                          Copyright 2024, Usiola. |
//|                                   https://www.trenddaytrader.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Usiola."
#property link      "https://www.trenddaytrader.com"
#property version   "2.00" // Version up

#include <Trade/Trade.mqh>
CTrade Trade;

int barsTotal;
int totalT; // For existing trade count check

// --- Input Parameters ---
input ENUM_TIMEFRAMES InpAnalysisTimeframe = PERIOD_CURRENT; // <<< NEW: Timeframe for SMC analysis
input ENUM_TIMEFRAMES InpSmaTimeframe = PERIOD_H1;      // <<< NEW: Timeframe for SMA Filter
input int             InpSmaPeriod = 89;
input double          InpRiskToReward = 2.0;
input double          InpLots = 0.01;
input double          InpBreakevenTriggerPoints = 10000; // Changed to points
input double          InpBreakevenPoints = 2000;         // Changed to points

// Rejection Block Colors & Width (from File 3)
input color Inp_Bullish_Green_rBlock_Color = clrGreen;
input color Inp_Bullish_Red_rBlock_Color = clrTeal;
input color Inp_Bearish_Green_rBlock_Color = clrFireBrick;
input color Inp_Bearish_Red_rBlock_Color = clrRed;
input int   Inp_rBlock_Width = 1;


// --- Global Arrays & Handles ---
//Swing
double Highs[];
double Lows[];
datetime HighsTime[];
datetime LowsTime[];
int LastSwingMeter = 0;
datetime lastTimeH = 0; // For BoS/CHoCH
datetime prevTimeH = 0; // For BoS/CHoCH
datetime lastTimeL = 0; // For BoS/CHoCH
datetime prevTimeL = 0; // For BoS/CHoCH

//FVG
double BuFVGHighs[];
double BuFVGLows[];
datetime BuFVGTime[];
double BeFVGHighs[];
double BeFVGLows[];
datetime BeFVGTime[];

//Order Block
double bullishOrderBlockHigh[];
double bullishOrderBlockLow[];
datetime bullishOrderBlockTime[];
double bearishOrderBlockHigh[];
double bearishOrderBlockLow[];
datetime bearishOrderBlockTime[];

// Rejection Block (from File 3)
double bullishGreenHighValues[];
double bullishGreenLowValues[];
datetime bullishGreenTimeValues[];
double bullishRedHighValues[];
double bullishRedLowValues[];
datetime bullishRedTimeValues[];
double bearishRedLowValues[];
double bearishRedHighValues[];
datetime bearishRedTimeValues[];
double bearishGreenLowValues[];
double bearishGreenHighValues[];
datetime bearishGreenTimeValues[];

// Handles
int OnInit_handlesma_RetCode; // To store return code of iMA

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

   // Rejection Block Arrays
   ArraySetAsSeries(bullishGreenHighValues,true);
   ArraySetAsSeries(bullishGreenLowValues,true);
   ArraySetAsSeries(bullishGreenTimeValues,true);
   ArraySetAsSeries(bullishRedHighValues,true);
   ArraySetAsSeries(bullishRedLowValues,true);
   ArraySetAsSeries(bullishRedTimeValues,true);
   ArraySetAsSeries(bearishRedLowValues,true);
   ArraySetAsSeries(bearishRedHighValues,true);
   ArraySetAsSeries(bearishRedTimeValues,true);
   ArraySetAsSeries(bearishGreenLowValues,true);
   ArraySetAsSeries(bearishGreenHighValues,true);
   ArraySetAsSeries(bearishGreenTimeValues,true);

   // SMA Handle - Use input timeframe and period
   OnInit_handlesma_RetCode = iMA(_Symbol, InpSmaTimeframe, InpSmaPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(OnInit_handlesma_RetCode == INVALID_HANDLE)
     {
      Print("Error creating SMA indicator handle - Error code: ", GetLastError());
      return(INIT_FAILED);
     }

   // Check if InpAnalysisTimeframe is valid (e.g., not less than current chart period for some logic)
   if(InpAnalysisTimeframe < Period())
     {
      Print("Warning: Analysis Timeframe (", EnumToString(InpAnalysisTimeframe),
            ") is less than chart timeframe (", EnumToString(Period()),
            "). Some visual elements might not display as expected if drawn far into future bars of a smaller TF.");
     }


   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(OnInit_handlesma_RetCode); // Release indicator handle
   // Potentially delete all created objects if desired
   ObjectsDeleteAll(0,0,-1); // Deletes all objects on main chart. Adjust if subwindows used.
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Using PERIOD_CURRENT here for the new bar check, which is standard for EAs.
   // The analysis functions will use InpAnalysisTimeframe.
   int bars = iBars(_Symbol, PERIOD_CURRENT);

   if(barsTotal != bars)
     {
      barsTotal = bars;

      //SMA INDICATOR BUFFER - Fetched from InpSmaTimeframe
      double sma[];
      ArraySetAsSeries(sma, true);
      if(CopyBuffer(OnInit_handlesma_RetCode,MAIN_LINE,0,9,sma) <= 0)
        {
         Print("Error copying SMA buffer - Error code: ", GetLastError());
         // Decide how to handle - skip this tick's logic?
        }

      // MQLRates for general use, e.g., current price for entries
      // Specific analysis functions will fetch their own rates for InpAnalysisTimeframe
      MqlRates currentTfRates[];
      ArraySetAsSeries(currentTfRates,true);
      CopyRates(_Symbol,PERIOD_CURRENT,0,2,currentTfRates); // For current entry conditions


      // --- Call analysis functions, now ensuring they use InpAnalysisTimeframe ---
      swingPoints(); // Will be modified to use InpAnalysisTimeframe
      FVG();         // Will be modified to use InpAnalysisTimeframe
      orderBlock();  // Will be modified to use InpAnalysisTimeframe
      rBlock();      // Will be ADDED and modified to use InpAnalysisTimeframe


      // --- TRADING LOGIC ---
      // This logic will need significant review and adaptation.
      // For now, I'm keeping the old logic commented out or placeholders.
      // The conditions should now reference patterns detected on InpAnalysisTimeframe.

      totalT = PositionsTotal();

      // BUY TRADE EXAMPLE - Needs complete rework for new TF flexibility
      /*
      if
      (
         totalT < 1 &&
         ArraySize(bullishGreenHighValues) > 0 && // Assuming this is from rBlock
         currentTfRates[1].low <  bullishGreenHighValues[0] &&
         currentTfRates[1].close >  bullishGreenHighValues[0] &&
         // Additional filter: sma condition on InpSmaTimeframe data
         (ArraySize(sma) > 1 && currentTfRates[1].close > sma[1]) // Example
      )
        {
         double entryprice = currentTfRates[1].close;
         entryprice = NormalizeDouble(entryprice,_Digits);

         double ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         double bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
         double spread=ask-bid;

         double stoploss = bullishGreenLowValues[0] - spread*4; // SL from rBlock
         stoploss = NormalizeDouble(stoploss,_Digits);

         double riskvalue = entryprice - stoploss;
         riskvalue = NormalizeDouble(riskvalue,_Digits);

         double takeprofit = entryprice + (InpRiskToReward * riskvalue);
         takeprofit = NormalizeDouble(takeprofit,_Digits);

         Trade.PositionOpen(_Symbol,ORDER_TYPE_BUY, InpLots,entryprice, stoploss, takeprofit, "SMC Buy");
        }
      */


      // SELL TRADE EXAMPLE - Needs complete rework
      /*
      if
      (
         totalT < 1 &&
         ArraySize(bearishGreenLowValues) > 0 && // Assuming from rBlock
         currentTfRates[1].high > bearishGreenLowValues[0] &&
         currentTfRates[1].close <  bearishGreenLowValues[0] &&
         // Additional filter: sma condition on InpSmaTimeframe data
         (ArraySize(sma) > 1 && currentTfRates[1].close < sma[1]) // Example
      )
        {
         // ... similar logic for sell trade ...
        }
      */


      //BREAKEVEN TRIGGER (uses _Point from current symbol, which is fine)
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

            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
              {
               double breakevenTriggerB = (posEntryPrice + InpBreakevenTriggerPoints*_Point);
               breakevenTriggerB = NormalizeDouble(breakevenTriggerB, _Digits);
               double newSlB = (posEntryPrice + InpBreakevenPoints*_Point);
               newSlB = NormalizeDouble(newSlB, _Digits);

               if( tradeSymbol == _Symbol && posCurrentPrice > breakevenTriggerB && posSL < posEntryPrice)
                 {
                  if(Trade.PositionModify(positionTicketa, newSlB, posTP))
                     Print(__FUNCTION__,"Pos #",positionTicketa, " MODIFIED TO BREAKEVEN FOR BUY");
                 }
              }

            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
              {
               double breakevenTriggerS = (posEntryPrice - InpBreakevenTriggerPoints*_Point);
               breakevenTriggerS = NormalizeDouble(breakevenTriggerS, _Digits);
               double newSlS = (posEntryPrice - InpBreakevenPoints*_Point);
               newSlS = NormalizeDouble(newSlS, _Digits);

               if( tradeSymbol == _Symbol && posCurrentPrice < breakevenTriggerS && posSL > posEntryPrice)
                 {
                  if(Trade.PositionModify(positionTicketa, newSlS, posTP))
                     Print(__FUNCTION__,"Pos #",positionTicketa, " MODIFIED TO BREAKEVEN FOR SELL");
                 }
              }
           }
        }
     }
  }

// --- createObj, deleteObj ---
// (These were fine and can be kept from File 4)
//+------------------------------------------------------------------+
void createObj(datetime time, double price, int arrowCode, int direction, color clr, string txt)
  {
   string objName ="";
   StringConcatenate(objName, "Signal@", time, "at", DoubleToString(price, _Digits), "(", arrowCode, ")");

   double ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double spread=ask-bid;

   double priceOffset = 2 * spread * _Point; // Define a reasonable offset

   if(direction > 0) price += priceOffset;
   else if(direction < 0) price -= priceOffset;
   
   // Adjust price further if InpAnalysisTimeframe is different from chart timeframe
   // to avoid object being drawn off-screen on current chart if analysis TF is much larger.
   // This is a complex problem to solve perfectly for all TF combinations.
   // For now, the basic offset should help for reasonably close TFs.

   if(ObjectCreate(0, objName, OBJ_ARROW, 0, time, price))
     {
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2); // Example width
      if(direction > 0) ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_TOP);
      if(direction < 0) ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
     }
   string objNameDesc = objName + txt; // Use a slightly different name for the text
   if(ObjectCreate(0, objNameDesc, OBJ_TEXT, 0, time, price))
     {
      ObjectSetString(0, objNameDesc, OBJPROP_TEXT, "  " + txt); // Add some space for readability
      ObjectSetInteger(0, objNameDesc, OBJPROP_COLOR, clr);
      ObjectSetInteger(0,objNameDesc,OBJPROP_FONTSIZE,8); // Smaller font for description
      if(direction > 0) ObjectSetInteger(0, objNameDesc, OBJPROP_ANCHOR, ANCHOR_LEFT); // Anchor text beside arrow
      if(direction < 0) ObjectSetInteger(0, objNameDesc, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetDouble(0,objNameDesc,OBJPROP_ANGLE,0); // Ensure text is horizontal
     }
  }
//+------------------------------------------------------------------+
void deleteObj(datetime time, double price, int arrowCode, string txt)
  {
   string objName = "";
   StringConcatenate(objName, "Signal@", time, "at", DoubleToString(price, _Digits), "(", arrowCode, ")");
   if(ObjectFind(0, objName) != -1) ObjectDelete(0, objName);

   string objNameDesc = objName + txt;
   if(ObjectFind(0, objNameDesc) != -1) ObjectDelete(0, objNameDesc);
  }


// --- SMC Detection Functions (to be modified/added) ---

//+------------------------------------------------------------------+
//| Swing Points, BoS, CHoCH (to be adapted for InpAnalysisTimeframe)|
//+------------------------------------------------------------------+
int swingPoints()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   // MODIFIED: Use InpAnalysisTimeframe
   int copied = CopyRates(_Symbol,InpAnalysisTimeframe,0,50,rates);
    if(copied < 5) { Print("swingPoints: Not enough rates for ",EnumToString(InpAnalysisTimeframe)); return 0; }


   // --- BoS/CHoCH Logic ---
   // This part needs careful adaptation if lastTimeH/L are from InpAnalysisTimeframe
   // and the break is detected on InpAnalysisTimeframe candles.
   // iBarShift will also need to use InpAnalysisTimeframe.
   
   // Convert datetime from InpAnalysisTimeframe to bar index on InpAnalysisTimeframe
   int indexLastH = iBarShift(_Symbol,InpAnalysisTimeframe,lastTimeH, true); // exact = true
   int indexLastL = iBarShift(_Symbol,InpAnalysisTimeframe,lastTimeL, true);
   int indexPrevH = iBarShift(_Symbol,InpAnalysisTimeframe,prevTimeH, true);
   int indexPrevL = iBarShift(_Symbol,InpAnalysisTimeframe,prevTimeL, true);

//Break Of Structure
//Bullish
   if(indexLastH >=0 && indexLastL >=0 && indexPrevH >=0 && indexPrevL >=0 && copied > MathMax(indexLastH, MathMax(indexLastL, MathMax(indexPrevH, indexPrevL)) ) ) //Ensure indices are valid and within copied range
     {
        // Make sure rates[] has enough elements for these indices if they are large
        if (rates[indexLastL].low > rates[indexPrevL].low && // Higher Low structure for bullish BoS
            rates[1].close > rates[indexLastH].high &&   // Current bar (index 1) close above previous high
            rates[2].close < rates[indexLastH].high)    // Previous bar (index 2) close was below
        {
            string objname = "SMC BoS " + TimeToString(rates[indexLastH].time) + " " + EnumToString(InpAnalysisTimeframe);
            if(ObjectFind(0,objname) < 0)
            {
                // Draw trend line from the broken high horizontally to the current bar time on InpAnalysisTimeframe
                ObjectCreate(0,objname,OBJ_TREND,0,rates[indexLastH].time,rates[indexLastH].high, rates[0].time ,rates[indexLastH].high);
                ObjectSetInteger(0,objname,OBJPROP_COLOR, clrBlue);
                ObjectSetInteger(0,objname,OBJPROP_WIDTH, 2); // Thinner for less clutter
                ObjectSetInteger(0,objname,OBJPROP_RAY_RIGHT, false); // Don't extend to right indefinitely

                createObj(rates[indexLastH].time, rates[indexLastH].high, WingdingsSymbol("W"), 1, clrBlue, "BoS"); // Wingdings W for upward pointing
            }
        }
    //BEARISH BoS
        if (rates[indexLastH].high < rates[indexPrevH].high && // Lower High structure for bearish BoS
            rates[1].close < rates[indexLastL].low &&    // Current bar close below previous low
            rates[2].close > rates[indexLastL].low)     // Previous bar close was above
        {
            string objname = "SMC BoS " + TimeToString(rates[indexLastL].time) + " " + EnumToString(InpAnalysisTimeframe);
            if(ObjectFind(0,objname) < 0)
            {
                ObjectCreate(0,objname,OBJ_TREND,0,rates[indexLastL].time,rates[indexLastL].low, rates[0].time, rates[indexLastL].low);
                ObjectSetInteger(0,objname,OBJPROP_COLOR, clrRed);
                ObjectSetInteger(0,objname,OBJPROP_WIDTH, 2);
                ObjectSetInteger(0,objname,OBJPROP_RAY_RIGHT, false);
                
                createObj(rates[indexLastL].time, rates[indexLastL].low, WingdingsSymbol("X"), -1, clrRed, "BoS"); // Wingdings X for downward
            }
        }
     }

//Change of Character
//Bullish CHoCH
    if(indexLastH >=0 && indexLastL >=0 && indexPrevH >=0 && indexPrevL >=0 && copied > MathMax(indexLastH, MathMax(indexLastL, MathMax(indexPrevH, indexPrevL)) ) )
     {
        if (rates[indexLastH].high < rates[indexPrevH].high && rates[indexLastL].low < rates[indexPrevL].low && // Downtrend structure broken (LH, LL)
            rates[1].close > rates[indexLastH].high && // Break of the last Lower High
            rates[2].close < rates[indexLastH].high)
        {
            string objname = "SMC CHoCH " + TimeToString(rates[indexLastH].time) + " " + EnumToString(InpAnalysisTimeframe);
            if(ObjectFind(0,objname) < 0)
            {
                ObjectCreate(0,objname,OBJ_TREND,0,rates[indexLastH].time,rates[indexLastH].high,rates[0].time,rates[indexLastH].high);
                ObjectSetInteger(0,objname,OBJPROP_COLOR, clrGreen);
                ObjectSetInteger(0,objname,OBJPROP_WIDTH, 2);
                ObjectSetInteger(0,objname,OBJPROP_RAY_RIGHT, false);

                createObj(rates[indexLastH].time, rates[indexLastH].high, WingdingsSymbol("W"), 1, clrGreen, "CHoCH");
            }
        }
    //BEARISH CHoCH
        if (rates[indexLastH].high > rates[indexPrevH].high && rates[indexLastL].low > rates[indexPrevL].low && // Uptrend structure broken (HL, HH)
            rates[1].close < rates[indexLastL].low && // Break of the last Higher Low
            rates[2].close > rates[indexLastL].low)
        {
            string objname = "SMC CHoCH " + TimeToString(rates[indexLastL].time) + " " + EnumToString(InpAnalysisTimeframe);
            if(ObjectFind(0,objname) < 0)
            {
                ObjectCreate(0,objname,OBJ_TREND,0,rates[indexLastL].time,rates[indexLastL].low,rates[0].time,rates[indexLastL].low);
                ObjectSetInteger(0,objname,OBJPROP_COLOR, clrDarkOrange);
                ObjectSetInteger(0,objname,OBJPROP_WIDTH, 2);
                ObjectSetInteger(0,objname,OBJPROP_RAY_RIGHT, false);
                
                createObj(rates[indexLastL].time, rates[indexLastL].low, WingdingsSymbol("X"), -1, clrDarkOrange, "CHoCH");
            }
        }
     }

//Swing Detection (on InpAnalysisTimeframe)
//SwingHigh
   if (copied >= 4 && // Need at least 4 bars (0,1,2,3) for rates[2], rates[3] etc. for 3-bar pattern. rates[4] not needed here.
      rates[2].high > rates[3].high &&
      rates[2].high > rates[1].high
   )
     {
      double highvalue =  rates[2].high;
      datetime hightime = rates[2].time;

      if(LastSwingMeter < 0 && ArraySize(Highs) > 0 && highvalue < Highs[0]) { /* Do nothing, lower high continuation */ }
      else if(LastSwingMeter < 0 && ArraySize(Highs) > 0 && highvalue > Highs[0]) // Higher High, new swing, remove old
        {
         if(ArraySize(HighsTime)>0 && ArraySize(Highs)>0) deleteObj(HighsTime[0], Highs[0], 234, ""); // Assuming 234 was used for high
         if(ArraySize(Highs)>0) ArrayRemove(Highs, 0, 1);
         if(ArraySize(HighsTime)>0) ArrayRemove(HighsTime, 0, 1);
        
         ArrayResize(Highs, ArraySize(Highs) + 1);
         ArrayCopy(Highs, Highs, 1, 0);
         Highs[0] = highvalue;
         if(ArraySize(Highs) > 10) ArrayResize(Highs, 10);
         
         ArrayResize(HighsTime, ArraySize(HighsTime) + 1);
         ArrayCopy(HighsTime, HighsTime, 1, 0);
         HighsTime[0] = hightime;
         if(ArraySize(HighsTime) > 10) ArrayResize(HighsTime, 10);

         prevTimeH = lastTimeH; lastTimeH = hightime;
         // createObj(hightime, highvalue, 234, -1, clrGreen, "SH"); // Swing High marker
         LastSwingMeter = -1;
         return -1;
        }
      else if(LastSwingMeter >= 0) // First high or high after a low
        {
         ArrayResize(Highs, ArraySize(Highs) + 1);
         ArrayCopy(Highs, Highs, 1, 0);
         Highs[0] = highvalue;
         if(ArraySize(Highs) > 10) ArrayResize(Highs, 10);
         
         ArrayResize(HighsTime, ArraySize(HighsTime) + 1);
         ArrayCopy(HighsTime, HighsTime, 1, 0);
         HighsTime[0] = hightime;
         if(ArraySize(HighsTime) > 10) ArrayResize(HighsTime, 10);

         prevTimeH = lastTimeH; lastTimeH = hightime;
         // createObj(hightime, highvalue, 234, -1, clrGreen, "SH");
         LastSwingMeter = -1;
         return -1;
        }
     }

//SwingLow
    if (copied >= 4 &&
      rates[2].low < rates[3].low &&
      rates[2].low < rates[1].low
   )
     {
      double lowvalue = rates[2].low;
      datetime lowtime = rates[2].time;

      if(LastSwingMeter > 0 && ArraySize(Lows) > 0 && lowvalue > Lows[0]) { /* Do nothing, higher low continuation */ }
      else if(LastSwingMeter > 0 && ArraySize(Lows) > 0 && lowvalue < Lows[0]) // Lower Low, new swing, remove old
        {
         if(ArraySize(LowsTime)>0 && ArraySize(Lows)>0) deleteObj(LowsTime[0], Lows[0], 233, ""); // Assuming 233 for low
         if(ArraySize(Lows)>0) ArrayRemove(Lows, 0, 1);
         if(ArraySize(LowsTime)>0) ArrayRemove(LowsTime, 0, 1);
        
         ArrayResize(Lows, ArraySize(Lows) + 1);
         ArrayCopy(Lows, Lows, 1, 0);
         Lows[0] = lowvalue;
         if(ArraySize(Lows) > 10) ArrayResize(Lows, 10);
         
         ArrayResize(LowsTime, ArraySize(LowsTime) + 1);
         ArrayCopy(LowsTime, LowsTime, 1, 0);
         LowsTime[0] = lowtime;
         if(ArraySize(LowsTime) > 10) ArrayResize(LowsTime, 10);

         prevTimeL = lastTimeL; lastTimeL = lowtime;
         // createObj(lowtime, lowvalue, 233, 1, clrDarkOrange, "SL"); // Swing Low marker
         LastSwingMeter = 1;
         return 1;
        }
      else if(LastSwingMeter <= 0) // First low or low after a high
        {
         ArrayResize(Lows, ArraySize(Lows) + 1);
         ArrayCopy(Lows, Lows, 1, 0);
         Lows[0] = lowvalue;
         if(ArraySize(Lows) > 10) ArrayResize(Lows, 10);
         
         ArrayResize(LowsTime, ArraySize(LowsTime) + 1);
         ArrayCopy(LowsTime, LowsTime, 1, 0);
         LowsTime[0] = lowtime;
         if(ArraySize(LowsTime) > 10) ArrayResize(LowsTime, 10);

         prevTimeL = lastTimeL; lastTimeL = lowtime;
         // createObj(lowtime, lowvalue, 233, 1, clrDarkOrange, "SL");
         LastSwingMeter = 1;
         return 1;
        }
     }
   return 0;
  }

//+------------------------------------------------------------------+
//| FVG (to be adapted for InpAnalysisTimeframe)                     |
//+------------------------------------------------------------------+
int FVG()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   // MODIFIED: Use InpAnalysisTimeframe
   int copied = CopyRates(_Symbol,InpAnalysisTimeframe,0,50,rates);
   if(copied < 4) { Print("FVG: Not enough rates for ",EnumToString(InpAnalysisTimeframe)); return 0; } // Need at least 4 bars for FVG: 0,1,2,3

//Bullish FVG (on InpAnalysisTimeframe)
   if( rates[1].low > rates[3].high &&
       rates[2].close > rates[3].high && // Candle 2 pushes through
       rates[1].close > rates[1].open && // Candle 1 is bullish
       rates[3].close > rates[3].open    // Candle 3 is bullish (often FVG forms between two strong candles)
     )
     {
      double fvghigh_price = rates[3].high; // Top of gap
      double fvglow_price = rates[1].low;   // Bottom of gap (using lows for bullish for clarity with rectangle)
      datetime fvgtime_start = rates[3].time;
      datetime fvgtime_end = rates[0].time; // Extends to current bar on InpAnalysisTimeframe
      datetime fvg_unique_time_id = rates[2].time; // Use middle candle time for uniqueness of this FVG instance

      // Store FVG (Consider a check to prevent duplicate FVG for the same rates[2].time)
      if(ArraySize(BuFVGTime) == 0 || (ArraySize(BuFVGTime) > 0 && BuFVGTime[0] != fvg_unique_time_id))
        {
         ArrayResize(BuFVGHighs, ArraySize(BuFVGHighs) + 1);
         ArrayCopy(BuFVGHighs, BuFVGHighs, 1, 0);
         BuFVGHighs[0] = fvghigh_price;
         if(ArraySize(BuFVGHighs) > 10) ArrayResize(BuFVGHighs, 10);
         
         ArrayResize(BuFVGLows, ArraySize(BuFVGLows) + 1);
         ArrayCopy(BuFVGLows, BuFVGLows, 1, 0);
         BuFVGLows[0] = fvglow_price;
         if(ArraySize(BuFVGLows) > 10) ArrayResize(BuFVGLows, 10);
         
         ArrayResize(BuFVGTime, ArraySize(BuFVGTime) + 1);
         ArrayCopy(BuFVGTime, BuFVGTime, 1, 0);
         BuFVGTime[0] = fvg_unique_time_id;
         if(ArraySize(BuFVGTime) > 10) ArrayResize(BuFVGTime, 10);

         string objName = "Bu.FVG " + TimeToString(fvg_unique_time_id) + " " + EnumToString(InpAnalysisTimeframe);
         if(ObjectFind(0, objName) < 0)
             ObjectCreate(0, objName, OBJ_RECTANGLE, 0, fvgtime_start, fvghigh_price, fvgtime_end, fvglow_price);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGreen);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT); // Dotted to distinguish from OB
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true); // Send to back
         ObjectSetInteger(0, objName, OBJPROP_FILL, false); 
         return 1;
        }
     }

//Bearish FVG (on InpAnalysisTimeframe)
   if( rates[1].high < rates[3].low &&
       rates[2].close < rates[3].low && // Candle 2 pushes through
       rates[1].close < rates[1].open && // Candle 1 is bearish
       rates[3].close < rates[3].open    // Candle 3 is bearish
     )
     {
      double fvghigh_price = rates[1].high; // Top of gap (using highs for bearish for clarity)
      double fvglow_price = rates[3].low;   // Bottom of gap
      datetime fvgtime_start = rates[3].time;
      datetime fvgtime_end = rates[0].time;
      datetime fvg_unique_time_id = rates[2].time;

      if(ArraySize(BeFVGTime) == 0 || (ArraySize(BeFVGTime) > 0 && BeFVGTime[0] != fvg_unique_time_id))
        {
         ArrayResize(BeFVGHighs, ArraySize(BeFVGHighs) + 1);
         ArrayCopy(BeFVGHighs, BeFVGHighs, 1, 0);
         BeFVGHighs[0] = fvghigh_price;
         if(ArraySize(BeFVGHighs) > 10) ArrayResize(BeFVGHighs, 10);
         
         ArrayResize(BeFVGLows, ArraySize(BeFVGLows) + 1);
         ArrayCopy(BeFVGLows, BeFVGLows, 1, 0);
         BeFVGLows[0] = fvglow_price;
         if(ArraySize(BeFVGLows) > 10) ArrayResize(BeFVGLows, 10);
         
         ArrayResize(BeFVGTime, ArraySize(BeFVGTime) + 1);
         ArrayCopy(BeFVGTime, BeFVGTime, 1, 0);
         BeFVGTime[0] = fvg_unique_time_id;
         if(ArraySize(BeFVGTime) > 10) ArrayResize(BeFVGTime, 10);
        
         string objName = "Be.FVG " + TimeToString(fvg_unique_time_id) + " " + EnumToString(InpAnalysisTimeframe);
         if(ObjectFind(0, objName) < 0)
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, fvgtime_start, fvglow_price, fvgtime_end, fvghigh_price);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetInteger(0, objName, OBJPROP_FILL, false);
         return -1; // Changed from 1 to -1 for bearish
        }
     }

   // Invalidation Logic for FVGs (Example: FVG is invalidated if price trades completely through it)
   // This requires keeping track of previously drawn FVGs and checking current price against them.
   // For simplicity in this merge, I'm omitting FVG invalidation drawing removal, but you can add it similar to OB invalidation.
   
   return 0;
  }

//+------------------------------------------------------------------+
//| Order Block (to be adapted for InpAnalysisTimeframe)             |
//+------------------------------------------------------------------+
int orderBlock()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // MODIFIED: Use InpAnalysisTimeframe
   int copied = CopyRates(_Symbol, InpAnalysisTimeframe, 0, 50, rates);
   if(copied < 5) { Print("orderBlock: Not enough rates for ",EnumToString(InpAnalysisTimeframe)); return 0; } // rates[4] needs at least 5 bars (0,1,2,3,4)

// Bullish Order Block
   if( rates[3].low < rates[4].low &&
       rates[3].low < rates[2].low &&
       rates[1].low > rates[3].high // Using rates[3].high (full range) for bullish OB top for displacement check
     )
     {
      double bullishOrderBlockHighValue = rates[3].high; // Using full high of the down candle for OB zone
      double bullishOrderBlockLowValue = rates[3].low;
      datetime bullishOrderBlockTimeValue = rates[3].time;

      if(ArraySize(bullishOrderBlockTime) == 0 || (ArraySize(bullishOrderBlockTime) > 0 && bullishOrderBlockTime[0] != bullishOrderBlockTimeValue))
        {
         ArrayResize(bullishOrderBlockHigh, ArraySize(bullishOrderBlockHigh) + 1);
         ArrayCopy(bullishOrderBlockHigh, bullishOrderBlockHigh, 1, 0);
         bullishOrderBlockHigh[0] = bullishOrderBlockHighValue;
         if(ArraySize(bullishOrderBlockHigh) > 10) ArrayResize(bullishOrderBlockHigh, 10);
         
         ArrayResize(bullishOrderBlockLow, ArraySize(bullishOrderBlockLow) + 1);
         ArrayCopy(bullishOrderBlockLow, bullishOrderBlockLow, 1, 0);
         bullishOrderBlockLow[0] = bullishOrderBlockLowValue;
         if(ArraySize(bullishOrderBlockLow) > 10) ArrayResize(bullishOrderBlockLow, 10);
         
         ArrayResize(bullishOrderBlockTime, ArraySize(bullishOrderBlockTime) + 1);
         ArrayCopy(bullishOrderBlockTime, bullishOrderBlockTime, 1, 0);
         bullishOrderBlockTime[0] = bullishOrderBlockTimeValue;
         if(ArraySize(bullishOrderBlockTime) > 10) ArrayResize(bullishOrderBlockTime, 10);

         string objName = "Bu.OB " + TimeToString(bullishOrderBlockTimeValue) + " " + EnumToString(InpAnalysisTimeframe);
         if(ObjectFind(0, objName) < 0)
             ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rates[3].time, rates[3].low, rates[0].time, bullishOrderBlockHighValue);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrTeal);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2); // Slightly thinner than original File3
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetInteger(0, objName, OBJPROP_FILL, false); 
         return 1;
        }
     }

// Bearish Order Block
   if( rates[3].high > rates[4].high &&
       rates[3].high > rates[2].high &&
       rates[1].high < rates[3].low // Using rates[3].low (full range) for bearish OB bottom for displacement
     )
     {
      double bearishOrderBlockLowValue = rates[3].low; // Using full low of the up candle
      double bearishOrderBlockHighValue = rates[3].high;
      datetime bearishOrderBlockTimeValue = rates[3].time;

      if(ArraySize(bearishOrderBlockTime) == 0 || (ArraySize(bearishOrderBlockTime) > 0 && bearishOrderBlockTime[0] != bearishOrderBlockTimeValue))
        {
         ArrayResize(bearishOrderBlockLow, ArraySize(bearishOrderBlockLow) + 1);
         ArrayCopy(bearishOrderBlockLow, bearishOrderBlockLow, 1, 0);
         bearishOrderBlockLow[0] = bearishOrderBlockLowValue;
         if(ArraySize(bearishOrderBlockLow) > 10) ArrayResize(bearishOrderBlockLow, 10);
         
         ArrayResize(bearishOrderBlockHigh, ArraySize(bearishOrderBlockHigh) + 1);
         ArrayCopy(bearishOrderBlockHigh, bearishOrderBlockHigh, 1, 0);
         bearishOrderBlockHigh[0] = bearishOrderBlockHighValue;
         if(ArraySize(bearishOrderBlockHigh) > 10) ArrayResize(bearishOrderBlockHigh, 10);
         
         ArrayResize(bearishOrderBlockTime, ArraySize(bearishOrderBlockTime) + 1);
         ArrayCopy(bearishOrderBlockTime, bearishOrderBlockTime, 1, 0);
         bearishOrderBlockTime[0] = bearishOrderBlockTimeValue;
         if(ArraySize(bearishOrderBlockTime) > 10) ArrayResize(bearishOrderBlockTime, 10);

         string objName = "Be.OB " + TimeToString(bearishOrderBlockTimeValue) + " " + EnumToString(InpAnalysisTimeframe);
         if(ObjectFind(0, objName) < 0)
             ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rates[3].time, rates[3].high, rates[0].time, bearishOrderBlockLowValue);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDarkRed);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetInteger(0, objName, OBJPROP_FILL, false);
         return -1;
        }
     }

//Invalidation Logic (checks InpAnalysisTimeframe OBs against InpAnalysisTimeframe price action)
//Bullish
   for(int i = ArraySize(bullishOrderBlockLow) - 1; i >= 0; i--)
     {
      // Check if enough elements exist, OB is in the past, and price has mitigated/invalidated
      if( ArraySize(bullishOrderBlockTime) > i && bullishOrderBlockTime[i] < rates[0].time && 
          rates[1].low < bullishOrderBlockLow[i] && // Example: Wick into OB low
          rates[1].close < bullishOrderBlockLow[i] // Example: Close below OB low for invalidation
        )
        {
         string objName1 = "Bu.OB " + TimeToString(bullishOrderBlockTime[i]) + " " + EnumToString(InpAnalysisTimeframe);
         if(ObjectFind(0, objName1) >= 0 && ObjectDelete(0, objName1))
           {
            ArrayRemove(bullishOrderBlockLow, i, 1);
            ArrayRemove(bullishOrderBlockHigh, i, 1);
            ArrayRemove(bullishOrderBlockTime, i, 1);
           }
        }
     }
//Bearish
   for(int i = ArraySize(bearishOrderBlockHigh) - 1; i >= 0; i--)
     {
      if( ArraySize(bearishOrderBlockTime) > i && bearishOrderBlockTime[i] < rates[0].time &&
          rates[1].high > bearishOrderBlockHigh[i] && // Wick into OB high
          rates[1].close > bearishOrderBlockHigh[i]   // Close above OB high
        )
        {
         string objName2 = "Be.OB " + TimeToString(bearishOrderBlockTime[i]) + " " + EnumToString(InpAnalysisTimeframe);
         if(ObjectFind(0, objName2) >= 0 && ObjectDelete(0, objName2))
           {
            ArrayRemove(bearishOrderBlockLow, i, 1);
            ArrayRemove(bearishOrderBlockHigh, i, 1);
            ArrayRemove(bearishOrderBlockTime, i, 1);
           }
        }
     }
   return 0;
  }

//+------------------------------------------------------------------+
//| Rejection Block (Copied from File 3, adapted for InpAnalysisTimeframe & Inputs) |
//+------------------------------------------------------------------+
int rBlock()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // MODIFIED: Use InpAnalysisTimeframe
   int copied = CopyRates(_Symbol, InpAnalysisTimeframe, 0, 50, rates);
   if(copied < 4) { Print("rBlock: Not enough rates for ",EnumToString(InpAnalysisTimeframe)); return 0; } // rates[3] needs 4 bars (0,1,2,3)

// Bullish rBlock Green (Green candle swing low)
   if( rates[2].close > rates[2].open && // Green candle
       rates[2].low < rates[3].low &&
       rates[2].low < rates[1].low
     )
     {
      double rBlockHigh = rates[2].open;  // Body top for green candle
      double rBlockLow = rates[2].low;   // Wick low
      datetime rBlockTime = rates[2].time;

      if(ArraySize(bullishGreenTimeValues) == 0 || (ArraySize(bullishGreenTimeValues) > 0 && bullishGreenTimeValues[0] != rBlockTime))
        {
         ArrayResize(bullishGreenHighValues, ArraySize(bullishGreenHighValues) + 1);
         ArrayCopy(bullishGreenHighValues, bullishGreenHighValues, 1, 0);
         bullishGreenHighValues[0] = rBlockHigh;
         if(ArraySize(bullishGreenHighValues) > 10) ArrayResize(bullishGreenHighValues, 10);
         
         ArrayResize(bullishGreenLowValues, ArraySize(bullishGreenLowValues) + 1);
         ArrayCopy(bullishGreenLowValues, bullishGreenLowValues, 1, 0);
         bullishGreenLowValues[0] = rBlockLow;
         if(ArraySize(bullishGreenLowValues) > 10) ArrayResize(bullishGreenLowValues, 10);
         
         ArrayResize(bullishGreenTimeValues, ArraySize(bullishGreenTimeValues) + 1);
         ArrayCopy(bullishGreenTimeValues, bullishGreenTimeValues, 1, 0);
         bullishGreenTimeValues[0] = rBlockTime;
         if(ArraySize(bullishGreenTimeValues) > 10) ArrayResize(bullishGreenTimeValues, 10);

         string objName = "Bu.rBG " + TimeToString(rBlockTime) + " " + EnumToString(InpAnalysisTimeframe);
         if(ObjectFind(0, objName) < 0)
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rBlockTime, rBlockLow, rates[0].time, rBlockHigh);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, Inp_Bullish_Green_rBlock_Color);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, Inp_rBlock_Width);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true); ObjectSetInteger(0, objName, OBJPROP_FILL, false);
         return 1; // Bullish Green
        }
     }

// Bullish rBlock Red (Red candle swing low)
   if( rates[2].close < rates[2].open && // Red candle
       rates[2].low < rates[3].low &&
       rates[2].low < rates[1].low
     )
     {
      double rBlockHigh = rates[2].close; // Body bottom for red candle (which is higher price for bullish context)
      double rBlockLow = rates[2].low;
      datetime rBlockTime = rates[2].time;
      
      if(ArraySize(bullishRedTimeValues) == 0 || (ArraySize(bullishRedTimeValues) > 0 && bullishRedTimeValues[0] != rBlockTime))
        {
         ArrayResize(bullishRedHighValues, ArraySize(bullishRedHighValues) + 1);
         ArrayCopy(bullishRedHighValues, bullishRedHighValues, 1, 0);
         bullishRedHighValues[0] = rBlockHigh;
         if(ArraySize(bullishRedHighValues) > 10) ArrayResize(bullishRedHighValues, 10);
         
         ArrayResize(bullishRedLowValues, ArraySize(bullishRedLowValues) + 1);
         ArrayCopy(bullishRedLowValues, bullishRedLowValues, 1, 0);
         bullishRedLowValues[0] = rBlockLow;
         if(ArraySize(bullishRedLowValues) > 10) ArrayResize(bullishRedLowValues, 10);
         
         ArrayResize(bullishRedTimeValues, ArraySize(bullishRedTimeValues) + 1);
         ArrayCopy(bullishRedTimeValues, bullishRedTimeValues, 1, 0);
         bullishRedTimeValues[0] = rBlockTime;
         if(ArraySize(bullishRedTimeValues) > 10) ArrayResize(bullishRedTimeValues, 10);

         string objName = "Bu.rBR " + TimeToString(rBlockTime) + " " + EnumToString(InpAnalysisTimeframe);
         if(ObjectFind(0, objName) < 0)
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rBlockTime, rBlockLow, rates[0].time, rBlockHigh);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, Inp_Bullish_Red_rBlock_Color);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, Inp_rBlock_Width);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true); ObjectSetInteger(0, objName, OBJPROP_FILL, false);
         return 2; // Bullish Red
        }
     }

// Bearish rBlock Red (Red candle swing high)
   if( rates[2].close < rates[2].open && // Red candle
       rates[2].high > rates[3].high &&
       rates[2].high > rates[1].high
     )
     {
      double rBlockHigh = rates[2].high;
      double rBlockLow = rates[2].open;   // Body top for red candle
      datetime rBlockTime = rates[2].time;

      if(ArraySize(bearishRedTimeValues) == 0 || (ArraySize(bearishRedTimeValues) > 0 && bearishRedTimeValues[0] != rBlockTime))
        {
         ArrayResize(bearishRedHighValues, ArraySize(bearishRedHighValues) + 1);
         ArrayCopy(bearishRedHighValues, bearishRedHighValues, 1, 0);
         bearishRedHighValues[0] = rBlockHigh;
         if(ArraySize(bearishRedHighValues) > 10) ArrayResize(bearishRedHighValues, 10);
         
         ArrayResize(bearishRedLowValues, ArraySize(bearishRedLowValues) + 1);
         ArrayCopy(bearishRedLowValues, bearishRedLowValues, 1, 0);
         bearishRedLowValues[0] = rBlockLow;
         if(ArraySize(bearishRedLowValues) > 10) ArrayResize(bearishRedLowValues, 10);
         
         ArrayResize(bearishRedTimeValues, ArraySize(bearishRedTimeValues) + 1);
         ArrayCopy(bearishRedTimeValues, bearishRedTimeValues, 1, 0);
         bearishRedTimeValues[0] = rBlockTime;
         if(ArraySize(bearishRedTimeValues) > 10) ArrayResize(bearishRedTimeValues, 10);

         string objName = "Be.rBR " + TimeToString(rBlockTime) + " " + EnumToString(InpAnalysisTimeframe);
         if(ObjectFind(0, objName) < 0)
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rBlockTime, rBlockHigh, rates[0].time, rBlockLow);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, Inp_Bearish_Red_rBlock_Color);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, Inp_rBlock_Width);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true); ObjectSetInteger(0, objName, OBJPROP_FILL, false);
         return -1; // Bearish Red
        }
     }

// Bearish rBlock Green (Green candle swing high)
   if( rates[2].close > rates[2].open && // Green candle
       rates[2].high > rates[3].high &&
       rates[2].high > rates[1].high
     )
     {
      double rBlockHigh = rates[2].high;
      double rBlockLow = rates[2].close;  // Body bottom for green candle
      datetime rBlockTime = rates[2].time;

      if(ArraySize(bearishGreenTimeValues) == 0 || (ArraySize(bearishGreenTimeValues) > 0 && bearishGreenTimeValues[0] != rBlockTime))
        {
         ArrayResize(bearishGreenHighValues, ArraySize(bearishGreenHighValues) + 1);
         ArrayCopy(bearishGreenHighValues, bearishGreenHighValues, 1, 0);
         bearishGreenHighValues[0] = rBlockHigh;
         if(ArraySize(bearishGreenHighValues) > 10) ArrayResize(bearishGreenHighValues, 10);
         
         ArrayResize(bearishGreenLowValues, ArraySize(bearishGreenLowValues) + 1);
         ArrayCopy(bearishGreenLowValues, bearishGreenLowValues, 1, 0);
         bearishGreenLowValues[0] = rBlockLow;
         if(ArraySize(bearishGreenLowValues) > 10) ArrayResize(bearishGreenLowValues, 10);
         
         ArrayResize(bearishGreenTimeValues, ArraySize(bearishGreenTimeValues) + 1);
         ArrayCopy(bearishGreenTimeValues, bearishGreenTimeValues, 1, 0);
         bearishGreenTimeValues[0] = rBlockTime;
         if(ArraySize(bearishGreenTimeValues) > 10) ArrayResize(bearishGreenTimeValues, 10);

         string objName = "Be.rBG " + TimeToString(rBlockTime) + " " + EnumToString(InpAnalysisTimeframe);
         if(ObjectFind(0, objName) < 0)
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rBlockTime, rBlockHigh, rates[0].time, rBlockLow);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, Inp_Bearish_Green_rBlock_Color);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, Inp_rBlock_Width);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true); ObjectSetInteger(0, objName, OBJPROP_FILL, false);
         return -2; // Bearish Green
        }
     }

//Invalidation Logic for rBlocks (Wick through implies invalidation)
//Bullish Green
   for(int i = ArraySize(bullishGreenLowValues) - 1; i >= 0; i--)
     {
      if( ArraySize(bullishGreenTimeValues) > i && bullishGreenTimeValues[i] < rates[0].time &&
          rates[1].low < bullishGreenLowValues[i] // Simplified: just a wick below invalidates
        )
        {
         string objName1 = "Bu.rBG " + TimeToString(bullishGreenTimeValues[i]) + " " + EnumToString(InpAnalysisTimeframe);
         if(ObjectFind(0, objName1) >= 0 && ObjectDelete(0, objName1))
           {
            ArrayRemove(bullishGreenLowValues, i, 1); ArrayRemove(bullishGreenHighValues, i, 1); ArrayRemove(bullishGreenTimeValues, i, 1);
           }
        }
     }
//Bullish Red
    for(int i = ArraySize(bullishRedLowValues) - 1; i >= 0; i--)
     {
      if( ArraySize(bullishRedTimeValues) > i && bullishRedTimeValues[i] < rates[0].time &&
          rates[1].low < bullishRedLowValues[i] )
        {
         string objName = "Bu.rBR " + TimeToString(bullishRedTimeValues[i]) + " " + EnumToString(InpAnalysisTimeframe);
         if(ObjectFind(0, objName) >= 0 && ObjectDelete(0, objName))
           {
            ArrayRemove(bullishRedLowValues, i, 1); ArrayRemove(bullishRedHighValues, i, 1); ArrayRemove(bullishRedTimeValues, i, 1);
           }
        }
     }
//Bearish Red
    for(int i = ArraySize(bearishRedHighValues) - 1; i >= 0; i--)
     {
      if( ArraySize(bearishRedTimeValues) > i && bearishRedTimeValues[i] < rates[0].time &&
          rates[1].high > bearishRedHighValues[i] )
        {
         string objName = "Be.rBR " + TimeToString(bearishRedTimeValues[i]) + " " + EnumToString(InpAnalysisTimeframe);
         if(ObjectFind(0, objName) >= 0 && ObjectDelete(0, objName))
           {
            ArrayRemove(bearishRedLowValues, i, 1); ArrayRemove(bearishRedHighValues, i, 1); ArrayRemove(bearishRedTimeValues, i, 1);
           }
        }
     }
//Bearish Green
    for(int i = ArraySize(bearishGreenHighValues) - 1; i >= 0; i--)
     {
      if( ArraySize(bearishGreenTimeValues) > i && bearishGreenTimeValues[i] < rates[0].time &&
          rates[1].high > bearishGreenHighValues[i] )
        {
         string objName = "Be.rBG " + TimeToString(bearishGreenTimeValues[i]) + " " + EnumToString(InpAnalysisTimeframe);
         if(ObjectFind(0, objName) >= 0 && ObjectDelete(0, objName))
           {
            ArrayRemove(bearishGreenLowValues, i, 1); ArrayRemove(bearishGreenHighValues, i, 1); ArrayRemove(bearishGreenTimeValues, i, 1);
           }
        }
     }
   return 0;
  }

// Helper for Wingdings symbols if you want specific icons for BoS/CHoCH
int WingdingsSymbol(string character)
{
    if (character == "W") return 233; // Up arrow in Wingdings
    if (character == "X") return 234; // Down arrow in Wingdings
    // Add more as needed
    return 0; // Default: bullet or simple marker if char not found
}

//+------------------------------------------------------------------+