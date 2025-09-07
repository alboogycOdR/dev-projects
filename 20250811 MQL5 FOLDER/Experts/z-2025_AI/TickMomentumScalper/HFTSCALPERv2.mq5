//+------------------------------------------------------------------+
//|                                        TickMomentumScalperEA.mq5 |
//|                        Copyright 2023, Your Name/Company         |
//|                                              https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name/Company"
#property link      "https://www.example.com"
#property version   "1.10" // Incremented version
#property description "High-Frequency Tick Momentum Scalper for XAUUSD"
#property description "Includes Market Open check and enhanced Risk Management."
#property description "Uses Martingale Grid or Fixed Lot. NO STOP LOSS."
#property description "EXTREMELY HIGH RISK STRATEGY."

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh> // Added for Account checks

//--- EA Inputs ---
// ... (Keep all previous inputs: Trade Logic, Risk Management, Filters, Timing, EA ID) ...
// --- Add New Risk Management Inputs ---
input group          "Enhanced Risk Management"
input double         MaxAccountDrawdownPercent = 30.0;    // Max % drawdown from Peak Equity before stopping (0 = disabled)
input bool           StopTradingAfterAccountSL = true;    // Stop all EA activity after Account SL is hit?
input double         MaxAllowedLotSize         = 5.0;     // Absolute maximum lot size allowed (0 = disabled)
input double         MaxBasketDrawdownUSD      = 50.0;    // Max floating loss in currency for Buy or Sell basket before closing it (0 = disabled)
input bool           CloseBasketOnMaxDD        = true;    // Enable closing basket on Max Drawdown?
input double         MinMarginLevelPercent     = 150.0;   // Minimum margin level % required to open NEW trades (0 = disabled)
input bool           PauseAfterLoss            = true;    // Pause new entries after AccountSL or BasketMaxDD is hit?
input int            PauseDurationMinutes      = 60;      // How long to pause in minutes

// --- Add New Profitability/Efficiency Inputs ---
input group          "Profitability & Efficiency"
input bool           UseDynamicGridStep        = false;   // Use ATR for grid step?
input int            AtrPeriodGrid             = 14;      // ATR Period for dynamic grid step (e.g., on M1/M5)
input double         AtrMultiplierGrid         = 0.5;     // ATR Multiplier for dynamic grid step
input ENUM_TIMEFRAMES AtrTimeframeGrid          = PERIOD_M5; // Timeframe for ATR Grid Calc
input bool           UseDynamicBasketTP        = false;   // Use ATR or Lot Size for basket TP?
input int            AtrPeriodTP               = 14;      // ATR Period for dynamic TP (e.g., on M1/M5)
input double         AtrMultiplierTP           = 0.3;     // ATR Multiplier for dynamic TP
input ENUM_TIMEFRAMES AtrTimeframeTP            = PERIOD_M5; // Timeframe for ATR TP Calc
// --- OR ---
input double         BasketTPPerLot            = 0.0;     // Alternative Dynamic TP: Target USD per total Lot size in basket (0 = disabled, overrides ATR TP if > 0)
// --- AND ---
input int            MinSecondsBetweenEntries  = 3;       // Minimum seconds between INITIAL entries (0=disabled)

//--- Global Variables ---
CTrade         trade;
CSymbolInfo    symbolInfo;
CPositionInfo  positionInfo;
CAccountInfo   accountInfo; // Added for Account checks

// Tick storage
double         tickPrices[];
int            tickIndex = 0;
int            ticksStored = 0;

// Position tracking
int            buyPositionsCount = 0;
int            sellPositionsCount = 0;
double         highestBuyPrice = 0.0;
double         lowestSellPrice = 0.0;
double         totalBuyProfit = 0.0;
double         totalSellProfit = 0.0;
double         nextBuyLot = 0.0;
double         nextSellLot = 0.0;
double         totalBuyLots = 0.0; // For dynamic TP per lot
double         totalSellLots = 0.0;// For dynamic TP per lot

// Grid price tracking
double         lastBuyGridPrice = 0.0;
double         lastSellGridPrice = 0.0;

// Risk Management Globals
double         startBalance = 0;
double         peakEquity = 0;
bool           accountStopped = false;
bool           isPaused = false;
datetime       pauseEndTime = 0;

// Timing Globals
datetime       lastInitialBuyTime = 0;
datetime       lastInitialSellTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize objects
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   if(!symbolInfo.Name(_Symbol)) return(INIT_FAILED);
   if(!accountInfo.Select()) return(INIT_FAILED); // Ensure account is selected

   // Initialize PositionInfo (doesn't matter if positions exist yet)
   positionInfo.SelectByMagic(_Symbol, MagicNumber);

   // Initialize Tick Array
   if(TickCheckPeriod <= 0) return(INIT_FAILED);
   ArrayResize(tickPrices, TickCheckPeriod + 1);
   ArrayInitialize(tickPrices, 0.0);
   tickIndex = 0;
   ticksStored = 0;

   // Initialize Risk Management
   startBalance = accountInfo.Balance();
   peakEquity = MathMax(accountInfo.Equity(), startBalance); // Start with current equity or balance
   accountStopped = false;
   isPaused = false;
   pauseEndTime = 0;

   // Validate Inputs
   if(MaxTrades <= 0) return(INIT_FAILED);
   if(UseMartingale && MartingaleMultiplier <= 1.0) return(INIT_FAILED);
   if(MaxAllowedLotSize > 0 && InitialLotSize > MaxAllowedLotSize)
     {
      Print("Error: InitialLotSize cannot be greater than MaxAllowedLotSize. Init failed.");
      return(INIT_FAILED);
     }

   Print("TickMomentumScalperEA Initialized Successfully (v", DoubleToString(_Digits), ").");
   Print("Symbol: ", _Symbol);
   Print("Martingale: ", UseMartingale, ", Multiplier: ", MartingaleMultiplier);
   Print("Max Trades: ", MaxTrades);
   Print("Account SL %: ", MaxAccountDrawdownPercent > 0 ? DoubleToString(MaxAccountDrawdownPercent, 1) : "Disabled");
   Print("Basket Max DD $: ", MaxBasketDrawdownUSD > 0 ? DoubleToString(MaxBasketDrawdownUSD, 2) : "Disabled");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("TickMomentumScalperEA Deinitialized. Reason: ", reason);
   ArrayFree(tickPrices);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check if EA has been stopped by Account SL
   if(accountStopped) return;

   //--- Update Account Info and Peak Equity
   if(!accountInfo.Refresh()) return; // Refresh account data
   peakEquity = MathMax(peakEquity, accountInfo.Equity()); // Update peak equity

   //--- Check Account Stop Loss
   if(CheckAccountStopLoss()) return; // Exits if SL is hit and stops EA

   //--- Check if Paused After Loss
   if(isPaused)
     {
      if(TimeCurrent() >= pauseEndTime)
        {
         isPaused = false; // Resume trading
         Print("Trading Resumed after pause period.");
        }
      else
        {
         return; // Still paused
        }
     }

   //--- Refresh symbol data
   if(!symbolInfo.RefreshRates()) return;

   //--- Check Time Filter
   if(UseTimeFilter && !CheckTimeFilter()) return;

   //--- Check if Market is Open for the Symbol --- << NEW CHECK >>
   if(!IsMarketOpenForSymbol())
     {
      // Optional: Print message occasionally
      // static datetime last_market_closed_print = 0;
      // if (TimeCurrent() > last_market_closed_print + 300) { // Print every 5 mins if closed
      //     Print(_Symbol, " market session is currently closed.");
      //     last_market_closed_print = TimeCurrent();
      // }
      return; // Exit OnTick if market is closed
     }

   //--- Check Spread Filter
   if(!CheckSpreadFilter()) return;

   //--- Check Margin Level Filter (before trying to open trades)
   if(!CheckMarginLevelFilter()) return; // Don't proceed if margin is too low for NEW trades

   //--- Store tick price
   double currentMidPrice = (symbolInfo.Ask() + symbolInfo.Bid()) / 2.0;
   StoreTickPrice(currentMidPrice);
   if(ticksStored <= TickCheckPeriod) return; // Need enough history

   //--- Analyze positions & Check for Basket Closures (Profit Target or Max DD)
   int totalOpenPositions = AnalyzeOpenPositions(); // Updates global position counts, profits, lots etc.
   CheckCloseBaskets();                             // Checks both profit and max DD targets

   //--- Logic for Opening New Trades (Initial or Grid)
   if(totalOpenPositions < MaxTrades)
     {
      // Calculate momentum
      double previousPrice = tickPrices[(tickIndex - TickCheckPeriod + ArraySize(tickPrices)) % ArraySize(tickPrices)];
      double priceMove = currentMidPrice - previousPrice;
      double priceMovePoints = priceMove / symbolInfo.Point();

      // Calculate dynamic grid step if enabled
      int currentGridStepPoints = GridStepPoints;
      if(UseDynamicGridStep)
        {
         double atrGrid = iATR(_Symbol, AtrTimeframeGrid, AtrPeriodGrid, 0);
         currentGridStepPoints = (int)MathMax(GridStepPoints, int(atrGrid * AtrMultiplierGrid / symbolInfo.Point()));
        }

      // --- Initial Entry Logic ---
      if(totalOpenPositions == 0)
        {
         bool canEnterBuy = (MinSecondsBetweenEntries <= 0 || TimeCurrent() >= lastInitialBuyTime + MinSecondsBetweenEntries);
         bool canEnterSell = (MinSecondsBetweenEntries <= 0 || TimeCurrent() >= lastInitialSellTime + MinSecondsBetweenEntries);

         if(priceMovePoints >= MinMovePoints && canEnterBuy)
           {
            if(OpenBuyPosition(InitialLotSize)) lastInitialBuyTime = TimeCurrent();
           }
         else if(priceMovePoints <= -MinMovePoints && canEnterSell)
           {
            if(OpenSellPosition(InitialLotSize)) lastInitialSellTime = TimeCurrent();
           }
        }
      // --- Grid Entry Logic ---
      else if(totalOpenPositions > 0) // Grid only if positions exist
        {
         double currentBid = symbolInfo.Bid();
         double currentAsk = symbolInfo.Ask();

         // Buy Grid
         if(UseMartingale || !UseMartingale) // Condition applies to both martingale and fixed lot grid addition
           {
            if(buyPositionsCount > 0 && currentBid < highestBuyPrice - (currentGridStepPoints * symbolInfo.Point()))
              {
               if(NormalizeDouble(currentBid, symbolInfo.Digits()) != NormalizeDouble(lastBuyGridPrice, symbolInfo.Digits()))
                 {
                  double lotToUse = UseMartingale ? nextBuyLot : InitialLotSize;
                  if(OpenBuyPosition(lotToUse))
                    {
                     lastBuyGridPrice = currentBid;
                    }
                 }
              }
           }

         // Sell Grid
         if(UseMartingale || !UseMartingale)
           {
            if(sellPositionsCount > 0 && currentAsk > lowestSellPrice + (currentGridStepPoints * symbolInfo.Point()))
              {
               if(NormalizeDouble(currentAsk, symbolInfo.Digits()) != NormalizeDouble(lastSellGridPrice, symbolInfo.Digits()))
                 {
                  double lotToUse = UseMartingale ? nextSellLot : InitialLotSize;
                  if(OpenSellPosition(lotToUse))
                    {
                     lastSellGridPrice = currentAsk;
                    }
                 }
              }
           }
        } // End Grid Entry Logic
     } // End if(totalOpenPositions < MaxTrades)
}

//+------------------------------------------------------------------+
//| Check if Market Session is Open for the Symbol                   |
//+------------------------------------------------------------------+
bool IsMarketOpenForSymbol()
{
   MqlDateTime current_time_struct;
   datetime current_server_time = TimeCurrent(); // Get current server time once
   TimeToStruct(current_server_time, current_time_struct);

   // Get session times for the current day of the week
   datetime session_start_dt = 0;
   datetime session_end_dt = 0;

   // Try to get the first trading session (index 0)
   if(!SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)current_time_struct.day_of_week, 0, session_start_dt, session_end_dt))
     {
      // Could not get session info, assume closed for safety or print warning
      // Print("Warning: Could not retrieve trading session info for ", _Symbol, " on day ", current_time_struct.day_of_week);
      return false;
     }

   // Check if the current server time is within the retrieved session
   if(current_server_time >= session_start_dt && current_server_time < session_end_dt)
     {
      return true; // Market is open
     }

   // Optional: Check previous day if near midnight, in case session crosses over
   // MQL5 datetime handles this implicitly, but this is a fallback concept if needed
   // (More complex logic required if SymbolInfoSessionTrade doesn't handle cross-day sessions well)

   return false; // Market is closed
}

//+------------------------------------------------------------------+
//| Check Account Stop Loss                                          |
//+------------------------------------------------------------------+
bool CheckAccountStopLoss()
{
   if(MaxAccountDrawdownPercent <= 0) return false; // Disabled

   double currentEquity = accountInfo.Equity();
   double drawdownThreshold = peakEquity * (1.0 - MaxAccountDrawdownPercent / 100.0);

   if(currentEquity <= drawdownThreshold)
     {
      Print("ACCOUNT STOP LOSS HIT!");
      Print("Peak Equity: ", DoubleToString(peakEquity, 2));
      Print("Current Equity: ", DoubleToString(currentEquity, 2));
      Print("Drawdown Threshold: ", DoubleToString(drawdownThreshold, 2));
      Print("Closing all positions and stopping EA activity.");

      CloseAllBuys();
      CloseAllSells();

      if(StopTradingAfterAccountSL)
        {
         accountStopped = true; // Set flag to stop OnTick
         ExpertRemove();        // Optionally remove the EA from the chart
        }
      else if(PauseAfterLoss) // If not stopping permanently, check if pausing
        {
         isPaused = true;
         pauseEndTime = TimeCurrent() + PauseDurationMinutes * 60;
         Print("EA paused for ", PauseDurationMinutes, " minutes due to Account SL hit.");
        }
      return true; // Indicate SL was hit
     }
   return false;
}
//+------------------------------------------------------------------+
//| Check Margin Level Filter                                        |
//+------------------------------------------------------------------+
bool CheckMarginLevelFilter()
{
   if(MinMarginLevelPercent <= 0) return true; // Disabled

   if(accountInfo.MarginLevel() < MinMarginLevelPercent)
     {
      // Optional Print
      // static datetime last_margin_print = 0;
      // if(TimeCurrent() > last_margin_print + 60) {
      //    Print("Margin Level ", DoubleToString(accountInfo.MarginLevel(), 1), "% is below threshold ", MinMarginLevelPercent, "%. No new trades.");
      //    last_margin_print = TimeCurrent();
      // }
      return false; // Margin too low
     }
   return true;
}

// ... (Keep StoreTickPrice, CheckTimeFilter, CheckSpreadFilter functions as before) ...

//+------------------------------------------------------------------+
//| Analyze Open Positions (Updated for Total Lots)                 |
//+------------------------------------------------------------------+
int AnalyzeOpenPositions()
{
   buyPositionsCount = 0;
   sellPositionsCount = 0;
   totalBuyProfit = 0.0;
   totalSellProfit = 0.0;
   totalBuyLots = 0.0; // Reset total lots
   totalSellLots = 0.0;// Reset total lots
   highestBuyPrice = 0.0;
   lowestSellPrice = 999999.0;
   double lastBuyLotSize = 0.0;
   double lastSellLotSize = 0.0;
   datetime lastBuyTime = 0;
   datetime lastSellTime = 0;

   int totalPositions = (int)PositionsTotal();
   int eaPositions = 0;

   for(int i = totalPositions - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
           {
            eaPositions++;
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentLot = PositionGetDouble(POSITION_VOLUME);
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

            if(type == POSITION_TYPE_BUY)
              {
               buyPositionsCount++;
               totalBuyProfit += profit;
               totalBuyLots += currentLot; // Accumulate lots
               if(openPrice > highestBuyPrice) highestBuyPrice = openPrice;
               if(openTime > lastBuyTime) { lastBuyTime = openTime; lastBuyLotSize = currentLot; }
              }
            else if(type == POSITION_TYPE_SELL)
              {
               sellPositionsCount++;
               totalSellProfit += profit;
               totalSellLots += currentLot; // Accumulate lots
               if(openPrice < lowestSellPrice) lowestSellPrice = openPrice;
               if(openTime > lastSellTime) { lastSellTime = openTime; lastSellLotSize = currentLot; }
              }
           }
        }
      else { Print("Error selecting position by ticket ", ticket, ", Error code: ", GetLastError()); }
     }

   // Calculate next Martingale lot sizes (respecting MaxAllowedLotSize)
   if(UseMartingale) {
        nextBuyLot = NormalizeLotWithCap(lastBuyLotSize > 0 ? lastBuyLotSize * MartingaleMultiplier : InitialLotSize);
        nextSellLot = NormalizeLotWithCap(lastSellLotSize > 0 ? lastSellLotSize * MartingaleMultiplier : InitialLotSize);
    } else {
        nextBuyLot = NormalizeLotWithCap(InitialLotSize);
        nextSellLot = NormalizeLotWithCap(InitialLotSize);
    }

   if(buyPositionsCount == 0) lastBuyGridPrice = 0.0;
   if(sellPositionsCount == 0) lastSellGridPrice = 0.0;

   return eaPositions;
}
//+------------------------------------------------------------------+
//| Check and Close Baskets (Profit Target or Max DD)                |
//+------------------------------------------------------------------+
void CheckCloseBaskets()
{
   bool closedSomething = false;

   // --- Check Max Basket Drawdown FIRST ---
   if(CloseBasketOnMaxDD && MaxBasketDrawdownUSD > 0)
     {
      if(buyPositionsCount > 0 && totalBuyProfit < -MaxBasketDrawdownUSD)
        {
         Print("Max Basket Drawdown HIT for BUYS! Profit: ", DoubleToString(totalBuyProfit, 2), ", Threshold: -", DoubleToString(MaxBasketDrawdownUSD, 2), ". Closing Buy Basket.");
         CloseAllBuys();
         closedSomething = true;
         if(PauseAfterLoss) // Check if pausing
           {
            isPaused = true;
            pauseEndTime = TimeCurrent() + PauseDurationMinutes * 60;
            Print("EA paused for ", PauseDurationMinutes, " minutes due to Buy Basket Max DD hit.");
           }
        }
      if(sellPositionsCount > 0 && totalSellProfit < -MaxBasketDrawdownUSD)
        {
         Print("Max Basket Drawdown HIT for SELLS! Profit: ", DoubleToString(totalSellProfit, 2), ", Threshold: -", DoubleToString(MaxBasketDrawdownUSD, 2), ". Closing Sell Basket.");
         CloseAllSells();
         closedSomething = true;
          if(PauseAfterLoss) // Check if pausing
           {
            isPaused = true;
            pauseEndTime = TimeCurrent() + PauseDurationMinutes * 60;
            Print("EA paused for ", PauseDurationMinutes, " minutes due to Sell Basket Max DD hit.");
           }
        }
      // If we closed due to DD, don't immediately check for profit target on remaining opposite positions in the same tick
      if(closedSomething) return;
     }

   // --- Check Basket Profit Target ---
   double targetBuyProfit = BasketProfitTarget_USD;
   double targetSellProfit = BasketProfitTarget_USD;

   // Calculate Dynamic TP if enabled
   if(BasketTPPerLot > 0) // Per Lot takes precedence
   {
       targetBuyProfit = MathMax(BasketProfitTarget_USD, totalBuyLots * BasketTPPerLot);
       targetSellProfit = MathMax(BasketProfitTarget_USD, totalSellLots * BasketTPPerLot);
   }
   else if (UseDynamicBasketTP && AtrMultiplierTP > 0) // Then check ATR
   {
       double atrTP = iATR(_Symbol, AtrTimeframeTP, AtrPeriodTP, 0);
       // Assuming TP target scales with volatility in currency terms
       double dynamicTarget = atrTP * AtrMultiplierTP * symbolInfo.TickValue() / symbolInfo.TickSize() * symbolInfo.Point() * 10; // Approximation - needs check
       dynamicTarget = MathMax(BasketProfitTarget_USD, dynamicTarget); // Ensure minimum
       targetBuyProfit = dynamicTarget;
       targetSellProfit = dynamicTarget;
   }


   // Close Buys on Profit Target
   if(buyPositionsCount > 0 && totalBuyProfit >= targetBuyProfit)
     {
      Print("Closing Buy Basket. Profit: ", DoubleToString(totalBuyProfit, 2), " >= Target: ", DoubleToString(targetBuyProfit, 2));
      CloseAllBuys();
     }

   // Close Sells on Profit Target
   if(sellPositionsCount > 0 && totalSellProfit >= targetSellProfit)
     {
      Print("Closing Sell Basket. Profit: ", DoubleToString(totalSellProfit, 2), " >= Target: ", DoubleToString(targetSellProfit, 2));
      CloseAllSells();
     }
}

// ... (Keep OpenBuyPosition, OpenSellPosition, CloseAllBuys, CloseAllSells functions - they are mostly okay) ...
// ... (You might want to add more robust error handling/retry logic within the close functions if needed) ...


//+------------------------------------------------------------------+
//| Normalize Lot Size with Max Cap                                 |
//+------------------------------------------------------------------+
double NormalizeLotWithCap(double lot)
{
   double min_lot = symbolInfo.LotsMin();
   double max_lot_symbol = symbolInfo.LotsMax(); // Max allowed by symbol/broker
   double lot_step = symbolInfo.LotsStep();

   // Apply user-defined MaxAllowedLotSize if enabled
   double effective_max_lot = max_lot_symbol;
   if(MaxAllowedLotSize > 0)
     {
      effective_max_lot = MathMin(max_lot_symbol > 0 ? max_lot_symbol : MaxAllowedLotSize + lot_step, MaxAllowedLotSize); // Take the smaller of broker max or user max
     }


   // Ensure positive lot size
   if(lot < min_lot)
      lot = min_lot;

   // Adjust to lot step
   lot = MathRound(lot / lot_step) * lot_step;

   // Ensure within effective max lot limits
   if(effective_max_lot > 0 && lot > effective_max_lot)
      lot = effective_max_lot;

   // Final check against min_lot after rounding/capping
   if(lot < min_lot)
      lot = min_lot;


   return NormalizeDouble(lot, 2); // Normalize to standard 2 decimal places for lots
}

//+------------------------------------------------------------------+
//| [Helper] Print Position Info (for debugging)                     |
//+------------------------------------------------------------------+
/* // Uncomment to use for debugging
void PrintPositionDetails(ulong ticket)
{
   if(PositionSelectByTicket(ticket))
     {
      PrintFormat("Ticket: %d, Symbol: %s, Magic: %d, Type: %s, Lots: %.2f, Price: %s, Profit: %.2f",
                  ticket,
                  PositionGetString(POSITION_SYMBOL),
                  PositionGetInteger(POSITION_MAGIC),
                  (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL",
                  PositionGetDouble(POSITION_VOLUME),
                  DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),_Digits),
                  PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP)
                 );
     }
}
*/
//+------------------------------------------------------------------+