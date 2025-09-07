//+------------------------------------------------------------------+
//|                                         utbotea1_hlc_optimized.mq5 |
//|                                                   shikhar shivam |
//|                                     @artificialintelligencefacts |
//+------------------------------------------------------------------+
#property copyright "shikhar shivam"
#property link      "@artificialintelligencefacts"
#property version   "2.00"

// Include necessary libraries
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

// Input parameters - Trading parameters
input group "Risk Management"
input double   RiskPercent = 1.0;      // Risk per trade (% of balance)
input double   MinLotSize = 0.01;      // Minimum lot size
input double   MaxLotSize = 2.0;       // Maximum lot size
input bool     EnableBuy = true;       // Enable Buy Signals
input bool     EnableSell = true;      // Enable Sell Signals
input int      MaxPositions = 1;       // Maximum Open Positions
input bool     EnableStrictTimeFilter = false; // Enable Strict Trading Hours

input group "Stop Loss & Take Profit"
input double   StopLossPercent = 1.0;  // Stop Loss (% of ATR)
input double   TakeProfitPercent = 2.0;// Take Profit (% of ATR)
input bool     UseTrailingStop = true; // Use Trailing Stop
input bool     UseBreakEven = true;    // Use Break Even
input double   BreakEvenTrigger = 0.5; // Break Even Trigger (% of TP)
input double   BreakEvenProfit = 5;    // Break Even Profit (points)

input group "Trade Management"
input bool     CloseOnOppositeSignal = true; // Close on Opposite Signal
input bool     PartialClosing = false; // Enable Partial Closing
input double   PartialClosePercent = 50.0; // Partial Close Percentage
input double   PartialCloseTrigger = 1.0; // Partial Close Trigger (% of TP)

input group "Trading Hours Filter"
input int      StartHour = 0;          // Start Hour (0-23, server time)
input int      EndHour = 23;           // End Hour (0-23, server time)
input bool     MondayFilter = false;   // Filter Monday Trading
input bool     FridayFilter = false;   // Filter Friday Trading
input int      FridayEndHour = 12;     // Friday End Hour (0-23, server time)

input group "UT Bot Indicator Settings"
input double   UTBot_KeyValue = 3.0;   // UT Bot: Key Value (Sensitivity)
input int      UTBot_ATRPeriod = 14;   // UT Bot: ATR Period
input bool     UTBot_UseHeikinAshi = false; // UT Bot: Use Heikin Ashi Candles

input group "Signal Confirmation"
input bool     UseRSIFilter = false;   // Use RSI Filter
input int      RSIPeriod = 14;         // RSI Period
input int      RSIOverbought = 70;     // RSI Overbought Level
input int      RSIOversold = 30;       // RSI Oversold Level

input group "Expert Settings"
input int      MagicNumber = 123456;   // Magic Number
input bool     DetailedLogging = false;// Enable Detailed Logging
input double   MaxDailyLoss = 3.0;     // Max Daily Loss (% of balance)
input double   MaxWeeklyLoss = 7.0;    // Max Weekly Loss (% of balance)

// Global variables
CTrade         trade;                   // Trading object
CPositionInfo  positionInfo;            // Position information object
CAccountInfo   accountInfo;             // Account information object
int            utbotHandle;             // Handle for the UT Bot indicator
int            rsiHandle;               // Handle for the RSI indicator
double         buyBuffer[];             // Buffer for buy signals
double         sellBuffer[];            // Buffer for sell signals
double         atrTrailingStopBuffer[]; // Buffer for ATR Trailing Stop
double         rsiBuffer[];             // Buffer for RSI values
double         currentATR;              // Current ATR value
int            atrHandle;               // Handle for the ATR indicator
datetime       lastBarTime;             // Last processed bar time
bool           signalProcessed;         // Flag to prevent duplicate signals
double         startBalance;            // Starting balance for the day/week
datetime       startBalanceTime;        // Time when start balance was recorded
double         todayProfit;             // Today's running profit
double         weeklyProfit;            // Weekly running profit
bool           partiallyClosedPositions[];  // Array to track partially closed positions

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize trade object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10); // Set acceptable slippage
   trade.SetMarginMode();         // Set margin calculation mode
   trade.LogLevel(LOG_LEVEL_ERRORS); // Only log errors
   
   // Initialize the start balance
   startBalance = accountInfo.Balance();
   startBalanceTime = TimeCurrent();
   todayProfit = 0.0;
   weeklyProfit = 0.0;
   
   // Get UT Bot indicator handle with custom parameters
   utbotHandle = iCustom(_Symbol, PERIOD_CURRENT, "utbot", 
                        UTBot_KeyValue,      // Key Value (Sensitivity)
                        UTBot_ATRPeriod,     // ATR Period
                        UTBot_UseHeikinAshi  // Use Heikin Ashi Candles
                      );
                      
   if(utbotHandle == INVALID_HANDLE)
   {
      Print("Failed to create handle for the UT Bot indicator");
      return(INIT_FAILED);
   }
   
   // Get ATR indicator handle for stop loss and take profit calculations
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, UTBot_ATRPeriod);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator handle");
      return(INIT_FAILED);
   }
   
   // Initialize RSI handle if filter is enabled
   if(UseRSIFilter)
   {
      rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
      if(rsiHandle == INVALID_HANDLE)
      {
         Print("Failed to create RSI indicator handle");
         return(INIT_FAILED);
      }
   }
   
   // Allocate and initialize buffers
   ArraySetAsSeries(buyBuffer, true);
   ArraySetAsSeries(sellBuffer, true);
   ArraySetAsSeries(atrTrailingStopBuffer, true);
   ArraySetAsSeries(rsiBuffer, true);
   ArrayResize(partiallyClosedPositions, 0); // Will resize as needed
   
   // Initialize last bar time
   lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   signalProcessed = false;
   
   Print("UT Bot EA optimized version initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(utbotHandle != INVALID_HANDLE)
      IndicatorRelease(utbotHandle);
      
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
      
   if(UseRSIFilter && rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
      
   Print("UT Bot EA deinitialized, reason code: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if market is closed
   if(!IsMarketOpen())
      return;
      
   // Check if we've hit daily/weekly loss limits
   if(CheckDrawdownLimits())
      return;
   
   // Get current bar time
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   // Check for new bar - HLC processing basis
   bool isNewBar = (currentBarTime != lastBarTime);
   
   // Always manage existing positions regardless of new bar
   ManageExistingPositions(isNewBar);
   
   // If no new bar has formed, exit after managing positions
   if(!isNewBar)
      return;
   
   // Update last bar time since we have a new bar
   lastBarTime = currentBarTime;
   signalProcessed = false; // Reset signal processed flag for new bar
   
   // Process trading signals on the new bar
   ProcessTradingSignals();
}

//+------------------------------------------------------------------+
//| Process trading signals                                          |
//+------------------------------------------------------------------+
void ProcessTradingSignals()
{
   // Skip if signals already processed for this bar
   if(signalProcessed)
      return;
   
   // Copy indicator buffers
   if(CopyBuffer(utbotHandle, 1, 0, 3, buyBuffer) <= 0 ||
      CopyBuffer(utbotHandle, 2, 0, 3, sellBuffer) <= 0 ||
      CopyBuffer(utbotHandle, 0, 0, 3, atrTrailingStopBuffer) <= 0)
   {
      Print("Error copying indicator buffers");
      return;
   }
   
   // Copy ATR values for stop loss and take profit
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrValues) <= 0)
   {
      Print("Error copying ATR buffer");
      return;
   }
   currentATR = atrValues[0];
   
   // Check RSI if filter is enabled
   bool rsiConfirms = true; // Default if filter not used
   if(UseRSIFilter)
   {
      if(CopyBuffer(rsiHandle, 0, 0, 1, rsiBuffer) <= 0)
      {
         Print("Error copying RSI buffer");
         return;
      }
      
      // RSI is neutral by default, confirms both Buy and Sell unless extremes
      double currentRSI = rsiBuffer[0];
      if(currentRSI > RSIOverbought)
         rsiConfirms = false; // Don't allow buys when overbought
      else if(currentRSI < RSIOversold)
         rsiConfirms = false; // Don't allow sells when oversold
   }
   
   // Process trade signals based on completed bar data
   bool hasBuySignal = (buyBuffer[1] > 0);   // Signal from the previous completed bar
   bool hasSellSignal = (sellBuffer[1] > 0); // Signal from the previous completed bar
   
   // Count current positions
   int totalPositions = CountPositions();
   
   // Apply trading hour filter if enabled
   if(EnableStrictTimeFilter && !IsValidTradingHour())
   {
      if(DetailedLogging) 
         Print("Trading hour filter active - no new positions will be opened");
      return;
   }
   
   // Check for opposite signals to close positions
   if(CloseOnOppositeSignal)
   {
      if(hasBuySignal && IsPositionOpen(POSITION_TYPE_SELL))
         CloseAllPositions(POSITION_TYPE_SELL);
         
      if(hasSellSignal && IsPositionOpen(POSITION_TYPE_BUY))
         CloseAllPositions(POSITION_TYPE_BUY);
   }
   
   // Check if we can open new positions
   if(totalPositions < MaxPositions)
   {
      // Check for buy signal
      if(EnableBuy && hasBuySignal && !IsPositionOpen(POSITION_TYPE_BUY) && 
         (!UseRSIFilter || rsiBuffer[0] < RSIOverbought))
      {
         OpenBuyPosition();
      }
      
      // Check for sell signal
      if(EnableSell && hasSellSignal && !IsPositionOpen(POSITION_TYPE_SELL) && 
         (!UseRSIFilter || rsiBuffer[0] > RSIOversold))
      {
         OpenSellPosition();
      }
   }
   
   signalProcessed = true;
}

//+------------------------------------------------------------------+
//| Manage existing positions (trailing stop, break even, etc.)      |
//+------------------------------------------------------------------+
void ManageExistingPositions(bool isNewBar)
{
   // Skip position management if no positions
   if(PositionsTotal() == 0)
      return;
      
   // Check trailing stops on existing positions
   if(UseTrailingStop)
   {
      // Copy trailing stop buffer if needed
      if(CopyBuffer(utbotHandle, 0, 0, 1, atrTrailingStopBuffer) <= 0)
      {
         Print("Error copying trailing stop buffer");
         return;
      }
      
      ManageTrailingStop();
   }
   
   // Process break even and partial closing
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || PositionGetInteger(POSITION_MAGIC) != MagicNumber || 
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double takeProfit = PositionGetDouble(POSITION_TP);
      double stopLoss = PositionGetDouble(POSITION_SL);
      double profit = PositionGetDouble(POSITION_PROFIT);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Check if position needs to be set to break even
      if(UseBreakEven && stopLoss != openPrice)
      {
         double tpDistance = MathAbs(takeProfit - openPrice);
         double breakEvenTriggerDistance = tpDistance * BreakEvenTrigger / 100.0;
         
         bool shouldSetBreakEven = false;
         if(posType == POSITION_TYPE_BUY && currentPrice >= openPrice + breakEvenTriggerDistance)
            shouldSetBreakEven = true;
         else if(posType == POSITION_TYPE_SELL && currentPrice <= openPrice - breakEvenTriggerDistance)
            shouldSetBreakEven = true;
            
         if(shouldSetBreakEven)
         {
            // Calculate the new stop loss at break even plus profit buffer
            double newStopLoss = openPrice;
            if(posType == POSITION_TYPE_BUY)
               newStopLoss += BreakEvenProfit * _Point;
            else if(posType == POSITION_TYPE_SELL)
               newStopLoss -= BreakEvenProfit * _Point;
               
            newStopLoss = NormalizeDouble(newStopLoss, _Digits);
            
            // Only modify if the new stop loss is better than current
            if((posType == POSITION_TYPE_BUY && newStopLoss > stopLoss) ||
               (posType == POSITION_TYPE_SELL && (stopLoss == 0 || newStopLoss < stopLoss)))
            {
               trade.PositionModify(ticket, newStopLoss, takeProfit);
               if(DetailedLogging)
                  Print("Position #", ticket, " moved to break even at ", newStopLoss);
            }
         }
      }
      
      // Process partial closing if enabled
      if(PartialClosing && isNewBar)
      {
         // Check if this position has already been partially closed
         bool alreadyPartiallyClosed = false;
         for(int j = 0; j < ArraySize(partiallyClosedPositions); j++)
         {
            if(partiallyClosedPositions[j] == ticket)
            {
               alreadyPartiallyClosed = true;
               break;
            }
         }
         
         if(!alreadyPartiallyClosed)
         {
            double tpDistance = MathAbs(takeProfit - openPrice);
            double partialTriggerDistance = tpDistance * PartialCloseTrigger / 100.0;
            
            bool shouldPartiallyClose = false;
            if(posType == POSITION_TYPE_BUY && currentPrice >= openPrice + partialTriggerDistance)
               shouldPartiallyClose = true;
            else if(posType == POSITION_TYPE_SELL && currentPrice <= openPrice - partialTriggerDistance)
               shouldPartiallyClose = true;
               
            if(shouldPartiallyClose)
            {
               // Calculate volume to close
               double volume = PositionGetDouble(POSITION_VOLUME);
               double volumeToClose = volume * PartialClosePercent / 100.0;
               volumeToClose = NormalizeDouble(volumeToClose, 2); // Adjust to broker's lot size precision
               
               // Ensure minimum lot size
               if(volumeToClose >= MinLotSize && volumeToClose < volume)
               {
                  if(trade.PositionClosePartial(ticket, volumeToClose))
                  {
                     // Record position as partially closed
                     int size = ArraySize(partiallyClosedPositions);
                     ArrayResize(partiallyClosedPositions, size + 1);
                     partiallyClosedPositions[size] = ticket;
                     
                     if(DetailedLogging)
                        Print("Partially closed position #", ticket, " - ", volumeToClose, " lots of ", volume);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check drawdown limits                                           |
//+------------------------------------------------------------------+
bool CheckDrawdownLimits()
{
   // Get current time and balance
   datetime currentTime = TimeCurrent();
   double currentBalance = accountInfo.Balance();
   
   // Initialize start balance time if not set
   if(startBalanceTime == 0)
   {
      startBalanceTime = currentTime;
      startBalance = currentBalance;
      return false;
   }
   
   // Check if we need to reset daily/weekly tracking
   MqlDateTime timeStruct, startTimeStruct;
   TimeToStruct(currentTime, timeStruct);
   TimeToStruct(startBalanceTime, startTimeStruct);
   
   // Reset daily tracking if day has changed
   if(timeStruct.day != startTimeStruct.day || 
      timeStruct.mon != startTimeStruct.mon ||
      timeStruct.year != startTimeStruct.year)
   {
      startBalance = currentBalance;
      startBalanceTime = currentTime;
      todayProfit = 0.0;
      
      // Also reset weekly tracking if week has changed
      if(timeStruct.day_of_week < startTimeStruct.day_of_week)
         weeklyProfit = 0.0;
         
      return false;
   }
   
   // Calculate current profit/loss
   double currentProfit = currentBalance - startBalance;
   double profitPercent = (currentProfit / startBalance) * 100.0;
   
   // Update today's profit
   todayProfit = profitPercent;
   
   // Update weekly profit (accumulate daily)
   if(timeStruct.day != startTimeStruct.day)
      weeklyProfit += todayProfit;
   
   // Check daily loss limit
   if(profitPercent < -MaxDailyLoss)
   {
      if(CountPositions() > 0)
      {
         Print("Daily maximum loss of ", MaxDailyLoss, "% reached (", profitPercent, "%). Closing all positions.");
         CloseAllPositions(-1); // Close all positions
      }
      return true;
   }
   
   // Check weekly loss limit
   if(weeklyProfit < -MaxWeeklyLoss)
   {
      if(CountPositions() > 0)
      {
         Print("Weekly maximum loss of ", MaxWeeklyLoss, "% reached (", weeklyProfit, "%). Closing all positions.");
         CloseAllPositions(-1); // Close all positions
      }
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Open a buy position with dynamic lot sizing                     |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopLoss = 0;
   double takeProfit = 0;
   
   // Calculate stop loss and take profit
   if(StopLossPercent > 0)
      stopLoss = NormalizeDouble(ask - (currentATR * StopLossPercent), _Digits);
      
   if(TakeProfitPercent > 0)
      takeProfit = NormalizeDouble(ask + (currentATR * TakeProfitPercent), _Digits);
   
   // Calculate lot size based on risk percentage
   double lotSize = CalculateLotSize(POSITION_TYPE_BUY, ask, stopLoss);
   
   // Open buy position
   if(!trade.Buy(
      lotSize,
      _Symbol,
      ask,
      stopLoss,
      takeProfit,
      "UT Bot Buy Signal"
   ))
   {
      Print("Error opening buy position: ", GetLastError());
   }
   else
   {
      if(DetailedLogging)
         Print("Buy position opened at price ", ask, 
               ", SL: ", stopLoss, 
               ", TP: ", takeProfit, 
               ", Lot Size: ", lotSize);
   }
}

//+------------------------------------------------------------------+
//| Open a sell position with dynamic lot sizing                    |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopLoss = 0;
   double takeProfit = 0;
   
   // Calculate stop loss and take profit
   if(StopLossPercent > 0)
      stopLoss = NormalizeDouble(bid + (currentATR * StopLossPercent), _Digits);
      
   if(TakeProfitPercent > 0)
      takeProfit = NormalizeDouble(bid - (currentATR * TakeProfitPercent), _Digits);
   
   // Calculate lot size based on risk percentage
   double lotSize = CalculateLotSize(POSITION_TYPE_SELL, bid, stopLoss);
   
   // Open sell position
   if(!trade.Sell(
      lotSize,
      _Symbol,
      bid,
      stopLoss,
      takeProfit,
      "UT Bot Sell Signal"
   ))
   {
      Print("Error opening sell position: ", GetLastError());
   }
   else
   {
      if(DetailedLogging)
         Print("Sell position opened at price ", bid, 
               ", SL: ", stopLoss, 
               ", TP: ", takeProfit, 
               ", Lot Size: ", lotSize);
   }
}

//+------------------------------------------------------------------+
//| Calculate optimal lot size based on risk percentage             |
//+------------------------------------------------------------------+
double CalculateLotSize(ENUM_POSITION_TYPE posType, double entryPrice, double stopLoss)
{
   if(stopLoss == 0) // If no stop loss, use fixed lot size
      return MinLotSize;
   
   double riskAmount = accountInfo.Balance() * (RiskPercent / 100.0);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double pointValue = tickValue / tickSize;
   
   double slDistance = MathAbs(entryPrice - stopLoss);
   double slPoints = slDistance / _Point;
   
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double lotSize = NormalizeDouble(riskAmount / (slPoints * pointValue), 2);
   
   // Round to the nearest lot step
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   // Ensure lot size is within limits
   lotSize = MathMax(lotSize, MinLotSize);
   lotSize = MathMin(lotSize, MaxLotSize);
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Count open positions                                            |
//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
         PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check if a specific position type is open                        |
//+------------------------------------------------------------------+
bool IsPositionOpen(ENUM_POSITION_TYPE posType)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_TYPE) == posType)
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Close all positions of a specific type or all positions         |
//+------------------------------------------------------------------+
void CloseAllPositions(int posType = -1) // -1 means close all positions
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
         PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         // If position type is specified, only close that type
         if(posType != -1 && 
            PositionGetInteger(POSITION_TYPE) != posType)
            continue;
            
         trade.PositionClose(ticket);
         
         if(DetailedLogging)
            Print("Closed position #", ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage trailing stops for open positions                        |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   // Cache the trailing stop value to avoid repetitive buffer access
   double currentTrailingStop = atrTrailingStopBuffer[0];
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
         PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double currentStopLoss = PositionGetDouble(POSITION_SL);
         double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         
         // For buy positions
         if(posType == POSITION_TYPE_BUY)
         {
            // Normalize the stop loss value with proper precision
            double newStopLoss = NormalizeDouble(currentTrailingStop, _Digits);
            
            // Only modify if there's a significant difference and better than current
            if(newStopLoss > currentStopLoss + 10*_Point && newStopLoss < SymbolInfoDouble(_Symbol, SYMBOL_BID))
            {
               trade.PositionModify(
                  ticket,
                  newStopLoss,
                  PositionGetDouble(POSITION_TP)
               );
               
               if(DetailedLogging)
                  Print("Trailing stop updated for position #", ticket, " to ", newStopLoss);
            }
         }
         // For sell positions
         else if(posType == POSITION_TYPE_SELL)
         {
            // Normalize the stop loss value with proper precision
            double newStopLoss = NormalizeDouble(currentTrailingStop, _Digits);
            
            // Only modify if there's a significant difference and better than current
            if((currentStopLoss == 0 || newStopLoss < currentStopLoss - 10*_Point) && 
               newStopLoss > SymbolInfoDouble(_Symbol, SYMBOL_ASK))
            {
               trade.PositionModify(
                  ticket,
                  newStopLoss,
                  PositionGetDouble(POSITION_TP)
               );
               
               if(DetailedLogging)
                  Print("Trailing stop updated for position #", ticket, " to ", newStopLoss);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if it's a valid trading hour                              |
//+------------------------------------------------------------------+
bool IsValidTradingHour()
{
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   
   // Apply day of week filters
   if(MondayFilter && now.day_of_week == 1)
      return false;
      
   // Special handling for Friday
   if(FridayFilter && now.day_of_week == 5)
   {
      if(now.hour >= FridayEndHour)
         return false;
   }
   
   // Check trading hours
   if(StartHour <= EndHour)
   {
      // Simple case: StartHour to EndHour in the same day
      return (now.hour >= StartHour && now.hour < EndHour);
   }
   else
   {
      // Complex case: Trading session spans midnight
      return (now.hour >= StartHour || now.hour < EndHour);
   }
}

//+------------------------------------------------------------------+
//| Check if the market is open                                     |
//+------------------------------------------------------------------+
bool IsMarketOpen()
{
   // This is a simple check that ignores holidays
   // For production, consider a more comprehensive check
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   
   // Check if it's the weekend
   if(now.day_of_week == 0 || now.day_of_week == 6)
      return false;
      
   return true;
}
//+------------------------------------------------------------------+