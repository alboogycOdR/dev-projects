//+------------------------------------------------------------------+
//|                                                utbotea1_hlc.mq5 |
//|                                                   shikhar shivam |
//|                                     @artificialintelligencefacts |
//+------------------------------------------------------------------+
#property copyright "shikhar shivam"
#property link      "@artificialintelligencefacts"
#property version   "1.00"

// Include necessary libraries
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

// Input parameters - Trading parameters
input double   LotSize = 0.2;         // Lot Size
input bool     EnableBuy = true;       // Enable Buy Signals
input bool     EnableSell = true;      // Enable Sell Signals
input int      MaxPositions = 1;       // Maximum Open Positions
input double   StopLossPercent = 1.0;  // Stop Loss (% of ATR)
input double   TakeProfitPercent = 2.0;// Take Profit (% of ATR)
input bool     UseTrailingStop = true; // Use Trailing Stop
input int      MagicNumber = 123456;   // Magic Number
input bool     CloseOnOppositeSignal = true; // Close on Opposite Signal

// Input parameters - UT Bot Indicator parameters
input double   UTBot_KeyValue = 3.0;   // UT Bot: Key Value (Sensitivity)
input int      UTBot_ATRPeriod = 14;   // UT Bot: ATR Period
input bool     UTBot_UseHeikinAshi = false; // UT Bot: Use Heikin Ashi Candles

// Global variables
CTrade         trade;                   // Trading object
CPositionInfo  positionInfo;            // Position information object
int            utbotHandle;             // Handle for the UT Bot indicator
double         buyBuffer[];             // Buffer for buy signals
double         sellBuffer[];            // Buffer for sell signals
double         atrTrailingStopBuffer[]; // Buffer for ATR Trailing Stop
double         currentATR;              // Current ATR value
int            atrHandle;               // Handle for the ATR indicator
datetime       lastBarTime;             // Last processed bar time

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize trade object
   trade.SetExpertMagicNumber(MagicNumber);
   
   // Get UT Bot indicator handle with custom parameters
   utbotHandle = iCustom(_Symbol, PERIOD_CURRENT, "utbot", 
                        UTBot_KeyValue,      // Key Value (Sensitivity)
                        UTBot_ATRPeriod,     // ATR Period
                        UTBot_UseHeikinAshi  // Use Heikin Ashi Candles
                      );
                      
   if(utbotHandle == INVALID_HANDLE)
   {
      Print("Failed to create handle for the UT Bot indicator with parameters: ",
            "KeyValue=", UTBot_KeyValue, 
            ", ATRPeriod=", UTBot_ATRPeriod, 
            ", UseHeikinAshi=", UTBot_UseHeikinAshi);
      return(INIT_FAILED);
   }
   
   // Get ATR indicator handle for stop loss and take profit calculations
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, UTBot_ATRPeriod);  // Use same ATR period as UTBot
   if(atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator handle");
      return(INIT_FAILED);
   }
   
   // Allocate buffers
   ArraySetAsSeries(buyBuffer, true);
   ArraySetAsSeries(sellBuffer, true);
   ArraySetAsSeries(atrTrailingStopBuffer, true);
   
   // Initialize last bar time
   lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   Print("UT Bot EA initialized successfully with KeyValue=", UTBot_KeyValue, 
         ", ATRPeriod=", UTBot_ATRPeriod, 
         ", UseHeikinAshi=", UTBot_UseHeikinAshi);
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
      
   Print("UT Bot EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if market is closed
   if(!IsMarketOpen())
      return;
   
   // Get current bar time
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   // Check for new bar - this is the key change to HLC basis
   // Only process when a new bar/candle has formed
   bool isNewBar = (currentBarTime != lastBarTime);
   
   // If no new bar has formed, only check trailing stops if needed
   if(!isNewBar)
   {
      // For HLC basis, we still want to manage trailing stops on ticks
      // to capture price movements within the current bar
      if(UseTrailingStop)
      {
         if(CopyBuffer(utbotHandle, 0, 0, 1, atrTrailingStopBuffer) > 0)
         {
            ManageTrailingStop();
         }
      }
      return;  // Exit if no new bar
   }
   
   // Update last bar time since we have a new bar
   lastBarTime = currentBarTime;
   
   // Copy indicator buffers using HLC data
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
   
   // Process trade signals based on completed bar data
   bool hasBuySignal = (buyBuffer[1] > 0);   // Signal from the previous completed bar (index 1)
   bool hasSellSignal = (sellBuffer[1] > 0); // Signal from the previous completed bar (index 1)
   
   // Count current positions
   int totalPositions = CountPositions();
      
   // Check for opposite signals to close positions
   if(CloseOnOppositeSignal)
   {
      if(hasBuySignal && IsPositionOpen(POSITION_TYPE_SELL))
         CloseAllPositions(POSITION_TYPE_SELL);
         
      if(hasSellSignal && IsPositionOpen(POSITION_TYPE_BUY))
         CloseAllPositions(POSITION_TYPE_BUY);
   }
   
   // Check for trailing stops on existing positions
   if(UseTrailingStop)
      ManageTrailingStop();
   
   // Check if we can open new positions
   if(totalPositions < MaxPositions)
   {
      // Check for buy signal
      if(EnableBuy && hasBuySignal && !IsPositionOpen(POSITION_TYPE_BUY))
      {
         OpenBuyPosition();
      }
      
      // Check for sell signal
      if(EnableSell && hasSellSignal && !IsPositionOpen(POSITION_TYPE_SELL))
      {
         OpenSellPosition();
      }
   }
}

//+------------------------------------------------------------------+
//| Open a buy position                                             |
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
      
   // Open buy position
   if(!trade.Buy(
      LotSize,
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
      Print("Buy position opened at price ", ask, 
            ", SL: ", stopLoss, 
            ", TP: ", takeProfit);
   }
}

//+------------------------------------------------------------------+
//| Open a sell position                                            |
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
      
   // Open sell position
   if(!trade.Sell(
      LotSize,
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
      Print("Sell position opened at price ", bid, 
            ", SL: ", stopLoss, 
            ", TP: ", takeProfit);
   }
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
//| Close all positions of a specific type                          |
//+------------------------------------------------------------------+
void CloseAllPositions(ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_TYPE) == posType)
      {
         trade.PositionClose(ticket);
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
            
            // Only modify if there's a significant difference (to reduce unnecessary modifications)
            if(newStopLoss > currentStopLoss + 10*_Point && newStopLoss < positionOpenPrice)
            {
               trade.PositionModify(
                  ticket,
                  newStopLoss,
                  PositionGetDouble(POSITION_TP)
               );
            }
         }
         // For sell positions
         else if(posType == POSITION_TYPE_SELL)
         {
            // Normalize the stop loss value with proper precision
            double newStopLoss = NormalizeDouble(currentTrailingStop, _Digits);
            
            // Only modify if there's a significant difference and the new SL is higher than open price
            if((currentStopLoss == 0 || newStopLoss < currentStopLoss - 10*_Point) && newStopLoss > positionOpenPrice)
            {
               trade.PositionModify(
                  ticket,
                  newStopLoss,
                  PositionGetDouble(POSITION_TP)
               );
            }
         }
      }
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