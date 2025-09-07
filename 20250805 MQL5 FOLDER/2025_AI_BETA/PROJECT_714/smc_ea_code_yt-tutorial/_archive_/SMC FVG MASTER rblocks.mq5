//+------------------------------------------------------------------+
//| Rejection Block (Adapted for InpAnalysisTimeframe & Inputs)    |
//+------------------------------------------------------------------+
int rBlock()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // MODIFIED: Use InpAnalysisTimeframe
   int copied = CopyRates(_Symbol, InpAnalysisTimeframe, 0, 50, rates); // Get 50 bars of selected TF
   if(copied < 4) // Need rates[3], rates[2], rates[1], rates[0]
     {
      PrintFormat("rBlock: Not enough history for %s. Copied: %d, Needed: >=4",
                  EnumToString(InpAnalysisTimeframe), copied);
      return 0;
     }

// Bullish rBlock Green (Green candle swing low on InpAnalysisTimeframe)
   if( rates[2].close > rates[2].open && // Green candle
       rates[2].low < rates[3].low &&    // Lower low than previous
       rates[2].low < rates[1].low     // Lower low than next (swing low)
     )
     {
      double rBlockHigh = rates[2].open;  // Body top for green candle
      double rBlockLow = rates[2].low;   // Wick low
      datetime rBlockTime = rates[2].time; // Time of the rBlock candle

      // Check if this rBlock already exists to avoid duplicates
      if(ArraySize(bullishGreenTimeValues) == 0 || bullishGreenTimeValues[0] != rBlockTime)
        {
         // Add to arrays
         ArrayInsert(bullishGreenHighValues,rBlockHigh,0); ArrayResize(bullishGreenHighValues, MathMin(ArraySize(bullishGreenHighValues),10));
         ArrayInsert(bullishGreenLowValues,rBlockLow,0);   ArrayResize(bullishGreenLowValues,  MathMin(ArraySize(bullishGreenLowValues),10));
         ArrayInsert(bullishGreenTimeValues,rBlockTime,0); ArrayResize(bullishGreenTimeValues,MathMin(ArraySize(bullishGreenTimeValues),10));

         // Create rectangle object
         string objName = StringFormat("Bu.rBG %s %s", TimeToString(rBlockTime, TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objName) < 0) // If object doesn't exist
             ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rBlockTime, rBlockLow, rates[0].time, rBlockHigh); // Draw from rBlock time to current bar time of InpAnalysisTF
         ObjectSetInteger(0, objName, OBJPROP_COLOR, Inp_Bullish_Green_rBlock_Color);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, Inp_rBlock_Width);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true); 
         ObjectSetInteger(0, objName, OBJPROP_FILL, false);
         return 1; // Bullish Green rBlock
        }
     }

// Bullish rBlock Red (Red candle swing low on InpAnalysisTimeframe)
   if( rates[2].close < rates[2].open && // Red candle
       rates[2].low < rates[3].low &&
       rates[2].low < rates[1].low
     )
     {
      double rBlockHigh = rates[2].close; // For a red candle, close is lower than open. For Bullish rBlock, use close (upper part of wick interest)
      double rBlockLow = rates[2].low;
      datetime rBlockTime = rates[2].time;
      
      if(ArraySize(bullishRedTimeValues) == 0 || bullishRedTimeValues[0] != rBlockTime)
        {
         ArrayInsert(bullishRedHighValues,rBlockHigh,0); ArrayResize(bullishRedHighValues, MathMin(ArraySize(bullishRedHighValues),10));
         ArrayInsert(bullishRedLowValues,rBlockLow,0);   ArrayResize(bullishRedLowValues,  MathMin(ArraySize(bullishRedLowValues),10));
         ArrayInsert(bullishRedTimeValues,rBlockTime,0); ArrayResize(bullishRedTimeValues,MathMin(ArraySize(bullishRedTimeValues),10));

         string objName = StringFormat("Bu.rBR %s %s", TimeToString(rBlockTime, TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objName) < 0)
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rBlockTime, rBlockLow, rates[0].time, rBlockHigh);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, Inp_Bullish_Red_rBlock_Color);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, Inp_rBlock_Width);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true); ObjectSetInteger(0, objName, OBJPROP_FILL, false);
         return 2; // Bullish Red rBlock
        }
     }

// Bearish rBlock Red (Red candle swing high on InpAnalysisTimeframe)
   if( rates[2].close < rates[2].open && // Red candle
       rates[2].high > rates[3].high &&  // Higher high than previous
       rates[2].high > rates[1].high    // Higher high than next (swing high)
     )
     {
      double rBlockHigh = rates[2].high;
      double rBlockLow = rates[2].open;   // Body top for red candle
      datetime rBlockTime = rates[2].time;

      if(ArraySize(bearishRedTimeValues) == 0 || bearishRedTimeValues[0] != rBlockTime)
        {
         ArrayInsert(bearishRedHighValues,rBlockHigh,0); ArrayResize(bearishRedHighValues, MathMin(ArraySize(bearishRedHighValues),10));
         ArrayInsert(bearishRedLowValues,rBlockLow,0);   ArrayResize(bearishRedLowValues,  MathMin(ArraySize(bearishRedLowValues),10));
         ArrayInsert(bearishRedTimeValues,rBlockTime,0); ArrayResize(bearishRedTimeValues,MathMin(ArraySize(bearishRedTimeValues),10));

         string objName = StringFormat("Be.rBR %s %s", TimeToString(rBlockTime, TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objName) < 0)
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rBlockTime, rBlockHigh, rates[0].time, rBlockLow);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, Inp_Bearish_Red_rBlock_Color);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, Inp_rBlock_Width);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true); ObjectSetInteger(0, objName, OBJPROP_FILL, false);
         return -1; // Bearish Red rBlock
        }
     }

// Bearish rBlock Green (Green candle swing high on InpAnalysisTimeframe)
   if( rates[2].close > rates[2].open && // Green candle
       rates[2].high > rates[3].high &&
       rates[2].high > rates[1].high
     )
     {
      double rBlockHigh = rates[2].high;
      double rBlockLow = rates[2].close;  // Body bottom for green candle
      datetime rBlockTime = rates[2].time;

      if(ArraySize(bearishGreenTimeValues) == 0 || bearishGreenTimeValues[0] != rBlockTime)
        {
         ArrayInsert(bearishGreenHighValues,rBlockHigh,0); ArrayResize(bearishGreenHighValues, MathMin(ArraySize(bearishGreenHighValues),10));
         ArrayInsert(bearishGreenLowValues,rBlockLow,0);   ArrayResize(bearishGreenLowValues,  MathMin(ArraySize(bearishGreenLowValues),10));
         ArrayInsert(bearishGreenTimeValues,rBlockTime,0); ArrayResize(bearishGreenTimeValues,MathMin(ArraySize(bearishGreenTimeValues),10));

         string objName = StringFormat("Be.rBG %s %s", TimeToString(rBlockTime, TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objName) < 0)
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rBlockTime, rBlockHigh, rates[0].time, rBlockLow);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, Inp_Bearish_Green_rBlock_Color);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, Inp_rBlock_Width);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true); ObjectSetInteger(0, objName, OBJPROP_FILL, false);
         return -2; // Bearish Green rBlock
        }
     }

//Invalidation Logic for rBlocks (Wick through implies invalidation)
// Occurs on InpAnalysisTimeframe price action against InpAnalysisTimeframe rBlocks
// Bullish Green
   for(int i = ArraySize(bullishGreenTimeValues) - 1; i >= 0; i--)
     {
      // Ensure the rBlock is in the past relative to the current bar (rates[0]) of InpAnalysisTimeframe
      if( ArraySize(bullishGreenLowValues) > i && bullishGreenTimeValues[i] < rates[0].time &&
          rates[1].low < bullishGreenLowValues[i] // Current candle (rates[1]) wicks below the rBlock's low
        )
        {
         string objNameInvalid = StringFormat("Bu.rBG %s %s", TimeToString(bullishGreenTimeValues[i], TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objNameInvalid) >= 0 && ObjectDelete(0, objNameInvalid))
           {
            // Safely remove elements from arrays
            if(ArraySize(bullishGreenLowValues)>i) ArrayRemove(bullishGreenLowValues, i, 1);
            if(ArraySize(bullishGreenHighValues)>i) ArrayRemove(bullishGreenHighValues, i, 1);
            if(ArraySize(bullishGreenTimeValues)>i) ArrayRemove(bullishGreenTimeValues, i, 1);
           }
        }
     }
//Bullish Red
    for(int i = ArraySize(bullishRedTimeValues) - 1; i >= 0; i--)
     {
      if( ArraySize(bullishRedLowValues) > i && bullishRedTimeValues[i] < rates[0].time &&
          rates[1].low < bullishRedLowValues[i] )
        {
         string objNameInvalid = StringFormat("Bu.rBR %s %s", TimeToString(bullishRedTimeValues[i], TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objNameInvalid) >= 0 && ObjectDelete(0, objNameInvalid))
           {
            if(ArraySize(bullishRedLowValues)>i) ArrayRemove(bullishRedLowValues, i, 1);
            if(ArraySize(bullishRedHighValues)>i) ArrayRemove(bullishRedHighValues, i, 1);
            if(ArraySize(bullishRedTimeValues)>i) ArrayRemove(bullishRedTimeValues, i, 1);
           }
        }
     }
//Bearish Red
    for(int i = ArraySize(bearishRedTimeValues) - 1; i >= 0; i--)
     {
      if( ArraySize(bearishRedHighValues) > i && bearishRedTimeValues[i] < rates[0].time &&
          rates[1].high > bearishRedHighValues[i] ) // Wick above the rBlock's high
        {
         string objNameInvalid = StringFormat("Be.rBR %s %s", TimeToString(bearishRedTimeValues[i], TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objNameInvalid) >= 0 && ObjectDelete(0, objNameInvalid))
           {
            if(ArraySize(bearishRedLowValues)>i) ArrayRemove(bearishRedLowValues, i, 1);
            if(ArraySize(bearishRedHighValues)>i) ArrayRemove(bearishRedHighValues, i, 1);
            if(ArraySize(bearishRedTimeValues)>i) ArrayRemove(bearishRedTimeValues, i, 1);
           }
        }
     }
//Bearish Green
    for(int i = ArraySize(bearishGreenTimeValues) - 1; i >= 0; i--)
     {
      if( ArraySize(bearishGreenHighValues) > i && bearishGreenTimeValues[i] < rates[0].time &&
          rates[1].high > bearishGreenHighValues[i] )
        {
         string objNameInvalid = StringFormat("Be.rBG %s %s", TimeToString(bearishGreenTimeValues[i], TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objNameInvalid) >= 0 && ObjectDelete(0, objNameInvalid))
           {
            if(ArraySize(bearishGreenLowValues)>i) ArrayRemove(bearishGreenLowValues, i, 1);
            if(ArraySize(bearishGreenHighValues)>i) ArrayRemove(bearishGreenHighValues, i, 1);
            if(ArraySize(bearishGreenTimeValues)>i) ArrayRemove(bearishGreenTimeValues, i, 1);
           }
        }
     }
   return 0;
  }