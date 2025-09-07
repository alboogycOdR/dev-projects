//+------------------------------------------------------------------+
//|                                    London_FVG_Inversion_V1.mq5 |
//|                        Copyright 2023, Generated from Strategy |
//|                                              Strategy Developer |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Generated from Strategy"
#property link      "None"
#property version   "1.00"
#property strict
/*
   Next Steps (Beyond V1):
   Refine Stop Loss logic (e.g., using ATR or finding swing points).
   Improve retest detection (e.g., require candle pattern confirmation).
   Add option for Break-Even.
   Add Trailing Stop Loss.
   Potentially integrate logic for Liquidity Sweeps/DOL (more complex).
   Add filters (e.g., MA filter, Higher Timeframe bias check).
   Improve time zone handling (if possible within MQL5 limitations or using external libraries).
   More robust trade management (handling partial closes, multiple positions if desired).
   Add News Filter (requires external data integration).
*/
#include <Trade\Trade.mqh> // Trading class

//--- Input Parameters
input group           "Trading Session (Broker Server Time)"
input int             LondonOpenHour    = 10; // ===> IMPORTANT: Set BROKER Server Hour corresponding to 3 AM NYT <===
input int             LondonCloseHour   = 18; // ===> IMPORTANT: Set BROKER Server Hour corresponding to 7 AM NYT <===

input group           "Trade Settings"
input double          Lots              = 0.01;   // Lot size
input double          RiskRewardRatio   = 2.0;    // Risk:Reward Ratio (e.g., 2.0 for 1:2)
input int             StopLossPips      = 15;     // ===> V1: Fixed SL in Pips beyond inversion high/low <===
input ulong           MagicNumber       = 123450; // Magic number for EA orders

input group           "FVG Settings"
input int             MaxBarsToCheckFVG = 100;    // How many bars back to check for FVG/Inversion

//--- Global Variables
CTrade            trade;                  // Trading object
bool              fvgFoundToday     = false; // Flag if FVG found for the current day's London session
bool              fvgInvertedToday  = false; // Flag if the daily FVG has been inverted
bool              tradeOpenedToday  = false; // Flag if a trade has been opened based on today's setup
bool              fvgIsBearish      = false; // True if bearish FVG, false if bullish
double            fvgHigh           = 0.0;   // High price of the FVG zone
double            fvgLow            = 0.0;   // Low price of the FVG zone
datetime          fvgCandleTime     = 0;     // Time of the *middle* candle of the FVG formation
double            inversionLevel    = 0.0;   // The price level (FVG high or low) that was breached for inversion
datetime          inversionTime     = 0;     // Time the inversion occurred
int               dayResetCheck     = -1;    // Helper to detect new day

// Structure to hold FVG info
struct FVGInfo
{
   bool     found;
   bool     isBearish;
   double   high;
   double   low;
   datetime candleTime; // Time of the *middle* candle (bar index 1 relative to formation)
   int      indexFormed; // Bar index where the FVG formation completed (index of 3rd candle)
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

   Print("London FVG Inversion V1 Initialized.");
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
   fvgCandleTime = 0;
   inversionLevel = 0.0;
   inversionTime = 0;
   // Print("Daily variables reset for ", TimeToString(TimeCurrent(), TIME_DATE));
}
//+------------------------------------------------------------------+
//| Check if current time is within London Session                  |
//+------------------------------------------------------------------+
bool IsLondonSession(datetime currentTime)
{
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);

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
   int barsCopied = CopyRates(_Symbol, PERIOD_M15, 0, MaxBarsToCheckFVG, rates);

   if(barsCopied < 3)
   {
      // Print("Not enough history to find FVG");
      return fvg; // Not enough bars
   }

   // Iterate backwards from the last completed bar (index 1)
   // candles are indexed rates[i=3rd], rates[i+1=2nd], rates[i+2=1st]
   for(int i = barsCopied - 3; i >= 1; i--)
   {
      // --- Check if the FVG formed *after* the London Open time ---
      // We check the time of the third candle's completion
       if(rates[i].time < londonOpenTimeToday) continue; // Skip FVGs formed before session open


      // Check Bearish FVG (Gap between low of candle 1 and high of candle 3)
      if(rates[i+2].low > rates[i].high)
      {
         fvg.found = true;
         fvg.isBearish = true;
         fvg.high = rates[i+2].low;  // Top of bearish FVG zone
         fvg.low = rates[i].high;   // Bottom of bearish FVG zone
         fvg.candleTime = rates[i+1].time; // Time of the middle candle
         fvg.indexFormed = i;
         // PrintFormat("Bearish FVG Found: High=%.5f, Low=%.5f, Time=%s, Index=%d", fvg.high, fvg.low, TimeToString(fvg.candleTime), fvg.indexFormed);
         return fvg; // Return the *first* one found after open
      }

      // Check Bullish FVG (Gap between high of candle 1 and low of candle 3)
       if(rates[i+2].high < rates[i].low)
      {
         fvg.found = true;
         fvg.isBearish = false;
         fvg.high = rates[i].low;    // Top of bullish FVG zone
         fvg.low = rates[i+2].high; // Bottom of bullish FVG zone
         fvg.candleTime = rates[i+1].time; // Time of the middle candle
         fvg.indexFormed = i;
        // PrintFormat("Bullish FVG Found: High=%.5f, Low=%.5f, Time=%s, Index=%d", fvg.high, fvg.low, TimeToString(fvg.candleTime), fvg.indexFormed);
         return fvg; // Return the *first* one found after open
      }
   }

   return fvg; // No suitable FVG found
}

//+------------------------------------------------------------------+
//| Check for FVG Inversion                                          |
//+------------------------------------------------------------------+
bool CheckFVGInversion(const FVGInfo &fvg)
{
    if (!fvg.found || fvgInvertedToday) return false; // Cannot check if no FVG or already inverted today

    MqlRates rates[];
    // Check bars AFTER the FVG formation index up to the current completed bar
    int barsToCheck = Bars(_Symbol, PERIOD_M15) - fvg.indexFormed; // Get count of bars since FVG formed
    if (barsToCheck <= 0) return false; // No new bars since FVG

    // Copy only the bars needed, starting from the FVG formation index + 1
    // Need at least one bar after FVG formed to check inversion
    if(CopyRates(_Symbol, PERIOD_M15, fvg.indexFormed + 1, barsToCheck, rates) < 1) return false;


    // Iterate forwards from the bar *after* FVG formed up to the most recently completed bar
    for(int i = 0; i < barsToCheck; i++) // rates[i] corresponds to original chart index fvg.indexFormed + 1 + i
    {
         if(rates[i].time <= fvg.candleTime) continue; // Should not happen with indexing, but safety check

         // Check for Bullish FVG inversion (candle closes BELOW fvgLow)
         if(!fvg.isBearish && rates[i].close < fvg.low)
         {
            fvgInvertedToday = true;
            inversionLevel = fvg.low; // Inversion happened at the low boundary
            inversionTime = rates[i].time;
            // PrintFormat("Bullish FVG Inverted (Bearish Signal): Level=%.5f, Time=%s", inversionLevel, TimeToString(inversionTime));
            return true;
         }
         // Check for Bearish FVG inversion (candle closes ABOVE fvgHigh)
          if(fvg.isBearish && rates[i].close > fvg.high)
         {
            fvgInvertedToday = true;
            inversionLevel = fvg.high; // Inversion happened at the high boundary
            inversionTime = rates[i].time;
            // PrintFormat("Bearish FVG Inverted (Bullish Signal): Level=%.5f, Time=%s", inversionLevel, TimeToString(inversionTime));
            return true;
         }
    }

    return false; // No inversion found yet
}


//+------------------------------------------------------------------+
//| Check for Retest of Inversion Level                             |
//+------------------------------------------------------------------+
bool CheckRetest(const FVGInfo &fvg)
{
   if(!fvgFoundToday || !fvgInvertedToday || tradeOpenedToday || inversionTime == 0) return false;

   MqlRates rates[5]; // Check last few bars for retest
   if(CopyRates(_Symbol, PERIOD_M15, 1, 5, rates) < 1) return false; // Get last 5 completed bars

   for(int i=0; i<ArraySize(rates); i++)
   {
       if(rates[i].time <= inversionTime) continue; // Only check bars after inversion

      // Check for retest for BUY (price dips to or below inverted bearish FVG's high boundary)
       if(fvg.isBearish && rates[i].low <= inversionLevel) // fvgIsBearish means original FVG was bearish, inversion makes it bullish support
       {
           // PrintFormat("Retest for BUY occurred at %s (Low: %.5f <= Inversion: %.5f)", TimeToString(rates[i].time), rates[i].low, inversionLevel);
           return true;
       }
       // Check for retest for SELL (price rises to or above inverted bullish FVG's low boundary)
       if(!fvg.isBearish && rates[i].high >= inversionLevel) // !fvgIsBearish means original FVG was bullish, inversion makes it bearish resistance
       {
          // PrintFormat("Retest for SELL occurred at %s (High: %.5f >= Inversion: %.5f)", TimeToString(rates[i].time), rates[i].high, inversionLevel);
          return true;
       }
   }
   return false;
}
//+------------------------------------------------------------------+
//| Place Trade Function                                            |
//+------------------------------------------------------------------+
void PlaceTrade(const FVGInfo &fvg)
{
   if(!fvgFoundToday || !fvgInvertedToday || tradeOpenedToday) return; // Sanity checks

   // Check if we already have a position for this EA
   if(PositionSelectByTicket(0) == false) // Fast way to check if any position is open for *any* symbol/magic by this EA instance (might need refinement)
     {
      if(PositionsTotal() > 0) // Crude check if *any* position is open on the account
        {
         bool positionExists = false;
         for(int i = PositionsTotal() - 1; i >= 0; i--)
           {
            ulong ticket = PositionGetTicket(i);
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
              {
               positionExists = true;
               break;
              }
           }
         if(positionExists)
           {
            // Print("Position already exists for this symbol and magic number.");
            return; // Don't open another trade
           }
        }
     }
   else
     {
      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
         // Print("Position already exists for this symbol and magic number.");
         return; // Don't open another trade
        }
     }


   double slPipsValue = StopLossPips * _Point * 10; // MQL5 point conversion might need adjustment based on broker (e.g. *10 for 5-digit) - USE PIPs for clarity
   double slDistance = StopLossPips * _Point * (SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5 ? 10 : 1); // Adjust for JPY pairs / 5 digit brokers
   double tpDistance = slDistance * RiskRewardRatio;
   double entryPrice = SymbolInfoDouble(_Symbol, fvg.isBearish ? SYMBOL_ASK : SYMBOL_BID); // Ask for buy, Bid for sell
   double stopLoss = 0;
   double takeProfit = 0;

   // Determine direction based on which FVG was inverted
   if(fvg.isBearish) // Original was Bearish -> Inverted -> Bullish Setup -> BUY
   {
       entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
       stopLoss = inversionLevel - slDistance; // V1 SL below inversion level
       // Alternative SL - below FVG low: stopLoss = fvg.low - slDistance; // Needs testing
       takeProfit = entryPrice + tpDistance;
       if(!trade.Buy(Lots, _Symbol, entryPrice, stopLoss, takeProfit, "London FVG V1 Buy"))
       {
         Print("Buy Order failed: ", trade.ResultRetcodeDescription());
       }
       else
       {
          Print("Buy Order Placed: SL=", NormalizeDouble(stopLoss, _Digits), " TP=", NormalizeDouble(takeProfit, _Digits));
          tradeOpenedToday = true;
       }
   }
   else // Original was Bullish -> Inverted -> Bearish Setup -> SELL
   {
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      stopLoss = inversionLevel + slDistance; // V1 SL above inversion level
      // Alternative SL - above FVG high: stopLoss = fvg.high + slDistance; // Needs testing
      takeProfit = entryPrice - tpDistance;
       if(!trade.Sell(Lots, _Symbol, entryPrice, stopLoss, takeProfit, "London FVG V1 Sell"))
       {
           Print("Sell Order failed: ", trade.ResultRetcodeDescription());
       }
        else
       {
           Print("Sell Order Placed: SL=", NormalizeDouble(stopLoss, _Digits), " TP=", NormalizeDouble(takeProfit, _Digits));
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
   datetime currentTime = (datetime)SeriesInfoInteger(_Symbol, PERIOD_M15, SERIES_LASTBAR_DATE); // Time of the current M15 bar start

   if(currentTime == lastBarTime) return; // Not a new bar
   lastBarTime = currentTime;

   //--- Check for new day to reset flags
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day != dayResetCheck)
   {
      ResetDailyVariables();
      dayResetCheck = dt.day;
   }

   //--- Check if inside London session
    datetime serverTimeCurrent = TimeCurrent(); // Use current server time for session check
    if (!IsLondonSession(serverTimeCurrent)) {
       // If session ended, ensure flags are ready for next day (optional, handled by daily reset)
       // if (fvgFoundToday && !tradeOpenedToday) ResetDailyVariables(); // Optionally reset if session ends without trade
       return;
    }

    // --- Define London Open Time for *today* ---
    MqlDateTime todayDT;
    TimeToStruct(serverTimeCurrent, todayDT); // Get current date parts
    todayDT.hour = LondonOpenHour;
    todayDT.min = 0;
    todayDT.sec = 0;
    datetime londonOpenTimeToday = StructToTime(todayDT);


   //--- Trading Logic Flow
   FVGInfo currentFVG = { false };

   // 1. Find FVG if not found yet for today's session
   if(!fvgFoundToday)
   {
       currentFVG = FindFirstFVG_AfterLondonOpen(londonOpenTimeToday);
       if(currentFVG.found)
       {
          fvgFoundToday = true;
          fvgIsBearish = currentFVG.isBearish;
          fvgHigh = currentFVG.high;
          fvgLow = currentFVG.low;
          fvgCandleTime = currentFVG.candleTime;
           // Store FVG details globally if found
       }
   } else {
       // Ensure global FVG data persists if already found
       currentFVG.found = true;
       currentFVG.isBearish = fvgIsBearish;
       currentFVG.high = fvgHigh;
       currentFVG.low = fvgLow;
       currentFVG.candleTime = fvgCandleTime;
   }

   // 2. Check for inversion if FVG is found but not yet inverted
   if(fvgFoundToday && !fvgInvertedToday)
   {
      CheckFVGInversion(currentFVG); // Updates global fvgInvertedToday, inversionLevel, inversionTime if true
   }

   // 3. Check for retest and place trade if FVG inverted and no trade opened yet
   if(fvgFoundToday && fvgInvertedToday && !tradeOpenedToday)
   {
        if(CheckRetest(currentFVG))
        {
            PlaceTrade(currentFVG); // Attempts to place the trade
        }
   }
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Cleanup
   Print("London FVG Inversion V1 Deinitialized. Reason: ", reason);
}
//+------------------------------------------------------------------+