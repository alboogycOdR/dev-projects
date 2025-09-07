// **4. Strategy Execution Module**

// *   **Path:** `...\MQL5\Include\ScalpEA\ScalpEA_StrategyExecution.mqh`
// *   **Filename:** `ScalpEA_StrategyExecution.mqh`

// ```mql5
//+------------------------------------------------------------------+
//| ScalpEA_StrategyExecution.mqh                                    |
//| Strategy Execution Module for Scalp EA                           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.example.com"
#property strict

// Include required libraries
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Strategy Execution Class
class CStrategyExecution
  {
private:
   // Configuration Parameters
   double            m_riskPercent;       // Risk per trade (%)
   int               m_maxTrades;         // Maximum concurrent trades
   bool              m_useMarketOrders;   // Use market orders (true) or pending orders (false)
   int               m_pendingDistance;   // Distance for pending orders (points)
   int               m_maxSpread;         // Maximum allowed spread (points, 0=off)
   ulong             m_magicNumber;       // Magic number for EA trades

   // Objects
   CTrade            m_trade;         // Trade object
   CSymbolInfo       m_symbolInfo;    // SymbolInfo object
   CPositionInfo     m_posInfo;       // PositionInfo object
   COrderInfo        m_orderInfo;     // OrderInfo object
   CAccountInfo      m_accountInfo;   // AccountInfo object

   // Internal state
   bool              m_isInitialized;
   string            m_symbol;

   // Calculate lot size based on risk % and SL distance in points
   double            CalculateLotSize(double stopLossPoints)
     {
      if(stopLossPoints<=0 || m_riskPercent<=0) { /*Print("CalcLot Err: SL pts or Risk% invalid.");*/ return 0.0; }
      if(!m_symbolInfo.Name(m_symbol)) { /*Print("CalcLot Err: SymbolInfo not set.");*/ return 0.0; }
      //m_accountInfo.Refresh();
      double equity = m_accountInfo.Equity();
      if(equity<=0) {/*Print("CalcLot Err: Bad Equity.");*/ return 0.0;}
      double riskAmount = equity * (m_riskPercent / 100.0);
      double tickVal=m_symbolInfo.TickValue();
      double tickSize=m_symbolInfo.TickSize();
      double pnt=m_symbolInfo.Point();
      if(tickSize<=0||pnt<=0||tickVal<=0) { /*Print("CalcLot Err: Bad tick/point props.");*/ return 0.0; }
      double pointValuePerLot = tickVal / (tickSize / pnt);
      if(pointValuePerLot<=0) {/*Print("CalcLot Err: Bad PointVal.");*/ return 0.0;}
      double riskPerLot = stopLossPoints * pointValuePerLot;
      if(riskPerLot<=0) {/*Print("CalcLot Err: Bad RiskPerLot.");*/ return 0.0;}
      double lotSize = riskAmount / riskPerLot;
      double minL=m_symbolInfo.LotsMin();
      double maxL=m_symbolInfo.LotsMax();
      double stepL=m_symbolInfo.LotsStep();
      if(stepL<=0) {/*Print("CalcLot Err: Bad LotStep.");*/ return 0.0;}
      lotSize=MathFloor(lotSize/stepL)*stepL;
      lotSize=MathMax(minL,lotSize);
      lotSize=MathMin(maxL,lotSize);
      if(lotSize<minL||lotSize>maxL) {/*Print("CalcLot Err: Lot outside limits [",minL,"-",maxL,"]. Calc:",lotSize);*/ return 0.0;}
      //Print("CalcLot: SLpts=",stopLossPoints," RiskAmt=",riskAmount," PointVal=",pointValuePerLot," Lot=",lotSize);
      return lotSize;
     }

   // Calculate stop loss distance in points
   double            CalculateStopLossPoints(double entryPrice, double stopLossPrice, ENUM_ORDER_TYPE orderType)
     {
      if(entryPrice<=0 || stopLossPrice<=0)
         return 0.0;
      if(!m_symbolInfo.Name(m_symbol))
        {
         return 0.0;
        }
      double pnt=m_symbolInfo.Point();
      if(pnt<=0)
         return 0.0;
      double points=0;
      bool isBuy=(orderType==ORDER_TYPE_BUY||orderType==ORDER_TYPE_BUY_STOP||orderType==ORDER_TYPE_BUY_LIMIT);
      if(isBuy && stopLossPrice<entryPrice)
         points=(entryPrice-stopLossPrice)/pnt;
      else
         if(!isBuy && stopLossPrice>entryPrice)
            points=(stopLossPrice-entryPrice)/pnt;
      return MathMax(0.0,points);
     }

   // Check core trading conditions before attempting an order
   bool              ValidateTradeConditions(string direction, double &entryPrice, double &stopLoss, double &takeProfit)
     {
      if(!m_isInitialized)
         return false;
      if(!m_symbolInfo.Name(m_symbol) || !m_symbolInfo.RefreshRates())
         return false;
      //if (!m_symbolInfo.Trade()) { /*Print("Val Cond Err: Trading disabled for ", m_symbol);*/ return false; }
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) { /*Print("Val Cond Err: Trading disabled in Terminal.");*/ return false; }
      int spread = (int)m_symbolInfo.Spread();
      if(m_maxSpread > 0 && spread > m_maxSpread) { /*Print("Val Cond Err: Spread ",spread," > Max ",m_maxSpread);*/ return false; }
      if(CountOpenTrades() >= m_maxTrades) { /*Print("Val Cond Err: Max trades ",m_maxTrades," reached.");*/ return false; }
      if(direction != "BUY" && direction != "SELL") { /*Print("Val Cond Err: Bad direction ",direction);*/ return false; }
      double ask=m_symbolInfo.Ask();
      double bid=m_symbolInfo.Bid();
      if(entryPrice <= 0)
         entryPrice = (direction == "BUY") ? ask : bid; // Default entry to market
      if(stopLoss <= 0) { /*Print("Val Cond Err: Invalid SL <= 0.");*/ return false; }
      if((direction == "BUY" && stopLoss >= entryPrice) || (direction == "SELL" && stopLoss <= entryPrice)) { /*Print("Val Cond Err: SL wrong side of entry.");*/ return false; }
      if(takeProfit > 0 && ((direction == "BUY" && takeProfit <= entryPrice) || (direction == "SELL" && takeProfit >= entryPrice))) { /*Print("Val Cond Err: TP wrong side of entry.");*/ return false; }
      // Check Stops Level (distance from current market price)
      double stopsLevelPts = (double)m_symbolInfo.StopsLevel();
      if(stopsLevelPts<1)
         stopsLevelPts=1;
      double minDist = stopsLevelPts * m_symbolInfo.Point();
      if(direction == "BUY")
        {
         if((ask - stopLoss) < minDist) { /*Print("Val Cond Err: SL too close to Ask. Need ",minDist," Have ",(ask-stopLoss));*/ return false; }
         if(takeProfit > 0 && (takeProfit - ask) < minDist) { /*Print("Val Cond Err: TP too close to Ask.");*/ return false; }
        }
      else     // SELL
        {
         if((stopLoss - bid) < minDist) { /*Print("Val Cond Err: SL too close to Bid.");*/ return false; }
         if(takeProfit > 0 && (bid - takeProfit) < minDist) { /*Print("Val Cond Err: TP too close to Bid.");*/ return false; }
        }
      return true;
     }

public:
                     CStrategyExecution() { m_isInitialized = false; m_riskPercent = 1.0; m_maxTrades = 3; m_useMarketOrders = true; m_pendingDistance = 10; m_maxSpread = 30; m_magicNumber = 0; m_symbol = ""; }
                    ~CStrategyExecution() {}

   // Count current open trades for this EA/symbol/magic
   int               CountOpenTrades()
     {
      if(!m_isInitialized)
         return 0;
      int count=0;
      int total=PositionsTotal();
      for(int i=0; i<total; i++)
        {
         ulong t=PositionGetTicket(i);
         if(t>0 && m_posInfo.Select(t))
           {
            if(m_posInfo.Symbol()==m_symbol && m_posInfo.Magic()==m_magicNumber)
               count++;
           }
        }
      return count;
     }

   // Count current pending orders for this EA/symbol/magic
   int               CountPendingOrders()
     {
      if(!m_isInitialized)
         return 0;
      int count=0;
      int total=OrdersTotal();
      for(int i=0; i<total; i++)
        {
         ulong t=OrderGetTicket(i);
         if(t>0 && m_orderInfo.Select(t))
           {
            if(m_orderInfo.Symbol()==m_symbol && m_orderInfo.Magic()==m_magicNumber)
              {
               ENUM_ORDER_TYPE type=m_orderInfo.OrderType();
               if(type>=ORDER_TYPE_BUY_LIMIT && type<=ORDER_TYPE_SELL_STOP_LIMIT)
                  count++;
              }
           }
        }
      return count;
     }

   // Initialize the module
   bool              Initialize(double riskPercent, int maxTrades, bool useMarketOrders, int pendingDistance, int maxSpread, ulong magicNumber, string symbol)
     {
      m_symbol=symbol;
      if(!m_symbolInfo.Name(m_symbol))
        {
         Print("StratExec Init Err: Bad Symbol ", m_symbol);
         return false;
        }
      m_symbolInfo.RefreshRates();
      m_riskPercent = riskPercent > 0 ? riskPercent : 1.0;
      m_maxTrades = maxTrades > 0 ? maxTrades : 1;
      m_useMarketOrders = useMarketOrders;
      m_pendingDistance = pendingDistance > 0 ? pendingDistance : 10;
      m_maxSpread = maxSpread >= 0 ? maxSpread : 30;
      m_magicNumber = magicNumber;
      m_trade.SetExpertMagicNumber(m_magicNumber);
      m_trade.SetDeviationInPoints(5);
      m_trade.SetTypeFillingBySymbol(m_symbol);
      //m_accountInfo.Refresh(); TODO
      m_isInitialized = true;
      //Print("Strategy Execution Initialized: ", m_symbol, " Magic:", m_magicNumber);
      return true;
     }

   // Execute a trade based on validated inputs
   ulong             ExecuteTrade(string direction, double entryPrice, double stopLoss, double takeProfit)
     {
      if(!m_isInitialized)
         return 0;
      m_symbolInfo.RefreshRates();
      if(!ValidateTradeConditions(direction, entryPrice, stopLoss, takeProfit))
         return 0; // Re-validate here
      ENUM_ORDER_TYPE typeForCalc = (direction == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double slPoints = CalculateStopLossPoints(entryPrice, stopLoss, typeForCalc);
      if(slPoints <= 0)
        {
         Print("ExecTrade Err: Bad SL Points ", slPoints);
         return 0;
        }
      double lotSize = CalculateLotSize(slPoints);
      if(lotSize <= 0)
        {
         Print("ExecTrade Err: Bad Lot Size ", lotSize);
         return 0;
        }
      ulong ticket = 0;
      string comment = "ScalpEA " + direction;
      if(m_useMarketOrders)
        {
         // Print("ExecTrade: Attempt Market ", direction, " ", lotSize, " SL:", stopLoss, " TP:", takeProfit);
         if(direction == "BUY")
           {
            if(m_trade.Buy(lotSize, m_symbol, 0, stopLoss, takeProfit, comment))
               ticket = m_trade.ResultOrder();
           }
         else
           {
            if(m_trade.Sell(lotSize, m_symbol, 0, stopLoss, takeProfit, comment))
               ticket = m_trade.ResultOrder();
           }
         if(ticket==0)
            Print("ExecTrade: Market ", direction, " FAILED! Error: ", m_trade.ResultRetcode(), " - ", m_trade.ResultComment());
         // else Print("ExecTrade: Market ", direction, " OK. Ticket: ", ticket);
        }
      else
        {
         double point = m_symbolInfo.Point();
         double pendPrice = 0;
         ENUM_ORDER_TYPE pendType;
         double stopsLevelPts=(double)m_symbolInfo.StopsLevel();
         double freezeLevelPts=(double)m_symbolInfo.FreezeLevel();
         if(freezeLevelPts<=0)
            freezeLevelPts=stopsLevelPts;
         double minDistMarket=freezeLevelPts*point;
         if(minDistMarket<=point)
            minDistMarket=point*2.0; // Ensure min 2 points freeze distance
         double minDistStops=stopsLevelPts*point;
         if(minDistStops<=point)
            minDistStops=point*2.0;
         double ask=m_symbolInfo.Ask();
         double bid=m_symbolInfo.Bid();
         if(direction == "BUY")
           {
            pendPrice = ask + m_pendingDistance * point;
            pendType = ORDER_TYPE_BUY_STOP;
            if((pendPrice-ask)<minDistMarket)
              {
               Print("ExecTrade Err: BuyStop price too close to Ask.");
               return 0;
              }
            if((pendPrice-stopLoss)<minDistStops)
              {
               Print("ExecTrade Err: BuyStop SL too close to PendPrice.");
               return 0;
              }
            if(takeProfit>0 && (takeProfit-pendPrice)<minDistStops)
              {
               Print("ExecTrade Err: BuyStop TP too close.");
               return 0;
              }
           }
         else
           {
            pendPrice = bid - m_pendingDistance * point;
            pendType = ORDER_TYPE_SELL_STOP;
            if((bid-pendPrice)<minDistMarket)
              {
               Print("ExecTrade Err: SellStop price too close to Bid.");
               return 0;
              }
            if((stopLoss-pendPrice)<minDistStops)
              {
               Print("ExecTrade Err: SellStop SL too close.");
               return 0;
              }
            if(takeProfit>0 && (pendPrice-takeProfit)<minDistStops)
              {
               Print("ExecTrade Err: SellStop TP too close.");
               return 0;
              }
           }
         pendPrice = NormalizeDouble(pendPrice, m_symbolInfo.Digits());
         // Print("ExecTrade: Attempt Pend ", EnumToString(pendType), " ", lotSize, " at ", pendPrice, " SL:", stopLoss, " TP:", takeProfit);
         if(m_trade.OrderOpen(m_symbol, pendType, lotSize, pendPrice, stopLoss, takeProfit, ORDER_TIME_GTC, 0, comment))
            ticket = m_trade.ResultOrder();
         if(ticket==0)
            Print("ExecTrade: Pending ", EnumToString(pendType), " FAILED! Error: ", m_trade.ResultRetcode(), " - ", m_trade.ResultComment());
         // else Print("ExecTrade: Pending ", EnumToString(pendType), " OK. Ticket: ", ticket);
        }
      return ticket;
     }

   // Close a specific trade
   bool              CloseTrade(ulong ticket, string reason = "")
     {
      if(!m_isInitialized || ticket <= 0)
         return false;
      if(!m_posInfo.Select(ticket))
         return false; // Already closed or invalid
      if(m_posInfo.Symbol() != m_symbol || m_posInfo.Magic() != m_magicNumber)
         return false; // Not ours
      //Print("CloseTrade: Attempt closing #", ticket, " Reason: ", reason);
      if(!m_trade.PositionClose(ticket))
        {
         Print("CloseTrade: FAILED closing #", ticket, "! Error: ", m_trade.ResultRetcode(), " - ", m_trade.ResultComment());
         return false;
        }
      //Print("CloseTrade: Closed #", ticket, " successfully. Reason: ", reason);
      return true;
     }

   // Close all trades for this EA instance
   void              CloseAllTrades(string reason = "")
     {
      if(!m_isInitialized)
         return;
      int closedCount=0;
      int total=PositionsTotal();
      //Print("CloseAllTrades: Closing ", total, " positions (Magic:", m_magicNumber, "). Reason: ", reason);
      for(int i=total-1; i>=0; i--)
        {
         ulong t=PositionGetTicket(i);   // Small delay
         if(t>0 && m_posInfo.Select(t))
           {
            if(m_posInfo.Symbol()==m_symbol && m_posInfo.Magic()==m_magicNumber)
              {
               if(CloseTrade(t, reason))
                  closedCount++;
               Sleep(50);
              }
           }
        }
      //if(total > 0) Print("CloseAllTrades: Finished. Closed ", closedCount, " positions.");
     }

   // Cancel all pending orders for this EA instance
   void              CancelAllPendingOrders(string reason = "")
     {
      if(!m_isInitialized)
         return;
      int deletedCount=0;
      int total=OrdersTotal();
      //Print("CancelAllPending: Cancelling ", total, " orders (Magic:", m_magicNumber, "). Reason: ", reason);
      for(int i=total-1; i>=0; i--)
        {
         ulong t=OrderGetTicket(i);
         if(t>0 && m_orderInfo.Select(t))
           {
            if(m_orderInfo.Symbol()==m_symbol && m_orderInfo.Magic()==m_magicNumber)
              {
               ENUM_ORDER_TYPE type=m_orderInfo.OrderType();
               if(type>=ORDER_TYPE_BUY_LIMIT && type<=ORDER_TYPE_SELL_STOP_LIMIT) { /*Print("CancelAllPending: Deleting #", t);*/ if(m_trade.OrderDelete(t)) deletedCount++; else Print("CancelAllPending: FAILED deleting #", t, "! Error: ", m_trade.ResultRetcode(), " - ", m_trade.ResultComment()); Sleep(50); }
              }
           }
        }
      //if(total > 0) Print("CancelAllPending: Finished. Deleted ", deletedCount, " orders.");
     }

   // Get current risk exposure %
   double            GetCurrentRiskExposure()
     {
      if(!m_isInitialized)
         return 0.0;
      //m_accountInfo.Refresh();
      RefreshRates();
      double equity = m_accountInfo.Equity();
      if(equity <= 0)
         return 0.0;
      if(!m_symbolInfo.Name(m_symbol))
        {
         return 0.0;
        }
      double pnt=m_symbolInfo.Point();
      double tickVal=m_symbolInfo.TickValue();
      double tickSize=m_symbolInfo.TickSize();
      if(pnt<=0||tickVal<=0||tickSize<=0)
        {
         return 0.0;
        }
      double pointValuePerLot=tickVal/(tickSize/pnt);
      double totalRiskAmount=0;
      int totalPos=PositionsTotal();
      for(int i=0; i<totalPos; i++)
        {
         ulong t=PositionGetTicket(i);
         if(t>0 && m_posInfo.Select(t))
           {
            if(m_posInfo.Symbol()==m_symbol && m_posInfo.Magic()==m_magicNumber)
              {
               double entry=m_posInfo.PriceOpen();
               double sl=m_posInfo.StopLoss();
               double vol=m_posInfo.Volume();
               ENUM_POSITION_TYPE pt=m_posInfo.PositionType();
               if(sl > 0)
                 {
                  double slPts = 0;
                  if(pt == POSITION_TYPE_BUY && sl < entry)
                     slPts = (entry - sl) / pnt;
                  else
                     if(pt == POSITION_TYPE_SELL && sl > entry)
                        slPts = (sl - entry) / pnt;
                  if(slPts > 0)
                     totalRiskAmount += slPts * pointValuePerLot * vol;
                 }
              }
           }
        }
      return (totalRiskAmount / equity) * 100.0;
     }

   // Modify SL/TP for an existing position
   bool              ModifyPosition(ulong ticket, double newStopLoss, double newTakeProfit)
     {
      if(!m_isInitialized || ticket <= 0)
         return false;
      if(!m_posInfo.Select(ticket))
         return false;
      if(m_posInfo.Symbol() != m_symbol || m_posInfo.Magic() != m_magicNumber)
         return false;
      if(!m_symbolInfo.RefreshRates())
         return false; // Need fresh rates for validation
      double currentSL=m_posInfo.StopLoss();
      double currentTP=m_posInfo.TakeProfit();
      if(newStopLoss<=0)
         newStopLoss=currentSL;
      if(newTakeProfit<=0)
         newTakeProfit=currentTP; // Use current if new is invalid
      double pnt=m_symbolInfo.Point();
      if(MathAbs(newStopLoss-currentSL)<pnt && MathAbs(newTakeProfit-currentTP)<pnt)
         return true; // No change needed
      // Validate new levels (stops level, directionality)
      ENUM_POSITION_TYPE posType = m_posInfo.PositionType();
      double price = (posType == POSITION_TYPE_BUY) ? m_symbolInfo.Bid() : m_symbolInfo.Ask();
      double stopsLevelPts = (double)m_symbolInfo.StopsLevel();
      if(stopsLevelPts<1)
         stopsLevelPts=1;
      double minDist = stopsLevelPts * pnt;
      if(newStopLoss>0)
        {
         if(((posType==POSITION_TYPE_BUY && newStopLoss>=price) || (posType==POSITION_TYPE_SELL && newStopLoss<=price)))
           {
            Print("Modify Err: New SL ",newStopLoss," wrong side of price ",price," for #",ticket);
            return false;
           }
         if(((posType==POSITION_TYPE_BUY && (price-newStopLoss)<minDist) || (posType==POSITION_TYPE_SELL && (newStopLoss-price)<minDist)))
           {
            Print("Modify Err: New SL ",newStopLoss," too close to price ",price," for #",ticket);
            return false;
           }
        }
      if(newTakeProfit>0)
        {
         if(((posType==POSITION_TYPE_BUY && newTakeProfit<=price) || (posType==POSITION_TYPE_SELL && newTakeProfit>=price)))
           {
            Print("Modify Err: New TP ",newTakeProfit," wrong side of price ",price," for #",ticket);
            return false;
           }
         if(((posType==POSITION_TYPE_BUY && (newTakeProfit-price)<minDist) || (posType==POSITION_TYPE_SELL && (price-newTakeProfit)<minDist)))
           {
            Print("Modify Err: New TP ",newTakeProfit," too close to price ",price," for #",ticket);
            return false;
           }
        }
      //Print("Modify Attempt #", ticket, ": New SL=", newStopLoss, " New TP=", newTakeProfit);
      if(!m_trade.PositionModify(ticket, newStopLoss, newTakeProfit))
        {
         Print("Modify FAILED #", ticket, "! Error: ", m_trade.ResultRetcode(), " - ", m_trade.ResultComment());
         return false;
        }
      //Print("Modify OK #", ticket, ". New SL:",DoubleToString(newStopLoss,m_symbolInfo.Digits())," TP:",DoubleToString(newTakeProfit,m_symbolInfo.Digits()));
      return true;
     }

   // Execute Market Order (direct, uses provided volume)
   ulong             ExecuteMarketOrder(string direction, double volume, double stopLoss, double takeProfit)
     {
      if(!m_isInitialized || volume <= 0)
         return 0;
      // Simplified Validation for direct order: Spread, MaxTrades
      m_symbolInfo.RefreshRates();
      int spread = (int)m_symbolInfo.Spread();
      if(m_maxSpread>0 && spread > m_maxSpread)
         return 0;
      if(CountOpenTrades() >= m_maxTrades)
         return 0;
      if(direction!="BUY" && direction!="SELL")
         return 0;
      // Add SL/TP validation against current market
      double ask=m_symbolInfo.Ask();
      double bid=m_symbolInfo.Bid();
      double stopsLvl=(double)m_symbolInfo.StopsLevel();
      if(stopsLvl<1)
         stopsLvl=1;
      double minD=stopsLvl*m_symbolInfo.Point();
      if(direction=="BUY")
        {
         if(stopLoss>0 && (ask-stopLoss)<minD)
            return 0;
         if(takeProfit>0 && (takeProfit-ask)<minD)
            return 0;
        }
      else
        {
         if(stopLoss>0 && (stopLoss-bid)<minD)
            return 0;
         if(takeProfit>0 && (bid-takeProfit)<minD)
            return 0;
        }
      // Execution
      ulong ticket = 0;
      string cmt = "ScalpEA Mkt " + direction;
      if(direction=="BUY")
        {
         if(m_trade.Buy(volume,m_symbol,0,stopLoss,takeProfit,cmt))
            ticket=m_trade.ResultOrder();
        }
      else
        {
         if(m_trade.Sell(volume,m_symbol,0,stopLoss,takeProfit,cmt))
            ticket=m_trade.ResultOrder();
        }
      if(ticket==0)
         Print("ExecMarket FAILED: ", m_trade.ResultRetcode(), " ", m_trade.ResultComment());
      // else Print("ExecMarket OK: ",direction," Vol:",volume," Ticket:",ticket);
      return ticket;
     }

   // Execute Pending Order (direct)
   ulong             ExecutePendingOrder(ENUM_ORDER_TYPE orderType, double volume, double price, double stopLoss, double takeProfit, datetime expiration = 0)
     {
      if(!m_isInitialized || volume <= 0 || price <= 0)
         return 0;
      if(orderType < ORDER_TYPE_BUY_LIMIT || orderType > ORDER_TYPE_SELL_STOP_LIMIT)
         return 0; // Validate type
      // Simplified Validation: Spread, MaxTrades+Pending
      m_symbolInfo.RefreshRates();
      int spread = (int)m_symbolInfo.Spread();
      if(m_maxSpread>0 && spread > m_maxSpread)
         return 0;
      if((CountOpenTrades()+CountPendingOrders())>=m_maxTrades)
         return 0;
      // Add validation for price/sl/tp against market & stops/freeze levels (complex - see ExecuteTrade for example)
      // Basic check:
      bool isBuy = (orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT);
      if(isBuy)
        {
         if(stopLoss>0 && stopLoss>=price)
            return 0;
         if(takeProfit>0 && takeProfit<=price)
            return 0;
        }
      else
        {
         if(stopLoss>0 && stopLoss<=price)
            return 0;
         if(takeProfit>0 && takeProfit>=price)
            return 0;
        }
      // Execution
      ulong ticket = 0;
      string cmt = "ScalpEA Pend " + EnumToString(orderType);
      ENUM_ORDER_TYPE_TIME timeType = (expiration==0)?ORDER_TIME_GTC:ORDER_TIME_SPECIFIED;
      if(m_trade.OrderOpen(m_symbol, orderType, volume, price,price, stopLoss, takeProfit, timeType, expiration, cmt))
         ticket = m_trade.ResultOrder();
      if(ticket==0)
         Print("ExecPending FAILED: ", m_trade.ResultRetcode(), " ", m_trade.ResultComment());
      // else Print("ExecPending OK: ",EnumToString(orderType)," Vol:",volume," Ticket:",ticket);
      return ticket;
     }

   // Get total profit/loss for EA's open positions
   double            GetTotalProfit()
     {
      if(!m_isInitialized)
         return 0.0;
      double totalProfit=0;
      int total=PositionsTotal();
      for(int i=0; i<total; i++)
        {
         ulong t=PositionGetTicket(i);
         if(t>0 && m_posInfo.Select(t))
           {
            if(m_posInfo.Symbol()==m_symbol && m_posInfo.Magic()==m_magicNumber)
              {
               totalProfit += m_posInfo.Profit() + m_posInfo.Swap() + m_posInfo.Commission();
              }
           }
        }
      return totalProfit; // Include swap/comm
     }

   // Getters for config/state
   CTrade*           GetTradeObject() { return &m_trade; }
   double            GetRiskPercent() const { return m_riskPercent; }
   int               GetMaxTrades()   const { return m_maxTrades; }
   ulong             GetMagicNumber() const { return m_magicNumber; }
   string            GetSymbol()      const { return m_symbol; }

  };
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
