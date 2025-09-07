//+------------------------------------------------------------------+
//|                                            MyMA_Crossover_EA.mq5 |
//|                        Copyright 2023, Your Name/Company         |
//|                                         https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Freelancer @ MQL5"
#property link      "https://www.mql5.com/en/users/nuburo"
#property version   "1.00"
#property description "Moving Average Crossover Expert Advisor"
#property strict    // Recommended for better code checking

#include <Trade\Trade.mqh>    // Include CTrade class for simplified trading
//#include <Indicators\MovingAverages.mqh> // Access to MA functions (optional but good)

//--- Enumerations for Input Clarity
enum ENUM_LOT_SIZE_MODE
  {
   LOT_SIZE_FIXED     = 0, // Fixed Lot Size
   LOT_SIZE_PERCENT   = 1  // Percentage of Balance
  };

enum ENUM_STOP_LOSS_MODE
  {
   SL_FIXED_PIPS = 0, // Fixed Pips
   SL_ATR        = 1  // ATR Based
  };

enum ENUM_TAKE_PROFIT_MODE
  {
   TP_FIXED_PIPS = 0, // Fixed Pips
   TP_ATR        = 1  // ATR Based
  };

enum ENUM_TRAILING_MODE
 {
  TRAIL_FIXED_PIPS = 0, // Fixed Pips
  TRAIL_ATR        = 1  // ATR Based
 };

//--- Input parameters (User Dashboard)
// MA Settings
input group           "Moving Average Settings"
input int             Fast_MA_Period      = 50;              // Fast MA Period
input ENUM_MA_METHOD  MA_Method_Fast      = MODE_EMA;        // Fast MA Method (MODE_SMA, MODE_EMA, MODE_SMMA, MODE_LWMA)
input int             Slow_MA_Period      = 200;             // Slow MA Period
input ENUM_MA_METHOD  MA_Method_Slow      = MODE_EMA;        // Slow MA Method
input ENUM_APPLIED_PRICE MA_Applied_Price = PRICE_CLOSE;     // Applied Price for MAs

// Confirmation Filters
input group           "Confirmation Filters"
input bool            Use_RSI_Filter      = false;           // Use RSI Filter?
input int             RSI_Period          = 14;              // RSI Period
input double          RSI_Level_Buy       = 50.0;            // RSI Level threshold for Buy
input double          RSI_Level_Sell      = 50.0;            // RSI Level threshold for Sell
input bool            Use_MACD_Filter     = false;           // Use MACD Filter?
input int             MACD_Fast_EMA       = 12;              // MACD Fast EMA Period
input int             MACD_Slow_EMA       = 26;              // MACD Slow EMA Period
input int             MACD_Signal_SMA     = 9;               // MACD Signal Line Period
input ENUM_APPLIED_PRICE MACD_Applied_Price = PRICE_CLOSE;    // Applied Price for MACD

// Multi-Timeframe (MTF) Filter
input group           "MTF Filter (Optional)"
input bool            Use_MTF_Filter      = false;           // Use MTF Filter?
input ENUM_TIMEFRAMES MTF_Timeframe       = PERIOD_H1;       // Timeframe for MTF Confirmation
// --- Use similar MA settings for MTF ---
input int             MTF_Fast_MA_Period  = 50;
input ENUM_MA_METHOD  MTF_MA_Method_Fast  = MODE_EMA;
input int             MTF_Slow_MA_Period  = 200;
input ENUM_MA_METHOD  MTF_MA_Method_Slow  = MODE_EMA;
input ENUM_APPLIED_PRICE MTF_MA_Applied_Price = PRICE_CLOSE;

input group           "Risk & Position Sizing"
input ENUM_LOT_SIZE_MODE LotSizeMode      = LOT_SIZE_FIXED;  // Lot Sizing Mode  // CORRECTED
input double          FixedLotSize        = 0.01;            // Fixed Lot Size
input double          RiskPercent         = 1.0;             // Risk % of Account Balance
input ENUM_STOP_LOSS_MODE StopLossMode    = SL_FIXED_PIPS;   // Stop Loss Mode   // CORRECTED
input int             FixedStopLossPips   = 100;             // Fixed SL in Pips
input int             ATR_Period_SL       = 14;              // ATR Period for SL
input double          ATR_Multiplier_SL   = 1.5;             // ATR Multiplier for SL
input ENUM_TAKE_PROFIT_MODE TakeProfitMode= TP_FIXED_PIPS;   // Take Profit Mode // CORRECTED
input int             FixedTakeProfitPips = 200;             // Fixed TP in Pips
input int             ATR_Period_TP       = 14;              // ATR Period for TP
input double          ATR_Multiplier_TP   = 3.0;             // ATR Multiplier for TP

// Trailing Stop
input group           "Trailing Stop Loss"
input bool            UseTrailingStop     = true;            // Use Trailing Stop?
input ENUM_TRAILING_MODE TrailingStopMode = TRAIL_FIXED_PIPS;// Trailing Stop Mode // CORRECTED
input int             TrailingStopPips    = 50;              // Trailing SL Activation/Value in Pips
input int             ATR_Period_Trail    = 14;              // ATR Period for Trailing SL
input double          ATR_Multiplier_Trail= 2.0;             // ATR Multiplier for Trailing SL
input int             TrailingStopStepPips= 10;              // Trailing Stop Step in Pips

// Risk Limits
input group           "Account Protection"
input bool            UseMaxDailyLoss     = false;           // Enable Max Daily Loss Limit?
input double          MaxDailyLossPercent = 5.0;             // Max Daily Loss Percentage
input bool            UseMaxWeeklyLoss    = false;           // Enable Max Weekly Loss Limit?
input double          MaxWeeklyLossPercent= 10.0;            // Max Weekly Loss Percentage

// Trade Management
input group           "Trade Settings"
input long            MagicNumber         = 123456;          // EA Magic Number
input int             MaxSlippage         = 3;               // Max Slippage in Points
input string          TradeComment        = "MyMA_Cross_EA"; // Trade Comment
input string          AllowedTradeHours   = "";              // Allowed hours (e.g., "08:00-16:00", empty for all)
input bool            _LogTradesToFile_     = true;            // Log trades to CSV file?

 bool            LogTradesToFile     = _LogTradesToFile_;            // Log trades to CSV file?
input string          LogFileName         = "MA_Cross_EA_Log.csv"; // Log file name

//--- Global Variables
CTrade         trade;                   // Trading class instance
int            fastMaHandle = INVALID_HANDLE; // Handle for Fast MA
int            slowMaHandle = INVALID_HANDLE; // Handle for Slow MA
int            rsiHandle = INVALID_HANDLE;    // Handle for RSI
int            macdHandle = INVALID_HANDLE;   // Handle for MACD
int            atrHandle = INVALID_HANDLE;    // Handle for ATR (used for SL/TP/Trail)
int            mtfFastMaHandle = INVALID_HANDLE; // Handle for MTF Fast MA
int            mtfSlowMaHandle = INVALID_HANDLE; // Handle for MTF Slow MA

// Risk Limit Tracking
datetime       currentDayStart = 0;
datetime       currentWeekStart = 0;
double         dailyLoss = 0.0;
double         weeklyLoss = 0.0;
bool           dailyLimitReached = false;
bool           weeklyLimitReached = false;

// Logging
int            fileHandle = INVALID_HANDLE;

// For checking new bar
datetime       lastBarTime = 0;

// MTF Data Buffers
double         mtfFastMA[];
double         mtfSlowMA[];
bool                                         RUNMODE_EXPIRY=true;    //Enable expiry
datetime                                     expiryDate = D'2025.04.23 13:59'; //change as per your requirement


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
     if(RUNMODE_EXPIRY)
     {
      Print("DEMO MODE: demo until "+(string)expiryDate);
     }
//--- Initialize Trading Class
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(MaxSlippage);
   trade.SetTypeFillingBySymbol(_Symbol); // Auto-detect fill policy

//--- Validate Inputs
   if(Fast_MA_Period >= Slow_MA_Period)
     {
      Alert("Error: Fast MA Period (", Fast_MA_Period, ") must be less than Slow MA Period (", Slow_MA_Period, ")");
      return(INIT_FAILED);
     }
   if(Use_MTF_Filter && MTF_Fast_MA_Period >= MTF_Slow_MA_Period)
     {
       Alert("Error: MTF Fast MA Period (", MTF_Fast_MA_Period, ") must be less than MTF Slow MA Period (", MTF_Slow_MA_Period, ")");
       return(INIT_FAILED);
     }
   if(LotSizeMode == LOT_SIZE_PERCENT && (RiskPercent <= 0 || RiskPercent > 100))
     {
      Alert("Error: Risk Percent must be between 0 and 100.");
      return(INIT_FAILED);
     }

//--- Initialize Indicator Handles
   // Main Chart Indicators
   fastMaHandle = iMA(_Symbol, _Period, Fast_MA_Period, 0, MA_Method_Fast, MA_Applied_Price);
   if(fastMaHandle == INVALID_HANDLE)
     {
      Alert("Error initializing Fast MA indicator - Error code:", GetLastError());
      return(INIT_FAILED);
     }

   slowMaHandle = iMA(_Symbol, _Period, Slow_MA_Period, 0, MA_Method_Slow, MA_Applied_Price);
   if(slowMaHandle == INVALID_HANDLE)
     {
      Alert("Error initializing Slow MA indicator - Error code:", GetLastError());
      return(INIT_FAILED);
     }

   // ATR (always needed if any ATR mode is selected)
   if(StopLossMode == SL_ATR || TakeProfitMode == TP_ATR || (UseTrailingStop && TrailingStopMode == TRAIL_ATR) )
   {
      int atr_period = MathMax(MathMax(ATR_Period_SL, ATR_Period_TP), (UseTrailingStop && TrailingStopMode == TRAIL_ATR) ? ATR_Period_Trail : 1);
      atrHandle = iATR(_Symbol, _Period, atr_period);
      if(atrHandle == INVALID_HANDLE)
        {
         Alert("Error initializing ATR indicator - Error code:", GetLastError());
         return(INIT_FAILED);
        }
   }


   // Optional Indicators
   if(Use_RSI_Filter)
     {
      rsiHandle = iRSI(_Symbol, _Period, RSI_Period, MA_Applied_Price); // Typically PRICE_CLOSE for RSI
      if(rsiHandle == INVALID_HANDLE)
        {
         Alert("Error initializing RSI indicator - Error code:", GetLastError());
         return(INIT_FAILED);
        }
     }

   if(Use_MACD_Filter)
     {
      macdHandle = iMACD(_Symbol, _Period, MACD_Fast_EMA, MACD_Slow_EMA, MACD_Signal_SMA, MACD_Applied_Price);
      if(macdHandle == INVALID_HANDLE)
        {
         Alert("Error initializing MACD indicator - Error code:", GetLastError());
         return(INIT_FAILED);
        }
     }

   // MTF Indicators
   if(Use_MTF_Filter)
     {
       mtfFastMaHandle = iMA(_Symbol, MTF_Timeframe, MTF_Fast_MA_Period, 0, MTF_MA_Method_Fast, MTF_MA_Applied_Price);
       if(mtfFastMaHandle == INVALID_HANDLE)
        {
         Alert("Error initializing MTF Fast MA indicator - Error code:", GetLastError());
         return(INIT_FAILED);
        }

       mtfSlowMaHandle = iMA(_Symbol, MTF_Timeframe, MTF_Slow_MA_Period, 0, MTF_MA_Method_Slow, MTF_MA_Applied_Price);
       if(mtfSlowMaHandle == INVALID_HANDLE)
        {
         Alert("Error initializing MTF Slow MA indicator - Error code:", GetLastError());
         return(INIT_FAILED);
        }
       // Allocate MTF Buffers
       ArraySetAsSeries(mtfFastMA, true);
       ArraySetAsSeries(mtfSlowMA, true);
     }

//--- Initialize Logging
   if(LogTradesToFile)
     {
      // Reset file (clear contents) during initialization
      fileHandle = FileOpen(LogFileName, FILE_WRITE | FILE_CSV | FILE_ANSI);
      if(fileHandle != INVALID_HANDLE)
        {
         // Write Header
         FileWrite(fileHandle, "Timestamp", "Action", "Type", "Symbol", "Lots", "Price", "SL", "TP", "Ticket", "Magic", "Comment", "Result Price", "Profit");
         FileClose(fileHandle); // Close after writing header
        }
      else
        {
         Alert("Error creating log file ", LogFileName, " - Error code: ", GetLastError());
         LogTradesToFile = false; // Disable logging if file can't be opened
        }
     }

//--- Initialize Risk Limit Timestamps
   ResetDailyLoss(TimeCurrent());
   ResetWeeklyLoss(TimeCurrent());

//--- Output initialization message
   Print("MyMA_Crossover_EA initialized successfully.");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(_Period));
   Print("Magic Number: ", MagicNumber);
   Print("Lot Sizing: ", EnumToString(LotSizeMode));
   if(LotSizeMode==LOT_SIZE_FIXED) Print("Fixed Lot Size: ", FixedLotSize);
   else Print("Risk Percent: ", RiskPercent, "%");

//--- Successful initialization
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Release indicator handles
   if(fastMaHandle != INVALID_HANDLE) IndicatorRelease(fastMaHandle);
   if(slowMaHandle != INVALID_HANDLE) IndicatorRelease(slowMaHandle);
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(macdHandle != INVALID_HANDLE) IndicatorRelease(macdHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(mtfFastMaHandle != INVALID_HANDLE) IndicatorRelease(mtfFastMaHandle);
   if(mtfSlowMaHandle != INVALID_HANDLE) IndicatorRelease(mtfSlowMaHandle);

//--- Close Log file if open (though it should be opened/closed per write)
// if(LogTradesToFile && fileHandle != INVALID_HANDLE) FileClose(fileHandle);


//--- Output deinitialization message
   Print("MyMA_Crossover_EA deinitialized. Reason code: ", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
  if(RUNMODE_EXPIRY)
     {
      if(TimeCurrent() > expiryDate)
        {
         Alert("Expired demo copy. To renew or purchase, please contact the author");
         Print("Expired demo copy. To renew or purchase, please contact the author");
         ExpertRemove();

        }
     }
     
//--- Check if trading is allowed at all
 
   if((bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT) == false)
     {
       // static bool broker_warning_shown = false;
       // if (!broker_warning_shown) {
       //    Print("Expert Advisor trading is disabled for this account by the broker.");
       //    broker_warning_shown = true;
       // }
       return; // Stop processing if broker disabled EA trading
     }

//--- Check if new bar has started (optional but reduces calculations)
   datetime currentTime = iTime(_Symbol, _Period, 0);
   bool isNewBar = (currentTime != lastBarTime);
   if(isNewBar) {
        lastBarTime = currentTime;
   }
   // --- Or process every tick if preferred ---
   // if (!isNewBar) return; // Uncomment to process only on new bar


//--- Check Time Filter
   if(!IsTradingHourAllowed()) return;

//--- Check Risk Limits
   if(!CheckRiskLimits()) return; // Stop trading if limits are hit

//--- Get latest prices
   MqlTick latest_tick;
   if(!SymbolInfoTick(_Symbol, latest_tick)) return; // Cannot get current prices

//--- Get Indicator Data
   double fastMA_current, fastMA_prev;
   double slowMA_current, slowMA_prev;
   double rsiValue = 0;
   double macdMain = 0, macdSignal = 0;
   double mtfFastVal = 0, mtfSlowVal = 0;

   // MA Values (indices 1 and 2 for crossover on the *previous closed* bar)
   if(!GetMAValues(fastMaHandle, 1, fastMA_current) || !GetMAValues(fastMaHandle, 2, fastMA_prev) ||
      !GetMAValues(slowMaHandle, 1, slowMA_current) || !GetMAValues(slowMaHandle, 2, slowMA_prev))
     {
       //Print("Could not get MA values."); // Too noisy for ticks
       return; // Wait for next tick if data isn't ready
     }

   // Optional Filter Values (index 1 for previous closed bar confirmation)
   if(Use_RSI_Filter && !GetRSIValue(1, rsiValue)) return;
   if(Use_MACD_Filter && !GetMACDValues(1, macdMain, macdSignal)) return;
   if(Use_MTF_Filter && !GetMTFMAValues(1, mtfFastVal, mtfSlowVal)) return;


//--- Define Crossover Conditions on previous completed bar
   bool bullishCross = (fastMA_prev <= slowMA_prev && fastMA_current > slowMA_current); // Golden Cross
   bool bearishCross = (fastMA_prev >= slowMA_prev && fastMA_current < slowMA_current); // Death Cross

//--- Define Filter Conditions (True if filter passes or is disabled)
   bool rsiBuyFilter = !Use_RSI_Filter || (rsiValue > RSI_Level_Buy);
   bool rsiSellFilter= !Use_RSI_Filter || (rsiValue < RSI_Level_Sell);
   bool macdBuyFilter = !Use_MACD_Filter || (macdMain > macdSignal); // Main Line > Signal Line
   bool macdSellFilter= !Use_MACD_Filter || (macdMain < macdSignal); // Main Line < Signal Line
   bool mtfBuyFilter  = !Use_MTF_Filter || (mtfFastVal > mtfSlowVal);
   bool mtfSellFilter = !Use_MTF_Filter || (mtfFastVal < mtfSlowVal);


//--- Combine Entry Conditions
   bool buySignal = bullishCross && rsiBuyFilter && macdBuyFilter && mtfBuyFilter;
   bool sellSignal= bearishCross && rsiSellFilter && macdSellFilter && mtfSellFilter;


//--- Entry Logic
   if(CountEaOpenPositions() == 0) // Only enter if no position is currently open by this EA
     {
      double lots = CalculateLotSize(latest_tick.ask); // Use Ask for lot size calculation, refine if needed based on SL mode

      if(buySignal)
        {
         double stopLossPrice = CalculateStopLoss(latest_tick.ask, ORDER_TYPE_BUY);
         double takeProfitPrice = CalculateTakeProfit(latest_tick.ask, ORDER_TYPE_BUY);

         // Ensure SL/TP are valid relative to current price
         if(stopLossPrice >= latest_tick.ask || stopLossPrice <= 0) {
            Print("Invalid SL calculated for BUY: ", stopLossPrice, " Ask: ", latest_tick.ask);
         } else if (takeProfitPrice <= latest_tick.ask && takeProfitPrice != 0){
            Print("Invalid TP calculated for BUY: ", takeProfitPrice, " Ask: ", latest_tick.ask);
         } else {
            bool result = trade.Buy(lots, _Symbol, latest_tick.ask, stopLossPrice, takeProfitPrice, TradeComment);
            if(result) {
                 LogTrade("OrderSend", "BUY", _Symbol, lots, trade.ResultPrice(), 
                 stopLossPrice, takeProfitPrice, trade.ResultOrder(), MagicNumber, TradeComment, 0, 0);
            } else {
                 LogTrade("OrderSend Failed", "BUY", _Symbol, lots, latest_tick.ask,
                  stopLossPrice, takeProfitPrice, 0, MagicNumber, TradeComment + " | Error: " + IntegerToString(trade.ResultRetcode()), 0, 0);
                 Print("Buy order failed: ", trade.ResultRetcodeDescription());
            }
         }

        }
      else if(sellSignal)
        {
         double stopLossPrice = CalculateStopLoss(latest_tick.bid, ORDER_TYPE_SELL);
         double takeProfitPrice = CalculateTakeProfit(latest_tick.bid, ORDER_TYPE_SELL);

          // Ensure SL/TP are valid relative to current price
         if(stopLossPrice <= latest_tick.bid && stopLossPrice != 0) {
            Print("Invalid SL calculated for SELL: ", stopLossPrice, " Bid: ", latest_tick.bid);
         } else if (takeProfitPrice >= latest_tick.bid || takeProfitPrice <= 0) {
             Print("Invalid TP calculated for SELL: ", takeProfitPrice, " Bid: ", latest_tick.bid);
         } else {
             bool result = trade.Sell(lots, _Symbol, latest_tick.bid, stopLossPrice, takeProfitPrice, TradeComment);
             if(result) {
                  LogTrade("OrderSend", "SELL", _Symbol, lots, trade.ResultPrice(),
                   stopLossPrice, takeProfitPrice, trade.ResultOrder(), MagicNumber, TradeComment, 0, 0);
             } else {
                  LogTrade("OrderSend Failed", "SELL", _Symbol, lots, latest_tick.bid, stopLossPrice, takeProfitPrice, 0, MagicNumber, TradeComment + " | Error: " + IntegerToString(trade.ResultRetcode()), 0, 0);
                  Print("Sell order failed: ", trade.ResultRetcodeDescription());
             }
         }
        }
     } // End if no open positions

//--- Trailing Stop Logic
   if(UseTrailingStop)
     {
      ManageTrailingStop(latest_tick);
     }

//--- Additonal logic (like partial closes, checking if MA cross *against* position for exit, etc.) could go here.

  } // End OnTick()

//+------------------------------------------------------------------+
//| Timer function (can be used for less frequent tasks)             |
//+------------------------------------------------------------------+
/* // Uncomment and configure in OnInit if needed
void OnTimer()
{
   // Example: Run trailing stop only on timer events
   if(UseTrailingStop)
   {
       MqlTick latest_tick;
       if(!SymbolInfoTick(_Symbol, latest_tick)) return;
       ManageTrailingStop(latest_tick);
   }
   // Example: Check risk limits periodically
   CheckRiskLimits();
}
*/

//+------------------------------------------------------------------+
//| Trade event function (useful for logging closures/modifications) |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   //--- Filter by Symbol first (usually efficient)
   if(trans.symbol != _Symbol) return;

   //--- Filter by Magic Number (if applicable)
   // Check deal magic if it's a deal transaction
   if (trans.deal > 0)
   {
       if (HistoryDealSelect(trans.deal))
       {
           if (HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != MagicNumber)
           {
               return; // Ignore deals not from this EA
           }
       }
       else
       {
          // Print("OnTradeTransaction: Failed to select deal #", trans.deal);
           return; // Could not verify deal, maybe ignore
       }
   }
   // Check order magic if it's an order transaction (and not also a deal)
   else if (trans.order > 0)
   {
       if (HistoryOrderSelect(trans.order))
       {
            if (HistoryOrderGetInteger(trans.order, ORDER_MAGIC) != MagicNumber)
            {
                 return; // Ignore orders not from this EA
            }
       }
        else
       {
          // Print("OnTradeTransaction: Failed to select order #", trans.order);
           return; // Could not verify order, maybe ignore
       }
   }
   // If it's neither a deal nor an order transaction with a valid ticket,
   // we might not be able to determine the magic number easily.
   // We proceed here, assuming subsequent logic might handle specific types.

   // Log Closed Trades from Deals
   if (trans.type == TRADE_TRANSACTION_DEAL_ADD) {
        ulong dealTicket = trans.deal;
        if (HistoryDealSelect(dealTicket)) {
             long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
             // Log only exit deals (DEAL_ENTRY_OUT or DEAL_ENTRY_INOUT)
             if (dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT) {
                  string typeStr = (HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_BUY) ? "Closed SELL" : "Closed BUY";
                  LogTrade("Trade Closed",
                           typeStr,
                           HistoryDealGetString(dealTicket, DEAL_SYMBOL),
                           HistoryDealGetDouble(dealTicket, DEAL_VOLUME),
                           HistoryDealGetDouble(dealTicket, DEAL_PRICE),
                           HistoryDealGetDouble(dealTicket, DEAL_SL), // Might be 0 if closed manually/TP
                           HistoryDealGetDouble(dealTicket, DEAL_TP), // Might be 0 if closed manually/SL
                           HistoryDealGetInteger(dealTicket, DEAL_ORDER),
                           HistoryDealGetInteger(dealTicket, DEAL_MAGIC),
                           HistoryDealGetString(dealTicket, DEAL_COMMENT),
                           HistoryDealGetDouble(dealTicket, DEAL_PRICE), // Use deal price as result price
                           HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + HistoryDealGetDouble(dealTicket, DEAL_SWAP) + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION) // Total Profit
                          );

                  // Update risk limits
                  UpdateRiskLimits(HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + HistoryDealGetDouble(dealTicket, DEAL_SWAP) + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION));

             }
        }
    }
    // Could add logging for modifications, rejected requests etc. here too
  }
//+------------------------------------------------------------------+
//| Check if trading is allowed in the current hour                  |
//+------------------------------------------------------------------+
bool IsTradingHourAllowed()
{
    if(AllowedTradeHours == "") return true; // No restriction

    MqlDateTime currentTimeStruct;
    TimeCurrent(currentTimeStruct);
    int currentHour = currentTimeStruct.hour;
    int currentMinute = currentTimeStruct.min;
    int currentTotalMinutes = currentHour * 60 + currentMinute;

    // Parse AllowedTradeHours (basic implementation assumes HH:MM-HH:MM)
    string parts[];
    if(StringSplit(AllowedTradeHours, '-', parts) == 2)
    {
        string startParts[], endParts[];
        if(StringSplit(parts[0], ':', startParts) == 2 && StringSplit(parts[1], ':', endParts) == 2)
        {
            int startHour = (int)StringToInteger(startParts[0]);
            int startMinute = (int)StringToInteger(startParts[1]);
            int endHour = (int)StringToInteger(endParts[0]);
            int endMinute = (int)StringToInteger(endParts[1]);

            int startTotalMinutes = startHour * 60 + startMinute;
            int endTotalMinutes = endHour * 60 + endMinute;

            // Handle overnight ranges (e.g., 22:00-06:00)
            if(startTotalMinutes <= endTotalMinutes)
            {
                // Normal range (e.g., 08:00-16:00)
                return (currentTotalMinutes >= startTotalMinutes && currentTotalMinutes < endTotalMinutes);
            }
            else
            {
                // Overnight range (e.g., 22:00-06:00)
                return (currentTotalMinutes >= startTotalMinutes || currentTotalMinutes < endTotalMinutes);
            }
        }
    }

    Print("Warning: Invalid format for AllowedTradeHours input '", AllowedTradeHours, "'. Trading always allowed.");
    return true; // Allow trading if format is wrong
}

//+------------------------------------------------------------------+
//| Reset Daily Loss Tracker                                          |
//+------------------------------------------------------------------+
void ResetDailyLoss(datetime time)
{
    MqlDateTime dt;
    TimeToStruct(time, dt);
    dt.hour = 0; dt.min = 0; dt.sec = 0;
    datetime dayStart = StructToTime(dt);

    if (dayStart > currentDayStart) {
        currentDayStart = dayStart;
        dailyLoss = 0.0;
        dailyLimitReached = false;
       // Print("Daily loss tracker reset for ", TimeToString(currentDayStart, TIME_DATE));
    }
}
//+------------------------------------------------------------------+
//| Reset Weekly Loss Tracker                                         |
//+------------------------------------------------------------------+
void ResetWeeklyLoss(datetime time)
{
     MqlDateTime dt;
     TimeToStruct(time, dt);
     int daysToMonday = (dt.day_of_week == 0) ? 6 : dt.day_of_week - 1; // Sunday=0, Monday=1..Saturday=6
     datetime weekStartTime = time - daysToMonday * 86400; // Subtract seconds to get to start of Monday
     TimeToStruct(weekStartTime, dt);
     dt.hour = 0; dt.min = 0; dt.sec = 0;
     datetime weekStart = StructToTime(dt);

     if(weekStart > currentWeekStart)
     {
         currentWeekStart = weekStart;
         weeklyLoss = 0.0;
         weeklyLimitReached = false;
       //  Print("Weekly loss tracker reset for week starting ", TimeToString(currentWeekStart, TIME_DATE));
     }
}
//+------------------------------------------------------------------+
//| Update Risk Limits after a trade closes                          |
//+------------------------------------------------------------------+
void UpdateRiskLimits(double pnl) {
    datetime now = TimeCurrent();
    ResetDailyLoss(now); // Ensure we're comparing against the correct day
    ResetWeeklyLoss(now); // Ensure we're comparing against the correct week

    dailyLoss += pnl;
    weeklyLoss += pnl;

    double balance = AccountInfoDouble(ACCOUNT_BALANCE); // Use current balance for limit check? Or start of day/week balance? Usually start is better.
                                                       // Let's use current balance for simplicity here. Refine if needed.

    if (UseMaxDailyLoss && MaxDailyLossPercent > 0) {
        double maxAllowedLoss = (balance * MaxDailyLossPercent / 100.0);
        if (dailyLoss < 0 && MathAbs(dailyLoss) >= maxAllowedLoss) {
            dailyLimitReached = true;
            Print("Maximum daily loss limit (", MaxDailyLossPercent,"%) reached. Loss: ", DoubleToString(dailyLoss, 2),". Trading disabled for today.");
            // Optionally close all open positions here if needed
        }
    }

    if (UseMaxWeeklyLoss && MaxWeeklyLossPercent > 0) {
         double maxAllowedLoss = (balance * MaxWeeklyLossPercent / 100.0);
         if (weeklyLoss < 0 && MathAbs(weeklyLoss) >= maxAllowedLoss) {
            weeklyLimitReached = true;
            Print("Maximum weekly loss limit (", MaxWeeklyLossPercent, "%) reached. Loss: ", DoubleToString(weeklyLoss, 2), ". Trading disabled for this week.");
            // Optionally close all open positions here if needed
         }
    }
}

//+------------------------------------------------------------------+
//| Check if risk limits allow trading                               |
//+------------------------------------------------------------------+
bool CheckRiskLimits()
{
    datetime now = TimeCurrent();
    ResetDailyLoss(now);  // Recalculate if day has changed
    ResetWeeklyLoss(now); // Recalculate if week has changed

    if (dailyLimitReached) return false;
    if (weeklyLimitReached) return false;

    return true;
}


//+------------------------------------------------------------------+
//| Get MA Value Helper                                              |
//+------------------------------------------------------------------+
bool GetMAValues(int handle, int index,  double &maValue)
  {
   double maBuffer[1];
   if(CopyBuffer(handle, 0, index, 1, maBuffer) <= 0) // Get value for main line (buffer 0)
     {
      //Alert("Error copying MA buffer - Code:", GetLastError());
      return(false);
     }
   maValue = maBuffer[0];
   return(true);
  }
//+------------------------------------------------------------------+
//| Get RSI Value Helper                                             |
//+------------------------------------------------------------------+
bool GetRSIValue(int index,  double &rsiValue)
  {
   if(rsiHandle == INVALID_HANDLE) return false; // Should not happen if Use_RSI_Filter is true
   double rsiBuffer[1];
   if(CopyBuffer(rsiHandle, 0, index, 1, rsiBuffer) <= 0)
     {
      //Alert("Error copying RSI buffer - Code:", GetLastError());
      return(false);
     }
   rsiValue = rsiBuffer[0];
   return(true);
  }
//+------------------------------------------------------------------+
//| Get MACD Values Helper                                           |
//+------------------------------------------------------------------+
bool GetMACDValues(int index,  double &mainValue,  double &signalValue)
  {
   if(macdHandle == INVALID_HANDLE) return false;
   double macdBufferMain[1];
   double macdBufferSignal[1];

   // Copy Main Line (Buffer 0)
   if(CopyBuffer(macdHandle, 0, index, 1, macdBufferMain) <= 0)
     {
     // Alert("Error copying MACD Main buffer - Code:", GetLastError());
      return(false);
     }
   // Copy Signal Line (Buffer 1)
   if(CopyBuffer(macdHandle, 1, index, 1, macdBufferSignal) <= 0)
     {
      //Alert("Error copying MACD Signal buffer - Code:", GetLastError());
      return(false);
     }
   mainValue = macdBufferMain[0];
   signalValue = macdBufferSignal[0];
   return(true);
  }

//+------------------------------------------------------------------+
//| Get MTF MA Values Helper                                         |
//+------------------------------------------------------------------+
bool GetMTFMAValues(int barsAgo,  double &fastMA,  double &slowMA) {
    if (mtfFastMaHandle == INVALID_HANDLE || mtfSlowMaHandle == INVALID_HANDLE) return false;

    // --- Calculate Shift ---
    // Find the bar on the current timeframe that corresponds to the close of the 'barsAgo' bar on the MTF timeframe.
    // Use iBarShift for accurate mapping, considering potential gaps or different trading hours.
    datetime mtfTargetTime = iTime(_Symbol, MTF_Timeframe, barsAgo);
    if (mtfTargetTime <= 0) {
        // Print("Could not get target MTF time for bar ", barsAgo);
        return false;
    }
    int mtfShift = iBarShift(_Symbol, MTF_Timeframe, mtfTargetTime);
    if (mtfShift < 0) {
         // Print("Could not find corresponding MTF bar shift.");
        return false;
    }

    // Ensure buffer sizes are adequate
    int barsRequiredMTF = mtfShift + 1; // We need data up to this shift index
    int fastMASize = ArraySize(mtfFastMA);
    int slowMASize = ArraySize(mtfSlowMA);

    if (fastMASize < barsRequiredMTF) ArrayResize(mtfFastMA, barsRequiredMTF);
    if (slowMASize < barsRequiredMTF) ArrayResize(mtfSlowMA, barsRequiredMTF);

    // --- Copy Buffers ---
    // Copy 1 bar starting from the calculated shift on the MTF timeframe
    if (CopyBuffer(mtfFastMaHandle, 0, mtfShift, 1, mtfFastMA) <= 0) {
        // Print("Failed to copy MTF Fast MA data. Shift:", mtfShift, " Error:", GetLastError());
        return false;
    }
     if (CopyBuffer(mtfSlowMaHandle, 0, mtfShift, 1, mtfSlowMA) <= 0) {
        // Print("Failed to copy MTF Slow MA data. Shift:", mtfShift, " Error:", GetLastError());
        return false;
    }

    // Assign the values from index 0 (which now holds the data for the calculated shift)
    fastMA = mtfFastMA[0];
    slowMA = mtfSlowMA[0];


    // Basic check for valid numbers
    if (fastMA == 0 || slowMA == 0 || fastMA == EMPTY_VALUE || slowMA == EMPTY_VALUE) {
        // Data might not be ready yet on higher timeframes
        // Print("MTF MA values are zero or empty.");
        return false;
    }


    return true;
}


//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double price) // Price needed for potential margin calculations later
  {
   double lots = FixedLotSize; // Default to fixed

   if(LotSizeMode == LOT_SIZE_PERCENT)
     {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE); // Or ACCOUNT_EQUITY
      double riskAmount = balance * (RiskPercent / 100.0);

      // --- For a more accurate percentage risk, you need the stop loss distance ---
      double slPips = 0;
      if(StopLossMode == SL_FIXED_PIPS) {
            slPips = FixedStopLossPips;
      } else if (StopLossMode == SL_ATR) {
          double atrVal = GetATRValue(1); // ATR on previous closed bar
          if(atrVal > 0) {
               slPips = (ATR_Multiplier_SL * atrVal) / SymbolInfoDouble(_Symbol, SYMBOL_POINT) / PointMultiplier();
          } else {
               slPips = FixedStopLossPips; // Fallback to fixed pips if ATR is zero/invalid
               Print("Warning: ATR value is zero or invalid for lot calculation. Using Fixed Pips SL distance.");
          }
      }

      if (slPips <= 0) {
           Print("Warning: Stop Loss distance is zero or negative for lot calculation. Using Fixed Lot Size.");
           return NormalizeLot(FixedLotSize); // Fallback if SL can't be determined
      }

      double slDistancePoints = slPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * PointMultiplier();
      if(slDistancePoints <= 0) {
         Print("Warning: Calculated SL distance in points is zero or less. Using Fixed Lot Size.");
         return NormalizeLot(FixedLotSize);
      }

      // Calculate value per point/pip
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
       if (tickValue <= 0 || tickSize <=0) {
          Print("Warning: Invalid Tick Value/Size for ", _Symbol,". Cannot calculate risk-based lot size. Using Fixed Lot Size.");
          return NormalizeLot(FixedLotSize);
       }
      double valuePerPoint = tickValue / tickSize * SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      // Calculate Lot Size
      if(valuePerPoint > 0) {
        lots = riskAmount / (slDistancePoints * valuePerPoint);
      } else {
         Print("Warning: Value per point is zero. Using Fixed Lot Size.");
         lots = FixedLotSize; // Fallback
      }


     }

   // Normalize and check against min/max limits
   return NormalizeLot(lots);
  }
//+------------------------------------------------------------------+
//| Normalize Lot Size                                               |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
    double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

    // Ensure lot is multiple of step
    lot = MathRound(lot / volumeStep) * volumeStep;

    // Check Min/Max limits
    if (lot < minVolume) lot = minVolume;
    if (lot > maxVolume) lot = maxVolume;

    return(lot);
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss Price                                        |
//+------------------------------------------------------------------+
double CalculateStopLoss(double entryPrice, int orderType)
  {
   double stopLoss = 0;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double multiplier = PointMultiplier(); // Handle 3/5 digit brokers

   if(StopLossMode == SL_FIXED_PIPS)
     {
       double pips = FixedStopLossPips * point * multiplier;
       if(orderType == ORDER_TYPE_BUY) stopLoss = entryPrice - pips;
       else if(orderType == ORDER_TYPE_SELL) stopLoss = entryPrice + pips;
     }
   else if(StopLossMode == SL_ATR)
     {
      double atrVal = GetATRValue(1); // ATR on previous closed bar
      if(atrVal > 0)
       {
        double atrDistance = ATR_Multiplier_SL * atrVal;
         if(orderType == ORDER_TYPE_BUY) stopLoss = entryPrice - atrDistance;
         else if(orderType == ORDER_TYPE_SELL) stopLoss = entryPrice + atrDistance;
       }
      else // Fallback if ATR is invalid
       {
         Print("Warning: ATR is zero or invalid. Calculating SL using Fixed Pips.");
         double pips = FixedStopLossPips * point * multiplier;
         if(orderType == ORDER_TYPE_BUY) stopLoss = entryPrice - pips;
         else if(orderType == ORDER_TYPE_SELL) stopLoss = entryPrice + pips;
       }
     }

   // Normalize SL price to the symbol's digits and ensure it's valid
   stopLoss = NormalizeDouble(stopLoss, _Digits);

   // Check if SL is too close according to broker's stops level
   double stopsLevelPips = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopsLevelPips * point;
   double currentPrice = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if (orderType == ORDER_TYPE_BUY && stopLoss > currentPrice - minDistance) {
        stopLoss = currentPrice - minDistance;
       // Print("Adjusting BUY SL due to Stops Level. New SL: ", stopLoss);
   } else if (orderType == ORDER_TYPE_SELL && stopLoss < currentPrice + minDistance && stopLoss > 0) {
       stopLoss = currentPrice + minDistance;
      // Print("Adjusting SELL SL due to Stops Level. New SL: ", stopLoss);
   }


   return(stopLoss > 0 ? NormalizeDouble(stopLoss, _Digits) : 0); // Return 0 if calculation failed
  }

//+------------------------------------------------------------------+
//| Calculate Take Profit Price                                      |
//+------------------------------------------------------------------+
double CalculateTakeProfit(double entryPrice, int orderType)
  {
   double takeProfit = 0;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double multiplier = PointMultiplier();

   if(TakeProfitMode == TP_FIXED_PIPS)
     {
       double pips = FixedTakeProfitPips * point * multiplier;
       if(orderType == ORDER_TYPE_BUY) takeProfit = entryPrice + pips;
       else if(orderType == ORDER_TYPE_SELL) takeProfit = entryPrice - pips;
     }
   else if(TakeProfitMode == TP_ATR)
     {
      double atrVal = GetATRValue(1);
       if(atrVal > 0)
       {
         double atrDistance = ATR_Multiplier_TP * atrVal;
         if(orderType == ORDER_TYPE_BUY) takeProfit = entryPrice + atrDistance;
         else if(orderType == ORDER_TYPE_SELL) takeProfit = entryPrice - atrDistance;
       }
       else // Fallback
       {
           Print("Warning: ATR is zero or invalid. Calculating TP using Fixed Pips.");
           double pips = FixedTakeProfitPips * point * multiplier;
           if(orderType == ORDER_TYPE_BUY) takeProfit = entryPrice + pips;
           else if(orderType == ORDER_TYPE_SELL) takeProfit = entryPrice - pips;
       }

     }

    // Normalize TP price
   takeProfit = NormalizeDouble(takeProfit, _Digits);


   // Check if TP is too close according to broker's stops level
   double stopsLevelPips = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopsLevelPips * point;
   double currentPrice = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

    if (orderType == ORDER_TYPE_BUY && takeProfit < currentPrice + minDistance) {
        takeProfit = currentPrice + minDistance;
      //  Print("Adjusting BUY TP due to Stops Level. New TP: ", takeProfit);
    } else if (orderType == ORDER_TYPE_SELL && takeProfit > currentPrice - minDistance && takeProfit > 0) {
        takeProfit = currentPrice - minDistance;
       // Print("Adjusting SELL TP due to Stops Level. New TP: ", takeProfit);
    }

   return (takeProfit > 0 ? NormalizeDouble(takeProfit, _Digits) : 0); // Return 0 if calculation failed or mode is off
  }
//+------------------------------------------------------------------+
//| Get ATR Value Helper                                             |
//+------------------------------------------------------------------+
double GetATRValue(int index)
  {
   if(atrHandle == INVALID_HANDLE) {
        // Attempt to initialize if not already done (defensive)
        int atr_period = MathMax(MathMax(ATR_Period_SL, ATR_Period_TP), (UseTrailingStop && TrailingStopMode == TRAIL_ATR) ? ATR_Period_Trail : 1);
        atrHandle = iATR(_Symbol, _Period, atr_period);
        if(atrHandle == INVALID_HANDLE) return 0; // Still failed
   }

   double atrBuffer[1];
   if(CopyBuffer(atrHandle, 0, index, 1, atrBuffer) <= 0)
     {
      // Print("Error copying ATR buffer - Code:", GetLastError());
       return 0;
     }
   return atrBuffer[0];
  }
//+------------------------------------------------------------------+
//| Get Point Multiplier for 3/5 Digit Brokers                     |
//+------------------------------------------------------------------+
int PointMultiplier()
 {
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    if (digits == 3 || digits == 5) return 10;
    return 1;
 }
//+------------------------------------------------------------------+
//| Manage Trailing Stop Loss                                        |
//+------------------------------------------------------------------+
void ManageTrailingStop(MqlTick &tick)
  {
    if(!UseTrailingStop) return;

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double multiplier = PointMultiplier();
    double trailingDistance = 0;
    double currentSL = 0;
    double newSL = 0;
    double openPrice = 0;
    long positionTicket = 0;
    ENUM_POSITION_TYPE positionType;


    // Determine Trailing Distance
     if (TrailingStopMode == TRAIL_FIXED_PIPS) {
        trailingDistance = TrailingStopPips * point * multiplier;
    } else if (TrailingStopMode == TRAIL_ATR) {
        double atrVal = GetATRValue(1); // Use previous bar's ATR
        if (atrVal > 0) {
            trailingDistance = ATR_Multiplier_Trail * atrVal;
        } else {
            Print("Warning: ATR invalid for trailing stop. Using Fixed Pips Trail.");
            trailingDistance = TrailingStopPips * point * multiplier; // Fallback
        }
    }
    if(trailingDistance <= 0) {
         Print("Warning: Invalid trailing distance (", trailingDistance, "). Trailing Stop disabled for this tick.");
         return; // Cannot trail if distance is invalid
    }


    // Iterate through open positions for THIS symbol and Magic Number
    for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
        if((positionTicket = PositionGetTicket(i)) > 0) // Select position by index
         {
           // Check if it belongs to this EA and Symbol
           if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
             {
                currentSL = PositionGetDouble(POSITION_SL);
                openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

                if(positionType == POSITION_TYPE_BUY)
                 {
                    // Calculate potential new SL based on current highest high or current price
                    // Simple: Based on current Ask - trail distance
                     newSL = tick.ask - trailingDistance;

                     // Activation condition: Profit must be at least the trail distance
                     if (tick.bid > openPrice + trailingDistance)
                     {
                          // Only modify if the new SL is HIGHER than the current SL AND HIGHER than the open price
                          if (newSL > currentSL && newSL > openPrice)
                          {
                             // Check Trailing Step
                             if(MathAbs(newSL - currentSL) >= TrailingStopStepPips * point * multiplier ) {
                                ModifyPositionSL(positionTicket, newSL);
                             }

                          }
                     }
                 }
               else if(positionType == POSITION_TYPE_SELL)
                 {
                   // Calculate potential new SL based on current lowest low or current price
                   // Simple: Based on current Bid + trail distance
                    newSL = tick.bid + trailingDistance;

                    // Activation condition: Profit must be at least the trail distance
                    if (tick.ask < openPrice - trailingDistance)
                    {
                       // Only modify if the new SL is LOWER than the current SL AND LOWER than the open price
                       // Ensure newSL is positive, otherwise it's an invalid SL level
                       if (newSL < currentSL && newSL < openPrice && newSL > 0 )
                       {
                             // Check Trailing Step
                             if(MathAbs(newSL - currentSL) >= TrailingStopStepPips * point * multiplier) {
                                ModifyPositionSL(positionTicket, newSL);
                             }
                       }
                        // Handle case where currentSL is 0 (initially)
                        else if (currentSL == 0 && newSL < openPrice && newSL > 0)
                        {
                            // Check Trailing Step (relative to open price if no SL exists)
                           // This activation logic could be refined - first move might not need a step check
                            if (MathAbs(openPrice - newSL) >= TrailingStopStepPips * point * multiplier) {
                                ModifyPositionSL(positionTicket, newSL);
                            }
                        }
                    }
                 }

             } // End if magic/symbol matches
         } // End if position ticket valid
      } // End loop through positions
  }
//+------------------------------------------------------------------+
//| Modify Stop Loss for an existing position                         |
//+------------------------------------------------------------------+
void ModifyPositionSL(long ticket, double newSL)
{
    if (PositionSelectByTicket(ticket)) {
        double currentTP = PositionGetDouble(POSITION_TP);
        newSL = NormalizeDouble(newSL, _Digits);

        // Check against Stops Level BEFORE sending modify request
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double stopsLevelPips = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
        double minDistance = stopsLevelPips * point;
        double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

        // Don't allow SL modification too close to market price
        if (isBuy && newSL > currentPrice - minDistance) {
             Print("Cannot modify Buy SL for #",ticket," to ",newSL," - Too close to current Ask (",currentPrice,"). Min distance: ",minDistance);
             return;
        }
         if (!isBuy && newSL < currentPrice + minDistance && newSL > 0) {
             Print("Cannot modify Sell SL for #",ticket," to ",newSL," - Too close to current Bid (",currentPrice,"). Min distance: ",minDistance);
             return;
        }

        if (trade.PositionModify(ticket, newSL, currentTP)) {
            Print("Trailing stop for position #", ticket, " modified to ", newSL);
             // Optionally Log this modification event
            // LogTrade("Modify", (isBuy ? "BUY" : "SELL"), _Symbol, PositionGetDouble(POSITION_VOLUME), PositionGetDouble(POSITION_PRICE_CURRENT) , newSL, currentTP, ticket, MagicNumber, "Trailing Stop", 0, 0);

        } else {
            Print("Error modifying position #", ticket, " SL to ", newSL, " : ", trade.ResultRetcodeDescription());
        }
    }
}

//+------------------------------------------------------------------+
//| Count Open Positions by this EA                                 |
//+------------------------------------------------------------------+
int CountEaOpenPositions()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
       ulong ticket = PositionGetTicket(i);
       if(PositionSelectByTicket(ticket)) // Ensure position data is loaded
       {
           if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
             {
               count++;
             }
       }

     }
   return count;
  }

//+------------------------------------------------------------------+
//| Log Trade Action to File                                         |
//+------------------------------------------------------------------+
void LogTrade(string action, string type, string symbol, double lots, double price, double sl, double tp, long ticket, long magic, string comment, double resultPrice, double profit)
{
    if (!LogTradesToFile) return;

    // Use FILE_READ | FILE_WRITE to append without clearing
    fileHandle = FileOpen(LogFileName, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI);

    if (fileHandle != INVALID_HANDLE)
    {
        // Move to the end of the file to append
        FileSeek(fileHandle, 0, SEEK_END);

        // Write data
        FileWrite(fileHandle,
                  TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), // Timestamp
                  action,        // e.g., "OrderSend", "Trade Closed", "Modify"
                  type,          // e.g., "BUY", "SELL", "Closed BUY"
                  symbol,
                  DoubleToString(lots, 2),
                  DoubleToString(price, _Digits),
                  DoubleToString(sl, _Digits),
                  DoubleToString(tp, _Digits),
                  (string)ticket, // Ticket
                  (string)magic, // Magic Number
                  comment,
                  DoubleToString(resultPrice, _Digits), // Price at closure/result
                  DoubleToString(profit, 2)            // Profit
                 );

        FileClose(fileHandle);
    }
    else
    {
       // Alert("Error opening log file ", LogFileName, " for writing - Error code: ", GetLastError());
       // Avoid continuous alerts, maybe disable logging temporarily or print once.
       // static bool logErrorShown = false;
       // if (!logErrorShown) {
       //     Alert("Error opening log file ", LogFileName, " for writing - Error code: ", GetLastError());
       //     logErrorShown = true;
       // }

    }
}

//+------------------------------------------------------------------+