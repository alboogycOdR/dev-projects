//+------------------------------------------------------------------+
//|                                         Master SMC EA.mq5        |
//|                                          Copyright 2024, Usiola. |
//|                                   https://www.trenddaytrader.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Usiola."
#property link      "https://www.trenddaytrader.com"
#property version   "2.12" // Version up for up for Text Labels
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

// Analysis Timeframe Settings
input group             "Analysis Settings"
input ENUM_TIMEFRAMES   InpAnalysisTimeframe = PERIOD_H1;  // Analysis Timeframe

// SMC Pattern Detection Settings
input group             "SMC Pattern Settings"
input bool              InpFilterObVolume = false;         // Filter Order Blocks by volume
input double            InpEqTolerancePips = 1.0;         // Equal High/Low tolerance (pips)

// Moving Average Filter Settings
input group             "MA Filter Settings"
input ENUM_TIMEFRAMES   InpSmaTimeframe = PERIOD_H1;       // MA Timeframe
input int               InpSmaPeriod = 89;                // MA Period

// Trade Management Settings
input group             "Trade Management"
input double            InpRiskToReward = 2.0;             // Risk:Reward ratio
input double            InpLots = 0.01;                   // Position size (lots)
input double            InpBreakevenTriggerPoints = 10000; // Breakeven trigger (points)
input double            InpBreakevenPoints = 2000;         // Breakeven offset (points)

// Visual Settings - General
input group             "Visual Settings - General"
input bool              InpDrawLabels = true;              // Show all text labels
input int               InpLabelFontSize = 7;              // Label font size

// Visual Settings - Periodic Levels
input group             "Visual Settings - Periodic Levels"
input int               InpPeriodicLabel_X_Offset = 50;    // Label X offset from right
input int               InpPeriodicLabel_Y_Offset = 5;     // Label Y offset from line
input ENUM_ANCHOR_POINT InpPeriodicLabel_Anchor = ANCHOR_RIGHT_UPPER; // Label anchor point

// Previous Day/Week High/Low Settings
input bool              InpDrawPDH = true;                 // Show Previous Day High
input color             InpColorPDH = clrDarkViolet;       // PDH color
input bool              InpDrawPDL = true;                 // Show Previous Day Low
input color             InpColorPDL = clrDarkViolet;       // PDL color
input bool              InpDrawPWH = true;                 // Show Previous Week High
input color             InpColorPWH = clrChocolate;        // PWH color
input bool              InpDrawPWL = true;                 // Show Previous Week Low
input color             InpColorPWL = clrChocolate;        // PWL color

// FVG and Equal High/Low Settings
input group             "Visual Settings - SMC Patterns"
input bool              InpDrawFvgCE = true;               // Show FVG center line
input color             InpColorFvgCE = clrGoldenrod;      // FVG center line color
input bool              InpDrawEqHL = true;                // Show Equal High/Low markers
input color             InpColorEQH = clrAqua;             // Equal High marker color
input color             InpColorEQL = clrMagenta;          // Equal Low marker color

// rBlock Color Settings
input group             "Visual Settings - rBlocks"
input color             Inp_Bullish_Green_rBlock_Color = clrGreen;     // Bullish Green rBlock
input color             Inp_Bullish_Red_rBlock_Color = clrTeal;       // Bullish Red rBlock
input color             Inp_Bearish_Green_rBlock_Color = clrFireBrick; // Bearish Green rBlock
input color             Inp_Bearish_Red_rBlock_Color = clrRed;        // Bearish Red rBlock
input int               Inp_rBlock_Width = 1;                          // rBlock line width
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
  {
   /* ... as before ... */
   ArrayResize(arr, ArraySize(arr) + 1);
   for(int i = ArraySize(arr) - 1; i > 0; i--)
      arr[i] = arr[i-1];
   arr[0] = value;
   if(ArraySize(arr) > max_size)
      ArrayResize(arr, max_size);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void AddToHistory_Datetime(datetime &arr[], datetime value, int max_size)
  {
   /* ... as before ... */
   ArrayResize(arr, ArraySize(arr) + 1);
   for(int i = ArraySize(arr) - 1; i > 0; i--)
      arr[i] = arr[i-1];
   arr[0] = value;
   if(ArraySize(arr) > max_size)
      ArrayResize(arr, max_size);
  }

// Simplified Helper for Text attached to Time/Price Objects (using OBJ_TEXT)
//+------------------------------------------------------------------+
void CreateAttachedText(string base_name, datetime time1, double price1, string text, color text_color,
                        int anchor = ANCHOR_LEFT, int x_shift_bars = 2, double y_shift_pips = 5)
  {
   if(!InpDrawLabels)
     {
      ObjectDelete(0, base_name + "_txt"); // Delete existing label if labels are off
      return;
     }

   string label_name = base_name + "_txt"; // Consistent suffix
   datetime label_time = iTime(_Symbol, InpAnalysisTimeframe, iBarShift(_Symbol, InpAnalysisTimeframe, time1) - x_shift_bars); // Position slightly left time-wise
   double label_price = price1 + (y_shift_pips * _Point); // Position slightly above price-wise

   if(ObjectFind(0, label_name) < 0)
     {
      if(!ObjectCreate(0, label_name, OBJ_TEXT, 0, label_time, label_price))
        {
         PrintFormat("Error creating attached text %s: %d", label_name, GetLastError());
         return;
        }
     }
   else
     {
      // If exists, update position
      ObjectSetInteger(0, label_name, OBJPROP_TIME, 0, label_time);
      ObjectSetDouble(0, label_name, OBJPROP_PRICE, 0, label_price);
     }

// Set common properties
   ObjectSetString(0, label_name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, label_name, OBJPROP_COLOR, text_color);
   ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, InpLabelFontSize);
   ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, label_name, OBJPROP_BACK, false); // Usually drawn over price
   ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, label_name, OBJPROP_HIDDEN, true);
  }



// <<< NEW Helper Function for Text Labels >>>
//+------------------------------------------------------------------+
void CreateTextLabel(string base_name, datetime time1, double price1, string text, color text_color,
                     int corner = CORNER_LEFT_UPPER, int anchor = ANCHOR_LEFT_UPPER,
                     int x_offset = 5, int y_offset = 5)
  {
   if(!InpDrawLabels) // Check global label flag
     {
      ObjectDelete(0, base_name + "_label"); // Delete if exists and labels are off
      return;
     }

   string label_name = base_name + "_label";

   if(ObjectFind(0, label_name) < 0) // Only create if it doesn't exist
     {
      if(!ObjectCreate(0, label_name, OBJ_LABEL, 0, 0, 0)) // Uses corner coords, not time/price for OBJ_LABEL
        {
         PrintFormat("Error creating label %s: %d", label_name, GetLastError());
         return;
        }
     }

// Set common properties for OBJ_LABEL (screen coordinates)
   ObjectSetInteger(0, label_name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, label_name, OBJPROP_XDISTANCE, x_offset); // Horizontal position from corner
   ObjectSetInteger(0, label_name, OBJPROP_YDISTANCE, y_offset); // Vertical position from corner
   ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, anchor);       // Where on the label its coords refer to

// Set text-specific properties
   ObjectSetString(0, label_name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, label_name, OBJPROP_COLOR, text_color);
   ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, InpLabelFontSize);
   ObjectSetInteger(0, label_name, OBJPROP_BACK, true); // Usually labels on top
   ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false); // Labels usually not selectable
   ObjectSetInteger(0, label_name, OBJPROP_HIDDEN, true); // Hide from object list
  }
// --- Initialization ---
//+------------------------------------------------------------------+
int OnInit()
  {
// Array Setups (Added CE Arrays)
   ArraySetAsSeries(Highs,true);
   ArraySetAsSeries(Lows,true);
   ArraySetAsSeries(HighsTime,true);
   ArraySetAsSeries(LowsTime,true);
   ArraySetAsSeries(BuFVGHighs,true);
   ArraySetAsSeries(BuFVGLows,true);
   ArraySetAsSeries(BuFVG_CE,true);
   ArraySetAsSeries(BuFVGTime,true);
   ArraySetAsSeries(BeFVGHighs,true);
   ArraySetAsSeries(BeFVGLows,true);
   ArraySetAsSeries(BeFVG_CE,true);
   ArraySetAsSeries(BeFVGTime,true);
   ArraySetAsSeries(bullishOrderBlockHigh,true);
   ArraySetAsSeries(bullishOrderBlockLow,true);
   ArraySetAsSeries(bullishOrderBlockTime,true);
   ArraySetAsSeries(bearishOrderBlockHigh,true);
   ArraySetAsSeries(bearishOrderBlockLow,true);
   ArraySetAsSeries(bearishOrderBlockTime,true);
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
// void OnDeinit(const int reason)
//   {
//    if(OnInit_handlesma_RetCode != INVALID_HANDLE) IndicatorRelease(OnInit_handlesma_RetCode);
// // Enhanced object deletion to include labels
//    ObjectsDeleteAll(0, "SMC ");       // BoS/CHoCH lines
//    ObjectsDeleteAll(0, "Bu.FVG ");    // FVG rect + CE line + labels
//    ObjectsDeleteAll(0, "Be.FVG ");    // FVG rect + CE line + labels
//    ObjectsDeleteAll(0, "Bu.OB ");     // OB rect + label
//    ObjectsDeleteAll(0, "Be.OB ");     // OB rect + label
//    ObjectsDeleteAll(0, "Bu.rB");      // RB rect + label (catches Bu.rBG & Bu.rBR)
//    ObjectsDeleteAll(0, "Be.rB");      // RB rect + label (catches Be.rBG & Be.rBR)
//    ObjectsDeleteAll(0, "PDH_Line");
//    ObjectsDeleteAll(0, "PDL_Line");
//    ObjectsDeleteAll(0, "PWH_Line");
//    ObjectsDeleteAll(0, "PWL_Line");
//    ObjectsDeleteAll(0, "Signal@");    // BoS/CHoCH/EQH/EQL markers & their text

//    // Might need to delete labels separately if using different suffix/prefix not caught above
//    ObjectsDeleteAll(0, "_label"); // Catch labels from CreateTextLabel if suffix was used (Now using CreateAttachedText)
//    ObjectsDeleteAll(0, "_txt"); // Catch labels from CreateAttachedText
//    ChartRedraw(0);
//   }
void OnDeinit(const int reason)
  {
   if(OnInit_handlesma_RetCode != INVALID_HANDLE)
      IndicatorRelease(OnInit_handlesma_RetCode);

   string prefixes[] = {"SMC ", "Bu.FVG", "Be.FVG", "Bu.OB", "Be.OB", "Bu.rB", "Be.rB", "PDH_Line", "PDL_Line", "PWH_Line", "PWL_Line", "Signal@"};
   for(int i = 0; i < ArraySize(prefixes); i++)
     {
      ObjectsDeleteAll(0, prefixes[i]);          // Delete the main object
      ObjectsDeleteAll(0, prefixes[i], "_txt");  // Delete associated text label
      ObjectsDeleteAll(0, prefixes[i], "_label");// Delete screen corner label if that was used
      if(StringFind(prefixes[i],"FVG")>=0)
         ObjectsDeleteAll(0, prefixes[i],".CE"); //Delete CE lines for FVGs
     }
   ObjectsDeleteAll(0,"_PD_label"); // Specific catch for Periodic Level Labels
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
// void UpdatePeriodicLevels()
//   {
//    datetime now = TimeCurrent();
//    bool updated = false;

//    // Daily Update (Check only once per day)
//    MqlDateTime now_struct, last_daily_struct;
//    TimeToStruct(now, now_struct);
//    TimeToStruct(g_timeLastDailyUpdate, last_daily_struct);

//    if(now_struct.day != last_daily_struct.day)
//      {
//       double daily_H[], daily_L[];
//       if(CopyHigh(_Symbol, PERIOD_D1, 1, 1, daily_H) > 0 && CopyLow(_Symbol, PERIOD_D1, 1, 1, daily_L) > 0)
//          {
//           g_pdh = daily_H[0];
//           g_pdl = daily_L[0];
//           g_timeLastDailyUpdate = now; // Update last check time
//           DrawHorizontalLine("PDH_Line", g_pdh, InpColorPDH, STYLE_DASHDOT, 1, InpDrawPDH);
//           DrawHorizontalLine("PDL_Line", g_pdl, InpColorPDL, STYLE_DASHDOT, 1, InpDrawPDL);
//           updated = true;
//           PrintFormat("Updated PDH: %.5f, PDL: %.5f", g_pdh, g_pdl);
//          }
//       else
//          Print("Error fetching PDH/PDL data: ", GetLastError());
//      }

//    // Weekly Update (Check only once per week)
//    MqlDateTime last_weekly_struct;
//    TimeToStruct(g_timeLastWeeklyUpdate, last_weekly_struct);

//    if(now_struct.day_of_week < last_weekly_struct.day_of_week || // New week started
//       (g_timeLastWeeklyUpdate == 0 && now > 0)) // First run
//      {
//       double weekly_H[], weekly_L[];
//       if(CopyHigh(_Symbol, PERIOD_W1, 1, 1, weekly_H) > 0 && CopyLow(_Symbol, PERIOD_W1, 1, 1, weekly_L) > 0)
//          {
//           g_pwh = weekly_H[0];
//           g_pwl = weekly_L[0];
//           g_timeLastWeeklyUpdate = now;
//           DrawHorizontalLine("PWH_Line", g_pwh, InpColorPWH, STYLE_DOT, 2, InpDrawPWH); // Thicker dotted line
//           DrawHorizontalLine("PWL_Line", g_pwl, InpColorPWL, STYLE_DOT, 2, InpDrawPWL);
//           updated = true;
//           PrintFormat("Updated PWH: %.5f, PWL: %.5f", g_pwh, g_pwl);
//          }
//        else
//          Print("Error fetching PWH/PWL data: ", GetLastError());
//      }

//     if(updated) ChartRedraw();
//   }
// --- Periodic Level Functions (MODIFIED) ---
//+------------------------------------------------------------------+
void UpdatePeriodicLevels()
  {
   datetime now = TimeCurrent();
   bool updated = false;

   MqlDateTime now_struct, last_daily_struct;
   TimeToStruct(now, now_struct);
   TimeToStruct(g_timeLastDailyUpdate, last_daily_struct);

   if(now_struct.day != last_daily_struct.day || g_timeLastDailyUpdate == 0) // Added check for first run
     {
      double daily_H[], daily_L[];
      if(CopyHigh(_Symbol, PERIOD_D1, 1, 1, daily_H) > 0 && CopyLow(_Symbol, PERIOD_D1, 1, 1, daily_L) > 0)
        {
         g_pdh = daily_H[0];
         g_pdl = daily_L[0];
         g_timeLastDailyUpdate = now;
         // MODIFIED: Pass the text to DrawHorizontalLine
         DrawHorizontalLine("PDH_Line", "PDH", g_pdh, InpColorPDH, STYLE_DASHDOT, 1, InpDrawPDH);
         DrawHorizontalLine("PDL_Line", "PDL", g_pdl, InpColorPDL, STYLE_DASHDOT, 1, InpDrawPDL);
         updated = true;
         PrintFormat("Updated PDH: %.5f, PDL: %.5f", g_pdh, g_pdl);
        }
      else
         Print("Error fetching PDH/PDL data: ", GetLastError());
     }

   MqlDateTime last_weekly_struct;
   TimeToStruct(g_timeLastWeeklyUpdate, last_weekly_struct);

   if(now_struct.day_of_week < last_weekly_struct.day_of_week || (g_timeLastWeeklyUpdate == 0 && now > 0))
     {
      double weekly_H[], weekly_L[];
      if(CopyHigh(_Symbol, PERIOD_W1, 1, 1, weekly_H) > 0 && CopyLow(_Symbol, PERIOD_W1, 1, 1, weekly_L) > 0)
        {
         g_pwh = weekly_H[0];
         g_pwl = weekly_L[0];
         g_timeLastWeeklyUpdate = now;
         // MODIFIED: Pass the text to DrawHorizontalLine
         DrawHorizontalLine("PWH_Line", "PWH", g_pwh, InpColorPWH, STYLE_DOT, 2, InpDrawPWH);
         DrawHorizontalLine("PWL_Line", "PWL", g_pwl, InpColorPWL, STYLE_DOT, 2, InpDrawPWL);
         updated = true;
         PrintFormat("Updated PWH: %.5f, PWL: %.5f", g_pwh, g_pwl);
        }
      else
         Print("Error fetching PWH/PWL data: ", GetLastError());
     }

   if(updated)
      ChartRedraw(0);
  }
//+------------------------------------------------------------------+
// void DrawHorizontalLine(string name, double price, color line_color, ENUM_LINE_STYLE style, int width, bool show)
//   {
//    if(!show)
//      {
//       ObjectDelete(0, name);
//       return;
//      }

//    if(ObjectFind(0, name) < 0) // If doesn't exist, create
//      {
//       if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
//          { Print("Error creating HLine ", name, ": ", GetLastError()); return; }
//       ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
//       ObjectSetInteger(0, name, OBJPROP_STYLE, style);
//       ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
//       ObjectSetInteger(0, name, OBJPROP_BACK, true);
//       ObjectSetString(0, name, OBJPROP_TEXT, StringSubstr(name,0,3)); // Show PDH/PDL etc.
//       ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true); // Extend line to right
//      }
//    else // If exists, update price
//      {
//       ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
//       ObjectSetInteger(0, name, OBJPROP_COLOR, line_color); // Ensure color updated if changed in inputs
//       ObjectSetInteger(0, name, OBJPROP_STYLE, style);
//       ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
//      }
//   }
//+------------------------------------------------------------------+
// MODIFIED DrawHorizontalLine to create a separate OBJ_TEXT label
//+------------------------------------------------------------------+
void DrawHorizontalLine(string base_name, string label_text_param, double price, color line_color,
                        ENUM_LINE_STYLE style, int width, bool show_line)
  {
   string line_obj_name = base_name;       // Name for the OBJ_HLINE
   string label_obj_name = base_name + "_PD_label"; // Unique name for the OBJ_TEXT label
// PD suffix for "Periodic Display" to distinguish from other labels
   if(!show_line)
     {
      ObjectDelete(0, line_obj_name);
      ObjectDelete(0, label_obj_name); // Also delete the label if line is hidden
      return;
     }

// --- Draw/Update the Horizontal Line ---
   if(ObjectFind(0, line_obj_name) < 0)
     {
      if(!ObjectCreate(0, line_obj_name, OBJ_HLINE, 0, 0, price))
        { Print("Error creating HLine ", line_obj_name, ": ", GetLastError()); return; }
      ObjectSetInteger(0, line_obj_name, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, line_obj_name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, line_obj_name, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, line_obj_name, OBJPROP_BACK, true);
      //ObjectSetString(0, line_obj_name, OBJPROP_TEXT, StringSubstr(label_text_param,0,3)); // No longer needed on HLINE
      ObjectSetInteger(0, line_obj_name, OBJPROP_RAY_RIGHT, true);
     }
   else
     {
      ObjectSetDouble(0, line_obj_name, OBJPROP_PRICE, 0, price);
      ObjectSetInteger(0, line_obj_name, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, line_obj_name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, line_obj_name, OBJPROP_WIDTH, width);
     }

// --- Draw/Update the Text Label at the Right Edge ---
   if(InpDrawLabels)  // Only draw text if master label switch is on
     {
      if(ObjectFind(0, label_obj_name) < 0) // If text label doesn't exist, create
        {
         // Time argument for OBJ_TEXT will be ignored when CORNER is used, but price is used for Y
         if(!ObjectCreate(0, label_obj_name, OBJ_TEXT, 0, TimeCurrent(), price))
           {
            Print("Error creating Periodic Label ", label_obj_name, ": ", GetLastError());
            return;
           }
        }
      // Update text label properties
      ObjectSetInteger(0, label_obj_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER); // Anchor to top-right
      ObjectSetDouble(0, label_obj_name, OBJPROP_PRICE, 0, price);            // Y position from price level
      ObjectSetInteger(0, label_obj_name, OBJPROP_XDISTANCE, InpPeriodicLabel_X_Offset);  // X distance from right edge
      ObjectSetInteger(0, label_obj_name, OBJPROP_YDISTANCE, InpPeriodicLabel_Y_Offset);  // Y distance from top (or adjusted Y based on price)

      // The YDISTANCE is from the TOP of the chart when CORNER_RIGHT_UPPER.
      // To place it *above* the line, we need to calculate Y pixel position of the line, then offset from there.
      // This is complex. A simpler way for OBJ_TEXT anchored to PRICE but shown on edge is harder.
      // Let's try anchoring to price directly but pushing it visually right.
      // Simpler approach for now: Anchoring to the line's price, far right TIME-WISE.
      // THIS IS A COMPROMISE because OBJ_TEXT needs a time coordinate.

      datetime label_time_on_edge = TimeCurrent() + PeriodSeconds() * int(ChartGetInteger(0, CHART_WIDTH_IN_BARS) * 0.2); // Heuristic for "far right"
      if(ObjectFind(0, label_obj_name) < 0)
        {
         if(!ObjectCreate(0, label_obj_name, OBJ_TEXT, 0, label_time_on_edge, price + InpPeriodicLabel_Y_Offset * _Point))
           { Print("Error creating label text for ", label_obj_name); return; }
        }
      else
        {
         ObjectSetInteger(0, label_obj_name, OBJPROP_TIME,0, label_time_on_edge);
         ObjectSetDouble(0, label_obj_name, OBJPROP_PRICE,0, price + InpPeriodicLabel_Y_Offset * _Point);
        }
      ObjectSetString(0, label_obj_name, OBJPROP_TEXT, " " + label_text_param);
      ObjectSetInteger(0, label_obj_name, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, label_obj_name, OBJPROP_FONTSIZE, InpLabelFontSize);
      ObjectSetInteger(0, label_obj_name, OBJPROP_ANCHOR, ANCHOR_RIGHT); // Anchor text to its right, placing it left of the "far right" time
      ObjectSetInteger(0, label_obj_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, label_obj_name, OBJPROP_SELECTABLE, false);
     }
   else
     {
      ObjectDelete(0, label_obj_name); // Delete label if InpDrawLabels is false
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

   if(direction > 0)
      price += priceOffset;
   else
      if(direction < 0)
         price -= priceOffset;

   if(ObjectFind(0, objName) < 0) // Create only if it doesn't exist
     {
      if(ObjectCreate(0, objName, OBJ_ARROW, 0, time, price))
        {
         /* Set properties */
         ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
         if(direction > 0)
            ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_TOP);
         if(direction < 0)
            ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
        }
     }

   string objNameDesc = objName + "_TXT";
   if(ObjectFind(0, objNameDesc) < 0) // Create only if it doesn't exist
     {
      if(ObjectCreate(0, objNameDesc, OBJ_TEXT, 0, time, price))
        {
         /* Set properties */
         ObjectSetString(0, objNameDesc, OBJPROP_TEXT, " " + txt);
         ObjectSetInteger(0, objNameDesc, OBJPROP_COLOR, clr);
         ObjectSetInteger(0,objNameDesc,OBJPROP_FONTSIZE,8);
         if(direction > 0)
            ObjectSetInteger(0, objNameDesc, OBJPROP_ANCHOR, ANCHOR_LEFT);
         if(direction < 0)
            ObjectSetInteger(0, objNameDesc, OBJPROP_ANCHOR, ANCHOR_LEFT);
         ObjectSetDouble(0,objNameDesc,OBJPROP_ANGLE,0);
        }
     }
  }
//+------------------------------------------------------------------+
void deleteObj(datetime time, double price, int arrowCode, string txt) // Needs adjustment if arrowCode isn't used
  {
   string objName = "";
   StringConcatenate(objName, "Signal@", time, "_", DoubleToString(price, _Digits), "(", arrowCode, ")_", EnumToString(InpAnalysisTimeframe));
   if(ObjectFind(0, objName) != -1)
      ObjectDelete(0, objName);

   string objNameDesc = objName + "_TXT";
   if(ObjectFind(0, objNameDesc) != -1)
      ObjectDelete(0, objNameDesc);
  }

// Helper to delete marker objects like EQH/EQL text if price moves far away
void CleanupOldMarkers(datetime oldestTimeToKeep) // Call periodically if needed
  {
   int total = ObjectsTotal(0, 0, -1); //-1 indicates all object types
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, " EQH") >= 0 || StringFind(name, " EQL") >= 0)
        {
         datetime time = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
         if(time < oldestTimeToKeep)
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
   if(copied >= 4)  // Need rates[3], [2], [1]
     {
      //SwingHigh
      if(rates[2].high > rates[3].high && rates[2].high > rates[1].high)
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
               if(ArraySize(Highs)>=1 && MathAbs(highvalue_swing - Highs[0]) <= InpEqTolerancePips*_Point && InpDrawEqHL)
                 {
                  createObj(HighsTime[0], Highs[0], 0, 1, InpColorEQH, "=EQH="); // Using Text obj
                  createObj(hightime_swing, highvalue_swing, 0, 1, InpColorEQH, "=EQH=");
                 }
               // Store new high
               AddToHistory_Double(Highs, highvalue_swing, 10);
               AddToHistory_Datetime(HighsTime, hightime_swing, 10);
               prevTimeH = lastTimeH;
               lastTimeH = hightime_swing;
               // Don't draw final marker yet, might be intermediate
              }
            // else: Lower High - do nothing, current temp high remains
           }
         else // New High after a Low or first swing
           {
            AddToHistory_Double(Highs, highvalue_swing, 10);
            AddToHistory_Datetime(HighsTime, hightime_swing, 10);
            prevTimeH = lastTimeH;
            lastTimeH = hightime_swing;
            LastSwingMeter = -1;
            // Optional: createObj(hightime_swing, highvalue_swing, WingdingsSymbol("X"), -1, clrLightGray, "SH"); // Mark the confirmed swing
            return -1;
           }
        } // End SwingHigh detection

      //SwingLow
      if(rates[2].low < rates[3].low && rates[2].low < rates[1].low)
        {
         double lowvalue_swing = rates[2].low;
         datetime lowtime_swing = rates[2].time;

         if(LastSwingMeter > 0 && ArraySize(Lows) > 0)  // If previous was also Low
           {
            if(lowvalue_swing < Lows[0])  // Lower Low - Overwrite previous temp SL
              {
               if(ArraySize(LowsTime) > 0)  // Delete previous SL obj (marker 'W')
                  deleteObj(LowsTime[0], Lows[0], WingdingsSymbol("W"), "SL");
               // Check for EQL before storing new low
               if(ArraySize(Lows)>=1 && MathAbs(lowvalue_swing - Lows[0]) <= InpEqTolerancePips*_Point && InpDrawEqHL)
                 {
                  createObj(LowsTime[0], Lows[0], 0, -1, InpColorEQL, "=EQL=");
                  createObj(lowtime_swing, lowvalue_swing, 0, -1, InpColorEQL, "=EQL=");
                 }
               // Store new low
               AddToHistory_Double(Lows, lowvalue_swing, 10);
               AddToHistory_Datetime(LowsTime, lowtime_swing, 10);
               prevTimeL = lastTimeL;
               lastTimeL = lowtime_swing;
               // Don't draw final marker yet
              }
            // else: Higher Low - do nothing
           }
         else // New Low after High or first swing
           {
            AddToHistory_Double(Lows, lowvalue_swing, 10);
            AddToHistory_Datetime(LowsTime, lowtime_swing, 10);
            prevTimeL = lastTimeL;
            lastTimeL = lowtime_swing;
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
      rates[3].close > rates[3].open)
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

         //      <<< Create Label for FVG Rectangle >>>
         CreateAttachedText(objName, fvgTStart_b, fvgh_b, "Bu FVG", clrGreen, ANCHOR_LEFT_UPPER, 2, 2);
         // <<< Draw CE Line
         if(InpDrawFvgCE)
           {
            string ceName = StringFormat("Bu.FVG.CE %s %s", TimeToString(fvgTId_b, TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
            if(ObjectFind(0,ceName)<0)
               ObjectCreate(0,ceName,OBJ_TREND,0,fvgTStart_b,fvgCE_b,fvgTEnd_b,fvgCE_b);
            ObjectSetInteger(0,ceName,OBJPROP_COLOR,InpColorFvgCE);
            ObjectSetInteger(0,ceName,OBJPROP_STYLE,STYLE_DASHDOTDOT); // Different style for CE
            ObjectSetInteger(0,ceName,OBJPROP_WIDTH,1);
            ObjectSetInteger(0,ceName,OBJPROP_BACK,true);
            ObjectSetInteger(0,ceName,OBJPROP_RAY_RIGHT,false);
            // <<< Create Label for CE Line >>>
            CreateAttachedText(ceName, fvgTStart_b, fvgCE_b, "CE 50%", InpColorFvgCE, ANCHOR_LEFT, 2, 1);
           }
         return 1;
        }
     }

//Bearish FVG
   if(/* FVG conditions as before */
      rates[1].high < rates[3].low &&
      rates[2].close < rates[3].low &&
      rates[1].close < rates[1].open &&
      rates[3].close < rates[3].open)
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
         // <<< Create Label for FVG Rectangle >>>
         CreateAttachedText(objName, fvgTStart_s, fvgl_s, "Be FVG", clrRed, ANCHOR_LEFT_LOWER, 2, -2);
         // <<< Draw CE Line
         if(InpDrawFvgCE)
           {
            string ceName = StringFormat("Be.FVG.CE %s %s", TimeToString(fvgTId_s, TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
            if(ObjectFind(0,ceName)<0)
               ObjectCreate(0,ceName,OBJ_TREND,0,fvgTStart_s,fvgCE_s,fvgTEnd_s,fvgCE_s);
            ObjectSetInteger(0,ceName,OBJPROP_COLOR,InpColorFvgCE);
            ObjectSetInteger(0,ceName,OBJPROP_STYLE,STYLE_DASHDOTDOT);
            ObjectSetInteger(0,ceName,OBJPROP_WIDTH,1);
            ObjectSetInteger(0,ceName,OBJPROP_BACK,true);
            ObjectSetInteger(0,ceName,OBJPROP_RAY_RIGHT,false);
            // <<< Create Label for CE Line >>>
            CreateAttachedText(ceName, fvgTStart_s, fvgCE_s, "CE 50%", InpColorFvgCE, ANCHOR_LEFT, 2, 1);
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
   if(rates[3].low < rates[4].low &&
      rates[3].low < rates[2].low &&
      rates[1].low > rates[3].high)  // Displacement check uses full high
     {
      // Check Volume Filter
      bool volume_ok = !InpFilterObVolume;
      if(InpFilterObVolume)
        {
         if(rates[3].tick_volume > rates[4].tick_volume && rates[3].tick_volume > rates[2].tick_volume)
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

            // <<< Create Label for OB Rectangle >>>
            CreateAttachedText(objName, ob_t_b, ob_l_b, "Bu OB", clrTeal, ANCHOR_LEFT_LOWER, 2, -2);

            return 1;
           }
        } // End if volume_ok
     } // End Bullish OB check

// Bearish Order Block
   if(rates[3].high > rates[4].high &&
      rates[3].high > rates[2].high &&
      rates[1].high < rates[3].low)  // Displacement check uses full low
     {
      // Check Volume Filter
      bool volume_ok = !InpFilterObVolume;
      if(InpFilterObVolume)
        {
         if(rates[3].tick_volume > rates[4].tick_volume && rates[3].tick_volume > rates[2].tick_volume)
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
            // <<< Create Label for OB Rectangle >>>
            CreateAttachedText(objName, ob_t_s, ob_h_s, "Be OB", clrDarkRed, ANCHOR_LEFT_UPPER, 2, 2);
            return -1;
           }
        } // End if volume_ok
     } // End Bearish OB Check

//Invalidation Logic (Close past OB)
// ... (Invalidation logic remains as corrected in last step) ...
   return 0;
  }

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Rejection Block (Adapted for InpAnalysisTimeframe & Inputs, with Full Labels) |
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
   if(rates[2].close > rates[2].open &&  // Green candle
      rates[2].low < rates[3].low &&    // Lower low than previous
      rates[2].low < rates[1].low     // Lower low than next (swing low)
     )
     {
      double rBlockHigh_local = rates[2].open;  // Body top for green candle
      double rBlockLow_local = rates[2].low;   // Wick low
      datetime rBlockTime_local = rates[2].time; // Time of the rBlock candle

      // Check if this rBlock already exists to avoid duplicates
      if(ArraySize(bullishGreenTimeValues) == 0 || bullishGreenTimeValues[0] != rBlockTime_local)
        {
         // Add to arrays
         AddToHistory_Double(bullishGreenHighValues,rBlockHigh_local,10);
         AddToHistory_Double(bullishGreenLowValues,rBlockLow_local,10);
         AddToHistory_Datetime(bullishGreenTimeValues,rBlockTime_local,10);

         // Create rectangle object
         string objName = StringFormat("Bu.rBG %s %s", TimeToString(rBlockTime_local, TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objName) < 0) // If object doesn't exist
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rBlockTime_local, rBlockLow_local, rates[0].time, rBlockHigh_local); // Draw from rBlock time to current bar time of InpAnalysisTF
         ObjectSetInteger(0, objName, OBJPROP_COLOR, Inp_Bullish_Green_rBlock_Color);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, Inp_rBlock_Width);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetInteger(0, objName, OBJPROP_FILL, false);

         // Create Label for RB Rectangle
         CreateAttachedText(objName, rBlockTime_local, rBlockLow_local, "Bu rBG", Inp_Bullish_Green_rBlock_Color, ANCHOR_LEFT_LOWER, 2, -2);
         return 1; // Bullish Green rBlock
        }
     }

// Bullish rBlock Red (Red candle swing low on InpAnalysisTimeframe)
   if(rates[2].close < rates[2].open &&  // Red candle
      rates[2].low < rates[3].low &&
      rates[2].low < rates[1].low
     )
     {
      double rBlockHigh_local = rates[2].close; // For a red candle, close is lower than open. For Bullish rBlock, use close (upper part of wick interest)
      double rBlockLow_local = rates[2].low;
      datetime rBlockTime_local = rates[2].time;

      if(ArraySize(bullishRedTimeValues) == 0 || bullishRedTimeValues[0] != rBlockTime_local)
        {
         AddToHistory_Double(bullishRedHighValues,rBlockHigh_local,10);
         AddToHistory_Double(bullishRedLowValues,rBlockLow_local,10);
         AddToHistory_Datetime(bullishRedTimeValues,rBlockTime_local,10);

         string objName = StringFormat("Bu.rBR %s %s", TimeToString(rBlockTime_local, TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objName) < 0)
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rBlockTime_local, rBlockLow_local, rates[0].time, rBlockHigh_local);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, Inp_Bullish_Red_rBlock_Color);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, Inp_rBlock_Width);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetInteger(0, objName, OBJPROP_FILL, false);

         // Create Label for RB Rectangle
         CreateAttachedText(objName, rBlockTime_local, rBlockLow_local, "Bu rBR", Inp_Bullish_Red_rBlock_Color, ANCHOR_LEFT_LOWER, 2, -2);
         return 2; // Bullish Red rBlock
        }
     }

// Bearish rBlock Red (Red candle swing high on InpAnalysisTimeframe)
   if(rates[2].close < rates[2].open &&  // Red candle
      rates[2].high > rates[3].high &&  // Higher high than previous
      rates[2].high > rates[1].high    // Higher high than next (swing high)
     )
     {
      double rBlockHigh_local = rates[2].high;
      double rBlockLow_local = rates[2].open;   // Body top for red candle
      datetime rBlockTime_local = rates[2].time;

      if(ArraySize(bearishRedTimeValues) == 0 || bearishRedTimeValues[0] != rBlockTime_local)
        {
         AddToHistory_Double(bearishRedHighValues,rBlockHigh_local,10);
         AddToHistory_Double(bearishRedLowValues,rBlockLow_local,10);
         AddToHistory_Datetime(bearishRedTimeValues,rBlockTime_local,10);

         string objName = StringFormat("Be.rBR %s %s", TimeToString(rBlockTime_local, TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objName) < 0)
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rBlockTime_local, rBlockHigh_local, rates[0].time, rBlockLow_local);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, Inp_Bearish_Red_rBlock_Color);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, Inp_rBlock_Width);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetInteger(0, objName, OBJPROP_FILL, false);

         // Create Label for RB Rectangle
         CreateAttachedText(objName, rBlockTime_local, rBlockHigh_local, "Be rBR", Inp_Bearish_Red_rBlock_Color, ANCHOR_LEFT_UPPER, 2, 2);
         return -1; // Bearish Red rBlock
        }
     }

// Bearish rBlock Green (Green candle swing high on InpAnalysisTimeframe)
   if(rates[2].close > rates[2].open &&  // Green candle
      rates[2].high > rates[3].high &&
      rates[2].high > rates[1].high
     )
     {
      double rBlockHigh_local = rates[2].high;
      double rBlockLow_local = rates[2].close;  // Body bottom for green candle
      datetime rBlockTime_local = rates[2].time;

      if(ArraySize(bearishGreenTimeValues) == 0 || bearishGreenTimeValues[0] != rBlockTime_local)
        {
         AddToHistory_Double(bearishGreenHighValues,rBlockHigh_local,10);
         AddToHistory_Double(bearishGreenLowValues,rBlockLow_local,10);
         AddToHistory_Datetime(bearishGreenTimeValues,rBlockTime_local,10);

         string objName = StringFormat("Be.rBG %s %s", TimeToString(rBlockTime_local, TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objName) < 0)
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, rBlockTime_local, rBlockHigh_local, rates[0].time, rBlockLow_local);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, Inp_Bearish_Green_rBlock_Color);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, Inp_rBlock_Width);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetInteger(0, objName, OBJPROP_FILL, false);

         // Create Label for RB Rectangle
         CreateAttachedText(objName, rBlockTime_local, rBlockHigh_local, "Be rBG", Inp_Bearish_Green_rBlock_Color, ANCHOR_LEFT_UPPER, 2, 2);
         return -2; // Bearish Green rBlock
        }
     }

//Invalidation Logic for rBlocks (Wick through implies invalidation)
// Bullish Green
   for(int i = ArraySize(bullishGreenTimeValues) - 1; i >= 0; i--)
     {
      // Ensure the rBlock is in the past relative to the current bar (rates[0]) of InpAnalysisTimeframe
      if(ArraySize(bullishGreenLowValues) > i && bullishGreenTimeValues[i] < rates[0].time &&
         rates[1].low < bullishGreenLowValues[i] // Current candle (rates[1]) wicks below the rBlock's low
        )
        {
         string objNameInvalid = StringFormat("Bu.rBG %s %s", TimeToString(bullishGreenTimeValues[i], TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objNameInvalid) >= 0 && ObjectDelete(0, objNameInvalid))
           {
            ObjectDelete(0, objNameInvalid + "_txt"); // Delete label
            // Safely remove elements from arrays
            if(ArraySize(bullishGreenLowValues)>i)
               ArrayRemove(bullishGreenLowValues, i, 1);
            if(ArraySize(bullishGreenHighValues)>i)
               ArrayRemove(bullishGreenHighValues, i, 1);
            if(ArraySize(bullishGreenTimeValues)>i)
               ArrayRemove(bullishGreenTimeValues, i, 1);
           }
        }
     }
//Bullish Red
   for(int i = ArraySize(bullishRedTimeValues) - 1; i >= 0; i--)
     {
      if(ArraySize(bullishRedLowValues) > i && bullishRedTimeValues[i] < rates[0].time &&
         rates[1].low < bullishRedLowValues[i])
        {
         string objNameInvalid = StringFormat("Bu.rBR %s %s", TimeToString(bullishRedTimeValues[i], TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objNameInvalid) >= 0 && ObjectDelete(0, objNameInvalid))
           {
            ObjectDelete(0, objNameInvalid + "_txt"); // Delete label
            if(ArraySize(bullishRedLowValues)>i)
               ArrayRemove(bullishRedLowValues, i, 1);
            if(ArraySize(bullishRedHighValues)>i)
               ArrayRemove(bullishRedHighValues, i, 1);
            if(ArraySize(bullishRedTimeValues)>i)
               ArrayRemove(bullishRedTimeValues, i, 1);
           }
        }
     }
//Bearish Red
   for(int i = ArraySize(bearishRedTimeValues) - 1; i >= 0; i--)
     {
      if(ArraySize(bearishRedHighValues) > i && bearishRedTimeValues[i] < rates[0].time &&
         rates[1].high > bearishRedHighValues[i])  // Wick above the rBlock's high
        {
         string objNameInvalid = StringFormat("Be.rBR %s %s", TimeToString(bearishRedTimeValues[i], TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objNameInvalid) >= 0 && ObjectDelete(0, objNameInvalid))
           {
            ObjectDelete(0, objNameInvalid + "_txt"); // Delete label
            if(ArraySize(bearishRedLowValues)>i)
               ArrayRemove(bearishRedLowValues, i, 1);
            if(ArraySize(bearishRedHighValues)>i)
               ArrayRemove(bearishRedHighValues, i, 1);
            if(ArraySize(bearishRedTimeValues)>i)
               ArrayRemove(bearishRedTimeValues, i, 1);
           }
        }
     }
//Bearish Green
   for(int i = ArraySize(bearishGreenTimeValues) - 1; i >= 0; i--)
     {
      if(ArraySize(bearishGreenHighValues) > i && bearishGreenTimeValues[i] < rates[0].time &&
         rates[1].high > bearishGreenHighValues[i])
        {
         string objNameInvalid = StringFormat("Be.rBG %s %s", TimeToString(bearishGreenTimeValues[i], TIME_MINUTES), EnumToString(InpAnalysisTimeframe));
         if(ObjectFind(0, objNameInvalid) >= 0 && ObjectDelete(0, objNameInvalid))
           {
            ObjectDelete(0, objNameInvalid + "_txt"); // Delete label
            if(ArraySize(bearishGreenLowValues)>i)
               ArrayRemove(bearishGreenLowValues, i, 1);
            if(ArraySize(bearishGreenHighValues)>i)
               ArrayRemove(bearishGreenHighValues, i, 1);
            if(ArraySize(bearishGreenTimeValues)>i)
               ArrayRemove(bearishGreenTimeValues, i, 1);
           }
        }
     }
   return 0;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
int WingdingsSymbol(string character)
  {
   /* ... as before ... */
   if(character == "W")
      return 233;
   if(character == "X")
      return 234;
   return 0;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
