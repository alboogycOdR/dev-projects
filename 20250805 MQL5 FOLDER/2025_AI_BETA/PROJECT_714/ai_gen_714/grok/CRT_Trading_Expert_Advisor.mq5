//+------------------------------------------------------------------+
//| Expert Advisor: CRT Trading System                               |
//| Developer: Senior Forex Developer with CRT Expertise             |
//| Version: 1.0                                                     |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>
CTrade Trade;

// Input Parameters
input ENUM_TIMEFRAMES MainTimeframe = PERIOD_H4;         // Main Timeframe
input ENUM_TIMEFRAMES SubTimeframe = PERIOD_M15;         // Sub Timeframe for Nested CRT
input double RiskPercent = 1.0;                          // Risk per Trade (%)
input double MinRRRatio = 2.0;                           // Minimum Risk-Reward Ratio
input int MaxTradesPerDay = 5;                           // Max Trades per Day
input int MaxTradesPerSession = 3;                       // Max Trades per Session
input double MaxSpread = 20.0;                           // Max Allowable Spread (points)
input int GMTOffset = 2;                                 // Broker GMT Offset (hours)
input bool EnableSoundAlerts = true;                     // Enable Sound Alerts
input bool EnableEmailAlerts = false;                    // Enable Email Alerts
input bool EnablePushAlerts = false;                     // Enable Push Notifications

enum ENUM_ENTRY_METHOD
{
   ENTRY_TURTLE_SOUP,
   ENTRY_ORDER_BLOCK,
   ENTRY_THIRD_CANDLE,
   ENTRY_AUTO_BEST
};

enum ENUM_TRADE_MODE
{
   MODE_AUTO,
   MODE_MANUAL,
   MODE_HYBRID
};

enum ENUM_CRT_PHASE
{
   PHASE_ACCUMULATION,
   PHASE_MANIPULATION,
   PHASE_DISTRIBUTION
};

input ENUM_ENTRY_METHOD EntryMethod = ENTRY_ORDER_BLOCK; // Entry Method
input ENUM_TRADE_MODE TradeMode = MODE_AUTO;             // Trade Mode

// Trade Management Structure
struct TRADE_INFO
{
   ulong ticketTP1;    // Ticket for TP1 trade
   ulong ticketTP2;    // Ticket for TP2 trade
   int tradeType;      // POSITION_TYPE_BUY or POSITION_TYPE_SELL
   bool tp1Closed;     // Flag for TP1 closure
};

TRADE_INFO activeTrades[];

// Global Variables
int tradesToday = 0;
int tradesSession = 0;
datetime lastDay = 0;
int atrHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(Period() != MainTimeframe)
   {
      Alert("Please attach the EA to an H4 chart.");
      return INIT_FAILED;
   }
   
   // Initialize ATR indicator handle
   atrHandle = iATR(_Symbol, MainTimeframe, 14);
   if(atrHandle == INVALID_HANDLE)
   {
      Alert("Failed to create ATR indicator handle");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(activeTrades, true);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Reset daily trade count if new day
   datetime currentDay = TimeCurrent() / 86400;
   if(currentDay != lastDay)
   {
      tradesToday = 0;
      tradesSession = 0;
      lastDay = currentDay;
   }

   // Check trading conditions
   if(!IsTradingAllowed()) return;

   // Detect CRT phase on H4
   ENUM_CRT_PHASE h4Phase = DetectCRTPhase(MainTimeframe);
   ENUM_CRT_PHASE m15Phase = DetectCRTPhase(SubTimeframe);

   // Update dashboard
   UpdateDashboard(h4Phase);

   // Check entry conditions based on method
   CheckEntryConditions(h4Phase, m15Phase);

   // Manage active trades for trailing stops
   ManageActiveTrades();
}

//+------------------------------------------------------------------+
//| Check if Trading is Allowed                                      |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > MaxSpread) return false;
   if(tradesToday >= MaxTradesPerDay) return false;
   if(tradesSession >= MaxTradesPerSession) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Detect CRT Phase (Simplified)                                    |
//+------------------------------------------------------------------+
ENUM_CRT_PHASE DetectCRTPhase(ENUM_TIMEFRAMES timeframe)
{
   double atr[];
   ArraySetAsSeries(atr, true);
   
   if(CopyBuffer(atrHandle, 0, 1, 1, atr) <= 0)
      return PHASE_ACCUMULATION;
      
   double range = iHigh(_Symbol, timeframe, 1) - iLow(_Symbol, timeframe, 1);
   double close = iClose(_Symbol, timeframe, 1);
   double open = iOpen(_Symbol, timeframe, 1);

   if(range < atr[0] && close > open) return PHASE_ACCUMULATION;
   if(range > atr[0] * 1.5) return PHASE_MANIPULATION;
   if(range < atr[0] && close < open) return PHASE_DISTRIBUTION;
   return PHASE_ACCUMULATION; // Default
}

//+------------------------------------------------------------------+
//| Check Entry Conditions                                           |
//+------------------------------------------------------------------+
void CheckEntryConditions(ENUM_CRT_PHASE h4Phase, ENUM_CRT_PHASE m15Phase)
{
   if(EntryMethod == ENTRY_ORDER_BLOCK)
   {
      ORDER_BLOCK ob = FindLastOrderBlock();
      if(ob.shift > 0)
      {
         double closeM15Prev = iClose(_Symbol, SubTimeframe, 1);
         double closeM15Curr = iClose(_Symbol, SubTimeframe, 0);

         if(ob.isBullish && m15Phase != PHASE_DISTRIBUTION)
         {
            double orderBlockLow = iLow(_Symbol, MainTimeframe, ob.shift);
            if(closeM15Prev < orderBlockLow && closeM15Curr > orderBlockLow)
            {
               ExecuteTrade(ORDER_TYPE_BUY, "Order Block Buy");
            }
         }
         else if(!ob.isBullish && m15Phase != PHASE_ACCUMULATION)
         {
            double orderBlockHigh = iHigh(_Symbol, MainTimeframe, ob.shift);
            if(closeM15Prev > orderBlockHigh && closeM15Curr < orderBlockHigh)
            {
               ExecuteTrade(ORDER_TYPE_SELL, "Order Block Sell");
            }
         }
      }
   }
   // Add other entry methods (e.g., Turtle Soup, Third Candle) here if needed
}

//+------------------------------------------------------------------+
//| Identify Order Block                                             |
//+------------------------------------------------------------------+
struct ORDER_BLOCK
{
   int shift;
   bool isBullish;
};

ORDER_BLOCK FindLastOrderBlock()
{
   ORDER_BLOCK ob;
   ob.shift = -1;
   for(int i = 1; i < 100; i++)
   {
      if(IsOrderBlock(i))
      {
         ob.shift = i;
         ob.isBullish = iClose(_Symbol, MainTimeframe, i) > iOpen(_Symbol, MainTimeframe, i);
         break;
      }
   }
   return ob;
}

bool IsOrderBlock(int shift)
{
   double body = MathAbs(iOpen(_Symbol, MainTimeframe, shift) - iClose(_Symbol, MainTimeframe, shift));
   double wickHigh = iHigh(_Symbol, MainTimeframe, shift) - MathMax(iOpen(_Symbol, MainTimeframe, shift), iClose(_Symbol, MainTimeframe, shift));
   double wickLow = MathMin(iOpen(_Symbol, MainTimeframe, shift), iClose(_Symbol, MainTimeframe, shift)) - iLow(_Symbol, MainTimeframe, shift);
   
   double atr[];
   ArraySetAsSeries(atr, true);
   
   if(CopyBuffer(atrHandle, 0, shift, 1, atr) <= 0)
      return false;

   return (body > 2 * atr[0] && wickHigh < 0.2 * body && wickLow < 0.2 * body);
}

//+------------------------------------------------------------------+
//| Execute Trade with Partial Take Profits                          |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE type, string comment)
{
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slPips = 50; // Example SL distance in pips, adjust based on strategy
   double sl = (type == ORDER_TYPE_BUY) ? price - slPips * _Point : price + slPips * _Point;
   double tp1 = (type == ORDER_TYPE_BUY) ? price + slPips * _Point : price - slPips * _Point;
   double tp2 = (type == ORDER_TYPE_BUY) ? price + slPips * 2 * _Point : price - slPips * 2 * _Point;

   double lotSize = CalculateLotSize(slPips);
   double lotSize1 = lotSize / 2;
   double lotSize2 = lotSize / 2;

   if(TradeMode == MODE_AUTO)
   {
      bool result1 = Trade.Buy(lotSize1, _Symbol, price, sl, tp1, "TP1 " + comment);
      bool result2 = Trade.Buy(lotSize2, _Symbol, price, sl, tp2, "TP2 " + comment);
      
      if(type == ORDER_TYPE_SELL)
      {
         result1 = Trade.Sell(lotSize1, _Symbol, price, sl, tp1, "TP1 " + comment);
         result2 = Trade.Sell(lotSize2, _Symbol, price, sl, tp2, "TP2 " + comment);
      }

      if(result1 && result2)
      {
         TRADE_INFO trade;
         trade.ticketTP1 = Trade.ResultOrder();
         trade.ticketTP2 = Trade.ResultOrder();
         trade.tradeType = (type == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
         trade.tp1Closed = false;
         ArrayResize(activeTrades, ArraySize(activeTrades) + 1);
         activeTrades[ArraySize(activeTrades) - 1] = trade;

         tradesToday++;
         tradesSession++;
         SendAlert(comment + " executed.");
      }
   }
   else if(TradeMode == MODE_MANUAL)
   {
      SendAlert(comment + " signal detected.");
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size Based on Risk                                 |
//+------------------------------------------------------------------+
double CalculateLotSize(double slPips)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * RiskPercent / 100.0;
   double slValue = slPips * _Point;
   double lotSize = riskAmount / (slValue * tickValue);
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Manage Active Trades for Trailing Stops                          |
//+------------------------------------------------------------------+
void ManageActiveTrades()
{
   for(int i = ArraySize(activeTrades) - 1; i >= 0; i--)
   {
      TRADE_INFO trade = activeTrades[i];

      // Check if both trades are closed
      if(!PositionSelectByTicket(trade.ticketTP1) && !PositionSelectByTicket(trade.ticketTP2))
      {
         ArrayRemove(activeTrades, i, 1);
         continue;
      }

      // Check if TP1 trade is closed
      if(!trade.tp1Closed && !PositionSelectByTicket(trade.ticketTP1))
      {
         activeTrades[i].tp1Closed = true;
         if(PositionSelectByTicket(trade.ticketTP2))
         {
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            Trade.PositionModify(trade.ticketTP2, entryPrice, PositionGetDouble(POSITION_TP));
         }
      }

      // Apply trailing stop if TP1 is closed
      if(activeTrades[i].tp1Closed && PositionSelectByTicket(trade.ticketTP2))
      {
         double currentPrice = (trade.tradeType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         double atr[];
         ArraySetAsSeries(atr, true);
         
         if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
         {
            double trailDistance = 2 * atr[0];
            double currentSL = PositionGetDouble(POSITION_SL);
            double newSL = (trade.tradeType == POSITION_TYPE_BUY) ? currentPrice - trailDistance : currentPrice + trailDistance;

            if((trade.tradeType == POSITION_TYPE_BUY && newSL > currentSL) || (trade.tradeType == POSITION_TYPE_SELL && newSL < currentSL))
            {
               Trade.PositionModify(trade.ticketTP2, newSL, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update Dashboard                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard(ENUM_CRT_PHASE phase)
{
   string dashboard = "CRT Phase: " + PhaseToString(phase) + "\n";
   dashboard += "Trades Today: " + IntegerToString(tradesToday) + "/" + IntegerToString(MaxTradesPerDay) + "\n";
   dashboard += "Trades Session: " + IntegerToString(tradesSession) + "/" + IntegerToString(MaxTradesPerSession) + "\n";
   Comment(dashboard);
}

string PhaseToString(ENUM_CRT_PHASE phase)
{
   switch(phase)
   {
      case PHASE_ACCUMULATION: return "Accumulation";
      case PHASE_MANIPULATION: return "Manipulation";
      case PHASE_DISTRIBUTION: return "Distribution";
      default: return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Send Alert                                                       |
//+------------------------------------------------------------------+
void SendAlert(string message)
{
   if(EnableSoundAlerts) Alert(message);
   if(EnableEmailAlerts) SendMail("CRT EA Alert", message);
   if(EnablePushAlerts) SendNotification(message);
}

//+------------------------------------------------------------------+