//+------------------------------------------------------------------+
//| Expert Advisor: Mitigation Order Blocks Strategy (SMC Liquidity Mod) |
//+------------------------------------------------------------------+
// Original Idea: https://www.mql5.com/en/job/235273
// SMC Liquidity Concept Added
/*
TESTER CONFIG

    05 NOV 2024 - START TIME
     EURUSD

PROMPT ASSISTENCE
https://aistudio.google.com/prompts/1YFz1Joxxms7Tv6oI8fWjL5jt5Bqrvtt-

*/
#include <Trade\Trade.mqh>  // Include Trade library for CTrade class
 ulong MagicNumber = 12345;
/*
   MODIFIED STRATEGY (SMC Liquidity Grab):
   1. Order Block Identification (IdentifyOrderBlock):
      - Looks back for consolidation (optional: range < 0.5 * ATR).
      - Checks for a strong move after consolidation (optional: > 1.5 * ATR).
      - Defines Bullish/Bearish OB zone (high/low of consolidation).
   2. Liquidity Zone Definition:
      - For Bullish OB: Zone below OB low (size based on ATR * ATR_Multiplier_Liq).
      - For Bearish OB: Zone above OB high (size based on ATR * ATR_Multiplier_Liq).
   3. Entry Signal Check (CheckSMCSignal - Replaces CheckMitigation):
      - Runs on new bar for non-traded OBs (!mitigated).
      - Checks if the *previous* bar (index 1):
         - Bullish OB: Low dipped into liquidity zone (low1 <= liqBottom) AND Close reversed back inside OB (close1 >= obLow && close1 <= obHigh).
         - Bearish OB: High spiked into liquidity zone (high1 >= liqTop) AND Close reversed back inside OB (close1 <= obHigh && close1 >= obLow).
   4. Market Structure Confirmation (Optional):
      - Uses H4 SMA (`ConfirmMarketStructure`) if enabled.
   5. Trade Execution (PlaceSMCTrade - Called from CheckSMCSignal):
      - If signal valid (+ optional H4 filter passes) and trading allowed:
         - Enters market order (Buy for Bullish OB, Sell for Bearish OB).
         - Lot size: Calculated based on RiskPercent and distance to SL.
         - Stop Loss (SL): Placed just beyond the liquidity zone (liqBottom/liqTop + buffer).
         - Take Profit (TP): Calculated based on SL and takeProfitRR.
      - Marks OB as traded (`mitigated = true`).
   In summary: Trade is taken when price grabs liquidity just outside an OB and then reverses back into it, optionally confirming with H4 trend.
*/

// Input Parameters
input group "Order Block Identification"
input int LookbackPeriod = 500;        // Lookback period for initial Order Block identification
input int ConsolidationPeriod = 15;    // Number of bars to check for consolidation (def: 20)
 int ATRPeriod = 14;              // ATR period for volatility measurement
input bool CheckConsolidationRange = true; // Enable/disable consolidation range check (vs 0.5*ATR)
input bool CheckStrongMoveATR = true;     // Enable/disable strong move check (vs 1.5*ATR)
input double ATRCOFACTOR = 1.1;//atr multiplier (Def 1.5))

input group "SMC Liquidity & Entry"
/*
ATR_Multiplier_Liq is key for signal filtering and frequency.

stopLossBufferPips is key for SL robustness vs. risk size.

takeProfitRR is key for the strategy's win rate vs. reward profile.
*/
input double ATR_Multiplier_Liq = 0.5;    // ATR multiplier for liquidity zone size (k)
/*
Impact:

Smaller Value (e.g., 0.2, 0.3): 
The liquidity zone is smaller and closer to the OB boundary. 
Price doesn't need to pierce very far beyond the OB to potentially trigger the 
"liquidityGrabbed" condition. This will likely lead to more frequent signals, but they 
might represent less significant liquidity grabs (potentially more false signals or weaker reversals).

Larger Value (e.g., 0.8, 1.0, 1.2): 
The zone is larger, requiring a deeper price probe beyond the OB. This will l
ikely lead to fewer signals, but the ones that occur might represent more significant 
stops being hunted or a stronger rejection from levels further away (potentially higher quality signals).
*/
input double stopLossBufferPips = 5.0;      // Extra pips buffer for Stop Loss placement beyond liquidity zone
/*
Smaller Value (e.g., 1.0, 2.0): Tighter stop loss, closer to the liquidity grab point. Reduces initial risk per trade (allowing potentially larger lot size for the same % risk), but increases the chance of being stopped out by spread or minor volatility/noise just beyond the grab level.

Larger Value (e.g., 8.0, 10.0): Wider stop loss, giving the trade more breathing room. Decreases the chance of being stopped out by noise/spread, but increases initial risk per trade (requiring smaller lot size for the same % risk) and pushes the Take Profit level further away (for the same RR).
*/
input double takeProfitRR = 2.0;          // Risk:Reward Ratio for Take Profit calculation
/*
Lower Value (e.g., 1.0, 1.5): Closer Take Profit. Likely increases the win rate
 (easier to hit the TP), but results in smaller winning trades. Might lead to a
  smoother equity curve but potentially lower overall profit.

Higher Value (e.g., 2.5, 3.0): Further Take Profit. Likely decreases the win rate
 (harder to hit the TP), but results in larger winning trades. Can lead to higher potential 
 profit but potentially larger drawdowns between wins and a choppier equity curve.
*/
input group "Risk Management"
input double RiskPercent = 1.0;        // Risk percentage per trade
input double MaxDailyLoss = 5.0;       // Maximum daily loss percentage

input group "Market Structure Filter"
input bool UseMarketStructureFilter = false; // Enable/disable H4 SMA filter
input int MAPeriod = 20;               // Moving average period for market structure filter (H4)

input group "Visualization"
// Define distinct colors
input color bullishOBColor = clrDeepSkyBlue; // Color for active Bullish OB
input color bearishOBColor = clrOrangeRed;   // Color for active Bearish OB
input color tradedColor = clrGray;         // Color for OB after trade is taken (formerly mitigated)

// Global Variables
struct OrderBlock {
   double high;        // High of the Order Block zone (consolidation high)
   double low;         // Low of the Order Block zone (consolidation low)
   bool isBullish;     // True for bullish, false for bearish
   bool mitigated;     // <<<< NOW MEANS: True if SMC trade taken based on this block >>>>
   int barIndex;       // Bar index where consolidation started
   // Removed: hasEntrySignal, entryLevel (obsolete under new logic)
};

OrderBlock orderBlocks[];
int blockCount = 0;
datetime lastBarTime = 0;
double startOfDayEquity = 0;
int lastDay = 0;
bool tradingAllowed = true;

// Indicator handles
int atrHandle = INVALID_HANDLE;
int maHandle = INVALID_HANDLE; // For H4 SMA filter

// Global Trade object
CTrade trade;

//+------------------------------------------------------------------+
//| Get day of year from datetime                                    |
//+------------------------------------------------------------------+
int DayOfYear(datetime time) {
   MqlDateTime dt;
   TimeToStruct(time, dt);
   return dt.day_of_year;
}

//+------------------------------------------------------------------+
//| Get ATR value for a specific bar                                 |
//+------------------------------------------------------------------+
double GetATR(int period, int shift) {
   // Ensure handle is valid
   if(atrHandle == INVALID_HANDLE) {
       atrHandle = iATR(_Symbol, PERIOD_CURRENT, period);
       if(atrHandle == INVALID_HANDLE) {
          Print("Error creating ATR indicator in GetATR: ", GetLastError());
          return 0.0;
       }
   }

   // Ensure enough bars are available on the chart
   if(shift >= Bars(_Symbol, PERIOD_CURRENT)) {
      // Print("Requested ATR shift ", shift, " is beyond available bars ", Bars(_Symbol, PERIOD_CURRENT));
      return 0.0; // Or handle appropriately
   }

   // Wait for the data to be calculated if needed (basic check)
    int calculated = BarsCalculated(atrHandle);
    if(calculated <= shift) {
       // Potentially wait or return 0.0 if data isn't ready
       // Print("ATR indicator not calculated enough bars: ", calculated, " needed: ", shift + 1);
       // Sleep(100); // Use Sleep cautiously
       return 0.0;
    }


   // Copy the ATR data
   double atr_buffer[];
   if(CopyBuffer(atrHandle, 0, shift, 1, atr_buffer) <= 0) {
      // int error = GetLastError();
      // Print("Error copying ATR data (Shift ", shift, "): ", error);
      // Consider resetting handle if error is persistent (e.g., 4066 means data not ready yet)
      // if(error != 4066 && error != 4099) { /* Handle reset? */ }
      return 0.0;
   }

   // Basic validation
   if(atr_buffer[0] <= 0 || !MathIsValidNumber(atr_buffer[0])) {
       // Print("Invalid ATR value retrieved (Shift ", shift, "): ", atr_buffer[0]);
       return 0.0;
   }

   return atr_buffer[0];
}


//+------------------------------------------------------------------+
//| Get MA value for a specific bar on H4 timeframe                  |
//+------------------------------------------------------------------+
double GetMAH4(int period, int shift) {
    // Ensure handle is valid
    if(maHandle == INVALID_HANDLE) {
        maHandle = iMA(_Symbol, PERIOD_H4, period, 0, MODE_SMA, PRICE_CLOSE);
        if(maHandle == INVALID_HANDLE) {
            Print("Error creating H4 MA indicator: ", GetLastError());
            return 0.0;
        }
    }

    // Check available H4 bars (relative to current time)
    int h4BarsAvailable = iBars(_Symbol, PERIOD_H4);
    if (h4BarsAvailable <= shift) {
        // Print("Not enough H4 bars available for MA calculation. Available: ", h4BarsAvailable, " Needed: ", shift+1);
        return 0.0;
    }

    // Wait for data (basic check)
    int calculated = BarsCalculated(maHandle);
    if(calculated <= shift) {
        // Print("H4 MA indicator not calculated enough bars: ", calculated, " needed: ", shift + 1);
        // Sleep(100); // Use Sleep cautiously
        return 0.0;
    }

    // Copy MA data
    double ma_buffer[];
    if(CopyBuffer(maHandle, 0, shift, 1, ma_buffer) <= 0) {
        // int error = GetLastError();
        // Print("Error copying H4 MA data: ", error);
        // Consider handle reset on persistent errors
        return 0.0;
    }

    if(!MathIsValidNumber(ma_buffer[0])) {
        // Print("Invalid H4 MA value retrieved: ", ma_buffer[0]);
        return 0.0;
    }

    return ma_buffer[0];
}


//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Resize the Order Blocks array (initial size)
   ArrayResize(orderBlocks, 100);
   blockCount = 0;

   // Initialize daily equity tracking
   startOfDayEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   lastDay = DayOfYear(TimeCurrent());
   tradingAllowed = true;

   // Initialize indicators
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   if(atrHandle == INVALID_HANDLE) {
      Print("Error creating ATR indicator OnInit: ", GetLastError());
      return INIT_FAILED;
   }

   // Only initialize MA handle if filter is enabled
   if (UseMarketStructureFilter) {
       maHandle = iMA(_Symbol, PERIOD_H4, MAPeriod, 0, MODE_SMA, PRICE_CLOSE);
       if(maHandle == INVALID_HANDLE) {
          Print("Error creating H4 MA indicator OnInit: ", GetLastError());
          // Allow initialization even if MA fails? Or return INIT_FAILED?
          // Depending on strictness, you might return INIT_FAILED here.
          // return INIT_FAILED;
       }
   } else {
       maHandle = INVALID_HANDLE; // Ensure it's invalid if not used
   }

   // Draw initial Order Blocks from history
   IdentifyInitialOrderBlocks();

   // Set Magic Number for CTrade
   trade.SetExpertMagicNumber(MagicNumber); // Use default MagicNumber or add input

   Print("EA Initialized: ", _Symbol, " ", EnumToString(_Period));
   Print("SMC Liquidity Grab Strategy Enabled.");
   Print("Risk Percent: ", RiskPercent, "%, Daily Loss Limit: ", MaxDailyLoss, "%");
   Print("H4 MA Filter: ", (UseMarketStructureFilter ? "Enabled (Period " + IntegerToString(MAPeriod) + ")" : "Disabled"));


   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime != lastBarTime) {
      lastBarTime = currentBarTime;
      OnNewBar(); // Process logic on the new bar
   }

   // Check daily loss limit (check every tick to stop trading immediately if limit hit)
   CheckDailyLossLimit();

   // Removed direct call to ExecuteTrades - logic moved to OnNewBar/CheckSMCSignal
}

//+------------------------------------------------------------------+
//| New Bar Event Handler                                            |
//+------------------------------------------------------------------+
void OnNewBar() {
   // Identify potential new Order Blocks based on the most recent bars
   IdentifyNewOrderBlocks();

   // Check existing, non-traded Order Blocks for SMC entry signals
   CheckSMCSignal();
}

//+------------------------------------------------------------------+
//| Identify Initial Order Blocks on Startup                         |
//+------------------------------------------------------------------+
void IdentifyInitialOrderBlocks() {
   Print("Identifying initial order blocks from bar ", LookbackPeriod, " to ", ConsolidationPeriod + 1);
   int identifiedCount = 0;
   for(int i = LookbackPeriod; i >= ConsolidationPeriod + 1; i--) {
      if(IdentifyOrderBlock(i)) {
         VisualizeOrderBlock(blockCount - 1); // Visualize the newly added block
         identifiedCount++;
      }
   }
   Print("Initial identification complete. Found ", identifiedCount, " potential OBs.");
}

//+------------------------------------------------------------------+
//| Identify New Order Blocks                                        |
//+------------------------------------------------------------------+
void IdentifyNewOrderBlocks() {
   // Check only the most recent possibility on a new bar
   if(IdentifyOrderBlock(ConsolidationPeriod + 1)) { // Check based on the bar that just closed + consolidation period
      VisualizeOrderBlock(blockCount - 1);
      Print("New potential OB identified and visualized. Total OBs: ", blockCount);
   }
}

//+------------------------------------------------------------------+
//| Identify an Order Block at a Given Starting Bar                  |
//+------------------------------------------------------------------+
bool IdentifyOrderBlock(int startBar) {
   // --- This function remains largely the same as original ob-AIGEN ---
   // --- It identifies the OB zone based on consolidation and strong move ---

   int barsAvailable = (int)Bars(_Symbol, PERIOD_CURRENT);
   // Ensure enough bars for the entire check (start bar + consolidation + move bar)
   if (startBar + 1 >= barsAvailable) { // Need at least startBar and the bar *after* consolidation (startBar - ConsolidationPeriod - 1)
        // Print("IdentifyOrderBlock: Not enough bars (", barsAvailable, ") for startBar ", startBar);
        return false;
   }
    // Specifically check index for the move bar
    int moveBarIndex = startBar - ConsolidationPeriod -1;
    if (moveBarIndex < 0) {
        // Print("IdentifyOrderBlock: Calculated moveBarIndex ", moveBarIndex, " is invalid for startBar ", startBar);
        return false;
    }


   // --- Calculate Consolidation Range ---
   // Initialize high/low with the *first* bar of the potential consolidation period
   int firstConsBar = startBar - ConsolidationPeriod;
    if (firstConsBar < 0) {
        // Print("IdentifyOrderBlock: Calculated firstConsBar ", firstConsBar, " is invalid for startBar ", startBar);
        return false; // Not enough history
    }

   double consHigh = iHigh(_Symbol, PERIOD_CURRENT, startBar); // Start with the latest bar in the potential range
   double consLow = iLow(_Symbol, PERIOD_CURRENT, startBar);

   for(int i = startBar - 1; i >= firstConsBar; i--) {
      if (i < 0) break; // Safety break, though initial check should prevent this
      double h = iHigh(_Symbol, PERIOD_CURRENT, i);
      double l = iLow(_Symbol, PERIOD_CURRENT, i);
      consHigh = MathMax(consHigh, h);
      consLow = MathMin(consLow, l);
   }

    // Check for zero range
    if (consHigh <= consLow) {
        // Print("IdentifyOrderBlock: Invalid consolidation range (High <= Low) at startBar ", startBar);
        return false;
    }


   // --- Optional ATR Checks (kept from original logic) ---
   double atr = 0;
   if (CheckConsolidationRange || CheckStrongMoveATR) {
        atr = GetATR(ATRPeriod, startBar); // Get ATR relevant to the consolidation period
        if (atr <= 0) {
           Print("IdentifyOrderBlock: Invalid ATR (", atr, ") at bar ", startBar, ". Skipping ATR checks.");
           // Decide whether to proceed without ATR checks or return false
           if (CheckConsolidationRange || CheckStrongMoveATR) return false; // Strict: If checks enabled but ATR fails, fail OB identification.
        }
   }

   // Optional: Check for consolidation range vs ATR
   if (CheckConsolidationRange && atr > 0) {
      if (consHigh - consLow >= 0.5 * atr) { // Use '>=' for safer comparison
         // Print("IdentifyOrderBlock: Consolidation range ", consHigh-consLow, " too large vs 0.5*ATR ", 0.5*atr, " at startBar ", startBar);
         return false; // Range too large
      }
   }

   // --- Check for strong move after consolidation ---
   double nextClose = iClose(_Symbol, PERIOD_CURRENT, moveBarIndex);
   bool isBullishMove = false;
   bool isBearishMove = false;

   if (CheckStrongMoveATR && atr > 0) {
      // Check using ATR multiplier
      isBullishMove = (nextClose - consHigh >= ATRCOFACTOR * atr); // Use '>='
      isBearishMove = (consLow - nextClose >= ATRCOFACTOR * atr); // Use '>='
      // if (!isBullishMove && !isBearishMove) Print("IdentifyOrderBlock: Move not strong enough vs 1.5*ATR at startBar ", startBar);
   } else if (!CheckStrongMoveATR) { // Check only if ATR check is disabled
      // Check simply if close is beyond the range (without ATR)
      isBullishMove = (nextClose > consHigh);
      isBearishMove = (nextClose < consLow);
      // if (!isBullishMove && !isBearishMove) Print("IdentifyOrderBlock: Move not beyond consolidation range at startBar ", startBar);
   }
   // If CheckStrongMoveATR is true but atr <= 0, neither flag will be set here if strict return was used above.

   // --- Create Order Block Struct if conditions met ---
   if (isBullishMove) { // Bullish move identified
      if(blockCount >= ArraySize(orderBlocks)) ArrayResize(orderBlocks, blockCount + 50); // Increase size moderately
      orderBlocks[blockCount].high = consHigh; // Use consolidation high/low
      orderBlocks[blockCount].low = consLow;
      orderBlocks[blockCount].isBullish = true;
      orderBlocks[blockCount].mitigated = false; // Initialize as not traded
      orderBlocks[blockCount].barIndex = firstConsBar; // Store the index of the first bar in consolidation
      blockCount++;
      // Print("IdentifyOrderBlock: Bullish OB identified ending at bar ", startBar, " (Consolidation ", firstConsBar,"-",startBar,"). High: ", consHigh, ", Low: ", consLow);
      return true;
   }
   else if (isBearishMove) { // Bearish move identified
      if(blockCount >= ArraySize(orderBlocks)) ArrayResize(orderBlocks, blockCount + 50);
      orderBlocks[blockCount].high = consHigh;
      orderBlocks[blockCount].low = consLow;
      orderBlocks[blockCount].isBullish = false;
      orderBlocks[blockCount].mitigated = false; // Initialize as not traded
      orderBlocks[blockCount].barIndex = firstConsBar; // Store the index of the first bar in consolidation
      blockCount++;
      // Print("IdentifyOrderBlock: Bearish OB identified ending at bar ", startBar, " (Consolidation ", firstConsBar,"-",startBar,"). High: ", consHigh, ", Low: ", consLow);
      return true;
   }

   return false; // No qualifying OB found
}


//+------------------------------------------------------------------+
//| Check Existing OBs for SMC Signal & Trigger Trade                |
//+------------------------------------------------------------------+
void CheckSMCSignal() {
   if (!tradingAllowed) return; // Check daily loss limit flag

   // Get data of the last completed bar (index 1) - this bar's action determines the signal
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   datetime time1 = iTime(_Symbol, PERIOD_CURRENT, 1);

    // Check if we have bar 1 data
    if (Bars(_Symbol, PERIOD_CURRENT) < 2) {
        // Print("CheckSMCSignal: Not enough bars for analysis (need at least 2).");
        return;
    }


   // Get current ATR value from the last completed bar for liquidity zone calculation
   double currentATR = GetATR(ATRPeriod, 1);
   if (currentATR <= 0) {
       Print("CheckSMCSignal: Invalid ATR value (", currentATR, ") from bar 1. Skipping signal checks.");
       return; // Cannot calculate liquidity zones without valid ATR
   }
   double pointValue = _Point; // Cache point value

   // Loop through all identified order blocks
   for(int i = 0; i < blockCount; i++) {
      // Skip if already traded based on this OB
      if(orderBlocks[i].mitigated) continue;

      // Get OB details
      double obHigh = orderBlocks[i].high;
      double obLow = orderBlocks[i].low;
      bool isBullishOB = orderBlocks[i].isBullish;

      // Define Liquidity Zone
      double liqTop, liqBottom;
      double zoneSize = currentATR * ATR_Multiplier_Liq; // Use the specific multiplier for liquidity
      if (isBullishOB) {
          liqTop = obLow;                // Top of liquidity zone is OB low
          liqBottom = obLow - zoneSize;  // Bottom extends below OB low
      } else { // Bearish OB
          liqBottom = obHigh;            // Bottom of liquidity zone is OB high
          liqTop = obHigh + zoneSize;    // Top extends above OB high
      }
      // Normalize liquidity zone boundaries for accurate comparison
      liqTop = NormalizeDouble(liqTop, _Digits);
      liqBottom = NormalizeDouble(liqBottom, _Digits);

      // --- Check for Entry Signals based on the *previous* bar's action (bar 1) ---
      bool signalDetected = false;
      // Check Long Signal (Bullish OB)
      if (isBullishOB) {
          // Condition 1: Previous bar's low dipped into or below the liquidity zone
          bool liquidityGrabbed = (low1 <= liqBottom);
          // Condition 2: Previous bar's close reversed back *inside* the OB range
          bool reversedIntoOB = (close1 >= obLow && close1 <= obHigh);

          if (liquidityGrabbed && reversedIntoOB) {
               Print("SMC Long Signal Pre-Check Met for OB starting bar: ", orderBlocks[i].barIndex);
               Print(" -> Low1 (", low1, ") <= LiqBottom (", liqBottom, ")");
               Print(" -> Close1 (", close1, ") >= OB Low (", obLow, ") and <= OB High (", obHigh, ")");
               signalDetected = true;
          }
      }
      // Check Short Signal (Bearish OB)
      else { // isBearishOB
          // Condition 1: Previous bar's high spiked into or above the liquidity zone
          bool liquidityGrabbed = (high1 >= liqTop);
          // Condition 2: Previous bar's close reversed back *inside* the OB range
          bool reversedIntoOB = (close1 <= obHigh && close1 >= obLow);

          if (liquidityGrabbed && reversedIntoOB) {
               Print("SMC Short Signal Pre-Check Met for OB starting bar: ", orderBlocks[i].barIndex);
               Print(" -> High1 (", high1, ") >= LiqTop (", liqTop, ")");
               Print(" -> Close1 (", close1, ") <= OB High (", obHigh, ") and >= OB Low (", obLow, ")");
               signalDetected = true;
          }
      }

      // --- If signal detected, check optional filter and place trade ---
      if (signalDetected) {
          bool structureConfirmed = true; // Assume true if filter disabled
          if (UseMarketStructureFilter) {
              structureConfirmed = ConfirmMarketStructure(isBullishOB);
              if (!structureConfirmed) {
                  Print("SMC Signal found for OB ", orderBlocks[i].barIndex, " but H4 Structure Filter not confirmed.");
              }
          }

          if (structureConfirmed) {
              Print("SMC Signal CONFIRMED (with H4 filter if enabled) for OB ", orderBlocks[i].barIndex, ". Attempting trade...");
              // Place the trade
              double sl = isBullishOB ? (liqBottom - stopLossBufferPips * pointValue) : (liqTop + stopLossBufferPips * pointValue);
              // Pass liqBottom/liqTop for SL calculation
              if (PlaceSMCTrade(isBullishOB ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, sl, i)) {
                   // Trade placed successfully, flag already set in PlaceSMCTrade
                   // Break or continue? If only one trade per bar allowed, break here.
                   // If multiple signals on same bar could be traded, continue. Let's assume continue for now.
              } else {
                   Print("Failed to place SMC trade for OB ", orderBlocks[i].barIndex);
              }
          }
      }
   } // end loop through order blocks
}

//--- REMOVED IsBullishRejection Function ---
//--- REMOVED IsBearishRejection Function ---

//+------------------------------------------------------------------+
//| Confirm Market Structure on Higher Timeframe (H4 SMA)            |
//+------------------------------------------------------------------+
bool ConfirmMarketStructure(bool isBullishSignal) {
   // If filter is globally disabled, always return true
   if (!UseMarketStructureFilter) return true;

   // Get H4 SMA value (use shift 0 for the most recent completed H4 bar relative to now)
   double h4SMA = GetMAH4(MAPeriod, 0);
   if (h4SMA <= 0) {
        Print("ConfirmMarketStructure: Invalid H4 SMA value (", h4SMA, "). Filter inconclusive, returning false.");
        return false; // Treat invalid MA as non-confirmation
   }

   // Get current price on the *trading* timeframe to compare with H4 SMA
   // Using Ask for Bullish check, Bid for Bearish check might be slightly more robust at entry time
   double currentPrice = isBullishSignal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if (isBullishSignal) {
       return (currentPrice > h4SMA);
   } else { // Bearish Signal
       return (currentPrice < h4SMA);
   }
}


//--- REMOVED ExecuteTrades Function ---


//+------------------------------------------------------------------+
//| Place SMC Trade with Risk Management                             |
//+------------------------------------------------------------------+
// Returns true if trade placement was successful
bool PlaceSMCTrade(ENUM_ORDER_TYPE type, double stopLossPrice, int blockIndex) {
   // Normalize the proposed Stop Loss
   stopLossPrice = NormalizeDouble(stopLossPrice, _Digits);

   // Get current market price for entry
   double entryPrice;
   if (type == ORDER_TYPE_BUY) {
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   } else { // ORDER_TYPE_SELL
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   entryPrice = NormalizeDouble(entryPrice, _Digits); // Normalize entry price too

   // --- Validate Stop Loss ---
   if (type == ORDER_TYPE_BUY && stopLossPrice >= entryPrice) {
       Print("PlaceSMCTrade Error: Invalid SL for Buy order (SL >= Entry). SL=", stopLossPrice, " Entry=", entryPrice);
       return false;
   }
   if (type == ORDER_TYPE_SELL && stopLossPrice <= entryPrice) {
       Print("PlaceSMCTrade Error: Invalid SL for Sell order (SL <= Entry). SL=", stopLossPrice, " Entry=", entryPrice);
       return false;
   }
    // Check against stop level distance
    double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * Point();
    if (type == ORDER_TYPE_BUY && entryPrice - stopLossPrice < stopLevel) {
         Print("PlaceSMCTrade Error: Buy SL too close. Distance: ", (entryPrice - stopLossPrice), " Min Distance: ", stopLevel);
         // Optionally adjust SL slightly further away?
         // stopLossPrice = NormalizeDouble(entryPrice - stopLevel - Point(), _Digits); // Example adjustment
         return false; // Or just fail
    }
     if (type == ORDER_TYPE_SELL && stopLossPrice - entryPrice < stopLevel) {
         Print("PlaceSMCTrade Error: Sell SL too close. Distance: ", (stopLossPrice - entryPrice), " Min Distance: ", stopLevel);
         // stopLossPrice = NormalizeDouble(entryPrice + stopLevel + Point(), _Digits); // Example adjustment
         return false; // Or just fail
    }


   // --- Calculate Lot Size ---
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double stopLossDistancePoints = MathAbs(entryPrice - stopLossPrice); // Distance in price units

   if (stopLossDistancePoints <= 0 || tickSize <= 0) { // Prevent division by zero
       Print("PlaceSMCTrade Error: Invalid stop loss distance (", stopLossDistancePoints, ") or tick size (", tickSize, ")");
       return false;
   }

   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercent / 100.0);
   // Ensure riskAmount is positive
    if (riskAmount <= 0) {
        Print("PlaceSMCTrade Error: Invalid Risk Amount calculated: ", riskAmount);
        return false;
    }

   double riskPerLot = (stopLossDistancePoints / tickSize) * tickValue;
    if (riskPerLot <= 0) {
        Print("PlaceSMCTrade Error: Invalid Risk Per Lot calculated: ", riskPerLot);
        return false; // Avoid division by zero or invalid lots
    }

   double lotSize = NormalizeDouble(riskAmount / riskPerLot, 2); // Normalize to 2 decimal places for standard lots

   // --- Validate Lot Size ---
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if (lotSize < minLot) {
      Print("PlaceSMCTrade Warning: Calculated lot size (", lotSize, ") is below minimum (", minLot, "). Adjusting to minimum.");
      lotSize = minLot;
   }
   if (lotSize > maxLot) {
       Print("PlaceSMCTrade Warning: Calculated lot size (", lotSize, ") exceeds maximum (", maxLot, "). Adjusting to maximum.");
       lotSize = maxLot;
   }
   // Adjust lot size to match the volume step
   lotSize = NormalizeDouble(MathRound(lotSize / stepLot) * stepLot, LotDigits()); // Use LotDigits() helper

   // --- Calculate Take Profit ---
   double takeProfitPrice = 0;
   if (type == ORDER_TYPE_BUY) {
      takeProfitPrice = NormalizeDouble(entryPrice + stopLossDistancePoints * takeProfitRR, _Digits);
   } else {
      takeProfitPrice = NormalizeDouble(entryPrice - stopLossDistancePoints * takeProfitRR, _Digits);
   }

   // --- Validate Take Profit ---
    if (type == ORDER_TYPE_BUY && takeProfitPrice <= entryPrice) {
       Print("PlaceSMCTrade Error: Invalid TP for Buy order (TP <= Entry). TP=", takeProfitPrice, " Entry=", entryPrice);
       return false;
    }
    if (type == ORDER_TYPE_SELL && takeProfitPrice >= entryPrice) {
       Print("PlaceSMCTrade Error: Invalid TP for Sell order (TP >= Entry). TP=", takeProfitPrice, " Entry=", entryPrice);
       return false;
    }
     // Check against stop level distance for TP
    if (type == ORDER_TYPE_BUY && takeProfitPrice - entryPrice < stopLevel) {
         Print("PlaceSMCTrade Error: Buy TP too close. Distance: ", (takeProfitPrice - entryPrice), " Min Distance: ", stopLevel);
         return false;
    }
     if (type == ORDER_TYPE_SELL && entryPrice - takeProfitPrice < stopLevel) {
         Print("PlaceSMCTrade Error: Sell TP too close. Distance: ", (entryPrice - takeProfitPrice), " Min Distance: ", stopLevel);
         return false;
    }


   // --- Place the Trade ---
   string comment = (type == ORDER_TYPE_BUY ? "SMC Buy OB " : "SMC Sell OB ") + IntegerToString(orderBlocks[blockIndex].barIndex);
   bool result = false;

   if(type == ORDER_TYPE_BUY) {
      result = trade.Buy(lotSize, _Symbol, entryPrice, stopLossPrice, takeProfitPrice, comment);
   } else {
      result = trade.Sell(lotSize, _Symbol, entryPrice, stopLossPrice, takeProfitPrice, comment);
   }

   // --- Handle Result ---
   if(result) {
      Print("Trade Placed Successfully. Type: ", EnumToString(type), " Lots: ", lotSize, " Entry: ", entryPrice, " SL: ", stopLossPrice, " TP: ", takeProfitPrice, " Ticket: ", trade.ResultDeal());
      orderBlocks[blockIndex].mitigated = true; // Mark OB as traded
      //orderBlocks[blockIndex].hasEntrySignal = false; // Ensure old flags are clear
      //orderBlocks[blockIndex].entryLevel = 0;
      UpdateVisualization(blockIndex); // Update color to tradedColor
      return true;
   } else {
      Print("Trade Placement Failed. Error: ", trade.ResultRetcode(), " - ", trade.ResultComment());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Get Lot Digits                                                    |
//+------------------------------------------------------------------+
int LotDigits()
{
  double lot_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
  if(lot_step==1) return(0);
  if(lot_step==0.1) return(1);
  if(lot_step==0.01) return(2);
  if(lot_step==0.001) return(3);
  return(2); // Default to 2
}


//+------------------------------------------------------------------+
//| Check Daily Loss Limit                                           |
//+------------------------------------------------------------------+
void CheckDailyLossLimit() {
   // Only check if the limit is positive
    if (MaxDailyLoss <= 0) {
        tradingAllowed = true;
        return;
    }

   datetime currentTime = TimeCurrent();
   int currentDay = DayOfYear(currentTime);

   // Reset at the start of a new day
   if(currentDay != lastDay) {
      startOfDayEquity = AccountInfoDouble(ACCOUNT_EQUITY); // Use current equity as starting point
      lastDay = currentDay;
      if (!tradingAllowed) { // If trading was stopped previous day, re-enable it
         tradingAllowed = true;
         Print("New Day Started. Trading Re-enabled. Start Equity: ", startOfDayEquity);
      } else {
         Print("New Day Started. Start Equity Updated: ", startOfDayEquity);
      }
   }

   // Check if limit has been hit
   if (tradingAllowed) { // Only check if currently allowed
       double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
       double lossPercent = (startOfDayEquity > 0) ? ((startOfDayEquity - currentEquity) / startOfDayEquity) * 100.0 : 0;

       if(lossPercent >= MaxDailyLoss) {
          tradingAllowed = false;
          Print("Daily Loss Limit Reached (", DoubleToString(lossPercent, 2), "% >= ", MaxDailyLoss, "%). Trading stopped for today.");
          // Optional: Close all open trades?
          // CloseAllTrades();
       }
   }
}

//+------------------------------------------------------------------+
//| Visualize Order Block on Chart                                   |
//+------------------------------------------------------------------+
void VisualizeOrderBlock(int index) {
   // Use the first bar of consolidation as the unique identifier part of the name
   string name = "OB_SMC_" + IntegerToString(orderBlocks[index].barIndex);
   datetime timeStart = iTime(_Symbol, PERIOD_CURRENT, orderBlocks[index].barIndex);
   // Calculate end time based on the consolidation period to cover the relevant bars visually
   datetime timeEndCons = iTime(_Symbol, PERIOD_CURRENT, MathMax(0, orderBlocks[index].barIndex + ConsolidationPeriod)); // End of consolidation visually

   // Draw rectangle slightly into future for visibility
   int futureBars = 50; // How many bars forward to draw
   datetime timeEndVisual = TimeCurrent() + futureBars * PeriodSeconds(); // Extend from current time


   ObjectCreate(0, name, OBJ_RECTANGLE, 0, timeStart, orderBlocks[index].high, timeEndVisual, orderBlocks[index].low);
   // Set color based on OB type
   ObjectSetInteger(0, name, OBJPROP_COLOR, orderBlocks[index].isBullish ? bullishOBColor : bearishOBColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT); // Use dotted or dashed for active?
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_FILL, false); // Don't fill active OBs
   ObjectSetInteger(0, name, OBJPROP_BACK, true); // Draw behind price
   ObjectSetString(0, name, OBJPROP_TOOLTIP, (orderBlocks[index].isBullish ? "Bullish OB" : "Bearish OB") + "\nStart Bar: " + IntegerToString(orderBlocks[index].barIndex));
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Visualization When Traded                                |
//+------------------------------------------------------------------+
void UpdateVisualization(int index) {
   // Find the object name using the start bar index stored in the struct
   string name = "OB_SMC_" + IntegerToString(orderBlocks[index].barIndex);
   if (ObjectFind(0, name) >= 0) { // Check if object exists
       ObjectSetInteger(0, name, OBJPROP_COLOR, tradedColor); // Change color to gray/traded color
       ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID); // Make traded OB solid?
       ObjectSetInteger(0, name, OBJPROP_FILL, true);         // Fill traded OBs?
       ObjectSetString(0, name, OBJPROP_TOOLTIP, (orderBlocks[index].isBullish ? "TRADED Bullish OB" : "TRADED Bearish OB") + "\nStart Bar: " + IntegerToString(orderBlocks[index].barIndex));
       ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Print("EA Deinitializing. Reason code: ", reason);
   // Release indicator handles
   if(atrHandle != INVALID_HANDLE) {
      IndicatorRelease(atrHandle);
      atrHandle = INVALID_HANDLE;
      Print("ATR Handle Released.");
   }

   if(maHandle != INVALID_HANDLE) {
      IndicatorRelease(maHandle);
      maHandle = INVALID_HANDLE;
      Print("MA Handle Released.");
   }

   // Clean up chart objects (optional - uncomment if desired)
   /*
   int removedCount = 0;
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--) {
      string objName = ObjectName(0, i);
      if (StringFind(objName, "OB_SMC_") == 0) { // Check if name starts with our prefix
          if (ObjectDelete(0, objName)) {
              removedCount++;
          }
      }
   }
   Print("Removed ", removedCount, " OB chart objects.");
   ChartRedraw();
   */

   Print("EA Deinitialization Complete.");
}
//+------------------------------------------------------------------+