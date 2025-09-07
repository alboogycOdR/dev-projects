//+------------------------------------------------------------------+
//|                                        TickMomentumScalperEA.mq5 |
//|                        Copyright 2023, Your Name/Company         |
//|                                              https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name/Company"
#property link      "https://www.example.com"
#property version   "1.00"
#property description "High-Frequency Tick Momentum Scalper for XAUUSD"
#property description "Uses Martingale Grid or Fixed Lot. NO STOP LOSS."
#property description "EXTREMELY HIGH RISK STRATEGY."

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>

//--- EA Inputs
// Trade Logic
input group             "Trade Logic Settings"
input int               MinMovePoints        = 10;       // Minimum points price must move for initial entry
input int               TickCheckPeriod      = 2;        // Number of ticks to check for the move (e.g., 2 = compare current vs 2 ticks ago)
input double            BasketProfitTarget_USD = 1.50;    // Target profit in account currency to close a basket (all Buys or all Sells)

// Risk Management
input group             "Risk Management Settings"
input bool              UseMartingale        = true;     // Use Martingale grid? (false = Fixed Lot)
input double            InitialLotSize       = 0.01;     // Initial Lot Size (or Fixed Lot Size if UseMartingale=false)
input double            MartingaleMultiplier = 1.6;      // Lot multiplier for grid steps (if UseMartingale=true)
input int               GridStepPoints       = 50;       // Points in drawdown before adding next grid trade
input int               MaxTrades            = 10;       // Maximum total open trades allowed

// Filters
input group             "Filters & Timing"
input int               MaxAllowedSpread     = 30;       // Maximum allowed spread in points (0 = disabled)
input ENUM_DAY_OF_WEEK  StartDay             = MONDAY;   // --- Time Filter ---
input int               StartHour            = 0;        // Start Hour (0-23)
input int               StartMinute          = 0;        // Start Minute (0-59)
input ENUM_DAY_OF_WEEK  EndDay               = FRIDAY;   // End Day
input int               EndHour              = 23;       // End Hour (0-23)
input int               EndMinute            = 59;       // End Minute (0-59)
input bool              UseTimeFilter        = true;     // Enable Time Filter?

// EA Identification & Execution
input group             "EA Identification & Execution"
input ulong             MagicNumber          = 123456;   // EA Magic Number
input string            EaComment            = "TickScalper"; // EA Comment
input uint              Slippage             = 3;        // Allowed slippage in points

//--- Global Variables
CTrade         trade;
CSymbolInfo    symbolInfo;
CPositionInfo  positionInfo;

// Tick storage
double         tickPrices[];       // Array to store recent tick prices
int            tickIndex = 0;      // Current index for tickPrices array
int            ticksStored = 0;    // Counter for how many ticks we've stored initially

// Position tracking (updated in AnalyzeOpenPositions)
int            buyPositionsCount = 0;
int            sellPositionsCount = 0;
double         highestBuyPrice = 0.0;
double         lowestSellPrice = 0.0;
double         totalBuyProfit = 0.0;
double         totalSellProfit = 0.0;
double         nextBuyLot = 0.0;
double         nextSellLot = 0.0;

// Grid price tracking
double         lastBuyGridPrice = 0.0; // Price level where the last BUY grid order was added
double         lastSellGridPrice = 0.0;// Price level where the last SELL grid order was added

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize objects
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   trade.SetTypeFillingBySymbol(_Symbol); // Important for execution type

   if(!symbolInfo.Name(_Symbol))
     {
      Print("Error setting symbol for CSymbolInfo");
      return(INIT_FAILED);
     }

   if(!positionInfo.SelectByMagic(_Symbol, MagicNumber))
     {
      // Not necessarily an error if there are no open positions yet
      Print("No initial positions found for magic number ", MagicNumber);
     }

   //--- Initialize Tick Array
   if(TickCheckPeriod <= 0)
     {
      Print("Error: TickCheckPeriod must be greater than 0. Initialization failed.");
      return(INIT_FAILED);
     }
   ArrayResize(tickPrices, TickCheckPeriod + 1); // Store current + previous ticks
   ArrayInitialize(tickPrices, 0.0);
   tickIndex = 0;
   ticksStored = 0;

   //--- Validate Inputs
   if(MaxTrades <= 0)
     {
      Print("Error: MaxTrades must be greater than 0. Initialization failed.");
      return(INIT_FAILED);
     }
   if(UseMartingale && MartingaleMultiplier <= 1.0)
     {
      Print("Error: MartingaleMultiplier must be > 1.0 when UseMartingale is true. Initialization failed.");
      return(INIT_FAILED);
     }

   Print("TickMomentumScalperEA Initialized Successfully.");
   Print("Symbol: ", _Symbol);
   Print("Tick Check Period: ", TickCheckPeriod);
   Print("Martingale Enabled: ", UseMartingale);
   Print("Max Trades: ", MaxTrades);
   Print("Basket Profit Target (USD): ", DoubleToString(BasketProfitTarget_USD, 2));

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
   //--- Refresh symbol data
   if(!symbolInfo.RefreshRates())
     {
      Print("Error refreshing rates");
      return;
     }

   //--- Check Time Filter
   if(UseTimeFilter && !CheckTimeFilter())
      return;

   //--- Check Spread Filter
   if(!CheckSpreadFilter())
      return;

   //--- Store current tick price (use midpoint for general momentum)
   double currentMidPrice = (symbolInfo.Ask() + symbolInfo.Bid()) / 2.0;
   StoreTickPrice(currentMidPrice);

   //--- Need enough ticks before starting
   if(ticksStored <= TickCheckPeriod)
      return;

   //--- Analyze current positions and check for basket closure first
   int totalOpenPositions = AnalyzeOpenPositions();
   CheckCloseBaskets(); // Uses globally updated totalBuyProfit, totalSellProfit

   //--- Check for new Entries or Grid Additions if MaxTrades not reached
   if(totalOpenPositions < MaxTrades)
     {
      //--- Calculate momentum
      double previousPrice = tickPrices[(tickIndex - TickCheckPeriod + ArraySize(tickPrices)) % ArraySize(tickPrices)];
      double priceMove = currentMidPrice - previousPrice;
      double priceMovePoints = priceMove / symbolInfo.Point();

      //--- Entry Logic
      if(totalOpenPositions == 0) // Only initial entry if no positions exist
        {
         if(priceMovePoints >= MinMovePoints)
           {
            OpenBuyPosition(InitialLotSize);
           }
         else if(priceMovePoints <= -MinMovePoints)
           {
            OpenSellPosition(InitialLotSize);
           }
        }
      //--- Grid Logic (only if Martingale enabled and initial positions exist)
      else if(UseMartingale)
        {
         // Check for adding to Buy grid
         if(buyPositionsCount > 0 && symbolInfo.Bid() < highestBuyPrice - (GridStepPoints * symbolInfo.Point()))
           {
            // Avoid adding at the exact same price repeatedly if market stalls
            if(NormalizeDouble(symbolInfo.Bid(), symbolInfo.Digits()) != NormalizeDouble(lastBuyGridPrice, symbolInfo.Digits()))
              {
               if(OpenBuyPosition(nextBuyLot)) // Use calculated next lot
                 {
                  lastBuyGridPrice = symbolInfo.Bid(); // Update last grid price
                 }
              }
           }
         // Check for adding to Sell grid
         else if(sellPositionsCount > 0 && symbolInfo.Ask() > lowestSellPrice + (GridStepPoints * symbolInfo.Point()))
           {
            // Avoid adding at the exact same price repeatedly if market stalls
             if(NormalizeDouble(symbolInfo.Ask(), symbolInfo.Digits()) != NormalizeDouble(lastSellGridPrice, symbolInfo.Digits()))
              {
               if(OpenSellPosition(nextSellLot)) // Use calculated next lot
                 {
                  lastSellGridPrice = symbolInfo.Ask(); // Update last grid price
                 }
              }
           }
        }
      //--- Fixed Lot Grid Logic (if Martingale disabled but positions exist)
       else if (!UseMartingale && totalOpenPositions > 0)
        {
             // Check for adding to Buy grid (fixed lot)
             if(buyPositionsCount > 0 && symbolInfo.Bid() < highestBuyPrice - (GridStepPoints * symbolInfo.Point()))
             {
                  if(NormalizeDouble(symbolInfo.Bid(), symbolInfo.Digits()) != NormalizeDouble(lastBuyGridPrice, symbolInfo.Digits()))
                  {
                       if(OpenBuyPosition(InitialLotSize)) // Use fixed initial lot
                       {
                            lastBuyGridPrice = symbolInfo.Bid();
                       }
                  }
             }
             // Check for adding to Sell grid (fixed lot)
             else if(sellPositionsCount > 0 && symbolInfo.Ask() > lowestSellPrice + (GridStepPoints * symbolInfo.Point()))
             {
                  if(NormalizeDouble(symbolInfo.Ask(), symbolInfo.Digits()) != NormalizeDouble(lastSellGridPrice, symbolInfo.Digits()))
                  {
                       if(OpenSellPosition(InitialLotSize)) // Use fixed initial lot
                       {
                            lastSellGridPrice = symbolInfo.Ask();
                       }
                  }
             }
        }

     } // End if(totalOpenPositions < MaxTrades)
}
//+------------------------------------------------------------------+
//| Store Tick Price                                                 |
//+------------------------------------------------------------------+
void StoreTickPrice(double price)
{
   tickPrices[tickIndex] = price;
   tickIndex = (tickIndex + 1) % ArraySize(tickPrices);
   if(ticksStored <= TickCheckPeriod)
     {
      ticksStored++;
     }
}
//+------------------------------------------------------------------+
//| Check Time Filter                                                |
//+------------------------------------------------------------------+
bool CheckTimeFilter()
{
   MqlDateTime current_time_struct;
   TimeCurrent(current_time_struct);

   // Convert start/end times to minutes since Sunday 00:00 for easy comparison
   int start_total_minutes = (int)StartDay * 24 * 60 + StartHour * 60 + StartMinute;
   int end_total_minutes = (int)EndDay * 24 * 60 + EndHour * 60 + EndMinute;
   int current_total_minutes = current_time_struct.day_of_week * 24 * 60 + current_time_struct.hour * 60 + current_time_struct.min;

   // Handle week-wrap scenario (e.g., Friday end to Monday start)
   if(start_total_minutes <= end_total_minutes)
     {
      // Normal case: Start and end within the same logical week span
      if(current_total_minutes >= start_total_minutes && current_total_minutes <= end_total_minutes)
         return true;
     }
   else
     {
      // Wrap-around case: End time is earlier in the week than start time
      if(current_total_minutes >= start_total_minutes || current_total_minutes <= end_total_minutes)
         return true;
     }

   return false; // Outside trading time
}
//+------------------------------------------------------------------+
//| Check Spread Filter                                              |
//+------------------------------------------------------------------+
bool CheckSpreadFilter()
{
   if(MaxAllowedSpread <= 0)
      return true; // Filter disabled

   long currentSpread = symbolInfo.Spread(); // Spread in points

   if(currentSpread > MaxAllowedSpread)
     {
      // Optional: Print message only occasionally to avoid flooding logs
      // static datetime last_print_time = 0;
      // if(TimeCurrent() > last_print_time + 60) {
      //    Print("Spread too high: ", currentSpread, " > ", MaxAllowedSpread);
      //    last_print_time = TimeCurrent();
      // }
      return false;
     }
   return true;
}
//+------------------------------------------------------------------+
//| Analyze Open Positions                                           |
//+------------------------------------------------------------------+
int AnalyzeOpenPositions()
{
   buyPositionsCount = 0;
   sellPositionsCount = 0;
   totalBuyProfit = 0.0;
   totalSellProfit = 0.0;
   highestBuyPrice = 0.0;     // Reset for recalculation
   lowestSellPrice = 999999.0;// Reset for recalculation
   double lastBuyLotSize = 0.0;
   double lastSellLotSize = 0.0;
   datetime lastBuyTime = 0;
   datetime lastSellTime = 0;

   int totalPositions = (int)PositionsTotal(); // Use MQL5 built-in function
   int eaPositions = 0;

   for(int i = totalPositions - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) // Select position to get its properties
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
               if(openPrice > highestBuyPrice)
                 {
                  highestBuyPrice = openPrice;
                 }
               // Find the lot of the most recent buy trade for martingale calculation
               if(openTime > lastBuyTime)
                 {
                  lastBuyTime = openTime;
                  lastBuyLotSize = currentLot;
                 }
              }
            else if(type == POSITION_TYPE_SELL)
              {
               sellPositionsCount++;
               totalSellProfit += profit;
               if(openPrice < lowestSellPrice)
                 {
                  lowestSellPrice = openPrice;
                 }
                // Find the lot of the most recent sell trade for martingale calculation
               if(openTime > lastSellTime)
                 {
                  lastSellTime = openTime;
                  lastSellLotSize = currentLot;
                 }
              }
           }
        }
      else
        {
         Print("Error selecting position by ticket ", ticket, ", Error code: ", GetLastError());
        }
     }

    // Calculate next Martingale lot sizes
    if(UseMartingale) {
        nextBuyLot = NormalizeLot(lastBuyLotSize > 0 ? lastBuyLotSize * MartingaleMultiplier : InitialLotSize);
        nextSellLot = NormalizeLot(lastSellLotSize > 0 ? lastSellLotSize * MartingaleMultiplier : InitialLotSize);
    } else {
        // Not strictly needed if fixed lot, but set for consistency
        nextBuyLot = NormalizeLot(InitialLotSize);
        nextSellLot = NormalizeLot(InitialLotSize);
    }

   // Reset grid price trackers if no positions of that type exist
   if(buyPositionsCount == 0) lastBuyGridPrice = 0.0;
   if(sellPositionsCount == 0) lastSellGridPrice = 0.0;


   return eaPositions;
}
//+------------------------------------------------------------------+
//| Check and Close Baskets if Profit Target Reached                 |
//+------------------------------------------------------------------+
void CheckCloseBaskets()
{
   // Close Buys
   if(buyPositionsCount > 0 && totalBuyProfit >= BasketProfitTarget_USD)
     {
      Print("Closing Buy Basket. Profit: ", DoubleToString(totalBuyProfit, 2), " >= Target: ", DoubleToString(BasketProfitTarget_USD, 2));
      CloseAllBuys();
     }

   // Close Sells
   if(sellPositionsCount > 0 && totalSellProfit >= BasketProfitTarget_USD)
     {
      Print("Closing Sell Basket. Profit: ", DoubleToString(totalSellProfit, 2), " >= Target: ", DoubleToString(BasketProfitTarget_USD, 2));
      CloseAllSells();
     }
}
//+------------------------------------------------------------------+
//| Open Buy Position                                                |
//+------------------------------------------------------------------+
bool OpenBuyPosition(double lotSize)
{
   double useLot = NormalizeLot(lotSize);
   if(useLot <= 0)
     {
      Print("Invalid lot size calculated for Buy: ", lotSize);
      return false;
     }

   // Reset grid tracker only if this is the *first* buy in a potential sequence
   if (buyPositionsCount == 0) {
       lastBuyGridPrice = 0.0;
   }

   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = useLot;
   request.type = ORDER_TYPE_BUY;
   request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // Use Ask for Buy
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.comment = EaComment;
   int fillType = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   request.type_filling = ORDER_FILLING_FOK; // Use CTrade's setting
   request.type_time = ORDER_TIME_GTC;         // Or other if needed

   if(!OrderSend(request, result))
     {
      Print("Error Opening Buy: ", GetLastError(), ", Result Retcode: ", result.retcode);
      return false;
     }

   Print("Buy Order Sent: ", useLot, " lots at ", request.price, ", Ticket: ", result.order);
   // Optional: Small delay after opening a trade if needed for broker rate limits, but avoid in scalping if possible
   // Sleep(100);
   return true;
}
//+------------------------------------------------------------------+
//| Open Sell Position                                               |
//+------------------------------------------------------------------+
bool OpenSellPosition(double lotSize)
{
    double useLot = NormalizeLot(lotSize);
   if(useLot <= 0)
     {
      Print("Invalid lot size calculated for Sell: ", lotSize);
      return false;
     }

   // Reset grid tracker only if this is the *first* sell in a potential sequence
   if (sellPositionsCount == 0) {
       lastSellGridPrice = 0.0;
   }

   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = useLot;
   request.type = ORDER_TYPE_SELL;
   request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID); // Use Bid for Sell
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.comment = EaComment;
   //request.type_filling = trade.TypeFilling();
   int fillType = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   request.type_filling =ORDER_FILLING_FOK ; // Use CTrade's setting
   request.type_time = ORDER_TIME_GTC;

   if(!OrderSend(request, result))
     {
      Print("Error Opening Sell: ", GetLastError(), ", Result Retcode: ", result.retcode);
      return false;
     }

   Print("Sell Order Sent: ", useLot, " lots at ", request.price, ", Ticket: ", result.order);
   // Optional: Small delay
   // Sleep(100);
   return true;
}
//+------------------------------------------------------------------+
//| Close All Buy Positions                                          |
//+------------------------------------------------------------------+
void CloseAllBuys()
{
   int total = (int)PositionsTotal();
   bool closed_any = false;
   for(int i = total - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
            (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           {
            if(!trade.PositionClose(ticket, Slippage))
              {
               Print("Error closing BUY ticket ", ticket, ": ", GetLastError(), ", RetCode: ", trade.ResultRetcode());
               // Consider adding a small delay and retry logic here if needed
              }
            else
              {
               //Print("Closed BUY ticket ", ticket, ". Profit: ", trade.ResultDealProfit());

               ulong deal_ticket = trade.ResultDeal();
                double deal_profit = 0.0;
                if(deal_ticket > 0)
                    deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
                Print("Closed BUY ticket ", ticket, ". Profit: ", deal_profit);

               closed_any = true;
              }
           }
        }
     }
    if (closed_any) {
         lastBuyGridPrice = 0.0; // Reset grid price after closing basket
         // Small delay might be needed for terminal to update after mass close
         Sleep(250);
    }
}
//+------------------------------------------------------------------+
//| Close All Sell Positions                                         |
//+------------------------------------------------------------------+
void CloseAllSells()
{
   int total = (int)PositionsTotal();
    bool closed_any = false;
   for(int i = total - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
            (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
           {
            if(!trade.PositionClose(ticket, Slippage))
              {
               Print("Error closing SELL ticket ", ticket, ": ", GetLastError(), ", RetCode: ", trade.ResultRetcode());
              }
             else
              {
               //Print("Closed SELL ticket ", ticket, ". Profit: ", trade.ResultDealProfit());

               ulong deal_ticket = trade.ResultDeal();
               double deal_profit = 0.0;
               if(deal_ticket > 0)
                   deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
               Print("Closed SELL ticket ", ticket, ". Profit: ", deal_profit);
                closed_any = true;
              }
           }
        }
     }
      if (closed_any) {
         lastSellGridPrice = 0.0; // Reset grid price after closing basket
         Sleep(250);
      }
}
//+------------------------------------------------------------------+
//| Normalize Lot Size according to symbol rules                     |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
   double min_lot = symbolInfo.LotsMin();
   double max_lot = symbolInfo.LotsMax();
   double lot_step = symbolInfo.LotsStep();

   // Ensure positive lot size
   if(lot < min_lot)
      lot = min_lot;

   // Adjust to lot step
   lot = MathRound(lot / lot_step) * lot_step;

   // Ensure within max lot limits
   if(max_lot > 0 && lot > max_lot) // Check if max_lot is defined
      lot = max_lot;

   // Final check against min_lot after rounding
   if(lot < min_lot)
      lot = min_lot;


   return NormalizeDouble(lot, 2); // Normalize to standard 2 decimal places for lots
}