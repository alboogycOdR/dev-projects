//+------------------------------------------------------------------+
//|                                                      Maverick EA |
//|                                      Copyright 2025, kingdom_f   |
//|                                       https://t.me/AlisterFx/    |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, kingdom financier"
#property link      "https://t.me/AlisterFx/"
#property version   "1.6" // Simplified Recovery Trigger
#property description "\n\nMaverick EA"
#property description "\n____________"
#property description "\nHedging System"
#property description "\nRecovery only on Main Survivor BE Stop Hit"
//+------------------------------------------------------------------+
//| Expert Advisor: MAVERICK                                         |
//| Description: MT5 Hedge EA with main trades and recovery trigger  |
//|              based on main survivor hitting BE stop.             |
//| Version: 1.6 (Simplified Recovery Trigger / No SL Hit Trigger)   |
//| Author: Alister / AI Refactor                                    |
//+------------------------------------------------------------------+
/*
 Refactor Notes (v1.6):
 - Recovery pairs ONLY triggered when Main survivor (at BE) has price hit entry.
 - Initial SL hit on Main DOES NOT trigger recovery.
 - OnStopLossHit callback pathway completely removed.
 - Global skipRecovery flag removed.
 - blockRecovery mechanism retained for pairs failing AFTER stage 2 trail.
 - recoveryUsedToday flag retained for one-recovery-per-day rule.
*/
#include <Trade/Trade.mqh>
CTrade trade;
//--------------------------------------------------//
//               INPUT PARAMETERS
//--------------------------------------------------//
input group "Main Trade Settings"
input double   InpLotSize = 0.2;                 // Lot Size for Main Trade
input int      InpSLPointsMain = 250000;          // SL Points (Main Trade)
input int      InpTPPointsMain = 1000000;         // TP Points (Main Trade)
input string   InpTradeTime = "00:00";            // Main Trade Entry Time (HH:MM)
input int      InpTrail2TriggerMain = 500000;  // Points profit after BE before second trail
input int      InpTrail2OffsetMain  = 250000;  // Points to move SL above/below entry during second trail
input int      InpMagicMain = 7777777;             // Magic Number (Main Trade)

input group "Recovery Trade Settings"
input bool     UseRecoveryTrade        = true;     // Turn recovery trades on/off
input double   InpLotSizeRecovery      = 0.4;     // Lot Size for Recovery Trade
input int      InpSLPointsRecovery     = 500000;   // SL Points (Recovery Trade)
input int      InpTPPointsRecovery     = 1000000;  // TP Points (Recovery Trade)
input int      InpMagicRecovery        = 8888888;   // Magic Number (Recovery Trade)
input int      InpRecoveryProfitForBEPoints = 500000; // Points profit before moving recovery SL to entry
input double   BreakevenThreshold = -5.0;    // For logging/display: Threshold to consider pair result as "BE"

input group "Other Settings"
input bool     InpEnableDebug        = true;     // Enable detailed debug output
input int      UpdateFrequency = 1000;       // Dashboard update frequency in milliseconds (1 sec = 1000)
input bool     InpIsLogging=false;         // Reduced default logging for transactions // Defaulted to false, set true for deep debug
input bool     ShowDashboard = true;       // Show dashboard on chart
enum ENUM_DASHBOARD_POSITION
  {
   DASHBOARD_TOP_LEFT,      // Top Left
   DASHBOARD_TOP_RIGHT,     // Top Right
   DASHBOARD_BOTTOM_LEFT,   // Bottom Left
   DASHBOARD_BOTTOM_RIGHT   // Bottom Right
  };
input ENUM_DASHBOARD_POSITION DashboardPosition = DASHBOARD_TOP_LEFT; // Dashboard Position

//--------------------------------------------------//
//           STRUCTURES & GLOBAL VARIABLES
//--------------------------------------------------//

// Structure to hold information about an active main hedge pair
struct HedgePairInfo
  {
   string            guid;           // Unique identifier for the pair
   ulong             buyTicket;      // Ticket of the BUY position (0 if closed)
   ulong             sellTicket;     // Ticket of the SELL position (0 if closed)
   double            buyEntry;       // Entry price of the BUY position
   double            sellEntry;      // Entry price of the SELL position
   bool              buySLAtBE;      // Has the BUY position's SL been moved to entry?
   bool              sellSLAtBE;     // Has the SELL position's SL been moved to entry?
   datetime          openTime;       // Approx time pair was opened
  };

// Global dynamic array to store active main pairs being managed
HedgePairInfo activeMainPairs[];

// -- State Variables --
datetime mainTradeOpenTime = 0;   // Time when the *very latest* main trade pair was opened
double adjustedLotSize = 0;       // Adjusted lot size for Main
double adjustedLotSizeRecovery = 0; // Adjusted lot size for Recovery

// -- Daily Tracking Variables --
datetime currentTradeDate = 0;      // Current trading day date (start of day)
double dailyCumulativeProfit = 0.0; // Track daily P/L (Informative)

// -- Chart & Info Variables --
string infoLabelPrefix = "MAVERICK_";     // Prefix for chart objects
string tradingDayLineName = "MAVERICK_TRADING_DAY_LINE";  // Name for the vertical line
string currentTradeGuid = "";  // Stores the GUID of the main pair being *currently* opened

// -- Profit/Trade History Tracking --
struct TradeInfo
  {
   double            profit;    // Profit or loss in dollars
   datetime          time;      // Time the trade was closed
   string            comment;   // Trade Comment (e.g., B-GUID, RS-GUID)
  };
TradeInfo lastFiveTrades[5]; // Array to store the last 5 closed trades
double totalRealizedProfit = 0.0; // Total profit from all closed trades this EA run (updated incrementally)

// Structure to track results of a *recently closed* pair (now primarily for logging/display)
struct TradeResultPair
  {
   string            guid;          // Trade pair GUID
   bool              buyHitSL;      // Whether the buy position hit stop loss
   bool              sellHitSL;     // Whether the sell position hit stop loss
   double            buyProfit;     // Profit from buy position
   double            sellProfit;    // Profit from sell position
   double            totalProfit;   // Combined profit
   bool              buyClosed;     // Flag: Buy side is closed
   bool              sellClosed;    // Flag: Sell side is closed
   bool              evaluated;     // Not used for logic anymore, maybe for complex logging? Set true when both closed.
  };
TradeResultPair lastClosedPair; // Stores info of the pair whose parts are currently closing

// Structure for Tracking Positions *AFTER* SL Moved Beyond BE (for recovery blocking logic)
struct TrackedPosition
  {
   ulong             ticket;           // Position ticket
   string            guid;             // Position GUID (of the pair)
   double            trailedSL;        // The SL value *after* it was moved beyond entry
   double            entryPrice;       // Entry price of this position
   ENUM_POSITION_TYPE posType;         // Buy or Sell
   bool              blockRecovery;    // Flag to block recovery for this hedge set (GUID) - Set ONLY when SL hit *after* trail
  };
TrackedPosition trackedPositions[];  // Array to store positions reaching the second trail stage

// Define object names for the dashboard
#define DASHBOARD_BG_NAME   infoLabelPrefix + "Dashboard_BG"
#define DASHBOARD_TEXT_NAME infoLabelPrefix + "Dashboard_Text"


//+------------------------------------------------------------------+
//| Function to check if a pair result is "Breakeven" for logging    |
//+------------------------------------------------------------------+
bool IsPairAtEffectiveBreakeven(double totalProfit)
  {
// Only used for status logging, not recovery decisions now
   return totalProfit >= BreakevenThreshold;
  }

//--- Transaction Type Defines --- (Unchanged)
#define IS_TRANSACTION_ORDER_PLACED            (trans.type == TRADE_TRANSACTION_REQUEST && request.action == TRADE_ACTION_PENDING && OrderSelect(result.order) && (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE) == ORDER_STATE_PLACED)
#define IS_TRANSACTION_ORDER_MODIFIED          (trans.type == TRADE_TRANSACTION_REQUEST && request.action == TRADE_ACTION_MODIFY && OrderSelect(result.order) && (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE) == ORDER_STATE_PLACED)
#define IS_TRANSACTION_ORDER_DELETED           (trans.type == TRADE_TRANSACTION_HISTORY_ADD && (trans.order_type >= ORDER_TYPE_BUY_LIMIT && trans.order_type <= ORDER_TYPE_SELL_STOP_LIMIT) && trans.order_state == ORDER_STATE_CANCELED)
#define IS_TRANSACTION_ORDER_EXPIRED           (trans.type == TRADE_TRANSACTION_HISTORY_ADD && (trans.order_type >= ORDER_TYPE_BUY_LIMIT && trans.order_type <= ORDER_TYPE_SELL_STOP_LIMIT) && trans.order_state == ORDER_STATE_EXPIRED)
#define IS_TRANSACTION_ORDER_TRIGGERED         (trans.type == TRADE_TRANSACTION_HISTORY_ADD && (trans.order_type >= ORDER_TYPE_BUY_LIMIT && trans.order_type <= ORDER_TYPE_SELL_STOP_LIMIT) && trans.order_state == ORDER_STATE_FILLED)

#define IS_TRANSACTION_POSITION_OPENED         (trans.type == TRADE_TRANSACTION_DEAL_ADD && HistoryDealSelect(trans.deal) && (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
#define IS_TRANSACTION_POSITION_STOP_TAKE      (trans.type == TRADE_TRANSACTION_DEAL_ADD && HistoryDealSelect(trans.deal) && (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY) == DEAL_ENTRY_OUT && ((ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON) == DEAL_REASON_SL || (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON) == DEAL_REASON_TP))
#define IS_TRANSACTION_POSITION_CLOSED         (trans.type == TRADE_TRANSACTION_DEAL_ADD && HistoryDealSelect(trans.deal) && (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY) == DEAL_ENTRY_OUT && ((ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON) != DEAL_REASON_SL && (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON) != DEAL_REASON_TP))
#define IS_TRANSACTION_POSITION_CLOSEBY        (trans.type == TRADE_TRANSACTION_DEAL_ADD && HistoryDealSelect(trans.deal) && (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY) == DEAL_ENTRY_OUT_BY)
#define IS_TRANSACTION_POSITION_MODIFIED       (trans.type == TRADE_TRANSACTION_REQUEST && request.action == TRADE_ACTION_SLTP)

// --- Removed Callback Definitions ---
// typedef void (*OnStopLossHitCallback)(...);


//+------------------------------------------------------------------+
//| Class CTradeTransaction: Base for handling trade events.         |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Class CTradeTransaction: Base for handling trade events.         |
//+------------------------------------------------------------------+
class CTradeTransaction
  {
public: // Public Interface
                     CTradeTransaction(void)  {   }
                    ~CTradeTransaction(void)  {   }
   void              OnTradeTransaction(const MqlTradeTransaction &trans,
                                        const MqlTradeRequest &request,
                                        const MqlTradeResult &result);

   // --- Helper Functions MOVED TO PUBLIC --- << SOLUTION
   string            GetOriginalCommentForDeal(ulong deal_ticket)
     {
      // (Implementation...)
      ulong order_ticket = HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
      if(!HistoryOrderSelect(order_ticket))
         return "";
      ulong position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
      if(position_id > 0 && HistorySelectByPosition(position_id))
        {
         int deals_total = HistoryDealsTotal();
         for(int i = 0; i < deals_total; i++)
           {
            ulong pos_deal_ticket = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(pos_deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
              {
               ulong opening_order_ticket = HistoryDealGetInteger(pos_deal_ticket, DEAL_ORDER);
               if(HistoryOrderSelect(opening_order_ticket))
                  return HistoryOrderGetString(opening_order_ticket, ORDER_COMMENT);
               break;
              }
           }
        }
      string fallback_comment = HistoryOrderGetString(order_ticket, ORDER_COMMENT);
      return fallback_comment;
     }

   string            ExtractGuidFromComment(string comment)
     {
      // (Implementation...)
      if(comment == NULL || StringLen(comment) <= 1)
         return "";
      if(StringSubstr(comment, 0, 1) == "B" || StringSubstr(comment, 0, 1) == "S")
         return StringSubstr(comment, 1);
      if(StringLen(comment) > 2 && (StringSubstr(comment, 0, 2) == "RB" || StringSubstr(comment, 0, 2) == "RS"))
         return StringSubstr(comment, 2);
      return "";
     }

   void              UpdateLastTrades(double profit, datetime time, string comment)
     {
      // (Implementation...)
      for(int i = 0; i < 4; i++)
        {
         lastFiveTrades[i] = lastFiveTrades[i+1];
        }
      lastFiveTrades[4].profit = profit;
      lastFiveTrades[4].time = time;
      lastFiveTrades[4].comment = comment;
     }

   // Update recently closed pair info (for logging/display)
   void              UpdateLastClosedPairInfo(const string guid, const string comment, double profit, bool sl_hit)
     {
      // (Implementation...)
      if(guid == "")
         return;
      if(lastClosedPair.guid != guid)    /* Reset */
        {
         lastClosedPair.guid = guid;
         lastClosedPair.buyProfit=0.0;
         lastClosedPair.sellProfit=0.0;
         lastClosedPair.buyHitSL=false;
         lastClosedPair.sellHitSL=false;
         lastClosedPair.totalProfit=0.0;
         lastClosedPair.buyClosed=false;
         lastClosedPair.sellClosed=false;
         lastClosedPair.evaluated=false;
        }
      if(StringSubstr(comment, 0, 1) == "B" && !lastClosedPair.buyClosed)   /* Update Buy */
        {
         lastClosedPair.buyProfit=profit;
         lastClosedPair.buyHitSL=sl_hit;
         lastClosedPair.buyClosed=true;
        }
      else
         if(StringSubstr(comment, 0, 1) == "S" && !lastClosedPair.sellClosed)   /* Update Sell */
           {
            lastClosedPair.sellProfit=profit;
            lastClosedPair.sellHitSL=sl_hit;
            lastClosedPair.sellClosed=true;
           }
      if(lastClosedPair.buyClosed && lastClosedPair.sellClosed)   /* Update Total, Mark Evaluated */
        {
         lastClosedPair.totalProfit = lastClosedPair.buyProfit + lastClosedPair.sellProfit;
         lastClosedPair.evaluated = true;
         if(InpEnableDebug)
            PrintFormat("Pair %s Both Closed. Total P: %.2f (UpdateInfo)", guid, lastClosedPair.totalProfit);
        }
     }

protected: // Protected members - only for this class and derived classes
   // --- Virtual methods to be overridden ---
   virtual void      TradeTransactionOrderPlaced(ulong order)                      {   }
   virtual void      TradeTransactionOrderModified(ulong order)                    {   }
   virtual void      TradeTransactionOrderDeleted(ulong order)                     {   }
   virtual void      TradeTransactionOrderExpired(ulong order)                     {   }
   virtual void      TradeTransactionOrderTriggered(ulong order)                   {   }
   virtual void      TradeTransactionPositionOpened(ulong position, ulong deal)    {   }
   virtual void      TradeTransactionPositionStopTake(ulong position, ulong deal)  {   }
   virtual void      TradeTransactionPositionClosed(ulong position, ulong deal)    {   }
   virtual void      TradeTransactionPositionCloseBy(ulong position, ulong deal)   {   }
   virtual void      TradeTransactionPositionModified(ulong position)              {   }

  }; // End CTradeTransaction Class
//+------------------------------------------------------------------+
//| CTradeTransaction: OnTradeTransaction Implementation             |
//+------------------------------------------------------------------+
void CTradeTransaction::OnTradeTransaction(const MqlTradeTransaction &trans,
      const MqlTradeRequest &request,
      const MqlTradeResult &result)
  {
// Route based on transaction type using DEFINES
   if(IS_TRANSACTION_ORDER_PLACED)
      TradeTransactionOrderPlaced(result.order);
   else
      if(IS_TRANSACTION_ORDER_MODIFIED)
         TradeTransactionOrderModified(result.order);
      else
         if(IS_TRANSACTION_ORDER_DELETED)
            TradeTransactionOrderDeleted(trans.order);
         else
            if(IS_TRANSACTION_ORDER_EXPIRED)
               TradeTransactionOrderExpired(trans.order);
            else
               if(IS_TRANSACTION_ORDER_TRIGGERED)
                  TradeTransactionOrderTriggered(trans.order);
               else
                  if(IS_TRANSACTION_POSITION_OPENED)
                     TradeTransactionPositionOpened(trans.position,trans.deal);
                  else
                     if(IS_TRANSACTION_POSITION_STOP_TAKE)
                        TradeTransactionPositionStopTake(trans.position,trans.deal);
                     else
                        if(IS_TRANSACTION_POSITION_CLOSED)
                           TradeTransactionPositionClosed(trans.position,trans.deal);
                        else
                           if(IS_TRANSACTION_POSITION_CLOSEBY)
                              TradeTransactionPositionCloseBy(trans.position,trans.deal);
                           else
                              if(IS_TRANSACTION_POSITION_MODIFIED)
                                 TradeTransactionPositionModified(request.position);
  }

//+------------------------------------------------------------------+
//| CExtTransaction: Extended class with EA-specific logic.          |
//+------------------------------------------------------------------+
class CExtTransaction : public CTradeTransaction
  {
   // --- Removed Callback Member and Set Method ---
   // OnStopLossHitCallback m_onStopLossHitCallback;
   // void SetStopLossCallback(...);

public:
                     CExtTransaction() {} // Constructor

protected: // Override base class virtual methods

   // --- Simple Logging for Order Events ---
   virtual void      TradeTransactionOrderPlaced(ulong order) override
     {
      long magic = OrderGetInteger(ORDER_MAGIC);
      if((magic==InpMagicMain || magic==InpMagicRecovery) && InpEnableDebug && InpIsLogging)
         PrintFormat("Log: Order Placed %I64u (Magic %d)", order, magic);
     }
   virtual void      TradeTransactionOrderModified(ulong order) override
     {
      long magic = OrderGetInteger(ORDER_MAGIC);
      if((magic==InpMagicMain || magic==InpMagicRecovery) && InpEnableDebug && InpIsLogging)
         PrintFormat("Log: Order Modified %I64u (Magic %d)", order, magic);
     }
   virtual void      TradeTransactionOrderDeleted(ulong order) override
     {
      if(InpEnableDebug && InpIsLogging)
         PrintFormat("Log: Order Deleted %I64u", order);
     }
   virtual void      TradeTransactionOrderExpired(ulong order) override
     {
      if(InpEnableDebug && InpIsLogging)
         PrintFormat("Log: Order Expired %I64u", order);
     }
   virtual void      TradeTransactionOrderTriggered(ulong order) override
     {
      if(OrderSelect(order))
        {
         long magic = OrderGetInteger(ORDER_MAGIC);
         if((magic == InpMagicMain || magic == InpMagicRecovery) && InpEnableDebug && InpIsLogging)
            PrintFormat("Log: Order Triggered %I64u (Magic %d, Type %s)", order, magic, EnumToString((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)));
        }
     }
   virtual void      TradeTransactionPositionModified(ulong position_ticket) override   // SL/TP modify request event
     {
      if(PositionSelectByTicket(position_ticket))
        {
         long magic = PositionGetInteger(POSITION_MAGIC);
         if((magic == InpMagicMain || magic == InpMagicRecovery) && InpEnableDebug && InpIsLogging)
            PrintFormat("Log: Pos %I64u (Magic %d) SL/TP modify processed.", position_ticket, magic);
        }
     }

   // --- Position Opened ---
   virtual void      TradeTransactionPositionOpened(ulong position_id, ulong deal) override
     {
      long magic = HistoryDealGetInteger(deal, DEAL_MAGIC);
      if(magic == InpMagicMain || magic == InpMagicRecovery)
        {
         if(InpEnableDebug)
            PrintFormat("Position Opened: Magic %d (Pos %I64u from Deal %I64u)", magic, position_id, deal);
        }
     }

   // --- Position Closure Handlers ---
   virtual void      TradeTransactionPositionStopTake(ulong position_id, ulong deal) override { HandlePositionClose(position_id, deal, true); }
   virtual void      TradeTransactionPositionClosed(ulong position_id, ulong deal) override { HandlePositionClose(position_id, deal, false); }
   virtual void      TradeTransactionPositionCloseBy(ulong position_id, ulong deal) override { HandlePositionClose(position_id, deal, false); }


   // --- Centralized Handler for ALL Position Closure Events ---
   void              HandlePositionClose(ulong position_id, ulong deal, bool isStopTake)
     {
      // 1. Get Essential Info from the Closing Deal
      ENUM_DEAL_REASON closeReason = (ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON);
      long magic = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);
      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
      datetime closeTime = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      ulong closingDealTicket = deal;
      if(position_id == 0)
        {
         Print("HandleClose Error: Position ID is 0");
         return;
        }
      // 2. Get Original Comment & GUID
      string dealComment = GetOriginalCommentForDeal(closingDealTicket);
      string guid = ExtractGuidFromComment(dealComment);
      if(InpEnableDebug)
        {
         // Simplified logging type - rely on the Reason Enum directly
         string closeCategory = isStopTake ? "Stop/Take" : "Other/CloseBy"; // Simplified category
         PrintFormat("Pos Closed (%s). Magic: %d, Reason: %s, P/L: %.2f, PosID: %I64u, Deal: %I64u, Cmt: '%s', GUID: '%s'",
                     closeCategory,                            // Use simplified category
                     magic,
                     EnumToString(closeReason),                // Log the actual reason code string
                     profit,
                     position_id,
                     closingDealTicket,
                     dealComment,
                     guid);
        }
      // 3. Update Global Stats
      if(magic == InpMagicMain || magic == InpMagicRecovery)
        {
         totalRealizedProfit += profit;
         UpdateLastTrades(profit, closeTime, dealComment);
        }
      // 4. Update Tracked MAIN Pair State (if applicable)
      if(magic == InpMagicMain && guid != "")
        {
         bool pairUpdated = false;
         for(int i = 0; i < ArraySize(activeMainPairs); i++)
           {
            if(activeMainPairs[i].guid == guid)    // Found the pair
              {
               bool closedInThisPair = false;
               if(activeMainPairs[i].buyTicket == position_id)
                 {
                  activeMainPairs[i].buyTicket = 0;
                  activeMainPairs[i].buySLAtBE = false;
                  closedInThisPair = true;
                 }
               else
                  if(activeMainPairs[i].sellTicket == position_id)
                    {
                     activeMainPairs[i].sellTicket = 0;
                     activeMainPairs[i].sellSLAtBE = false;
                     closedInThisPair = true;
                    }
               if(closedInThisPair)
                 {
                  // Update struct for recent pair logging/display info
                  UpdateLastClosedPairInfo(guid, dealComment, profit, closeReason == DEAL_REASON_SL);
                  if(InpEnableDebug)
                     PrintFormat("Pair %s: Marked Pos %I64u as closed in active list.", guid, position_id);
                  pairUpdated = true;
                  break;
                 }
              }
           } // End pair search loop
         if(!pairUpdated && guid!="") { /* Warning if pair not found */ }
        }
      // 5. Check if SL Hit was for a TRAILED Position (to set BLOCK flag)
      if(closeReason == DEAL_REASON_SL)
        {
         for(int i = 0; i < ArraySize(trackedPositions); i++)
           {
            if(trackedPositions[i].ticket == position_id)    // Match closed pos with tracked pos
              {
               // This position was being tracked AFTER stage 2 trail
               double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
               bool slWasTrulyTrailed = false; // Check if SL was beyond BE threshold
               if(trackedPositions[i].posType == POSITION_TYPE_BUY && trackedPositions[i].trailedSL > trackedPositions[i].entryPrice + point)
                 {
                  slWasTrulyTrailed = true;
                 }
               else
                  if(trackedPositions[i].posType == POSITION_TYPE_SELL && trackedPositions[i].trailedSL < trackedPositions[i].entryPrice - point)
                    {
                     slWasTrulyTrailed = true;
                    }
               if(slWasTrulyTrailed)
                 {
                  // SET BLOCK FLAG for this GUID in the tracked array
                  string pairGuidToBlock = trackedPositions[i].guid;
                  for(int j=0; j<ArraySize(trackedPositions); j++)
                    {
                     if(trackedPositions[j].guid == pairGuidToBlock)
                        trackedPositions[j].blockRecovery = true; // Block all for this pair
                    }
                  if(InpEnableDebug)
                     PrintFormat("!!! SL HIT AFTER TRAILING !!! Pos %I64u (GUID %s). Recovery BLOCKED for Pair.",
                                 position_id, pairGuidToBlock);
                  // No need for skipRecovery flag anymore, the check is done via trackedPositions.blockRecovery
                 }
               else { /* Log SL hit at BE - Normal */ }
               break; // Found tracked position, exit loop
              }
           }
        } // End if SL hit check
      // --- Removed Call to OnStopLossHit Callback ---
     } // End HandlePositionClose

  }; // End CExtTransaction Class

//+------------------------------------------------------------------+
//| Global transaction object                                        |
//+------------------------------------------------------------------+
CExtTransaction ExtTransaction;

//+------------------------------------------------------------------+
//| OnTradeTransaction (System Callback -> routes to handler)        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  { ExtTransaction.OnTradeTransaction(trans,request,result); } // Delegate
//+------------------------------------------------------------------+

// --- Removed OnStopLossHit Function Implementation ---

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
  {
// Initialize arrays and global vars
   for(int i=0; i<ArraySize(lastFiveTrades); i++)   // Clear trade history display
     {
      lastFiveTrades[i].profit=0.0;
      lastFiveTrades[i].time=0;
      lastFiveTrades[i].comment="";
     }
   ArrayResize(activeMainPairs, 0); // Clear active main pair list
   ArrayResize(trackedPositions, 0); // Clear trailed position list
   totalRealizedProfit = 0.0;      // Reset realized profit
// History analysis
   if(!HistorySelect(0, TimeCurrent()))
     {
      Print("OnInit Error: Failed HistorySelect.");
     }
   else   /* Load initial profit and last 5 trades */
     {
      // (Same history loading loop as before using helpers)
      int totalDeals = HistoryDealsTotal();
      int tradeCount = 0;
      double initialProfitSum = 0.0;
      for(int i = totalDeals - 1; i >= 0; i--)
        {
         ulong dealTicket = HistoryDealGetTicket(i);
         if(HistoryDealSelect(dealTicket))
           {
            long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
            long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
            if(entry == DEAL_ENTRY_OUT && (magic == InpMagicMain || magic == InpMagicRecovery))
              {
               initialProfitSum += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
               if(tradeCount < 5)
                 {
                  lastFiveTrades[tradeCount].profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                  lastFiveTrades[tradeCount].time = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                  lastFiveTrades[tradeCount].comment = ExtTransaction.GetOriginalCommentForDeal(dealTicket); // Use helper
                  tradeCount++;
                 }
              }
           }
        }
      totalRealizedProfit = initialProfitSum;
      if(tradeCount > 1)
         ArrayReverse(lastFiveTrades, 0, tradeCount);
      if(InpEnableDebug)
         PrintFormat("OnInit: History Load. Init Profit=%.2f. Last %d trades logged.", totalRealizedProfit, tradeCount);
     }
// Trade object setup
   trade.SetExpertMagicNumber(InpMagicMain);
   trade.SetMarginMode();
   trade.LogLevel(LOG_LEVEL_ERRORS);
   trade.SetTypeFillingBySymbol(_Symbol);
// Parameter Validation
   if(!ValidateAdjustLotSize(InpLotSize, adjustedLotSize, "Main"))
      return INIT_FAILED;
   if(UseRecoveryTrade && !ValidateAdjustLotSize(InpLotSizeRecovery, adjustedLotSizeRecovery, "Recovery"))
      return INIT_FAILED;
// Basic Magic Number Checks
   if(InpMagicMain == 0 || (UseRecoveryTrade && InpMagicRecovery==0))
     {
      Print("OnInit Error: Magic Numbers cannot be 0.");
      return INIT_FAILED;
     }
   if(InpMagicMain == InpMagicRecovery)
     {
      Print("OnInit Error: Main and Recovery Magic Numbers must be different.");
      return INIT_FAILED;
     }
// Account Check (Hedging)
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      Print("OnInit Warning: Hedging account required for strategy.");
     }
// Initialize Time & State
   MqlDateTime time_struct;
   TimeCurrent(time_struct);
   currentTradeDate = StructToTime(time_struct) - (StructToTime(time_struct) % 86400);
   dailyCumulativeProfit = 0.0;                                           // Reset counter
   lastClosedPair.guid = "";
   lastClosedPair.evaluated = false;            // Reset last pair log
// Setup Timer
   int timerSeconds = UpdateFrequency / 1000;
   if(timerSeconds < 1)
      timerSeconds = 1;
   if(!EventSetTimer(timerSeconds))
     {
      Print("OnInit Error: EventSetTimer failed.");
      return INIT_FAILED;
     }
   if(InpEnableDebug)
      PrintFormat("MAVERICK EA initialized (v%.2f - Simplified Rec Trigger). Sym:%s Date:%s", _Digits==3?1.63:1.65, _Symbol, TimeToString(currentTradeDate, TIME_DATE));
// Initialize state for existing pairs
   InitializeExistingPairs();
   CreateTradingDayLine(TimeCurrent());
   return INIT_SUCCEEDED;
  } // End OnInit

//+------------------------------------------------------------------+
//| Helper Function for Lot Size Validation                          |
//+------------------------------------------------------------------+
bool ValidateAdjustLotSize(const double inputLot, double &adjustedLot, string tradeType)
  {
// (Implementation is complete as provided before - calculates lotDigits, clamps, adjusts step, final clamp, logs, returns true/false)
   double minLot=SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), maxLot=SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), stepLot=SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP), limitVol=SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
   if(limitVol > 0 && limitVol < maxLot)
      maxLot = limitVol;
   int lotDigits=0;
   if(stepLot>0 && stepLot<1)
     {
      string s=DoubleToString(stepLot,8);
      int p=StringFind(s,".");
      if(p>=0)
         lotDigits=StringLen(s)-p-1;
     }
   lotDigits=MathMax(0,MathMin(8,lotDigits));
   adjustedLot=inputLot;
   if(adjustedLot<minLot)
      adjustedLot=minLot;
   if(adjustedLot>maxLot)
      adjustedLot=maxLot;
   if(stepLot>0)
      adjustedLot=MathRound(adjustedLot/stepLot)*stepLot;
   else
      adjustedLot=MathRound(adjustedLot);
   adjustedLot=NormalizeDouble(adjustedLot,lotDigits);
   adjustedLot=MathMax(minLot,MathMin(adjustedLot,maxLot));
   adjustedLot=NormalizeDouble(adjustedLot,lotDigits);
   if(MathAbs(adjustedLot-inputLot)>(stepLot>0?stepLot*0.01:1e-9))
     {
      if(InpEnableDebug)
         PrintFormat("ValidateLot Notice: %s Lot finalized %.*f from %.*f",tradeType,lotDigits,adjustedLot,lotDigits,inputLot);
     }
   if(adjustedLot<minLot||adjustedLot<=0)
     {
      PrintFormat("ValidateLot Error:%s FINAL Lot %.*f < Min Lot %.*f.",tradeType,lotDigits,adjustedLot,lotDigits,minLot);
      return false;
     }
   return true;
  } // End ValidateAdjustLotSize

//+------------------------------------------------------------------+
//| Initialize Existing Pairs on Startup                             |
//+------------------------------------------------------------------+
void InitializeExistingPairs()
  {
// (Implementation is complete as provided before - Finds MAIN positions, pairs by GUID, adds to activeMainPairs, checks initial BE state)
   if(InpEnableDebug)
      Print("InitPairs: Scanning existing MAIN positions...");
   struct FoundPos { ulong t; string c; double e; ENUM_POSITION_TYPE y; string g;};
   FoundPos fP[];
   int cnt=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong tk=PositionGetTicket(i);
      if(PositionSelectByTicket(tk))
        {
         if(PositionGetInteger(POSITION_MAGIC)==InpMagicMain&&PositionGetString(POSITION_SYMBOL)==_Symbol)
           {
            ArrayResize(fP,cnt+1);
            fP[cnt].t=tk;
            fP[cnt].c=PositionGetString(POSITION_COMMENT);
            fP[cnt].e=PositionGetDouble(POSITION_PRICE_OPEN);
            fP[cnt].y=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            fP[cnt].g=ExtTransaction.ExtractGuidFromComment(fP[cnt].c);
            if(fP[cnt].g=="") {/*Warning*/} cnt++;
           }
        }
     }
   if(cnt==0)
      return;
   bool uI[];
   ArrayResize(uI,cnt);
   ArrayInitialize(uI,false);
   int pairsF=0;
   for(int i=0; i<cnt; i++)
     {
      if(uI[i]||fP[i].g=="")
         continue;
      for(int j=i+1; j<cnt; j++)
        {
         if(uI[j]||fP[j].g=="")
            continue;
         if(fP[i].g==fP[j].g&&fP[i].y!=fP[j].y)
           {
            int nS=ArraySize(activeMainPairs)+1;
            if(ArrayResize(activeMainPairs,nS)!=nS) {/*Error*/ continue;}
            int idx=nS-1;
            activeMainPairs[idx].guid=fP[i].g;
            if(fP[i].y==POSITION_TYPE_BUY)
              {
               activeMainPairs[idx].buyTicket=fP[i].t;
               activeMainPairs[idx].buyEntry=fP[i].e;
               activeMainPairs[idx].sellTicket=fP[j].t;
               activeMainPairs[idx].sellEntry=fP[j].e;
              }
            else
              {
               activeMainPairs[idx].buyTicket=fP[j].t;
               activeMainPairs[idx].buyEntry=fP[j].e;
               activeMainPairs[idx].sellTicket=fP[i].t;
               activeMainPairs[idx].sellEntry=fP[i].e;
              }
            double bSL=0,sSL=0;
            if(PositionSelectByTicket(activeMainPairs[idx].buyTicket))
               bSL=PositionGetDouble(POSITION_SL);
            if(PositionSelectByTicket(activeMainPairs[idx].sellTicket))
               sSL=PositionGetDouble(POSITION_SL);
            double pt=_Point;
            activeMainPairs[idx].buySLAtBE=(MathAbs(bSL-activeMainPairs[idx].buyEntry)<pt*2);
            activeMainPairs[idx].sellSLAtBE=(MathAbs(sSL-activeMainPairs[idx].sellEntry)<pt*2);
            if(PositionSelectByTicket(activeMainPairs[idx].buyTicket))
               activeMainPairs[idx].openTime=(datetime)PositionGetInteger(POSITION_TIME);
            else
               if(PositionSelectByTicket(activeMainPairs[idx].sellTicket))
                  activeMainPairs[idx].openTime=(datetime)PositionGetInteger(POSITION_TIME);
               else
                  activeMainPairs[idx].openTime=TimeCurrent();
            if(InpEnableDebug)
               PrintFormat("InitPairs: Initialized Pair %s (B:%I64u,S:%I64u) BE(B:%s,S:%s)",activeMainPairs[idx].guid,activeMainPairs[idx].buyTicket,activeMainPairs[idx].sellTicket,activeMainPairs[idx].buySLAtBE?"Y":"N",activeMainPairs[idx].sellSLAtBE?"Y":"N");
            uI[i]=true;
            uI[j]=true;
            pairsF++;
            break;
           }
        }
     }
   for(int i=0; i<cnt; i++)
     {
      if(!uI[i])
        {
         if(InpEnableDebug)
            PrintFormat("InitPairs Warn: MAIN Pos %I64u ('%s') unpaired.",fP[i].t,fP[i].c);
        }
     }
   if(InpEnableDebug)
      PrintFormat("InitPairs: Finished, %d pairs added.", pairsF);
  } // End InitializeExistingPairs


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, infoLabelPrefix);
   ObjectDelete(0,DASHBOARD_BG_NAME);
   ObjectDelete(0,DASHBOARD_TEXT_NAME);
   ObjectsDeleteAll(0, tradingDayLineName, 0, -1);
   if(ShowDashboard)
      Comment(""); // Clear dashboard comment
   if(InpEnableDebug)
      Print("MAVERICK EA Deinitialized. Reason code: ", reason);
  }

//+------------------------------------------------------------------+
//| Timer function (Called every 'UpdateFrequency' ms)               |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(ShowDashboard)
      UpdateRunningTotal(); // Update dashboard display
// CheckTrackedPositionsCrossed(); // Optional Debug check
  }

//+------------------------------------------------------------------+
//| New Bar Check                                                    |
//+------------------------------------------------------------------+
bool NewBar() { static datetime pBT=0; datetime cBT=iTime(_Symbol,PERIOD_CURRENT,0); if(cBT!=pBT) {pBT=cBT; return true;} return false; }

//+------------------------------------------------------------------+
//| Expert tick function (Called on every tick, throttled by NewBar) |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!NewBar())
      return; // Main logic runs once per bar
   datetime now=TimeCurrent();
   CheckNewTradingDay(now);
   ManagePositions();
// Check Main Trade Entry Time
   MqlDateTime dt;
   TimeToStruct(now,dt);
   string timeStr=StringFormat("%02d:%02d",dt.hour,dt.min);
   bool isTradeTime=(timeStr==InpTradeTime);
   // MODIFIED: Check only if it's the designated trade time.
   if(isTradeTime)
     {
      static datetime lastOpenAttempt=0;
      if(now-lastOpenAttempt>=55)
        {
         if(OpenMainTrade())
            lastOpenAttempt=now;
         else
            lastOpenAttempt=now;
        }
     }
  }

//+------------------------------------------------------------------+
//| CheckNewTradingDay: reset daily flags when day changes           |
//+------------------------------------------------------------------+
void CheckNewTradingDay(datetime currentTime)
  {
   datetime today=currentTime-(currentTime%86400);
   if(today<=currentTradeDate)
      return; // Not a new day
   currentTradeDate=today;
   if(InpEnableDebug)
      PrintFormat("--- New Trading Day: %s ---",TimeToString(today,TIME_DATE));
   dailyCumulativeProfit=0.0;
   lastClosedPair.guid="";
   lastClosedPair.evaluated=false; // Reset last pair log
   if(InpEnableDebug)
      PrintTradeStatus("After Daily Reset");
   CreateTradingDayLine(currentTime);
  }

//+------------------------------------------------------------------+
//| CountOpenPositions / CountOpenPositionsMagic                     |
//+------------------------------------------------------------------+
int CountOpenPositions() { return CountOpenPositionsMagic(InpMagicMain)+CountOpenPositionsMagic(InpMagicRecovery); }
int CountOpenPositionsMagic(int magic) { int c=0; for(int i=PositionsTotal()-1; i>=0; i--) {ulong t=PositionGetTicket(i);if(PositionSelectByTicket(t)) {if(PositionGetString(POSITION_SYMBOL)==_Symbol&&PositionGetInteger(POSITION_MAGIC)==magic)c++;}} return c;}

//+------------------------------------------------------------------+
//| GenerateTradeGuid                                                |
//+------------------------------------------------------------------+
string GenerateTradeGuid() { return IntegerToString(TimeCurrent())+"-"+IntegerToString(MathRand()%10000); }

//+------------------------------------------------------------------+
//| Helper: Get Position Ticket from Deal Ticket                     |
//+------------------------------------------------------------------+
ulong GetPositionTicketByDeal(ulong deal_ticket) { if(HistoryDealSelect(deal_ticket))return HistoryDealGetInteger(deal_ticket,DEAL_POSITION_ID); return 0; }

//+------------------------------------------------------------------+
//| OpenMainTrade: Opens pair, adds to activeMainPairs array         |
//+------------------------------------------------------------------+
bool OpenMainTrade()
  {
// (Implementation is complete as provided before - uses currentTradeGuid, comments, prices, SL/TP, opens B/S, handles orphans, adds to activeMainPairs on success)
   currentTradeGuid=GenerateTradeGuid();
   string bc="B"+currentTradeGuid, sc="S"+currentTradeGuid;
   if(InpEnableDebug)
      PrintFormat("OpenMainTrade: Try Pair %s Lot %.2f",currentTradeGuid,adjustedLotSize);
   trade.SetExpertMagicNumber(InpMagicMain);
   trade.SetDeviationInPoints(5);
   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t))
     {
      Print("OpenMainTrade Err: Tick");
      return false;
     }
   double a=t.ask, b=t.bid, p=_Point, slB=NormalizeDouble(a-InpSLPointsMain*p,_Digits),tpB=NormalizeDouble(a+InpTPPointsMain*p,_Digits),slS=NormalizeDouble(b+InpSLPointsMain*p,_Digits),tpS=NormalizeDouble(b-InpTPPointsMain*p,_Digits);
   ulong bDT=0,sDT=0,bPT=0,sPT=0;
   bool bOK=false,sOK=false;
   if(!trade.Buy(adjustedLotSize,_Symbol,a,slB,tpB,bc))
     {
      PrintFormat("OpenMainTrade Err: BUY fail %d %s",trade.ResultRetcode(),trade.ResultComment());
      return false;
     }
   bDT=trade.ResultDeal();
   if(bDT>0)
      bPT=GetPositionTicketByDeal(bDT);
   if(bPT>0)
      bOK=true;
   if(!bOK)
     {
      Print("OpenMainTrade Err: No Buy Pos Ticket");
      return false;
     }
   Sleep(100);
   if(!trade.Sell(adjustedLotSize,_Symbol,b,slS,tpS,sc))
     {
      PrintFormat("OpenMainTrade Err: SELL fail %d %s! Close BUY %I64u",trade.ResultRetcode(),trade.ResultComment(),bPT);
      trade.PositionClose(bPT);
      return false;
     }
   sDT=trade.ResultDeal();
   if(sDT>0)
      sPT=GetPositionTicketByDeal(sDT);
   if(sPT>0)
      sOK=true;
   if(!sOK)
     {
      PrintFormat("OpenMainTrade Err: No Sell Pos Ticket! Close BUY %I64u",bPT);
      trade.PositionClose(bPT);
      return false;
     }
   if(bOK&&sOK)
     {
      int ns=ArraySize(activeMainPairs)+1;
      if(ArrayResize(activeMainPairs,ns)!=ns)
        {
         Print("OpenMainTrade Err: Resize Fail! Close %I64u %I64u",bPT,sPT);
         trade.PositionClose(bPT);
         Sleep(50);
         trade.PositionClose(sPT);
         return false;
        }
      int i=ns-1;
      activeMainPairs[i].guid=currentTradeGuid;
      activeMainPairs[i].buyTicket=bPT;
      activeMainPairs[i].sellTicket=sPT;
      activeMainPairs[i].buyEntry=a;
      activeMainPairs[i].sellEntry=b;
      activeMainPairs[i].buySLAtBE=false;
      activeMainPairs[i].sellSLAtBE=false;
      activeMainPairs[i].openTime=TimeCurrent();
      if(InpEnableDebug)
         PrintFormat("Pair %s Added Track (Idx %d) B:%I64u@%.5f S:%I64u@%.5f",currentTradeGuid,i,bPT,a,sPT,b);
      mainTradeOpenTime=TimeCurrent();
      return true;
     }
   return false;
  } // End OpenMainTrade

//+------------------------------------------------------------------+
//| OpenRecoveryTrade: Opens recovery pair, sets state flags         |
//+------------------------------------------------------------------+
bool OpenRecoveryTrade()
  {
// (Pre-checks already done by caller)
   string recGuid=GenerateTradeGuid();
   if(InpEnableDebug)
      PrintFormat("OpenRecoveryTrade: Try Pair %s Lot %.2f",recGuid,adjustedLotSizeRecovery);
   string bc="RB"+recGuid, sc="RS"+recGuid;
   trade.SetExpertMagicNumber(InpMagicRecovery);
   trade.SetDeviationInPoints(5);
   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t))
     {
      Print("OpenRecoveryTrade Err: Tick");
      return false;
     }
   double a=t.ask,b=t.bid,p=_Point,slB=NormalizeDouble(a-InpSLPointsRecovery*p,_Digits),tpB=NormalizeDouble(a+InpTPPointsRecovery*p,_Digits),slS=NormalizeDouble(b+InpSLPointsRecovery*p,_Digits),tpS=NormalizeDouble(b-InpTPPointsRecovery*p,_Digits);
   ulong bPT=0,sPT=0;
   bool bOK=false,sOK=false;
   if(!trade.Buy(adjustedLotSizeRecovery,_Symbol,a,slB,tpB,bc))
     {
      PrintFormat("OpenRec Err: BUY %d %s",trade.ResultRetcode(),trade.ResultComment());
      return false;
     }
   ulong dB=trade.ResultDeal();
   if(dB>0)
      bPT=GetPositionTicketByDeal(dB);
   if(bPT>0)
      bOK=true;
   else
     {
      Print("OpenRec Err: No Buy Pos Ticket");
      return false;
     }
   Sleep(100);
   if(!trade.Sell(adjustedLotSizeRecovery,_Symbol,b,slS,tpS,sc))
     {
      PrintFormat("OpenRec Err: SELL %d %s! Close BUY %I64u",trade.ResultRetcode(),trade.ResultComment(),bPT);
      trade.SetExpertMagicNumber(InpMagicRecovery);
      trade.PositionClose(bPT);
      return false;
     }
   ulong dS=trade.ResultDeal();
   if(dS>0)
      sPT=GetPositionTicketByDeal(dS);
   if(sPT>0)
      sOK=true;
   else
     {
      PrintFormat("OpenRec Err: No Sell Pos Ticket! Close BUY %I64u",bPT);
      trade.SetExpertMagicNumber(InpMagicRecovery);
      trade.PositionClose(bPT);
      return false;
     }
   if(bOK&&sOK)
     {
      if(InpEnableDebug)
         PrintFormat("==> Rec Pair %s Opened OK (B:%I64u S:%I64u).",recGuid,bPT,sPT); // Adjusted log message
      return true;
     }
   return false; // Should not be reached
  } // End OpenRecoveryTrade


//+------------------------------------------------------------------+
//| Helper: Remove closed pair from activeMainPairs array            |
//+------------------------------------------------------------------+
void RemoveActivePair(int index)
  {
   int size = ArraySize(activeMainPairs);
   if(index<0||index>=size)
      return;
   if(InpEnableDebug)
      PrintFormat("Remove Pair %s @ Idx %d",activeMainPairs[index].guid,index);
   if(index<size-1)
     {
      for(int i=index; i<size-1; i++)
        {
         activeMainPairs[i]=activeMainPairs[i+1];
        }
     }
   if(ArrayResize(activeMainPairs,size-1)!=size-1)
     {
      Print("RemoveActivePair ERR: Resize Fail");
     }
  }

//+------------------------------------------------------------------+
//| ManagePositions: Handles Recovery, then iterates Active Main Pairs|
//+------------------------------------------------------------------+
void ManagePositions()
  {
// --- 1. Recovery Position Management ---
   int recCount=CountOpenPositionsMagic(InpMagicRecovery);

   if(recCount > 0)
     {
      if(recCount==2)
         TrailSLRecoveryTrade();
      else
         if(recCount==1)
            ModifySLToEntry(InpMagicRecovery);
         else
            if(recCount==0) // This condition check remains, as it marks the end of the sequence if it was active
              {
               if(InpEnableDebug)
                  Print("Manage: All Rec Pairs Closed.");
               if(InpEnableDebug)
                  Print("Manage: Recovery Sequence Done."); // Adjusted log message
              }
     }
// --- 2. Main Position Management (Runs always) ---
   int actCount=ArraySize(activeMainPairs);
   for(int i=actCount-1; i>=0; i--)   // Iterate Backwards for safe remove
     {
      // Access struct element directly - NO REFERENCE '&'
      bool isOpenB=(activeMainPairs[i].buyTicket!=0 && PositionSelectByTicket(activeMainPairs[i].buyTicket));
      bool isOpenS=(activeMainPairs[i].sellTicket!=0 && PositionSelectByTicket(activeMainPairs[i].sellTicket));
      // Correct state if position closed outside transaction handler
      if(activeMainPairs[i].buyTicket!=0 && !isOpenB)
        {
         activeMainPairs[i].buyTicket=0;
         activeMainPairs[i].buySLAtBE=false;
        }
      if(activeMainPairs[i].sellTicket!=0 && !isOpenS)
        {
         activeMainPairs[i].sellTicket=0;
         activeMainPairs[i].sellSLAtBE=false;
        }
      // --- Case A: Buy Survivor ---
      if(isOpenB && !isOpenS)
        {
         ModifySLToEntry(InpMagicMain, activeMainPairs[i].buyTicket, activeMainPairs[i]); // Pass struct copy or modify inside
         if(activeMainPairs[i].buySLAtBE)
           {
            TrailSLMainTrade(activeMainPairs[i].buyTicket, activeMainPairs[i]);   // Pass struct copy or modify inside
           }
         // Check Recovery Trigger (Only if BE set and Recovery Allowed by input & not blocked for THIS pair)
         if(activeMainPairs[i].buySLAtBE && UseRecoveryTrade && !IsRecoveryBlockedForPair(activeMainPairs[i].guid))
           {
            MqlTick tk;
            if(SymbolInfoTick(_Symbol,tk) && tk.bid<=activeMainPairs[i].buyEntry)
              {
               if(InpEnableDebug)
                  PrintFormat("Pair %s: Price Hit BUY BE @%.5f -> TRIG REC",activeMainPairs[i].guid,activeMainPairs[i].buyEntry);
               if(OpenRecoveryTrade())
                 {
                  if(InpEnableDebug)
                     Print("-->Recovery Opened OK from Buy BE Hit.");
                 }
              }
           }
        }
      // --- Case B: Sell Survivor ---
      else
         if(!isOpenB && isOpenS)
           {
            ModifySLToEntry(InpMagicMain, activeMainPairs[i].sellTicket, activeMainPairs[i]); // Pass struct copy or modify inside
            if(activeMainPairs[i].sellSLAtBE)
              {
               TrailSLMainTrade(activeMainPairs[i].sellTicket, activeMainPairs[i]);   // Pass struct copy or modify inside
              }
            // Check Recovery Trigger
            if(activeMainPairs[i].sellSLAtBE && UseRecoveryTrade && !IsRecoveryBlockedForPair(activeMainPairs[i].guid))
              {
               MqlTick tk;
               if(SymbolInfoTick(_Symbol,tk) && tk.ask>=activeMainPairs[i].sellEntry)
                 {
                  if(InpEnableDebug)
                     PrintFormat("Pair %s: Price Hit SELL BE @%.5f -> TRIG REC",activeMainPairs[i].guid,activeMainPairs[i].sellEntry);
                  if(OpenRecoveryTrade())
                    {
                     if(InpEnableDebug)
                        Print("-->Recovery Opened OK from Sell BE Hit.");
                    }
                 }
              }
           }
         // --- Case C: Both Open --- (No action needed)
         // --- Case D: Both Closed ---
         else
            if(!isOpenB && !isOpenS)
              {
               RemoveActivePair(i);
              }
     } // End loop active pairs
  } // End ManagePositions

//+------------------------------------------------------------------+
//| Helper: Check if Recovery is Blocked for a Pair GUID             |
//+------------------------------------------------------------------+
bool IsRecoveryBlockedForPair(string pair_guid)
  {
   for(int i=0; i<ArraySize(trackedPositions); i++)
     {
      if(trackedPositions[i].guid == pair_guid && trackedPositions[i].blockRecovery)
        {
         if(InpEnableDebug)
            PrintFormat("Check Recovery Block: Pair %s IS BLOCKED.", pair_guid);
         return true; // Found blocked entry for this GUID
        }
     }
// if(InpEnableDebug) PrintFormat("Check Recovery Block: Pair %s NOT blocked.", pair_guid);
   return false; // No block found
  }


//+------------------------------------------------------------------+
//| ModifySLToEntry: Sets SL=Entry for SPECIFIC Main Trade ticket    |
//|                    Also updates the passed PAIR state            |
//+------------------------------------------------------------------+
void ModifySLToEntry(int magic, ulong survivorTicket, HedgePairInfo &pair)   // Accept pair by REFERENCE
  {
   if(magic != InpMagicMain || survivorTicket == 0)
      return;
   if(!PositionSelectByTicket(survivorTicket))
      return;
   if(PositionGetInteger(POSITION_MAGIC) != magic)
      return;
   double entry=PositionGetDouble(POSITION_PRICE_OPEN), currSL=PositionGetDouble(POSITION_SL), currTP=PositionGetDouble(POSITION_TP), pt=_Point;
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   bool needsUpdate = false, flagStateChanged=false;
// Check current flag state in the PASSED structure
   bool isAlreadyBE = (posType==POSITION_TYPE_BUY) ? pair.buySLAtBE : pair.sellSLAtBE;
// Determine if SL needs modification
   if(MathAbs(currSL-entry) > pt*1.5)
      needsUpdate = true;
   if(needsUpdate && !isAlreadyBE)   // Needs update AND flag not already set
     {
      if(InpEnableDebug)
         PrintFormat("ModSL->BE: Pair %s Pos %I64u (%s) Moving SL: %.5f -> %.5f", pair.guid, survivorTicket, EnumToString(posType), currSL, entry);
      trade.SetExpertMagicNumber(magic);
      if(trade.PositionModify(survivorTicket,entry,currTP))  // Modify SL
        {
         // SUCCESS - Update flag IN THE PAIR STRUCTURE passed by reference
         if(posType==POSITION_TYPE_BUY)
            pair.buySLAtBE=true;
         else
            pair.sellSLAtBE=true;
         if(InpEnableDebug)
            PrintFormat("... OK -> Set Pair %s %s BE Flag.", pair.guid, EnumToString(posType));
         flagStateChanged = true; // Record flag was changed
        }
      else
        {
         PrintFormat("ModSL->BE ERROR Pair %s Pos %I64u! Err:%d %s", pair.guid, survivorTicket, trade.ResultRetcode(), trade.ResultComment());
        }
     }
   else
      if(!needsUpdate && !isAlreadyBE)    // Already at BE, just ensure flag is set
        {
         if(posType==POSITION_TYPE_BUY)
            pair.buySLAtBE=true;
         else
            pair.sellSLAtBE=true;
         flagStateChanged = true;
         // if(InpEnableDebug) PrintFormat("ModSL->BE: Pair %s Pos %I64u SL already ok. SET Pair BE Flag.", pair.guid, survivorTicket);
        }
  } // End ModifySLToEntry (Main)


//+------------------------------------------------------------------+
//| ModifySLToEntry: Simpler version for Recovery Trades             |
//+------------------------------------------------------------------+
void ModifySLToEntry(int magic)   // Overload for recovery
  {
   if(magic != InpMagicRecovery)
      return;
   ulong survivorTicket=0;
   int openCnt=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong t=PositionGetTicket(i);
      if(PositionSelectByTicket(t))
        {
         if(PositionGetString(POSITION_SYMBOL)==_Symbol&&PositionGetInteger(POSITION_MAGIC)==magic)
           {
            openCnt++;
            survivorTicket=t;
            if(openCnt>1)
               break;
           }
        }
     }
   if(openCnt==1 && survivorTicket>0 && PositionSelectByTicket(survivorTicket))
     {
      double e=PositionGetDouble(POSITION_PRICE_OPEN), sl=PositionGetDouble(POSITION_SL), tp=PositionGetDouble(POSITION_TP);
      if(MathAbs(sl-e)>_Point*1.5)
        {
         if(InpEnableDebug)
            PrintFormat("ModSL->BE(Rec): Pos %I64u -> %.5f",survivorTicket,e);
         trade.SetExpertMagicNumber(magic);
         if(!trade.PositionModify(survivorTicket,e,tp)) {/*Log Err*/}
         else {/*Log OK*/}
        }
     }
  } // End ModifySLToEntry (Recovery)

//+------------------------------------------------------------------+
//| TrailSLMainTrade: Stage 2 trailing for SPECIFIC ticket/pair      |
//+------------------------------------------------------------------+
void TrailSLMainTrade(ulong survivorTicket, HedgePairInfo &pair)   // Accept pair by REFERENCE
  {
   if(survivorTicket==0 || !PositionSelectByTicket(survivorTicket))
      return;
   if(PositionGetInteger(POSITION_MAGIC)!=InpMagicMain)
      return;
   ENUM_POSITION_TYPE posType=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
// Check PAIR flag first
   if(!((posType==POSITION_TYPE_BUY && pair.buySLAtBE)||(posType==POSITION_TYPE_SELL && pair.sellSLAtBE)))
      return; // Must be at BE
   double e=PositionGetDouble(POSITION_PRICE_OPEN), sl=PositionGetDouble(POSITION_SL), tp=PositionGetDouble(POSITION_TP), pt=_Point;
   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t))
      return;
   double profPts=0;
   if(posType==POSITION_TYPE_BUY)
      profPts=(t.bid-e)/pt;
   else
      profPts=(e-t.ask)/pt;
   if(profPts >= InpTrail2TriggerMain)   // Trigger Profit Reached
     {
      double newSL=0;
      int d=_Digits;
      if(posType==POSITION_TYPE_BUY)
        {
         newSL=NormalizeDouble(e+InpTrail2OffsetMain*pt,d);
         newSL=MathMin(newSL,NormalizeDouble(t.bid-pt*5,d));
        }
      else
        {
         newSL=NormalizeDouble(e-InpTrail2OffsetMain*pt,d);
         newSL=MathMax(newSL,NormalizeDouble(t.ask+pt*5,d));
        }
      bool modify=false;
      if(posType==POSITION_TYPE_BUY && newSL>sl+pt*0.5)
         modify=true;
      if(posType==POSITION_TYPE_SELL && newSL<sl-pt*0.5)
         modify=true;
      if(modify)
        {
         if(InpEnableDebug)
            PrintFormat("TrailSL Stage2: Pair %s Pos %I64u -> SL %.5f (Prof %.0fp)",pair.guid,survivorTicket,newSL,profPts);
         trade.SetExpertMagicNumber(InpMagicMain);
         if(trade.PositionModify(survivorTicket,newSL,tp))  // SUCCESS
           {
            if(InpEnableDebug)
               Print("--> Trail Stage2 OK");
            // Track for blocking recovery IF IT FAILS LATER
            bool tracked=false;
            for(int j=0;j<ArraySize(trackedPositions);j++)
              {
               if(trackedPositions[j].ticket==survivorTicket)
                 {
                  trackedPositions[j].trailedSL=newSL;
                  tracked=true;
                  break;
                 }
              }
            if(!tracked)
              {
               int sz=ArraySize(trackedPositions);
               if(ArrayResize(trackedPositions,sz+1)==sz+1)
                 {
                  trackedPositions[sz].ticket=survivorTicket;
                  trackedPositions[sz].guid=pair.guid;
                  trackedPositions[sz].trailedSL=newSL;
                  trackedPositions[sz].entryPrice=e;
                  trackedPositions[sz].posType=posType;
                  trackedPositions[sz].blockRecovery=false;
                  if(InpEnableDebug)
                     Print("... Added Pos %I64u to TRAILED block watch list.", survivorTicket);
                 }
               else
                 {
                  Print("Trail ERR:Resize Tracked");
                 }
              }
           }
         else
           {
            PrintFormat("TrailSL Stage2 ERROR: Pair %s Pos %I64u Fail %d %s", pair.guid, survivorTicket, trade.ResultRetcode(),trade.ResultComment());   // FAILURE
           }
        } // End Modify
     } // End Profit Trigger
  } // End TrailSLMainTrade

//+------------------------------------------------------------------+
//| TrailSLRecoveryTrade: Moves individual recovery SL to BE         |
//+------------------------------------------------------------------+
void TrailSLRecoveryTrade()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong tk=PositionGetTicket(i);
      if(PositionSelectByTicket(tk))
        {
         if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagicRecovery)
           {
            double e=PositionGetDouble(POSITION_PRICE_OPEN), sl=PositionGetDouble(POSITION_SL);
            if(MathAbs(e-sl)<_Point*1.5)
               continue;
            ENUM_POSITION_TYPE pT=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            MqlTick t;
            if(!SymbolInfoTick(_Symbol,t))
               continue;
            double pts=0;
            if(pT==POSITION_TYPE_BUY)
               pts=(t.bid-e)/_Point;
            else
               pts=(e-t.ask)/_Point;
            if(pts>=InpRecoveryProfitForBEPoints)
              {
               if(InpEnableDebug)
                  PrintFormat("TrailSL Rec: Pos %I64u -> Entry %.5f (Prof %.0fp)",tk,e,pts);
               trade.SetExpertMagicNumber(InpMagicRecovery);
               if(!trade.PositionModify(tk,e,PositionGetDouble(POSITION_TP)))
                 {
                  Print("TrailSL Rec ERR Modify");
                 }
               else {/*OK*/}
              }
           }
        }
     }
  } // End TrailSLRecoveryTrade

//+------------------------------------------------------------------+
//| DeleteOldLinesIfNoPositions: Removes old VLines if no pos open   |
//+------------------------------------------------------------------+
void DeleteOldLinesIfNoPositions(datetime currentTime)
  {
   if(CountOpenPositions()==0)
     {
      datetime today=currentTime-(currentTime%86400);
      for(int i=ObjectsTotal(0)-1;i>=0;i--)
        {
         string n=ObjectName(0,i);
         if(StringFind(n,tradingDayLineName)==0)
           {
            if((datetime)ObjectGetInteger(0,n,OBJPROP_TIME,0)<today)
               ObjectDelete(0,n);
           }
        }
     }
  } // End DeleteOldLines

//+------------------------------------------------------------------+
//| PrintTradeStatus: Log current EA state                           |
//+------------------------------------------------------------------+
void PrintTradeStatus(string context = "")
  {
   if(!InpEnableDebug)
      return;
   string status=StringFormat("\n==== MAVERICK STATUS (%s) ====", context==""?TimeToString(TimeCurrent(),TIME_SECONDS):context);
   status+=StringFormat("\nDate: %s | Rec Active:%s",TimeToString(currentTradeDate,TIME_DATE), (CountOpenPositionsMagic(InpMagicRecovery) > 0)?"Y":"N");
   status+=StringFormat("\nProfit(Run): %.2f | Open Pos: Total=%d (Main=%d Rec=%d)", totalRealizedProfit,CountOpenPositions(),CountOpenPositionsMagic(InpMagicMain),CountOpenPositionsMagic(InpMagicRecovery));
   int ac=ArraySize(activeMainPairs);
   status+=StringFormat("\nActive Main Pairs (%d):",ac);
   if(ac>0)
     {
      for(int i=0;i<ac;i++)
        {
         status+=StringFormat("\n [%d] %s (B:%I64u%s S:%I64u%s)",i,activeMainPairs[i].guid, activeMainPairs[i].buyTicket,activeMainPairs[i].buySLAtBE?" BE":"", activeMainPairs[i].sellTicket,activeMainPairs[i].sellSLAtBE?" BE":"");
        }
     }
   else
      status+=" None";
   if(lastClosedPair.guid!="")
     {
      status+=StringFormat("\nLast Closed (%s): P=%.2f (B:%.2f%s S:%.2f%s) Eval:%s",lastClosedPair.guid,lastClosedPair.totalProfit, lastClosedPair.buyProfit,lastClosedPair.buyHitSL?" SL":"",lastClosedPair.sellProfit,lastClosedPair.sellHitSL?" SL":"", lastClosedPair.evaluated?"Y":"N");
     }
   else
      status+="\nLast Closed Pair: N/A";
   status+="\n==================================================";
   Print(status);
  } // End PrintTradeStatus

//+------------------------------------------------------------------+
//| CreateTradingDayLine: Draw vertical marker line on chart         |
//+------------------------------------------------------------------+
void CreateTradingDayLine(datetime lineTime)
  {
   MqlDateTime dt;
   TimeToStruct(lineTime, dt);
   string sfx=StringFormat("%04d%02d%02d_%02d%02d",dt.year,dt.mon,dt.day,dt.hour,dt.min);
   string name=tradingDayLineName+"_"+sfx;
   if(ObjectFind(0,name)!=-1)
      return; // Don't duplicate
   if(ObjectCreate(0,name,OBJ_VLINE,0,lineTime,0))
     {
      ObjectSetInteger(0,name,OBJPROP_COLOR,clrGreen);
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      ObjectSetString(0,name,OBJPROP_TOOLTIP,"\n");
     }
   else {/* Error Log */}
  }

//+------------------------------------------------------------------+
//| UpdateRunningTotal: Dashboard display function                   |
//+------------------------------------------------------------------+
void UpdateRunningTotal()
  {
   if(!ShowDashboard)
     {
      ObjectDelete(0, DASHBOARD_BG_NAME);   // Hide/clear if disabled
      Comment("");
      return;
     }
   double unrealP=0.0;
   int mainC=0, recC=0;
   for(int i=0; i<PositionsTotal(); i++)
     {
      ulong t=PositionGetTicket(i);
      if(PositionSelectByTicket(t) && PositionGetString(POSITION_SYMBOL)==_Symbol)
        {
         long m=PositionGetInteger(POSITION_MAGIC);
         if(m==InpMagicMain||m==InpMagicRecovery)
           {
            unrealP+=PositionGetDouble(POSITION_PROFIT);
            if(m==InpMagicMain)
               mainC++;
            else
               recC++;
           }
        }
     }
   double runningT=totalRealizedProfit+unrealP;
   string curr=AccountInfoString(ACCOUNT_CURRENCY);
   string nl="\r\n";
   string ind=" "; // Indent
   string dsb=StringFormat("%s=== MAVERICK EA (v%.2f) ===%s%sTime: %s%s",ind,_Digits==3?1.63:1.65,nl,ind,TimeToString(TimeCurrent(),TIME_SECONDS),nl);

   string state="Idle/"+InpTradeTime;
   if(recC > 0) // Check recovery count first
      state = "[RECOVERY ACTIVE]";
   else if (mainC > 0) // Then check main count
      state = "Trade(s) Active";
   dsb+=StringFormat("%sStatus: %s%s",ind,state,nl);
   dsb+=ind+"------------------------------"+nl;
   dsb+=StringFormat("%sRealized (Run): %+.2f %s%s",ind,totalRealizedProfit,curr,nl);
   dsb+=StringFormat("%sUnrealized P/L: %+.2f %s%s",ind,unrealP,curr,nl);
   dsb+=StringFormat("%sRunning Total : %+.2f %s%s",ind,runningT,curr,nl);
   dsb+=ind+"------------------------------"+nl;
   dsb+=StringFormat("%sOpen Pos: Main=%d | Recov=%d%s",ind,mainC,recC,nl);
   dsb+=ind+"-- Last 5 Closed (Comment) ---"+nl;
   bool foundT=false;
   for(int i=4; i>=0; i--)
     {
      if(lastFiveTrades[i].time>0)
        {
         string ps=StringFormat("%.2f",lastFiveTrades[i].profit);
         dsb+=StringFormat("%s %s %s (%s)%s",ind,lastFiveTrades[i].profit>=0?"+":"-",ps,lastFiveTrades[i].comment,nl);
         foundT=true;
        }
     }
   if(!foundT)
      dsb+=ind+" (None logged yet)"+nl;
   dsb+=ind+"==============================";
// Use Comment to display - simple multi-line display
   Comment(dsb);
// ChartRedraw(); // Avoid frequent redraws
  } // End UpdateRunningTotal


//+------------------------------------------------------------------+
//| CheckTrackedPositionsCrossed: Debug function (Confirms SL state) |
//+------------------------------------------------------------------+
void CheckTrackedPositionsCrossed()
  {
   if(!InpEnableDebug)
      return; // Skip if debug off
   for(int i=0; i<ArraySize(trackedPositions); i++)
     {
      if(trackedPositions[i].blockRecovery)
         continue; // Skip if already blocked
      if(!PositionSelectByTicket(trackedPositions[i].ticket))  // Position is closed
        {
         // if(InpEnableDebug) PrintFormat("CheckTracked: Tracked Pos %I64u (GUID %s) is closed. Block status should reflect outcome.", trackedPositions[i].ticket, trackedPositions[i].guid);
         // Note: Actual blocking is set in HandlePositionClose based on SL reason and trail status
        }
     }
  } // End CheckTrackedPositionsCrossed


//+------------------------------------------------------------------+
//| Get Profit of Last Deal for Magic (Within Current Day)           |
//+------------------------------------------------------------------+
double GetLastDealProfit(int magic)
  {
   double p=0.0;
   if(HistorySelect(currentTradeDate,TimeCurrent()))
     {
      int tot=HistoryDealsTotal();
      for(int i=tot-1; i>=0; i--)
        {
         ulong dt=HistoryDealGetTicket(i);
         if(HistoryDealSelect(dt)&&HistoryDealGetInteger(dt,DEAL_MAGIC)==magic)
           {
            if(HistoryDealGetInteger(dt,DEAL_ENTRY)==DEAL_ENTRY_OUT)
               p=HistoryDealGetDouble(dt,DEAL_PROFIT);
            break;
           }
        }
     }
   return p;
  }

// --- End of File ---
//+------------------------------------------------------------------+
