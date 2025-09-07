//+------------------------------------------------------------------+
//|                       Advanced Scalping EA                       |
//| Trades every tick on 1-minute chart with hedging & recovery      |
//+------------------------------------------------------------------+

#property copyright "Advanced Algo Trader"
#property link      "https://www.example.com"
#property version   "3.00"
#include <Trade\Trade.mqh> // Include the CTrade class for simplified trading
#include <Arrays\List.mqh>     // For sorting positions/orders
#include <Arrays\ArrayObj.mqh>
//--- Input Parameters
input double RiskPercent = 1.0;      // Risk % per trade (1% of account balance)
input int MaxPositions = 5;          // Maximum number of open positions
input int FastMAPeriod = 5;          // Fast Moving Average Period
input int SlowMAPeriod = 20;         // Slow Moving Average Period (for SMA)
input int ATR_Period = 7;            // ATR period for scalping
input double HedgeATRMultiplier = 1.0; // Multiplier for hedge distance
input double PendingATRMultiplier = 1.5; // Multiplier for pending order distance
input double RecoveryThreshold = 5.0;// Loss threshold for recovery trade (pips)
input double BreakevenPips = 5.0;    // Pips in profit to move SL to breakeven
input double ProfitTarget = 5.0;     // Combined profit target in USD
input int MaxSlippage = 3;           // Maximum slippage in points
input int RSI_Period = 14;           // RSI period for overbought/oversold filter
input int ADX_Period = 14;           // ADX period for trend detection
input bool PauseDuringNews = false;  // Pause trading during high-impact news

//--- Global Variables
int fastMAHandle, smaHandle, atrHandle, atrSMAHandle, rsiHandle, adxHandle, smaH1Handle;
double fastMA[], sma[], atr[], atrSMA[], rsi[], adx[], smaH1[];
double point, pipValue, recentHighH1, recentLowH1;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   TesterHideIndicators(true);
   // Initialize indicators
   fastMAHandle = iMA(_Symbol, PERIOD_M1, FastMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   smaHandle = iMA(_Symbol, PERIOD_M1, SlowMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, PERIOD_M1, ATR_Period);
   atrSMAHandle = iMA(_Symbol, PERIOD_M1, 20, 0, MODE_SMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, PERIOD_M1, RSI_Period, PRICE_CLOSE);
   adxHandle = iADX(_Symbol, PERIOD_H1, ADX_Period);
   smaH1Handle = iMA(_Symbol, PERIOD_H1, 20, 0, MODE_SMA, PRICE_CLOSE);
   
   if(fastMAHandle == INVALID_HANDLE || smaHandle == INVALID_HANDLE || 
      atrHandle == INVALID_HANDLE || atrSMAHandle == INVALID_HANDLE ||
      rsiHandle == INVALID_HANDLE || adxHandle == INVALID_HANDLE || smaH1Handle == INVALID_HANDLE)
   {
      Print("Failed to initialize indicators");
      return(INIT_FAILED);
   }
   
   ArraySetAsSeries(fastMA, true);
   ArraySetAsSeries(sma, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(atrSMA, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(smaH1, true);
   
   point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // Set pipValue based on symbol
   if(StringFind(_Symbol, "JPY") != -1)
      pipValue = 0.01;
   else
      pipValue = 0.0001;
   
   EventSetTimer(60); // Log every minute
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(fastMAHandle);
   IndicatorRelease(smaHandle);
   IndicatorRelease(atrHandle);
   IndicatorRelease(atrSMAHandle);
   IndicatorRelease(rsiHandle);
   IndicatorRelease(adxHandle);
   IndicatorRelease(smaH1Handle);
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Expert timer function                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   string logMessage = StringFormat("Time: %s, ATR: %.5f, ADX: %.2f, RSI: %.2f, Positions: %d, Profit: %.2f",
                                   TimeToString(TimeCurrent()),
                                   atr[0], adx[0], rsi[0],
                                   PositionsTotal(),
                                   CalculateTotalProfit());
   FileWrite(FileOpen("ScalpingEA_Log.csv", FILE_WRITE|FILE_CSV|FILE_COMMON), logMessage);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Get indicator values
   if(CopyBuffer(fastMAHandle, 0, 0, 3, fastMA) < 3 || CopyBuffer(smaHandle, 0, 0, 3, sma) < 3 || 
      CopyBuffer(atrHandle, 0, 0, 2, atr) < 2 || CopyBuffer(atrSMAHandle, 0, 0, 1, atrSMA) < 1 ||
      CopyBuffer(rsiHandle, 0, 0, 1, rsi) < 1 || CopyBuffer(adxHandle, 0, 0, 1, adx) < 1 ||
      CopyBuffer(smaH1Handle, 0, 0, 1, smaH1) < 1)
      return;
   
   double currentATR = atr[0];
   double prevATR = atr[1];
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double prevPrice = iClose(_Symbol, PERIOD_M1, 1);
   
   // Pause during news if enabled
   if(PauseDuringNews)
      return;
   
   // Higher timeframe trend and support/resistance
   bool isBullishH1 = currentPrice > smaH1[0];
   recentHighH1 = iHigh(_Symbol, PERIOD_H1, iHighest(_Symbol, PERIOD_H1, MODE_HIGH, 20));
   recentLowH1 = iLow(_Symbol, PERIOD_H1, iLowest(_Symbol, PERIOD_H1, MODE_LOW, 20));
   if(MathAbs(currentPrice - recentHighH1) < currentATR || MathAbs(currentPrice - recentLowH1) < currentATR)
      return; // Avoid trading near support/resistance
   
   // Divergence detection
   bool avoidBuy = (currentPrice > prevPrice && currentATR < prevATR); // Bearish divergence
   bool avoidSell = (currentPrice < prevPrice && currentATR > prevATR); // Bullish divergence
   
   // Market condition (trending or ranging)
   bool isTrending = adx[0] > 25;
   double slMultiplier = isTrending ? 1.0 : 2.0; // 1x ATR in trends, 2x in ranges
   double tpMultiplier = isTrending ? 3.0 : 1.0; // 3x ATR in trends, 1x in ranges
   
   // Check total profit and close all if target reached
   if(CalculateTotalProfit() > ProfitTarget)
   {
      CloseAllPositions();
      DeleteAllPendingOrders();
      return;
   }
   
   // Manage existing positions
   ManagePositions();
   
   // ATR Channel
   double upperChannel = currentPrice + currentATR * 2.0;
   double lowerChannel = currentPrice - currentATR * 2.0;
   double recentHigh = iHigh(_Symbol, PERIOD_M1, 1);
   double recentLow = iLow(_Symbol, PERIOD_M1, 1);
   
   // Check for new trade opportunities
   if(PositionsTotal() < MaxPositions)
   {
      double lotSize = CalculateLotSize(slMultiplier);
      
      // Breakout and Fade Logic
      if(currentPrice > recentHigh + currentATR * 1.2 && currentPrice > upperChannel && 
         currentPrice > sma[1] && rsi[0] < 70 && !avoidBuy && isBullishH1) // Buy breakout
      {
         OpenBuyTrade(lotSize, slMultiplier, tpMultiplier);
         double hedgeDistancePrice = currentATR * HedgeATRMultiplier;
         PlaceHedgeOrder(POSITION_TYPE_SELL, hedgeDistancePrice, lotSize, slMultiplier, tpMultiplier);
         double pendingDistancePrice = currentATR * PendingATRMultiplier;
         PlacePendingOrder(ORDER_TYPE_BUY_STOP, pendingDistancePrice, lotSize, slMultiplier, tpMultiplier);
      }
      else if(currentPrice < recentLow - currentATR * 1.2 && currentPrice < lowerChannel && 
              currentPrice < sma[1] && rsi[0] > 30 && !avoidSell && !isBullishH1) // Sell breakout
      {
         OpenSellTrade(lotSize, slMultiplier, tpMultiplier);
         double hedgeDistancePrice = currentATR * HedgeATRMultiplier;
         PlaceHedgeOrder(POSITION_TYPE_BUY, hedgeDistancePrice, lotSize, slMultiplier, tpMultiplier);
         double pendingDistancePrice = currentATR * PendingATRMultiplier;
         PlacePendingOrder(ORDER_TYPE_SELL_STOP, pendingDistancePrice, lotSize, slMultiplier, tpMultiplier);
      }
      else if(!isTrending && currentPrice > sma[1] + currentATR * 2.0 && rsi[0] > 70 && !avoidSell) // Fade overbought in range
      {
         OpenSellTrade(lotSize, slMultiplier, tpMultiplier);
      }
      else if(!isTrending && currentPrice < sma[1] - currentATR * 2.0 && rsi[0] < 30 && !avoidBuy) // Fade oversold in range
      {
         OpenBuyTrade(lotSize, slMultiplier, tpMultiplier);
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
//+------------------------------------------------------------------+
double CalculateLotSize(double slMultiplier)
{
//   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1 || CopyBuffer(atrSMAHandle, 0, 0, 1, atrSMA) < 1)
//      return 0.01; // Fallback lot size
//   
//   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
//   double riskAmount = balance * (RiskPercent / 100.0);
//   double currentATR = atr[0];
//   double slPoints = currentATR * slMultiplier / point; // SL in points
//   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
//   double baseLotSize = NormalizeDouble(riskAmount / (slPoints * tickValue), 2);
//   
//   // Volatility adjustment
//   double avgATR = atrSMA[0];
//   double lotMultiplier = (currentATR > avgATR) ? 0.5 : 1.5;
//   double adjustedLotSize = NormalizeDouble(baseLotSize * lotMultiplier, 2);
//   return MathMin(adjustedLotSize, baseLotSize * 2.0); // Cap at 2x base lot size
   return 1;
}

//+------------------------------------------------------------------+
//| Open a buy trade                                                 |
//+------------------------------------------------------------------+
void OpenBuyTrade(double lotSize, double slMultiplier, double tpMultiplier)
{
   CTrade trade;
   trade.SetDeviationInPoints(MaxSlippage);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID); // Need Bid for TP calculation
   double currentATR = atr[0];
   double stopLevelPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double stopLevelPrice = stopLevelPoints * point;

   // Calculate raw SL/TP
   double rawSL = price - currentATR * slMultiplier;
   double rawTP = price + currentATR * tpMultiplier;

   // Adjust SL to be at least stopLevelPrice below Bid price
   double adjustedSL = MathMin(rawSL, bid - stopLevelPrice);

   // Adjust TP to be at least stopLevelPrice above Ask price
   double adjustedTP = MathMax(rawTP, price + stopLevelPrice);

   // Normalize prices
   adjustedSL = NormalizeDouble(adjustedSL, _Digits);
   adjustedTP = NormalizeDouble(adjustedTP, _Digits);
   price = NormalizeDouble(price, _Digits); // Normalize entry price too

   // Ensure SL is not zero or negative if adjustedSL becomes invalid
   if(adjustedSL <= 0)
      adjustedSL = 0; // Set SL to 0 (no SL) if calculation is invalid

   trade.Buy(lotSize, _Symbol, price, adjustedSL, adjustedTP, "Initial Buy");
}

//+------------------------------------------------------------------+
//| Open a sell trade                                                |
//+------------------------------------------------------------------+
void OpenSellTrade(double lotSize, double slMultiplier, double tpMultiplier)
{
   CTrade trade;
   trade.SetDeviationInPoints(MaxSlippage);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // Need Ask for SL calculation
   double currentATR = atr[0];
   
   
   double stopLevelPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double stopLevelPrice = stopLevelPoints * point;

   // Calculate raw SL/TP
   double rawSL = price + currentATR * slMultiplier;
   double rawTP = price - currentATR * tpMultiplier;

   // Adjust SL to be at least stopLevelPrice above Ask price
   double adjustedSL = MathMax(rawSL, ask + stopLevelPrice);

   // Adjust TP to be at least stopLevelPrice below Bid price
   double adjustedTP = MathMin(rawTP, price - stopLevelPrice);

   // Normalize prices
   adjustedSL = NormalizeDouble(adjustedSL, _Digits);
   adjustedTP = NormalizeDouble(adjustedTP, _Digits);
   price = NormalizeDouble(price, _Digits); // Normalize entry price too

   // Ensure TP is not zero or negative if adjustedTP becomes invalid
   if(adjustedTP <= 0)
      adjustedTP = 0; // Set TP to 0 (no TP) if calculation is invalid

   trade.Sell(lotSize, _Symbol, price, adjustedSL, adjustedTP, "Initial Sell");
}

//+------------------------------------------------------------------+
//| Place hedge pending order                                        |
//+------------------------------------------------------------------+
void PlaceHedgeOrder(ENUM_POSITION_TYPE type, double distancePrice, double lotSize, 
                     double slMultiplier, double tpMultiplier)
{
   CTrade trade;
   double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double hedgePrice = (type == POSITION_TYPE_BUY) ? currentPrice + distancePrice : currentPrice - distancePrice;
   double currentATR = atr[0];
   double sl = (type == POSITION_TYPE_BUY) ? hedgePrice - currentATR * slMultiplier : hedgePrice + currentATR * slMultiplier;
   double tp = (type == POSITION_TYPE_BUY) ? hedgePrice + currentATR * tpMultiplier : hedgePrice - currentATR * tpMultiplier;
   
   if(type == POSITION_TYPE_BUY)
      trade.BuyStop(lotSize, hedgePrice, _Symbol, sl, tp, 0, 0, "Hedge Buy Stop");
   else
      trade.SellStop(lotSize, hedgePrice, _Symbol, sl, tp, 0, 0, "Hedge Sell Stop");
}

//+------------------------------------------------------------------+
//| Place strategic pending order                                    |
//+------------------------------------------------------------------+
void PlacePendingOrder(ENUM_ORDER_TYPE type, double distancePrice, double lotSize, 
                       double slMultiplier, double tpMultiplier)
{
   CTrade trade;
   double currentPrice = (type == ORDER_TYPE_BUY_STOP) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double pendingPrice = (type == ORDER_TYPE_BUY_STOP) ? currentPrice + distancePrice : currentPrice - distancePrice;
   double currentATR = atr[0];
   double sl = (type == ORDER_TYPE_BUY_STOP) ? pendingPrice - currentATR * slMultiplier : pendingPrice + currentATR * slMultiplier;
   double tp = (type == ORDER_TYPE_BUY_STOP) ? pendingPrice + currentATR * tpMultiplier : pendingPrice - currentATR * tpMultiplier;
   
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
         ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double currentPrice = (positionType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK); // Get current price based on position type
         double sl = PositionGetDouble(POSITION_SL);
         double currentATR = atr[0];
         double profitInPips = (positionType == POSITION_TYPE_BUY ?
                                (currentPrice - entryPrice) : (entryPrice - currentPrice)) / pipValue;
         
         // Move SL to breakeven
         if(profitInPips > BreakevenPips && sl != entryPrice)
         {
            CTrade trade;
            double newSL = entryPrice;
            double tp = PositionGetDouble(POSITION_TP);
            trade.PositionModify(ticket, newSL, tp);
         }
         
         // Trailing stop
         double trailingSL = (positionType == POSITION_TYPE_BUY) ?
                            currentPrice - currentATR * 1.5 : currentPrice + currentATR * 1.5;
         if((positionType == POSITION_TYPE_BUY && trailingSL > sl) ||
            (positionType == POSITION_TYPE_SELL && trailingSL < sl))
         {
            CTrade trade;
            double tp = PositionGetDouble(POSITION_TP);
            trade.PositionModify(ticket, trailingSL, tp);
         }
         
         // Recovery trade logic
         if(profitInPips < -RecoveryThreshold && PositionsTotal() < MaxPositions)
         {
            double lotSize = PositionGetDouble(POSITION_VOLUME) * 2;
            bool isTrending = adx[0] > 25;
            double slMultiplier = isTrending ? 1.0 : 2.0;
            double tpMultiplier = isTrending ? 3.0 : 1.0;
            if(positionType == POSITION_TYPE_BUY)
               OpenBuyTrade(lotSize, slMultiplier, tpMultiplier);
            else
               OpenSellTrade(lotSize, slMultiplier, tpMultiplier);
         }
      }
   }
}