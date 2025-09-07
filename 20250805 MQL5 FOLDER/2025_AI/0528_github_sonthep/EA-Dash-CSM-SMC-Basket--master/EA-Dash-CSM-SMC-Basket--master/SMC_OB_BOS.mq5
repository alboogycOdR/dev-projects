//+------------------------------------------------------------------+
//| SMC_OB_BOS.mq5 - Optimized for M5 timeframe                      |
//+------------------------------------------------------------------+
#property copyright "2024"
#property version   "1.01"
#property strict
#property indicator_chart_window

// --- SMC Parameters for M5 ---
input ENUM_TIMEFRAMES Timeframe = PERIOD_M5; // Timeframe for detection (default: M5)
input int LookbackBars = 500;                // Bars to look back for swings (default: 500 for M5)
input int SwingWindow = 2;                   // Window size for swing high/low detection (default: 2)
input double MinMovePercent = 0.1;           // Minimum move for BOS/OB as percent (default: 0.1%)
input color BullOBColor = clrGreen;          // Color for Bullish OB
input color BearOBColor = clrRed;            // Color for Bearish OB
input color BOSColor = clrBlue;              // Color for BOS line

// Structure for Order Block
struct OrderBlock {
   int index;
   double price_high;
   double price_low;
   bool isBullish;
   bool valid;
};

OrderBlock LastBullOB, LastBearOB;
bool BullBOS = false, BearBOS = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   ChartRedraw();
   // UnitTest_SMC(); // Remove or comment out unit test for live chart
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   DetectBOSandOB();
   DrawZones();
   ShowTradeSuggestion();
}

//+------------------------------------------------------------------+
//| Detect BOS and Order Blocks                                      |
//+------------------------------------------------------------------+
void DetectBOSandOB()
{
   int bars = MathMin(Bars(_Symbol, Timeframe), LookbackBars);
   double highs[], lows[];
   CopyHigh(_Symbol, Timeframe, 0, bars, highs);
   CopyLow(_Symbol, Timeframe, 0, bars, lows);

   int lastHH = -1, lastHL = -1, lastLL = -1, lastLH = -1;
   // Find swings
   for(int i = bars-3; i >= 2; i--)
   {
      if(IsSwingHigh(highs, i))
      {
         if(lastHH == -1 || highs[i] > highs[lastHH]) lastHH = i;
         else if(lastHL == -1 || highs[i] < highs[lastHH]) lastHL = i;
      }
      if(IsSwingLow(lows, i))
      {
         if(lastLL == -1 || lows[i] < lows[lastLL]) lastLL = i;
         else if(lastLH == -1 || lows[i] > lows[lastLL]) lastLH = i;
      }
   }
   // Detect BOS
   BullBOS = false; BearBOS = false;
   if(lastLL > 0 && lastLH > 0 && lastHH > 0)
   {
      if(lastLH < lastLL && lastHH < lastLH) // LL -> LH -> break to HH
         BullBOS = true;
   }
   if(lastHH > 0 && lastHL > 0 && lastLL > 0)
   {
      if(lastHL < lastHH && lastLL < lastHL) // HH -> HL -> break to LL
         BearBOS = true;
   }
   Print("DetectBOSandOB: lastHH=", lastHH, " lastHL=", lastHL, " lastLL=", lastLL, " lastLH=", lastLH, " BullBOS=", BullBOS, " BearBOS=", BearBOS);

   // Draw all detected OB/BOS zones in the lookback window
   int obCount = 0, bosCount = 0;
   for(int i = bars-2; i >= 1; i--)
   {
      if(BullBOS && IsBullishOB(i, highs, lows) && !OBInvalidated(i, highs, lows, true))
      {
         string obName = StringFormat("BullOB_%d", i);
         DrawZone(obName, i, lows[i], highs[i], BullOBColor);
         obCount++;
      }
      if(BearBOS && IsBearishOB(i, highs, lows) && !OBInvalidated(i, highs, lows, false))
      {
         string obName = StringFormat("BearOB_%d", i);
         DrawZone(obName, i, lows[i], highs[i], BearOBColor);
         obCount++;
      }
      // Draw BOS lines for all detected BOS
      if(BullBOS && IsBullishOB(i, highs, lows) && !OBInvalidated(i, highs, lows, true))
      {
         string bosName = StringFormat("BOS_Bull_%d", i-1);
         DrawBOS(bosName, i-1, BOSColor);
         bosCount++;
      }
      if(BearBOS && IsBearishOB(i, highs, lows) && !OBInvalidated(i, highs, lows, false))
      {
         string bosName = StringFormat("BOS_Bear_%d", i-1);
         DrawBOS(bosName, i-1, BOSColor);
         bosCount++;
      }
   }
   Print("Drawn OBs:", obCount, " BOS lines:", bosCount);
}

//+------------------------------------------------------------------+
//| Loosened swing detection: windowed swing high/low                |
//+------------------------------------------------------------------+
bool IsSwingHigh(const double &highs[], int i, int window)
{
    int size = ArraySize(highs);
    for(int j = i-window; j <= i+window; j++)
    {
        if(j < 0 || j >= size || j == i) continue;
        if(highs[j] >= highs[i]) return false;
    }
    return true;
}

bool IsSwingLow(const double &lows[], int i, int window)
{
    int size = ArraySize(lows);
    for(int j = i-window; j <= i+window; j++)
    {
        if(j < 0 || j >= size || j == i) continue;
        if(lows[j] <= lows[i]) return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Order Block Detection                                            |
//+------------------------------------------------------------------+
bool IsBullishOB(int i, const double &highs[], const double &lows[], int window)
{
   return highs[i] < highs[i+1] && lows[i] < lows[i+1] && IsSwingLow(lows, i, window);
}
bool IsBearishOB(int i, const double &highs[], const double &lows[], int window)
{
   return highs[i] > highs[i+1] && lows[i] > lows[i+1] && IsSwingHigh(highs, i, window);
}

//+------------------------------------------------------------------+
//| OB Invalidation                                                  |
//+------------------------------------------------------------------+
bool OBInvalidated(int obIdx, const double &highs[], const double &lows[], bool bullish)
{
   int bars = ArraySize(highs);
   for(int j = obIdx-1; j >= 0; j--)
   {
      if(bullish && lows[j] < lows[obIdx]) return true;
      if(!bullish && highs[j] > highs[obIdx]) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Draw the most recent valid OB/BOS and last 5 swing labels        |
//+------------------------------------------------------------------+
void DrawZones()
{
   // Remove old objects
   ObjectsDeleteAll(0, (int)OBJ_RECTANGLE, 0);
   ObjectsDeleteAll(0, (int)OBJ_VLINE, 0);
   ObjectsDeleteAll(0, (int)OBJ_TEXT, 0);
   ObjectsDeleteAll(0, (int)OBJ_LABEL, 0);

   int bars = MathMin(Bars(_Symbol, Timeframe), LookbackBars);
   double highs[], lows[];
   CopyHigh(_Symbol, Timeframe, 0, bars, highs);
   CopyLow(_Symbol, Timeframe, 0, bars, lows);

   // --- 1. Draw only the last 5 swing structure labels ---
   int swingCount = 0;
   for(int i = bars-3; i >= 2 && swingCount < 5; i--)
   {
      string swingLabel = "";
      if(IsSwingHigh(highs, i, SwingWindow))
      {
         // Determine if HH or LH
         bool isHH = true;
         for(int j = i+1; j < bars; j++)
            if(IsSwingHigh(highs, j, SwingWindow) && highs[j] > highs[i]) isHH = false;
         swingLabel = isHH ? "HH" : "LH";
      }
      if(IsSwingLow(lows, i, SwingWindow))
      {
         // Determine if LL or HL
         bool isLL = true;
         for(int j = i+1; j < bars; j++)
            if(IsSwingLow(lows, j, SwingWindow) && lows[j] < lows[i]) isLL = false;
         swingLabel = isLL ? "LL" : "HL";
      }
      if(swingLabel != "")
      {
         string labelName = StringFormat("SwingLabel_%d", i);
         datetime t = iTime(_Symbol, Timeframe, i);
         double price = swingLabel == "HH" || swingLabel == "LH" ? highs[i] : lows[i];
         ObjectCreate(0, labelName, OBJ_TEXT, 0, t, price);
         ObjectSetString(0, labelName, OBJPROP_TEXT, swingLabel);
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
         swingCount++;
      }
   }

   // --- 2. Draw only the most recent valid OB and BOS, with min move filter ---
   int lastBullOB = -1, lastBearOB = -1;
   double minMove = MinMovePercent / 100.0; // Convert percent to fraction
   for(int i = bars-2; i >= 1; i--)
   {
      // Bullish OB/BOS
      if(lastBullOB == -1 && BullBOS && IsBullishOB(i, highs, lows, SwingWindow) && !OBInvalidated(i, highs, lows, true))
      {
         // Only accept if break is significant
         double move = MathAbs(highs[i] - lows[i]) / highs[i];
         if(move >= minMove)
            lastBullOB = i;
      }
      // Bearish OB/BOS
      if(lastBearOB == -1 && BearBOS && IsBearishOB(i, highs, lows, SwingWindow) && !OBInvalidated(i, highs, lows, false))
      {
         double move = MathAbs(highs[i] - lows[i]) / highs[i];
         if(move >= minMove)
            lastBearOB = i;
      }
      if(lastBullOB != -1 && lastBearOB != -1) break;
   }
   // Draw the most recent OB (bullish or bearish)
   if(lastBullOB != -1)
   {
      string obName = "BullOB_Recent";
      DrawZone(obName, lastBullOB, lows[lastBullOB], highs[lastBullOB], BullOBColor);
      // OB label
      string obLabel = obName + "_label";
      datetime t = iTime(_Symbol, Timeframe, lastBullOB);
      ObjectCreate(0, obLabel, OBJ_TEXT, 0, t, highs[lastBullOB]);
      ObjectSetString(0, obLabel, OBJPROP_TEXT, "OB");
      ObjectSetInteger(0, obLabel, OBJPROP_COLOR, BullOBColor);
      ObjectSetInteger(0, obLabel, OBJPROP_FONTSIZE, 10);
      // Draw BOS line and label
      string bosName = "BOS_Bull_Recent";
      DrawBOS(bosName, lastBullOB-1, BOSColor);
      string bosLabel = bosName + "_label";
      datetime tBOS = iTime(_Symbol, Timeframe, lastBullOB-1);
      ObjectCreate(0, bosLabel, OBJ_TEXT, 0, tBOS, highs[lastBullOB-1]);
      ObjectSetString(0, bosLabel, OBJPROP_TEXT, "BOS");
      ObjectSetInteger(0, bosLabel, OBJPROP_COLOR, BOSColor);
      ObjectSetInteger(0, bosLabel, OBJPROP_FONTSIZE, 10);
   }
   if(lastBearOB != -1)
   {
      string obName = "BearOB_Recent";
      DrawZone(obName, lastBearOB, lows[lastBearOB], highs[lastBearOB], BearOBColor);
      // OB label
      string obLabel = obName + "_label";
      datetime t = iTime(_Symbol, Timeframe, lastBearOB);
      ObjectCreate(0, obLabel, OBJ_TEXT, 0, t, lows[lastBearOB]);
      ObjectSetString(0, obLabel, OBJPROP_TEXT, "OB");
      ObjectSetInteger(0, obLabel, OBJPROP_COLOR, BearOBColor);
      ObjectSetInteger(0, obLabel, OBJPROP_FONTSIZE, 10);
      // Draw BOS line and label
      string bosName = "BOS_Bear_Recent";
      DrawBOS(bosName, lastBearOB-1, BOSColor);
      string bosLabel = bosName + "_label";
      datetime tBOS = iTime(_Symbol, Timeframe, lastBearOB-1);
      ObjectCreate(0, bosLabel, OBJ_TEXT, 0, tBOS, lows[lastBearOB-1]);
      ObjectSetString(0, bosLabel, OBJPROP_TEXT, "BOS");
      ObjectSetInteger(0, bosLabel, OBJPROP_COLOR, BOSColor);
      ObjectSetInteger(0, bosLabel, OBJPROP_FONTSIZE, 10);
   }
}

void DrawZone(string name, int barIdx, double price1, double price2, color clr)
{
   datetime t1 = iTime(_Symbol, Timeframe, barIdx);
   datetime t2 = iTime(_Symbol, Timeframe, 0);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, price1, t2, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

void DrawBOS(string name, int barIdx, color clr)
{
   datetime t = iTime(_Symbol, Timeframe, barIdx);
   ObjectCreate(0, name, OBJ_VLINE, 0, t, 0);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
}

//+------------------------------------------------------------------+
//| Show Trade Suggestion                                            |
//+------------------------------------------------------------------+
void ShowTradeSuggestion()
{
   string msg = "";
   if(BullBOS && LastBullOB.valid)
      msg = "BUY (Bullish BOS & OB)";
   else if(BearBOS && LastBearOB.valid)
      msg = "SELL (Bearish BOS & OB)";
   else
      msg = "NO TRADE";
   // Comment("SMC OB/BOS: ", msg); // Remove old comment

   // Draw a chart label in the upper left corner
   string labelName = "SMC_OB_BOS_Label";
   if(ObjectFind(0, labelName) < 0)
      ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 10);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, labelName, OBJPROP_TEXT, "SMC OB/BOS: " + msg);
}

//+------------------------------------------------------------------+
//| Unit Test Function                                               |
//+------------------------------------------------------------------+
void UnitTest_SMC()
{
   // Simulate a simple price series with a bullish BOS and OB
   double highs[10] = {1.10,1.12,1.11,1.13,1.15,1.14,1.16,1.18,1.17,1.19};
   double lows[10]  = {1.08,1.09,1.09,1.10,1.12,1.13,1.14,1.15,1.15,1.16};
   // Should detect swing high at 1.12 (bar 1), swing low at 1.08 (bar 0), etc.
   bool swingHigh = IsSwingHigh(highs, 1);
   bool swingLow = IsSwingLow(lows, 0);
   Print("UnitTest: swingHigh=", swingHigh, " swingLow=", swingLow);
   // Test OB detection
   bool bullOB = IsBullishOB(4, highs, lows);
   bool bearOB = IsBearishOB(5, highs, lows);
   Print("UnitTest: bullOB=", bullOB, " bearOB=", bearOB);
   // Test OB invalidation
   bool inv = OBInvalidated(4, highs, lows, true);
   Print("UnitTest: OBInvalidated=", inv);
}
// To run the unit test, call UnitTest_SMC() from OnInit or OnTick as needed.
//+------------------------------------------------------------------+ 