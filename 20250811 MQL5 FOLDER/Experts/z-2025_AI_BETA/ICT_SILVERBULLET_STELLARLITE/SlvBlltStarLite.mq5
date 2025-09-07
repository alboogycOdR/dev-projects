//+------------------------------------------------------------------+
//|                                    StellarLite_ICT_EA.mq5         |
//|                      Copyright 2025, Advanced ICT Trader          |
//|                                      https://www.example.com      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Advanced ICT Trader"
#property link      "https://www.example.com"
#property version   "1.14" // Version Updated
#property description "EA for Stellar Lite 5K Challenge using Silver Bullet and 2022 Model"
#property description "High win-rate ICT strategies with low risk, partial TPs, trailing SL"

#include <Trade\Trade.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\DealInfo.mqh> // Included for OnTradeTransaction

//--- Input Parameters
input group             "Risk Management"
    input double            RiskPercentPerTrade = 0.25;     // Risk 0.25% per trade
    input double            MaxTotalDrawdownPercent = 10.0; // Stellar Lite max drawdown
    input double            MaxDailyDrawdownPercent = 5.0;  // Stellar Lite daily limit
    input double            InitialBalance = 5000.0;        // Starting balance

input group             "Trade Management"
    input double            TP1_RR = 1.0;                   // TP1 = 1:1 Risk:Reward
    input double            TP2_RR = 2.0;                   // TP2 = 2:1
    input double            TP3_RR = 3.0;                   // TP3 = 3:1
    input double            PartialClosePercentTP1 = 50.0;  // Close 50% at TP1
    input double            PartialClosePercentTP2 = 25.0;  // Close 25% at TP2
    input double            PartialClosePercentTP3 = 25.0;  // Close 25% at TP3 (remainder closed by main TP)
    input bool              MoveSLToBE_AfterTP1 = true;     // Move SL to Break Even after TP1
    input int               BE_PlusPips = 1;                // Pips above/below BE
    input double            TrailingSL_Pips = 10.0;         // Trailing SL after TP2

input group             "Strategy Selection"
    input bool              Use_SilverBullet = true;        // Enable Silver Bullet
    input string            SB_StartTime = "10:00";         // NY AM Killzone Start
    input string            SB_EndTime = "11:00";           // NY AM Killzone End
    input bool              Use_2022Model = true;           // Enable 2022 Model
    input bool              Use_OTE_Entry = true;           // Use Fibonacci OTE

input group             "Higher Timeframe Bias"
input ENUM_TIMEFRAMES   HTF = PERIOD_H1;                // HTF for Bias
input int               HTF_MA_Period = 200;            // MA period
input ENUM_MA_METHOD    HTF_MA_Method = MODE_SMA;       // MA method
input ENUM_APPLIED_PRICE HTF_MA_Price = PRICE_CLOSE;    // Applied price

input group             "Draw on Liquidity (DOL)"
input int               DOL_Lookback_Bars = 120;        // Lookback bars
input double            NDOG_NWOG_Threshold = 0.5;      // ATR multiplier for NDOG/NWOG

input group             "Fibonacci OTE"
input double            OTE_Lower_Level = 0.618;        // Lower Fib level
input double            OTE_Upper_Level = 0.786;        // Upper Fib level

input group             "Visuals"
input bool              ShowTradeLevels = true;         // Show Entry, SL, TP lines
input bool              ShowICTElements = true;         // Show ICT Analysis Elements
input bool              ShowFVG = true;                 // Show Fair Value Gaps
input bool              ShowLiquidity = true;           // Show Liquidity Levels
input bool              ShowMSS = true;                 // Show Market Structure Shifts
input bool              ShowOTE = true;                 // Show OTE Zones
input bool              ShowNDOG = true;                // Show NDOG/NWOG Markers
input bool              ShowKillzones = true;           // Show Killzone Lines
input color             KillzoneColor = clrOrange;      // Killzone line color
input ENUM_LINE_STYLE   KillzoneStyle = STYLE_DOT;     // Killzone line style
input color             BuyLevelColor = clrDodgerBlue;
input color             SellLevelColor = clrRed;
input color             TPLevelColor = clrGreen;
input color             SLLevelColor = clrOrangeRed;
input color             FVGColor = C'32,178,170';       // FVG zone color
input color             LiquidityColor = clrGoldenrod;  // Liquidity level color
input color             MSSColor = clrMagenta;          // MSS point color
input color             OTEColor = clrDarkViolet;       // OTE zone color
input color             NDOGColor = clrDarkOrange;      // NDOG/NWOG marker color
//+------------------------------------------------------------------+
//| Input Parameters - Custom SmartMoneyConcepts Indicator Settings  |
//+------------------------------------------------------------------+
input group "=== Custom Indicator: SmartMoneyConcepts Settings ===";

// --- Main Settings ---
input int    custInd_HistoryCandles    = 2000;    // Number of historical candles to process for the indicator.
input int    custInd_Mode              = 0;       // Indicator calculation mode (e.g., 0=Historical, 1=Realtime - Verify actual mapping with indicator source).
input int    custInd_Style             = 0;       // Visual style of the indicator (e.g., 0=Colored, 1=Plain - Verify actual mapping).
input int   custInd_ColorCandles      = 0;   // Enable/disable coloring of chart candles based on indicator signals.

// --- Real Time Internal Structure ---
input int   custInd_ShowInternalStructure = 1; // Show/hide internal market structure elements in real-time.
input int    custInd_RTInt_BullishStructureEnum = 0;  // Type of bullish internal structure to display (e.g., 0=All, 1=Break of Structure - Verify mapping).
input color  custInd_RTInt_BullishColor  = clrLimeGreen; // Color for bullish internal structure.
input int    custInd_RTInt_BearishStructureEnum = 0;  // Type of bearish internal structure to display (e.g., 0=All, 1=Break of Structure - Verify mapping).
input color  custInd_RTInt_BearishColor  = clrRed;        // Color for bearish internal structure.
input bool   custInd_RTInt_ConfluenceFilter = false; // Enable/disable confluence filter for real-time internal structure.

// --- Real Time Swing Structure ---
input int   custInd_ShowSwingStructure  = 1;    // Show/hide swing market structure elements in real-time.
input int    custInd_RTSwing_BullishStructureEnum=0; // Type of bullish swing structure to display (e.g., 0=All - Verify mapping).
input color  custInd_RTSwing_BullishColor= clrLimeGreen; // Color for bullish swing structure.
input int    custInd_RTSwing_BearishStructureEnum=0; // Type of bearish swing structure to display (e.g., 0=All - Verify mapping).
input color  custInd_RTSwing_BearishColor = clrRed;    // Color for bearish swing structure.
input bool   custInd_ShowSwingPoints     = false;   // Show/hide individual swing points.
input int    custInd_SwingLength         = 50;      // Lookback period for identifying swing points.

// --- Structure High/Low ---
input int   custInd_ShowStrongWeakHL    = 1;    // Show/hide strong and weak highs/lows.

// --- Order Blocks ---
input bool   custInd_ShowInternalOBs     = true;    // Show/hide internal order blocks.
input int    custInd_InternalOBLookback  = 5;       // Lookback period for identifying internal order blocks.
input bool   custInd_ShowSwingOBs        = false;   // Show/hide swing order blocks.
input int    custInd_SwingOBLookback     = 5;       // Lookback period for identifying swing order blocks.
input int    custInd_OBFilterEnum        = 0;       // Filter for order blocks (e.g., 0=ATR, 1=Volume - Verify mapping).
input color  custInd_InternalBullishOBColor = clrDeepSkyBlue; // Color for bullish internal order blocks.
input color  custInd_InternalBearishOBColor = clrHotPink;     // Color for bearish internal order blocks.
input color  custInd_SwingBullishOBColor = clrRoyalBlue;   // Color for bullish swing order blocks.
input color  custInd_SwingBearishOBColor = clrIndianRed;   // Color for bearish swing order blocks.

// --- EQH/EQL ---
input bool   custInd_ShowEQH_EQL         = false;   // Show/hide Equal Highs (EQH) and Equal Lows (EQL).
input int    custInd_EQ_BarsConfirmation = 3;       // Number of bars for confirming EQH/EQL.
input double custInd_EQ_Threshold        = 0.1;     // Threshold (e.g., in pips or ATR multiple) for defining equal highs/lows.

// --- Fair Value Gaps ---
input bool   custInd_ShowFVGs            = true;    // Show/hide Fair Value Gaps (FVGs) / Imbalances.
input bool   custInd_FVG_AutoThreshold   = true;    // Enable/disable automatic threshold calculation for FVG detection.
input ENUM_TIMEFRAMES custInd_FVG_Timeframe = PERIOD_CURRENT; // Timeframe on which to detect FVGs.
input color  custInd_BullishFVGColor     = clrPaleGreen; // Color for bullish FVGs.
input color  custInd_BearishFVGColor     = clrLightPink; // Color for bearish FVGs.
input int    custInd_ExtendFVG           = 1;       // Number of bars to extend the FVG visualization.

// --- Highs & Lows MTF ---
input bool   custInd_ShowDailyHL         = false;   // Show/hide daily highs and lows.
input ENUM_LINE_STYLE custInd_StyleDailyHL  = STYLE_SOLID; // Line style for daily highs/lows.
input color  custInd_ColorDailyHL        = clrCornflowerBlue; // Color for daily highs/lows.
input bool   custInd_ShowWeeklyHL        = false;   // Show/hide weekly highs and lows.
input ENUM_LINE_STYLE custInd_StyleWeeklyHL = STYLE_SOLID; // Line style for weekly highs/lows.
input color  custInd_ColorWeeklyHL       = clrCornflowerBlue; // Color for weekly highs/lows.
input bool   custInd_ShowMonthlyHL       = false;   // Show/hide monthly highs and lows.
input ENUM_LINE_STYLE custInd_StyleMonthlyHL= STYLE_SOLID; // Line style for monthly highs/lows.
input color  custInd_ColorMonthlyHL      = clrCornflowerBlue; // Color for monthly highs/lows.

// --- Premium & Discount Zones ---
input bool   custInd_ShowPDZones         = false;   // Show/hide Premium, Discount, and Equilibrium zones.
input color  custInd_PremiumZoneColor    = clrOrangeRed;   // Color for the Premium zone.
input color  custInd_EquilibriumZoneColor= clrSilver;        // Color for the Equilibrium zone.
input color  custInd_DiscountZoneColor   = clrSpringGreen;   // Color for the Discount zone.
string     visual_comment_text = "714EA"; // Prefix for chart comments/object descriptions

//--- Global Variables
CTrade          trade;
CAccountInfo    accountInfo;
CPositionInfo   positionInfo;
CSymbolInfo     symbolInfo;
CDealInfo       dealInfo; // For OnTradeTransaction
long            magicNumber;
double          minLot, maxLot, lotStep, pointValue, tickSize;
int             digitsFactor;
datetime        dailyStartTime = 0;
double          dailyStartEquity = 0;
int             htfMAHandle = INVALID_HANDLE; // Initialize to INVALID_HANDLE
int             atrHandle = INVALID_HANDLE;   // Initialize to INVALID_HANDLE

// Structure for Trade Setup
struct TradeSetup
{
   bool        isValid;
   double      entryPrice;
   double      stopLossPrice;
   double      tp1Price;
   double      tp2Price;
   double      tp3Price;
   // double      tp4Price; // tp4Price was in struct but not used in original, removed for clarity
   ENUM_ORDER_TYPE orderType;
   string      strategyName;
   double      lotSize;
};

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   magicNumber = 343747347;//ChartID(); // Simplified magic number
   trade.SetExpertMagicNumber(magicNumber);
   trade.SetTypeFillingBySymbol(_Symbol); // Recommended for CTrade

   if(!symbolInfo.Name(_Symbol))
   {
      Print("Error initializing symbol info for ", _Symbol);
      return(INIT_FAILED);
   }
   minLot = symbolInfo.LotsMin();
   maxLot = symbolInfo.LotsMax();
   lotStep = symbolInfo.LotsStep();
   pointValue = symbolInfo.Point();
   tickSize = symbolInfo.TickSize();
   digitsFactor = (symbolInfo.Digits() == 5 || symbolInfo.Digits() == 3) ? 10 : 1;

   htfMAHandle = iMA(_Symbol, HTF, HTF_MA_Period, 0, HTF_MA_Method, HTF_MA_Price);
   if(htfMAHandle == INVALID_HANDLE)
   {
      Print("Error initializing HTF MA handle");
      return(INIT_FAILED);
   }

   // Initialize ATR Handle once
   atrHandle = iATR(_Symbol, _Period, 14); // Default ATR period for NDOG/NWOG
   if(atrHandle == INVALID_HANDLE)
   {
      Print("Error initializing ATR handle");
      return(INIT_FAILED);
   }

   if(RiskPercentPerTrade <= 0 || InitialBalance <= 0)
   {
      Print("Error: Invalid RiskPercentPerTrade or InitialBalance");
      return(INIT_FAILED);
   }

   dailyStartEquity = accountInfo.Equity();
   dailyStartTime = TimeCurrent(); // Ensure this is set correctly
   
   // Initialize Dashboard
   CreateDashboard();
   //--- Add Custom Indicator ---
   string indicator_path = "2025SMART\\SmartMoneyConcepts";
   bool indicator_exists = false;
   for(int i = 0; i < ChartIndicatorsTotal(0, 0); i++) {
      string ind_name_on_chart = ChartIndicatorName(0, 0, i);
      if(StringFind(ind_name_on_chart, "SmartMoneyConcepts", 0) != -1) {
         indicator_exists = true;
         Print(visual_comment_text + " - Custom indicator '", indicator_path, "' already found on chart.");
         break;
      }
   }
   if(!indicator_exists) {
      ResetLastError();
      // Call iCustom with all parameters directly
        int indicator_handle = iCustom(Symbol(), Period(), indicator_path,
                                  // --- Main Settings ---
                                  custInd_HistoryCandles,                 // Param 1 (int)
                                  "HEADER",
                                  custInd_Mode,                           // Param 2 (int for enum)
                                  custInd_Style,                          // Param 3 (int for enum)
                                  custInd_ColorCandles,                   // Param 4 (bool)
                                  "realtime int struct",
                                  // --- Real Time Internal Structure ---
                                  custInd_ShowInternalStructure,          // Param 5 (bool)
                                  custInd_RTInt_BullishStructureEnum,     // Param 6 (int for enum)
                                  custInd_RTInt_BullishColor,             // Param 7 (color)
                                  custInd_RTInt_BearishStructureEnum,     // Param 8 (int for enum)
                                  custInd_RTInt_BearishColor,             // Param 9 (color)
                                  custInd_RTInt_ConfluenceFilter,         // Param 10 (bool)
                                  "realtime swing",
                                  // --- Real Time Swing Structure ---
                                  custInd_ShowSwingStructure,             // Param 11 (bool)
                                  custInd_RTSwing_BullishStructureEnum,   // Param 12 (int for enum)
                                  custInd_RTSwing_BullishColor,           // Param 13 (color)
                                  custInd_RTSwing_BearishStructureEnum,   // Param 14 (int for enum)
                                  custInd_RTSwing_BearishColor,           // Param 15 (color)
                                  custInd_ShowSwingPoints,                // Param 16 (bool)
                                  custInd_SwingLength,                    // Param 17 (int)
                                  // --- Structure High/Low ---
                                  custInd_ShowStrongWeakHL,               // Param 18 (bool)
                                  "OB",
                                  // --- Order Blocks ---
                                  custInd_ShowInternalOBs,                // Param 19 (bool)
                                  custInd_InternalOBLookback,             // Param 20 (int)
                                  custInd_ShowSwingOBs,                   // Param 21 (bool)
                                  custInd_SwingOBLookback,                // Param 22 (int)
                                  custInd_OBFilterEnum,                   // Param 23 (int for enum)
                                  custInd_InternalBullishOBColor,         // Param 24 (color)
                                  custInd_InternalBearishOBColor,         // Param 25 (color)
                                  custInd_SwingBullishOBColor,            // Param 26 (color)
                                  custInd_SwingBearishOBColor,            // Param 27 (color)
                                  "EQH EQL",
                                  // --- EQH/EQL ---
                                  custInd_ShowEQH_EQL,                    // Param 28 (bool)
                                  custInd_EQ_BarsConfirmation,            // Param 29 (int)
                                  custInd_EQ_Threshold,                   // Param 30 (double)
                                  "FVG",
                                  // --- Fair Value Gaps ---
                                  custInd_ShowFVGs,                       // Param 31 (bool)
                                  custInd_FVG_AutoThreshold,              // Param 32 (bool)
                                  (int)custInd_FVG_Timeframe,             // Param 33 (ENUM_TIMEFRAMES cast to int)
                                  custInd_BullishFVGColor,                // Param 34 (color)
                                  custInd_BearishFVGColor,                // Param 35 (color)
                                  custInd_ExtendFVG,                      // Param 36 (int)
                                  "highs & lows mtf",
                                  // --- Highs & Lows MTF ---
                                  custInd_ShowDailyHL,                    // Param 37 (bool)
                                  (int)custInd_StyleDailyHL,              // Param 38 (ENUM_LINE_STYLE cast to int)
                                  custInd_ColorDailyHL,                   // Param 39 (color)
                                  custInd_ShowWeeklyHL,                   // Param 40 (bool)
                                  (int)custInd_StyleWeeklyHL,             // Param 41 (ENUM_LINE_STYLE cast to int)
                                  custInd_ColorWeeklyHL,                  // Param 42 (color)
                                  custInd_ShowMonthlyHL,                  // Param 43 (bool)
                                  (int)custInd_StyleMonthlyHL,            // Param 44 (ENUM_LINE_STYLE cast to int)
                                  custInd_ColorMonthlyHL,                 // Param 45 (color)
                                  "PREM DISC",
                                  // --- Premium & Discount Zones ---
                                  custInd_ShowPDZones,                    // Param 46 (bool)
                                  custInd_PremiumZoneColor,               // Param 47 (color)
                                  custInd_EquilibriumZoneColor,           // Param 48 (color)
                                  custInd_DiscountZoneColor               // Param 49 (color) 
                                 );
      if(indicator_handle != INVALID_HANDLE) {
         // Removed IndicatorSetString block as it's not needed and causes errors
         if(!ChartIndicatorAdd(0, 0, indicator_handle)) {
            Print(visual_comment_text + " - ERROR: Failed to add custom indicator '", indicator_path, "' to chart using iCustom. Error code: ", GetLastError());
         }
         else {
            Print(visual_comment_text + " - Custom indicator '", indicator_path, "' added to chart successfully using iCustom.");
            ChartRedraw();
         }
      }
      else {
         Print(visual_comment_text + " - ERROR: iCustom failed for '", indicator_path, "'. Error code: ", GetLastError());
         Print(visual_comment_text + " - Verify the indicator path and that parameter types/count match exactly.");
      }
   }
   Print("StellarLite ICT EA Initialized.", "Magic: ", magicNumber, ", Symbol: ", _Symbol);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(htfMAHandle != INVALID_HANDLE) IndicatorRelease(htfMAHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle); // Release ATR handle
   ObjectsDeleteAll(ChartID(), "SL_ICT_EA_");
   DeleteDashboard();
   Print("StellarLite ICT EA Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Dashboard Functions                                               |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   // Main panel background
   string name = "SL_ICT_EA_Dashboard_BG";
   if(!ObjectCreate(ChartID(), name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      Print("Error creating dashboard background!");
      return;
   }
   
   ObjectSetInteger(ChartID(), name, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(ChartID(), name, OBJPROP_YDISTANCE, 10);
   ObjectSetInteger(ChartID(), name, OBJPROP_XSIZE, 200);
   ObjectSetInteger(ChartID(), name, OBJPROP_YSIZE, 120);
   ObjectSetInteger(ChartID(), name, OBJPROP_BGCOLOR, C'32,32,32');
   ObjectSetInteger(ChartID(), name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(ChartID(), name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(ChartID(), name, OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(ChartID(), name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(ChartID(), name, OBJPROP_SELECTED, false);
   
   // Title
   CreateDashboardLabel("Title", "ICT StellarLite Dashboard", 20, 15, clrWhite, true);
   
   // Labels for data
   CreateDashboardLabel("BiasLabel", "HTF Bias:", 20, 40, clrGray, false);
   CreateDashboardLabel("BiasValue", "---", 100, 40, clrWhite, false);
   
   CreateDashboardLabel("KZLabel", "Killzone:", 20, 60, clrGray, false);
   CreateDashboardLabel("KZValue", "---", 100, 60, clrWhite, false);
   
   CreateDashboardLabel("KZTimeLabel", "KZ Time:", 20, 80, clrGray, false);
   CreateDashboardLabel("KZTimeValue", "---", 100, 80, clrWhite, false);
   
   ChartRedraw();
}

void CreateDashboardLabel(string name, string text, int x, int y, color clr, bool isBold)
{
   name = "SL_ICT_EA_Dashboard_" + name;
   if(!ObjectCreate(ChartID(), name, OBJ_LABEL, 0, 0, 0))
   {
      Print("Error creating label ", name);
      return;
   }
   
   ObjectSetInteger(ChartID(), name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(ChartID(), name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(ChartID(), name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(ChartID(), name, OBJPROP_TEXT, text);
   ObjectSetString(ChartID(), name, OBJPROP_FONT, isBold ? "Arial Bold" : "Arial");
   ObjectSetInteger(ChartID(), name, OBJPROP_FONTSIZE, isBold ? 10 : 9);
   ObjectSetInteger(ChartID(), name, OBJPROP_COLOR, clr);
   ObjectSetInteger(ChartID(), name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(ChartID(), name, OBJPROP_SELECTED, false);
}

void UpdateDashboard(ENUM_ORDER_TYPE bias)
{
   // Update Bias
   string biasText = "---";
   color biasColor = clrGray;
   
   switch(bias)
   {
      case ORDER_TYPE_BUY:
         biasText = "BULLISH";
         biasColor = clrLime;
         break;
      case ORDER_TYPE_SELL:
         biasText = "BEARISH";
         biasColor = clrRed;
         break;
      default:
         biasText = "NEUTRAL";
         biasColor = clrGray;
   }
   
   ObjectSetString(ChartID(), "SL_ICT_EA_Dashboard_BiasValue", OBJPROP_TEXT, biasText);
   ObjectSetInteger(ChartID(), "SL_ICT_EA_Dashboard_BiasValue", OBJPROP_COLOR, biasColor);
   
   // Update Killzone Status
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   string timeStr = StringFormat("%02d:%02d", currentTime.hour, currentTime.min);
   
   bool inKillzone = (timeStr >= SB_StartTime && timeStr < SB_EndTime);
   ObjectSetString(ChartID(), "SL_ICT_EA_Dashboard_KZValue", OBJPROP_TEXT, inKillzone ? "ACTIVE" : "INACTIVE");
   ObjectSetInteger(ChartID(), "SL_ICT_EA_Dashboard_KZValue", OBJPROP_COLOR, inKillzone ? clrLime : clrGray);
   
   // Update Killzone Time
   string kzTimeText = SB_StartTime + " - " + SB_EndTime;
   ObjectSetString(ChartID(), "SL_ICT_EA_Dashboard_KZTimeValue", OBJPROP_TEXT, kzTimeText);
   
   ChartRedraw();
}

void DeleteDashboard()
{
   ObjectsDeleteAll(ChartID(), "SL_ICT_EA_Dashboard_");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Close All Open Positions by Magic Number and Symbol              |
//+------------------------------------------------------------------+
void CloseAllOpenPositionsByMagic()
{
   int totalPositions = PositionsTotal();
   int closedCount = 0;

   PrintFormat("Attempting to close all positions for magic %d on symbol %s.", magicNumber, _Symbol);

   // Iterate backwards because closing positions can shift the indices
   for(int i = totalPositions - 1; i >= 0; i--)
   {
      // Select position by index
      if(positionInfo.SelectByIndex(i))
      {
         // Check if it's our EA's position and on the current chart's symbol
         if(positionInfo.Magic() == magicNumber && positionInfo.Symbol() == _Symbol)
         {
            ulong ticket = positionInfo.Ticket();
            ENUM_POSITION_TYPE type = positionInfo.PositionType();
            double volume = positionInfo.Volume();
            string positionSymbol = positionInfo.Symbol();

            PrintFormat("Closing position #%I64u (%s %s %.2f lots)...",
                        ticket, positionSymbol, type == POSITION_TYPE_BUY ? "BUY" : "SELL", volume);

            // Use the CTrade object to close the position
            if(trade.PositionClose(ticket))
            {
               PrintFormat("Position #%I64u closed successfully.", ticket);
               closedCount++;
            }
            else
            {
               MqlTradeResult trade_result;
               trade.Result(trade_result); // Get the result of the last operation
               int lastError = GetLastError();
               PrintFormat("Failed to close position #%I64u. Error: %d, Retcode: %d - %s",
                           ticket, lastError, trade_result.retcode, trade.ResultRetcodeDescription());
            }
         }
      }
      else
      {
         Print("Error selecting position by index ", i, " during CloseAllOpenPositionsByMagic. Error: ", GetLastError());
      }
   }
   if(closedCount > 0)
      PrintFormat("%d positions closed by CloseAllOpenPositionsByMagic.", closedCount);
   else
      Print("No positions were found/closed by CloseAllOpenPositionsByMagic for magic %d on symbol %s.", magicNumber, _Symbol);
}
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates()
  {
//--- refresh rates
   if(!symbolInfo.RefreshRates())
      return(false);
//--- protection against the return value of "zero"
   if(symbolInfo.Ask()==0 || symbolInfo.Bid()==0)
      return(false);
//---
   return(true);
  }
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!RefreshRates()) // Add this
   {
      Print("Failed to refresh rates in OnTick. Skipping tick.");
      return;
   }
   if(!IsTradingAllowed()) return;

   // Daily drawdown reset logic
   MqlDateTime currentDt;
   TimeToStruct(TimeCurrent(), currentDt);
   datetime startOfCurrentDay = TimeCurrent() - (currentDt.hour * 3600 + currentDt.min * 60 + currentDt.sec);
   if(dailyStartTime < startOfCurrentDay) // Check if a new day has started
   {
      dailyStartEquity = accountInfo.Equity();
      dailyStartTime = startOfCurrentDay;
      Print("New trading day. Daily Start Equity reset to: ", dailyStartEquity, " at ", TimeToString(dailyStartTime));
   }

   if(CheckDrawdownLimits())
   {
      Print("Drawdown limit reached. Closing all open positions for magic number %d.", magicNumber);
      CloseAllOpenPositionsByMagic();
      return;
   }

   static datetime lastBarTime = 0;
   datetime currentBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   bool positionExists = positionInfo.SelectByMagic(_Symbol, magicNumber);

   // Get rates for ICT analysis and drawing
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, 20, rates) >= 20) // Get enough bars for ICT analysis
   {
      if(currentBarTime > lastBarTime) // New bar
      {
         lastBarTime = currentBarTime;
         if(positionExists)
            ManageOpenTrades();
         else
            CheckForEntrySignals();
            
         // Draw ICT elements on new bar
         if(ShowICTElements)
            DrawICTElements(rates);
      }
      else if(positionExists)
      {
         ManageOpenTrades();
      }
   }

   if(ShowTradeLevels && positionExists)
   {
      // Ensure positionInfo is still valid if ManageOpenTrades closed the position
      if (positionInfo.SelectByMagic(_Symbol, magicNumber)) {
         DrawTradeInfo(positionInfo.PriceOpen(), positionInfo.StopLoss(), positionInfo.TakeProfit(),
                       positionInfo.PositionType() == POSITION_TYPE_BUY ? BuyLevelColor : SellLevelColor,
                       SLLevelColor, TPLevelColor);
         // Re-draw partial TPs if still relevant
         TradeSetup partialTPs = RetrievePartialTPLevels(positionInfo.Ticket());
         if(partialTPs.isValid)
         {
            if(!HasTPLevelBeenHit(positionInfo.Ticket(), 1)) DrawPartialTPLevel(1, partialTPs.tp1Price); else ObjectsDeleteAll(0, "SL_ICT_EA_Level_TP1_" + IntegerToString(magicNumber));
            if(!HasTPLevelBeenHit(positionInfo.Ticket(), 2)) DrawPartialTPLevel(2, partialTPs.tp2Price); else ObjectsDeleteAll(0, "SL_ICT_EA_Level_TP2_" + IntegerToString(magicNumber));
            DrawPartialTPLevel(3, partialTPs.tp3Price); // Main TP line might cover this, but good for consistency
         }
      } else {
         ObjectsDeleteAll(ChartID(), "SL_ICT_EA_Level_"); // Position closed, clean up all levels
      }
   }
   else
   {
      ObjectsDeleteAll(ChartID(), "SL_ICT_EA_Level_");
   }
}

//+------------------------------------------------------------------+
//| Trade Transaction Function                                       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD  ) //TODO Check against global magicNumber
   {
      if(dealInfo.SelectByIndex(trans.deal)) // Changed SelectByTicket to SelectByIndex
      {
        if(dealInfo.Magic() == magicNumber)
         {
         // Check if the deal is related to closing a position
         if(dealInfo.Entry() == DEAL_ENTRY_OUT || dealInfo.Entry() == DEAL_ENTRY_INOUT)
         {
            ulong positionTicket = dealInfo.PositionId(); // Changed Pos to PositionId
            // Check if the position is now fully closed
            // Attempt to select the position. If it fails, the position is closed.
            if(!positionInfo.SelectByTicket(positionTicket))
            {
               CleanUpGlobalVariables(positionTicket);
            }
         }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Clean up Global Variables for a closed position                  |
//+------------------------------------------------------------------+
void CleanUpGlobalVariables(ulong closedPositionTicket)
{
   string prefix = "SL_ICT_EA_" + IntegerToString(magicNumber) + "_" + IntegerToString(closedPositionTicket) + "_";
   Print("Cleaning up Global Variables for closed position #", closedPositionTicket);

   GlobalVariableDel(prefix + "TP1");
   GlobalVariableDel(prefix + "TP2");
   GlobalVariableDel(prefix + "TP3");
   GlobalVariableDel(prefix + "InitVol");
   GlobalVariableDel(prefix + "TP1Hit");
   GlobalVariableDel(prefix + "TP2Hit");
   GlobalVariableDel(prefix + "IsValid");
   // Optional: A final check if they were deleted
   // if(!GlobalVariableCheck(prefix + "IsValid")) Print("GVs for #", closedPositionTicket, " cleaned successfully.");
}


//+------------------------------------------------------------------+
//| Check if trading is allowed                                       |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   if(!accountInfo.TradeAllowed() || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      Print("Trading is not allowed by account settings or terminal.");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check Drawdown Limits                                            |
//+------------------------------------------------------------------+
bool CheckDrawdownLimits()
{
   double equity = accountInfo.Equity();
   double balance = accountInfo.Balance(); // Use current balance for drawdown calculation relative to it, or InitialBalance if fixed.
                                          // Prop firms often use Initial Balance of the phase.

   // Total Drawdown (Relative to Initial Balance as per typical prop firm rules)
   double totalDrawdown = ((InitialBalance - equity) / InitialBalance) * 100.0;
   if (totalDrawdown >= MaxTotalDrawdownPercent)
   {
      PrintFormat("Max Total Drawdown Limit Reached: %.2f%% (Limit: %.2f%%). Equity: %.2f. Initial Balance: %.2f",
                  totalDrawdown, MaxTotalDrawdownPercent, equity, InitialBalance);
      return true;
   }

   // Daily Drawdown (Relative to Equity at start of day)
   double dailyDrawdown = ((dailyStartEquity - equity) / dailyStartEquity) * 100.0;
     if (dailyStartEquity > 0 && dailyDrawdown >= MaxDailyDrawdownPercent) // dailyStartEquity must be > 0
   {
      PrintFormat("Max Daily Drawdown Limit Reached: %.2f%% (Limit: %.2f%%). Equity: %.2f. Daily Start Equity: %.2f",
                  dailyDrawdown, MaxDailyDrawdownPercent, equity, dailyStartEquity);
      return true;
   }
   return false;
}


//+------------------------------------------------------------------+
//| Check for Entry Signals                                          |
//+------------------------------------------------------------------+
void CheckForEntrySignals()
{
   if(!RefreshRates()) // Add this
   {
      Print("Failed to refresh rates in CheckForEntrySignals. Skipping check.");
      return;
   }
   TradeSetup setup = {false, 0, 0, 0, 0, 0, ORDER_TYPE_BUY, "", 0}; // tp4Price removed from struct init

   ENUM_ORDER_TYPE htfBias = DetermineHTFBias();
   if(htfBias == (ENUM_ORDER_TYPE)-1) // Explicitly cast -1 for comparison if needed, or check against specific invalid value
   {
       Print("HTF Bias Undetermined.");
      return;
   }

   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   string timeStr = StringFormat("%02d:%02d", currentTime.hour, currentTime.min);

   if(Use_SilverBullet && timeStr >= SB_StartTime && timeStr < SB_EndTime)
   {
      setup = CheckSilverBulletEntry(htfBias);
      if(setup.isValid)
      {
         setup.lotSize = CalculateLotSize(setup.stopLossPrice, setup.entryPrice, setup.orderType);
         if(setup.lotSize >= minLot) OpenTrade(setup);
         else Print("Calculated Lot Size (", setup.lotSize, ") is less than MinLot (", minLot, ") for SilverBullet.");
         return;
      }
   }

   if(!setup.isValid && Use_2022Model) // Check only if SilverBullet didn't fire
   {
      setup = Check2022ModelEntry(htfBias);
      if(setup.isValid)
      {
         setup.lotSize = CalculateLotSize(setup.stopLossPrice, setup.entryPrice, setup.orderType);
         if(setup.lotSize >= minLot) OpenTrade(setup);
         else Print("Calculated Lot Size (", setup.lotSize, ") is less than MinLot (", minLot, ") for 2022Model.");
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Determine Higher Timeframe Bias                                  |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE DetermineHTFBias()
{
   double ma[3]; // Need 3 values for ma[0], ma[1], ma[2]
   if(CopyBuffer(htfMAHandle, 0, 0, 3, ma) < 3)
   {
      Print("Failed to copy HTF MA buffer.");
      UpdateDashboard((ENUM_ORDER_TYPE)-1);
      return (ENUM_ORDER_TYPE)-1; // Return an invalid order type
   }
   RefreshRates();
   
   // Normalize MA values
   ma[0] = NormalizeDouble(ma[0], symbolInfo.Digits());
   ma[1] = NormalizeDouble(ma[1], symbolInfo.Digits());
   ma[2] = NormalizeDouble(ma[2], symbolInfo.Digits());
   
   double currentAsk = NormalizeDouble(symbolInfo.Ask(), symbolInfo.Digits());
   double currentBid = NormalizeDouble(symbolInfo.Bid(), symbolInfo.Digits());

   Print("HTF Bias Check - MA Values: MA[0]=", ma[0], " MA[1]=", ma[1], " MA[2]=", ma[2]);
   Print("Current Ask=", currentAsk, " Bid=", currentBid);
   Print("MA Trend: MA[1]=", ma[1], " vs MA[2]=", ma[2], " (Up if MA[1] > MA[2])");

   Print("condition check full:"+(currentBid < ma[1] ));
   Print("condition check full:"+( ma[1] < ma[2]));
   
   ENUM_ORDER_TYPE bias = (ENUM_ORDER_TYPE)-1;
   
   if(currentAsk > ma[1]) {
      Print("BUY Bias: Ask(", currentAsk, ") > MA[1](", ma[1], ")");
      bias = ORDER_TYPE_BUY;
   }
   else if(currentBid < ma[1]) {
      Print("SELL Bias: Bid(", currentBid, ") < MA[1](", ma[1], ")");
      bias = ORDER_TYPE_SELL;
   }
   else {
      Print("NO CLEAR BIAS: Conditions not met for either Buy or Sell");
   }
   
   UpdateDashboard(bias);
   return bias;
}

//+------------------------------------------------------------------+
//| Check Silver Bullet Entry                                        |
//+------------------------------------------------------------------+
TradeSetup CheckSilverBulletEntry(ENUM_ORDER_TYPE bias)
{
   TradeSetup setup = {false, 0, 0, 0, 0, 0, ORDER_TYPE_BUY, "SilverBullet", 0};
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, 20, rates) < 20) return setup;

   // Note: For Silver Bullet, liquidity sweep is often on a lower timeframe (e.g., M1) than the entry FVG (e.g., M5/M15).
   // This simplified version checks on the current _Period.
   double liquidityLevel = FindNearestLiquidityLevel(bias == ORDER_TYPE_SELL); // Find high for sell, low for buy
   bool liquiditySwept = CheckLiquiditySweep(liquidityLevel, bias == ORDER_TYPE_SELL ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, rates); // Sweep liquidity *against* the bias
   bool mssConfirmed = CheckMSS(bias, rates);
   double fvgHigh = 0, fvgLow = 0;
   FindFVG(rates, fvgHigh, fvgLow, bias); // Pass bias to FindFVG to look for appropriate FVG

   if(liquiditySwept && mssConfirmed && fvgHigh > 0 && fvgLow > 0 && CheckNDOG_NWOG(rates, 0)) // Assuming rates[0] is the FVG candle
   {
      // Entry logic: typically retrace into FVG
      setup.orderType = bias;
      setup.entryPrice = CalculateEntryPrice(fvgLow, fvgHigh, Use_OTE_Entry, bias);
      setup.stopLossPrice = FindProtectiveStopLoss(rates, bias == ORDER_TYPE_BUY, fvgLow, fvgHigh); // SL beyond FVG or swing

      if( (bias == ORDER_TYPE_BUY && setup.entryPrice < setup.stopLossPrice) ||
          (bias == ORDER_TYPE_SELL && setup.entryPrice > setup.stopLossPrice) )
      {
          Print("Invalid SL for SilverBullet: Entry ", setup.entryPrice, " SL ", setup.stopLossPrice);
          return setup; // Invalid SL
      }

      double riskDistance = MathAbs(setup.entryPrice - setup.stopLossPrice);
      if (riskDistance == 0) return setup; // Avoid division by zero

      setup.tp1Price = bias == ORDER_TYPE_BUY ? setup.entryPrice + riskDistance * TP1_RR : setup.entryPrice - riskDistance * TP1_RR;
      setup.tp2Price = bias == ORDER_TYPE_BUY ? setup.entryPrice + riskDistance * TP2_RR : setup.entryPrice - riskDistance * TP2_RR;
      setup.tp3Price = bias == ORDER_TYPE_BUY ? setup.entryPrice + riskDistance * TP3_RR : setup.entryPrice - riskDistance * TP3_RR;
      setup.isValid = true;
   }
   return setup;
}

//+------------------------------------------------------------------+
//| Check 2022 Model Entry                                           |
//+------------------------------------------------------------------+
TradeSetup Check2022ModelEntry(ENUM_ORDER_TYPE bias)
{
   TradeSetup setup = {false, 0, 0, 0, 0, 0, ORDER_TYPE_BUY, "2022Model", 0};
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, 20, rates) < 20) return setup;

   // 2022 Model: Inducement (sweep of recent swing), MSS, then FVG entry
   bool inducementSwept = false;
   double inducementLevel = 0;
   // For Buy: sweep a recent low. For Sell: sweep a recent high.
   // This is a simplified inducement check; actual inducement can be more nuanced.
   inducementLevel = FindNearestLiquidityLevel(bias == ORDER_TYPE_SELL); // If buying, look for a low to be swept. If selling, a high.
   inducementSwept = CheckLiquiditySweep(inducementLevel, bias == ORDER_TYPE_SELL ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, rates); // Sweeping liquidity against the bias

   bool mssConfirmed = CheckMSS(bias, rates);
   double fvgHigh = 0, fvgLow = 0;
   FindFVG(rates, fvgHigh, fvgLow, bias); // Pass bias

   if(inducementSwept && mssConfirmed && fvgHigh > 0 && fvgLow > 0 && CheckNDOG_NWOG(rates,0))
   {
      setup.orderType = bias;
      setup.entryPrice = CalculateEntryPrice(fvgLow, fvgHigh, Use_OTE_Entry, bias);
      setup.stopLossPrice = FindProtectiveStopLoss(rates, bias == ORDER_TYPE_BUY, fvgLow, fvgHigh);

      if( (bias == ORDER_TYPE_BUY && setup.entryPrice < setup.stopLossPrice) ||
          (bias == ORDER_TYPE_SELL && setup.entryPrice > setup.stopLossPrice) )
      {
          Print("Invalid SL for 2022Model: Entry ", setup.entryPrice, " SL ", setup.stopLossPrice);
          return setup; // Invalid SL
      }

      double riskDistance = MathAbs(setup.entryPrice - setup.stopLossPrice);
      if (riskDistance == 0) return setup;

      setup.tp1Price = bias == ORDER_TYPE_BUY ? setup.entryPrice + riskDistance * TP1_RR : setup.entryPrice - riskDistance * TP1_RR;
      setup.tp2Price = bias == ORDER_TYPE_BUY ? setup.entryPrice + riskDistance * TP2_RR : setup.entryPrice - riskDistance * TP2_RR;
      setup.tp3Price = bias == ORDER_TYPE_BUY ? setup.entryPrice + riskDistance * TP3_RR : setup.entryPrice - riskDistance * TP3_RR;
      setup.isValid = true;
   }
   return setup;
}


//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossPrice, double entryPrice, ENUM_ORDER_TYPE orderType)
{
   if(RiskPercentPerTrade <= 0) return minLot;
   double accountBalance = accountInfo.Balance(); // Or use Equity: accountInfo.Equity();
   double riskAmount = accountBalance * (RiskPercentPerTrade / 100.0);
   double slDistancePips = MathAbs(entryPrice - stopLossPrice) / pointValue / digitsFactor; // SL in standard pips

   if(slDistancePips <= 0)
   {
      Print("Stop Loss distance is zero or invalid. Cannot calculate lot size.");
      return minLot; // Return minLot if SL distance is zero or invalid.
   }

   // Recalculate slDistancePoints correctly for tick value calculation
   double slDistancePointsAbs = MathAbs(entryPrice - stopLossPrice);
   if(slDistancePointsAbs == 0) return minLot; // Should be covered by above, but for safety

   // Get tick value for the specific lot size (usually 1.0)
   // SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) is tick value per 1 lot
   double tickValuePerLot = symbolInfo.TickValue();
   if(tickValuePerLot <= 0)
   {
      Print("Tick value is zero or invalid. Cannot calculate lot size.");
      return minLot;
   }

   // The loss per lot for the given SL distance
   double lossPerLot = (slDistancePointsAbs / symbolInfo.TickSize()) * tickValuePerLot;
   if(lossPerLot <= 0)
   {
       Print("Calculated loss per lot is zero or invalid. SL Distance Points: ", slDistancePointsAbs, " Tick Size: ", symbolInfo.TickSize(), " Tick Value: ", tickValuePerLot);
       return minLot;
   }

   double calculatedLot = riskAmount / lossPerLot;

   // Normalize lot size
   calculatedLot = NormalizeDouble(MathFloor(calculatedLot / lotStep) * lotStep, 2); // Assuming 2 decimal places for lots
   if (lotStep == 0.1) calculatedLot = NormalizeDouble(MathFloor(calculatedLot / lotStep) * lotStep, 1);
   else if (lotStep == 1.0) calculatedLot = NormalizeDouble(MathFloor(calculatedLot / lotStep) * lotStep, 0);


   return MathMax(minLot, MathMin(maxLot, calculatedLot));
}

//+------------------------------------------------------------------+
//| Open Trade                                                       |
//+------------------------------------------------------------------+
bool OpenTrade(TradeSetup &setup)
{
   if(!setup.isValid || setup.lotSize < minLot)
   {
      if(setup.lotSize < minLot) Print("Attempt to open trade with lot size ", setup.lotSize, " < minLot ", minLot);
      return false;
   }

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = setup.lotSize;
   request.magic = magicNumber;
   request.comment = setup.strategyName + " Entry";
   request.sl = NormalizeDouble(setup.stopLossPrice, symbolInfo.Digits());
   request.tp = NormalizeDouble(setup.tp3Price, symbolInfo.Digits()); // Final TP
   request.deviation = 5; // Slippage in points

   if(setup.orderType == ORDER_TYPE_BUY)
   {
      request.type = ORDER_TYPE_BUY;
      request.price = symbolInfo.Ask(); // Market order buy at Ask
   }
   else if(setup.orderType == ORDER_TYPE_SELL)
   {
      request.type = ORDER_TYPE_SELL;
      request.price = symbolInfo.Bid(); // Market order sell at Bid
   }
   else return false;

   request.type_filling = ORDER_FILLING_FOK; // Use direct ENUM - Fill Or Kill
   request.type_time = ORDER_TIME_GTC;

   // Check if entry price makes sense with SL (basic check)
    if (request.type == ORDER_TYPE_BUY && request.price >= request.sl && request.sl != 0) {
        Print("Buy order price ", request.price, " is at or above SL ", request.sl, ". Trade not sent.");
        return false;
    }
    if (request.type == ORDER_TYPE_SELL && request.price <= request.sl && request.sl != 0) {
        Print("Sell order price ", request.price, " is at or below SL ", request.sl, ". Trade not sent.");
        return false;
    }


   if(trade.OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
      {
         PrintFormat("Trade Opened: %s %.2f Lots @ %.5f, SL: %.5f, TP: %.5f, Ticket: %I64u, Strategy: %s",
                     (request.type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
                     request.volume, result.price, request.sl, request.tp, result.order, setup.strategyName);
         StorePartialTPLevels(result.order, setup); // Use result.order as the ticket for the position
         if(ShowTradeLevels)
         {
            // Use result.price as actual entry for drawing
            DrawTradeInfo(result.price, request.sl, request.tp,
                          setup.orderType == ORDER_TYPE_BUY ? BuyLevelColor : SellLevelColor,
                          SLLevelColor, TPLevelColor);
            DrawPartialTPLevel(1, setup.tp1Price);
            DrawPartialTPLevel(2, setup.tp2Price);
            // TP3 is the main TP, already drawn by DrawTradeInfo if ShowTradeLevels is true
         }
         return true;
      }
      else
      {
         Print("OrderSend failed. Retcode: ", result.retcode, ", Error: ", GetLastError(), " - ", trade.ResultRetcodeDescription());
      }
   }
   else
   {
      Print("trade.OrderSend call failed. Error: ", GetLastError());
   }
   return false;
}

//+------------------------------------------------------------------+
//| Manage Open Trades                                               |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   // positionInfo should already be selected by magic number in OnTick
   if(!positionInfo.SelectByMagic(_Symbol, magicNumber)) return; // Double check or if called from elsewhere

   ulong ticket = positionInfo.Ticket();
   double initialVolume = GlobalVariableGet("SL_ICT_EA_" + IntegerToString(magicNumber) + "_" + IntegerToString(ticket) + "_InitVol");

   if(initialVolume == 0) // If for some reason GV not found, use current position volume as fallback (less accurate for partials)
   {
      Print("Warning: Initial volume GV not found for ticket #", ticket, ". Using current volume for partials.");
      initialVolume = positionInfo.Volume(); // This might not be the true initial volume if EA restarted
      // Try to set it if it was missed (e.g. EA restart before StorePartialTPLevels fully completed writing GVs)
      string prefix = "SL_ICT_EA_" + IntegerToString(magicNumber) + "_" + IntegerToString(ticket) + "_";
      if(GlobalVariableCheck(prefix+"IsValid") && GlobalVariableGet(prefix+"IsValid") == 1 && !GlobalVariableCheck(prefix+"InitVol"))
      {
         // This is a rare case, but if other GVs exist, we can try to infer initial volume
         // For now, we'll proceed with the warning. More robust recovery could be added.
      }
   }

   double currentVolume = positionInfo.Volume();
   double entryPrice = positionInfo.PriceOpen();
   double currentSL = positionInfo.StopLoss();
   double currentTP = positionInfo.TakeProfit();
   ENUM_POSITION_TYPE type = positionInfo.PositionType();
   double marketPrice = (type == POSITION_TYPE_BUY) ? symbolInfo.Bid() : symbolInfo.Ask(); // Use Bid for Buy TPs, Ask for Sell TPs

   TradeSetup partialTPs = RetrievePartialTPLevels(ticket);
   if(!partialTPs.isValid)
   {
      // Print("Could not retrieve partial TP levels for ticket #", ticket);
      return;
   }

   bool tp1HitState = HasTPLevelBeenHit(ticket, 1);
   bool tp2HitState = HasTPLevelBeenHit(ticket, 2);

   // TP1 Management
   if(!tp1HitState && partialTPs.tp1Price > 0)
   {
      bool hitCondition = (type == POSITION_TYPE_BUY && marketPrice >= partialTPs.tp1Price) ||
                          (type == POSITION_TYPE_SELL && marketPrice <= partialTPs.tp1Price);
      if(hitCondition)
      {
         double volToClose = initialVolume * (PartialClosePercentTP1 / 100.0);
         volToClose = NormalizeDouble(MathFloor(volToClose / lotStep) * lotStep, (lotStep == 0.01 ? 2: (lotStep == 0.1 ? 1:0) ) );

         if(volToClose >= minLot && currentVolume > volToClose) // Ensure we don't close more than available or less than minLot
         {
            if(trade.PositionClosePartial(ticket, volToClose))
            {
               PrintFormat("TP1 Hit for #%I64u. Closed %.2f lots at %.5f.", ticket, volToClose, marketPrice);
               MarkTPLevelAsHit(ticket, 1);
               currentVolume -= volToClose; // Update current volume locally for subsequent checks in this tick

               if(MoveSLToBE_AfterTP1)
               {
                  double beLevel = entryPrice + (type == POSITION_TYPE_BUY ? BE_PlusPips : -BE_PlusPips) * pointValue * digitsFactor;
                  beLevel = NormalizeDouble(beLevel, symbolInfo.Digits());
                  // Only move SL if it's an improvement and valid
                  if((type == POSITION_TYPE_BUY && beLevel > currentSL) || (type == POSITION_TYPE_SELL && beLevel < currentSL))
                  {
                     if(trade.PositionModify(ticket, beLevel, currentTP))
                        Print("SL moved to BE +", BE_PlusPips, " pips for #", ticket, " to ", beLevel);
                     else
                        Print("Failed to move SL to BE for #", ticket, ". Error: ", GetLastError());
                  }
               }
               ObjectsDeleteAll(0, "SL_ICT_EA_Level_TP1_" + IntegerToString(magicNumber)); // Clean TP1 line
            } else Print("Failed to partially close for TP1 on #", ticket, ". Error: ", GetLastError());
         } else if (volToClose >= currentVolume && currentVolume >= minLot) { // Close remaining if volToClose is more than or equal to what's left
             if(trade.PositionClose(ticket)){
                PrintFormat("TP1 Hit for #%I64u. Closing remaining %.2f lots at %.5f (full close as partial > remaining).", ticket, currentVolume, marketPrice);
                MarkTPLevelAsHit(ticket, 1); // Still mark TP1 as hit
                // GV cleanup will happen in OnTradeTransaction
             } else Print("Failed to close remaining for TP1 on #", ticket, ". Error: ", GetLastError());
             return; // Position is closed
         }
      }
   }

   // TP2 Management (only if TP1 was hit and position still exists)
   // Re-check position existence as TP1 might have closed it all
   if(!positionInfo.SelectByTicket(ticket) || currentVolume < minLot) return;


   if(tp1HitState && !tp2HitState && partialTPs.tp2Price > 0)
   {
      bool hitCondition = (type == POSITION_TYPE_BUY && marketPrice >= partialTPs.tp2Price) ||
                          (type == POSITION_TYPE_SELL && marketPrice <= partialTPs.tp2Price);
      if(hitCondition)
      {
         double volToClose = initialVolume * (PartialClosePercentTP2 / 100.0);
         volToClose = NormalizeDouble(MathFloor(volToClose / lotStep) * lotStep, (lotStep == 0.01 ? 2: (lotStep == 0.1 ? 1:0) ) );

         if(volToClose >= minLot && currentVolume > volToClose)
         {
            if(trade.PositionClosePartial(ticket, volToClose))
            {
               PrintFormat("TP2 Hit for #%I64u. Closed %.2f lots at %.5f.", ticket, volToClose, marketPrice);
               MarkTPLevelAsHit(ticket, 2);
               currentVolume -= volToClose; // Update current volume locally

               // Trailing SL activation/update after TP2
               if (TrailingSL_Pips > 0) {
                  double newSL = (type == POSITION_TYPE_BUY) ?
                                 marketPrice - TrailingSL_Pips * pointValue * digitsFactor :
                                 marketPrice + TrailingSL_Pips * pointValue * digitsFactor;
                  newSL = NormalizeDouble(newSL, symbolInfo.Digits());
                  currentSL = positionInfo.StopLoss(); // Refresh current SL before modify
                  if((type == POSITION_TYPE_BUY && newSL > currentSL) || (type == POSITION_TYPE_SELL && newSL < currentSL))
                  {
                     if(trade.PositionModify(ticket, newSL, currentTP))
                        Print("Trailing SL updated for #", ticket, " to ", newSL);
                     else
                        Print("Failed to update Trailing SL for #", ticket, ". Error: ", GetLastError());
                  }
               }
               ObjectsDeleteAll(0, "SL_ICT_EA_Level_TP2_" + IntegerToString(magicNumber)); // Clean TP2 line
            } else Print("Failed to partially close for TP2 on #", ticket, ". Error: ", GetLastError());
         } else if (volToClose >= currentVolume && currentVolume >= minLot) { // Close remaining
             if(trade.PositionClose(ticket)){
                PrintFormat("TP2 Hit for #%I64u. Closing remaining %.2f lots at %.5f (full close as partial > remaining).", ticket, currentVolume, marketPrice);
                MarkTPLevelAsHit(ticket, 2);
             } else Print("Failed to close remaining for TP2 on #", ticket, ". Error: ", GetLastError());
             return; // Position is closed
         }
      }
   }
   
   // Trailing SL logic (if TP2 already hit, or general trailing if enabled without TP condition)
   // This part assumes TrailingSL_Pips > 0 means trailing is active after TP2
   if(tp2HitState && TrailingSL_Pips > 0 && currentVolume >= minLot)
   {
        // Re-select to get latest SL if modified by BE logic or previous trailing
        if(!positionInfo.SelectByTicket(ticket)) return;
        currentSL = positionInfo.StopLoss();

        double newSL = 0;
        if (type == POSITION_TYPE_BUY)
            newSL = marketPrice - TrailingSL_Pips * pointValue * digitsFactor;
        else
            newSL = marketPrice + TrailingSL_Pips * pointValue * digitsFactor;
        
        newSL = NormalizeDouble(newSL, symbolInfo.Digits());

        bool shouldTrail = (type == POSITION_TYPE_BUY && newSL > currentSL && marketPrice > entryPrice) ||
                           (type == POSITION_TYPE_SELL && newSL < currentSL && marketPrice < entryPrice);

        if (shouldTrail)
        {
            if(trade.PositionModify(ticket, newSL, currentTP))
            {
                // Print("Trailing SL updated for #", ticket, " to ", newSL); // Can be noisy
            }
            // else Print("Failed to update Trailing SL (continuous) for #", ticket, ". Error: ", GetLastError());
        }
   }
}


//+------------------------------------------------------------------+
//| Store Partial TP Levels                                          |
//+------------------------------------------------------------------+
void StorePartialTPLevels(ulong ticket, TradeSetup &setup)
{
   string prefix = "SL_ICT_EA_" + IntegerToString(magicNumber) + "_" + IntegerToString(ticket) + "_";
   GlobalVariableSet(prefix + "TP1", setup.tp1Price);
   GlobalVariableSet(prefix + "TP2", setup.tp2Price);
   GlobalVariableSet(prefix + "TP3", setup.tp3Price); // Store final TP too for reference
   GlobalVariableSet(prefix + "InitVol", setup.lotSize);
   GlobalVariableSet(prefix + "TP1Hit", 0); // 0 for false, 1 for true
   GlobalVariableSet(prefix + "TP2Hit", 0);
   GlobalVariableSet(prefix + "IsValid", 1); // Mark this set of GVs as valid
   GlobalVariablesFlush(); // Ensure GVs are written
}

//+------------------------------------------------------------------+
//| Retrieve Partial TP Levels                                       |
//+------------------------------------------------------------------+
TradeSetup RetrievePartialTPLevels(ulong ticket)
{
   TradeSetup setup = {false, 0, 0, 0, 0, 0, ORDER_TYPE_BUY, "", 0};
   string prefix = "SL_ICT_EA_" + IntegerToString(magicNumber) + "_" + IntegerToString(ticket) + "_";
   if(GlobalVariableCheck(prefix + "IsValid") && GlobalVariableGet(prefix + "IsValid") == 1.0) // GVGet returns double
   {
      setup.tp1Price = GlobalVariableGet(prefix + "TP1");
      setup.tp2Price = GlobalVariableGet(prefix + "TP2");
      setup.tp3Price = GlobalVariableGet(prefix + "TP3");
      setup.lotSize  = GlobalVariableGet(prefix + "InitVol"); // This is initial lot size
      setup.isValid  = true;
   }
   return setup;
}

//+------------------------------------------------------------------+
//| Mark TP Level as Hit                                             |
//+------------------------------------------------------------------+
void MarkTPLevelAsHit(ulong ticket, int tpLevel)
{
   string prefix = "SL_ICT_EA_" + IntegerToString(magicNumber) + "_" + IntegerToString(ticket) + "_";
   string varName = prefix + "TP" + IntegerToString(tpLevel) + "Hit";
   GlobalVariableSet(varName, 1); // Mark as hit
   GlobalVariablesFlush();
}

//+------------------------------------------------------------------+
//| Check if TP Level Has Been Hit                                   |
//+------------------------------------------------------------------+
bool HasTPLevelBeenHit(ulong ticket, int tpLevel)
{
   string prefix = "SL_ICT_EA_" + IntegerToString(magicNumber) + "_" + IntegerToString(ticket) + "_";
   string varName = prefix + "TP" + IntegerToString(tpLevel) + "Hit";
   return GlobalVariableCheck(varName) && GlobalVariableGet(varName) == 1.0; // GVGet returns double
}

//+------------------------------------------------------------------+
//| Draw Trade Info Lines                                            |
//+------------------------------------------------------------------+
void DrawTradeInfo(double entry, double sl, double tp, color entryClr, color slClr, color tpClr)
{
   string entryLineName = "SL_ICT_EA_Level_Entry_" + IntegerToString(magicNumber);
   string slLineName = "SL_ICT_EA_Level_SL_" + IntegerToString(magicNumber);
   string tpLineName = "SL_ICT_EA_Level_TPMain_" + IntegerToString(magicNumber); // Differentiate from partial TP lines

   ObjectDelete(ChartID(), entryLineName);
   ObjectDelete(ChartID(), slLineName);
   ObjectDelete(ChartID(), tpLineName);

   if(entry > 0)
   {
      ObjectCreate(ChartID(), entryLineName, OBJ_HLINE, 0, 0, entry);
      ObjectSetInteger(ChartID(), entryLineName, OBJPROP_COLOR, entryClr);
      ObjectSetInteger(ChartID(), entryLineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(ChartID(), entryLineName, OBJPROP_WIDTH, 2);
      ObjectSetString(ChartID(), entryLineName, OBJPROP_TEXT, "Entry");
   }
   if(sl > 0)
   {
      ObjectCreate(ChartID(), slLineName, OBJ_HLINE, 0, 0, sl);
      ObjectSetInteger(ChartID(), slLineName, OBJPROP_COLOR, slClr);
      ObjectSetInteger(ChartID(), slLineName, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetString(ChartID(), slLineName, OBJPROP_TEXT, "SL");
   }
   if(tp > 0) // This is the main TP (TP3)
   {
      ObjectCreate(ChartID(), tpLineName, OBJ_HLINE, 0, 0, tp);
      ObjectSetInteger(ChartID(), tpLineName, OBJPROP_COLOR, tpClr);
      ObjectSetInteger(ChartID(), tpLineName, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetString(ChartID(), tpLineName, OBJPROP_TEXT, "Main TP");
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Draw Partial TP Level Lines                                      |
//+------------------------------------------------------------------+
void DrawPartialTPLevel(int tpNum, double price)
{
   if(price <= 0 || !ShowTradeLevels) return;
   string lineName = "SL_ICT_EA_Level_TP" + IntegerToString(tpNum) + "_" + IntegerToString(magicNumber);
   ObjectDelete(ChartID(), lineName); // Delete if exists to redraw
   ObjectCreate(ChartID(), lineName, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(ChartID(), lineName, OBJPROP_COLOR, TPLevelColor);
   ObjectSetInteger(ChartID(), lineName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetString(ChartID(), lineName, OBJPROP_TEXT, "TP" + IntegerToString(tpNum));
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| ICT Helper Functions (Refinements can be made based on specific ICT model interpretations) |
//+------------------------------------------------------------------+
double FindNearestLiquidityLevel(bool findHighSweepTarget) // if findHighSweepTarget=true, we are looking for a high to be swept (for a sell setup, or inducement for buy)
{
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 1, DOL_Lookback_Bars, rates) < DOL_Lookback_Bars) // Lookback from bar 1
      return 0;

   double level = 0;
   if(findHighSweepTarget) // find a significant high within lookback
   {
      level = rates[ArraySize(rates)-1].high; // Start with oldest high in lookback
      for(int i = ArraySize(rates)-2; i >= 0; i--)
         if(rates[i].high > level) level = rates[i].high;
   }
   else // find a significant low within lookback
   {
      level = rates[ArraySize(rates)-1].low; // Start with oldest low
      for(int i = ArraySize(rates)-2; i >= 0; i--)
         if(rates[i].low < level) level = rates[i].low;
   }
   return level;
}

// Check if liquidity at 'liquidityLevel' was recently swept by rates[0] or rates[1]
// 'biasForSweepDirection': ORDER_TYPE_BUY if we expect a high to be swept, ORDER_TYPE_SELL if a low.
bool CheckLiquiditySweep(double liquidityLevel, ENUM_ORDER_TYPE biasForSweepDirection, MqlRates &rates[])
{
   if(liquidityLevel == 0 || ArraySize(rates) < 2) return false; // Need at least current and previous bar

   // rates[0] is the current, developing bar. rates[1] is the last closed bar.
   // A sweep usually means price went beyond the level and then retracted.
   // For simplicity, we check if price just went beyond the level on rates[0] or rates[1].
   if(biasForSweepDirection == ORDER_TYPE_BUY) // Expecting a high to be taken (e.g. liquidity above 'liquidityLevel' is swept)
   {
      // Check if current bar's high or previous bar's high took out the liquidityLevel
      if (rates[0].high > liquidityLevel || rates[1].high > liquidityLevel)
      {
         // Optional: Add check for close back below for a more confirmed sweep
         // if (rates[0].close < liquidityLevel) return true;
         return true;
      }
   }
   else if(biasForSweepDirection == ORDER_TYPE_SELL) // Expecting a low to be taken
   {
      if (rates[0].low < liquidityLevel || rates[1].low < liquidityLevel)
      {
         // Optional: Add check for close back above
         // if (rates[0].close > liquidityLevel) return true;
         return true;
      }
   }
   return false;
}


// MSS: Market Structure Shift.
// For BUY bias: Price breaks a previous swing high.
// For SELL bias: Price breaks a previous swing low.
// The original logic was very specific: rates[0].close > rates[1].high && rates[1].close < rates[2].open;
// This is a specific pattern. A more general MSS would look for a break of a recent N-bar high/low.
// Keeping the original logic but adding a comment.
bool CheckMSS(ENUM_ORDER_TYPE bias, MqlRates &rates[])
{
   if(ArraySize(rates) < 3) return false; // Needs at least 3 bars for original logic

   // Original specific MSS logic:
   // This MSS definition is specific. A common MSS involves breaking a swing high/low.
   // The condition `rates[1].close < rates[2].open` (for buy) is particular.
   if(bias == ORDER_TYPE_BUY)
   {
      // Bullish MSS: Current bar closes above previous bar's high,
      // AND previous bar closed below its open (bearish bar before shift?) - this interpretation of rates[1].close < rates[2].open is loose
      // A more standard bullish MSS: current close > significant previous swing high.
      // Original: return rates[0].close > rates[1].high && rates[1].close < rates[2].open;
      // Simplified MSS: Break of previous bar's high strongly.
      return rates[0].close > rates[1].high; // Simplified: Strong close above previous high
   }
   if(bias == ORDER_TYPE_SELL)
   {
      // Bearish MSS: Current bar closes below previous bar's low
      // Original: return rates[0].close < rates[1].low && rates[1].close > rates[2].open;
      // Simplified MSS: Break of previous bar's low strongly.
      return rates[0].close < rates[1].low; // Simplified: Strong close below previous low
   }
   return false;
}

// Find FVG (Fair Value Gap) or Imbalance
// For BUY bias: Look for bullish FVG (gap between low of bar i and high of bar i+2)
// For SELL bias: Look for bearish FVG (gap between high of bar i and low of bar i+2)
// rates[k] is the most recent of the three bars forming the FVG (Candle 1)
// rates[k+1] is the middle bar (Candle 2 - displacement)
// rates[k+2] is the oldest of the three bars (Candle 3)
void FindFVG(MqlRates &rates[], double &fvgHigh, double &fvgLow, ENUM_ORDER_TYPE bias)
{
   fvgHigh = 0; fvgLow = 0;
   if(ArraySize(rates) < 3) return; // Need at least 3 bars to form an FVG

   // Iterate from the most recent possible 3-bar patterns to older ones in the provided 'rates' array.
   // rates[0] is the data for the first bar in the 'rates' array (e.g., current bar if CopyRates started at 0).
   for(int k = 0; k <= ArraySize(rates) - 3; k++)
   {
      // Bullish FVG: Low of Candle 1 (rates[k]) is above High of Candle 3 (rates[k+2]).
      // FVG is (rates[k+2].high, rates[k].low)
      if (bias == ORDER_TYPE_BUY && rates[k].low > rates[k+2].high)
      {
         // Ensure middle candle rates[k+1] (Candle 2) is a strong up move (displacement)
         // and its body/wick helps form the gap.
         if (rates[k+1].close > rates[k+1].open && // Bullish candle
             rates[k+1].high > rates[k+2].high &&  // Middle candle's high clears Candle 3's high
             rates[k+1].low > rates[k+2].high)    // Middle candle's low is also above Candle 3's high (confirming the space for FVG bottom)
         {
            fvgHigh = rates[k].low;   // Top of the bullish FVG (low of Candle 1)
            fvgLow = rates[k+2].high; // Bottom of the bullish FVG (high of Candle 3)
            // PrintFormat("Bullish FVG found: Low=%.5f, High=%.5f. Candles (idx in rates): C1=%d, C2=%d, C3=%d", fvgLow, fvgHigh, k, k+1, k+2);
            break; // Found the most recent FVG in the array, stop searching.
         }
      }
      // Bearish FVG: High of Candle 1 (rates[k]) is below Low of Candle 3 (rates[k+2]).
      // FVG is (rates[k].high, rates[k+2].low)
      else if (bias == ORDER_TYPE_SELL && rates[k].high < rates[k+2].low)
      {
         // Ensure middle candle rates[k+1] (Candle 2) is a strong down move
         if (rates[k+1].close < rates[k+1].open && // Bearish candle
             rates[k+1].low < rates[k+2].low &&    // Middle candle's low clears Candle 3's low
             rates[k+1].high < rates[k+2].low)   // Middle candle's high is also below Candle 3's low (confirming the space for FVG top)
         {
            fvgHigh = rates[k+2].low;  // Top of the bearish FVG (low of Candle 3)
            fvgLow = rates[k].high;   // Bottom of the bearish FVG (high of Candle 1)
            // PrintFormat("Bearish FVG found: Low=%.5f, High=%.5f. Candles (idx in rates): C1=%d, C2=%d, C3=%d", fvgLow, fvgHigh, k, k+1, k+2);
            break; // Found the most recent FVG in the array, stop searching.
         }
      }
   }
}


// Check for NDOG (Narrow Daily Opening Gap) / NWOG (Narrow Weekly Opening Gap) - simplified to small range bar
// This function checks if the range of a specific bar (default rates[0]) is small enough.
bool CheckNDOG_NWOG(MqlRates &rates[], int barIndexToCheck)
{
   if(atrHandle == INVALID_HANDLE || ArraySize(rates) <= barIndexToCheck || barIndexToCheck < 0)
   {
      // Print("ATR Handle invalid or rates array too small for NDOG/NWOG check.");
      return false; // Cannot check
   }

   double atrVal[1];
   if(CopyBuffer(atrHandle, 0, 0, 1, atrVal) < 1) // Get latest ATR value
   {
      Print("Failed to copy ATR buffer for NDOG/NWOG check.");
      return false;
   }

   if(atrVal[0] <= 0) return false; // ATR is zero or negative, invalid

   double threshold = atrVal[0] * NDOG_NWOG_Threshold;
   double barRange = rates[barIndexToCheck].high - rates[barIndexToCheck].low;

   return barRange <= threshold && barRange > 0; // Bar range is small but not zero
}

// Calculate Entry Price based on FVG and OTE option
double CalculateEntryPrice(double fvgLow, double fvgHigh, bool useOTE, ENUM_ORDER_TYPE orderType)
{
   if (fvgLow == 0 || fvgHigh == 0) return 0; // Invalid FVG

   double range = MathAbs(fvgHigh - fvgLow);
   if (range == 0) return (fvgLow + fvgHigh) / 2.0; // Should not happen if FVG is valid

   if (!useOTE)
   {
      return (fvgLow + fvgHigh) / 2.0; // Midpoint of FVG (50% retracement)
   }
   else // Use OTE
   {
      if (orderType == ORDER_TYPE_BUY) // Bullish FVG: fvgHigh is top, fvgLow is bottom
      {
         // OTE entry is between OTE_Lower_Level and OTE_Upper_Level of the FVG range, from bottom
         return fvgLow + range * OTE_Lower_Level; // Enter at the start of OTE zone (e.g., 0.618)
      }
      else // SELL, Bearish FVG: fvgHigh is top, fvgLow is bottom
      {
         // OTE entry from top of FVG
         return fvgHigh - range * OTE_Lower_Level;
      }
   }
}

// Find Protective Stop Loss
// For BUY: below the low of the FVG or recent swing low.
// For SELL: above the high of the FVG or recent swing high.
double FindProtectiveStopLoss(MqlRates &rates[], bool isBuy, double fvgLowPrice, double fvgHighPrice)
{
    if (ArraySize(rates) < 1) return 0;

    double slLevel;
    int lookbackForSL = 3; // Look back N bars for swing point beyond FVG candle structure

    if (isBuy)
    {
        // SL below the FVG's low (fvgLowPrice for bullish FVG)
        // Or below the low of the candle that created the FVG, or recent swing low
        slLevel = fvgLowPrice; // Start with FVG bottom
        // Look for a recent low to place SL under
        for(int i=0; i < lookbackForSL && i < ArraySize(rates); i++) {
            if(rates[i].low < slLevel) slLevel = rates[i].low;
        }
        return slLevel - symbolInfo.Point() * digitsFactor * 2; // SL a bit below the identified low
    }
    else // isSell
    {
        // SL above the FVG's high (fvgHighPrice for bearish FVG)
        slLevel = fvgHighPrice; // Start with FVG top
        for(int i=0; i < lookbackForSL && i < ArraySize(rates); i++) {
            if(rates[i].high > slLevel) slLevel = rates[i].high;
        }
        return slLevel + symbolInfo.Point() * digitsFactor * 2; // SL a bit above the identified high
    }
}

//+------------------------------------------------------------------+
//| Draw ICT Elements                                                |
//+------------------------------------------------------------------+
void DrawICTElements(MqlRates &rates[])
{
   if(!ShowICTElements) return;
   
   // Clean up old objects
   ObjectsDeleteAll(ChartID(), "SL_ICT_EA_FVG_");
   ObjectsDeleteAll(ChartID(), "SL_ICT_EA_LIQ_");
   ObjectsDeleteAll(ChartID(), "SL_ICT_EA_MSS_");
   ObjectsDeleteAll(ChartID(), "SL_ICT_EA_OTE_");
   ObjectsDeleteAll(ChartID(), "SL_ICT_EA_NDOG_");
   
   // Draw Killzone lines
   DrawKillzoneLines();
   
   if(ShowFVG)
   {
      double fvgHigh = 0, fvgLow = 0;
      // Check for both buy and sell FVGs
      FindFVG(rates, fvgHigh, fvgLow, ORDER_TYPE_BUY);
      if(fvgHigh > 0 && fvgLow > 0)
         DrawFVGZone(fvgLow, fvgHigh, true);
         
      FindFVG(rates, fvgHigh, fvgLow, ORDER_TYPE_SELL);
      if(fvgHigh > 0 && fvgLow > 0)
         DrawFVGZone(fvgLow, fvgHigh, false);
   }
   
   if(ShowLiquidity)
   {
      double highLiq = FindNearestLiquidityLevel(true);
      double lowLiq = FindNearestLiquidityLevel(false);
      if(highLiq > 0) DrawLiquidityLevel(highLiq, true);
      if(lowLiq > 0) DrawLiquidityLevel(lowLiq, false);
   }
   
   if(ShowMSS)
   {
      // Check both buy and sell MSS
      if(CheckMSS(ORDER_TYPE_BUY, rates))
         DrawMSSPoint(rates[0].close, true);
      if(CheckMSS(ORDER_TYPE_SELL, rates))
         DrawMSSPoint(rates[0].close, false);
   }
   
   if(ShowOTE && ShowFVG)
   {
      double fvgHigh = 0, fvgLow = 0;
      FindFVG(rates, fvgHigh, fvgLow, ORDER_TYPE_BUY);
      if(fvgHigh > 0 && fvgLow > 0)
         DrawOTEZone(fvgLow, fvgHigh, true);
         
      FindFVG(rates, fvgHigh, fvgLow, ORDER_TYPE_SELL);
      if(fvgHigh > 0 && fvgLow > 0)
         DrawOTEZone(fvgLow, fvgHigh, false);
   }
   
   if(ShowNDOG && CheckNDOG_NWOG(rates, 0))
   {
      DrawNDOGMarker(rates[0].time, rates[0].high, rates[0].low);
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Draw FVG Zone                                                     |
//+------------------------------------------------------------------+
void DrawFVGZone(double low, double high, bool isBullish)
{
   string prefix = "SL_ICT_EA_FVG_" + IntegerToString(magicNumber);
   string rectName = prefix + "_RECT_" + TimeToString(TimeCurrent());
   string labelName = prefix + "_LABEL_" + TimeToString(TimeCurrent());
   
   // Create rectangle for FVG zone
   ObjectCreate(ChartID(), rectName, OBJ_RECTANGLE, 0, TimeCurrent(), low, TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 20, high);
   ObjectSetInteger(ChartID(), rectName, OBJPROP_COLOR, FVGColor);
   ObjectSetInteger(ChartID(), rectName, OBJPROP_FILL, true);
   ObjectSetInteger(ChartID(), rectName, OBJPROP_BACK, true);
   ObjectSetInteger(ChartID(), rectName, OBJPROP_WIDTH, 1);
   
   // Add label
   ObjectCreate(ChartID(), labelName, OBJ_TEXT, 0, TimeCurrent(), high);
   ObjectSetString(ChartID(), labelName, OBJPROP_TEXT, isBullish ? "Bullish FVG" : "Bearish FVG");
   ObjectSetInteger(ChartID(), labelName, OBJPROP_COLOR, FVGColor);
   ObjectSetInteger(ChartID(), labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

//+------------------------------------------------------------------+
//| Draw Liquidity Level                                             |
//+------------------------------------------------------------------+
void DrawLiquidityLevel(double price, bool isHigh)
{
   string prefix = "SL_ICT_EA_LIQ_" + IntegerToString(magicNumber);
   string lineName = prefix + "_" + (isHigh ? "HIGH_" : "LOW_") + TimeToString(TimeCurrent());
   string labelName = prefix + "_LABEL_" + TimeToString(TimeCurrent());
   
   // Create horizontal line
   ObjectCreate(ChartID(), lineName, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(ChartID(), lineName, OBJPROP_COLOR, LiquidityColor);
   ObjectSetInteger(ChartID(), lineName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(ChartID(), lineName, OBJPROP_WIDTH, 1);
   
   // Add label
   ObjectCreate(ChartID(), labelName, OBJ_TEXT, 0, TimeCurrent(), price);
   ObjectSetString(ChartID(), labelName, OBJPROP_TEXT, isHigh ? "High Liquidity" : "Low Liquidity");
   ObjectSetInteger(ChartID(), labelName, OBJPROP_COLOR, LiquidityColor);
   ObjectSetInteger(ChartID(), labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

//+------------------------------------------------------------------+
//| Draw MSS Point                                                    |
//+------------------------------------------------------------------+
void DrawMSSPoint(double price, bool isBullish)
{
   string prefix = "SL_ICT_EA_MSS_" + IntegerToString(magicNumber);
   string arrowName = prefix + "_" + TimeToString(TimeCurrent());
   
   ObjectCreate(ChartID(), arrowName, isBullish ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), price);
   ObjectSetInteger(ChartID(), arrowName, OBJPROP_COLOR, MSSColor);
   ObjectSetInteger(ChartID(), arrowName, OBJPROP_WIDTH, 2);
   ObjectSetString(ChartID(), arrowName, OBJPROP_TEXT, "MSS");
}

//+------------------------------------------------------------------+
//| Draw OTE Zone                                                     |
//+------------------------------------------------------------------+
void DrawOTEZone(double fvgLow, double fvgHigh, bool isBullish)
{
   string prefix = "SL_ICT_EA_OTE_" + IntegerToString(magicNumber);
   string rectName = prefix + "_RECT_" + TimeToString(TimeCurrent());
   string labelName = prefix + "_LABEL_" + TimeToString(TimeCurrent());
   
   double range = MathAbs(fvgHigh - fvgLow);
   double oteLow, oteHigh;
   
   if(isBullish)
   {
      oteLow = fvgLow + range * OTE_Lower_Level;
      oteHigh = fvgLow + range * OTE_Upper_Level;
   }
   else
   {
      oteLow = fvgHigh - range * OTE_Upper_Level;
      oteHigh = fvgHigh - range * OTE_Lower_Level;
   }
   
   // Create rectangle for OTE zone
   ObjectCreate(ChartID(), rectName, OBJ_RECTANGLE, 0, TimeCurrent(), oteLow, TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 20, oteHigh);
   ObjectSetInteger(ChartID(), rectName, OBJPROP_COLOR, OTEColor);
   ObjectSetInteger(ChartID(), rectName, OBJPROP_FILL, true);
   ObjectSetInteger(ChartID(), rectName, OBJPROP_BACK, true);
   ObjectSetInteger(ChartID(), rectName, OBJPROP_WIDTH, 1);
   
   // Add label
   ObjectCreate(ChartID(), labelName, OBJ_TEXT, 0, TimeCurrent(), oteHigh);
   ObjectSetString(ChartID(), labelName, OBJPROP_TEXT, isBullish ? "Bullish OTE" : "Bearish OTE");
   ObjectSetInteger(ChartID(), labelName, OBJPROP_COLOR, OTEColor);
   ObjectSetInteger(ChartID(), labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

//+------------------------------------------------------------------+
//| Draw NDOG/NWOG Marker                                            |
//+------------------------------------------------------------------+
void DrawNDOGMarker(datetime time, double high, double low)
{
   string prefix = "SL_ICT_EA_NDOG_" + IntegerToString(magicNumber);
   string markerName = prefix + "_" + TimeToString(TimeCurrent());
   string labelName = prefix + "_LABEL_" + TimeToString(TimeCurrent());
   
   // Create arrow at the high of the narrow range bar
   ObjectCreate(ChartID(), markerName, OBJ_ARROW_RIGHT_PRICE, 0, time, (high + low) / 2);
   ObjectSetInteger(ChartID(), markerName, OBJPROP_COLOR, NDOGColor);
   ObjectSetInteger(ChartID(), markerName, OBJPROP_WIDTH, 2);
   
   // Add label
   ObjectCreate(ChartID(), labelName, OBJ_TEXT, 0, time, high);
   ObjectSetString(ChartID(), labelName, OBJPROP_TEXT, "NDOG/NWOG");
   ObjectSetInteger(ChartID(), labelName, OBJPROP_COLOR, NDOGColor);
   ObjectSetInteger(ChartID(), labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

//+------------------------------------------------------------------+
//| Draw Killzone Lines                                               |
//+------------------------------------------------------------------+
void DrawKillzoneLines()
{
   if(!ShowKillzones) return;
   
   // Delete old Killzone lines
   ObjectsDeleteAll(ChartID(), "SL_ICT_EA_KZ_");
   
   datetime currentTime = TimeCurrent();
   MqlDateTime currentMqlTime;
   TimeToStruct(currentTime, currentMqlTime);
   
   // Parse Killzone times
   string startHour, startMinute, endHour, endMinute;
   
   // Parse SB_StartTime
   string startComponents[];
   StringSplit(SB_StartTime, ':', startComponents);
   if(ArraySize(startComponents) == 2)
   {
      startHour = startComponents[0];
      startMinute = startComponents[1];
   }
   
   // Parse SB_EndTime
   string endComponents[];
   StringSplit(SB_EndTime, ':', endComponents);
   if(ArraySize(endComponents) == 2)
   {
      endHour = endComponents[0];
      endMinute = endComponents[1];
   }
   
   // Create start time for today's Killzone
   MqlDateTime kzStartTime = currentMqlTime;
   kzStartTime.hour = (int)StringToInteger(startHour);
   kzStartTime.min = (int)StringToInteger(startMinute);
   kzStartTime.sec = 0;
   
   // Create end time for today's Killzone
   MqlDateTime kzEndTime = currentMqlTime;
   kzEndTime.hour = (int)StringToInteger(endHour);
   kzEndTime.min = (int)StringToInteger(endMinute);
   kzEndTime.sec = 0;
   
   // Convert to datetime
   datetime startDateTime = StructToTime(kzStartTime);
   datetime endDateTime = StructToTime(kzEndTime);
   
   // Draw start line
   string startLineName = "SL_ICT_EA_KZ_Start_" + TimeToString(currentTime);
   ObjectCreate(ChartID(), startLineName, OBJ_VLINE, 0, startDateTime, 0);
   ObjectSetInteger(ChartID(), startLineName, OBJPROP_COLOR, KillzoneColor);
   ObjectSetInteger(ChartID(), startLineName, OBJPROP_STYLE, KillzoneStyle);
   ObjectSetInteger(ChartID(), startLineName, OBJPROP_WIDTH, 1);
   ObjectSetString(ChartID(), startLineName, OBJPROP_TEXT, "KZ Start");
   
   // Draw end line
   string endLineName = "SL_ICT_EA_KZ_End_" + TimeToString(currentTime);
   ObjectCreate(ChartID(), endLineName, OBJ_VLINE, 0, endDateTime, 0);
   ObjectSetInteger(ChartID(), endLineName, OBJPROP_COLOR, KillzoneColor);
   ObjectSetInteger(ChartID(), endLineName, OBJPROP_STYLE, KillzoneStyle);
   ObjectSetInteger(ChartID(), endLineName, OBJPROP_WIDTH, 1);
   ObjectSetString(ChartID(), endLineName, OBJPROP_TEXT, "KZ End");
   
   ChartRedraw();
}