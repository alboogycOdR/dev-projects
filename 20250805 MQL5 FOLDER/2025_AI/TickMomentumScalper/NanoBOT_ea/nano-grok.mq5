//+------------------------------------------------------------------+
//|                       Advanced Scalping EA                       |
//| Trades every tick on 1-minute chart with hedging & recovery      |
//+------------------------------------------------------------------+

#property copyright "Advanced Algo Trader"
#property link      "https://www.example.com"
#property version   "1.00"
#include <Trade\Trade.mqh> // Include the CTrade class for simplified trading
#include <Arrays\List.mqh>     // For sorting positions/orders
#include <Arrays\ArrayObj.mqh>
//--- Input Parameters
input double RiskPercent = 1.0;      // Risk % per trade (1% of account balance)
input int MaxPositions = 5;          // Maximum number of open positions
input int FastMAPeriod = 5;          // Fast Moving Average Period
input int SlowMAPeriod = 20;         // Slow Moving Average Period
input int ATR_Period = 14;           // ATR period for dynamic distances
input double HedgeATRMultiplier = 1.0; // Multiplier for hedge distance (ATR * multiplier)
input double PendingATRMultiplier = 1.5; // Multiplier for pending order distance (ATR * multiplier)
input double RecoveryThreshold = 5.0;// Loss threshold for recovery trade (pips)
input double BreakevenPips = 5.0;    // Pips in profit to move SL to breakeven
input double ProfitTarget = 5.0;     // Combined profit target in USD
input int MaxSlippage = 3;           // Maximum slippage in points

//--- Global Variables
int fastMAHandle, slowMAHandle, atrHandle;
double fastMA[], slowMA[], atr[];
double point, pipValue;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize indicators
   fastMAHandle = iMA(_Symbol, PERIOD_M1, FastMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   slowMAHandle = iMA(_Symbol, PERIOD_M1, SlowMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, PERIOD_M1, ATR_Period);
   
   if(fastMAHandle == INVALID_HANDLE || slowMAHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
   {
      Print("Failed to initialize indicators");
      return(INIT_FAILED);
   }
   
   ArraySetAsSeries(fastMA, true);
   ArraySetAsSeries(slowMA, true);
   ArraySetAsSeries(atr, true);
   
   point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Set pipValue based on symbol
   if(StringFind(_Symbol, "JPY") != -1)
      pipValue = 0.01;
   else
      pipValue = 0.0001;
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(fastMAHandle);
   IndicatorRelease(slowMAHandle);
   IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Get indicator values
   if(CopyBuffer(fastMAHandle, 0, 0, 3, fastMA) < 3 || CopyBuffer(slowMAHandle, 0, 0, 3, slowMA) < 3 || CopyBuffer(atrHandle, 0, 0, 1, atr) < 1)
      return;
   
   double currentATR = atr[0];
   
   // Check total profit and close all if target reached
   if(CalculateTotalProfit() > ProfitTarget)
   {
      CloseAllPositions();
      DeleteAllPendingOrders();
      return;
   }
   
   // Manage existing positions
   ManagePositions();
   
   // Check for new trade opportunities
   if(PositionsTotal() < MaxPositions)
   {
      double lotSize = CalculateLotSize();
      
      // MA Crossover Logic
      if(fastMA[1] > slowMA[1] && fastMA[2] <= slowMA[2]) // Buy Signal
      {
         OpenBuyTrade(lotSize);
         double hedgeDistancePrice = currentATR * HedgeATRMultiplier;
         PlaceHedgeOrder(POSITION_TYPE_SELL, hedgeDistancePrice, lotSize);
         double pendingDistancePrice = currentATR * PendingATRMultiplier;
         PlacePendingOrder(ORDER_TYPE_BUY_STOP, pendingDistancePrice, lotSize);
      }
      else if(fastMA[1] < slowMA[1] && fastMA[2] >= slowMA[2]) // Sell Signal
      {
         OpenSellTrade(lotSize);
         double hedgeDistancePrice = currentATR * HedgeATRMultiplier;
         PlaceHedgeOrder(POSITION_TYPE_BUY, hedgeDistancePrice, lotSize);
         double pendingDistancePrice = currentATR * PendingATRMultiplier;
         PlacePendingOrder(ORDER_TYPE_SELL_STOP, pendingDistancePrice, lotSize);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate total profit of all open positions                      |
//+------------------------------------------------------------------+
double CalculateTotalProfit()
{
   double totalProfit = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
         totalProfit += PositionGetDouble(POSITION_PROFIT);
   }
   return totalProfit;
}

//+------------------------------------------------------------------+
//| Close all open positions                                          |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         CTrade trade;
         trade.PositionClose(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Delete all pending orders                                         |
//+------------------------------------------------------------------+
void DeleteAllPendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket))
      {
         CTrade trade;
         trade.OrderDelete(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate dynamic lot size based on risk percentage              |
//+----------------------------------------------------------------------+
double CalculateLotSize()
{
//    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
//    double riskAmount = balance * (RiskPercent / 100.0);
//    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
//    double lotSize = NormalizeDouble(riskAmount / (50 * tickValue * point / pipValue), 2); // Assuming 50 points SL (e.g., 5 pips for EURUSD)
//    return lotSize;
   return 0.01;
}

//+------------------------------------------------------------------+
//| Open a buy trade                                                 |
//+------------------------------------------------------------------+
void OpenBuyTrade(double lotSize)
{
   CTrade trade;
   trade.SetDeviationInPoints(MaxSlippage);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = price - 50 * point; // 50 points SL (e.g., 5 pips for EURUSD)
   double tp = price + 50 * point; // 50 points TP
   trade.Buy(lotSize, _Symbol, price, sl, tp, "Initial Buy");
}

//+------------------------------------------------------------------+
//| Open a sell trade                                                |
//+------------------------------------------------------------------+
void OpenSellTrade(double lotSize)
{
   CTrade trade;
   trade.SetDeviationInPoints(MaxSlippage);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = price + 50 * point; // 50 points SL
   double tp = price - 50 * point; // 50 points TP
   trade.Sell(lotSize, _Symbol, price, sl, tp, "Initial Sell");
}

//+------------------------------------------------------------------+
//| Place hedge pending order                                        |
//+------------------------------------------------------------------+
void PlaceHedgeOrder(ENUM_POSITION_TYPE type, double distancePrice, double lotSize)
{
   CTrade trade;
   double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double hedgePrice = (type == POSITION_TYPE_BUY) ? currentPrice + distancePrice : currentPrice - distancePrice;
   double sl = (type == POSITION_TYPE_BUY) ? hedgePrice - 50 * point : hedgePrice + 50 * point;
   double tp = (type == POSITION_TYPE_BUY) ? hedgePrice + 50 * point : hedgePrice - 50 * point;
   
   if(type == POSITION_TYPE_BUY)
      trade.BuyStop(lotSize, hedgePrice, _Symbol, sl, tp, 0, 0, "Hedge Buy Stop");
   else
      trade.SellStop(lotSize, hedgePrice, _Symbol, sl, tp, 0, 0, "Hedge Sell Stop");
}

//+------------------------------------------------------------------+
//| Place strategic pending order                                    |
//+------------------------------------------------------------------+
void PlacePendingOrder(ENUM_ORDER_TYPE type, double distancePrice, double lotSize)
{
   CTrade trade;
   double currentPrice = (type == ORDER_TYPE_BUY_STOP) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double pendingPrice = (type == ORDER_TYPE_BUY_STOP) ? currentPrice + distancePrice : currentPrice - distancePrice;
   double sl = (type == ORDER_TYPE_BUY_STOP) ? pendingPrice - 50 * point : pendingPrice + 50 * point;
   double tp = (type == ORDER_TYPE_BUY_STOP) ? pendingPrice + 50 * point : pendingPrice - 50 * point;
   
   if(type == ORDER_TYPE_BUY_STOP)
      trade.BuyStop(lotSize, pendingPrice, _Symbol, sl, tp, 0, 0, "Strategic Buy Stop");
   else if(type == ORDER_TYPE_SELL_STOP)
      trade.SellStop(lotSize, pendingPrice, _Symbol, sl, tp, 0, 0, "Strategic Sell Stop");
}

//+------------------------------------------------------------------+
//| Manage open positions (SL to breakeven, recovery trades)         |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl = PositionGetDouble(POSITION_SL);
         double profitInPips = (posType == POSITION_TYPE_BUY ? 
                                (currentPrice - entryPrice) : (entryPrice - currentPrice)) / pipValue;
         
         // Move SL to breakeven
         if(profitInPips > BreakevenPips && sl != entryPrice)
         {
            CTrade trade;
            double newSL = entryPrice;
            double tp = PositionGetDouble(POSITION_TP);
            trade.PositionModify(ticket, newSL, tp);
         }
         
         // Recovery trade logic
         if(profitInPips < -RecoveryThreshold && PositionsTotal() < MaxPositions)
         {
            double lotSize = PositionGetDouble(POSITION_VOLUME) * 2;
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               OpenBuyTrade(lotSize);
            else
               OpenSellTrade(lotSize);
         }
      }
   }
}