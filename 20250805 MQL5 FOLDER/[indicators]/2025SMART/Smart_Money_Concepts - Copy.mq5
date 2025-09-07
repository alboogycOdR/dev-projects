#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   0

#include <Trade/Trade.mqh>

enum Modes
{
    Historical,
    Present
};

enum Styles
{
    Colored,
    Monochrome
};

// --- Inputs
// General
input Modes  mode = Historical;
input Styles style = Colored;
input bool   show_trend = false;

// Internal Structure
input bool  show_internals = true;
input string show_ibull_str = "All"; // "All", "BOS", "CHoCH"
input color swing_ibull_css = C'8,153,129';
input string show_ibear_str = "All"; // "All", "BOS", "CHoCH"
input color swing_ibear_css = C'242,54,69';
input bool  ifilter_confluence = false;
input int   internal_structure_size = 8; // Font size

// Swing Structure
input bool  show_Structure = true;
input string show_bull_str = "All"; // "All", "BOS", "CHoCH"
input color swing_bull_css = C'8,153,129';
input string show_bear_str = "All"; // "All", "BOS", "CHoCH"
input color swing_bear_css = C'242,54,69';
input int   swing_structure_size = 10; // Font size
input bool  show_swings = false;
input int   length = 50;
input bool  show_hl_swings = true;

// Order Blocks
input bool  show_iob = true;
input int   iob_showlast = 5;
input bool  show_ob = false;
input int   ob_showlast = 5;
input color ibull_ob_css = C'49,121,245'; // Alpha component removed – MQL5 C color constant supports only RGB
input color ibear_ob_css = C'247,124,128'; // Alpha component removed
input color bull_ob_css = C'24,72,204';   // Alpha component removed
input color bear_ob_css = C'178,40,51';   // Alpha component removed

// EQH/EQL
input bool   show_eq = true;
input int    eq_len = 3;
input double eq_threshold = 0.1; // Multiplier for ATR
input int    eq_size = 8; // Font size

// --- Global Variables & Buffers ---
double ExtDummyBuffer[];
int    ExtAtrHandle;

// Structure & Trend
static int    trend = 0, itrend = 0;
static double top_y = 0, btm_y = 0, itop_y = 0, ibtm_y = 0;
static int    top_x = 0, btm_x = 0, itop_x = 0, ibtm_x = 0;
static bool   top_cross = true, btm_cross = true, itop_cross = true, ibtm_cross = true;

// Order Block Arrays (Dynamic)
static double iob_top[], iob_btm[];
static long   iob_left[];
static int    iob_type[];

static double ob_top[], ob_btm[];
static long   ob_left[];
static int    ob_type[];

// EQH/EQL state
static double eq_prev_top = 0;
static int    eq_top_x = 0;
static double eq_prev_btm = 0;
static int    eq_btm_x = 0;

// Helper to get Pivot Highs (returns price or 0)
double PivotHigh(const double &high[], int left, int right, int shift)
{
    // Check if we have enough bars for the calculation
    if(shift < 0 || shift >= ArraySize(high) || shift + left + right >= ArraySize(high))
        return 0;
        
    double pivot = high[shift + right];
    for(int i = 0; i <= left + right; i++)
    {
        if(i == right) continue;
        if(shift + i >= ArraySize(high) || high[shift + i] > pivot)
            return 0;
    }
    return pivot;
}

// Helper to get Pivot Lows (returns price or 0)
double PivotLow(const double &low[], int left, int right, int shift)
{
    // Check if we have enough bars for the calculation
    if(shift < 0 || shift >= ArraySize(low) || shift + left + right >= ArraySize(low))
        return 0;
        
    double pivot = low[shift + right];
    for(int i = 0; i <= left + right; i++)
    {
        if(i == right) continue;
        if(shift + i >= ArraySize(low) || low[shift + i] < pivot)
            return 0;
    }
    return pivot;
}

// Structure drawing function
void display_Structure(int x, double y, string txt, color css, bool dashed, bool down, int lbl_size, const datetime &time[])
{
    if(mode == Present) return;

    string lineName = "StructureLine_" + TimeToString(time[x]);
    string labelName = "StructureLabel_" + TimeToString(time[x]);
    
    ObjectCreate(0, lineName, OBJ_TREND, 0, time[x], y, time[0], y);
    ObjectSetInteger(0, lineName, OBJPROP_STYLE, dashed ? STYLE_DASH : STYLE_SOLID);
    ObjectSetInteger(0, lineName, OBJPROP_COLOR, css);
    ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
    
    ObjectCreate(0, labelName, OBJ_TEXT, 0, time[x], y);
    ObjectSetString(0, labelName, OBJPROP_TEXT, txt);
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, css);
    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, lbl_size);
    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, down ? ANCHOR_TOP : ANCHOR_BOTTOM);
    ObjectSetInteger(0, labelName, OBJPROP_TIME, time[x]);
    ObjectSetDouble(0, labelName, OBJPROP_PRICE, y);
}

// Utility helpers to push a value to the front of a dynamic array -----------------------------------
void PushFrontDouble(double &arr[], double val)
{
   int sz = ArraySize(arr);
   ArrayResize(arr, sz + 1);
   for(int j = sz; j > 0; j--)
       arr[j] = arr[j - 1];
   arr[0] = val;
}

void PushFrontLong(long &arr[], long val)
{
   int sz = ArraySize(arr);
   ArrayResize(arr, sz + 1);
   for(int j = sz; j > 0; j--)
       arr[j] = arr[j - 1];
   arr[0] = val;
}

void PushFrontInt(int &arr[], int val)
{
   int sz = ArraySize(arr);
   ArrayResize(arr, sz + 1);
   for(int j = sz; j > 0; j--)
       arr[j] = arr[j - 1];
   arr[0] = val;
}
// -----------------------------------------------------------------------------------------------
void capture_ob_coord(bool isBearish, int bar_idx, const double &high[], const double &low[], const datetime &time[], int totalBars)
{
   double ob_high = high[bar_idx + 1];
   double ob_low  = low[bar_idx + 1];
   datetime ob_time = time[bar_idx + 1];

   if(isBearish) // looking for an up candle before the down move
   {
      for(int i = bar_idx + 1; i < bar_idx + 5 && i < totalBars - 1; i++)
      {
         if(low[i] > ob_high) break; // candle must be part of the move
         if(high[i] - low[i] > (high[i-1] - low[i-1]))
         {
            ob_high = high[i];
            ob_low  = low[i];
            ob_time = time[i];
         }
      }
      PushFrontDouble(ob_top,  ob_high);
      PushFrontDouble(ob_btm,  ob_low);
      PushFrontLong  (ob_left, (long)ob_time);
      PushFrontInt   (ob_type, -1);
   }
   else // bullish, looking for a down candle before the up move
   {
      for(int i = bar_idx + 1; i < bar_idx + 5 && i < totalBars - 1; i++)
      {
          if(high[i] < ob_low) break;
          if(high[i] - low[i] > (high[i-1] - low[i-1]))
          {
             ob_high = high[i];
             ob_low  = low[i];
             ob_time = time[i];
          }
      }
      PushFrontDouble(iob_top,  ob_high);
      PushFrontDouble(iob_btm,  ob_low);
      PushFrontLong  (iob_left, (long)ob_time);
      PushFrontInt   (iob_type, 1);
   }
}

// Function to display Order Blocks
void display_ob(int show_last, bool is_swing, const datetime &time[])
{
   int size = is_swing ? ArraySize(ob_type) : ArraySize(iob_type);
   string prefix = is_swing ? "SwingOB_" : "InternalOB_";

   for(int i = 0; i < show_last; i++)
   {
       if(i >= size)
       {
           ObjectDelete(0, prefix + IntegerToString(i));
           continue;
       }

       double top      = is_swing ? ob_top[i]   : iob_top[i];
       double bottom   = is_swing ? ob_btm[i]   : iob_btm[i];
       datetime leftTs = (datetime)(is_swing ? ob_left[i] : iob_left[i]);
       int    typ      = is_swing ? ob_type[i]  : iob_type[i];

       color css;
       if(style == Monochrome)
           css = (typ == 1 ? C'178,181,190' : C'93,96,107');
       else
           css = is_swing ? (typ == 1 ? bull_ob_css : bear_ob_css)
                           : (typ == 1 ? ibull_ob_css : ibear_ob_css);

       string boxName = prefix + IntegerToString(i);

       if(ObjectFind(0, boxName) < 0)
           ObjectCreate(0, boxName, OBJ_RECTANGLE_LABEL, 0, leftTs, top);

       ObjectSetInteger(0, boxName, OBJPROP_TIME, 1, time[0]);
       ObjectSetDouble(0, boxName, OBJPROP_PRICE, 1, bottom);
       ObjectSetInteger(0, boxName, OBJPROP_COLOR, css);
       ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
       ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
       ObjectSetInteger(0, boxName, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
    SetIndexBuffer(0, ExtDummyBuffer, INDICATOR_DATA);
    ExtAtrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    
    // Clear old objects on initialization
    ObjectsDeleteAll(0, 0, -1, "StructureLine_");
    ObjectsDeleteAll(0, 0, -1, "StructureLabel_");
    ObjectsDeleteAll(0, 0, -1, "SwingOB_");
    ObjectsDeleteAll(0, 0, -1, "InternalOB_");
    ObjectsDeleteAll(0, 0, -1, "EQH_");
    ObjectsDeleteAll(0, 0, -1, "EQL_");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clear objects on deinitialization
    ObjectsDeleteAll(0, 0, -1, "StructureLine_");
    ObjectsDeleteAll(0, 0, -1, "StructureLabel_");
    ObjectsDeleteAll(0, 0, -1, "SwingOB_");
    ObjectsDeleteAll(0, 0, -1, "InternalOB_");
    ObjectsDeleteAll(0, 0, -1, "EQH_");
    ObjectsDeleteAll(0, 0, -1, "EQL_");
}
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
    int start = prev_calculated > 1 ? prev_calculated - 1 : 1;
    if (start >= rates_total) start = rates_total - 2;

    for(int i = start; i >= 0; i--)
    {
        // Swing detection
        double pivot_h = PivotHigh(high, length/2, length/2, i);
        double pivot_l = PivotLow(low, length/2, length/2, i);

        // Internal Swing detection
        int iLen = 5;
        double ipivot_h = PivotHigh(high, iLen, iLen, i);
        double ipivot_l = PivotLow(low, iLen, iLen, i);
        
        // --- Swing High Logic ---
        if(pivot_h > 0 && pivot_h > top_y)
        {
           top_cross = true;
           top_y = pivot_h;
           top_x = i + length / 2;
        }

        // --- Internal Swing High Logic ---
        if(ipivot_h > 0 && ipivot_h > itop_y)
        {
           itop_cross = true;
           itop_y = ipivot_h;
           itop_x = i + iLen;
        }

        // --- Swing Low Logic ---
        if(pivot_l > 0 && (btm_y == 0 || pivot_l < btm_y))
        {
            btm_cross = true;
            btm_y = pivot_l;
            btm_x = i + length / 2;
        }

        // --- Internal Swing Low Logic ---
        if(ipivot_l > 0 && (ibtm_y == 0 || ipivot_l < ibtm_y))
        {
            ibtm_cross = true;
            ibtm_y = ipivot_l;
            ibtm_x = i + iLen;
        }

        color bull_css = style == Monochrome ? C'178,181,190' : swing_bull_css;
        color bear_css = style == Monochrome ? C'178,181,190' : swing_bear_css;
        color ibull_css = style == Monochrome ? C'178,181,190' : swing_ibull_css;
        color ibear_css = style == Monochrome ? C'178,181,190' : swing_ibear_css;

        // --- Bullish Structure Breaks ---
        if(close[i] > itop_y && itop_cross && itop_y > 0)
        {
           bool choch = (itrend < 0);
           string txt = choch ? "i-CHoCH" : "i-BOS";
           if(show_internals && (show_ibull_str == "All" || (show_ibull_str == "BOS" && !choch) || (show_ibull_str == "CHoCH" && choch)))
              display_Structure(itop_x, itop_y, txt, ibull_css, true, true, internal_structure_size, time);
           itop_cross = false;
           itrend = 1;
           if(show_iob) capture_ob_coord(false, itop_x, high, low, time, rates_total);
        }
        
        if(close[i] > top_y && top_cross && top_y > 0)
        {
           bool choch = (trend < 0);
           string txt = choch ? "CHoCH" : "BOS";
           if(show_Structure && (show_bull_str == "All" || (show_bull_str == "BOS" && !choch) || (show_bull_str == "CHoCH" && choch)))
               display_Structure(top_x, top_y, txt, bull_css, false, true, swing_structure_size, time);
           top_cross = false;
           trend = 1;
           if(show_ob) capture_ob_coord(false, top_x, high, low, time, rates_total);
        }
        
        // --- Bearish Structure Breaks ---
        if(close[i] < ibtm_y && ibtm_cross && ibtm_y > 0)
        {
            bool choch = (itrend > 0);
            string txt = choch ? "i-CHoCH" : "i-BOS";
            if(show_internals && (show_ibear_str == "All" || (show_ibear_str == "BOS" && !choch) || (show_ibear_str == "CHoCH" && choch)))
               display_Structure(ibtm_x, ibtm_y, txt, ibear_css, true, false, internal_structure_size, time);
            ibtm_cross = false;
            itrend = -1;
            if(show_iob) capture_ob_coord(true, ibtm_x, high, low, time, rates_total);
        }
        
        if(close[i] < btm_y && btm_cross && btm_y > 0)
        {
            bool choch = (trend > 0);
            string txt = choch ? "CHoCH" : "BOS";
            if(show_Structure && (show_bear_str == "All" || (show_bear_str == "BOS" && !choch) || (show_bear_str == "CHoCH" && choch)))
                display_Structure(btm_x, btm_y, txt, bear_css, false, false, swing_structure_size, time);
            btm_cross = false;
            trend = -1;
            if(show_ob) capture_ob_coord(true, btm_x, high, low, time, rates_total);
        }
        
        // --- Order Block Mitigation ---
        for(int k = ArraySize(iob_type) - 1; k >= 0; k--) {
            if((iob_type[k] == 1 && low[i] < iob_btm[k]) || (iob_type[k] == -1 && high[i] > iob_top[k])){
                ArrayRemove(iob_top, k, 1);
                ArrayRemove(iob_btm, k, 1);
                ArrayRemove(iob_left, k, 1);
                ArrayRemove(iob_type, k, 1);
            }
        }
        for(int k = ArraySize(ob_type) - 1; k >= 0; k--) {
            if((ob_type[k] == 1 && low[i] < ob_btm[k]) || (ob_type[k] == -1 && high[i] > ob_top[k])){
                ArrayRemove(ob_top, k, 1);
                ArrayRemove(ob_btm, k, 1);
                ArrayRemove(ob_left, k, 1);
                ArrayRemove(ob_type, k, 1);
            }
        }
        
        // --- EQH/EQL Logic ---
        if(show_eq) {
            double eq_h = PivotHigh(high, eq_len, eq_len, i);
            if(eq_h > 0) {
               if(eq_prev_top > 0) {
                  double atr_val[1];
                  CopyBuffer(ExtAtrHandle, 0, i, 1, atr_val);
                  double max_h = MathMax(eq_h, eq_prev_top);
                  double min_h = MathMin(eq_h, eq_prev_top);

                  if (max_h < min_h + atr_val[0] * eq_threshold) {
                      string lineName = "EQH_Line_" + TimeToString(time[i + eq_len]);
                      string labelName = "EQH_Label_" + TimeToString(time[i + eq_len]);
                      ObjectCreate(0, lineName, OBJ_TREND, 0, time[eq_top_x], eq_prev_top, time[i + eq_len], eq_h);
                      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
                      ObjectSetInteger(0, lineName, OBJPROP_COLOR, bear_css);

                      ObjectCreate(0, labelName, OBJ_TEXT, 0, time[(eq_top_x + i + eq_len)/2], max_h, "EQH");
                      ObjectSetInteger(0, labelName, OBJPROP_COLOR, bear_css);
                      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, eq_size);
                  }
               }
               eq_prev_top = eq_h;
               eq_top_x = i + eq_len;
            }

            double eq_l = PivotLow(low, eq_len, eq_len, i);
            if(eq_l > 0) {
                if(eq_prev_btm > 0) {
                  double atr_val[1];
                  CopyBuffer(ExtAtrHandle, 0, i, 1, atr_val);
                  double max_l = MathMax(eq_l, eq_prev_btm);
                  double min_l = MathMin(eq_l, eq_prev_btm);
                  if (min_l > max_l - atr_val[0] * eq_threshold) {
                      string lineName = "EQL_Line_" + TimeToString(time[i + eq_len]);
                      string labelName = "EQL_Label_" + TimeToString(time[i + eq_len]);
                      ObjectCreate(0, lineName, OBJ_TREND, 0, time[eq_btm_x], eq_prev_btm, time[i + eq_len], eq_l);
                      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
                      ObjectSetInteger(0, lineName, OBJPROP_COLOR, bull_css);

                      ObjectCreate(0, labelName, OBJ_TEXT, 0, time[(eq_btm_x + i + eq_len)/2], min_l, "EQL");
                      ObjectSetInteger(0, labelName, OBJPROP_COLOR, bull_css);
                      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_TOP);
                      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, eq_size);
                  }
                }
               eq_prev_btm = eq_l;
               eq_btm_x = i + eq_len;
            }
        }
    }

    // --- Last Bar Updates (drawing recent objects) ---
    if(show_iob) {
       display_ob(iob_showlast, false, time);
    }
    if(show_ob) {
       display_ob(ob_showlast, true, time);
    }

    return(rates_total);
}
 