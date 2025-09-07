#property copyright "Copyright Matt Todorovski 2025"
#property version   "1.01"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

input int    Magic          = 12345;
input string Comment        = "HF_MA_EA";
input double Lotsize        = 0.01;
input int    MaximumBuySell = 35;

datetime LastOrderTime = 0;
int      OrderDelay    = 60;
double   CurrentTrailProfit = 0;
bool     TrailActive = false;
int      ProfitableDirection = -1;
double   LastOrderPrice = 0;
int      BuyOrdersInSeries = 0;
int      SellOrdersInSeries = 0;
bool     BuyDirectionPaused = false;
bool     SellDirectionPaused = false;
double   FirstBuyOrderPrice = 0;
double   FirstSellOrderPrice = 0;
double   FourthBuyOrderPrice = 0;
double   FourthSellOrderPrice = 0;

// MQL5 equivalents for MQL4 order types
#define OP_BUY ORDER_TYPE_BUY
#define OP_SELL ORDER_TYPE_SELL

// Create global instances of Trade and PositionInfo classes
CTrade trade;
CPositionInfo positionInfo;

struct OrderInfo
{
   ulong ticket;
   double lots;
   double profit;
   int type;
};

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
   if (CountOrders() == 0)
   {
      BuyOrdersInSeries = 0;
      SellOrdersInSeries = 0;
      BuyDirectionPaused = false;
      SellDirectionPaused = false;
      FirstBuyOrderPrice = 0;
      FirstSellOrderPrice = 0;
      FourthBuyOrderPrice = 0;
      FourthSellOrderPrice = 0;
   }
   
   if (BuyDirectionPaused)
   {
      double distance = FourthBuyOrderPrice - FirstBuyOrderPrice;
      if (SymbolInfoDouble(Symbol(), SYMBOL_ASK) > FourthBuyOrderPrice + (distance * 2))
      {
         BuyDirectionPaused = false;
      }
   }
   
   if (SellDirectionPaused)
   {
      double distance = FirstSellOrderPrice - FourthSellOrderPrice;
      if (SymbolInfoDouble(Symbol(), SYMBOL_BID) < FourthSellOrderPrice - (distance * 2))
      {
         SellDirectionPaused = false;
      }
   }
   
   bool isTimeToOrder = (TimeCurrent() - LastOrderTime >= OrderDelay);
   bool hasOrderDelay = (LastOrderTime == 0 || isTimeToOrder);
   
   if (hasOrderDelay)
   {
      int direction = -1;
      
      if (CountOrders() > 0)
      {
         if (LastOrderPrice > SymbolInfoDouble(Symbol(), SYMBOL_ASK))
         {
            direction = OP_SELL;
         }
         else if (LastOrderPrice < SymbolInfoDouble(Symbol(), SYMBOL_ASK))
         {
            direction = OP_BUY;
         }
      }
      else
      {
         direction = OP_BUY;
      }
      
      if (direction != -1)
      {
         int buyCount = CountOrdersByType(OP_BUY);
         int sellCount = CountOrdersByType(OP_SELL);
         
         double currentPrice = (direction == OP_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID);
         double spreadDistance = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
         
         bool distanceRequirementMet = (LastOrderPrice == 0) || 
            (direction == OP_BUY && currentPrice - LastOrderPrice >= (spreadDistance * 3)) ||
            (direction == OP_SELL && LastOrderPrice - currentPrice >= (spreadDistance * 3));
         
         if ((direction == OP_BUY && buyCount < MaximumBuySell && !BuyDirectionPaused && distanceRequirementMet) || 
             (direction == OP_SELL && sellCount < MaximumBuySell && !SellDirectionPaused && distanceRequirementMet))
         {
            double dynamicLotsize = CalculateDynamicLotsize(direction);
            
            OpenOrder(direction, dynamicLotsize);
            LastOrderTime = TimeCurrent();
            LastOrderPrice = currentPrice;
            
            if (direction == OP_BUY)
            {
               if (BuyOrdersInSeries == 1)
               {
                  FirstBuyOrderPrice = currentPrice;
               }
               else if (BuyOrdersInSeries == 4)
               {
                  FourthBuyOrderPrice = currentPrice;
                  BuyDirectionPaused = true;
               }
            }
            else if (direction == OP_SELL)
            {
               if (SellOrdersInSeries == 1)
               {
                  FirstSellOrderPrice = currentPrice;
               }
               else if (SellOrdersInSeries == 4)
               {
                  FourthSellOrderPrice = currentPrice;
                  SellDirectionPaused = true;
               }
            }
            
            if (TrailActive && direction == ProfitableDirection)
            {
               CurrentTrailProfit += CurrentTrailProfit * 0.5;
            }
         }
      }
   }
   
   double totalCommissionAndSpread = CalculateTotalCommissionAndSpread();
   double totalProfit = CalculateTotalProfit();
   
   MatchAndCloseOppositeOrders(totalCommissionAndSpread * 100);
   
   ManageTrailingProfit(totalCommissionAndSpread * 150);
}

double CalculateDynamicLotsize(int direction)
{
   double dynamicLotsize = Lotsize;
   
   int buyCount = CountOrdersByType(OP_BUY);
   int sellCount = CountOrdersByType(OP_SELL);
   
   if ((direction == OP_BUY && sellCount > 0 && BuyOrdersInSeries == 0) ||
       (direction == OP_SELL && buyCount > 0 && SellOrdersInSeries == 0))
   {
      dynamicLotsize *= 2;
   }
   
   if (direction == OP_BUY)
   {
      BuyOrdersInSeries++;
      if (BuyOrdersInSeries > 3 && BuyOrdersInSeries <= 15)
      {
         dynamicLotsize = Lotsize + (0.01 * (BuyOrdersInSeries - 3));
      }
      else if (BuyOrdersInSeries > 15)
      {
         dynamicLotsize = Lotsize + (0.01 * 12);
      }
   }
   else if (direction == OP_SELL)
   {
      SellOrdersInSeries++;
      if (SellOrdersInSeries > 3 && SellOrdersInSeries <= 15)
      {
         dynamicLotsize = Lotsize + (0.01 * (SellOrdersInSeries - 3));
      }
      else if (SellOrdersInSeries > 15)
      {
         dynamicLotsize = Lotsize + (0.01 * 12);
      }
   }
   
   return dynamicLotsize;
}

double CalculateTotalCommissionAndSpread()
{
   double total = 0;
   
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (positionInfo.SelectByIndex(i))
      {
         if (positionInfo.Magic() == Magic && positionInfo.Symbol() == Symbol())
         {
            total += positionInfo.Commission() + positionInfo.Swap();
            total += positionInfo.Volume() * SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
         }
      }
   }
   
   return total;
}

double CalculateTotalProfit()
{
   double profit = 0;
   
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (positionInfo.SelectByIndex(i))
      {
         if (positionInfo.Magic() == Magic && positionInfo.Symbol() == Symbol())
         {
            profit += positionInfo.Profit() + positionInfo.Commission() + positionInfo.Swap();
         }
      }
   }
   
   return profit;
}

void MatchAndCloseOppositeOrders(double profitTarget)
{
   OrderInfo buyOrders[100];
   OrderInfo sellOrders[100];
   int buyCount = 0, sellCount = 0;
   
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (positionInfo.SelectByIndex(i))
      {
         if (positionInfo.Magic() == Magic && positionInfo.Symbol() == Symbol())
         {
            OrderInfo info;
            info.ticket = positionInfo.Ticket();
            info.lots = positionInfo.Volume();
            info.profit = positionInfo.Profit() + positionInfo.Commission() + positionInfo.Swap();
            info.type = (int)positionInfo.PositionType();
            
            if (info.type == OP_BUY)
            {
               buyOrders[buyCount++] = info;
            }
            else if (info.type == OP_SELL)
            {
               sellOrders[sellCount++] = info;
            }
         }
      }
   }
   
   SortOrdersByProfit(buyOrders, buyCount, true);
   SortOrdersByProfit(sellOrders, sellCount, true);
   
   for (int b = 0; b < buyCount; b++)
   {
      for (int s = 0; s < sellCount; s++)
      {
         double commissionAndSpread = CalculateTotalCommissionAndSpread();
         double targetProfit = MathAbs(sellOrders[s].profit) * 10;
         
         if (buyOrders[b].profit >= targetProfit && sellOrders[s].profit < 0)
         {
            if (CloseOrderPair(buyOrders[b].ticket, sellOrders[s].ticket))
            {
               return;
            }
         }
      }
   }
}

void ManageTrailingProfit(double trailStartThreshold)
{
   int buyCount = CountOrdersByType(OP_BUY);
   int sellCount = CountOrdersByType(OP_SELL);
   
   double buyProfit = CalculateProfitByType(OP_BUY);
   double sellProfit = CalculateProfitByType(OP_SELL);
   double commissionAndSpread = CalculateTotalCommissionAndSpread();
   
   if (!TrailActive)
   {
      if (buyProfit >= trailStartThreshold && buyCount >= 1)
      {
         TrailActive = true;
         ProfitableDirection = OP_BUY;
         CurrentTrailProfit = buyProfit;
      }
      else if (sellProfit >= trailStartThreshold && sellCount >= 1)
      {
         TrailActive = true;
         ProfitableDirection = OP_SELL;
         CurrentTrailProfit = sellProfit;
      }
   }
   else
   {
      if (ProfitableDirection == OP_BUY)
      {
         double buyProfitNow = CalculateProfitByType(OP_BUY);
         if (buyProfitNow > CurrentTrailProfit)
         {
            CurrentTrailProfit = buyProfitNow;
         }
         else if (CurrentTrailProfit - buyProfitNow > commissionAndSpread * 50)
         {
            CloseOrdersByType(OP_BUY);
            TrailActive = false;
            ProfitableDirection = -1;
         }
      }
      else if (ProfitableDirection == OP_SELL)
      {
         double sellProfitNow = CalculateProfitByType(OP_SELL);
         if (sellProfitNow > CurrentTrailProfit)
         {
            CurrentTrailProfit = sellProfitNow;
         }
         else if (CurrentTrailProfit - sellProfitNow > commissionAndSpread * 50)
         {
            CloseOrdersByType(OP_SELL);
            TrailActive = false;
            ProfitableDirection = -1;
         }
      }
   }
}

double CalculateProfitByType(int type)
{
   double profit = 0;
   
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (positionInfo.SelectByIndex(i))
      {
         if (positionInfo.Magic() == Magic && positionInfo.Symbol() == Symbol() && (int)positionInfo.PositionType() == type)
         {
            profit += positionInfo.Profit();
         }
      }
   }
   
   return profit;
}

void CloseAllOrders()
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (positionInfo.SelectByIndex(i))
      {
         if (positionInfo.Magic() == Magic && positionInfo.Symbol() == Symbol())
         {
            trade.PositionClose(positionInfo.Ticket());
            if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
               Print("Error closing position: ", trade.ResultRetcode(), ", ", trade.ResultComment());
         }
      }
   }
   
   LastOrderTime = 0;
   LastOrderPrice = 0;
   BuyOrdersInSeries = 0;
   SellOrdersInSeries = 0;
   BuyDirectionPaused = false;
   SellDirectionPaused = false;
   FirstBuyOrderPrice = 0;
   FirstSellOrderPrice = 0;
   FourthBuyOrderPrice = 0;
   FourthSellOrderPrice = 0;
}

void CloseOrdersByType(int type)
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (positionInfo.SelectByIndex(i))
      {
         if (positionInfo.Magic() == Magic && positionInfo.Symbol() == Symbol() && (int)positionInfo.PositionType() == type)
         {
            trade.PositionClose(positionInfo.Ticket());
            if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
               Print("Error closing position: ", trade.ResultRetcode(), ", ", trade.ResultComment());
         }
      }
   }
}

void OpenOrder(int type, double lots)
{
   double price = (type == OP_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   if (type == OP_BUY)
      trade.Buy(lots, Symbol(), 0, 0, 0, Comment);
   else if (type == OP_SELL)
      trade.Sell(lots, Symbol(), 0, 0, 0, Comment);
   
   if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
   {
      Print("Order open error: ", trade.ResultRetcode(), ", ", trade.ResultComment());
   }
}

int CountOrders()
{
   int count = 0;
   
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (positionInfo.SelectByIndex(i))
      {
         if (positionInfo.Magic() == Magic && positionInfo.Symbol() == Symbol())
         {
            count++;
         }
      }
   }
   
   return count;
}

int CountOrdersByType(int type)
{
   int count = 0;
   
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (positionInfo.SelectByIndex(i))
      {
         if (positionInfo.Magic() == Magic && positionInfo.Symbol() == Symbol() && (int)positionInfo.PositionType() == type)
         {
            count++;
         }
      }
   }

   return count;
}

bool AreAllOrdersInLoss(int type)
{
   bool allLoss = true;
   
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (positionInfo.SelectByIndex(i))
      {
         if (positionInfo.Magic() == Magic && positionInfo.Symbol() == Symbol() && (int)positionInfo.PositionType() == type)
         {
            if (positionInfo.Profit() >= 0)
            {
               allLoss = false;
               break;
            }
         }
      }
   }
   
   return allLoss;
}

void SortOrdersByProfit(OrderInfo &orders[], int count, bool descending)
{
   for (int i = 0; i < count - 1; i++)
   {
      for (int j = 0; j < count - i - 1; j++)
      {
         if ((descending && orders[j].profit < orders[j+1].profit) ||
             (!descending && orders[j].profit > orders[j+1].profit))
         {
            OrderInfo temp = orders[j];
            orders[j] = orders[j+1];
            orders[j+1] = temp;
         }
      }
   }
}

bool CloseOrderPair(ulong buyTicket, ulong sellTicket)
{
   bool buySuccess = false;
   bool sellSuccess = false;
   
   if (positionInfo.SelectByTicket(buyTicket))
   {
      buySuccess = trade.PositionClose(buyTicket);
      if (!buySuccess)
         Print("Error closing buy position: ", trade.ResultRetcode(), ", ", trade.ResultComment());
   }
   
   if (positionInfo.SelectByTicket(sellTicket))
   {
      sellSuccess = trade.PositionClose(sellTicket);
      if (!sellSuccess)
         Print("Error closing sell position: ", trade.ResultRetcode(), ", ", trade.ResultComment());
   }
   
   return buySuccess && sellSuccess;
}