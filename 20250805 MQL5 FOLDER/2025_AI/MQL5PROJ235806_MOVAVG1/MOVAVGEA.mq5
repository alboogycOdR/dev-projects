//+------------------------------------------------------------------+
//|                                              MovingAverageCrossEA|
//|                        Copyright 2023, Your Name/Company         |
//|                                              https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name/Company"
#property link      "https://www.example.com"
#property version   "1.00"
#property description "Automated EA based on Moving Average Crossover Strategy"
#property strict

#include <Trade\Trade.mqh> // Trading class
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Indicators\MovingAverages.mqh> // Optional, but good practice

//--- EA Input Parameters (User-Friendly Dashboard)
//--- MA Settings
input group             "Moving Average Settings"
input int               InpFastMAPeriod   = 50;          // Fast MA Period
input int               InpSlowMAPeriod   = 200;         // Slow MA Period
input int               InpMAShift        = 1;           // MA Shift (1 = check cross on previous bar)
input ENUM_MA_METHOD    InpMAMethod       = MODE_EMA;    // MA Method (SMA, EMA, SMMA, LWMA)
input ENUM_APPLIED_PRICE InpMAPrice       = PRICE_CLOSE; // Applied Price

//--- Confirmation Settings (Optional)
input group             "Confirmation Indicator (Optional)"
input bool              InpUseConfirmation = false;      // Use Confirmation Indicator?
input enum              ConfirmationType { RSI, MACD }; // Confirmation Type
input ConfirmationType  InpConfType        = RSI;       // Selected Confirmation Indicator
// RSI Settings
input int               InpRsiPeriod       = 14;          // RSI Period
input double            InpRsiBuyLevel     = 55;          // RSI level above which to allow buys
input double            InpRsiSellLevel    = 45;          // RSI level below which to allow sells
input ENUM_APPLIED_PRICE InpRsiPrice       = PRICE_CLOSE; // RSI Applied Price
// MACD Settings
input int               InpMacdFastPeriod  = 12;          // MACD Fast EMA Period
input int               InpMacdSlowPeriod  = 26;          // MACD Slow EMA Period
input int               InpMacdSignalPeriod = 9;           // MACD Signal SMA Period
input ENUM_APPLIED_PRICE InpMacdPrice       = PRICE_CLOSE; // MACD Applied Price

//--- Risk Management
input group             "Risk Management"
input long              InpMagicNumber    = 12345;       // EA Magic Number
input enum              LotSizeMode { Fixed, Percent }; // Lot Sizing Mode
input LotSizeMode       InpLotSizeMode    = Percent;   // Selected Lot Size Mode
input double            InpFixedLotSize   = 0.01;        // Fixed Lot Size
input double            InpPercentRisk    = 1.0;         // Risk Percent per Trade
input enum              StopLossType { Points, ATR }; // Stop Loss Type
input StopLossType      InpSLType         = ATR;         // Selected SL Type
input enum              TakeProfitType { Points, ATR, FixedRatio }; // TP Type
input TakeProfitType    InpTPType         = FixedRatio;  // Selected TP Type
input int               InpStopLossPoints = 500;         // Stop Loss in Points (if Points selected)
input int               InpTakeProfitPoints = 1000;       // Take Profit in Points (if Points selected)
input int               InpAtrPeriod      = 14;          // ATR Period (for SL/TP)
input double            InpAtrSLMultiplier = 1.5;         // ATR Multiplier for Stop Loss
input double            InpAtrTPMultiplier = 3.0;         // ATR Multiplier for Take Profit
input double            InpTpRRFactor      = 2.0;         // Risk:Reward Ratio for TP (if FixedRatio)
input bool              InpUseTrailingStop = true;        // Use Trailing Stop?
input double            InpTrailStopAtrMult = 1.0;         // ATR Multiplier for Trailing Stop Trigger/Distance
input double            InpMaxDailyLossPct = 5.0;         // Maximum Daily Loss Percent
input double            InpMaxWeeklyLossPct= 10.0;        // Maximum Weekly Loss Percent

//--- Trading Hours
input group             "Trading Session Filter"
input bool              InpUseTradingHours = false;       // Enable Trading Hours Filter?
input int               InpStartHour      = 3;           // Trading Start Hour (Server Time)
input int               InpStartMinute    = 0;           // Trading Start Minute
input int               InpEndHour        = 20;          // Trading End Hour (Server Time)
input int               InpEndMinute      = 59;          // Trading End Minute

//--- Logging
input group             "Logging"
input bool              InpEnableLogging  = true;        // Enable CSV Trade Logging?
input string            InpLogFileName    = "MACross_TradeLog.csv"; // Log File Name

//--- Global Variables
CTrade          trade;                     // Trading object
CSymbolInfo     symbolInfo;                // Symbol Info object
CAccountInfo    accountInfo;               // Account Info object

// Indicator Handles
int             h_fastMA = INVALID_HANDLE;
int             h_slowMA = INVALID_HANDLE;
int             h_atr = INVALID_HANDLE;
int             h_confInd1 = INVALID_HANDLE; // Handle for RSI or MACD Main
int             h_confInd2 = INVALID_HANDLE; // Handle for MACD Signal

// Indicator Buffers
double          fastMA_buf[];
double          slowMA_buf[];
double          atr_buf[];
double          confInd1_buf[]; // Buffer for RSI or MACD Main
double          confInd2_buf[]; // Buffer for MACD Signal

// Risk Management Tracking
double          startBalanceDay = -1;
double          startBalanceWeek = -1;
datetime        lastCheckTimeDay = 0;
datetime        lastCheckTimeWeek = 0;
bool            dailyLossLimitHit = false;
bool            weeklyLossLimitHit = false;

// Logging
int             logFileHandle = INVALID_HANDLE;
bool            isTester; // Are we running in the Strategy Tester?

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Initializing ", MQLInfoString(MQL_PROGRAM_NAME), " v", MQLInfoString(MQL_PROGRAM_VERSION));
   isTester = MQLInfoInteger(MQL_TESTER);

   //--- Initialize objects
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(MarketInfo(_Symbol, MODE_SPREAD)); // Set allowable slippage based on spread
   trade.SetTypeFillingBySymbol(_Symbol);
   symbolInfo.Name(_Symbol);
   accountInfo.Refresh();

   //--- Check Inputs (Basic)
   if (InpFastMAPeriod <= 0 || InpSlowMAPeriod <= 0 || InpFastMAPeriod >= InpSlowMAPeriod)
   {
      Alert("Invalid MA Periods! Fast MA must be less than Slow MA and both > 0.");
      return(INIT_FAILED);
   }
   if (InpAtrPeriod <= 0 && (InpSLType == ATR || InpTPType == ATR || InpUseTrailingStop))
   {
       Alert("ATR Period must be greater than 0 if used for SL/TP/Trailing Stop.");
       return(INIT_FAILED);
   }


   //--- Create Indicator Handles
   h_fastMA = iMA(_Symbol, _Period, InpFastMAPeriod, 0, InpMAMethod, InpMAPrice);
   if (h_fastMA == INVALID_HANDLE)
   {
      Alert("Error creating Fast MA indicator handle: ", GetLastError());
      return(INIT_FAILED);
   }

   h_slowMA = iMA(_Symbol, _Period, InpSlowMAPeriod, 0, InpMAMethod, InpMAPrice);
   if (h_slowMA == INVALID_HANDLE)
   {
      Alert("Error creating Slow MA indicator handle: ", GetLastError());
      return(INIT_FAILED);
   }

   // ATR handle needed if used for SL, TP or Trailing
   if(InpSLType == ATR || InpTPType == ATR || InpUseTrailingStop)
   {
       h_atr = iATR(_Symbol, _Period, InpAtrPeriod);
       if (h_atr == INVALID_HANDLE)
       {
          Alert("Error creating ATR indicator handle: ", GetLastError());
          return(INIT_FAILED);
       }
       if(!ArraySetAsSeries(atr_buf, true)) return(INIT_FAILED); // Prepare buffer for ATR
   }


   // Confirmation Indicator Handles
   if (InpUseConfirmation)
   {
       if (InpConfType == RSI)
       {
           h_confInd1 = iRSI(_Symbol, _Period, InpRsiPeriod, InpRsiPrice);
           if (h_confInd1 == INVALID_HANDLE)
           {
               Alert("Error creating RSI indicator handle: ", GetLastError());
               return(INIT_FAILED);
           }
           if(!ArraySetAsSeries(confInd1_buf, true)) return(INIT_FAILED);
       }
       else // MACD
       {
           h_confInd1 = iMACD(_Symbol, _Period, InpMacdFastPeriod, InpMacdSlowPeriod, InpMacdSignalPeriod, InpMacdPrice);
           if (h_confInd1 == INVALID_HANDLE)
           {
               Alert("Error creating MACD indicator handle: ", GetLastError());
               return(INIT_FAILED);
           }
           // Set buffers for MACD Main (0) and Signal (1)
           if(!SetIndexBuffer(h_confInd1, 0, confInd1_buf)) {Alert("Failed SetIndexBuffer for MACD Main"); return(INIT_FAILED);}
           if(!ArraySetAsSeries(confInd1_buf, true)) return(INIT_FAILED);
           if(!SetIndexBuffer(h_confInd1, 1, confInd2_buf)) {Alert("Failed SetIndexBuffer for MACD Signal"); return(INIT_FAILED);}
           if(!ArraySetAsSeries(confInd2_buf, true)) return(INIT_FAILED);
       }
   }

   //--- Set Buffer Directions (Important for accessing [0], [1] correctly)
   if(!ArraySetAsSeries(fastMA_buf, true)) return(INIT_FAILED);
   if(!ArraySetAsSeries(slowMA_buf, true)) return(INIT_FAILED);


   //--- Initialize Logging (only if enabled and not in Optimization)
   if(InpEnableLogging && !MQLInfoInteger(MQL_OPTIMIZATION))
   {
        // Reset file at the start of a test or live trading
       if(isTester) FileDelete(InpLogFileName);

       logFileHandle = FileOpen(InpLogFileName, FILE_WRITE | FILE_CSV | FILE_ANSI);
       if(logFileHandle == INVALID_HANDLE)
       {
           Print("Error opening log file ", InpLogFileName, ". Error code: ", GetLastError());
           // Don't fail init, just disable logging
           InpEnableLogging = false;
       }
       else
       {
           // Write Header Row
           FileWrite(logFileHandle, "Timestamp", "Type", "Symbol", "Lots", "Price", "SL", "TP", "Result P/L", "Comment", "Magic");
       }
   }

   //--- Initialize Risk Limits
   ResetLossLimits(); // Initialize tracking variables

   Print("Initialization successful.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Deinitializing EA. Reason: ", reason);

   //--- Release Indicator Handles
   if (h_fastMA != INVALID_HANDLE) IndicatorRelease(h_fastMA);
   if (h_slowMA != INVALID_HANDLE) IndicatorRelease(h_slowMA);
   if (h_atr != INVALID_HANDLE) IndicatorRelease(h_atr);
   if (h_confInd1 != INVALID_HANDLE) IndicatorRelease(h_confInd1);
   // Note: h_confInd2 is implicitly released when h_confInd1 (MACD handle) is released

   //--- Close Log File
   if (logFileHandle != INVALID_HANDLE)
   {
      FileClose(logFileHandle);
   }

   Print("Deinitialization complete.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check if new bar has started (optional, can reduce computations)
   static datetime lastBarTime = 0;
   if(TimeCurrent() == lastBarTime)
       return;
   lastBarTime = TimeCurrent();

   //--- Ensure sufficient history
   if (Bars(_Symbol, _Period) < MathMax(InpSlowMAPeriod, InpAtrPeriod) + 5) // Add buffer
   {
      // Print("Waiting for sufficient historical data...");
      return;
   }

    //--- Update Account & Symbol Info
    accountInfo.Refresh();
    symbolInfo.RefreshRates();


   //--- Check Trading Hours
   if (InpUseTradingHours && !IsTradeAllowedTime())
   {
      // Optionally close positions outside trading hours? Or just prevent new ones.
      // Print("Outside allowed trading hours.");
      return;
   }

   //--- Check Risk Limits
   if (CheckLossLimits())
   {
       // If limit hit, maybe close all positions? For now, just prevent new trades.
       // Print("Risk limit reached. No new trades allowed.");
       ManageOpenPositions(); // Still manage trailing stops etc.
       return;
   }

   //--- Get Indicator Data
   if (!CopyIndicatorBuffers())
   {
      Print("Error copying indicator buffers.");
      return;
   }

   //--- Check for Signals and Manage Positions
   if (PositionSelect(_Symbol)) // Check if there is an open position for this symbol
   {
       if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) // Belongs to this EA
       {
           ManageOpenPositions();
       }
       else
       {
           // Position exists but opened by another EA/manual trade - ignore
           CheckEntrySignals(); // Still check for new entries if allowed
       }
   }
   else // No open position for this symbol/EA
   {
        CheckEntrySignals();
   }
}

//+------------------------------------------------------------------+
//| Check Loss Limits                                                |
//+------------------------------------------------------------------+
bool CheckLossLimits()
{
    datetime now = TimeCurrent();
    datetime todayStart = iTime(_Symbol, PERIOD_D1, 0);
    datetime weekStart = now - DayOfWeek(now) * 86400 + ((DayOfWeek(now)==0)? -6*86400 : 0); // Adjust for Sunday as start

    accountInfo.Refresh(); // Get latest balance/equity
    double currentEquity = accountInfo.Equity();

    // --- Daily Check ---
    if(startBalanceDay < 0 || todayStart > lastCheckTimeDay ) // Initialize or new day
    {
        startBalanceDay = currentEquity; // Start tracking from current equity
        lastCheckTimeDay = todayStart;
        dailyLossLimitHit = false;
        PrintFormat("New Trading Day %s. Daily loss tracking reset. Start Equity: %.2f", TimeToString(todayStart, TIME_DATE), startBalanceDay);
    }
    else // Check current loss if not already hit
    {
        if(!dailyLossLimitHit && InpMaxDailyLossPct > 0)
        {
            double loss = startBalanceDay - currentEquity; // Potential loss calculated from start equity
            double lossPct = (loss / startBalanceDay) * 100.0;

            if(loss > 0 && lossPct >= InpMaxDailyLossPct)
            {
                 Alert("Maximum Daily Loss Limit (", DoubleToString(InpMaxDailyLossPct,1),"%) Reached! Equity Change: ", DoubleToString(loss,2));
                 dailyLossLimitHit = true;
                 // Optional: Close all open positions?
                 // CloseAllPositions();
            }
        }
    }

    // --- Weekly Check ---
     if(startBalanceWeek < 0 || weekStart > lastCheckTimeWeek) // Initialize or new week
     {
        startBalanceWeek = currentEquity;
        lastCheckTimeWeek = weekStart;
        weeklyLossLimitHit = false;
        PrintFormat("New Trading Week starting around %s. Weekly loss tracking reset. Start Equity: %.2f", TimeToString(weekStart, TIME_DATE), startBalanceWeek);
     }
     else // Check current loss if not already hit
     {
         if(!weeklyLossLimitHit && InpMaxWeeklyLossPct > 0)
         {
            double loss = startBalanceWeek - currentEquity; // Potential loss from week start equity
            double lossPct = (loss / startBalanceWeek) * 100.0;

            if(loss > 0 && lossPct >= InpMaxWeeklyLossPct)
            {
                 Alert("Maximum Weekly Loss Limit (", DoubleToString(InpMaxWeeklyLossPct,1),"%) Reached! Equity Change: ", DoubleToString(loss,2));
                 weeklyLossLimitHit = true;
                  // Optional: Close all open positions?
                 // CloseAllPositions();
            }
         }
     }


    // Return true if *any* limit is currently hit
    return dailyLossLimitHit || weeklyLossLimitHit;
}

//+------------------------------------------------------------------+
//| Reset loss limit tracking (called from OnInit)                   |
//+------------------------------------------------------------------+
void ResetLossLimits()
{
    datetime now = TimeCurrent();
    datetime todayStart = iTime(_Symbol, PERIOD_D1, 0);
     datetime weekStart = now - DayOfWeek(now) * 86400 + ((DayOfWeek(now)==0)? -6*86400 : 0); // Adjust for Sunday as start

    accountInfo.Refresh();
    startBalanceDay = accountInfo.Equity();
    startBalanceWeek = accountInfo.Equity();
    lastCheckTimeDay = todayStart;
    lastCheckTimeWeek = weekStart;
    dailyLossLimitHit = false;
    weeklyLossLimitHit = false;
}

//+------------------------------------------------------------------+
//| Copy Indicator Buffers                                           |
//+------------------------------------------------------------------+
bool CopyIndicatorBuffers()
{
    // Copy MA buffers (need last 2 bars for crossover detection)
    if (CopyBuffer(h_fastMA, 0, InpMAShift, 2, fastMA_buf) < 2 ||
        CopyBuffer(h_slowMA, 0, InpMAShift, 2, slowMA_buf) < 2)
    {
       // Print("Error copying MA buffers: ", GetLastError());
       return false;
    }

    // Copy ATR buffer (need latest value) if required
    if (h_atr != INVALID_HANDLE)
    {
        if(CopyBuffer(h_atr, 0, 0, 1, atr_buf) < 1)
        {
           // Print("Error copying ATR buffer: ", GetLastError());
            return false;
        }
        // Handle potential zero ATR value - perhaps use minimum point size?
        if (atr_buf[0] <= symbolInfo.Point() * 2) { // If ATR is basically zero
             Print("Warning: ATR value (", DoubleToString(atr_buf[0], symbolInfo.Digits()) ,") is very small or zero.");
             // Maybe default to a points-based SL/TP here? For simplicity, we proceed but this might cause issues.
        }

    }

    // Copy Confirmation buffers (need last 2 for MACD cross, 1 for RSI level)
    if (InpUseConfirmation)
    {
        int barsToCopy = (InpConfType == MACD) ? 2 : 1;
        if (CopyBuffer(h_confInd1, 0, 0, barsToCopy, confInd1_buf) < barsToCopy)
        {
           // Print("Error copying confirmation buffer 1: ", GetLastError());
            return false;
        }
        if (InpConfType == MACD)
        {
            if (CopyBuffer(h_confInd1, 1, 0, barsToCopy, confInd2_buf) < barsToCopy) // Copy MACD Signal (buffer 1)
            {
               // Print("Error copying MACD signal buffer: ", GetLastError());
                return false;
            }
        }
    }
    return true;
}


//+------------------------------------------------------------------+
//| Manage Open Positions (Trailing Stop, Exit Conditions?)          |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    if(!PositionSelect(_Symbol)) return; // Should not happen if called correctly, but safety first
    if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) return; // Not our position

    long positionType = PositionGetInteger(POSITION_TYPE);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = (positionType == POSITION_TYPE_BUY) ? symbolInfo.Bid() : symbolInfo.Ask();
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    double pointsProfit = 0;
    ulong ticket = PositionGetInteger(POSITION_TICKET);


    if (positionType == POSITION_TYPE_BUY) {
        pointsProfit = (symbolInfo.Bid() - openPrice) / symbolInfo.Point();
    } else { // SELL
        pointsProfit = (openPrice - symbolInfo.Ask()) / symbolInfo.Point();
    }


    // --- Trailing Stop Logic ---
    if (InpUseTrailingStop && h_atr != INVALID_HANDLE && atr_buf[0] > symbolInfo.Point())
    {
        double trailDistance = atr_buf[0] * InpTrailStopAtrMult;
        if (trailDistance < symbolInfo.Stoplevel() * symbolInfo.Point()) // Ensure min distance
           trailDistance = symbolInfo.Stoplevel() * symbolInfo.Point();

        double newSL = 0;
        bool modify = false;

        if (positionType == POSITION_TYPE_BUY && pointsProfit * symbolInfo.Point() > trailDistance )
        {
             newSL = NormalizeDouble(symbolInfo.Bid() - trailDistance, symbolInfo.Digits());
             // Only modify if new SL is better (higher) than current SL
             if (currentSL == 0 || newSL > currentSL)
             {
                 modify = true;
             }
        }
        else if (positionType == POSITION_TYPE_SELL && pointsProfit * symbolInfo.Point() > trailDistance)
        {
             newSL = NormalizeDouble(symbolInfo.Ask() + trailDistance, symbolInfo.Digits());
             // Only modify if new SL is better (lower) than current SL
             if (currentSL == 0 || newSL < currentSL)
             {
                 modify = true;
             }
        }

        if (modify)
        {
             if(trade.PositionModify(ticket, newSL, currentTP))
             {
                 PrintFormat("Trailing Stop updated for ticket %d: New SL=%.5f", ticket, newSL);
             } else {
                 PrintFormat("Error modifying trailing stop for ticket %d: %d", ticket, trade.ResultRetcode());
             }
        }

    }


    // --- Optional: Exit on MA Cross Back ---
    // Can add logic here to close the position if MAs cross back against the trade direction
    // Example: If holding BUY and FastMA[0] < SlowMA[0]
    bool crossExitCondition = false;
    if(positionType == POSITION_TYPE_BUY && fastMA_buf[0] < slowMA_buf[0]) crossExitCondition = true;
    if(positionType == POSITION_TYPE_SELL && fastMA_buf[0] > slowMA_buf[0]) crossExitCondition = true;

    if (crossExitCondition)
    {
         PrintFormat("MA crossed back against position %d. Closing.", ticket);
         ClosePosition(ticket, "MA cross back");
         return; // Exit after closing
    }
}

//+------------------------------------------------------------------+
//| Check Entry Signals                                              |
//+------------------------------------------------------------------+
void CheckEntrySignals()
{
    // MA Crossover Check (using the shift defined in inputs)
    // index 0 = current closing/most recent completed bar (due to shift=1 and ArrayAsSeries)
    // index 1 = the bar before that

    bool buySignal = fastMA_buf[1] < slowMA_buf[1] && fastMA_buf[0] > slowMA_buf[0];
    bool sellSignal = fastMA_buf[1] > slowMA_buf[1] && fastMA_buf[0] < slowMA_buf[0];

    if (!buySignal && !sellSignal)
       return; // No crossover detected

    // Apply Confirmation Filter
    if (InpUseConfirmation && !CheckConfirmation(buySignal, sellSignal))
    {
       // Print("MA Signal found but confirmation failed.");
       return;
    }


    // Execute Trade if Signal Confirmed
    double lotSize = CalculateLotSize();
    if (lotSize <= 0) {
         Print("Invalid Lot Size calculated: ", lotSize);
         return;
    }

    double slPrice = 0;
    double tpPrice = 0;
    double atrVal = (h_atr != INVALID_HANDLE && atr_buf[0] > 0) ? atr_buf[0] : 0;


    if (buySignal)
    {
       slPrice = CalculateStopLoss(ORDER_TYPE_BUY, symbolInfo.Ask(), atrVal);
       tpPrice = CalculateTakeProfit(ORDER_TYPE_BUY, symbolInfo.Ask(), slPrice, atrVal);
       if (OpenBuy(lotSize, slPrice, tpPrice))
       {
           // Log trade details if successful
           LogTrade("BUY", lotSize, symbolInfo.Ask(), slPrice, tpPrice, "Entry");
       }
    }
    else if (sellSignal)
    {
       slPrice = CalculateStopLoss(ORDER_TYPE_SELL, symbolInfo.Bid(), atrVal);
       tpPrice = CalculateTakeProfit(ORDER_TYPE_SELL, symbolInfo.Bid(), slPrice, atrVal);
       if (OpenSell(lotSize, slPrice, tpPrice))
       {
            LogTrade("SELL", lotSize, symbolInfo.Bid(), slPrice, tpPrice, "Entry");
       }
    }
}

//+------------------------------------------------------------------+
//| Check Confirmation Indicator Condition                           |
//+------------------------------------------------------------------+
bool CheckConfirmation(bool isBuySignal, bool isSellSignal)
{
    if (!InpUseConfirmation) return true; // No confirmation needed

    if (InpConfType == RSI && h_confInd1 != INVALID_HANDLE)
    {
        // RSI Level Confirmation
        double rsiValue = confInd1_buf[0]; // Use current bar's RSI value
        if (isBuySignal && rsiValue >= InpRsiBuyLevel) return true;
        if (isSellSignal && rsiValue <= InpRsiSellLevel) return true;
    }
    else if (InpConfType == MACD && h_confInd1 != INVALID_HANDLE)
    {
        // MACD Crossover Confirmation
        // Check if Main crossed Signal in the direction of the trade
        double macdMainNow = confInd1_buf[0];
        double macdSignNow = confInd2_buf[0];
        double macdMainPrev= confInd1_buf[1];
        double macdSignPrev= confInd2_buf[1];

        bool macdBullCross = macdMainPrev < macdSignPrev && macdMainNow > macdSignNow;
        bool macdBearCross = macdMainPrev > macdSignPrev && macdMainNow < macdSignNow;

        if(isBuySignal && macdBullCross) return true;
        if(isSellSignal && macdBearCross) return true;

        // Alternative: Check level relative to zero line (optional)
        // if(isBuySignal && macdMainNow > 0 && macdSignNow > 0) return true;
        // if(isSellSignal && macdMainNow < 0 && macdSignNow < 0) return true;
    }

    return false; // Confirmation failed
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double lotSize = InpFixedLotSize; // Default to fixed

    if (InpLotSizeMode == Percent)
    {
        if (InpPercentRisk <= 0)
        {
           Print("Warning: Risk Percent is zero or negative, using minimum lot size.");
           return symbolInfo.LotsMin();
        }

        double riskAmount = accountInfo.Equity() * (InpPercentRisk / 100.0);
        double slPoints = 0; // Stop loss in points

        // --- Calculate required SL in points first ---
         double atrVal = (h_atr != INVALID_HANDLE && atr_buf[0] > 0) ? atr_buf[0] : 0;
         double tempSlPriceBuy = CalculateStopLoss(ORDER_TYPE_BUY, symbolInfo.Ask(), atrVal);
         double tempSlPriceSell = CalculateStopLoss(ORDER_TYPE_SELL, symbolInfo.Bid(), atrVal);

         // Estimate SL points based on potential BUY signal (Ask - SL) or SELL signal (SL - Bid)
         // We take the larger potential loss distance for a conservative calculation
         double slPointsBuy = (tempSlPriceBuy > 0) ? (symbolInfo.Ask() - tempSlPriceBuy) / symbolInfo.Point() : 0;
         double slPointsSell = (tempSlPriceSell > 0) ? (tempSlPriceSell - symbolInfo.Bid()) / symbolInfo.Point() : 0;

         // Use the specified SL method
         if(InpSLType == Points) {
             slPoints = InpStopLossPoints;
         } else if (InpSLType == ATR && atrVal > 0) {
             // Need to estimate which direction trade might go for Ask/Bid difference
             slPoints = MathMax(slPointsBuy, slPointsSell);
         }

         // Check for invalid SL distance
         if (slPoints <= 0) {
              Print("Error: Stop Loss calculation resulted in zero or negative points for lot sizing.");
              // Default to Min Lot? Or fail? Let's use Min Lot
              return symbolInfo.LotsMin();
         }

         // --- Calculate Lot Size ---
         double tickValue = symbolInfo.TickValue(); // Value of 1 tick for 1 standard lot
         double pointValue = tickValue / symbolInfo.TickSize() * symbolInfo.Point(); // Value of 1 point move for 1 lot

         if(pointValue <= 0 || slPoints <= 0) {
            Print("Error: Cannot calculate lot size due to zero tick/point value or SL points.");
            return symbolInfo.LotsMin();
         }

         double calculatedLots = riskAmount / (slPoints * pointValue);


         // --- Normalize and Apply Constraints ---
         lotSize = NormalizeDouble(calculatedLots, 2); // MT5 lots typically use 2 decimal places

         // Apply minimum and maximum lot size constraints
         lotSize = MathMax(lotSize, symbolInfo.LotsMin());
         lotSize = MathMin(lotSize, symbolInfo.LotsMax());

         // Apply lot step constraint
         double lotStep = symbolInfo.LotsStep();
         lotSize = MathFloor(lotSize / lotStep) * lotStep;

         // Final check for zero lot size after rounding/step adjustment
          if (lotSize < symbolInfo.LotsMin()) {
              lotSize = symbolInfo.LotsMin();
          }

         PrintFormat("Lot Calculation: Equity=%.2f, Risk=%.2f%%, RiskAmt=%.2f, SLPoints=%.1f, PointValue=%.5f, CalcLots=%.4f, FinalLots=%.2f",
             accountInfo.Equity(), InpPercentRisk, riskAmount, slPoints, pointValue, calculatedLots, lotSize);

    } else { // Fixed Lot Size
         // Ensure fixed lot adheres to symbol limits
         lotSize = MathMax(InpFixedLotSize, symbolInfo.LotsMin());
         lotSize = MathMin(lotSize, symbolInfo.LotsMax());
         double lotStep = symbolInfo.LotsStep();
         lotSize = MathFloor(lotSize / lotStep) * lotStep;
         if (lotSize < symbolInfo.LotsMin()) { // Ensure it's not rounded below min
            lotSize = symbolInfo.LotsMin();
          }
    }


    return lotSize;
}


//+------------------------------------------------------------------+
//| Calculate Stop Loss Price                                        |
//+------------------------------------------------------------------+
double CalculateStopLoss(ENUM_ORDER_TYPE orderType, double openPrice, double atrValue)
{
    double slPrice = 0;
    double slDistance = 0; // Distance from open price in price units

    // Calculate distance based on selected type
    if (InpSLType == Points && InpStopLossPoints > 0)
    {
       slDistance = InpStopLossPoints * symbolInfo.Point();
    }
    else if (InpSLType == ATR && atrValue > 0 && InpAtrSLMultiplier > 0)
    {
       slDistance = atrValue * InpAtrSLMultiplier;
    }
    else
    {
        Print("Cannot calculate SL distance (Invalid Points or ATR value/multiplier). SL will be 0.");
        return 0.0; // No SL
    }

     // --- Adjust SL distance based on minimum stop level ---
    double minStopDistance = (double)symbolInfo.Stoplevel() * symbolInfo.Point();
    slDistance = MathMax(slDistance, minStopDistance);


    // Calculate SL Price based on order type
    if (orderType == ORDER_TYPE_BUY)
    {
       slPrice = openPrice - slDistance;
    }
    else if (orderType == ORDER_TYPE_SELL)
    {
       slPrice = openPrice + slDistance;
    }

    return NormalizeDouble(slPrice, symbolInfo.Digits());
}

//+------------------------------------------------------------------+
//| Calculate Take Profit Price                                      |
//+------------------------------------------------------------------+
double CalculateTakeProfit(ENUM_ORDER_TYPE orderType, double openPrice, double stopLossPrice, double atrValue)
{
    double tpPrice = 0;
    double tpDistance = 0; // Distance from open price in price units

    // Calculate distance based on selected type
    if(InpTPType == Points && InpTakeProfitPoints > 0)
    {
        tpDistance = InpTakeProfitPoints * symbolInfo.Point();
    }
    else if (InpTPType == ATR && atrValue > 0 && InpAtrTPMultiplier > 0)
    {
         tpDistance = atrValue * InpAtrTPMultiplier;
    }
    else if (InpTPType == FixedRatio && stopLossPrice != 0 && InpTpRRFactor > 0)
    {
         double slDistance = MathAbs(openPrice - stopLossPrice);
         if(slDistance > 0)
         {
             tpDistance = slDistance * InpTpRRFactor;
         }
    }
    else
    {
        // Print("Cannot calculate TP distance. TP will be 0.");
        return 0.0; // No TP
    }

     // --- Adjust TP distance based on minimum stop level ---
     // TP must also be at least Stoplevel away from the current market price
    double minStopDistance = (double)symbolInfo.Stoplevel() * symbolInfo.Point();
    tpDistance = MathMax(tpDistance, minStopDistance);

    // Calculate TP Price based on order type
    if (orderType == ORDER_TYPE_BUY)
    {
       tpPrice = openPrice + tpDistance;
    }
    else if (orderType == ORDER_TYPE_SELL)
    {
       tpPrice = openPrice - tpDistance;
    }


    return NormalizeDouble(tpPrice, symbolInfo.Digits());
}

//+------------------------------------------------------------------+
//| Open Buy Order                                                   |
//+------------------------------------------------------------------+
bool OpenBuy(double lotSize, double sl, double tp)
{
    if (lotSize <= 0) return false;

    MqlTradeRequest request = {0};
    MqlTradeResult result = {0};

    request.action   = TRADE_ACTION_DEAL;
    request.symbol   = _Symbol;
    request.volume   = lotSize;
    request.type     = ORDER_TYPE_BUY;
    request.price    = symbolInfo.Ask(); // Market execution buy at Ask
    request.sl       = sl;
    request.tp       = tp;
    request.magic    = InpMagicNumber;
    request.deviation= trade.Deviation(); // Use CTrade's slippage setting
    request.type_filling = trade.TypeFilling();
    request.type_time = ORDER_TIME_GTC;
    request.comment = StringFormat("MA Cross Buy %d/%d",InpFastMAPeriod,InpSlowMAPeriod);

    // Adjust SL/TP to conform to StopLevel requirements AFTER initial calculation
    if (request.sl != 0 && MathAbs(request.price - request.sl) < symbolInfo.Stoplevel() * symbolInfo.Point())
    {
       Print("Adjusting Buy SL to meet StopLevel. Original SL: ", DoubleToString(request.sl, _Digits));
       request.sl = NormalizeDouble(request.price - symbolInfo.Stoplevel() * symbolInfo.Point() - _Point, _Digits) ; // Add an extra point just in case
       Print("Adjusted Buy SL: ", DoubleToString(request.sl, _Digits));
    }
    if (request.tp != 0 && MathAbs(request.tp - request.price) < symbolInfo.Stoplevel() * symbolInfo.Point())
    {
        Print("Adjusting Buy TP to meet StopLevel. Original TP: ", DoubleToString(request.tp, _Digits));
        request.tp = NormalizeDouble(request.price + symbolInfo.Stoplevel() * symbolInfo.Point() + _Point, _Digits);
         Print("Adjusted Buy TP: ", DoubleToString(request.tp, _Digits));
    }

    if (!CheckMoneyForTrade(_Symbol, lotSize, ORDER_TYPE_BUY))
    {
        Print("Not enough money to open BUY order: ", lotSize, " lots for ", _Symbol);
        return false;
    }

    PrintFormat("Attempting BUY: Lots=%.2f, Price=%.5f, SL=%.5f, TP=%.5f, Magic=%d",
               request.volume, request.price, request.sl, request.tp, request.magic);

    // Send the order
    if (!OrderSend(request, result))
    {
        PrintFormat("OrderSend error %d: %s", result.retcode, result.comment);
        return false;
    }

    if (result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL)
    {
        PrintFormat("BUY Order successful. Ticket: %d, Deal: %d, Price: %.5f", result.order, result.deal, result.price);
        return true;
    }
    else
    {
        PrintFormat("OrderSend failed. Retcode: %d (%s)", result.retcode, GetTradeRetcodeDescription(result.retcode));
        return false;
    }
}

//+------------------------------------------------------------------+
//| Open Sell Order                                                  |
//+------------------------------------------------------------------+
bool OpenSell(double lotSize, double sl, double tp)
{
     if (lotSize <= 0) return false;

    MqlTradeRequest request = {0};
    MqlTradeResult result = {0};

    request.action   = TRADE_ACTION_DEAL;
    request.symbol   = _Symbol;
    request.volume   = lotSize;
    request.type     = ORDER_TYPE_SELL;
    request.price    = symbolInfo.Bid(); // Market execution sell at Bid
    request.sl       = sl;
    request.tp       = tp;
    request.magic    = InpMagicNumber;
    request.deviation= trade.Deviation(); // Use CTrade's slippage setting
    request.type_filling = trade.TypeFilling();
    request.type_time = ORDER_TIME_GTC;
    request.comment = StringFormat("MA Cross Sell %d/%d",InpFastMAPeriod,InpSlowMAPeriod);

   // Adjust SL/TP to conform to StopLevel requirements AFTER initial calculation
   if (request.sl != 0 && MathAbs(request.sl - request.price) < symbolInfo.Stoplevel() * symbolInfo.Point())
   {
        Print("Adjusting Sell SL to meet StopLevel. Original SL: ", DoubleToString(request.sl, _Digits));
        request.sl = NormalizeDouble(request.price + symbolInfo.Stoplevel() * symbolInfo.Point() + _Point, _Digits) ;
         Print("Adjusted Sell SL: ", DoubleToString(request.sl, _Digits));
   }
   if (request.tp != 0 && MathAbs(request.price - request.tp) < symbolInfo.Stoplevel() * symbolInfo.Point())
   {
        Print("Adjusting Sell TP to meet StopLevel. Original TP: ", DoubleToString(request.tp, _Digits));
       request.tp = NormalizeDouble(request.price - symbolInfo.Stoplevel() * symbolInfo.Point() - _Point, _Digits) ;
        Print("Adjusted Sell TP: ", DoubleToString(request.tp, _Digits));
   }

   if (!CheckMoneyForTrade(_Symbol, lotSize, ORDER_TYPE_SELL))
    {
        Print("Not enough money to open SELL order: ", lotSize, " lots for ", _Symbol);
        return false;
    }

   PrintFormat("Attempting SELL: Lots=%.2f, Price=%.5f, SL=%.5f, TP=%.5f, Magic=%d",
              request.volume, request.price, request.sl, request.tp, request.magic);


    // Send the order
    if (!OrderSend(request, result))
    {
        PrintFormat("OrderSend error %d: %s", result.retcode, result.comment);
        return false;
    }

    if (result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL)
    {
        PrintFormat("SELL Order successful. Ticket: %d, Deal: %d, Price: %.5f", result.order, result.deal, result.price);
        return true;
    }
    else
    {
         PrintFormat("OrderSend failed. Retcode: %d (%s)", result.retcode, GetTradeRetcodeDescription(result.retcode));
        return false;
    }
}

//+------------------------------------------------------------------+
//| Close Specific Position                                          |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket, string comment = "Closed by EA")
{
    // Use CTrade class for easier closing
    if(trade.PositionClose(ticket, trade.Deviation())) {
         PrintFormat("Position %d closed successfully. Reason: %s", ticket, comment);
         // Logging closed trades is handled by OnTradeTransaction usually, but can log here too.
         // Example LogTrade for closure would need profit info. Better handled globally.
         return true;
    } else {
        PrintFormat("Error closing position %d: %d (%s)", ticket, trade.ResultRetcode(), GetTradeRetcodeDescription(trade.ResultRetcode()));
        return false;
    }
}

//+------------------------------------------------------------------+
//| Log Trade Details                                                |
//+------------------------------------------------------------------+
void LogTrade(string type, double lots, double price, double sl, double tp, string comment, double profit = 0.0)
{
   if (!InpEnableLogging || logFileHandle == INVALID_HANDLE || MQLInfoInteger(MQL_OPTIMIZATION))
      return; // Don't log if disabled, file not open, or optimizing

   datetime now = TimeCurrent();
   string timeStr = TimeToString(now, TIME_DATE | TIME_SECONDS);

   // Write data to the CSV file
   FileWrite(logFileHandle,
             timeStr,                       // Timestamp
             type,                          // Type (BUY, SELL, CLOSE)
             _Symbol,                       // Symbol
             DoubleToString(lots, 2),       // Lots
             DoubleToString(price, _Digits),// Price
             DoubleToString(sl, _Digits),   // SL
             DoubleToString(tp, _Digits),   // TP
             (profit != 0.0) ? DoubleToString(profit, 2) : "", // Result P/L (only for close logs)
             comment,                       // Comment
             (string)InpMagicNumber);       // Magic

    FileFlush(logFileHandle); // Ensure data is written immediately
}

//+------------------------------------------------------------------+
//| OnTradeTransaction Function (Capture closed trades for logging) |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
    // Only process relevant transaction types (deal added) for our magic number
    if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
    if(trans.magic != InpMagicNumber) return;

    // Check if the deal relates to closing a position
    if (trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
    {
        // More reliably, check if the reason is SL, TP or position closing
        if( HistoryDealSelect(trans.deal) )
        {
             long entry_type = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

             // DEAL_ENTRY_IN => Opening trade
             // DEAL_ENTRY_OUT => Closing due to SL/TP/Manual/EA Close command
             // DEAL_ENTRY_INOUT => Position reversal
             // DEAL_ENTRY_OUT_BY => Closing counterpart of a hedged position

             if (entry_type == DEAL_ENTRY_OUT || entry_type == DEAL_ENTRY_INOUT || entry_type == DEAL_ENTRY_OUT_BY )
             {
                double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
                double price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
                double volume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
                string dealType = (HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_BUY) ? "CLOSED_SELL" : "CLOSED_BUY"; // The deal type is opposite of original position
                long order_ticket = HistoryDealGetInteger(trans.deal, DEAL_ORDER); // To potentially link to original order details
                string reason = GetDealReasonString(HistoryDealGetInteger(trans.deal, DEAL_REASON)); // More descriptive reason

                // Log the closed trade details
                LogTrade(dealType,
                         volume,
                         price,
                         0, // SL not relevant on close deal record itself
                         0, // TP not relevant on close deal record itself
                         "Close (" + reason + ")",
                         profit);
             }
        }
    }
}

//+------------------------------------------------------------------+
//| Check if Trading is Allowed within specified Hours              |
//+------------------------------------------------------------------+
bool IsTradeAllowedTime()
{
    if(!InpUseTradingHours) return true; // If filter is off, always allowed

    datetime now = TimeCurrent();
    MqlDateTime timeStruct;
    TimeToStruct(now, timeStruct);

    int currentMinuteOfDay = timeStruct.hour * 60 + timeStruct.min;
    int startMinuteOfDay = InpStartHour * 60 + InpStartMinute;
    int endMinuteOfDay = InpEndHour * 60 + InpEndMinute;

    // Handle overnight sessions (e.g., Start 22:00, End 06:00)
    if (startMinuteOfDay > endMinuteOfDay)
    {
       // Allowed if current time >= start OR current time <= end
       if (currentMinuteOfDay >= startMinuteOfDay || currentMinuteOfDay <= endMinuteOfDay)
       {
           return true;
       }
    }
    else // Normal same-day session
    {
       if (currentMinuteOfDay >= startMinuteOfDay && currentMinuteOfDay <= endMinuteOfDay)
       {
           return true;
       }
    }

    return false; // Outside allowed hours
}


//+------------------------------------------------------------------+
//| Check if there is enough money for the trade                     |
//+------------------------------------------------------------------+
bool CheckMoneyForTrade(string symbol, double lots, ENUM_ORDER_TYPE order_type)
{
   double free_margin = accountInfo.MarginFree();
   double required_margin = 0;

   if(!symbolInfo.Name(symbol)) return false; // Ensure symbol context is right

   // Use OrderCalcMargin to check required margin
   if (!OrderCalcMargin(order_type, symbol, lots, symbolInfo.Ask(), required_margin)) // Use Ask for Buy margin check (worst case)
   {
        // Try with Bid for Sell
        if(!OrderCalcMargin(order_type, symbol, lots, symbolInfo.Bid(), required_margin))
        {
            Print("OrderCalcMargin failed. Error: ", GetLastError());
            return false; // Cannot calculate margin, assume insufficient funds
        }
   }


   if (required_margin > free_margin)
   {
      PrintFormat("Insufficient margin for trade. Required: %.2f, Available: %.2f", required_margin, free_margin);
      return false;
   }

   return true; // Enough margin
}

//+------------------------------------------------------------------+
//| Get Trade Retcode Description (Helper)                           |
//+------------------------------------------------------------------+
string GetTradeRetcodeDescription(int retcode)
{
  switch(retcode)
  {
   case TRADE_RETCODE_REQUOTE          : return "Requote";
   case TRADE_RETCODE_REJECT           : return "Reject";
   case TRADE_RETCODE_CANCEL           : return "Cancel";
   case TRADE_RETCODE_PLACED           : return "Placed";
   case TRADE_RETCODE_DONE             : return "Done";
   case TRADE_RETCODE_DONE_PARTIAL     : return "Done Partial";
   case TRADE_RETCODE_ERROR            : return "Error";
   case TRADE_RETCODE_TIMEOUT          : return "Timeout";
   case TRADE_RETCODE_INVALID          : return "Invalid Request";
   case TRADE_RETCODE_INVALID_VOLUME   : return "Invalid Volume";
   case TRADE_RETCODE_INVALID_PRICE    : return "Invalid Price";
   case TRADE_RETCODE_INVALID_STOPS    : return "Invalid Stops";
   case TRADE_RETCODE_TRADE_DISABLED   : return "Trade Disabled";
   case TRADE_RETCODE_MARKET_CLOSED    : return "Market Closed";
   case TRADE_RETCODE_NO_MONEY         : return "No Money";
   case TRADE_RETCODE_PRICE_CHANGED    : return "Price Changed";
   case TRADE_RETCODE_PRICE_OFF        : return "Price Off";
   case TRADE_RETCODE_INVALID_EXPIRATION: return "Invalid Expiration";
   case TRADE_RETCODE_ORDER_CHANGED    : return "Order Changed";
   case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Too Many Requests";
   case TRADE_RETCODE_NO_CONNECTION    : return "No Connection";
   case TRADE_RETCODE_ACCOUNT_DISABLED : return "Account Disabled";
   case TRADE_RETCODE_INVALID_ACCOUNT  : return "Invalid Account";
   // Add more codes as needed from MQL5 documentation
   default                             : return "Unknown Retcode " + (string)retcode;
  }
}

//+------------------------------------------------------------------+
//| Get Deal Reason Description (Helper)                             |
//+------------------------------------------------------------------+
string GetDealReasonString(ENUM_DEAL_REASON reason)
  {
   switch(reason)
     {
      case DEAL_REASON_CLIENT:         return("Client terminal");
      case DEAL_REASON_MOBILE:         return("Mobile terminal");
      case DEAL_REASON_WEB:            return("Web terminal");
      case DEAL_REASON_EXPERT:         return("Expert Advisor");
      case DEAL_REASON_SL:             return("Stop Loss activation");
      case DEAL_REASON_TP:             return("Take Profit activation");
      case DEAL_REASON_SO:             return("Stop Out");
      case DEAL_REASON_ROLLOVER:       return("Rollover");
      case DEAL_REASON_VMARGIN:        return("Variation margin");
      case DEAL_REASON_SPLIT:          return("Split");
      // Add any others if needed
      default: return("Unknown (" + (string)reason + ")");
     }
  }
//+------------------------------------------------------------------+