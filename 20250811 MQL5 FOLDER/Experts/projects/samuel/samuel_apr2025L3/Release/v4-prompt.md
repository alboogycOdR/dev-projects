Okay, understood. You want to revert to a much simpler time input method where the user enters the desired **Trade Start Time directly in Broker Server Time (Hour and Minute)**, removing all the Local Time and GMT offset complexity.

This simplifies the EA logic considerably. Let's implement that.

**1. Update Properties (Version and Description):**

```mql
//+------------------------------------------------------------------+
//|                                                      Maverick EA |
//|                                      Copyright 2025, kingdom_f   |
//|                                       https://t.me/AlisterFx/    |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, kingdom financier"
#property link      "https://t.me/AlisterFx/"
#property version   "2.2" // Simplified SERVER Time Input

// About Box Information
#property description "\n MAVERICK EA v2.2"
// ... (other description properties remain as you like, but update the Time feature description) ...
#property description "-------------------------------------------------"
#property description " Key Features:"
#property description "   - Trade Start Time uses direct SERVER Hour:Minute" // *** UPDATED ***
#property description "   - Survivor SL to Break-Even (BE)"
#property description "   - Stage 2 Trailing SL (Main Trades)"
// ... (rest of features) ...
#property description "   - Opt. Position Status Labels"
#property description "-------------------------------------------------"
#property description " Version: 2.2"
#property description " Author: kingdom financier / AI Fix"
#property description " Support: https://t.me/AlisterFx/"
#property description "" // Blank line
#define EA_Version_String "2.2" // Define string version for display

// ... (Includes) ...
#include <Trade/Trade.mqh>
CTrade trade;
// ... (Rest of code) ...
```

**2. Modify Input Parameters:**

Replace the Local time and GMT offset inputs with direct Server Hour/Minute inputs.

```mql
input group "Main Trade Settings"
input double   InpLotSize = 0.2;                 // Lot Size for Main Trade
input int      InpSLPointsMain = 250000;          // SL Points (Main Trade)
input int      InpTPPointsMain = 1000000;         // TP Points (Main Trade)
input int      InpTradeServerHour = 0;            // <<< NEW >>> SERVER Hour for Main Trade Entry (0-23)
input int      InpTradeServerMinute = 0;         // <<< NEW >>> SERVER Minute for Main Trade Entry (0-59)
// REMOVED input int      InpTradeHourLocal = 11;
// REMOVED input int      InpTradeMinuteLocal = 45;
// REMOVED input double   InpClientLocalGMTOffsetHours = 2.0;
input int      InpTrail2TriggerMain = 500000;  // Points profit after BE before second trail
input int      InpTrail2OffsetMain = 250000;  // Points to move SL above/below entry during second trail
// Magic number moved to System Settings input int      InpMagicMain = 7777777;

// ... (Rest of Inputs remain the same) ...
```

**3. Remove Global Calculated Variables:**

Delete these lines from the Global Variables section:

```mql
// --- Calculated Target Server Time (REMOVE THESE) ---
// int g_serverStartHour = -1;
// int g_serverStartMinute = -1;
```

**4. Modify `OnInit`:**

*   Remove the entire "Calculate Target Server Time" block (Section 3.5 in the previous version).
*   Add validation for the *new* `InpTradeServerHour` and `InpTradeServerMinute` inputs.

```mql
//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    PrintFormat("--- MAVERICK EA v%s Initialization Start ---", EA_Version_String);

    // --- 1. Initial Checks (Terminal/Account/EA Settings) ---
    // ... (Keep these checks) ...

    // --- 2. Symbol Specific Checks ---
    // ... (Keep these checks) ...

    // --- 2.5 Market Hours Check ---
    // ... (Keep this check, possibly as a warning) ...


    // --- 3. Parameter Validation ---
    Print("OnInit: Validating input parameters...");
    // <<< VALIDATE NEW SERVER TIME INPUTS >>>
    if (InpTradeServerHour < 0 || InpTradeServerHour > 23 || InpTradeServerMinute < 0 || InpTradeServerMinute > 59) {
        Print("OnInit Error: Invalid Server Trade Time Input (Hour: %d, Minute: %d). Use 0-23 and 0-59.", InpTradeServerHour, InpTradeServerMinute);
        Alert("Invalid Server Trade Time specified!");
        return INIT_PARAMETERS_INCORRECT;
    }
    // <<< REMOVED Local Time & GMT Offset Validations >>>

    // Validate Other Params
    // ... (Lot size, SL/TP, Magic etc.) ...
     if(InpLotSize <= 0 || InpSLPointsMain <= 0 || InpTPPointsMain <= 0 || InpMagicMain == 0 || InpMagicMain == InpMagicRecovery || (UseRecoveryTrade && (InpLotSizeRecovery <= 0 || InpSLPointsRecovery <= 0 || InpTPPointsRecovery <= 0 || InpMagicRecovery == 0))) { /*Error*/ return INIT_PARAMETERS_INCORRECT;}

     
     if (!ValidateAdjustLotSize(InpLotSize, adjustedLotSize, "Main") || (UseRecoveryTrade && !ValidateAdjustLotSize(InpLotSizeRecovery, adjustedLotSizeRecovery, "Recovery"))) return INIT_FAILED;
    Print("OnInit Check: Input parameters valid.");


    // --- 3.5 Calculate Target Server Time ---
    // <<< REMOVED THIS ENTIRE CALCULATION BLOCK >>>


    // --- 4. Initialize Tracking Arrays & History ---
    Print("OnInit: Initializing state arrays & history...");
    // ... (Init arrays, Scan history) ...


    // --- 5. CTrade Defaults ---
    // ... (Remains same) ...


    // --- 6. Init Runtime State ---
    datetime serverTimeOnInit = TimeCurrent(); // Need this for date/line marker
    currentTradeDate = serverTimeOnInit - (serverTimeOnInit % 86400);
    InitializeExistingRecoveryPairs(); InitializeExistingPairs();
    recoveryTradeActive=(ArraySize(activeRecoveryPairs) > 0);
    dailyTradingEnded=false; dailyCumulativeProfit=0.0; skipRecovery=false;
    lastClosedPair.guid=""; lastClosedPair.evaluated=false;


    // --- 7. Register Callback & Timer ---
    ExtTransaction.SetStopLossCallback(OnStopLossHit);
    int timerSeconds = UpdateFrequency/1000; timerSeconds=(timerSeconds<1)?1:timerSeconds;
    if (!EventSetTimer(timerSeconds)) { /* Error */ return INIT_FAILED; }


    // --- 9. Final Success Log ---
    PrintFormat("--- MAVERICK EA v%s Initialization SUCCESSFUL ---", EA_Version_String);
    CreateTradingDayLine(serverTimeOnInit);

    return INIT_SUCCEEDED;
}
```

**5. Modify `OnTick` Trigger Logic:**

Update the time comparison to directly use the *input* server hour/minute.

```mql
//+------------------------------------------------------------------+
//| Expert tick function (Called on every tick)                      |
//+------------------------------------------------------------------+
void OnTick()
{
    // Static variables MUST be declared at the top for correct persistence
    static datetime lastMainOpenAttemptTime = 0;        // Throttle timer
    static bool tradeOpenedThisTargetMinute = false;    // Flag for success during target H:M
    static int lastCheckedTargetHour = -1;            // Track the target hour processed
    static int lastCheckedTargetMinute = -1;        // Track the target minute processed

    // === Section 1: Code to run on EVERY Tick ===
    datetime currentTime = TimeCurrent();
    MqlDateTime server_dt;
    TimeToStruct(currentTime, server_dt);

    bool isTradingAllowed = !dailyTradingEnded;

    CheckBEHits(); // Check BE price touches for recovery trigger

    // --- Reset the "Opened This Minute" flag IF Server Hour/Minute has CHANGED ---
    if (server_dt.hour != lastCheckedTargetHour || server_dt.min != lastCheckedTargetMinute)
    {
        if (tradeOpenedThisTargetMinute && InpEnableDebug)
           PrintFormat("Tick Check: Resetting tradeOpenedThisMinute flag (Server Time: %02d:%02d)", server_dt.hour, server_dt.min);
        tradeOpenedThisTargetMinute = false; // Reset flag outside the target minute
        lastCheckedTargetHour = server_dt.hour; // Update trackers
        lastCheckedTargetMinute = server_dt.min;
    }


    // --- Check for Main Trade Entry Time (Using DIRECT Server Time Inputs) ---
    if (server_dt.hour == InpTradeServerHour &&    // <<< Use Input Hour Directly
        server_dt.min == InpTradeServerMinute &&   // <<< Use Input Minute Directly
        isTradingAllowed &&
        !tradeOpenedThisTargetMinute)
    {
        // Throttle Check
        if (currentTime - lastMainOpenAttemptTime >= 5)
        {
             if (InpEnableDebug) PrintFormat("Tick Check: Target SERVER Time INPUT (%02d:%02d) Reached & Allowed. Flag=!Open. Attempting Open.", InpTradeServerHour, InpTradeServerMinute);

             if (OpenMainTrade()) {
                 lastMainOpenAttemptTime = currentTime;
                 tradeOpenedThisTargetMinute = true; // Set flag on SUCCESS
                 if(InpEnableDebug) Print("Tick Check: OpenMainTrade SUCCEEDED. Setting tradeOpenedThisTargetMinute=true.");
             } else {
                 lastMainOpenAttemptTime = currentTime; // Update timer on FAIL
                 if(InpEnableDebug) Print("Tick Check: OpenMainTrade FAILED. Throttle timer reset.");
             }
        }
    }
     // Optional log if time is right but disallowed
    else if (server_dt.hour == InpTradeServerHour && server_dt.min == InpTradeServerMinute && !isTradingAllowed && InpEnableDebug)
    {
        PrintFormat("Tick Check: Target SERVER Time INPUT (%02d:%02d) Reached but Trading DENIED (dailyTradingEnded=true).", InpTradeServerHour, InpTradeServerMinute);
    }


    // === Section 2: Code to run only ONCE Per Bar ===
    if (!NewBar()) return; // Exit if not a new bar

    // --- Execute Bar-Dependent Logic ---
    if(InpEnableDebug) PrintFormat("New Bar Detected: %s", TimeToString(currentTime, TIME_DATE|TIME_MINUTES));
    CheckNewTradingDay(currentTime);
    ManagePositions();
    DrawPositionLabels(); // Label update can be per bar

} // End OnTick
```

**6. Modify `UpdateRunningTotal` (Dashboard):**

Change the "Idle" status message to show the direct *input* server time.

```mql
// Inside UpdateRunningTotal:
    // ... Calculate counts etc ...

    // --- Status Line ---
    string stateStr = "";
    // ... check dailyTradingEnded, recoveryTradeActive, other open positions ...
    if (dailyTradingEnded) { stateStr = "** DAILY TRADING ENDED **"; }
    else if (/* recovery active */) { /* ... */ }
    else if (/* other trades active */) { /* ... */ }
    else // Idle
    {
        // Display the direct INPUT server time it's waiting for
        stateStr = StringFormat("Idle / Awaiting Server %02d:%02d", InpTradeServerHour, InpTradeServerMinute); // <<< Use Inputs Directly
    }
    dashboard += StringFormat("%sStatus: %s\r\n\r\n", indent, stateStr);

    // ... Rest of dashboard string ...

    Comment(dashboard);
    ChartRedraw(0);
```

These changes remove the complexity of the GMT offset calculations and make the trade trigger depend solely on the broker's server clock matching the time you directly input in the EA settings. This is much less prone to user error regarding time zones.