//+------------------------------------------------------------------+
//|                                           SmartMoneyConcepts.mq5 |
//|                                  Converted from LuxAlgo Indicator |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Converted from LuxAlgo"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   1

// Plot properties for colored candles
#property indicator_label1  "SMC Trend"
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrLimeGreen, clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

// Input parameters
// General
input string generalGroup = "===== General Settings =====";
input string modeOptions = "Historical";      // Mode: Historical or Present
input string styleOptions = "Colored";        // Style: Colored or Monochrome
input bool   showTrend = false;              // Color Candles

// Internal Structure
input string internalGroup = "===== Internal Structure =====";
input bool   showInternals = true;           // Show Internal Structure
input string showIBull = "All";              // Bullish Structure: All, BOS, CHoCH
input color  swingIBullColor = clrGreen;     // Bullish Internal Structure Color
input string showIBear = "All";              // Bearish Structure: All, BOS, CHoCH
input color  swingIBearColor = clrRed;       // Bearish Internal Structure Color
input bool   ifilterConfluence = false;      // Confluence Filter
input string internalStructureSize = "Tiny"; // Internal Label Size: Tiny, Small, Normal

// Swing Structure
input string swingGroup = "===== Swing Structure =====";
input bool   showStructure = true;           // Show Swing Structure
input string showBull = "All";               // Bullish Structure: All, BOS, CHoCH
input color  swingBullColor = clrGreen;      // Bullish Swing Structure Color
input string showBear = "All";               // Bearish Structure: All, BOS, CHoCH
input color  swingBearColor = clrRed;        // Bearish Swing Structure Color
input string swingStructureSize = "Small";   // Swing Label Size: Tiny, Small, Normal
input bool   showSwings = false;             // Show Swings Points
input int    length = 50;                    // Swing Length
input bool   showHLSwings = true;            // Show Strong/Weak High/Low

// Order Blocks
input string orderBlockGroup = "===== Order Blocks =====";
input bool   showIOB = true;                 // Internal Order Blocks
input int    iobShowLast = 5;                // Number of Internal Order Blocks
input bool   showOB = false;                 // Swing Order Blocks
input int    obShowLast = 5;                 // Number of Swing Order Blocks
input string obFilter = "Atr";               // Order Block Filter: Atr, Cumulative Mean Range
input color  ibullOBColor = C'49,121,245';   // Internal Bullish OB Color
input color  ibearOBColor = C'247,124,128';  // Internal Bearish OB Color
input color  bullOBColor = C'24,72,204';     // Bullish OB Color
input color  bearOBColor = C'178,40,51';     // Bearish OB Color

// EQH/EQL
input string eqhlGroup = "===== Equal Highs/Lows =====";
input bool   showEQ = true;                  // Equal High/Low
input int    eqLen = 3;                      // Bars Confirmation
input double eqThreshold = 0.1;              // Threshold (0-0.5)
input string eqSize = "Tiny";                // Label Size: Tiny, Small, Normal

// Fair Value Gaps
input string fvgGroup = "===== Fair Value Gaps =====";
input bool   showFVG = false;                // Fair Value Gaps
input bool   fvgAuto = true;                 // Auto Threshold
input string fvgTF = "current";              // Timeframe
input color  bullFVGColor = C'0,255,104';    // Bullish FVG Color
input color  bearFVGColor = C'255,0,8';      // Bearish FVG Color
input int    fvgExtend = 1;                  // Extend FVG

// Premium/Discount Zones
input string zoneGroup = "===== Premium/Discount Zones =====";
input bool   showSD = false;                 // Premium/Discount Zones
input color  premiumColor = clrRed;          // Premium Zone Color
input color  eqColor = clrGray;              // Equilibrium Zone Color
input color  discountColor = clrGreen;       // Discount Zone Color

// Buffers
double OpenBuffer[];
double HighBuffer[];
double LowBuffer[];
double CloseBuffer[];
double ColorBuffer[];
double ATRBuffer[];

// Global variables
int trend = 0, itrend = 0;
double topY = 0.0, btmY = 0.0;
int topX = 0, btmX = 0;
double itopY = 0.0, ibtmY = 0.0;
int itopX = 0, ibtmX = 0;
double trailUp, trailDn;
int trailUpX = 0, trailDnX = 0;
bool topCross = true, btmCross = true;
bool itopCross = true, ibtmCross = true;
string txtTop = "", txtBtm = "";

// Order blocks storage
struct OrderBlock {
   double top;
   double btm;
   datetime left;
   int type; // 1 for bullish, -1 for bearish
   string objName;
};

OrderBlock iOrderBlocks[];
OrderBlock sOrderBlocks[];
int iobSize = 0, obSize = 0;

// Structure labels
string structureLabels[];
int numLabels = 0;

// Fair Value Gaps
struct FVG {
   double top;
   double bottom;
   datetime time;
   bool bullish;
   string objName;
};

FVG fairValueGaps[];
int fvgCount = 0;

// Equal Highs/Lows
double eqPrevTop = 0.0;
datetime eqTopX = 0;
double eqPrevBtm = 0.0;
datetime eqBtmX = 0;

// Cumulative mean range
double cmeanRange = 0.0;
int barCount = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
   // Set indicator buffers
   SetIndexBuffer(0, OpenBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, HighBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, LowBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, CloseBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(5, ATRBuffer, INDICATOR_CALCULATIONS);
   
   // Settings for plotting
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_CANDLES);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, swingBullColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, swingBearColor);
   
   // Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Smart Money Concepts");
   
   // Initialize arrays
   ArrayResize(iOrderBlocks, iobShowLast);
   ArrayResize(sOrderBlocks, obShowLast);
   ArrayResize(structureLabels, 100);
   ArrayResize(fairValueGaps, 50);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Clean up all created objects
   ObjectsDeleteAll(0, "SMC_");
   
   for(int i = 0; i < numLabels; i++) {
      if(ObjectFind(0, structureLabels[i]) >= 0)
         ObjectDelete(0, structureLabels[i]);
   }
   
   // Clean up order blocks
   for(int i = 0; i < iobSize; i++) {
      if(ObjectFind(0, iOrderBlocks[i].objName) >= 0)
         ObjectDelete(0, iOrderBlocks[i].objName);
   }
   
   for(int i = 0; i < obSize; i++) {
      if(ObjectFind(0, sOrderBlocks[i].objName) >= 0)
         ObjectDelete(0, sOrderBlocks[i].objName);
   }
   
   // Clean up FVGs
   for(int i = 0; i < fvgCount; i++) {
      if(ObjectFind(0, fairValueGaps[i].objName) >= 0)
         ObjectDelete(0, fairValueGaps[i].objName);
   }
}

//+------------------------------------------------------------------+
//| Swings detection function                                        |
//+------------------------------------------------------------------+
void DetectSwings(const double &high[], const double &low[], int bars, int swingLen, 
                 bool &found_top, bool &found_btm, double &top_val, double &btm_val) {
   found_top = false;
   found_btm = false;
   
   if(bars < swingLen*2 + 1) return;
   
   // Find highest high within swing length
   int max_idx = ArrayMaximum(high, swingLen, bars-swingLen*2);
   double upper = high[max_idx];
   
   // Find lowest low within swing length
   int min_idx = ArrayMinimum(low, swingLen, bars-swingLen*2);
   double lower = low[min_idx];
   
   // Check for pivot high
   if(high[bars-swingLen] > upper && high[bars-swingLen] != high[bars-swingLen-1]) {
      found_top = true;
      top_val = high[bars-swingLen];
   }
   
   // Check for pivot low
   if(low[bars-swingLen] < lower && low[bars-swingLen] != low[bars-swingLen-1]) {
      found_btm = true;
      btm_val = low[bars-swingLen];
   }
}

//+------------------------------------------------------------------+
//| Display Structure function                                       |
//+------------------------------------------------------------------+
void DisplayStructure(datetime x, double y, string txt, color clr, bool dashed, bool down, string size) {
   string lineName = "SMC_Line_" + IntegerToString(numLabels);
   string labelName = "SMC_Label_" + IntegerToString(numLabels);
   
   // Store label name for cleanup
   structureLabels[numLabels] = labelName;
   numLabels++;
   
   // Create structure line
   ObjectCreate(0, lineName, OBJ_TREND, 0, x, y, TimeCurrent(), y);
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, dashed ? STYLE_DASH : STYLE_SOLID);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true);
   
   // Create label
   ObjectCreate(0, labelName, OBJ_TEXT, 0, x + (TimeCurrent() - x)/2, y);
   ObjectSetString(0, labelName, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
   
   // Set label size
   ENUM_ANCHOR_POINT anchor = down ? ANCHOR_LOWER : ANCHOR_UPPER;
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, anchor);
   
   int fontsize = 8;
   if(size == "Small") fontsize = 10;
   if(size == "Normal") fontsize = 12;
   
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, fontsize);
   
   // Clean up older objects if mode is Present
   if(modeOptions == "Present" && numLabels > 1) {
      ObjectDelete(0, structureLabels[numLabels-2]);
   }
}

//+------------------------------------------------------------------+
//| Order block coordinates function                                 |
//+------------------------------------------------------------------+
void FindOrderBlock(bool useMax, int startBar, double &top, double &btm, datetime &leftTime, int &blockType, 
                   const double &high[], const double &low[], const datetime &time[], const double &threshold[]) {
   double min = 999999;
   double max = 0;
   int idx = -1;
   
   int searchStart = MathMax(1, startBar - 50); // Search last 50 candles before the break
   
   if(useMax) {
      // Find bearish order block (previous swing high before bearish move)
      for(int i = searchStart; i < startBar; i++) {
         if((high[i] - low[i]) < threshold[i] * 2) {
            if(high[i] > max) {
               max = high[i];
               min = low[i];
               idx = i;
            }
         }
      }
   } else {
      // Find bullish order block (previous swing low before bullish move)
      for(int i = searchStart; i < startBar; i++) {
         if((high[i] - low[i]) < threshold[i] * 2) {
            if(low[i] < min || min == 999999) {
               min = low[i];
               max = high[i];
               idx = i;
            }
         }
      }
   }
   
   if(idx != -1)
   {
      top = max;
      btm = min;
      leftTime = time[idx];
      blockType = useMax ? -1 : 1; // -1 for bearish, 1 for bullish
   }
}

//+------------------------------------------------------------------+
//| Create Order Block objects                                       |
//+------------------------------------------------------------------+
void CreateOrderBlock(OrderBlock &blocks[], int index, double top, double btm, datetime left, 
                    int type, bool isInternal) {
   string prefix = isInternal ? "SMC_IOB_" : "SMC_OB_";
   string objName = prefix + IntegerToString(index);
   
   blocks[index].top = top;
   blocks[index].btm = btm;
   blocks[index].left = left;
   blocks[index].type = type;
   blocks[index].objName = objName;
   
   // Create rectangle object for order block
   ObjectCreate(0, objName, OBJ_RECTANGLE, 0, left, top, TimeCurrent(), btm);
   
   color blockColor;
   if(isInternal) {
      blockColor = type == 1 ? ibullOBColor : ibearOBColor;
   } else {
      blockColor = type == 1 ? bullOBColor : bearOBColor;
   }
   
   ObjectSetInteger(0, objName, OBJPROP_COLOR, blockColor);
   ObjectSetInteger(0, objName, OBJPROP_FILL, true);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   
   // Set fillcolor with appropriate transparency
   color fillColor = blockColor;
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, fillColor);
}

//+------------------------------------------------------------------+
//| Check order block break                                          |
//+------------------------------------------------------------------+
void CheckOrderBlockBreak(OrderBlock &blocks[], int &blockCount, double price) {
   for(int i = 0; i < blockCount; i++) {
      // If price breaks bearish order block (breaks above top)
      if(blocks[i].type == -1 && price > blocks[i].top) {
         ObjectDelete(0, blocks[i].objName);
         
         // Remove this order block by shifting all following blocks
         for(int j = i; j < blockCount - 1; j++) {
            blocks[j] = blocks[j+1];
         }
         blockCount--;
         i--; // Recheck this position as we've shifted elements
      }
      // If price breaks bullish order block (breaks below bottom)
      else if(blocks[i].type == 1 && price < blocks[i].btm) {
         ObjectDelete(0, blocks[i].objName);
         
         // Remove this order block by shifting all following blocks
         for(int j = i; j < blockCount - 1; j++) {
            blocks[j] = blocks[j+1];
         }
         blockCount--;
         i--; // Recheck this position as we've shifted elements
      }
   }
}

//+------------------------------------------------------------------+
//| Create Fair Value Gap                                            |
//+------------------------------------------------------------------+
void CreateFVG(bool bullish, double top, double bottom, datetime time) {
   if(fvgCount >= ArraySize(fairValueGaps)) {
      ArrayResize(fairValueGaps, fvgCount + 10);
   }
   
   string objName = "SMC_FVG_" + IntegerToString(fvgCount);
   
   fairValueGaps[fvgCount].top = top;
   fairValueGaps[fvgCount].bottom = bottom;
   fairValueGaps[fvgCount].time = time;
   fairValueGaps[fvgCount].bullish = bullish;
   fairValueGaps[fvgCount].objName = objName;
   
   // Create rectangle object for FVG
   ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time, top, 
               time + (PeriodSeconds(PERIOD_CURRENT) * fvgExtend), bottom);
   
   color fvgColor = bullish ? bullFVGColor : bearFVGColor;
   
   ObjectSetInteger(0, objName, OBJPROP_COLOR, fvgColor);
   ObjectSetInteger(0, objName, OBJPROP_FILL, true);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, fvgColor);
   
   fvgCount++;
}

//+------------------------------------------------------------------+
//| Check Fair Value Gap break                                       |
//+------------------------------------------------------------------+
void CheckFVGBreak(double high, double low) {
   for(int i = 0; i < fvgCount; i++) {
      // If bullish FVG is broken (price goes below bottom)
      if(fairValueGaps[i].bullish && low < fairValueGaps[i].bottom) {
         ObjectDelete(0, fairValueGaps[i].objName);
         
         // Remove this FVG by shifting all following FVGs
         for(int j = i; j < fvgCount - 1; j++) {
            fairValueGaps[j] = fairValueGaps[j+1];
         }
         fvgCount--;
         i--; // Recheck this position as we've shifted elements
      }
      // If bearish FVG is broken (price goes above top)
      else if(!fairValueGaps[i].bullish && high > fairValueGaps[i].top) {
         ObjectDelete(0, fairValueGaps[i].objName);
         
         // Remove this FVG by shifting all following FVGs
         for(int j = i; j < fvgCount - 1; j++) {
            fairValueGaps[j] = fairValueGaps[j+1];
         }
         fvgCount--;
         i--; // Recheck this position as we've shifted elements
      }
   }
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
   // Calculate ATR for order block filtering
   int atr_handle = iATR(NULL, 0, 200);
   CopyBuffer(atr_handle, 0, 0, rates_total, ATRBuffer);
   
   int start_calc = prev_calculated > 0 ? prev_calculated -1 : 0;
   
   // Calculate cumulative mean range
   for(int i = start_calc; i < rates_total; i++) {
      if(rates_total > 1) {
         double range = high[i] - low[i];
         if (barCount == 0) {
            cmeanRange = range;
         } else {
            cmeanRange = (cmeanRange * barCount + range) / (barCount + 1);
         }
         barCount++;
      }
   }
   
   // Copy price data to buffers if showing trend
   if(showTrend) {
      for(int i = prev_calculated; i < rates_total; i++) {
         OpenBuffer[i] = open[i];
         HighBuffer[i] = high[i];
         LowBuffer[i] = low[i];
         CloseBuffer[i] = close[i];
         
         // Color based on trend
         ColorBuffer[i] = (itrend > 0) ? 0 : 1; // 0 for bullish, 1 for bearish
      }
   }
   
   // Main calculation loop
   int limit = prev_calculated > 0 ? prev_calculated - 1 : 0;
   
   // Process all bars
   for(int i = limit; i < rates_total; i++) {
      // Skip insufficient bars
      if(i < length || i < 5) continue;
      
      // Detect swings
      bool foundTop = false, foundBtm = false;
      double topVal = 0, btmVal = 0;
      DetectSwings(high, low, i, length, foundTop, foundBtm, topVal, btmVal);
      
      // Detect internal swings (shorter timeframe)
      bool foundITop = false, foundIBtm = false;
      double iTopVal = 0, iBtmVal = 0;
      DetectSwings(high, low, i, 5, foundITop, foundIBtm, iTopVal, iBtmVal);
      
      // Handle pivot high
      if(foundTop) {
         topCross = true;
         txtTop = topVal > topY ? "HH" : "LH";
         
         if(showSwings) {
            string swingLabelName = "SMC_Swing_High_" + IntegerToString(i);
            ObjectCreate(0, swingLabelName, OBJ_TEXT, 0, time[i-length], topVal);
            ObjectSetString(0, swingLabelName, OBJPROP_TEXT, txtTop);
            ObjectSetInteger(0, swingLabelName, OBJPROP_COLOR, swingBearColor);
            ObjectSetInteger(0, swingLabelName, OBJPROP_ANCHOR, ANCHOR_LOWER);
            
            // Set label size
            int fontsize = 8;
            if(swingStructureSize == "Small") fontsize = 10;
            if(swingStructureSize == "Normal") fontsize = 12;
            ObjectSetInteger(0, swingLabelName, OBJPROP_FONTSIZE, fontsize);
         }
         
         topY = topVal;
         topX = i - length;
         
         trailUp = topVal;
         trailUpX = i - length;
      }
      
      // Handle internal pivot high
      if(foundITop) {
         itopCross = true;
         itopY = iTopVal;
         itopX = i - 5;
      }
      
      // Handle pivot low
      if(foundBtm) {
         btmCross = true;
         txtBtm = btmVal < btmY ? "LL" : "HL";
         
         if(showSwings) {
            string swingLabelName = "SMC_Swing_Low_" + IntegerToString(i);
            ObjectCreate(0, swingLabelName, OBJ_TEXT, 0, time[i-length], btmVal);
            ObjectSetString(0, swingLabelName, OBJPROP_TEXT, txtBtm);
            ObjectSetInteger(0, swingLabelName, OBJPROP_COLOR, swingBullColor);
            ObjectSetInteger(0, swingLabelName, OBJPROP_ANCHOR, ANCHOR_UPPER);
            
            // Set label size
            int fontsize = 8;
            if(swingStructureSize == "Small") fontsize = 10;
            if(swingStructureSize == "Normal") fontsize = 12;
            ObjectSetInteger(0, swingLabelName, OBJPROP_FONTSIZE, fontsize);
         }
         
         btmY = btmVal;
         btmX = i - length;
         
         trailDn = btmVal;
         trailDnX = i - length;
      }
      
      // Handle internal pivot low
      if(foundIBtm) {
         ibtmCross = true;
         ibtmY = iBtmVal;
         ibtmX = i - 5;
      }
      
      // Update trailing values
      trailUp = MathMax(high[i], trailUp);
      if(trailUp == high[i]) trailUpX = i;
      
      trailDn = MathMin(low[i], trailDn);
      if(trailDn == low[i]) trailDnX = i;
      
      // Check for internal bullish structure break
      bool bullConcordant = true;
      if(ifilterConfluence) {
         bullConcordant = (high[i] - MathMax(close[i], open[i])) > (MathMin(close[i], open[i]) - low[i]);
      }
      
      if(close[i] > itopY && itopCross && topY != itopY && bullConcordant) {
         bool choch = false;
         
         if(itrend < 0) {
            choch = true;
         }
         
         string txt = choch ? "CHoCH" : "BOS";
         
         if(showInternals) {
            if(showIBull == "All" || (showIBull == "BOS" && !choch) || (showIBull == "CHoCH" && choch)) {
               DisplayStructure(time[itopX], itopY, txt, swingIBullColor, true, true, internalStructureSize);
            }
         }
         
         itopCross = false;
         itrend = 1;
         
         // Internal Order Block
         if(showIOB && iobSize < iobShowLast) {
            double obTop=0, obBtm=0;
            datetime obLeft=0;
            int obType=0;
            FindOrderBlock(false, itopX, obTop, obBtm, obLeft, obType, high, low, time, ATRBuffer);
            if(obLeft != 0)
            {
              CreateOrderBlock(iOrderBlocks, iobSize, obTop, obBtm, obLeft, obType, true);
              iobSize++;
            }
         }
      }
      
      // Check for bullish structure break
      if(close[i] > topY && topCross) {
         bool choch = false;
         
         if(trend < 0) {
            choch = true;
         }
         
         string txt = choch ? "CHoCH" : "BOS";
         
         if(showStructure) {
            if(showBull == "All" || (showBull == "BOS" && !choch) || (showBull == "CHoCH" && choch)) {
               DisplayStructure(time[topX], topY, txt, swingBullColor, false, true, swingStructureSize);
            }
         }
         
         topCross = false;
         trend = 1;
         
         // Swing Order Block
         if(showOB && obSize < obShowLast) {
            double obTop=0, obBtm=0;
            datetime obLeft=0;
            int obType=0;
            FindOrderBlock(false, topX, obTop, obBtm, obLeft, obType, high, low, time, ATRBuffer);
            if(obLeft != 0)
            {
              CreateOrderBlock(sOrderBlocks, obSize, obTop, obBtm, obLeft, obType, false);
              obSize++;
            }
         }
      }
      
      // Check for internal bearish structure break
      bool bearConcordant = true;
      if(ifilterConfluence) {
         bearConcordant = (high[i] - MathMax(close[i], open[i])) < (MathMin(close[i], open[i]) - low[i]);
      }
      
      if(close[i] < ibtmY && ibtmCross && btmY != ibtmY && bearConcordant) {
         bool choch = false;
         
         if(itrend > 0) {
            choch = true;
         }
         
         string txt = choch ? "CHoCH" : "BOS";
         
         if(showInternals) {
            if(showIBear == "All" || (showIBear == "BOS" && !choch) || (showIBear == "CHoCH" && choch)) {
               DisplayStructure(time[ibtmX], ibtmY, txt, swingIBearColor, true, false, internalStructureSize);
            }
         }
         
         ibtmCross = false;
         itrend = -1;
         
         // Internal Order Block
         if(showIOB && iobSize < iobShowLast) {
            double obTop=0, obBtm=0;
            datetime obLeft=0;
            int obType=0;
            FindOrderBlock(true, ibtmX, obTop, obBtm, obLeft, obType, high, low, time, ATRBuffer);
            if(obLeft != 0)
            {
              CreateOrderBlock(iOrderBlocks, iobSize, obTop, obBtm, obLeft, obType, true);
              iobSize++;
            }
         }
      }
      
      // Check for bearish structure break
      if(close[i] < btmY && btmCross) {
         bool choch = false;
         
         if(trend > 0) {
            choch = true;
         }
         
         string txt = choch ? "CHoCH" : "BOS";
         
         if(showStructure) {
            if(showBear == "All" || (showBear == "BOS" && !choch) || (showBear == "CHoCH" && choch)) {
               DisplayStructure(time[btmX], btmY, txt, swingBearColor, false, false, swingStructureSize);
            }
         }
         
         btmCross = false;
         trend = -1;
         
         // Swing Order Block
         if(showOB && obSize < obShowLast) {
            double obTop=0, obBtm=0;
            datetime obLeft=0;
            int obType=0;
            FindOrderBlock(true, btmX, obTop, obBtm, obLeft, obType, high, low, time, ATRBuffer);
            if(obLeft != 0)
            {
               CreateOrderBlock(sOrderBlocks, obSize, obTop, obBtm, obLeft, obType, false);
               obSize++;
            }
         }
      }
      
      // Check for order block breaks
      CheckOrderBlockBreak(iOrderBlocks, iobSize, close[i]);
      CheckOrderBlockBreak(sOrderBlocks, obSize, close[i]);
      
      // Equal Highs/Lows Detection
      if(showEQ && i >= eqLen*2 + 1) {
         // Check for equal highs
         int highIndex1 = ArrayMaximum(high, eqLen, i-eqLen*2);
         int highIndex2 = ArrayMaximum(high, eqLen, i-eqLen);
         
         if(highIndex1 != -1 && highIndex2 != -1 && highIndex1 != highIndex2) {
            double maxHigh1 = high[highIndex1];
            double maxHigh2 = high[highIndex2];
            
            // If the highs are within the threshold
            if(MathAbs(maxHigh1 - maxHigh2) < ATRBuffer[i] * eqThreshold) {
               string eqhName = "SMC_EQH_" + IntegerToString(i);
               
               // Create dotted line between equal highs
               ObjectCreate(0, eqhName, OBJ_TREND, 0, time[highIndex1], maxHigh1, time[highIndex2], maxHigh2);
               ObjectSetInteger(0, eqhName, OBJPROP_COLOR, swingBearColor);
               ObjectSetInteger(0, eqhName, OBJPROP_STYLE, STYLE_DOT);
               ObjectSetInteger(0, eqhName, OBJPROP_WIDTH, 1);
               
               // Create label
               string eqhLabelName = "SMC_EQHL_" + IntegerToString(i);
               ObjectCreate(0, eqhLabelName, OBJ_TEXT, 0, time[highIndex2], maxHigh2);
               ObjectSetString(0, eqhLabelName, OBJPROP_TEXT, "EQH");
               ObjectSetInteger(0, eqhLabelName, OBJPROP_COLOR, swingBearColor);
               ObjectSetInteger(0, eqhLabelName, OBJPROP_ANCHOR, ANCHOR_LOWER);
               
               // Set label size
               int fontsize = 8;
               if(eqSize == "Small") fontsize = 10;
               if(eqSize == "Normal") fontsize = 12;
               ObjectSetInteger(0, eqhLabelName, OBJPROP_FONTSIZE, fontsize);
            }
         }
         
         // Check for equal lows
         int lowIndex1 = ArrayMinimum(low, eqLen, i-eqLen*2);
         int lowIndex2 = ArrayMinimum(low, eqLen, i-eqLen);
         
         if(lowIndex1 != -1 && lowIndex2 != -1 && lowIndex1 != lowIndex2) {
            double minLow1 = low[lowIndex1];
            double minLow2 = low[lowIndex2];
            
            // If the lows are within the threshold
            if(MathAbs(minLow1 - minLow2) < ATRBuffer[i] * eqThreshold) {
               string eqlName = "SMC_EQL_" + IntegerToString(i);
               
               // Create dotted line between equal lows
               ObjectCreate(0, eqlName, OBJ_TREND, 0, time[lowIndex1], minLow1, time[lowIndex2], minLow2);
               ObjectSetInteger(0, eqlName, OBJPROP_COLOR, swingBullColor);
               ObjectSetInteger(0, eqlName, OBJPROP_STYLE, STYLE_DOT);
               ObjectSetInteger(0, eqlName, OBJPROP_WIDTH, 1);
               
               // Create label
               string eqlLabelName = "SMC_EQLL_" + IntegerToString(i);
               ObjectCreate(0, eqlLabelName, OBJ_TEXT, 0, time[lowIndex2], minLow2);
               ObjectSetString(0, eqlLabelName, OBJPROP_TEXT, "EQL");
               ObjectSetInteger(0, eqlLabelName, OBJPROP_COLOR, swingBullColor);
               ObjectSetInteger(0, eqlLabelName, OBJPROP_ANCHOR, ANCHOR_UPPER);
               
               // Set label size
               int fontsize = 8;
               if(eqSize == "Small") fontsize = 10;
               if(eqSize == "Normal") fontsize = 12;
               ObjectSetInteger(0, eqlLabelName, OBJPROP_FONTSIZE, fontsize);
            }
         }
      }
      
      // Fair Value Gap detection
      if(showFVG && i >= 3) {
         // Bullish FVG: Current low > Previous high
         if(low[i] > high[i-2]) {
            double deltaPercent = ((close[i-1] - open[i-1]) / open[i-1]) * 100;
            double threshold = fvgAuto ? cmeanRange * 0.5 : 0; // Using 50% of mean range as threshold
            
            if(deltaPercent > threshold) {
               // Create bullish FVG
               CreateFVG(true, low[i], high[i-2], time[i-1]);
            }
         }
         
         // Bearish FVG: Current high < Previous low
         if(high[i] < low[i-2]) {
            double deltaPercent = ((close[i-1] - open[i-1]) / open[i-1]) * 100;
            double threshold = fvgAuto ? cmeanRange * 0.5 : 0; // Using 50% of mean range as threshold
            
            if(-deltaPercent > threshold) {
               // Create bearish FVG
               CreateFVG(false, high[i], low[i-2], time[i-1]);
            }
         }
         
         // Check for FVG breaks
         CheckFVGBreak(high[i], low[i]);
      }
   }
   
   // Draw Premium/Discount zones on the last bar
   if(showSD && rates_total > 0) {
      int lastBar = rates_total - 1;
      
      // Calculate zones
      double avg = (trailUp + trailDn) / 2;
      double premium_top = trailUp;
      double premium_bottom = 0.95 * trailUp + 0.05 * trailDn;
      double eq_top = 0.525 * trailUp + 0.475 * trailDn;
      double eq_bottom = 0.525 * trailDn + 0.475 * trailUp;
      double discount_top = 0.95 * trailDn + 0.05 * trailUp;
      double discount_bottom = trailDn;
      
      // Create premium zone
      string premiumName = "SMC_Premium_Zone";
      ObjectCreate(0, premiumName, OBJ_RECTANGLE, 0, time[MathMax(topX, btmX)], premium_top, 
                  time[lastBar], premium_bottom);
      ObjectSetInteger(0, premiumName, OBJPROP_COLOR, premiumColor);
      ObjectSetInteger(0, premiumName, OBJPROP_FILL, true);
      ObjectSetInteger(0, premiumName, OBJPROP_BACK, true);
      ObjectSetInteger(0, premiumName, OBJPROP_BGCOLOR, premiumColor);
      
      // Create premium label
      string premiumLabel = "SMC_Premium_Label";
      ObjectCreate(0, premiumLabel, OBJ_TEXT, 0, time[lastBar], premium_top);
      ObjectSetString(0, premiumLabel, OBJPROP_TEXT, "Premium");
      ObjectSetInteger(0, premiumLabel, OBJPROP_COLOR, premiumColor);
      ObjectSetInteger(0, premiumLabel, OBJPROP_ANCHOR, ANCHOR_LOWER);
      
      // Create equilibrium zone
      string eqName = "SMC_Equilibrium_Zone";
      ObjectCreate(0, eqName, OBJ_RECTANGLE, 0, time[MathMax(topX, btmX)], eq_top, 
                  time[lastBar], eq_bottom);
      ObjectSetInteger(0, eqName, OBJPROP_COLOR, eqColor);
      ObjectSetInteger(0, eqName, OBJPROP_FILL, true);
      ObjectSetInteger(0, eqName, OBJPROP_BACK, true);
      ObjectSetInteger(0, eqName, OBJPROP_BGCOLOR, eqColor);
      
      // Create equilibrium label
      string eqLabel = "SMC_Equilibrium_Label";
      ObjectCreate(0, eqLabel, OBJ_TEXT, 0, time[lastBar], avg);
      ObjectSetString(0, eqLabel, OBJPROP_TEXT, "Equilibrium");
      ObjectSetInteger(0, eqLabel, OBJPROP_COLOR, eqColor);
      ObjectSetInteger(0, eqLabel, OBJPROP_ANCHOR, ANCHOR_LEFT);
      
      // Create discount zone
      string discountName = "SMC_Discount_Zone";
      ObjectCreate(0, discountName, OBJ_RECTANGLE, 0, time[MathMax(topX, btmX)], discount_top, 
                  time[lastBar], discount_bottom);
      ObjectSetInteger(0, discountName, OBJPROP_COLOR, discountColor);
      ObjectSetInteger(0, discountName, OBJPROP_FILL, true);
      ObjectSetInteger(0, discountName, OBJPROP_BACK, true);
      ObjectSetInteger(0, discountName, OBJPROP_BGCOLOR, discountColor);
      
      // Create discount label
      string discountLabel = "SMC_Discount_Label";
      ObjectCreate(0, discountLabel, OBJ_TEXT, 0, time[lastBar], discount_bottom);
      ObjectSetString(0, discountLabel, OBJPROP_TEXT, "Discount");
      ObjectSetInteger(0, discountLabel, OBJPROP_COLOR, discountColor);
      ObjectSetInteger(0, discountLabel, OBJPROP_ANCHOR, ANCHOR_UPPER);
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+