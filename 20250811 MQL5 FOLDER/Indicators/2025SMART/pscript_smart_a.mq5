#property copyright "LuxAlgo, Converted by AI"
#property link      "https://www.tradingview.com/script/jUmWRlHZ-Smart-Money-Concepts-LuxAlgo/"
#property version   "1.00"

// Structure declarations needed for OnCalculate
struct PivotStruct
{
    double currentLevel;
    double lastLevel;
    bool crossed;
    datetime barTime;   // Pine int to datetime
    int barIndex;       // MQL5 index

    void Init()
    {
        currentLevel = 0; lastLevel = 0; // Pine 'na' can be 0 or DBL_MAX etc. for price
        crossed = false;
        barTime = 0;
        barIndex = -1; // Represents invalid/uninitialized MQL5 index
    }
};

// --- Custom Enums ---
enum ENUM_FONT_SIZE
{
    FONT_SIZE_XSMALL = 8,
    FONT_SIZE_SMALL = 10,
    FONT_SIZE_MEDIUM = 12,
    FONT_SIZE_LARGE = 14,
    FONT_SIZE_XLARGE = 16
};

// Forward declarations
struct MQL_SERIES_INFO;
struct AlertsStruct;

void MQL_DisplayStructure(int bar_idx, bool is_internal, const MQL_SERIES_INFO& series_info, int rates_total, AlertsStruct &alerts);
void MQL_DrawFairValueGaps(int bar_idx, const MQL_SERIES_INFO& series_info, ENUM_TIMEFRAMES fvg_tf, AlertsStruct &alerts);
void MQL_DeleteFairValueGaps(const MQL_SERIES_INFO& series_info, int bar_idx);
void MQL_DrawStructure(PivotStruct &pivot_to_draw, string tag, color structureColor, int lineStyleMQL, string labelStylePine, ENUM_FONT_SIZE labelSize, datetime currentTime, int currentBarIndexMQL, bool is_present_mode);

// Plot definitions
#property indicator_chart_window
#property indicator_buffers 5 // For colored candles (Open, High, Low, Close, ColorIndex)
#property indicator_plots   1

// Plot1: Colored Candles (if enabled)
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrGreen, clrRed, clrGray // Default colors for candles; can be set by inputs later
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

// Constants & Definitions
#define BULLISH_LEG                     1
#define BEARISH_LEG                     0

#define BULLISH_MQL                     +1 // Pine BULLISH = +1
#define BEARISH_MQL                     -1 // Pine BEARISH = -1

#define HISTORICAL                      "Historical"
#define PRESENT                         "Present"

#define COLORED                         "Colored"
#define MONOCHROME                      "Monochrome"

#define ALL_FILTER                      "All"
#define BOS_FILTER                      "BOS"
#define CHOCH_FILTER                    "CHoCH"

#define ATR_FILTER                      "Atr"
#define RANGE_FILTER                    "Cumulative Mean Range"

#define CLOSE_MITIGATION                "Close"
#define HIGHLOW_MITIGATION              "High/Low"

#define SOLID_STYLE_STR                 "SOLID" // Pine "⎯⎯⎯"
#define DASHED_STYLE_STR                "DASHED" // Pine "----"
#define DOTTED_STYLE_STR                "DOTTED" // Pine "····"

// --- Color Constants (Must be before inputs/functions using them) ---
#define MONO_BULLISH_COLOR C'178,181,190' // #b2b5be
#define MONO_BEARISH_COLOR C'93,96,107'   // #5d606b

//input color   InpFVGBullColor      = C'0,255,104,178';    // Used in OnInit
input color   InpFVGBearishColor   = C'255,0,8,178';      // Added for bearish FVG

// --- Alert Structure ---
struct AlertsStruct
{
    bool internalBullishBOS;
    bool internalBearishBOS;
    bool internalBullishCHoCH;
    bool internalBearishCHoCH;
    bool swingBullishBOS;
    bool swingBearishBOS;
    bool swingBullishCHoCH;
    bool swingBearishCHoCH;
    bool internalBullishOrderBlock;
    bool internalBearishOrderBlock;
    bool swingBullishOrderBlock;
    bool swingBearishOrderBlock;
    bool equalHighs;
    bool equalLows;
    bool bullishFairValueGap;
    bool bearishFairValueGap;
    void Init() { 
        internalBullishBOS = false; internalBearishBOS = false; internalBullishCHoCH = false; internalBearishCHoCH = false;
        swingBullishBOS = false; swingBearishBOS = false; swingBullishCHoCH = false; swingBearishCHoCH = false;
        internalBullishOrderBlock = false; internalBearishOrderBlock = false; swingBullishOrderBlock = false; swingBearishOrderBlock = false;
        equalHighs = false; equalLows = false; bullishFairValueGap = false; bearishFairValueGap = false;
    }
};

// --- Series Info Structure ---
// Dummy MQL_SERIES_INFO structure to pass price data around easier
struct MQL_SERIES_INFO {
    datetime time[];  // Changed back to dynamic arrays
    double   open[];  // Changed back to dynamic arrays
    double   high[];  // Changed back to dynamic arrays
    double   low[];   // Changed back to dynamic arrays
    double   close[]; // Changed back to dynamic arrays
    int             rates_total;
    
    // Helper to map Pine's bar_index (0=oldest) to MQL5 shift (0=current)
    int map_pine_idx_to_mql_shift(int pine_bar_idx) const {
        if (pine_bar_idx < 0 || pine_bar_idx >= rates_total) return -1; // Invalid
        return rates_total - 1 - pine_bar_idx;
    }
};


struct TrendStruct
{
    int bias;           // BULLISH_MQL or BEARISH_MQL
    void Init() { bias = 0; }
};

struct TrailingExtremesStruct
{
    double top;
    double bottom;
    datetime barTime;   // Pine int to datetime
    int barIndex;       // MQL5 index (0 is current, RatesTotal-1 is oldest)
    datetime lastTopTime;
    datetime lastBottomTime;

    void Init()
    {
        top = 0; bottom = 0;
        barTime = 0; barIndex = -1;
        lastTopTime = 0; lastBottomTime = 0;
    }
};

struct EqualDisplayStruct
{
    string lineName;    // Store object names
    string labelName;
    // Pine 'na' can be represented by empty string or a special value
    void Init() { lineName = ""; labelName = ""; }
};

struct FairValueGapStruct
{
    double top;
    double bottom;
    int bias;           // BULLISH_MQL or BEARISH_MQL
    string topBoxName;    // Store object names
    string bottomBoxName;

    void Init() { top = 0; bottom = 0; bias = 0; }
};

struct OrderBlockStruct
{
    double barHigh;
    double barLow;
    datetime barTime;   // Pine int to datetime
    int bias;           // BULLISH_MQL or BEARISH_MQL

    // Additional field for MQL5 object management
    string boxName;

    void Init()
    {
        barHigh = 0; barLow = 0;
        barTime = 0;
        bias = 0;
        boxName = "";
    }
};

// Global variables
PivotStruct ExtSwingHigh, ExtSwingLow;
PivotStruct ExtInternalHigh, ExtInternalLow;
PivotStruct ExtEqualHigh, ExtEqualLow;

TrendStruct ExtSwingTrend, ExtInternalTrend;

EqualDisplayStruct ExtEqualHighDisplay, ExtEqualLowDisplay;

// Dynamic arrays for complex structures
FairValueGapStruct ExtFairValueGaps[]; // Max size would need definition or truly dynamic resizing
OrderBlockStruct   ExtSwingOrderBlocks[];
OrderBlockStruct   ExtInternalOrderBlocks[];

// Storing simple arrays of price/time data
double ExtParsedHighs[], ExtParsedLows[]; // Prices from MQL5 buffers (Open, High, Low, Close, Time)
double ExtHighs[], ExtLows[];             // Store all historical High/Low available to indicator
datetime ExtTimes[];                      // Store all historical Time available

TrailingExtremesStruct ExtTrailing;

// For pre-created OB boxes
string ExtSwingOBBoxNames[];
string ExtInternalOBBoxNames[];

color VarSwingBullishColor;
color VarSwingBearishColor;
color VarFVGBullishColor;
color VarFVGBearishColor;
color VarPremiumZoneColor;
color VarDiscountZoneColor;

long VarChartId;
string VarIndicatorShortName; // For object naming prefix

AlertsStruct CurrentAlerts; // For alerts on current bar

// Buffers for DRAW_COLOR_CANDLES
double ExtOpenBuffer[];
double ExtHighBuffer[];
double ExtLowBuffer[];
double ExtCloseBuffer[];
double ExtColorBuffer[]; // 0 for bull, 1 for bear, 2 for neutral/no color change

// MQL5 specific global vars
datetime VarInitialTime = 0;
int      VarLastCalculatedBarIndex = -1; // Pine: currentBarIndex / lastBarIndex tracking

// --- Input Parameters (CRITICAL PLACEMENT - AFTER DEFINES/STRUCTS, BEFORE GLOBALS/FUNCTIONS) ---
sinput string comment_SMART_GROUP_Inputs          = "====== Smart Money Concepts ======";
input string           InpMode                     = HISTORICAL;
input string           InpStyle                    = COLORED;                // Used in OnInit
input bool             InpShowTrend                = false;                  // Used in OnInit & OnCalculate

sinput string comment_INTERNAL_GROUP_Inputs       = "====== Real Time Internal Structure ======";
input bool             InpShowInternals            = true;
input string           InpInternalBullFilter       = ALL_FILTER;
input color            InpInternalBullColor        = clrGreen;               // Used in OnInit (via VarSwingBullishColor)
input string           InpInternalBearFilter       = ALL_FILTER;
input color            InpInternalBearColor        = clrRed;                 // Used in OnInit (via VarSwingBearishColor)
input bool             InpInternalFilterConfluence = false;
input ENUM_FONT_SIZE   InpInternalLabelSize        = FONT_SIZE_XSMALL;

sinput string comment_SWING_GROUP_Inputs          = "====== Real Time Swing Structure ======";
input bool             InpShowStructure            = true;
input string           InpSwingBullFilter          = ALL_FILTER;
input color            InpSwingBullColor           = clrGreen;               // Used in OnInit
input string           InpSwingBearFilter          = ALL_FILTER;
input color            InpSwingBearColor           = clrRed;                 // Used in OnInit
input ENUM_FONT_SIZE   InpSwingLabelSize           = FONT_SIZE_SMALL;
input bool             InpShowSwingsPoints         = false;
input int              InpSwingsLength             = 50;                     // Used in OnInit & OnCalculate
input bool             InpShowHighLowSwings        = true;

sinput string comment_BLOCKS_GROUP_Inputs         = "====== Order Blocks ======";
input bool             InpShowInternalOB           = true;
input int              InpInternalOBSize           = 5;
input bool             InpShowSwingOB              = false;
input int              InpSwingOBSize              = 5;
input string           InpOBFilterType             = ATR_FILTER;
input string           InpOBMitigationType         = HIGHLOW_MITIGATION;
input color            InpInternalBullOBColor      = C'50,120,245';
input color            InpInternalBearOBColor      = C'247,125,128';
input color            InpSwingBullOBColor         = C'24,72,204';
input color            InpSwingBearOBColor         = C'178,40,51';

sinput string comment_EQUAL_GROUP_Inputs          = "====== EQH/EQL ======";
input bool             InpShowEQHL                 = true;
input int              InpEQHLLength               = 3;
input double           InpEQHLThreshold            = 0.1;
input ENUM_FONT_SIZE   InpEQHLLabelSize            = FONT_SIZE_XSMALL;

sinput string comment_GAPS_GROUP_Inputs           = "====== Fair Value Gaps ======";
input bool             InpShowFVG                  = false;
input bool             InpFVGAutoThreshold         = true;
input ENUM_TIMEFRAMES  InpFVGTimeframe             = PERIOD_CURRENT;
input color            InpFVGBullColor             = C'0,255,104,178';      // Used in OnInit
input color            InpFVGBearColor             = C'255,0,8,178';        // Used in OnInit
input int              InpFVGExtendBars            = 1;

sinput string comment_LEVELS_GROUP_Inputs         = "====== Highs & Lows MTF ======";
input bool             InpShowDailyLevels          = false;
input string           InpDailyLevelsStyleStr      = SOLID_STYLE_STR;
input color            InpDailyLevelsColor         = clrBlue;
input bool             InpShowWeeklyLevels         = false;
input string           InpWeeklyLevelsStyleStr     = SOLID_STYLE_STR;
input color            InpWeeklyLevelsColor        = clrBlue;
input bool             InpShowMonthlyLevels        = false;
input string           InpMonthlyLevelsStyleStr    = SOLID_STYLE_STR;
input color            InpMonthlyLevelsColor       = clrBlue;

sinput string comment_ZONES_GROUP_Inputs          = "====== Premium & Discount Zones ======";
input bool             InpShowPDZones              = false;
input color            InpPremiumZoneColor         = clrRed;                 // Used in OnInit
input color            InpEquilibriumZoneColor     = clrGray;
input color            InpDiscountZoneColor        = clrGreen;               // Used in OnInit

// Function Declarations
int OnInit();
void OnDeinit(const int reason);
int OnCalculate(const int rates_total, const int prev_calculated,
              const datetime &time[], const double &open[], const double &high[],
              const double &low[], const double &close[], const long &tick_volume[],
              const long &volume[], const int &spread[]);

// Helper Function Declarations
void MQL_DrawStructure(PivotStruct &pivot_to_draw, string tag, color structureColor, 
                   int lineStyleMQL, string labelStylePine, ENUM_FONT_SIZE labelSize, 
                   datetime currentTime, int currentBarIndexMQL, bool is_present_mode);

// Implementation of OnInit and helper functions
int OnInit()
{
    // Indicator buffers mapping
    SetIndexBuffer(0, ExtOpenBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, ExtHighBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, ExtLowBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, ExtCloseBuffer, INDICATOR_DATA);
    SetIndexBuffer(4, ExtColorBuffer, INDICATOR_COLOR_INDEX);
    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpSwingsLength > 0 ? InpSwingsLength : 10); // Don't draw until enough data

    if (InpShowTrend) // Only if "Color Candles" is true
    {
        PlotIndexSetInteger(0, PLOT_SHOW_DATA, true);
        ArraySetAsSeries(ExtOpenBuffer, true);
        ArraySetAsSeries(ExtHighBuffer, true);
        ArraySetAsSeries(ExtLowBuffer, true);
        ArraySetAsSeries(ExtCloseBuffer, true);
        ArraySetAsSeries(ExtColorBuffer, true);
    }
    else
    {
        PlotIndexSetInteger(0, PLOT_SHOW_DATA, false); // Hide DRAW_COLOR_CANDLES plot
    }

    VarChartId = ChartID();
    VarIndicatorShortName = "SmartMoneyConcepts";//ChartIndicatorName(); // Used for unique object names

    // Initialize colors based on style
    VarSwingBullishColor = (InpStyle == MONOCHROME) ? MONO_BULLISH_COLOR : InpSwingBullColor;
    VarSwingBearishColor = (InpStyle == MONOCHROME) ? MONO_BEARISH_COLOR : InpSwingBearColor;
    //VarFVGBullishColor   = (InpStyle == MONOCHROME) ? ColorToARGB(MONO_BULLISH_COLOR, 178) : InpFVGBullColor;
    //VarFVGBearishColor   = (InpStyle == MONOCHROME) ? ColorToARGB(MONO_BEARISH_COLOR, 178) : InpFVGBearColor;
    VarFVGBullishColor = (InpStyle == MONOCHROME) ? MONO_BULLISH_COLOR : InpFVGBullColor;
VarFVGBearishColor = (InpStyle == MONOCHROME) ? MONO_BEARISH_COLOR : InpFVGBearishColor;
    VarPremiumZoneColor  = (InpStyle == MONOCHROME) ? MONO_BEARISH_COLOR : InpPremiumZoneColor;
    VarDiscountZoneColor = (InpStyle == MONOCHROME) ? MONO_BULLISH_COLOR : InpDiscountZoneColor;
    
    // Set colors for DRAW_COLOR_CANDLES plot if used
    PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3); // 3 colors (bull, bear, neutral)
    PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, VarSwingBullishColor);  // Index 0 = bull
    PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, VarSwingBearishColor);  // Index 1 = bear
    PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, clrGray);               // Index 2 = neutral
    
    // Initialize structs
    ExtSwingHigh.Init(); ExtSwingLow.Init();
    ExtInternalHigh.Init(); ExtInternalLow.Init();
    ExtEqualHigh.Init(); ExtEqualLow.Init();
    ExtSwingTrend.Init(); ExtInternalTrend.Init();
    ExtEqualHighDisplay.Init(); ExtEqualLowDisplay.Init();
    ExtTrailing.Init();

    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    // Clean up all objects created by this indicator
    ObjectsDeleteAll(VarChartId, VarIndicatorShortName + "_");
    
    // Clean up arrays
     ArrayFree(ExtSwingOBBoxNames);
     ArrayFree(ExtInternalOBBoxNames);
     ArrayFree(ExtFairValueGaps);
     ArrayFree(ExtSwingOrderBlocks);
     ArrayFree(ExtInternalOrderBlocks);
     ArrayFree(ExtParsedHighs);
     ArrayFree(ExtParsedLows);
     ArrayFree(ExtHighs);
     ArrayFree(ExtLows);
     ArrayFree(ExtTimes);
}

// Corrected OnCalculate definition
int OnCalculate(const int rates_total, const int prev_calculated,
              const datetime &time[], const double &open[], const double &high[],
              const double &low[], const double &close[], const long &tick_volume[],
              const long &volume[], const int &spread[])
{
    if(rates_total < InpSwingsLength || rates_total < 10) return(0);
    
    MQL_SERIES_INFO series_info_obj; // series_info_obj is local to OnCalculate
    
    series_info_obj.rates_total = rates_total; // Set rates_total first

    // Resize and copy arrays
    ArrayResize(series_info_obj.time, rates_total);
    ArrayCopy(series_info_obj.time, time, 0, 0, WHOLE_ARRAY);

    ArrayResize(series_info_obj.open, rates_total);
    ArrayCopy(series_info_obj.open, open, 0, 0, WHOLE_ARRAY);

    ArrayResize(series_info_obj.high, rates_total);
    ArrayCopy(series_info_obj.high, high, 0, 0, WHOLE_ARRAY);

    ArrayResize(series_info_obj.low, rates_total);
    ArrayCopy(series_info_obj.low, low, 0, 0, WHOLE_ARRAY);

    ArrayResize(series_info_obj.close, rates_total);
    ArrayCopy(series_info_obj.close, close, 0, 0, WHOLE_ARRAY);
    
    if(InpShowTrend) { // InpShowTrend now in scope
        for(int i = MathMax(0, prev_calculated-1); i < rates_total; i++) {
            ExtOpenBuffer[i] = open[i];
            ExtHighBuffer[i] = high[i];
            ExtLowBuffer[i] = low[i];
            ExtCloseBuffer[i] = close[i];
            
            // Simple coloring based on current bar
            if(close[i] > open[i])
                ExtColorBuffer[i] = 0; // Bullish
            else if(close[i] < open[i])
                ExtColorBuffer[i] = 1; // Bearish
            else
                ExtColorBuffer[i] = 2; // Neutral
        }
    }

    return(rates_total);
}

// Helper Function Definitions
void MQL_DrawStructure(PivotStruct &pivot_to_draw, string tag, color structureColor, 
                   int lineStyleMQL, string labelStylePine, ENUM_FONT_SIZE labelSize, 
                   datetime currentTime, int currentBarIndexMQL, bool is_present_mode)
{
    // Implementation of MQL_DrawStructure function
}

// ...