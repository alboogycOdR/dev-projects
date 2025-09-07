//+------------------------------------------------------------------+
//|                                                    9AM_CRT_EA.mq5 |
//|                            Professional 9 AM CRT Trading System |
//|                                     Built for Institutional Logic |
//+------------------------------------------------------------------+
#property copyright "CRT Trading System"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Enumerations
enum ENUM_BIAS_DIRECTION {
    BIAS_BULLISH,
    BIAS_BEARISH
};

enum ENUM_ENTRY_TYPE {
    ENTRY_ORDERBLOCK,
    ENTRY_TURTLE_SOUP,
    ENTRY_3_CANDLE
};

enum ENUM_WEEKLY_PROFILE {
    WEEKLY_CLASSIC,
    WEEKLY_MIDWEEK_REVERSAL,
    WEEKLY_CONSOLIDATION_REVERSAL
};

enum ENUM_OPERATION_MODE {
    OP_FULLY_AUTO,
    OP_SIGNALS_ONLY,
    OP_MANUAL
};

//--- Input Parameters
input group "=== CRT Core Settings ==="
input ENUM_TIMEFRAMES TimeframeBias = PERIOD_D1;           // Higher Timeframe for Bias
input ENUM_TIMEFRAMES TimeframeSetup = PERIOD_H1;          // Setup Timeframe (1H for CRT)
input ENUM_TIMEFRAMES TimeframeEntry = PERIOD_M15;         // Entry Timeframe
input bool AutoBias = true;                                // Auto Detect Daily Bias
input ENUM_BIAS_DIRECTION ManualBias = BIAS_BULLISH;       // Manual Bias (if Auto=false)

input group "=== Trading Window ==="
input int NY_Killzone_Start_Hour = 9;                     // NY Killzone Start (Hour)
input int NY_Killzone_Start_Min = 30;                     // NY Killzone Start (Minutes)
input int NY_Killzone_End_Hour = 11;                      // NY Killzone End (Hour)
input int NY_Killzone_End_Min = 0;                        // NY Killzone End (Minutes)

input group "=== Entry Models ==="
input ENUM_ENTRY_TYPE EntryModel = ENTRY_ORDERBLOCK;      // Entry Model
input bool UseAggressiveEntry = false;                    // Enable Turtle Soup Model
input bool Use3CandlePattern = false;                     // Enable 3-Candle Pattern

input group "=== Risk Management ==="
input double RiskPercent = 0.5;                           // Risk Per Trade (%)
input double TP1_Ratio = 0.5;                            // TP1 at 50% of Range
input double TP2_Ratio = 1.0;                            // TP2 at opposite end
input bool MoveToBreakeven = true;                        // Move SL to BE after TP1
input bool UseTrailingStop = true;                        // Use Trailing Stop

input group "=== Advanced Filters ==="
input ENUM_WEEKLY_PROFILE WeeklyProfile = WEEKLY_CLASSIC; // Weekly Profile Filter
input bool UseSMTFilter = false;                          // Enable SMT Divergence Filter
input string SMTSymbol = "US30";                          // SMT Correlation Symbol
input bool UseNewsFilter = true;                          // Enable News Filter
input int NewsAvoidanceMinutes = 30;                      // Minutes to avoid before/after news

input group "=== Operational Mode ==="
input ENUM_OPERATION_MODE OperationMode = OP_FULLY_AUTO;  // Operation Mode
input bool EnableDashboard = true;                        // Show Dashboard
input bool EnableAlerts = true;                           // Enable Alerts

//--- Global Variables
CTrade trade;
CPositionInfo position;
COrderInfo order;

struct CRTSetup {
    double high;
    double low;
    datetime time;
    bool valid;
};

struct HTFKeyLevel {
    double level;
    string type;
    bool valid;
};

struct TradeSignal {
    bool valid;
    int direction;  // 1 for buy, -1 for sell
    double entry;
    double sl;
    double tp1;
    double tp2;
    string reason;
};

//--- Global Structure Variables
CRTSetup g_CRTRange;
HTFKeyLevel g_HTFLevel;
TradeSignal g_CurrentSignal;
ENUM_BIAS_DIRECTION g_CurrentBias;
bool g_RangeSet = false;
bool g_InKillzone = false;
bool g_TradeToday = false;
datetime g_LastProcessedBar = 0;

//--- Dashboard Variables
int g_DashboardX = 20;
int g_DashboardY = 30;
color g_DashboardColor = clrWhite;
color g_BackgroundColor = clrNavy;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("=== 9 AM CRT Expert Advisor Initialized ===");
    
    // Initialize trade object
    trade.SetExpertMagicNumber(123456);
    trade.SetMarginMode();
    trade.SetTypeFillingBySymbol(Symbol());
    
    // Initialize global variables
    g_CRTRange.valid = false;
    g_HTFLevel.valid = false;
    g_CurrentSignal.valid = false;
    g_TradeToday = false;
    
    // Set up dashboard
    if (EnableDashboard) {
        CreateDashboard();
    }
    
    // Initial bias determination
    DetermineDailyBias();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Clean up dashboard objects
    if (EnableDashboard) {
        CleanupDashboard();
    }
    
    Print("=== 9 AM CRT Expert Advisor Deinitialized ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Check if new bar
    if (IsNewBar()) {
        ProcessNewBar();
    }
    
    // Update dashboard
    if (EnableDashboard) {
        UpdateDashboard();
    }
    
    // Check for trade management
    ManageOpenTrades();
    
    // Main CRT logic
    ProcessCRTLogic();
}

//+------------------------------------------------------------------+
//| Check if new bar has formed                                     |
//+------------------------------------------------------------------+
bool IsNewBar() {
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(Symbol(), TimeframeEntry, 0);
    
    if (currentBarTime != lastBarTime) {
        lastBarTime = currentBarTime;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Process new bar logic                                           |
//+------------------------------------------------------------------+
void ProcessNewBar() {
    // Reset daily variables if new day
    if (IsNewDay()) {
        ResetDailyVariables();
        DetermineDailyBias();
        IdentifyHTFKeyLevel();
    }
    
    // Check if it's time to set the CRT range (8 AM NY close)
    if (IsTimeToSetCRTRange()) {
        SetCRTRange();
    }
    
    // Update killzone status
    g_InKillzone = IsInKillzone();
}

//+------------------------------------------------------------------+
//| Check if new day                                                |
//+------------------------------------------------------------------+
bool IsNewDay() {
    static int lastDay = -1;
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    if (dt.day != lastDay) {
        lastDay = dt.day;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Reset daily variables                                           |
//+------------------------------------------------------------------+
void ResetDailyVariables() {
    g_CRTRange.valid = false;
    g_HTFLevel.valid = false;
    g_CurrentSignal.valid = false;
    g_TradeToday = false;
    g_RangeSet = false;
    
    // Clear range lines
    ObjectDelete(0, "CRT_High");
    ObjectDelete(0, "CRT_Low");
    ObjectDelete(0, "HTF_Level");
}

//+------------------------------------------------------------------+
//| Determine daily bias                                            |
//+------------------------------------------------------------------+
void DetermineDailyBias() {
    if (AutoBias) {
        // Auto-detect bias based on recent price action
        double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double dailyHigh = iHigh(Symbol(), PERIOD_D1, 1);
        double dailyLow = iLow(Symbol(), PERIOD_D1, 1);
        double dailyMid = (dailyHigh + dailyLow) / 2;
        
        // Simple bias logic - can be enhanced
        if (currentPrice > dailyMid) {
            g_CurrentBias = BIAS_BULLISH;
        } else {
            g_CurrentBias = BIAS_BEARISH;
        }
    } else {
        g_CurrentBias = ManualBias;
    }
    
    Print("Daily Bias Set: ", (g_CurrentBias == BIAS_BULLISH) ? "BULLISH" : "BEARISH");
}

//+------------------------------------------------------------------+
//| Identify HTF Key Level                                          |
//+------------------------------------------------------------------+
void IdentifyHTFKeyLevel() {
    // This is a simplified version - in practice, you'd implement
    // sophisticated order block, FVG, and breaker block detection
    
    double h4_high = iHigh(Symbol(), PERIOD_H4, 1);
    double h4_low = iLow(Symbol(), PERIOD_H4, 1);
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    
    if (g_CurrentBias == BIAS_BULLISH) {
        // Look for support level below current price
        g_HTFLevel.level = h4_low;
        g_HTFLevel.type = "H4 Support";
        g_HTFLevel.valid = true;
    } else {
        // Look for resistance level above current price
        g_HTFLevel.level = h4_high;
        g_HTFLevel.type = "H4 Resistance";
        g_HTFLevel.valid = true;
    }
    
    // Draw HTF level on chart
    if (g_HTFLevel.valid) {
        ObjectCreate(0, "HTF_Level", OBJ_HLINE, 0, 0, g_HTFLevel.level);
        ObjectSetInteger(0, "HTF_Level", OBJPROP_COLOR, clrYellow);
        ObjectSetInteger(0, "HTF_Level", OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, "HTF_Level", OBJPROP_STYLE, STYLE_DOT);
    }
}

//+------------------------------------------------------------------+
//| Check if it's time to set CRT range                            |
//+------------------------------------------------------------------+
bool IsTimeToSetCRTRange() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    // Check if it's exactly 8 AM NY time close (9 AM start)
    if (dt.hour == 9 && dt.min == 0 && !g_RangeSet) {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Set CRT Range from 8 AM NY hourly candle                       |
//+------------------------------------------------------------------+
void SetCRTRange() {
    // Get the 8 AM NY hourly candle (previous H1 candle)
    double h1_high = iHigh(Symbol(), PERIOD_H1, 1);
    double h1_low = iLow(Symbol(), PERIOD_H1, 1);
    datetime h1_time = iTime(Symbol(), PERIOD_H1, 1);
    
    g_CRTRange.high = h1_high;
    g_CRTRange.low = h1_low;
    g_CRTRange.time = h1_time;
    g_CRTRange.valid = true;
    g_RangeSet = true;
    
    // Draw CRT range on chart
    ObjectCreate(0, "CRT_High", OBJ_HLINE, 0, 0, g_CRTRange.high);
    ObjectSetInteger(0, "CRT_High", OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, "CRT_High", OBJPROP_WIDTH, 2);
    
    ObjectCreate(0, "CRT_Low", OBJ_HLINE, 0, 0, g_CRTRange.low);
    ObjectSetInteger(0, "CRT_Low", OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, "CRT_Low", OBJPROP_WIDTH, 2);
    
    Print("CRT Range Set - High: ", g_CRTRange.high, " Low: ", g_CRTRange.low);
}

//+------------------------------------------------------------------+
//| Check if in killzone                                           |
//+------------------------------------------------------------------+
bool IsInKillzone() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    int currentMinutes = dt.hour * 60 + dt.min;
    int startMinutes = NY_Killzone_Start_Hour * 60 + NY_Killzone_Start_Min;
    int endMinutes = NY_Killzone_End_Hour * 60 + NY_Killzone_End_Min;
    
    return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
}

//+------------------------------------------------------------------+
//| Main CRT Processing Logic                                       |
//+------------------------------------------------------------------+
void ProcessCRTLogic() {
    // Only process if we have valid CRT range and we're in killzone
    if (!g_CRTRange.valid || !g_InKillzone || g_TradeToday) {
        return;
    }
    
    // Check for liquidity sweep
    if (CheckLiquiditySweep()) {
        // Generate trade signal based on entry model
        GenerateTradeSignal();
        
        // Execute trade if signal is valid
        if (g_CurrentSignal.valid) {
            ExecuteTrade();
        }
    }
}

//+------------------------------------------------------------------+
//| Check for liquidity sweep                                       |
//+------------------------------------------------------------------+
bool CheckLiquiditySweep() {
    double currentHigh = iHigh(Symbol(), TimeframeEntry, 0);
    double currentLow = iLow(Symbol(), TimeframeEntry, 0);
    double currentClose = iClose(Symbol(), TimeframeEntry, 0);
    
    // Check for sweep of CRT high
    if (currentHigh > g_CRTRange.high && currentClose < g_CRTRange.high) {
        if (g_CurrentBias == BIAS_BEARISH) {
            Print("Bearish liquidity sweep detected - High swept and rejected");
            return true;
        }
    }
    
    // Check for sweep of CRT low
    if (currentLow < g_CRTRange.low && currentClose > g_CRTRange.low) {
        if (g_CurrentBias == BIAS_BULLISH) {
            Print("Bullish liquidity sweep detected - Low swept and rejected");
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Generate trade signal                                           |
//+------------------------------------------------------------------+
void GenerateTradeSignal() {
    g_CurrentSignal.valid = false;
    
    if (EntryModel == ENTRY_ORDERBLOCK) {
        GenerateOrderBlockSignal();
    } else if (EntryModel == ENTRY_TURTLE_SOUP) {
        GenerateTurtleSoupSignal();
    } else if (EntryModel == ENTRY_3_CANDLE) {
        Generate3CandleSignal();
    }
}

//+------------------------------------------------------------------+
//| Generate Order Block Signal                                     |
//+------------------------------------------------------------------+
void GenerateOrderBlockSignal() {
    // Simplified order block logic
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double currentAsk = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    
    if (g_CurrentBias == BIAS_BULLISH) {
        // Look for bullish order block after low sweep
        g_CurrentSignal.direction = 1;
        g_CurrentSignal.entry = currentAsk;
        g_CurrentSignal.sl = g_CRTRange.low - (10 * Point());
        g_CurrentSignal.tp1 = g_CRTRange.low + (g_CRTRange.high - g_CRTRange.low) * TP1_Ratio;
        g_CurrentSignal.tp2 = g_CRTRange.high;
        g_CurrentSignal.reason = "Bullish Order Block Entry";
        g_CurrentSignal.valid = true;
    } else {
        // Look for bearish order block after high sweep
        g_CurrentSignal.direction = -1;
        g_CurrentSignal.entry = currentPrice;
        g_CurrentSignal.sl = g_CRTRange.high + (10 * Point());
        g_CurrentSignal.tp1 = g_CRTRange.high - (g_CRTRange.high - g_CRTRange.low) * TP1_Ratio;
        g_CurrentSignal.tp2 = g_CRTRange.low;
        g_CurrentSignal.reason = "Bearish Order Block Entry";
        g_CurrentSignal.valid = true;
    }
}

//+------------------------------------------------------------------+
//| Generate Turtle Soup Signal                                     |
//+------------------------------------------------------------------+
void GenerateTurtleSoupSignal() {
    // Aggressive entry immediately after sweep
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double currentAsk = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    
    if (g_CurrentBias == BIAS_BULLISH) {
        g_CurrentSignal.direction = 1;
        g_CurrentSignal.entry = currentAsk;
        g_CurrentSignal.sl = g_CRTRange.low - (15 * Point());
        g_CurrentSignal.tp1 = g_CRTRange.low + (g_CRTRange.high - g_CRTRange.low) * TP1_Ratio;
        g_CurrentSignal.tp2 = g_CRTRange.high;
        g_CurrentSignal.reason = "Turtle Soup Bullish Entry";
        g_CurrentSignal.valid = true;
    } else {
        g_CurrentSignal.direction = -1;
        g_CurrentSignal.entry = currentPrice;
        g_CurrentSignal.sl = g_CRTRange.high + (15 * Point());
        g_CurrentSignal.tp1 = g_CRTRange.high - (g_CRTRange.high - g_CRTRange.low) * TP1_Ratio;
        g_CurrentSignal.tp2 = g_CRTRange.low;
        g_CurrentSignal.reason = "Turtle Soup Bearish Entry";
        g_CurrentSignal.valid = true;
    }
}

//+------------------------------------------------------------------+
//| Generate 3-Candle Pattern Signal                                |
//+------------------------------------------------------------------+
void Generate3CandleSignal() {
    // Classic 3-candle pattern logic
    // This is a simplified version - would need more sophisticated pattern recognition
    
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double currentAsk = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    
    // Check for 3-candle pattern completion
    if (g_CurrentBias == BIAS_BULLISH) {
        g_CurrentSignal.direction = 1;
        g_CurrentSignal.entry = currentAsk;
        g_CurrentSignal.sl = g_CRTRange.low - (5 * Point());
        g_CurrentSignal.tp1 = g_CRTRange.low + (g_CRTRange.high - g_CRTRange.low) * TP1_Ratio;
        g_CurrentSignal.tp2 = g_CRTRange.high;
        g_CurrentSignal.reason = "3-Candle Pattern Bullish";
        g_CurrentSignal.valid = true;
    } else {
        g_CurrentSignal.direction = -1;
        g_CurrentSignal.entry = currentPrice;
        g_CurrentSignal.sl = g_CRTRange.high + (5 * Point());
        g_CurrentSignal.tp1 = g_CRTRange.high - (g_CRTRange.high - g_CRTRange.low) * TP1_Ratio;
        g_CurrentSignal.tp2 = g_CRTRange.low;
        g_CurrentSignal.reason = "3-Candle Pattern Bearish";
        g_CurrentSignal.valid = true;
    }
}

//+------------------------------------------------------------------+
//| Execute trade                                                   |
//+------------------------------------------------------------------+
void ExecuteTrade() {
    if (!g_CurrentSignal.valid) return;
    
    // Calculate lot size based on risk
    double lotSize = CalculateLotSize();
    if (lotSize <= 0) {
        Print("Invalid lot size calculated: ", lotSize, ". Aborting trade.");
        return;
    }

    // --- Price validation, normalization, and adjustment ---
    double sl = NormalizeDouble(g_CurrentSignal.sl, Digits());
    double tp = NormalizeDouble(g_CurrentSignal.tp1, Digits());

    // Refresh rates right before validation
    MqlTick current_tick;
    if(!SymbolInfoTick(Symbol(), current_tick)) {
        Print("SymbolInfoTick failed. Error ", GetLastError());
        return;
    }
    double ask = current_tick.ask;
    double bid = current_tick.bid;
    
    double stop_level_points = (double)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
    double stop_level_price = stop_level_points * Point();
    
    Print("Initial Check. SL=", sl, ", TP=", tp, ", Bid=", bid, ", Ask=", ask, ", StopLevel=", stop_level_points, "pts");

    if (OperationMode == OP_FULLY_AUTO) {
        bool result = false;
        
        if (g_CurrentSignal.direction == 1) { // Buy Order
            // Adjust SL if too close
            if (ask - sl < stop_level_price) {
                Print("SL for BUY is too close. Adjusting...");
                sl = ask - stop_level_price;
                Print("Adjusted SL: ", sl);
            }
            // Adjust TP if too close
            if (tp - ask < stop_level_price) {
                Print("TP for BUY is too close. Adjusting...");
                tp = ask + stop_level_price;
                Print("Adjusted TP: ", tp);
            }
            
            // Final validation
            if (sl >= ask || tp <= ask) {
                Print("Trade invalid after adjustments. SL: ", sl, " TP: ", tp, " Ask: ", ask);
                return;
            }
            result = trade.Buy(lotSize, Symbol(), 0, /*sl*/NULL , tp, g_CurrentSignal.reason);

        } else { // Sell Order
            // Adjust SL if too close
            if (sl - bid < stop_level_price) {
                Print("SL for SELL is too close. Adjusting...");
                sl = bid + stop_level_price;
                Print("Adjusted SL: ", sl);
            }
            // Adjust TP if too close
            if (bid - tp < stop_level_price) {
                Print("TP for SELL is too close. Adjusting...");
                tp = bid - stop_level_price;
                Print("Adjusted TP: ", tp);
            }

            // Final validation
            if (sl <= bid || tp >= bid) {
                Print("Trade invalid after adjustments. SL: ", sl, " TP: ", tp, " Bid: ", bid);
                return;
            }
            result = trade.Sell(lotSize, Symbol(), 0, /*sl*/NULL, tp, g_CurrentSignal.reason);
        }
        
        if (result) {
            Print("Trade executed successfully: ", g_CurrentSignal.reason);
            g_TradeToday = true;
        } else {
            Print("Trade execution failed. Reason: ", trade.ResultComment(), " (Code: ", trade.ResultRetcode(), ")");
        }
    } else if (OperationMode == OP_SIGNALS_ONLY) {
        // Send alert
        if (EnableAlerts) {
            string alertMsg = "CRT Signal: " + g_CurrentSignal.reason + 
                            " Entry: " + DoubleToString(g_CurrentSignal.entry, Digits()) +
                            " SL: " + DoubleToString(g_CurrentSignal.sl, Digits()) +
                            " TP1: " + DoubleToString(g_CurrentSignal.tp1, Digits());
            Alert(alertMsg);
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                |
//+------------------------------------------------------------------+
double CalculateLotSize() {
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (RiskPercent / 100);
    double stopLossPips = MathAbs(g_CurrentSignal.entry - g_CurrentSignal.sl) / Point();
    
    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double lotSize = riskAmount / (stopLossPips * tickValue);
    
    // Normalize lot size
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    lotSize = MathRound(lotSize / lotStep) * lotStep;
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Manage open trades                                              |
//+------------------------------------------------------------------+
void ManageOpenTrades() {
    if (!position.Select(Symbol())) return;
    
    // Move to breakeven after TP1 is hit
    if (MoveToBreakeven) {
        // Implementation would check if TP1 level is reached
        // and modify stop loss to entry price
    }
    
    // Trailing stop logic
    if (UseTrailingStop) {
        // Implementation would trail stop loss based on M15 structure
    }
}

//+------------------------------------------------------------------+
//| Create dashboard                                                |
//+------------------------------------------------------------------+
void CreateDashboard() {
    // Create dashboard background
    ObjectCreate(0, "Dashboard_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_XDISTANCE, g_DashboardX);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_YDISTANCE, g_DashboardY);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_XSIZE, 300);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_YSIZE, 200);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_COLOR, g_BackgroundColor);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_BGCOLOR, g_BackgroundColor);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_BORDER_COLOR, clrWhite);
    ObjectSetInteger(0, "Dashboard_BG", OBJPROP_WIDTH, 1);
    
    // Create text labels
    CreateDashboardLabel("Dashboard_Title", "=== 9 AM CRT EA ===", 0, 0, clrWhite, 12);
    CreateDashboardLabel("Dashboard_Bias", "Bias: ", 0, 25, clrWhite, 10);
    CreateDashboardLabel("Dashboard_Range", "CRT Range: ", 0, 45, clrWhite, 10);
    CreateDashboardLabel("Dashboard_HTF", "HTF Level: ", 0, 65, clrWhite, 10);
    CreateDashboardLabel("Dashboard_Status", "Status: ", 0, 85, clrWhite, 10);
    CreateDashboardLabel("Dashboard_Signal", "Signal: ", 0, 105, clrWhite, 10);
}

//+------------------------------------------------------------------+
//| Create dashboard label                                          |
//+------------------------------------------------------------------+
void CreateDashboardLabel(string name, string text, int x, int y, color clr, int size) {
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, g_DashboardX + 10 + x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, g_DashboardY + 10 + y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial");
}

//+------------------------------------------------------------------+
//| Update dashboard                                                |
//+------------------------------------------------------------------+
void UpdateDashboard() {
    if (!EnableDashboard) return;
    
    // Update bias
    string biasText = "Bias: " + ((g_CurrentBias == BIAS_BULLISH) ? "BULLISH" : "BEARISH");
    ObjectSetString(0, "Dashboard_Bias", OBJPROP_TEXT, biasText);
    
    // Update range
    string rangeText = "CRT Range: ";
    if (g_CRTRange.valid) {
        rangeText += DoubleToString(g_CRTRange.high, Digits()) + " / " + DoubleToString(g_CRTRange.low, Digits());
    } else {
        rangeText += "Not Set";
    }
    ObjectSetString(0, "Dashboard_Range", OBJPROP_TEXT, rangeText);
    
    // Update HTF level
    string htfText = "HTF Level: ";
    if (g_HTFLevel.valid) {
        htfText += g_HTFLevel.type + " @ " + DoubleToString(g_HTFLevel.level, Digits());
    } else {
        htfText += "Not Identified";
    }
    ObjectSetString(0, "Dashboard_HTF", OBJPROP_TEXT, htfText);
    
    // Update status
    string statusText = "Status: ";
    if (g_InKillzone) {
        statusText += "IN KILLZONE";
        ObjectSetInteger(0, "Dashboard_Status", OBJPROP_COLOR, clrLime);
    } else {
        statusText += "Outside Killzone";
        ObjectSetInteger(0, "Dashboard_Status", OBJPROP_COLOR, clrGray);
    }
    ObjectSetString(0, "Dashboard_Status", OBJPROP_TEXT, statusText);
    
    // Update signal
    string signalText = "Signal: ";
    if (g_CurrentSignal.valid) {
        signalText += g_CurrentSignal.reason;
        ObjectSetInteger(0, "Dashboard_Signal", OBJPROP_COLOR, clrYellow);
    } else {
        signalText += "Waiting...";
        ObjectSetInteger(0, "Dashboard_Signal", OBJPROP_COLOR, clrGray);
    }
    ObjectSetString(0, "Dashboard_Signal", OBJPROP_TEXT, signalText);
}

//+------------------------------------------------------------------+
//| Cleanup dashboard                                               |
//+------------------------------------------------------------------+
void CleanupDashboard() {
    ObjectDelete(0, "Dashboard_BG");
    ObjectDelete(0, "Dashboard_Title");
    ObjectDelete(0, "Dashboard_Bias");
    ObjectDelete(0, "Dashboard_Range");
    ObjectDelete(0, "Dashboard_HTF");
    ObjectDelete(0, "Dashboard_Status");
    ObjectDelete(0, "Dashboard_Signal");
}

//+------------------------------------------------------------------+
//| Chart event handler                                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    // Handle manual trading buttons if in manual mode
    if (OperationMode == OP_MANUAL) {
        if (id == CHARTEVENT_OBJECT_CLICK) {
            if (sparam == "ManualBuy") {
                // Execute manual buy
                if (g_CurrentSignal.valid && g_CurrentSignal.direction == 1) {
                    double lotSize = CalculateLotSize();
                    trade.Buy(lotSize, Symbol(), g_CurrentSignal.entry, g_CurrentSignal.sl, g_CurrentSignal.tp1);
                }
            } else if (sparam == "ManualSell") {
                // Execute manual sell
                if (g_CurrentSignal.valid && g_CurrentSignal.direction == -1) {
                    double lotSize = CalculateLotSize();
                    trade.Sell(lotSize, Symbol(), g_CurrentSignal.entry, g_CurrentSignal.sl, g_CurrentSignal.tp1);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| News Filter Implementation                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNewsTime() {
    if (!UseNewsFilter) return false;
    
    // Simplified news filter - in production, you'd integrate with
    // a news API or calendar service
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    // Example: Avoid trading during common news times
    // NFP (First Friday of month at 8:30 AM ET)
    if (dt.day_of_week == 5 && dt.day <= 7 && dt.hour == 8 && dt.min >= 0 && dt.min <= 60) {
        return true;
    }
    
    // CPI (Usually mid-month at 8:30 AM ET)
    if (dt.day >= 10 && dt.day <= 16 && dt.hour == 8 && dt.min >= 0 && dt.min <= 60) {
        return true;
    }
    
    // FOMC (8 times per year, usually 2:00 PM ET)
    if (dt.hour == 14 && dt.min >= 0 && dt.min <= 60) {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| SMT Divergence Filter Implementation                            |
//+------------------------------------------------------------------+
bool CheckSMTDivergence() {
    if (!UseSMTFilter) return true;
    
    // Simplified SMT divergence check
    // In production, you'd implement sophisticated correlation analysis
    
    double currentSymbolPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double smtSymbolPrice = SymbolInfoDouble(SMTSymbol, SYMBOL_BID);
    
    // Get previous prices for comparison
    double prevSymbolPrice = iClose(Symbol(), PERIOD_M15, 1);
    double prevSMTPrice = iClose(SMTSymbol, PERIOD_M15, 1);
    
    // Check for divergence
    bool symbolRising = currentSymbolPrice > prevSymbolPrice;
    bool smtRising = smtSymbolPrice > prevSMTPrice;
    
    // SMT divergence occurs when one moves up and the other moves down
    if (symbolRising != smtRising) {
        Print("SMT Divergence detected between ", Symbol(), " and ", SMTSymbol);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Weekly Profile Filter Implementation                            |
//+------------------------------------------------------------------+
bool IsValidForWeeklyProfile() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    switch (WeeklyProfile) {
        case WEEKLY_CLASSIC:
            // Classic expansion: Look for continuation Monday-Wednesday
            if (dt.day_of_week >= 1 && dt.day_of_week <= 3) {
                return true;
            }
            break;
            
        case WEEKLY_MIDWEEK_REVERSAL:
            // Midweek reversal: Look for reversals Tuesday-Thursday
            if (dt.day_of_week >= 2 && dt.day_of_week <= 4) {
                return true;
            }
            break;
            
        case WEEKLY_CONSOLIDATION_REVERSAL:
            // Consolidation reversal: Look for reversals Wednesday-Friday
            if (dt.day_of_week >= 3 && dt.day_of_week <= 5) {
                return true;
            }
            break;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Advanced Order Block Detection                                  |
//+------------------------------------------------------------------+
bool DetectOrderBlock(int direction) {
    // Simplified order block detection
    // In production, you'd implement sophisticated algorithms
    
    double currentClose = iClose(Symbol(), PERIOD_M15, 0);
    double prevClose = iClose(Symbol(), PERIOD_M15, 1);
    double prevOpen = iOpen(Symbol(), PERIOD_M15, 1);
    
    if (direction == 1) { // Bullish order block
        // Look for a bearish candle followed by bullish movement
        if (prevClose < prevOpen && currentClose > prevClose) {
            return true;
        }
    } else { // Bearish order block
        // Look for a bullish candle followed by bearish movement
        if (prevClose > prevOpen && currentClose < prevClose) {
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Fair Value Gap Detection                                        |
//+------------------------------------------------------------------+
bool DetectFairValueGap(int direction) {
    // Simplified FVG detection
    double high1 = iHigh(Symbol(), PERIOD_M15, 2);
    double low1 = iLow(Symbol(), PERIOD_M15, 2);
    double high2 = iHigh(Symbol(), PERIOD_M15, 1);
    double low2 = iLow(Symbol(), PERIOD_M15, 1);
    double high3 = iHigh(Symbol(), PERIOD_M15, 0);
    double low3 = iLow(Symbol(), PERIOD_M15, 0);
    
    if (direction == 1) { // Bullish FVG
        // Check if there's a gap between candle 1 high and candle 3 low
        if (low3 > high1 && low2 > high1) {
            return true;
        }
    } else { // Bearish FVG
        // Check if there's a gap between candle 1 low and candle 3 high
        if (high3 < low1 && high2 < low1) {
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Market Structure Shift Detection                                |
//+------------------------------------------------------------------+
bool DetectMarketStructureShift(int direction) {
    // Simplified MSS detection
    // Look for break of previous high/low
    
    double prevHigh = iHigh(Symbol(), PERIOD_M15, 1);
    double prevLow = iLow(Symbol(), PERIOD_M15, 1);
    double currentHigh = iHigh(Symbol(), PERIOD_M15, 0);
    double currentLow = iLow(Symbol(), PERIOD_M15, 0);
    
    if (direction == 1) { // Bullish MSS
        // Current high breaks previous high
        if (currentHigh > prevHigh) {
            return true;
        }
    } else { // Bearish MSS
        // Current low breaks previous low
        if (currentLow < prevLow) {
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Enhanced Trade Signal Generation with Filters                   |
//+------------------------------------------------------------------+
void GenerateEnhancedTradeSignal() {
    // Reset signal
    g_CurrentSignal.valid = false;
    
    // Check all filters first
    if (IsHighImpactNewsTime()) {
        Print("High impact news time - skipping trade");
        return;
    }
    
    if (!CheckSMTDivergence()) {
        Print("SMT divergence not confirmed - skipping trade");
        return;
    }
    
    if (!IsValidForWeeklyProfile()) {
        Print("Trade not valid for current weekly profile - skipping trade");
        return;
    }
    
    // Generate signal based on selected entry model
    GenerateTradeSignal();
}

//+------------------------------------------------------------------+
//| Enhanced Position Management                                     |
//+------------------------------------------------------------------+
void EnhancedPositionManagement() {
    if (!position.Select(Symbol())) return;
    
    double currentPrice = (position.PositionType() == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                         SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    
    // Check if TP1 has been hit
    if (MoveToBreakeven) {
        if (position.PositionType() == POSITION_TYPE_BUY) {
            if (currentPrice >= g_CurrentSignal.tp1 && position.StopLoss() < position.PriceOpen()) {
                trade.PositionModify(position.Ticket(), position.PriceOpen() + 1*Point(), position.TakeProfit());
                Print("Stop loss moved to breakeven");
            }
        } else {
            if (currentPrice <= g_CurrentSignal.tp1 && position.StopLoss() > position.PriceOpen()) {
                trade.PositionModify(position.Ticket(), position.PriceOpen() - 1*Point(), position.TakeProfit());
                Print("Stop loss moved to breakeven");
            }
        }
    }
    
    // Trailing stop based on market structure
    if (UseTrailingStop) {
        TrailStopByMarketStructure();
    }
}

//+------------------------------------------------------------------+
//| Trail Stop Loss by Market Structure                             |
//+------------------------------------------------------------------+
void TrailStopByMarketStructure() {
    if (!position.Select(Symbol())) return;
    
    // Get recent swing highs/lows for trailing
    double swingHigh = 0, swingLow = 0;
    
    // Find recent swing points (simplified)
    for (int i = 1; i <= 10; i++) {
        double high = iHigh(Symbol(), PERIOD_M15, i);
        double low = iLow(Symbol(), PERIOD_M15, i);
        
        if (swingHigh == 0 || high > swingHigh) swingHigh = high;
        if (swingLow == 0 || low < swingLow) swingLow = low;
    }
    
    if (position.PositionType() == POSITION_TYPE_BUY) {
        double newSL = swingLow - 5*Point();
        if (newSL > position.StopLoss()) {
            trade.PositionModify(position.Ticket(), newSL, position.TakeProfit());
            Print("Trailing stop updated to: ", newSL);
        }
    } else {
        double newSL = swingHigh + 5*Point();
        if (newSL < position.StopLoss()) {
            trade.PositionModify(position.Ticket(), newSL, position.TakeProfit());
            Print("Trailing stop updated to: ", newSL);
        }
    }
}

//+------------------------------------------------------------------+
//| Create Manual Trading Panel                                     |
//+------------------------------------------------------------------+
void CreateManualTradingPanel() {
    if (OperationMode != OP_MANUAL) return;
    
    // Create Buy button
    ObjectCreate(0, "ManualBuy", OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, "ManualBuy", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "ManualBuy", OBJPROP_XDISTANCE, g_DashboardX + 10);
    ObjectSetInteger(0, "ManualBuy", OBJPROP_YDISTANCE, g_DashboardY + 130);
    ObjectSetInteger(0, "ManualBuy", OBJPROP_XSIZE, 60);
    ObjectSetInteger(0, "ManualBuy", OBJPROP_YSIZE, 30);
    ObjectSetString(0, "ManualBuy", OBJPROP_TEXT, "BUY");
    ObjectSetInteger(0, "ManualBuy", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "ManualBuy", OBJPROP_BGCOLOR, clrGreen);
    ObjectSetInteger(0, "ManualBuy", OBJPROP_BORDER_COLOR, clrWhite);
    
    // Create Sell button
    ObjectCreate(0, "ManualSell", OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, "ManualSell", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "ManualSell", OBJPROP_XDISTANCE, g_DashboardX + 80);
    ObjectSetInteger(0, "ManualSell", OBJPROP_YDISTANCE, g_DashboardY + 130);
    ObjectSetInteger(0, "ManualSell", OBJPROP_XSIZE, 60);
    ObjectSetInteger(0, "ManualSell", OBJPROP_YSIZE, 30);
    ObjectSetString(0, "ManualSell", OBJPROP_TEXT, "SELL");
    ObjectSetInteger(0, "ManualSell", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "ManualSell", OBJPROP_BGCOLOR, clrRed);
    ObjectSetInteger(0, "ManualSell", OBJPROP_BORDER_COLOR, clrWhite);
    
    // Create Close All button
    ObjectCreate(0, "CloseAll", OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, "CloseAll", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "CloseAll", OBJPROP_XDISTANCE, g_DashboardX + 150);
    ObjectSetInteger(0, "CloseAll", OBJPROP_YDISTANCE, g_DashboardY + 130);
    ObjectSetInteger(0, "CloseAll", OBJPROP_XSIZE, 80);
    ObjectSetInteger(0, "CloseAll", OBJPROP_YSIZE, 30);
    ObjectSetString(0, "CloseAll", OBJPROP_TEXT, "CLOSE ALL");
    ObjectSetInteger(0, "CloseAll", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "CloseAll", OBJPROP_BGCOLOR, clrMaroon);
    ObjectSetInteger(0, "CloseAll", OBJPROP_BORDER_COLOR, clrWhite);
}

//+------------------------------------------------------------------+
//| Multi-Target Position Management                                 |
//+------------------------------------------------------------------+
void SetMultipleTargets() {
    if (!position.Select(Symbol())) return;
    
    double lotSize = position.Volume();
    double halfLot = lotSize / 2;
    
    // This is a simplified approach - in production you'd need
    // more sophisticated position splitting logic
    
    // Close half position at TP1
    if (position.PositionType() == POSITION_TYPE_BUY) {
        double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        if (currentPrice >= g_CurrentSignal.tp1) {
            trade.PositionClosePartial(position.Ticket(), halfLot);
            Print("Half position closed at TP1");
        }
    } else {
        double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        if (currentPrice <= g_CurrentSignal.tp1) {
            trade.PositionClosePartial(position.Ticket(), halfLot);
            Print("Half position closed at TP1");
        }
    }
}

//+------------------------------------------------------------------+
//| Logging and Statistics                                          |
//+------------------------------------------------------------------+
void LogTradeStatistics() {
    static int totalTrades = 0;
    static int winningTrades = 0;
    static double totalProfit = 0;
    
    // Update statistics when position closes
    if (position.Select(Symbol())) {
        if (position.Profit() > 0) {
            winningTrades++;
        }
        totalTrades++;
        totalProfit += position.Profit();
        
        double winRate = (totalTrades > 0) ? (double)winningTrades / totalTrades * 100 : 0;
        
        Print("=== CRT EA Statistics ===");
        Print("Total Trades: ", totalTrades);
        Print("Winning Trades: ", winningTrades);
        Print("Win Rate: ", DoubleToString(winRate, 2), "%");
        Print("Total Profit: ", DoubleToString(totalProfit, 2));
        Print("========================");
    }
}

//+------------------------------------------------------------------+
//| End of Expert Advisor                                           |
//+------------------------------------------------------------------+