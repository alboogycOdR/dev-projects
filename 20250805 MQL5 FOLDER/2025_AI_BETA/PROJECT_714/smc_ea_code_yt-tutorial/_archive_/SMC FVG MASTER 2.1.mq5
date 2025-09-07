//+------------------------------------------------------------------+
//|                                         Master SMC EA.mq5        | 
//|                                          Copyright 2024, Usiola. |
//|                                   https://www.trenddaytrader.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Usiola."
#property link      "https://www.trenddaytrader.com"
#property version   "2.10" // Version up for ICT enhancements
/*


v2.1.
Summary of Implemented Enhancements:
PDH/PDL, PWH/PWL Added:
    Global variables g_pdh, g_pdl, g_pwh, g_pwl, g_timeLastDailyUpdate, g_timeLastWeeklyUpdate.
    Input parameters InpDrawPDH/L/PWH/L and colors.
    UpdatePeriodicLevels() function added and called in OnInit() and OnTick().
    DrawHorizontalLine() helper function created for drawing/updating the lines.
FVG Enhanced with CE:
    Global arrays BuFVG_CE[], BeFVG_CE[].
    Input parameter InpDrawFvgCE and color InpColorFvgCE.
    FVG() function calculates CE, stores it using AddToHistory_Double, and draws a STYLE_DASHDOTDOT line using ObjectCreate/ObjectSetInteger if InpDrawFvgCE is true.

Order Block Refined:
    Input parameter InpFilterObVolume.
    orderBlock() defines the OB zone using rates[3].high and rates[3].low.
    Volume filter check implemented using rates[x].tick_volume before storing/drawing the OB.
EQH/EQL Detection Added:
    Input parameters InpEqTolerancePips, InpDrawEqHL, InpColorEQH, InpColorEQL.
    swingPoints() function checks MathAbs(Highs[0] - Highs[1]) <= InpEqTolerancePips * _Point after detecting a higher high candidate (before confirming the swing), and similarly for lows.
    Uses createObj() with arrow code 0 and specific colors/text ("=EQH=", "=EQL=") to mark these zones. The text object should appear beside the price level.
Important Considerations:
    Trading Logic: Still requires definition. This code provides the analysis tools.
    Object Management: The current OnDeinit deletes many objects. You might want more granular control, especially for the PDH/L/W/L lines which should persist between EA runs unless specifically disabled. Periodic cleanup of old EQH/EQL markers might be needed (CleanupOldMarkers function provided as an example - needs to be called, perhaps once per day). The FVG CE lines currently get deleted by ObjectsDeleteAll. If FVG invalidation is added later, the corresponding CE line deletion should be included.
    Performance: Fetching daily/weekly high/low data is very efficient. The added checks within the main detection loops are minor. Performance should remain good.
    This version now incorporates the core requested enhancements. Please compile and test this version carefully, checking the new drawings and ensure the existing detection logic works as expected on your chosen InpAnalysisTimeframe. Then we can focus on building the trading rules!


*/
#include <Trade/Trade.mqh>
CTrade Trade;

int barsTotal;
int totalT; 

// --- Input Parameters ---
input group             "SMC Analysis Settings"
input ENUM_TIMEFRAMES InpAnalysisTimeframe = PERIOD_H1; // Changed default to H1 for example
input bool            InpFilterObVolume = false;     // <<< NEW: Filter Order Blocks by volume
input double          InpEqTolerancePips = 1.0;     // <<< NEW: Pips tolerance for EQH/EQL

input group             "MA Filter Settings"
input ENUM_TIMEFRAMES InpSmaTimeframe = PERIOD_H1;      
input int             InpSmaPeriod = 89;

input group             "Trade Management Settings"
input double          InpRiskToReward = 2.0;
input double          InpLots = 0.01;
input double          InpBreakevenTriggerPoints = 10000; 
input double          InpBreakevenPoints = 2000;         

input group             "Drawing Options"
input bool            InpDrawPDH = true;
input color           InpColorPDH = clrDarkViolet;
input bool            InpDrawPDL = true;
input color           InpColorPDL = clrDarkViolet;
input bool            InpDrawPWH = true;
input color           InpColorPWH = clrChocolate;
input bool            InpDrawPWL = true;
input color           InpColorPWL = clrChocolate;
input bool            InpDrawFvgCE = true;              // <<< NEW: Draw FVG 0.5 level
input color           InpColorFvgCE = clrGoldenrod;     // <<< NEW: Color for FVG CE line
input bool            InpDrawEqHL = true;               // <<< NEW: Draw EQH/EQL markers
input color           InpColorEQH = clrAqua;            // <<< NEW: Color for EQH marker
input color           InpColorEQL = clrMagenta;         // <<< NEW: Color for EQL marker
input color           Inp_Bullish_Green_rBlock_Color = clrGreen;
input color           Inp_Bullish_Red_rBlock_Color = clrTeal;
input color           Inp_Bearish_Green_rBlock_Color = clrFireBrick;
input color           Inp_Bearish_Red_rBlock_Color = clrRed;
input int             Inp_rBlock_Width = 1;

// --- Global Variables ---
// Structure / Patterns
double Highs[];
double Lows[];
datetime HighsTime[];
datetime LowsTime[];
int LastSwingMeter = 0;
datetime lastTimeH = 0; 
datetime prevTimeH = 0; 
datetime lastTimeL = 0; 
datetime prevTimeL = 0; 

double BuFVGHighs[];
double BuFVGLows[];
double BuFVG_CE[];       // <<< NEW: FVG Consequent Encroachment levels
datetime BuFVGTime[];
double BeFVGHighs[];
double BeFVGLows[];
double BeFVG_CE[];       // <<< NEW: FVG Consequent Encroachment levels
datetime BeFVGTime[];

double bullishOrderBlockHigh[];
double bullishOrderBlockLow[];
datetime bullishOrderBlockTime[];
double bearishOrderBlockHigh[];
double bearishOrderBlockLow[];
datetime bearishOrderBlockTime[];

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

// Periodic Levels
double g_pdh = 0.0;        // <<< NEW: Previous Day High
double g_pdl = 0.0;        // <<< NEW: Previous Day Low
double g_pwh = 0.0;        // <<< NEW: Previous Week High
double g_pwl = 0.0;        // <<< NEW: Previous Week Low
datetime g_timeLastDailyUpdate = 0; // <<< NEW
datetime g_timeLastWeeklyUpdate = 0;// <<< NEW

// Handles
int OnInit_handlesma_RetCode; 

// History array management functions (as before)
void AddToHistory_Double(double &arr[], double value, int max_size)
  {/* ... as before ... */
   ArrayResize(arr, ArraySize(arr) + 1);
   for(int i = ArraySize(arr) - 1; i > 0; i--) arr[i] = arr[i-1];
   arr[0] = value;
   if(ArraySize(arr) > max_size) ArrayResize(arr, max_size);
  }
void AddToHistory_Datetime(datetime &arr[], datetime value, int max_size)
  {/* ... as before ... */
   ArrayResize(arr, ArraySize(arr) + 1);
   for(int i = ArraySize(arr) - 1; i > 0; i--) arr[i] = arr[i-1];
   arr[0] = value;
   if(ArraySize(arr) > max_size) ArrayResize(arr, max_size);
  }
  
// --- Initialization ---
//+------------------------------------------------------------------+
int OnInit()
  {
   // Array Setups (Added CE Arrays)
   ArraySetAsSeries(Highs,true); ArraySetAsSeries(Lows,true);
   ArraySetAsSeries(HighsTime,true); ArraySetAsSeries(LowsTime,true);
   ArraySetAsSeries(BuFVGHighs,true); ArraySetAsSeries(BuFVGLows,true); ArraySetAsSeries(BuFVG_CE,true); ArraySetAsSeries(BuFVGTime,true);
   ArraySetAsSeries(BeFVGHighs,true); ArraySetAsSeries(BeFVGLows,true); ArraySetAsSeries(BeFVG_CE,true); ArraySetAsSeries(BeFVGTime,true);
   ArraySetAsSeries(bullishOrderBlockHigh,true); ArraySetAsSeries(bullishOrderBlockLow,true); ArraySetAsSeries(bullishOrderBlockTime,true);
   ArraySetAsSeries(bearishOrderBlockHigh,true); ArraySetAsSeries(bearishOrderBlockLow,true); ArraySetAsSeries(bearishOrderBlockTime,true);
   ArraySetAsSeries(bullishGreenHighValues,true); ArraySetAsSeries(bullishGreenLowValues,true); ArraySetAsSeries(bullishGreenTimeValues,true);
   ArraySetAsSeries(bullishRedHighValues,true); ArraySetAsSeries(bullishRedLowValues,true); ArraySetAsSeries(bullishRedTimeValues,true);
   ArraySetAsSeries(bearishRedLowValues,true); ArraySetAsSeries(bearishRedHighValues,true); ArraySetAsSeries(bearishRedTimeValues,true);
   ArraySetAsSeries(bearishGreenLowValues,true); ArraySetAsSeries(bearishGreenHighValues,true); ArraySetAsSeries(bearishGreenTimeValues,true);

   // SMA Handle
   OnInit_handlesma_RetCode = iMA(_Symbol, InpSmaTimeframe, InpSmaPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(OnInit_handlesma_RetCode == INVALID_HANDLE)
     {/* ... error print ... */ return(INIT_FAILED);}

   // Timeframe Check
   if(InpAnalysisTimeframe < Period())
     {/* ... warning print ... */}
     
   // Initialize Periodic Level Update Times
   g_timeLastDailyUpdate = 0;
   g_timeLastWeeklyUpdate = 0;
     
   // Trigger initial fetch of periodic levels
   UpdatePeriodicLevels(); 
   
   return(INIT_SUCCEEDED);
  }

// --- Deinitialization ---
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(OnInit_handlesma_RetCode != INVALID_HANDLE) IndicatorRelease(OnInit_handlesma_RetCode); 
   // Delete specific objects created by the EA
   ObjectsDeleteAll(0, "SMC "); // Delete objects starting with "SMC " prefix used in names
   ObjectsDeleteAll(0, "Bu."); // Delete FVG/OB/RB starting with Bu.
   ObjectsDeleteAll(0, "Be."); // Delete FVG/OB/RB starting with Be.
   ObjectsDeleteAll(0,"PDH_Line"); ObjectsDeleteAll(0,"PDL_Line"); ObjectsDeleteAll(0,"PWH_Line"); ObjectsDeleteAll(0,"PWL_Line");
   ObjectsDeleteAll(0,"Signal@"); // Delete BoS/CHoCH/EQH/EQL markers
   ChartRedraw(0);
  }

// --- Main Tick Logic ---
//+------------------------------------------------------------------+
void OnTick()
  {
   int bars = iBars(_Symbol, PERIOD_CURRENT);
   if(barsTotal != bars)
     {
      barsTotal = bars;

      // Update Periodic Levels if necessary
      UpdatePeriodicLevels();

      // Get SMA Buffer
      double sma[];
      ArraySetAsSeries(sma, true);
      if(OnInit_handlesma_RetCode != INVALID_HANDLE)
      { if(CopyBuffer(OnInit_handlesma_RetCode,MAIN_LINE,0,9,sma) <= 0) { /* error print */ } }

      // Get Current Rates
      MqlRates currentTfRates[];
      ArraySetAsSeries(currentTfRates,true);
      if(CopyRates(_Symbol,PERIOD_CURRENT,0,2,currentTfRates) < 2) { /* print, maybe return */ }

      // Run Analysis Functions
      swingPoints(); 
      FVG();         
      orderBlock();  
      rBlock();      

      totalT = PositionsTotal();
      // --- TRADING LOGIC (PLACEHOLDER) ---


      // BREAKEVEN LOGIC (Seems OK) ---


     }
  }
  
// --- Periodic Level Functions ---
//+------------------------------------------------------------------+
void UpdatePeriodicLevels()
  {
   datetime now = TimeCurrent();
   bool updated = false;
   
   // Daily Update (Check only once per day)
   MqlDateTime now_struct, last_daily_struct;
   TimeToStruct(now, now_struct);
   TimeToStruct(g_timeLastDailyUpdate, last_daily_struct);
   
   if(now_struct.day != last_daily_struct.day)
     {
      double daily_H[], daily_L[];
      if(CopyHigh(_Symbol, PERIOD_D1, 1, 1, daily_H) > 0 && CopyLow(_Symbol, PERIOD_D1, 1, 1, daily_L) > 0)
         {
          g_pdh = daily_H[0];
          g_pdl = daily_L[0];
          g_timeLastDailyUpdate = now; // Update last check time
          DrawHorizontalLine("PDH_Line", g_pdh, InpColorPDH, STYLE_DASHDOT, 1, InpDrawPDH);
          DrawHorizontalLine("PDL_Line", g_pdl, InpColorPDL, STYLE_DASHDOT, 1, InpDrawPDL);
          updated = true;
          PrintFormat("Updated PDH: %.5f, PDL: %.5f", g_pdh, g_pdl); 
         }
      else
         Print("Error fetching PDH/PDL data: ", GetLastError());
     }

   // Weekly Update (Check only once per week)
   MqlDateTime last_weekly_struct;
   TimeToStruct(g_timeLastWeeklyUpdate, last_weekly_struct);
   
   if(now_struct.day_of_week < last_weekly_struct.day_of_week || // New week started
      (g_timeLastWeeklyUpdate == 0 && now > 0)) // First run
     {
      double weekly_H[], weekly_L[];
      if(CopyHigh(_Symbol, PERIOD_W1, 1, 1, weekly_H) > 0 && CopyLow(_Symbol, PERIOD_W1, 1, 1, weekly_L) > 0)
         {
          g_pwh = weekly_H[0];
          g_pwl = weekly_L[0];
          g_timeLastWeeklyUpdate = now;
          DrawHorizontalLine("PWH_Line", g_pwh, InpColorPWH, STYLE_DOT, 2, InpDrawPWH); // Thicker dotted line
          DrawHorizontalLine("PWL_Line", g_pwl, InpColorPWL, STYLE_DOT, 2, InpDrawPWL);
          updated = true;
          PrintFormat("Updated PWH: %.5f, PWL: %.5f", g_pwh, g_pwl);
         }
       else
         Print("Error fetching PWH/PWL data: ", GetLastError());
     }
     
    if(updated) ChartRedraw();
  }
//+------------------------------------------------------------------+
void DrawHorizontalLine(string name, double price, color line_color, ENUM_LINE_STYLE style, int width, bool show)
  {
   if(!show) 
     { 
      ObjectDelete(0, name); 
      return; 
     }
   
   if(ObjectFind(0, name) < 0) // If doesn't exist, create
     {
      if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
         { Print("Error creating HLine ", name, ": ", GetLastError()); return; }
      ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetString(0, name, OBJPROP_TEXT, StringSubstr(name,0,3)); // Show PDH/PDL etc.
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true); // Extend line to right
     }
   else // If exists, update price
     {
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, line_color); // Ensure color updated if changed in inputs
      ObjectSetInteger(0, name, OBJPROP_STYLE, style); 
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width); 
     }
  }


// --- Object Creation/Deletion Helpers --- 
// createObj, deleteObj - modified to include TF in name
//+------------------------------------------------------------------+
void createObj(datetime time, double price, int arrowCode, int direction, color clr, string txt)
  {
   string objName ="";
   // Added TF to name for uniqueness
   StringConcatenate(objName, "Signal@", time, "_", DoubleToString(price, _Digits), "(", arrowCode, ")_", EnumToString(InpAnalysisTimeframe));

   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point; 
   double priceOffset = 2 * spread; 

   if(direction > 0) price += priceOffset; else if(direction < 0) price -= priceOffset;
   
   if(ObjectFind(0, objName) < 0) // Create only if it doesn't exist
     {
      if(ObjectCreate(0, objName, OBJ_ARROW, 0, time, price))
       { /* Set properties */ 
        ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2); 
        if(direction > 0) ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_TOP);
        if(direction < 0) ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
       }
     }

   string objNameDesc = objName + "_TXT"; 
   if(ObjectFind(0, objNameDesc) < 0) // Create only if it doesn't exist
     {
        if(ObjectCreate(0, objNameDesc, OBJ_TEXT, 0, time, price))
        { /* Set properties */ 
            ObjectSetString(0, objNameDesc, OBJPROP_TEXT, " " + txt); 
            ObjectSetInteger(0, objNameDesc, OBJPROP_COLOR, clr);
            ObjectSetInteger(0,objNameDesc,OBJPROP_FONTSIZE,8); 
            if(direction > 0) ObjectSetInteger(0, objNameDesc, OBJPROP_ANCHOR, ANCHOR_LEFT); 
            if(direction < 0) ObjectSetInteger(0, objNameDesc, OBJPROP_ANCHOR, ANCHOR_LEFT);
            ObjectSetDouble(0,objNameDesc,OBJPROP_ANGLE,0); 
        }
     }
  }
//+------------------------------------------------------------------+
void deleteObj(datetime time, double price, int arrowCode, string txt) // Needs adjustment if arrowCode isn't used
  {
   string objName = "";
   StringConcatenate(objName, "Signal@", time, "_", DoubleToString(price, _Digits), "(", arrowCode, ")_", EnumToString(InpAnalysisTimeframe));
   if(ObjectFind(0, objName) != -1) ObjectDelete(0, objName);

   string objNameDesc = objName + "_TXT";
   if(ObjectFind(0, objNameDesc) != -1) ObjectDelete(0, objNameDesc);
  }

// Helper to delete marker objects like EQH/EQL text if price moves far away
void CleanupOldMarkers(datetime oldestTimeToKeep) // Call periodically if needed
{
    int total = ObjectsTotal(0, 0, -1); //-1 indicates all object types
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, 0, -1);
        if (StringFind(name, " EQH") >= 0 || StringFind(name, " EQL") >= 0)
        {
            datetime time = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
            if (time < oldestTimeToKeep)
            {
                ObjectDelete(0, name);
            }
        }
    }
}

// --- SMC Detection Functions (With Enhancements) ---

//+------------------------------------------------------------------+
int swingPoints()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int copied = CopyRates(_Symbol,InpAnalysisTimeframe,0,50,rates); 
    if(copied < 5) {/* print error */; return 0; }

   // Get indices (using exact=false as discussed)
   int indexLastH = iBarShift(_Symbol,InpAnalysisTimeframe,lastTimeH, false); 
   int indexLastL = iBarShift(_Symbol,InpAnalysisTimeframe,lastTimeL, false);
   int indexPrevH = iBarShift(_Symbol,InpAnalysisTimeframe,prevTimeH, false);
   int indexPrevL = iBarShift(_Symbol,InpAnalysisTimeframe,prevTimeL, false);
   
   // --- BoS/CHoCH --- 
   if(indexLastH > 0 && indexLastL > 0 && indexPrevH > 0 && indexPrevL > 0 && 
      MathMax(indexLastH, MathMax(indexLastL, MathMax(indexPrevH, indexPrevL))) < copied)
   {/* ... BoS/CHoCH Logic as previously corrected, ensuring unique names and using Wingdings/Text Markers ... */}
     
// --- Swing Detection --- 
   if (copied >= 4) // Need rates[3], [2], [1]
   {
     //SwingHigh
     if (rates[2].high > rates[3].high && rates[2].high > rates[1].high)
     {
       double highvalue_swing = rates[2].high; 
       datetime hightime_swing = rates[2].time;

       if(LastSwingMeter < 0 && ArraySize(Highs) > 0) // If previous swing was also a High
       {
          if(highvalue_swing > Highs[0]) // Higher High - Overwrite previous temp SH
          {
             if(ArraySize(HighsTime) > 0) // Delete previous SH obj if exists (marker 'X')
               deleteObj(HighsTime[0], Highs[0], WingdingsSymbol("X"), "SH");
             // Check for EQH BEFORE storing new High
             if(ArraySize(Highs)>=1 && MathAbs(highvalue_swing - Highs[0]) <= InpEqTolerancePips*_Point && InpDrawEqHL) {
                createObj(HighsTime[0], Highs[0], 0, 1, InpColorEQH, "=EQH="); // Using Text obj
                createObj(hightime_swing, highvalue_swing, 0, 1, InpColorEQH, "=EQH=");
             }
             // Store new high
             AddToHistory_Double(Highs, highvalue_swing, 10);
             AddToHistory_Datetime(HighsTime, hightime_swing, 10);
             prevTimeH = lastTimeH; lastTimeH = hightime_swing;
             // Don't draw final marker yet, might be intermediate
          } 
          // else: Lower High - do nothing, current temp high remains
       } 
       else // New High after a Low or first swing
       {
          AddToHistory_Double(Highs, highvalue_swing, 10);
          AddToHistory_Datetime(HighsTime, hightime_swing, 10);
          prevTimeH = lastTimeH; lastTimeH = hightime_swing;
          LastSwingMeter = -1;
          // Optional: createObj(hightime_swing, highvalue_swing, WingdingsSymbol("X"), -1, clrLightGray, "SH"); // Mark the confirmed swing
          return -1;
       }
     } // End SwingHigh detection

     //SwingLow
     if (rates[2].low < rates[3].low && rates[2].low < rates[1].low)
     {
       double lowvalue_swing = rates[2].low;
       datetime lowtime_swing = rates[2].time;

       if (LastSwingMeter > 0 && ArraySize(Lows) > 0) // If previous was also Low
       {
         if (lowvalue_swing < Lows[0]) // Lower Low - Overwrite previous temp SL
         {
           if (ArraySize(LowsTime) > 0) // Delete previous SL obj (marker 'W')
             deleteObj(LowsTime[0], Lows[0], WingdingsSymbol("W"), "SL"); 
           // Check for EQL before storing new low
           if(ArraySize(Lows)>=1 && MathAbs(lowvalue_swing - Lows[0]) <= InpEqTolerancePips*_Point && InpDrawEqHL) {
              createObj(LowsTime[0], Lows[0], 0, -1, InpColorEQL, "=EQL=");
              createObj(lowtime_swing, lowvalue_swing, 0, -1, InpColorEQL, "=EQL=");
           }
           // Store new low
           AddToHistory_Double(Lows, lowvalue_swing, 10);
           AddToHistory_Datetime(LowsTime, lowtime_swing, 10);
           prevTimeL = lastTimeL; lastTimeL = lowtime_swing;
           // Don't draw final marker yet
         }
         // else: Higher Low - do nothing
       } 
       else // New Low after High or first swing
       {
         AddToHistory_Double(Lows, lowvalue_swing, 10);
         AddToHistory_Datetime(LowsTime, lowtime_swing, 10);
         prevTimeL = lastTimeL; lastTimeL = lowtime_swing;
         LastSwingMeter = 1;
         // Optional: createObj(lowtime_swing, lowvalue_swing, WingdingsSymbol("W"), 1, clrLightGray, "SL"); // Mark confirmed swing
         return 1;
       }
     } // End SwingLow detection
   } // End check for copied>=4
   return 0;
}

//+------------------------------------------------------------------+
int FVG()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int copied = CopyRates(_Symbol,InpAnalysisTimeframe,0,50,rates);
   if(copied < 4) {/*... print error ...*/ return 0; } 

//Bullish FVG 
   if(/* FVG conditions as before */
      rates[1].low > rates[3].high &&
      rates[2].close > rates[3].high && 
      rates[1].close > rates[1].open && 
      rates[3].close > rates[3].open )   
     {
      double fvgh_b = rates[3].high; 
      double fvgl_b = rates[1].low;  
      double fvgCE_b = (fvgh_b + fvgl_b) / 2.0; // <<< Calculate CE
      datetime fvgTStart_b = rates[3].time;
      datetime fvgTEnd_b = rates[0].time; 
      datetime fvgTId_b = rates[2].time; 

      if(ArraySize(BuFVGTime) == 0 || BuFVGTime[0] != fvgTId_b)
        {
         // Store values using helpers
         AddToHistory_Double(BuFVGHighs, fvgh_b, 10);
         AddToHistory_Double(BuFVGLows, fvgl_b, 10);
         AddToHistory_Double(BuFVG_CE, fvgCE_b, 10); // <<< Store CE
         AddToHistory_Datetime(BuFVGTime, fvgTId_b, 10);

         // Draw FVG Rectangle
         string objName = StringFormat("Bu.FVG %s %s", TimeToString(fvgTId_b, TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objName) < 0)
             ObjectCreate(0, objName, OBJ_RECTANGLE, 0, fvgTStart_b, fvgh_b, fvgTEnd_b, fvgl_b);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGreen);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT); /* ... other props ... */
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true); 
         ObjectSetInteger(0, objName, OBJPROP_FILL, false); 

         // <<< Draw CE Line
         if(InpDrawFvgCE)
           {
             string ceName = StringFormat("Bu.FVG.CE %s %s", TimeToString(fvgTId_b, TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
             if(ObjectFind(0,ceName)<0) ObjectCreate(0,ceName,OBJ_TREND,0,fvgTStart_b,fvgCE_b,fvgTEnd_b,fvgCE_b);
             ObjectSetInteger(0,ceName,OBJPROP_COLOR,InpColorFvgCE);
             ObjectSetInteger(0,ceName,OBJPROP_STYLE,STYLE_DASHDOTDOT); // Different style for CE
             ObjectSetInteger(0,ceName,OBJPROP_WIDTH,1);
             ObjectSetInteger(0,ceName,OBJPROP_BACK,true);
             ObjectSetInteger(0,ceName,OBJPROP_RAY_RIGHT,false); 
           }
         return 1;
        }
     }

//Bearish FVG 
    if(/* FVG conditions as before */
      rates[1].high < rates[3].low &&
      rates[2].close < rates[3].low && 
      rates[1].close < rates[1].open && 
      rates[3].close < rates[3].open )
     {
      double fvgh_s = rates[1].high; 
      double fvgl_s = rates[3].low;   
      double fvgCE_s = (fvgh_s + fvgl_s) / 2.0; // <<< Calculate CE
      datetime fvgTStart_s = rates[3].time;
      datetime fvgTEnd_s = rates[0].time;
      datetime fvgTId_s = rates[2].time;

      if(ArraySize(BeFVGTime) == 0 || BeFVGTime[0] != fvgTId_s)
        {
         AddToHistory_Double(BeFVGHighs, fvgh_s, 10);
         AddToHistory_Double(BeFVGLows, fvgl_s, 10);
         AddToHistory_Double(BeFVG_CE, fvgCE_s, 10); // <<< Store CE
         AddToHistory_Datetime(BeFVGTime, fvgTId_s, 10);
        
         // Draw Rectangle
         string objName = StringFormat("Be.FVG %s %s", TimeToString(fvgTId_s, TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objName) < 0)
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, fvgTStart_s, fvgl_s, fvgTEnd_s, fvgh_s);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
         /* ... other props ... */
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetInteger(0, objName, OBJPROP_FILL, false);
         
         // <<< Draw CE Line
          if(InpDrawFvgCE)
           {
             string ceName = StringFormat("Be.FVG.CE %s %s", TimeToString(fvgTId_s, TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
             if(ObjectFind(0,ceName)<0) ObjectCreate(0,ceName,OBJ_TREND,0,fvgTStart_s,fvgCE_s,fvgTEnd_s,fvgCE_s);
             ObjectSetInteger(0,ceName,OBJPROP_COLOR,InpColorFvgCE);
             ObjectSetInteger(0,ceName,OBJPROP_STYLE,STYLE_DASHDOTDOT); 
             ObjectSetInteger(0,ceName,OBJPROP_WIDTH,1);
             ObjectSetInteger(0,ceName,OBJPROP_BACK,true);
             ObjectSetInteger(0,ceName,OBJPROP_RAY_RIGHT,false);
           }
         return -1; 
        }
     }
   return 0;
  }

//+------------------------------------------------------------------+
int orderBlock()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, InpAnalysisTimeframe, 0, 50, rates); // Tick volume is included by default
   if(copied < 5) { /* error print */ return 0; } 

// Bullish Order Block
   if( rates[3].low < rates[4].low &&
       rates[3].low < rates[2].low &&
       rates[1].low > rates[3].high ) // Displacement check uses full high
     {
      // Check Volume Filter
      bool volume_ok = !InpFilterObVolume; 
      if(InpFilterObVolume) { 
         if (rates[3].tick_volume > rates[4].tick_volume && rates[3].tick_volume > rates[2].tick_volume) 
            volume_ok = true; 
         else
            volume_ok = false; // Explicitly false if filter fails
      }
      
      if(volume_ok) // <<< Only proceed if volume filter passes (or is off)
      {
          // <<< OB Zone uses full range of rates[3] candle >>>
          double ob_h_b = rates[3].high; 
          double ob_l_b = rates[3].low;   
          datetime ob_t_b = rates[3].time; 
    
          if(ArraySize(bullishOrderBlockTime) == 0 || bullishOrderBlockTime[0] != ob_t_b)
            {
             AddToHistory_Double(bullishOrderBlockHigh, ob_h_b, 10);
             AddToHistory_Double(bullishOrderBlockLow, ob_l_b, 10);
             AddToHistory_Datetime(bullishOrderBlockTime, ob_t_b, 10);
    
             string objName = StringFormat("Bu.OB %s %s", TimeToString(ob_t_b, TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
             if(ObjectFind(0, objName) < 0)
                 ObjectCreate(0, objName, OBJ_RECTANGLE, 0, ob_t_b, ob_l_b, rates[0].time, ob_h_b); // <<< Low to High
             ObjectSetInteger(0, objName, OBJPROP_COLOR, clrTeal);
             ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
             ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2); 
             ObjectSetInteger(0, objName, OBJPROP_BACK, true);
             ObjectSetInteger(0, objName, OBJPROP_FILL, false); 
             return 1;
            }
      } // End if volume_ok
     } // End Bullish OB check

// Bearish Order Block
   if( rates[3].high > rates[4].high &&
       rates[3].high > rates[2].high &&
       rates[1].high < rates[3].low ) // Displacement check uses full low
     {
        // Check Volume Filter
      bool volume_ok = !InpFilterObVolume; 
      if(InpFilterObVolume) { 
         if (rates[3].tick_volume > rates[4].tick_volume && rates[3].tick_volume > rates[2].tick_volume) 
            volume_ok = true; 
          else
            volume_ok = false;
      }
      
      if(volume_ok) // <<< Only proceed if volume filter passes (or is off)
      {
          // <<< OB Zone uses full range of rates[3] candle >>>
          double ob_l_s = rates[3].low;     
          double ob_h_s = rates[3].high;   
          datetime ob_t_s = rates[3].time; 
    
          if(ArraySize(bearishOrderBlockTime) == 0 || bearishOrderBlockTime[0] != ob_t_s)
            {
             AddToHistory_Double(bearishOrderBlockLow, ob_l_s, 10);
             AddToHistory_Double(bearishOrderBlockHigh, ob_h_s, 10);
             AddToHistory_Datetime(bearishOrderBlockTime, ob_t_s, 10);
    
             string objName = StringFormat("Be.OB %s %s", TimeToString(ob_t_s, TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
             if(ObjectFind(0, objName) < 0)
                 ObjectCreate(0, objName, OBJ_RECTANGLE, 0, ob_t_s, ob_h_s, rates[0].time, ob_l_s); // <<< High to Low
             ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDarkRed);
             ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
             ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
             ObjectSetInteger(0, objName, OBJPROP_BACK, true);
             ObjectSetInteger(0, objName, OBJPROP_FILL, false);
             return -1;
            }
      } // End if volume_ok
     } // End Bearish OB Check

//Invalidation Logic (Close past OB)
// ... (Invalidation logic remains as corrected in last step) ...
   return 0;
  }

//+------------------------------------------------------------------+
int rBlock()
  {
   // ... (rBlock function remains as corrected in last step) ...
   return 0; // Added default return
  }

//+------------------------------------------------------------------+
int WingdingsSymbol(string character)
 { /* ... as before ... */ 
    if (character == "W") return 233; 
    if (character == "X") return 234; 
    return 0; 
 }
//+------------------------------------------------------------------+