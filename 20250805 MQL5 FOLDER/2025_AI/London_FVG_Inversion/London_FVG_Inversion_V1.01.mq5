//+------------------------------------------------------------------+
//|                                    London_FVG_Inversion_V1.mq5 |
//|                        Copyright 2023, Generated from Strategy |
//|                                              Strategy Developer |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Generated from Strategy"
#property link      "None"
#property version   "1.01" // Incremented version
#property strict

#include <Trade\Trade.mqh> // Trading class

/*
V1.1

Key Changes Made (Addressing the Error & Improving Logic):
FVGInfo Struct: Added datetime completionTime to specifically store the timestamp of the third candle of the FVG pattern. This is crucial for correctly checking subsequent bars.
FindFirstFVG_AfterLondonOpen Function:
Copies recent bars using a standard approach (CopyRates(..., 0, barsNeeded, rates)).
Sets ArraySetAsSeries(rates, true) so rates[0] is the latest complete bar.
The loop now iterates correctly using indices i, i-1, i-2.
It checks rates[i].time >= londonOpenTimeToday to ensure the FVG completed after the session started.
It searches backwards through the specified bar range (MaxBarsToSearchFVG) but keeps track of the earliest FVG found that satisfies the time condition, ensuring we get the first one.
It stores the correct fvg.completionTime (the time of the 3rd candle, rates[i].time).
CheckFVGInversion Function:
Now consistently copies the last MaxBarsToCheckInvRetest completed bars (using start index 1).
It iterates through these copied bars (index 0 is oldest in copied set, barsCopied-1 is newest completed).
Crucially, it checks if(rates[i].time <= fvg.completionTime) before checking for the inversion close. This ensures it only evaluates bars that formed after the FVG was confirmed, preventing the out-of-range error on the correct bars.
Stores rates[i].time as inversionTime when inversion is confirmed.
CheckRetest Function:
No longer takes FVGInfo as it uses the globally stored values (fvgIsBearish, inversionLevel, inversionTime).
Fetches recent bars and checks if(rates[i].time <= inversionTime).
Added a small buffer condition using StopLossPips to the retest check (rates[i].low > (inversionLevel - StopLossPips*_Point*10) and similar for high) to prevent entries if price violently spikes far beyond the retest level immediately.
PlaceTrade Function:
No longer takes FVGInfo.
Includes a more robust check to see if a position with the correct Magic Number and Symbol already exists before placing a new one.
Uses 0 for price in trade.Buy() / trade.Sell() to indicate a market order execution, as the retest confirmation happens on a completed bar, and we enter on the next tick/bar open.
OnTick Logic:
Simplified the flow. It first tries to find and store the first daily FVG.
If found, it then checks for inversion on subsequent bars.
If inverted, it then checks for a retest on subsequent bars and places the trade if conditions are met.
Uses the globally stored FVG details (fvgFoundToday, fvgIsBearish, fvgHigh, fvgLow, fvgCompletionTime, etc.) after they are initially set.
Added a check at the end to reset flags if the London session ends and no trade was opened from the identified FVG setup.


*/

//--- Input Parameters
input group           "Trading Session (Broker Server Time)"
input int             LondonOpenHour    = 10; // ===> IMPORTANT: Set BROKER Server Hour corresponding to 3 AM NYT <===
input int             LondonCloseHour   = 14; // ===> IMPORTANT: Set BROKER Server Hour corresponding to 7 AM NYT <===

input group           "Trade Settings"
input double          Lots              = 0.01;   // Lot size
input double          RiskRewardRatio   = 2.0;    // Risk:Reward Ratio (e.g., 2.0 for 1:2)
input int             StopLossPips      = 15;     // ===> V1: Fixed SL in Pips beyond inversion high/low <===
input ulong           MagicNumber       = 123450; // Magic number for EA orders

input group           "FVG Settings"
input int             MaxBarsToSearchFVG = 50;    // How many recent bars back to check for FVG within the session
input int             MaxBarsToCheckInvRetest = 50; // How many recent bars to check for Inversion/Retest

//--- Global Variables
CTrade            trade;                  // Trading object
bool              fvgFoundToday     = false; // Flag if FVG found for the current day's London session
bool              fvgInvertedToday  = false; // Flag if the daily FVG has been inverted
bool              tradeOpenedToday  = false; // Flag if a trade has been opened based on today's setup
bool              fvgIsBearish      = false; // True if bearish FVG, false if bullish
double            fvgHigh           = 0.0;   // High price of the FVG zone
double            fvgLow            = 0.0;   // Low price of the FVG zone
datetime          fvgCompletionTime = 0;     // *** ADDED: Time when the FVG pattern (3rd candle) completed ***
double            inversionLevel    = 0.0;   // The price level (FVG high or low) that was breached for inversion
datetime          inversionTime     = 0;     // Time the inversion occurred (time of the closing candle)
int               dayResetCheck     = -1;    // Helper to detect new day

// Structure to hold FVG info
struct FVGInfo
{
   bool     found;
   bool     isBearish;
   double   high;
   double   low;
   datetime completionTime; // *** MOVED: Time of the *third* candle (completion of pattern) ***
   int      indexFound;     // Index where the FVG search *stopped* (index of 3rd candle *relative to the CopyRates call*)
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Check Timeframe
   if(_Period != PERIOD_M15)
   {
      Alert("Error: Please apply this EA to an M15 chart.");
      return(INIT_FAILED);
   }

   //--- Initialize trading object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10); // Allowable slippage (adjust as needed)
   trade.SetTypeFillingBySymbol(_Symbol);

   Print("London FVG Inversion V1.01 Initialized.");
   Print("Broker Server Time for London Session: ", LondonOpenHour, ":00 - ", LondonCloseHour, ":00");
   Print("Risk Reward Ratio: 1:", RiskRewardRatio);
   Print("V1 Fixed Stop Loss Pips: ", StopLossPips);

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Reset daily variables                                           |
//+------------------------------------------------------------------+
void ResetDailyVariables()
{
   fvgFoundToday = false;
   fvgInvertedToday = false;
   tradeOpenedToday = false;
   fvgIsBearish = false;
   fvgHigh = 0.0;
   fvgLow = 0.0;
   fvgCompletionTime = 0; // Reset FVG time
   inversionLevel = 0.0;
   inversionTime = 0;
   // Print("Daily variables reset for ", TimeToString(TimeCurrent(), TIME_DATE));
}
//+------------------------------------------------------------------+
//| Check if current time is within London Session                  |
//+------------------------------------------------------------------+
bool IsLondonSession(datetime checkTime)
{
   MqlDateTime dt;
   TimeToStruct(checkTime, dt);
   // Basic hour check based on broker server time
   return(dt.hour >= LondonOpenHour && dt.hour < LondonCloseHour);
}

//+------------------------------------------------------------------+
//| Find the first FVG after London Open                            |
//+------------------------------------------------------------------+
FVGInfo FindFirstFVG_AfterLondonOpen(datetime londonOpenTimeToday)
{
   FVGInfo fvg = { false }; // Initialize as not found
   MqlRates rates[];
   // Copy bars from the beginning of the London session or slightly before, up to now
   // We need enough history to find the *first* FVG *after* the open time
   int startBarIndex = iBarShift(_Symbol, PERIOD_M15, londonOpenTimeToday) + 5; // Start a few bars before open
   if (startBarIndex < 0) startBarIndex = MaxBarsToSearchFVG; // Fallback if shift fails or is too recent
   int barsNeeded = startBarIndex; // Copy roughly this many bars

   int barsCopied = CopyRates(_Symbol, PERIOD_M15, 0, barsNeeded, rates); // Copy recent bars

   if(barsCopied < 3) return fvg;

   // Rates are typically newest [0] to oldest [n-1], but let's ensure
   ArraySetAsSeries(rates, true); // Now rates[0] is current (incomplete), rates[1] is last completed

   // Iterate backwards from the most recent *completed* bar (index 1)
   // candles are indexed rates[i=3rd], rates[i-1=2nd], rates[i-2=1st] (when AsSeries is true)
   for(int i = 2; i < barsCopied; i++) // Start from index 2 to check candles [0,1,2] etc.
   {
      // --- Check if the FVG's *completion* time is AFTER London Open ---
      if(rates[i].time < londonOpenTimeToday) continue; // This bar (3rd) must be AFTER session start

      // Check Bearish FVG (Gap between low of candle 1 (i-2) and high of candle 3 (i))
      if(rates[i-2].low > rates[i].high)
      {
         // Potential FVG found, check if it's the *earliest* one AFTER the open time
         if (!fvg.found || rates[i].time < fvg.completionTime) // If first found or earlier than previous earliest
         {
             fvg.found = true;
             fvg.isBearish = true;
             fvg.high = rates[i-2].low;  // Top of bearish FVG zone
             fvg.low = rates[i].high;   // Bottom of bearish FVG zone
             fvg.completionTime = rates[i].time; // Time of the THIRD candle's completion
             fvg.indexFound = i; // Store index relative to this call's rates array
         }
         // Continue searching backwards to ensure we find the absolute *first* one after the open
      }

      // Check Bullish FVG (Gap between high of candle 1 (i-2) and low of candle 3 (i))
      else if(rates[i-2].high < rates[i].low)
      {
        // Potential FVG found, check if it's the *earliest* one AFTER the open time
         if (!fvg.found || rates[i].time < fvg.completionTime) // If first found or earlier than previous earliest
         {
             fvg.found = true;
             fvg.isBearish = false;
             fvg.high = rates[i].low;    // Top of bullish FVG zone
             fvg.low = rates[i-2].high; // Bottom of bullish FVG zone
             fvg.completionTime = rates[i].time; // Time of the THIRD candle's completion
             fvg.indexFound = i; // Store index relative to this call's rates array
         }
          // Continue searching backwards to ensure we find the absolute *first* one after the open
      }
   }
    // After checking all relevant bars, if we found one, print it
   if (fvg.found)
   {
      PrintFormat("%s FVG Found: High=%.5f, Low=%.5f, CompletedTime=%s",
                  fvg.isBearish ? "Bearish" : "Bullish",
                  fvg.high, fvg.low, TimeToString(fvg.completionTime));
   }


   return fvg; // Return the FVG structure (or {false} if none found)
}


//+------------------------------------------------------------------+
//| Check for FVG Inversion                                          |
//+------------------------------------------------------------------+
bool CheckFVGInversion(const FVGInfo &fvg) // Pass fvg structure (with completionTime)
{
    if (!fvg.found || fvgInvertedToday) return false;

    MqlRates rates[];
    int barsToCopy = MaxBarsToCheckInvRetest; // How many recent bars to check
    int barsCopied = CopyRates(_Symbol, PERIOD_M15, 1, barsToCopy, rates); // Copy last N *completed* bars (index 0 oldest -> N-1 newest)

    if(barsCopied < 1) return false;

    // We don't need ArraySetAsSeries here if we copy backwards starting from index 1.
    // rates[0] will be the oldest completed bar in the copied range
    // rates[barsCopied-1] will be the most recent completed bar (previous tick's bar)

    // Iterate through the copied completed bars
    for(int i = 0; i < barsCopied; i++)
    {
         // Check only bars strictly AFTER the FVG pattern completed
         if(rates[i].time <= fvg.completionTime) continue; // <----- This comparison is now safe

         // Check for Bullish FVG inversion (candle closes BELOW fvgLow)
         if(!fvg.isBearish && rates[i].close < fvg.low)
         {
            fvgInvertedToday = true;
            inversionLevel = fvg.low; // Inversion reference is the FVG boundary
            inversionTime = rates[i].time; // Time the candle closed making the inversion
            PrintFormat("Bullish FVG Inverted (Bearish Signal): Level=%.5f, Time=%s", inversionLevel, TimeToString(inversionTime));
            return true;
         }
         // Check for Bearish FVG inversion (candle closes ABOVE fvgHigh)
         if(fvg.isBearish && rates[i].close > fvg.high)
         {
            fvgInvertedToday = true;
            inversionLevel = fvg.high; // Inversion reference is the FVG boundary
            inversionTime = rates[i].time; // Time the candle closed making the inversion
            PrintFormat("Bearish FVG Inverted (Bullish Signal): Level=%.5f, Time=%s", inversionLevel, TimeToString(inversionTime));
            return true;
         }
    }

    return false; // No inversion found in the checked bars after the FVG time
}


//+------------------------------------------------------------------+
//| Check for Retest of Inversion Level                             |
//+------------------------------------------------------------------+
bool CheckRetest() // Removed FVGInfo parameter, uses global inversionLevel and inversionTime
{
   // Uses global: fvgFoundToday, fvgInvertedToday, tradeOpenedToday, inversionLevel, inversionTime, fvgIsBearish
   if(!fvgFoundToday || !fvgInvertedToday || tradeOpenedToday || inversionLevel == 0.0 || inversionTime == 0) return false;

   MqlRates rates[]; // Check last few completed bars for retest
   int barsToCopy = 5;
   int barsCopied = CopyRates(_Symbol, PERIOD_M15, 1, barsToCopy, rates);

   if(barsCopied < 1) return false;

   // Again, rates[0] is oldest copied, rates[barsCopied-1] is newest completed bar

   for(int i=0; i < barsCopied; i++)
   {
       // Only check bars strictly after the inversion happened
       if(rates[i].time <= inversionTime) continue;

      // Check for retest for BUY (price dips to or just below the inversion level - which was the bearish FVG's high)
       if(fvgIsBearish && rates[i].low <= inversionLevel && rates[i].low > (inversionLevel - StopLossPips*_Point*10)) // Add buffer to avoid triggering on spikes way below
       {
           PrintFormat("Retest for BUY occurred at %s (Low: %.5f <= Inversion: %.5f)", TimeToString(rates[i].time), rates[i].low, inversionLevel);
           return true;
       }
       // Check for retest for SELL (price rises to or just above the inversion level - which was the bullish FVG's low)
       if(!fvgIsBearish && rates[i].high >= inversionLevel && rates[i].high < (inversionLevel + StopLossPips*_Point*10)) // Add buffer
       {
          PrintFormat("Retest for SELL occurred at %s (High: %.5f >= Inversion: %.5f)", TimeToString(rates[i].time), rates[i].high, inversionLevel);
          return true;
       }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Place Trade Function                                            |
//+------------------------------------------------------------------+
void PlaceTrade() // Removed FVGInfo parameter, uses global flags
{
   // Uses global: fvgFoundToday, fvgInvertedToday, tradeOpenedToday, fvgIsBearish, inversionLevel
   if(!fvgFoundToday || !fvgInvertedToday || tradeOpenedToday || inversionLevel == 0.0)
   {
       // Print("PlaceTrade conditions not met."); // Debug print
       return;
   }

   // --- Check for existing position ---
   bool positionExists = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
       ulong ticket = PositionGetTicket(i);
       if(PositionSelectByTicket(ticket)) // Select position to check its properties
       {
          if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
          {
              positionExists = true;
              break;
          }
       }
   }

   if(positionExists)
   {
       // Print("Position already exists for this symbol and magic number.");
       tradeOpenedToday = true; // Set flag even if position was opened previously today
       return; // Don't open another trade
   }
   // --- End Check for existing position ---


   double slDistance = StopLossPips * _Point * (SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5 ? 10 : 1); // Adjust for JPY pairs / 5 digit brokers
   double tpDistance = slDistance * RiskRewardRatio;
   double entryPrice = 0; // We enter at market on retest confirmation
   double stopLoss = 0;
   double takeProfit = 0;

   string comment = "";

   // Determine direction based on which FVG was inverted (use global fvgIsBearish)
   if(fvgIsBearish) // Original FVG was Bearish -> Inverted -> Support -> BUY
   {
       entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
       // V1 SL: Fixed pips below the inversion level (the high of the original bearish FVG)
       stopLoss = inversionLevel - slDistance;
       // Refined V1 SL might consider low of retest candle or inversion candle, more complex
       takeProfit = entryPrice + tpDistance;
       comment = "London FVG V1 Buy";

       if(!trade.Buy(Lots, _Symbol, 0, stopLoss, takeProfit, comment)) // Use 0 for market price
       {
         PrintFormat("Buy Order failed: %s (Price: %.5f, SL: %.5f, TP: %.5f)",
                     trade.ResultRetcodeDescription(), entryPrice, stopLoss, takeProfit);
       }
       else
       {
          PrintFormat("Buy Order Placed at Market (~%.5f): SL=%.5f, TP=%.5f",
                      entryPrice, NormalizeDouble(stopLoss, _Digits), NormalizeDouble(takeProfit, _Digits));
          tradeOpenedToday = true;
       }
   }
   else // Original FVG was Bullish -> Inverted -> Resistance -> SELL
   {
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      // V1 SL: Fixed pips above the inversion level (the low of the original bullish FVG)
      stopLoss = inversionLevel + slDistance;
       // Refined V1 SL might consider high of retest candle or inversion candle
      takeProfit = entryPrice - tpDistance;
      comment = "London FVG V1 Sell";

      if(!trade.Sell(Lots, _Symbol, 0, stopLoss, takeProfit, comment)) // Use 0 for market price
      {
          PrintFormat("Sell Order failed: %s (Price: %.5f, SL: %.5f, TP: %.5f)",
                      trade.ResultRetcodeDescription(), entryPrice, stopLoss, takeProfit);
      }
      else
      {
          PrintFormat("Sell Order Placed at Market (~%.5f): SL=%.5f, TP=%.5f",
                      entryPrice, NormalizeDouble(stopLoss, _Digits), NormalizeDouble(takeProfit, _Digits));
          tradeOpenedToday = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Only run logic once per bar for efficiency
   static datetime lastBarTime = 0;
   // Get time of the START of the currently forming bar
   datetime currentBarOpenTime = (datetime)SeriesInfoInteger(_Symbol, PERIOD_M15, SERIES_LASTBAR_DATE);

    // If the last completed bar's time hasn't changed, do nothing
   if(currentBarOpenTime == lastBarTime) return;
   lastBarTime = currentBarOpenTime; // Update last processed bar time

   //--- Check for new day to reset flags
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day != dayResetCheck)
   {
      ResetDailyVariables();
      dayResetCheck = dt.day;
      Print("New day detected, resetting variables."); // Added Print
   }

   //--- Check if inside London session (based on current server time)
   datetime serverTimeCurrent = TimeCurrent();
   if (!IsLondonSession(serverTimeCurrent)) return; // Exit if not in session

   // --- Define London Open Time for *today* ---
   MqlDateTime todayDT;
   TimeToStruct(serverTimeCurrent, todayDT);
   todayDT.hour = LondonOpenHour;
   todayDT.min = 0;
   todayDT.sec = 0;
   datetime londonOpenTimeToday = StructToTime(todayDT);


   //--- Trading Logic Flow (Executed once per new M15 bar)
   FVGInfo foundFVG = { false }; // Temporary storage for found FVG

   // 1. Find the FIRST FVG for today if not already found
   if(!fvgFoundToday)
   {
       foundFVG = FindFirstFVG_AfterLondonOpen(londonOpenTimeToday);
       if(foundFVG.found)
       {
          // Store the found FVG details globally
          fvgFoundToday = true;
          fvgIsBearish = foundFVG.isBearish;
          fvgHigh = foundFVG.high;
          fvgLow = foundFVG.low;
          fvgCompletionTime = foundFVG.completionTime; // Store the correct time
          Print("Stored first FVG details.");
       }
       // else Print("Still searching for first FVG after London Open...");
   }
   // We now proceed using the globally stored FVG info if fvgFoundToday is true

   // 2. Check for inversion if FVG is found but not yet inverted
   if(fvgFoundToday && !fvgInvertedToday)
   {
      // Construct temporary FVGInfo from globals for checking
       FVGInfo tempFVG;
       tempFVG.found = true; // Already confirmed
       tempFVG.isBearish = fvgIsBearish;
       tempFVG.high = fvgHigh;
       tempFVG.low = fvgLow;
       tempFVG.completionTime = fvgCompletionTime; // Use the correct completion time

       if (CheckFVGInversion(tempFVG))
       {
           Print("FVG inversion confirmed for today.");
           // Global flags fvgInvertedToday, inversionLevel, inversionTime are updated inside CheckFVGInversion
       }
       // else Print("FVG found, awaiting inversion...");

   }

   // 3. Check for retest and place trade if FVG inverted and no trade opened yet for today
   if(fvgFoundToday && fvgInvertedToday && !tradeOpenedToday)
   {
        if(CheckRetest()) // CheckRetest now uses global flags/levels
        {
            Print("Retest confirmed, attempting to place trade...");
            PlaceTrade(); // PlaceTrade also uses global flags/levels
        }
        // else Print("FVG inverted, awaiting retest...");
   }
    // --- Added Check: If Session is over and no trade was placed, reset ---
   MqlDateTime currentDT;
   TimeToStruct(serverTimeCurrent, currentDT);
   if(currentDT.hour >= LondonCloseHour && !tradeOpenedToday && fvgFoundToday)
   {
      Print("London session ended, no trade triggered for today's FVG. Resetting.");
      ResetDailyVariables();
   }

}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Cleanup
   Print("London FVG Inversion V1.01 Deinitialized. Reason: ", reason);
}
//+------------------------------------------------------------------+