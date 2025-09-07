Okay, let's integrate the local time input and GMT offset calculation into your provided v1.9 codebase.

**1. Update `#property` Directives and Version:**

Change the version to reflect this new functionality and update the description slightly.

```mql
// Top of the file
//+------------------------------------------------------------------+
//|                                                      Maverick EA |
//|                                      Copyright 2025, kingdom_f   |
//|                                       https://t.me/AlisterFx/    |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, kingdom financier"
#property link      "https://t.me/AlisterFx/"
#property version   "2.1" // Local Time Input with GMT Offset Calc

// About Box Information
#property description "\n MAVERICK EA" // Optional spacing
// #property description " Copyright © 2025, kingdom financier" // Removed redundancy with copyright prop
#property description "-------------------------------------------------"
#property description " Strategy: Hedging System"
#property description "   - Multi-Pair Main Trades (Concurrent, GUID)"
#property description "   - Multi-Pair Recovery Trades (Concurrent, GUID)"
#property description "-------------------------------------------------"
#property description " Key Features:"
#property description "   - Local Time Input + Client GMT Offset" // *** NEW/UPDATED ***
#property description "   - Survivor SL to Break-Even (BE)"
#property description "   - Stage 2 Trailing SL (Main Trades)"
#property description "   - Recovery Trades on Loss"
#property description "   - On-Tick BE Hit Detection (Recovery Trig)"
#property description "   - Recovery Blocking after Trailed SL Hit"
#property description "   - Daily Stop after Recovery Cycle Finishes"
#property description "   - Chart Dashboard (Summary)"
#property description "   - Opt. Position Status Labels"
#property description "-------------------------------------------------"
#property description " Version: 2.1"
#property description " Author: kingdom financier / AI Fix"
#property description " Support: https://t.me/AlisterFx/"
#property description "" // Blank line

// --- REST OF YOUR EA CODE STARTS HERE ---
/*
 V2.1 Notes:
 - Replaced InpTradeTime (string) with InpTradeHourLocal, InpTradeMinuteLocal (int),
   and InpClientLocalGMTOffsetHours (double).
 - OnInit calculates target server start time based on inputs and server offset.
 - OnTick now compares current server time to calculated target server time.

 V1.9 Notes:
 - Added second dashboard functionality (Position Labels) based on SL status.
 - Added On-Tick BE Hit Check functionality.
 - Retained v1.8 SL Flag persistence fix and multi-recovery handling.
 ... (other notes)
*/
#include <Trade/Trade.mqh>
CTrade trade;
// ... rest of code ...
```

**2. Modify Input Parameters:**

Replace `InpTradeTime` with the new inputs in the `Main Trade Settings` group.

```mql
input group "Main Trade Settings"
input double   InpLotSize = 0.2;                 // Lot Size for Main Trade
input int      InpSLPointsMain = 250000;          // SL Points (Main Trade)
input int      InpTPPointsMain = 1000000;         // TP Points (Main Trade)
// input string   InpTradeTime = "00:00";         // <<< REMOVED >>> Main Trade Entry Time (HH:MM)
input int      InpTradeHourLocal = 9;            // <<< NEW >>> Local Hour for Main Trade Entry (0-23)
input int      InpTradeMinuteLocal = 30;         // <<< NEW >>> Local Minute for Main Trade Entry (0-59)
input double   InpClientLocalGMTOffsetHours = 0.0;// <<< NEW >>> Your PC/Local Time Zone's Offset from GMT (e.g., NY=-4, London=1, CET=2)
input int      InpTrail2TriggerMain = 500000;  // Points profit after BE before second trail
input int      InpTrail2OffsetMain  = 250000;  // Points to move SL above/below entry during second trail
// Magic number moved to System Settings input int      InpMagicMain = 7777777;
```

*(Self-correction from previous response: Moved `InpMagicMain` to the "System Settings" group for better organisation, which you seem to have already done).*

**3. Add Global Variables for Calculated Time:**

```mql
// --- Add near other globals ---
string infoLabelPrefix = "MAVERICK_";     // Prefix for chart objects
string tradingDayLineName = "MAVERICK_TRADING_DAY_LINE";  // Name for the vertical line
string currentTradeGuid = "";             // Stores the GUID of the main pair being *currently* opened

// *** NEW: Calculated Target Server Time ***
int g_serverStartHour = -1;             // Calculated Server Hour Target (-1 indicates invalid/not calculated)
int g_serverStartMinute = -1;           // Calculated Server Minute Target
```

**4. Modify `OnInit` for Time Calculation & Validation:**

```mql
//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    PrintFormat("--- MAVERICK EA v%s Initialization Start ---", MQL5InfoString(MQL5_VERSION)); // Corrected MQL5 version function

    // --- 1. Initial Checks (Terminal/Account/EA Settings) ---
    if (!MQLInfoInteger(MQL_TRADE_ALLOWED)) { /* Error */ Alert("Algo Trading DISABLED in Terminal/EA settings!"); return(INIT_TRADE_NOT_ALLOWED); }
    if (!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) { /* Error */ Alert("Trading DISABLED for account!"); return(INIT_ACCOUNT_NOT_SYNCED); }
    if (AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) { Print("OnInit Warning: Account does not support hedging."); }
    Print("OnInit Check: Algo Trading & Account Trading Enabled.");

    // --- 2. Symbol Specific Checks ---
    string currentSymbol = _Symbol;
    if (!SymbolInfoInteger(currentSymbol, SYMBOL_SELECT)) { /* Error */ Alert("Symbol " + currentSymbol + " not in Market Watch!"); return(INIT_SYMBOL_NOT_FOUND); }
    if (_Point <= 0 || _Digits <= 0) { PrintFormat("OnInit Error: Invalid symbol info for %s", currentSymbol); return(INIT_FAILED); }
    PrintFormat("OnInit Check: Symbol %s selected.", currentSymbol);

    ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(currentSymbol, SYMBOL_TRADE_MODE);
    if (tradeMode == TRADE_MODE_DISABLED) { /* Error */ Alert("Trading DISABLED for symbol " + currentSymbol); return(INIT_TRADE_NOT_ALLOWED); }
    if (tradeMode == TRADE_MODE_CLOSEONLY) { /* Error */ Alert("Symbol " + currentSymbol + " is Close Only!"); return(INIT_TRADE_NOT_ALLOWED); }
    PrintFormat("OnInit Check: Symbol %s trade mode is Full.", currentSymbol);

    // --- 2.5 Market Hours Check at Initialization ---
    datetime serverTime = TimeCurrent(); MqlDateTime currentTimeStruct; TimeToStruct(serverTime, currentTimeStruct);
    datetime sessionStartTime, sessionEndTime; bool marketIsOpen=false;
    marketIsOpen = SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)currentTimeStruct.day_of_week, serverTime, sessionStartTime, sessionEndTime);
    if (!marketIsOpen) {
        // Print("OnInit Warning: Market for symbol appears CLOSED at init time. Verify trading hours."); // Make it a warning for flexibility
         Alert("Warning: Market for " + currentSymbol + " seems CLOSED. Check sessions.");
         // Allow init even if market closed: return(INIT_FAILED);
    } else { PrintFormat("OnInit Check: Market for %s OPEN at %s.", currentSymbol, TimeToString(serverTime)); }


    // --- 3. Parameter Validation ---
    Print("OnInit: Validating input parameters...");
    // Validate NEW Time Inputs
    if (InpTradeHourLocal < 0 || InpTradeHourLocal > 23 || InpTradeMinuteLocal < 0 || InpTradeMinuteLocal > 59) {
        Print("OnInit Error: Invalid Local Trade Time Input (Hour: %d, Minute: %d). Use 0-23 and 0-59.", InpTradeHourLocal, InpTradeMinuteLocal);
        Alert("Invalid Local Trade Time specified!");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (InpClientLocalGMTOffsetHours < -12.0 || InpClientLocalGMTOffsetHours > 14.0) { // Allow +/- 12/14 range
        Print("OnInit Warning: Client GMT Offset (%.1f) seems unusual. Please verify.", InpClientLocalGMTOffsetHours);
        Alert("Client GMT Offset (Set to: " + DoubleToString(InpClientLocalGMTOffsetHours, 1) + ") seems unusual - please check."); // Optional
    }
    // Validate Other Params
    if (InpLotSize <= 0 || InpSLPointsMain <= 0 /* etc. */ ) { Print("Invalid settings detected!"); return INIT_PARAMETERS_INCORRECT;}
    if (!ValidateAdjustLotSize(InpLotSize, adjustedLotSize, "Main") || (UseRecoveryTrade && !ValidateAdjustLotSize(InpLotSizeRecovery, adjustedLotSizeRecovery, "Recovery"))) return INIT_FAILED;
    Print("OnInit Check: Basic parameters seem valid.");


    // --- 3.5 Calculate Target Server Time ---
    Print("OnInit: Calculating target server time...");
    double serverGMTOffsetSeconds = TimeGMTOffset(); // Get server offset in SECONDS
    double clientGMTOffsetSeconds = InpClientLocalGMTOffsetHours * 3600.0; // Convert client input offset to SECONDS
    double timeDifferenceSeconds = serverGMTOffsetSeconds - clientGMTOffsetSeconds;

    // Create a datetime representing the user's LOCAL target time today
    MqlDateTime localTargetTime;
    TimeToStruct(TimeCurrent(), localTargetTime); // Get current date parts
    localTargetTime.hour = InpTradeHourLocal;
    localTargetTime.min  = InpTradeMinuteLocal;
    localTargetTime.sec  = 0;
    datetime dtLocalTarget = StructToTime(localTargetTime);

    // Calculate target server time by adding the difference
    datetime dtServerTarget = dtLocalTarget + (long)timeDifferenceSeconds; // Cast difference to long for datetime arithmetic

    // Extract the target server hour and minute
    MqlDateTime serverTargetTime;
    TimeToStruct(dtServerTarget, serverTargetTime);
    g_serverStartHour = serverTargetTime.hour;
    g_serverStartMinute = serverTargetTime.min;

    // Debug Print Calculation
    if (InpEnableDebug) {
        string clientOffsetStr = (InpClientLocalGMTOffsetHours>=0?"+":"")+DoubleToString(InpClientLocalGMTOffsetHours,1);
        string serverOffsetStr = (serverGMTOffsetSeconds>=0?"+":"")+DoubleToString(serverGMTOffsetSeconds/3600.0,1);
        PrintFormat("OnInit: Client Local Input: %02d:%02d (Local GMT Offset: %s)", InpTradeHourLocal, InpTradeMinuteLocal, clientOffsetStr);
        PrintFormat("OnInit: Server Time Now: %s (Server GMT Offset: %s)", TimeToString(TimeCurrent()), serverOffsetStr);
        PrintFormat("OnInit: ---> Calculated Target SERVER Time: %02d:%02d", g_serverStartHour, g_serverStartMinute);
    }
    // Sanity check - unlikely to fail with this method
    if (g_serverStartHour < 0 || g_serverStartMinute < 0) { Print("OnInit Error: Server Time Calculation Failed!"); return INIT_FAILED;}


    // --- 4. Initialize Tracking Arrays & History ---
    Print("OnInit: Initializing tracking arrays and scanning history...");
    ArrayResize(activeMainPairs, 0); ArrayResize(activeRecoveryPairs, 0); ArrayResize(trackedPositions, 0); ArrayResize(triggeredBEGuids, 0);
    for(int i=0; i<5; i++) { /* Init lastFiveTrades */ } totalRealizedProfit = 0.0;
    if(HistorySelect(0, TimeCurrent())) { /* History scan */ }
    Print("OnInit Check: History Scan complete.");


    // --- 5. Set CTrade Defaults ---
    // ... (Same as before) ...


    // --- 6. Initialize Runtime State ---
    // currentTradeDate already set based on serverTime fetched earlier
    currentTradeDate = serverTime - (serverTime % 86400); // Use serverTime to avoid extra TimeCurrent() call
    InitializeExistingRecoveryPairs(); InitializeExistingPairs();
    recoveryTradeActive=(ArraySize(activeRecoveryPairs)>0);
    dailyTradingEnded=false; dailyCumulativeProfit=0.0; skipRecovery=false;
    lastClosedPair.guid=""; lastClosedPair.evaluated=false;
    Print("OnInit Check: Runtime state initialized.");


    // --- 7. Register Callback & Setup Timer ---
    ExtTransaction.SetStopLossCallback(OnStopLossHit);
    int timerSeconds = UpdateFrequency / 1000; timerSeconds=(timerSeconds<1)?1:timerSeconds;
    if (!EventSetTimer(timerSeconds)) { Print("OnInit Error: Timer failed."); return INIT_FAILED; }


    // --- 9. Final Success Log & Finish ---
    PrintFormat("--- MAVERICK EA v%s Initialization SUCCESSFUL ---", MQL5InfoString(MQL5_VERSION));
    CreateTradingDayLine(serverTime); // Use server time for line

    return INIT_SUCCEEDED;
}
```

**5. Modify `OnTick` Function:**

```mql
//+------------------------------------------------------------------+
//| Expert tick function (Called on every tick)                      |
//+------------------------------------------------------------------+
void OnTick()
{
    // === Section 1: Code to run on EVERY Tick ===
    datetime currentTime = TimeCurrent(); // Get server time once per tick
    MqlDateTime server_dt;
    TimeToStruct(currentTime, server_dt);

    CheckBEHits(); // Check BE price touches

    // --- Check for Main Trade Entry Time (Using Calculated Server Time) ---
    bool isTradingAllowed = !dailyTradingEnded;

    // Compare current server time with CALCULATED target server time
    if (g_serverStartHour >= 0 && g_serverStartMinute >=0 && // Ensure time was calculated
        server_dt.hour == g_serverStartHour &&
        server_dt.min == g_serverStartMinute &&
        isTradingAllowed)
    {
        // Throttle logic
        static datetime lastMainOpenAttemptTime = 0;
        if (currentTime - lastMainOpenAttemptTime >= 55) // Check throttle *after* time match
        {
             if (InpEnableDebug) PrintFormat("Tick Check: Target SERVER Time (%02d:%02d) Reached & Allowed. Attempting Open.", g_serverStartHour, g_serverStartMinute);
             if (OpenMainTrade()) { lastMainOpenAttemptTime = currentTime; /*Log OK in OpenMainTrade*/ }
             else { lastMainOpenAttemptTime = currentTime; /*Log Fail in OpenMainTrade*/ }
        }
    }
    else if (g_serverStartHour >= 0 && g_serverStartMinute >= 0 &&
             server_dt.hour == g_serverStartHour && server_dt.min == g_serverStartMinute &&
             !isTradingAllowed && InpEnableDebug) // Log if time matched but trading ended
    {
        PrintFormat("Tick Check: Target SERVER Time (%02d:%02d) Reached but Trading DENIED (dailyTradingEnded=true).", g_serverStartHour, g_serverStartMinute);
    }

    // === Section 2: Code to run only ONCE Per Bar ===
    if (!NewBar()) return; // Exit if not a new bar

    // --- Execute Bar-Dependent Logic ---
    // Note: Pass currentTime if needed, to avoid redundant calls
    if(InpEnableDebug) PrintFormat("New Bar Detected: %s", TimeToString(currentTime, TIME_DATE|TIME_MINUTES));
    CheckNewTradingDay(currentTime);
    ManagePositions();
    DrawPositionLabels(); // Label update can be per bar

} // End OnTick
```

**6. Modify `UpdateRunningTotal` (Dashboard):**

```mql
//+------------------------------------------------------------------+
//| Update and display the dashboard                                |
//+------------------------------------------------------------------+
void UpdateRunningTotal()
{
    if(!ShowDashboard) { /* Delete BG, Comment(""), return; */ }

    // ... (Calculate P/L, Counts, Running Total, Currency) ...
     double unrealizedProfit=0; int mainCount=0; int recCount=0;
     /* ... Loop Positions ... */
     double runningTotal = totalRealizedProfit + unrealizedProfit; string currency = AccountInfoString(ACCOUNT_CURRENCY);


    string indent = "     ";
    string dashboard = StringFormat("%s==== MAVERICK EA (v%s) ====\r\n\r\n%sSymbol: %s | Time: %s\r\n",
                                  indent, MQL5InfoString(MQL5_VERSION),
                                  indent, _Symbol, TimeToString(TimeCurrent(), TIME_SECONDS));

    // --- Status Line ---
    string stateStr = "";
    recoveryTradeActive = (ArraySize(activeRecoveryPairs) > 0);
    mainCount = CountOpenPositionsMagic(InpMagicMain); // Use count for general status
    recCount = CountOpenPositionsMagic(InpMagicRecovery);

    if (dailyTradingEnded) { stateStr = "** DAILY TRADING ENDED **"; }
    else if (recoveryTradeActive) { stateStr = "[RECOVERY ACTIVE (" + IntegerToString(ArraySize(activeRecoveryPairs)) + " pairs)]"; }
    else if (mainCount > 0 || recCount > 0) { stateStr = "Trade(s) Active"; }
    else if (g_serverStartHour >= 0) // If waiting for calculated server time
    {
         stateStr = StringFormat("Idle / Awaiting Server %02d:%02d", g_serverStartHour, g_serverStartMinute);
    }
    else { stateStr = "Idle / Trade Time Invalid"; } // Fallback if time calc failed

    dashboard += StringFormat("%sStatus: %s\r\n\r\n", indent, stateStr);

    // ... (Profit Summary remains the same) ...

    // Position Summary (Using count)
    dashboard += StringFormat("%s Open Positions: Main=%d | Recov=%d\r\n\r\n\r\n", indent, mainCount, recCount);

    // ... (Last 5 Trades remains the same) ...

    // --- Display Dashboard ---
    // ... (Rectangle setup, Comment(dashboard), ChartRedraw() remains same) ...

} // End UpdateRunningTotal
```

Remember to fill in the condensed placeholder function bodies with the actual code from the v1.8 you had previously, where applicable (like the Trade Transaction handlers, validation, history scan, opening trades, managing pairs, etc.).