#property copyright "Copyright Matt Todorovski 2025"
#property version   "1.01"
#property strict
/*
1. Position Management
The EA manages positions using these mechanisms:
Directional tracking: Keeps track of BuyOrdersInSeries and SellOrdersInSeries to manage position sizing and sequence
Position limits: Enforces MaximumBuySell (35 by default) per direction
Directional pausing: After 4 consecutive orders in one direction, it pauses that direction until a significant price move occurs
Dynamic lotsize: Adjusts position size based on order sequence and market conditions

2. Position Closure Mechanisms
There are three main ways positions get closed:
a) Profit Matching (MatchAndCloseOppositeOrders)
Pairs profitable buys with losing sells
Closes a buy order when its profit can cover 10x a sell order's loss
This systematically offsets losses with profits

b) Trailing Profit Management (ManageTrailingProfit)
Activates when profit exceeds a threshold (150x commissions/spread)
Tracks highest profit level achieved
Closes positions if profit retraces from peak by more than 50x commissions/spread
Functions as a dynamic trailing stop


c) Session-Based Reset
If all positions are closed and UseSessionStarts is enabled, the EA will:
Wait for the next session (London or New York)
Reset all trading parameters
Start fresh with a new buy position

3. Closure Criteria Summary
Positions are closed when:
Profit offset: A profitable buy can cover multiple times a sell's loss
Trailing stop hit: Profit retraces from peak by a defined amount
Automatic hedging: The EA attempts to balance buys and sells, closing them in pairs when profit targets are met
Manual closing: External closure (not in code) between sessions will cause the EA to wait for next session
The EA doesn't use traditional stop-loss or take-profit levels. Instead, it uses sophisticated profit tracking and position pairing to manage risk and capture profits when certain thresholds are met.

*/
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

input int    Magic          = 12345;
input string Comment        = "HF_MA_EA";
input double Lotsize        = 0.1;
input int    MaximumBuySell = 35;
input bool   UseSessionStarts = true;     // Enable session-based trading
input int    LondonHour     = 8;          // London session start hour (GMT)
input int    LondonMinute   = 0;          // London session start minute
input int    NewYorkHour    = 13;         // New York session start hour (GMT)
input int    NewYorkMinute  = 0;          // New York session start minute

// Add dashboard configuration inputs
input bool   ShowDashboard   = true;      // Show trading dashboard
input int    DashboardX      = 20;        // Dashboard X position
input int    DashboardY      = 20;        // Dashboard Y position
input int    DashboardWidth  = 180;       // Dashboard width
input int    DashboardHeight = 135;       // Dashboard height

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
datetime LastSessionCheckDay = 0;
bool     LondonSessionTraded = false;
bool     NewYorkSessionTraded = false;

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

// Add global variables to track dashboard objects
string dashboard_bg = "Dashboard_BG";
string dashboard_title = "Dashboard_Title";
string dashboard_ny = "Dashboard_NY";
string dashboard_ny_buys = "Dashboard_NY_Buys";
string dashboard_ny_sells = "Dashboard_NY_Sells";
string dashboard_lnd = "Dashboard_LND";
string dashboard_lnd_buys = "Dashboard_LND_Buys";
string dashboard_lnd_sells = "Dashboard_LND_Sells";
string dashboard_pnl = "Dashboard_PNL";
string dashboard_pnl_value = "Dashboard_PNL_Value";

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   
   // Initialize dashboard if enabled
   if (ShowDashboard)
   {
      CreateDashboard();
   }
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   // Clean up dashboard objects
   if (ShowDashboard)
   {
      ObjectDelete(0, dashboard_bg);
      ObjectDelete(0, dashboard_title);
      ObjectDelete(0, dashboard_ny);
      ObjectDelete(0, dashboard_ny_buys);
      ObjectDelete(0, dashboard_ny_sells);
      ObjectDelete(0, dashboard_lnd);
      ObjectDelete(0, dashboard_lnd_buys);
      ObjectDelete(0, dashboard_lnd_sells);
      ObjectDelete(0, dashboard_pnl);
      ObjectDelete(0, dashboard_pnl_value);
   }
}

void OnTick()
{
   // Check for session-based trading
   if (UseSessionStarts)
   {
      CheckSessionTrades();
   }
   
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
      
      // Don't auto-start trading when there are no orders if we're using session starts
      if (UseSessionStarts)
         return; // Skip the rest of OnTick if we're waiting for a session start
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
         // Only automatically open initial trades if NOT using session starts
         if (!UseSessionStarts)
            direction = OP_BUY;
         else
            direction = -1; // Prevent automatic initial trades when using session times
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
   
   // Update dashboard
   if (ShowDashboard)
   {
      UpdateDashboard();
   }
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
   //Print("MatchAndCloseOppositeOrders");
   //Print("===================");
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

void OpenOrder(int type, double lots, string orderComment = "")
{
   double price = (type == OP_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   // Use the provided comment or fall back to the default Comment
   string tradeComment = (orderComment == "") ? Comment : orderComment;
   
   if (type == OP_BUY)
      trade.Buy(lots, Symbol(), 0, 0, 0, tradeComment);
   else if (type == OP_SELL)
      trade.Sell(lots, Symbol(), 0, 0, 0, tradeComment);
   
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

void CheckSessionTrades()
{
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   
   if (LastSessionCheckDay != currentTime.day_of_year)
   {
      LastSessionCheckDay = currentTime.day_of_year;
      LondonSessionTraded = false;
      NewYorkSessionTraded = false;
   }
   
   if (!LondonSessionTraded && 
       currentTime.hour == LondonHour && 
       currentTime.min >= LondonMinute && 
       currentTime.min < LondonMinute + 5)
   {
      Print("London session start detected, initiating trade");
      InitiateSessionTrade("LND"); // Pass London session comment
      LondonSessionTraded = true;
   }
   
   if (!NewYorkSessionTraded && 
       currentTime.hour == NewYorkHour && 
       currentTime.min >= NewYorkMinute && 
       currentTime.min < NewYorkMinute + 5)
   {
      Print("New York session start detected, initiating trade");
      InitiateSessionTrade("NY"); // Pass New York session comment
      NewYorkSessionTraded = true;
   }
}

void InitiateSessionTrade(string sessionTag)
{
   BuyOrdersInSeries = 0;
   SellOrdersInSeries = 0;
   BuyDirectionPaused = false;
   SellDirectionPaused = false;
   FirstBuyOrderPrice = 0;
   FirstSellOrderPrice = 0;
   FourthBuyOrderPrice = 0;
   FourthSellOrderPrice = 0;
   TrailActive = false;
   ProfitableDirection = -1;
   CurrentTrailProfit = 0;
   
   // Create session-specific comment by combining the base comment with the session tag
   string sessionComment = Comment + "_" + sessionTag;
   
   // Pass the session-specific comment to OpenOrder
   OpenOrder(OP_BUY, Lotsize, sessionComment);
   LastOrderTime = TimeCurrent();
   LastOrderPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   BuyOrdersInSeries++;
}

// Add new functions for dashboard

void CreateDashboard()
{
   // Create background
   ObjectCreate(0, dashboard_bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, dashboard_bg, OBJPROP_XDISTANCE, DashboardX);
   ObjectSetInteger(0, dashboard_bg, OBJPROP_YDISTANCE, DashboardY);
   ObjectSetInteger(0, dashboard_bg, OBJPROP_XSIZE, DashboardWidth);
   ObjectSetInteger(0, dashboard_bg, OBJPROP_YSIZE, DashboardHeight);
   ObjectSetInteger(0, dashboard_bg, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, dashboard_bg, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, dashboard_bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, dashboard_bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, dashboard_bg, OBJPROP_BACK, false);
   ObjectSetInteger(0, dashboard_bg, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, dashboard_bg, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, dashboard_bg, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, dashboard_bg, OBJPROP_ZORDER, 0);
   
   // Create title
   CreateLabel(dashboard_title, "Trading Dashboard", DashboardX + 10, DashboardY + 10, clrWhite, 10);
   
   // Create NY section
   CreateLabel(dashboard_ny, "NY Trades", DashboardX + 10, DashboardY + 30, clrWhite, 9);
   CreateLabel(dashboard_ny_buys, "  Buys: 0", DashboardX + 20, DashboardY + 45, clrWhite, 9);
   CreateLabel(dashboard_ny_sells, "  Sells: 0", DashboardX + 20, DashboardY + 60, clrWhite, 9);
   
   // Create LND section
   CreateLabel(dashboard_lnd, "LND Trades", DashboardX + 10, DashboardY + 75, clrWhite, 9);
   CreateLabel(dashboard_lnd_buys, "  Buys: 0", DashboardX + 20, DashboardY + 90, clrWhite, 9);
   CreateLabel(dashboard_lnd_sells, "  Sells: 0", DashboardX + 20, DashboardY + 105, clrWhite, 9);
   
   // Create PNL section
   CreateLabel(dashboard_pnl, "Overall PNL:", DashboardX + 10, DashboardY + 120, clrWhite, 9);
   CreateLabel(dashboard_pnl_value, "0.00", DashboardX + 100, DashboardY + 120, clrWhite, 9);
}

void CreateLabel(string name, string text, int x, int y, color clr, int size)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void UpdateDashboard()
{
   // Count NY trades
   int nyBuys = 0, nySells = 0;
   
   // Count LND trades
   int lndBuys = 0, lndSells = 0;
   
   // Calculate overall PNL
   double totalPnl = 0;
   
   // Loop through all positions
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (positionInfo.SelectByIndex(i))
      {
         if (positionInfo.Magic() == Magic && positionInfo.Symbol() == Symbol())
         {
            string posComment = positionInfo.Comment();
            int posType = (int)positionInfo.PositionType();
            
            // Update PNL
            totalPnl += positionInfo.Profit() + positionInfo.Commission() + positionInfo.Swap();
            
            // Check for NY trades
            if (StringFind(posComment, "_NY") >= 0)
            {
               if (posType == OP_BUY)
                  nyBuys++;
               else if (posType == OP_SELL)
                  nySells++;
            }
            // Check for LND trades
            else if (StringFind(posComment, "_LND") >= 0)
            {
               if (posType == OP_BUY)
                  lndBuys++;
               else if (posType == OP_SELL)
                  lndSells++;
            }
         }
      }
   }
   
   // Update dashboard text
   ObjectSetString(0, dashboard_ny_buys, OBJPROP_TEXT, "  Buys: " + IntegerToString(nyBuys));
   ObjectSetString(0, dashboard_ny_sells, OBJPROP_TEXT, "  Sells: " + IntegerToString(nySells));
   ObjectSetString(0, dashboard_lnd_buys, OBJPROP_TEXT, "  Buys: " + IntegerToString(lndBuys));
   ObjectSetString(0, dashboard_lnd_sells, OBJPROP_TEXT, "  Sells: " + IntegerToString(lndSells));
   
   // Format PNL with 2 decimal places
   string pnlText = DoubleToString(totalPnl, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY);
   ObjectSetString(0, dashboard_pnl_value, OBJPROP_TEXT, pnlText);
   
   // Set PNL color based on value
   color pnlColor = (totalPnl >= 0) ? clrLime : clrRed;
   ObjectSetInteger(0, dashboard_pnl_value, OBJPROP_COLOR, pnlColor);
   
   // Force chart redraw
   ChartRedraw(0);
}