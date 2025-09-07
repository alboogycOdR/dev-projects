//+------------------------------------------------------------------+
//| Expert Advisor: PivotBasketTrader                                |
//| Description: Pivot-based trading with basket management          |
//+------------------------------------------------------------------+
//https://www.mql5.com/en/job/234791/discussion?id=1149586
//https://grok.com/chat/a7842dd3-01a9-4c47-9040-8b24527e1088


//https://www.notion.so/Job-1c349e541670805fa34bf73ece7af2f1?pvs=4
//NOTION SPEC


#property copyright "Your Name"
#property link      "https://yourwebsite.com"
#property version   "1.00"
#include <Trade/Trade.mqh>
CTrade trade;
//--- Input Parameters
input int PivotPeriod = 5;              // Number of candles before/after for pivot confirmation
input bool UseAlternativePivot = false; // Use alternative pivot method
input int AlternativePivotPeriod = 3;   // Alternative pivot period
input bool UseHighToHighOscillator = false; // Use high-to-high for oscillator
input double InitialLotSize = 0.1;      // Initial trade volume
input double VolumePercentage = 25.0;   // Percentage of basket volume for scaling trades
input int MaxTrades = 5;                // Maximum number of trades in basket
input int ATRPeriod = 250;              // ATR period
input int EMAPeriod = 250;              // EMA smoothing period for ATR
 datetime ExpiryDate = D'2025.03.29 00:00'; // Expiry date and time for the EA

//--- Global Variables
double pivotHighs[], pivotLows[];
double atrSmoothed;
int basketTicket[];                     // Array to store ticket numbers of basket trades
double basketEntryPrices[];             // Array to store entry prices
double basketVolumes[];                 // Array to store trade volumes
double profitTarget;                    // Current profit target for the basket

//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   ArraySetAsSeries(pivotHighs, true);
   ArraySetAsSeries(pivotLows, true);
   ArrayResize(basketTicket, MaxTrades);
   ArrayResize(basketEntryPrices, MaxTrades);
   ArrayResize(basketVolumes, MaxTrades);
   ArrayInitialize(basketTicket, -1);   // -1 indicates no trade
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if the EA has expired
   if(TimeCurrent() >= ExpiryDate)
   {
      Print("EA has expired. Closing all positions and pending orders.");
      CloseAllPositionsAndOrders();
      ExpertRemove();
      return; // Stop further execution
   }
   
   CalculatePivots();
   CalculateATRSmoothed();
   ManageBasket();
   PlaceInitialTrade();
   PlaceScalingTrades();
}

//+------------------------------------------------------------------+
//| Close All Positions and Pending Orders                           |
//+------------------------------------------------------------------+
void CloseAllPositionsAndOrders()
{
   CTrade trade;
   
   // Close all open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
         trade.PositionClose(PositionGetTicket(i));
   }
   
   // Delete all pending orders
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(OrderGetTicket(i)))
         trade.OrderDelete(OrderGetTicket(i));
   }
}

//+------------------------------------------------------------------+
//| Calculate Pivot Points                                           |
//+------------------------------------------------------------------+
void CalculatePivots()
{
   int bars = Bars(_Symbol, PERIOD_M15);
   ArrayResize(pivotHighs, bars);
   ArrayResize(pivotLows, bars);
   ArrayInitialize(pivotHighs, 0);
   ArrayInitialize(pivotLows, 0);
   
   int period = UseAlternativePivot ? AlternativePivotPeriod : PivotPeriod;
   
   for(int i = period; i < bars - period; i++)
   {
      double high = iHigh(_Symbol, PERIOD_M15, i);
      double low = iLow(_Symbol, PERIOD_M15, i);
      bool isPivotHigh = true, isPivotLow = true;
      
      for(int j = 1; j <= period; j++)
      {
         if(iHigh(_Symbol, PERIOD_M15, i - j) >= high || iHigh(_Symbol, PERIOD_M15, i + j) >= high)
            isPivotHigh = false;
         if(iLow(_Symbol, PERIOD_M15, i - j) <= low || iLow(_Symbol, PERIOD_M15, i + j) <= low)
            isPivotLow = false;
      }
      
      if(isPivotHigh) pivotHighs[i] = high;
      if(isPivotLow) pivotLows[i] = low;
   }
}

//+------------------------------------------------------------------+
//| Calculate Smoothed ATR                                           |
//+------------------------------------------------------------------+
void CalculateATRSmoothed()
{
   double atr[];
   ArraySetAsSeries(atr, true);
   ArrayResize(atr, ATRPeriod);
   CopyBuffer(iATR(_Symbol, PERIOD_M15, ATRPeriod), 0, 0, ATRPeriod, atr);
   atrSmoothed = atr[0]; // Latest ATR value
}

//+------------------------------------------------------------------+
//| Calculate Pivot Oscillator                                       |
//+------------------------------------------------------------------+
double CalculatePivotOscillator()
{
   double distances[];
   int count = 0;
   ArrayResize(distances, Bars(_Symbol, PERIOD_M15));
   
   for(int i = PivotPeriod; i < Bars(_Symbol, PERIOD_M15) - PivotPeriod - 1; i++)
   {
      if(UseHighToHighOscillator)
      {
         if(pivotHighs[i] > 0 && pivotHighs[i + 1] > 0)
         {
            distances[count] = MathAbs(pivotHighs[i] - pivotHighs[i + 1]);
            count++;
         }
      }
      else
      {
         if(pivotHighs[i] > 0 && pivotLows[i + 1] > 0)
         {
            distances[count] = MathAbs(pivotHighs[i] - pivotLows[i + 1]);
            count++;
         }
         else if(pivotLows[i] > 0 && pivotHighs[i + 1] > 0)
         {
            distances[count] = MathAbs(pivotLows[i] - pivotHighs[i + 1]);
            count++;
         }
      }
   }
   
   if(count == 0) return 0;
   double sum = 0;
   for(int i = 0; i < count; i++) sum += distances[i];
   return sum / count;
}

//+------------------------------------------------------------------+
//| Place Initial Trade                                              |
//+------------------------------------------------------------------+
void PlaceInitialTrade()
{
   if(CountBasketTrades() > 0) return;
   
   double latestPivotHigh = GetLatestPivotHigh();
   double latestPivotLow = GetLatestPivotLow();
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(latestPivotLow > 0 && price > latestPivotLow)
   {
      double entryPrice = latestPivotLow + atrSmoothed * 0.1;
      PlaceLimitOrder(ORDER_TYPE_BUY, entryPrice, InitialLotSize);
   }
   else if(latestPivotHigh > 0 && price < latestPivotHigh)
   {
      double entryPrice = latestPivotHigh + atrSmoothed * 0.1;
      PlaceLimitOrder(ORDER_TYPE_SELL, entryPrice, InitialLotSize);
   }
}

//+------------------------------------------------------------------+
//| Place Scaling Trades                                             |
//+------------------------------------------------------------------+
void PlaceScalingTrades()
{
   int tradeCount = CountBasketTrades();
   if(tradeCount >= MaxTrades || tradeCount == 0) return;
   
   double lastEntry = basketEntryPrices[tradeCount - 1];
   double distance = CalculatePivotOscillator();
   double basketVolume = CalculateBasketVolume();
   double newVolume = InitialLotSize;
   
   if(PositionSelectByTicket(basketTicket[0]) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      double newEntry = lastEntry - distance;
      PlaceLimitOrder(ORDER_TYPE_BUY, newEntry, newVolume);
   }
   else
   {
      double newEntry = lastEntry + distance;
      PlaceLimitOrder(ORDER_TYPE_SELL, newEntry, newVolume);
   }
   
   RecalculateProfitTarget();
}

//+------------------------------------------------------------------+
//| Place Limit Order                                                |
//+------------------------------------------------------------------+
void PlaceLimitOrder(int type, double price, double volume)
{
   CTrade trade;
   
   if(type == ORDER_TYPE_BUY)
      trade.BuyLimit(volume, price, _Symbol);
   else
      trade.SellLimit(volume, price, _Symbol);
   
   if(trade.ResultRetcode() == TRADE_RETCODE_DONE)
   {
      int index = CountBasketTrades();
      basketTicket[index] = trade.ResultOrder();
      basketEntryPrices[index] = price;
      basketVolumes[index] = volume;
   }
}

//+------------------------------------------------------------------+
//| Manage Basket                                                    |
//+------------------------------------------------------------------+
void ManageBasket()
{
   int tradeCount = CountBasketTrades();
   if(tradeCount >= MaxTrades)
   {
      CloseBasket();
      return;
   }
   
   double totalProfit = CalculateBasketProfit();
   if(totalProfit >= profitTarget && profitTarget > 0)
      CloseBasket();
}

//+------------------------------------------------------------------+
//| Recalculate Profit Target                                        |
//+------------------------------------------------------------------+
void RecalculateProfitTarget()
{
   int tradeCount = CountBasketTrades();
   if(tradeCount == 0) return;
   
   double pivotLevel = (PositionSelectByTicket(basketTicket[0]) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? GetLatestPivotLow() : GetLatestPivotHigh();
   double lastEntry = basketEntryPrices[tradeCount - 1];
   profitTarget = pivotLevel + (lastEntry - pivotLevel) * 0.5; // 50% retracement
}

//+------------------------------------------------------------------+
//| Close Basket                                                     |
//+------------------------------------------------------------------+
void CloseBasket()
{
   CTrade trade;
   for(int i = 0; i < MaxTrades; i++)
   {
      if(basketTicket[i] != -1 && PositionSelectByTicket(basketTicket[i]))
         trade.PositionClose(basketTicket[i]);
      basketTicket[i] = -1;
   }
}

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
int CountBasketTrades()
{
   int count = 0;
   for(int i = 0; i < MaxTrades; i++)
      if(basketTicket[i] != -1) count++;
   return count;
}

double CalculateBasketVolume()
{
   double total = 0;
   for(int i = 0; i < MaxTrades; i++)
      if(basketVolumes[i] > 0) total += basketVolumes[i];
   return total;
}

double CalculateBasketProfit()
{
   double profit = 0;
   for(int i = 0; i < MaxTrades; i++)
      if(PositionSelectByTicket(basketTicket[i]))
         profit += PositionGetDouble(POSITION_PROFIT);
   return profit;
}

double GetLatestPivotHigh()
{
   for(int i = 0; i < ArraySize(pivotHighs); i++)
      if(pivotHighs[i] > 0) return pivotHighs[i];
   return 0;
}

double GetLatestPivotLow()
{
   for(int i = 0; i < ArraySize(pivotLows); i++)
      if(pivotLows[i] > 0) return pivotLows[i];
   return 0;
}