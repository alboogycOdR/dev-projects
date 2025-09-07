//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                      Maverick EA |
//|                                      Copyright 2025, kingdom_f   |
//|                                       https://t.me/AlisterFx/    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, kingdom financier"
#property link      "https://t.me/AlisterFx/"
#property version   "1.7" // Multiple Recovery Pair Handling
#property description "\n\nMaverick EA"
#property description "\n____________"
#property description "\nHedging System"
#property description "\nMultiple Main & Recovery Pair Handling"
//+------------------------------------------------------------------+
//| Expert Advisor: MAVERICK                                         |
//| Description: MT5 Hedge EA allowing multiple concurrent main      |
//|              and recovery pairs. Recovery only on BE hit.        |
//| Version: 1.7 (Multiple Recovery Refactor)                        |
//| Author: Alister / AI Refactor                                    |
//+------------------------------------------------------------------+
/*
 Refactor Notes (v1.7):
 - Added RecoveryPairInfo struct and activeRecoveryPairs array.
 - Recovery management now iterates activeRecoveryPairs.
 - Removed recoveryTradeActive and recoveryUsedToday flags. State managed by arrays.
 - Recovery still only triggered by Main survivor hitting BE stop.
 - Recovery blocking via TrackedPosition retained.
 - Main trades open based on time, regardless of active recovery pairs.
*/
#include <Trade/Trade.mqh>
CTrade trade;
//--------------------------------------------------//
//               INPUT PARAMETERS (Unchanged)      //
//--------------------------------------------------//
input group "Main Trade Settings"
input double   InpLotSize = 0.2;
input int      InpSLPointsMain = 250000;
input int      InpTPPointsMain = 1000000;
input string   InpTradeTime = "00:00";
input int      InpTrail2TriggerMain = 500000;
input int      InpTrail2OffsetMain  = 250000;
input int      InpMagicMain = 7777777;
input double   BREAKEVEN_SL_TOLERANCE_FACTOR=2.0;

input group "Recovery Trade Settings"
input bool     UseRecoveryTrade        = true;
input double   InpLotSizeRecovery      = 0.4;
input int      InpSLPointsRecovery     = 500000;
input int      InpTPPointsRecovery     = 1000000;
input int      InpMagicRecovery        = 8888888;
input int      InpRecoveryProfitForBEPoints = 500000;
input double   BreakevenThreshold = -5.0; // Logging only

input group "Other Settings"
input bool     InpEnableDebug        = true;
input int      UpdateFrequency = 1000;
input bool     InpIsLogging=false;
input bool     ShowDashboard = true;
enum ENUM_DASHBOARD_POSITION { DASHBOARD_TOP_LEFT, DASHBOARD_TOP_RIGHT, DASHBOARD_BOTTOM_LEFT, DASHBOARD_BOTTOM_RIGHT };
input ENUM_DASHBOARD_POSITION DashboardPosition = DASHBOARD_TOP_LEFT;

//--------------------------------------------------//
//           STRUCTURES & GLOBAL VARIABLES
//--------------------------------------------------//

// --- Main Pair Tracking ---
struct HedgePairInfo {
   string            guid;
   ulong             buyTicket;
   ulong             sellTicket;
   double            buyEntry;
   double            sellEntry;
   bool              buySLAtBE;
   bool              sellSLAtBE;
   datetime          openTime;
};
HedgePairInfo activeMainPairs[]; // Dynamic array for active Main pairs

// --- Recovery Pair Tracking ---
struct RecoveryPairInfo {
   string            guid;
   ulong             buyTicket;
   ulong             sellTicket;
   double            buyEntry;
   double            sellEntry;
   // Recovery typically just moves survivor to BE, may not need individual BE flags like main pairs
   datetime          openTime;
};
RecoveryPairInfo activeRecoveryPairs[]; // Dynamic array for active Recovery pairs


// -- State Variables --
// REMOVED: bool recoveryTradeActive = false;
datetime mainTradeOpenTime = 0;   // Time latest main pair opened
double adjustedLotSize = 0;       // Adjusted Main Lot
double adjustedLotSizeRecovery = 0; // Adjusted Recovery Lot

// -- Daily Tracking Variables --
datetime currentTradeDate = 0;      // Start of current trading day
double dailyCumulativeProfit = 0.0; // Informational P/L
// REMOVED: bool recoveryUsedToday = false; // Allows multiple recoveries now
// REMOVED: bool dailyTradingEnded = false; // Main trades continue regardless

// -- Chart & Info Variables --
string infoLabelPrefix = "MAVERICK_";
string tradingDayLineName = "MAVERICK_TRADING_DAY_LINE";
string currentTradeGuid = ""; // Temp storage during main pair opening

// -- Profit/Trade History Tracking --
struct TradeInfo {
   double profit;
   datetime time;
   string comment;
};
TradeInfo lastFiveTrades[5]; // Display array
double totalRealizedProfit = 0.0; // Cumulative realized profit for EA run

// -- Recently Closed Pair Logging --
struct TradeResultPair { // Only for logging state
   string            guid;
   bool              buyHitSL;
   bool              sellHitSL;
   double            buyProfit;
   double            sellProfit;
   double            totalProfit;
   bool              buyClosed;
   bool              sellClosed;
   bool              evaluated;
};
TradeResultPair lastClosedPair; // Temp storage for logging last pair close event

// -- Trailed Position Tracking (for blocking recovery) --
struct TrackedPosition {
   ulong             ticket;
   string            guid;
   double            trailedSL;
   double            entryPrice;
   ENUM_POSITION_TYPE posType;
   bool              blockRecovery; // Block flag is key here
};
TrackedPosition trackedPositions[];

// Dashboard Object Names
#define DASHBOARD_BG_NAME   infoLabelPrefix + "Dashboard_BG"
#define DASHBOARD_TEXT_NAME infoLabelPrefix + "Dashboard_Text"

//+------------------------------------------------------------------+
//| Function: Is Pair at Breakeven (Logging only)                   |
//+------------------------------------------------------------------+
bool IsPairAtEffectiveBreakeven(double totalProfit)
{
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


//+------------------------------------------------------------------+
//| Class CTradeTransaction: Base for handling trade events.         |
//+------------------------------------------------------------------+
class CTradeTransaction {
public:
   CTradeTransaction(void)  {   }
   ~CTradeTransaction(void)  {   }
   void              OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result);
   string            GetOriginalCommentForDeal(ulong deal_ticket); // Made public
   string            ExtractGuidFromComment(string comment);      // Made public
   void              UpdateLastTrades(double profit, datetime time, string comment); // Made public
   void              UpdateLastClosedPairInfo(const string guid, const string comment, double profit, bool sl_hit); // Made public

protected: // Virtual methods overridden by CExtTransaction
   virtual void      TradeTransactionOrderPlaced(ulong order) {} virtual void TradeTransactionOrderModified(ulong order) {}
   virtual void      TradeTransactionOrderDeleted(ulong order) {} virtual void TradeTransactionOrderExpired(ulong order) {}
   virtual void      TradeTransactionOrderTriggered(ulong order) {} virtual void TradeTransactionPositionOpened(ulong position, ulong deal) {}
   virtual void      TradeTransactionPositionStopTake(ulong position, ulong deal) {} virtual void TradeTransactionPositionClosed(ulong position, ulong deal) {}
   virtual void      TradeTransactionPositionCloseBy(ulong position, ulong deal) {} virtual void TradeTransactionPositionModified(ulong position) {}
}; // End CTradeTransaction Class


// --- Helper function implementations (moved out for clarity, but still part of the class conceptually) ---
string CTradeTransaction::GetOriginalCommentForDeal(ulong deal_ticket)   /* Implementation unchanged */
{
   ulong ot=HistoryDealGetInteger(deal_ticket,DEAL_ORDER);
   if(!HistoryOrderSelect(ot))
      return "";
   ulong pid=HistoryDealGetInteger(deal_ticket,DEAL_POSITION_ID);
   if(pid>0&&HistorySelectByPosition(pid)) {
      int dt=HistoryDealsTotal();
      for(int i=0;i<dt;i++) {
         ulong pdt=HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(pdt,DEAL_ENTRY)==DEAL_ENTRY_IN) {
            ulong oot=HistoryDealGetInteger(pdt,DEAL_ORDER);
            if(HistoryOrderSelect(oot))
               return HistoryOrderGetString(oot,ORDER_COMMENT);
            break;
         }
      }
   }
   return HistoryOrderGetString(ot,ORDER_COMMENT);
}
string CTradeTransaction::ExtractGuidFromComment(string comment)   /* Implementation unchanged */
{
   if(comment==NULL||StringLen(comment)<=1)
      return"";
   if(StringSubstr(comment,0,1)=="B"||StringSubstr(comment,0,1)=="S")
      return StringSubstr(comment,1);
   if(StringLen(comment)>2&&(StringSubstr(comment,0,2)=="RB"||StringSubstr(comment,0,2)=="RS"))
      return StringSubstr(comment,2);
   return"";
}
void CTradeTransaction::UpdateLastTrades(double profit, datetime time, string comment)   /* Implementation unchanged */
{
   for(int i=0;i<4;i++) {
      lastFiveTrades[i]=lastFiveTrades[i+1];
   }
   lastFiveTrades[4].profit=profit;
   lastFiveTrades[4].time=time;
   lastFiveTrades[4].comment=comment;
}
void CTradeTransaction::UpdateLastClosedPairInfo(const string guid, const string comment, double profit, bool sl_hit)   /* Implementation unchanged */
{
   if(guid=="")
      return;
   if(lastClosedPair.guid!=guid) {
      lastClosedPair.guid=guid;
      lastClosedPair.buyProfit=0.0;
      lastClosedPair.sellProfit=0.0;
      lastClosedPair.buyHitSL=false;
      lastClosedPair.sellHitSL=false;
      lastClosedPair.totalProfit=0.0;
      lastClosedPair.buyClosed=false;
      lastClosedPair.sellClosed=false;
      lastClosedPair.evaluated=false;
   }
   string pfx=StringSubstr(comment,0,1);
   bool was_be_sl_hit = sl_hit; // Interpret the passed boolean as indicating a BE SL hit specifically
   if(pfx=="B"&&!lastClosedPair.buyClosed) {
      lastClosedPair.buyProfit=profit;
      lastClosedPair.buyHitSL = was_be_sl_hit; // Store if this closure was a BE SL hit
      lastClosedPair.buyClosed=true;
   }
   else if(pfx=="S"&&!lastClosedPair.sellClosed) {
      lastClosedPair.sellProfit=profit;
      lastClosedPair.sellHitSL = was_be_sl_hit; // Store if this closure was a BE SL hit
      lastClosedPair.sellClosed=true;
   }
   if(lastClosedPair.buyClosed&&lastClosedPair.sellClosed) {
      lastClosedPair.totalProfit=lastClosedPair.buyProfit+lastClosedPair.sellProfit;
      lastClosedPair.evaluated=true;
      if(InpEnableDebug)
         PrintFormat("LogClosePair: %s P:%.2f",guid,lastClosedPair.totalProfit);
   }
}

// --- OnTradeTransaction Implementation ---
void CTradeTransaction::OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
// Routing Logic (unchanged)
   if(IS_TRANSACTION_ORDER_PLACED)
      TradeTransactionOrderPlaced(result.order);
   else if(IS_TRANSACTION_ORDER_MODIFIED)
      TradeTransactionOrderModified(result.order);
   else if(IS_TRANSACTION_ORDER_DELETED)
      TradeTransactionOrderDeleted(trans.order);
   else if(IS_TRANSACTION_ORDER_EXPIRED)
      TradeTransactionOrderExpired(trans.order);
   else if(IS_TRANSACTION_ORDER_TRIGGERED)
      TradeTransactionOrderTriggered(trans.order);
   else if(IS_TRANSACTION_POSITION_OPENED)
      TradeTransactionPositionOpened(trans.position,trans.deal);
   else if(IS_TRANSACTION_POSITION_STOP_TAKE)
      TradeTransactionPositionStopTake(trans.position,trans.deal);
   else if(IS_TRANSACTION_POSITION_CLOSED)
      TradeTransactionPositionClosed(trans.position,trans.deal);
   else if(IS_TRANSACTION_POSITION_CLOSEBY)
      TradeTransactionPositionCloseBy(trans.position,trans.deal);
   else if(IS_TRANSACTION_POSITION_MODIFIED)
      TradeTransactionPositionModified(request.position);
}

//+------------------------------------------------------------------+
//| CExtTransaction: Extended class with EA-specific logic.          |
//+------------------------------------------------------------------+
class CExtTransaction : public CTradeTransaction {
   // Removed callback members/methods
public:
   CExtTransaction() {} // Constructor

protected: // Override base class virtual methods
   // --- Basic Logging (unchanged from prev full version) ---
   virtual void      TradeTransactionOrderPlaced(ulong o) override
   {
      // FIX: Select the order before getting its properties
      if(OrderSelect(o)) {
         long magic = OrderGetInteger(ORDER_MAGIC);
         if((magic==InpMagicMain || magic==InpMagicRecovery) && InpEnableDebug && InpIsLogging)
            PrintFormat("Log: Order Placed %I64u (Magic %d)", o, magic);
      }
      else {
         if(InpEnableDebug && InpIsLogging)
            PrintFormat("Log Error: Could not select placed order %I64u", o);
      }
   }
   virtual void      TradeTransactionOrderModified(ulong o) override
   {
      // FIX: Select the order before getting its properties
      if(OrderSelect(o)) {
         long magic = OrderGetInteger(ORDER_MAGIC);
         if((magic==InpMagicMain || magic==InpMagicRecovery) && InpEnableDebug && InpIsLogging)
            PrintFormat("Log: Order Modified %I64u (Magic %d)", o, magic);
      }
      else {
         if(InpEnableDebug && InpIsLogging)
            PrintFormat("Log Error: Could not select modified order %I64u", o);
      }
   }
   virtual void      TradeTransactionOrderDeleted(ulong o)override
   {
      if(InpEnableDebug&&InpIsLogging)
         PrintFormat("Log: Order Del %I64u",o);
   }
   virtual void      TradeTransactionOrderExpired(ulong o)override
   {
      if(InpEnableDebug&&InpIsLogging)
         PrintFormat("Log: Order Exp %I64u",o);
   }
   virtual void      TradeTransactionOrderTriggered(ulong o) override
   {
      // FIX: Select the order before getting its properties (Even if the short version did it, ensure explicit check)
      if(OrderSelect(o)) {
         long magic = OrderGetInteger(ORDER_MAGIC);
         ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if((magic == InpMagicMain || magic == InpMagicRecovery) && InpEnableDebug && InpIsLogging)
            PrintFormat("Log: Order Triggered %I64u (Magic %d, Type %s)", o, magic, EnumToString(type));
      }
      else {
         if(InpEnableDebug && InpIsLogging)
            PrintFormat("Log Error: Could not select triggered order %I64u", o);
      }
   }
   virtual void      TradeTransactionPositionModified(ulong p)override
   {
      if(PositionSelectByTicket(p)) {
         long m=PositionGetInteger(POSITION_MAGIC);
         if((m==InpMagicMain||m==InpMagicRecovery)&&InpEnableDebug&&InpIsLogging)
            PrintFormat("Log: Pos %I64u SL/TP Mod OK M:%d",p,m);
      }
   }
   virtual void      TradeTransactionPositionOpened(ulong p, ulong d)override
   {
      long m=HistoryDealGetInteger(d,DEAL_MAGIC);
      if((m==InpMagicMain||m==InpMagicRecovery)&&InpEnableDebug) PrintFormat("Log: Pos Opened %I64u M:%d (from Deal %I64u)", p,m,d);
   }

   // --- Position Closure Handlers - Delegate to Central Handler ---
   virtual void      TradeTransactionPositionStopTake(ulong p, ulong d) override
   {
      HandlePositionClose(p, d, true);
   }
   virtual void      TradeTransactionPositionClosed(ulong p, ulong d) override
   {
      HandlePositionClose(p, d, false);
   }
   virtual void      TradeTransactionPositionCloseBy(ulong p, ulong d) override
   {
      HandlePositionClose(p, d, false);
   }

   void              HandlePositionClose(ulong position_id, ulong deal, bool isStopTake)
   {
      ENUM_DEAL_REASON closeReason = (ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON);
      long magic = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);
      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
      datetime closeTime = TimeCurrent(); // Use current time for trade log
      ulong closingDealTicket = deal;
      if(position_id == 0) {
         Print("HandleClose Error: Position ID is 0");
         return;
      }
      string dealComment = GetOriginalCommentForDeal(closingDealTicket);
      string guid = ExtractGuidFromComment(dealComment);
      // Log Close Event
      if(InpEnableDebug) {
         string closeCategory = isStopTake ? "Stop/Take" : "Other/CloseBy";
         PrintFormat("LogClose:(%s) M:%d Rsn:%s P:%.2f Pos:%I64u Deal:%I64u Cmt:'%s' GUID:'%s'", closeCategory, magic, EnumToString(closeReason), profit, position_id, closingDealTicket, dealComment, guid);
      }
      // Update Global Stats & Trade History Display
      if(magic == InpMagicMain || magic == InpMagicRecovery) {
         totalRealizedProfit += profit;
         UpdateLastTrades(profit, closeTime, dealComment);
      }
      // Update Active Pair Tracking (Remove closed position from activeMainPairs or activeRecoveryPairs)
      bool pairFoundInTracking = false; // Flag if we located the pair in tracking arrays
      if(magic == InpMagicMain && guid != "") {
         for(int i = 0; i < ArraySize(activeMainPairs); i++) {
            if(activeMainPairs[i].guid == guid) {
               bool clsd=false;
               if(activeMainPairs[i].buyTicket==position_id) {
                  activeMainPairs[i].buyTicket=0;
                  activeMainPairs[i].buySLAtBE=false;
                  clsd=true;
               }
               else if(activeMainPairs[i].sellTicket==position_id) {
                  activeMainPairs[i].sellTicket=0;
                  activeMainPairs[i].sellSLAtBE=false;
                  clsd=true;
               }
               if(clsd) {
                  pairFoundInTracking=true; /*UpdateLastClosedPairInfo...*/ break;
               }
            }
         }
      }
      else if(magic == InpMagicRecovery && guid != "") {
         for(int i = 0; i < ArraySize(activeRecoveryPairs); i++) {
            if(activeRecoveryPairs[i].guid == guid) {
               bool clsd=false;
               if(activeRecoveryPairs[i].buyTicket==position_id) {
                  activeRecoveryPairs[i].buyTicket=0;
                  clsd=true;
               }
               else if(activeRecoveryPairs[i].sellTicket==position_id) {
                  activeRecoveryPairs[i].sellTicket=0;
                  clsd=true;
               }
               if(clsd) {
                  pairFoundInTracking=true;
                  break;
               }
            }
         }
      }
      // --- Update display info regardless of finding in active array (covers positions closed before being fully added?) ---
      UpdateLastClosedPairInfo(guid, dealComment, profit, closeReason == DEAL_REASON_SL);
      // --- Check for Recovery Blocking Condition (SL Hit after Trailing) ---
      if(closeReason == DEAL_REASON_SL) {
         for(int i = 0; i < ArraySize(trackedPositions); i++) {
            if(trackedPositions[i].ticket == position_id) {  // Match closed pos with trailed pos
               double pt = _Point;
               bool trailedOK = false;
               if(trackedPositions[i].posType==POSITION_TYPE_BUY && trackedPositions[i].trailedSL > trackedPositions[i].entryPrice+pt)
                  trailedOK=true;
               else if(trackedPositions[i].posType==POSITION_TYPE_SELL && trackedPositions[i].trailedSL < trackedPositions[i].entryPrice-pt)
                  trailedOK=true;
               if(trailedOK) {  // Set Block flag if SL was truly beyond entry
                  string blockGUID = trackedPositions[i].guid;
                  for(int j=0; j<ArraySize(trackedPositions); j++) {
                     if(trackedPositions[j].guid==blockGUID)
                        trackedPositions[j].blockRecovery=true;
                  }
                  if(InpEnableDebug)
                     PrintFormat("!!! HandleClose: BLOCK REC set for GUID %s from trailed SL Pos %I64u !!!", blockGUID, position_id);
               }
               else { /* Log Hit at BE - Normal */}
               break;
            }
         }
      } // End block check
      // --- *** EVENT-BASED RECOVERY TRIGGER *** ---
      // Check if a MAIN trade hit SL *at* its Breakeven point
      if(magic == InpMagicMain && closeReason == DEAL_REASON_SL && guid != "") {
         // 1. Get Entry Price of the closed position
         double entryPrice = 0.0;
         if(HistorySelectByPosition(position_id)) {
            for(int k=0; k<HistoryDealsTotal(); k++) {
               ulong entryDealTicket = HistoryDealGetTicket(k);
               if(HistoryDealGetInteger(entryDealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN) {
                  if(HistoryDealSelect(entryDealTicket)) { // Need to select deal to get price
                     entryPrice = HistoryDealGetDouble(entryDealTicket, DEAL_PRICE);
                     break;
                  }
               }
            }
         }
         // Fallback? Maybe store entry price in HedgePairInfo during init/open more reliably?
         if(entryPrice == 0.0 && pairFoundInTracking) {  // If History failed, try getting from HedgePairInfo if we found it
            for(int i=0; i<ArraySize(activeMainPairs); i++) {
               if(activeMainPairs[i].guid == guid) {
                  if(activeMainPairs[i].buyTicket == position_id)
                     entryPrice = activeMainPairs[i].buyEntry; // This was incorrect - should use ID
                  else if(activeMainPairs[i].sellTicket == position_id)
                     entryPrice = activeMainPairs[i].sellEntry; // Check if closing position IS buy or sell
                  // Correction: Determine type from closed position_id to get correct entry
                  ENUM_POSITION_TYPE closedPosType = POSITION_TYPE_BUY; // Default assumption
                  if(PositionSelectByTicket(position_id))
                     closedPosType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE); // This won't work, pos is closed!
                  // Need a better way to know if it was Buy or Sell *after* close
                  string closedPosCommentPrefix = StringSubstr(dealComment, 0, 1); // Use original comment
                  if(closedPosCommentPrefix == "B")
                     entryPrice = activeMainPairs[i].buyEntry;
                  else if(closedPosCommentPrefix == "S")
                     entryPrice = activeMainPairs[i].sellEntry;
                  if(entryPrice != 0.0)
                     break;
               }
            }
            if(entryPrice == 0.0 && InpEnableDebug)
               PrintFormat("HandleClose Warn: Couldn't get Entry Price for Pos %I64u via History or Pair Track.", position_id);
         }
         // 2. Get the price at which the SL triggered from the closing deal
         double slExecutionPrice = HistoryDealGetDouble(deal, DEAL_PRICE);
         // 3. Check if SL execution was AT entry (allow tolerance)
         // --- Debugging statements ---
         PrintFormat("Debugging SL check: entryPrice=%.5f, slExecutionPrice=%.5f, _Point=%.5f, BREAKEVEN_SL_TOLERANCE_FACTOR=%d",
                     entryPrice, slExecutionPrice, _Point, BREAKEVEN_SL_TOLERANCE_FACTOR);
         PrintFormat("Debugging SL check: MathAbs(slExecutionPrice - entryPrice)=%.5f", MathAbs(slExecutionPrice - entryPrice));
         PrintFormat("Debugging SL check: (_Point * BREAKEVEN_SL_TOLERANCE_FACTOR)=%.5f", (_Point * BREAKEVEN_SL_TOLERANCE_FACTOR));
         // --- End Debugging ---
         if(entryPrice != 0.0 && MathAbs(slExecutionPrice - entryPrice) <= (_Point * BREAKEVEN_SL_TOLERANCE_FACTOR)) {
            if(InpEnableDebug)
               PrintFormat("HandleClose: Detected MAIN Pos %I64u (Pair %s) SL hit AT ENTRY (SL:%.5f vs Entry:%.5f).", position_id, guid, slExecutionPrice, entryPrice);
            // 4. Check Recovery Conditions (Enabled Globally? Not Blocked for THIS pair?)
            if(UseRecoveryTrade && !IsRecoveryBlockedForPair(guid)) {
               if(InpEnableDebug)
                  PrintFormat("...Recovery Checks Passed for Pair %s. Triggering OpenRecoveryTrade().", guid);
               // Try to open recovery pair
               if(OpenRecoveryTrade()) {
                  if(InpEnableDebug)
                     Print("--> Recovery Opened OK (Triggered by Main BE Stop Hit).");
                  // Note: Allows multiple sequences per day as requested. No "recoveryUsedToday" check.
               }
               else {
                  if(InpEnableDebug)
                     Print("--> OpenRecoveryTrade FAILED (Triggered by Main BE Stop Hit).");
               }
            }
            else {   // Recovery disabled or blocked
               if(InpEnableDebug)
                  PrintFormat("...Recovery Denied for Pair %s (Use:%s, Blocked:%s).", guid, UseRecoveryTrade?"Y":"N", IsRecoveryBlockedForPair(guid)?"Y":"N");
            }
         } // End if SL hit was at Entry
         // else: SL hit was initial SL, no recovery needed based on v1.7 rules.
      } // End if Main Trade SL Hit
   } // End HandlePositionClose

}; // End CExtTransaction Class

//+------------------------------------------------------------------+
//| Global transaction object & System Callback                      |
//+------------------------------------------------------------------+
CExtTransaction ExtTransaction; // Instantiate handler
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   ExtTransaction.OnTradeTransaction(trans,request,result);   // Delegate
}

// --- Removed OnStopLossHit ---

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
// Initialize arrays, profit, lastClosedPair log
   for(int i=0;i<5;i++) {
      lastFiveTrades[i].profit=0.0;
      lastFiveTrades[i].time=0;
      lastFiveTrades[i].comment="";
   }
   ArrayResize(activeMainPairs,0);
   ArrayResize(activeRecoveryPairs,0);
   ArrayResize(trackedPositions,0);
   totalRealizedProfit=0.0;
   lastClosedPair.guid="";
   lastClosedPair.evaluated=false;
// Load history & Initial Profit Sum
   if(HistorySelect(0,TimeCurrent())) {
      int td=HistoryDealsTotal(),tc=0;
      double ps=0.0;
      for(int i=td-1;i>=0;i--) {
         ulong d=HistoryDealGetTicket(i);
         if(HistoryDealSelect(d)) {
            long e=(long)HistoryDealGetInteger(d,DEAL_ENTRY),m=(long)HistoryDealGetInteger(d,DEAL_MAGIC);
            if(e==DEAL_ENTRY_OUT&&(m==InpMagicMain||m==InpMagicRecovery)) {
               ps+=HistoryDealGetDouble(d,DEAL_PROFIT);
               if(tc<5) {
                  lastFiveTrades[tc].profit=HistoryDealGetDouble(d,DEAL_PROFIT);
                  lastFiveTrades[tc].time=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
                  lastFiveTrades[tc].comment=ExtTransaction.GetOriginalCommentForDeal(d);
                  tc++;
               }
            }
         }
      }
      totalRealizedProfit=ps;
      if(tc>1)
         ArrayReverse(lastFiveTrades,0,tc);
      if(InpEnableDebug)
         PrintFormat("OnInit: Profit=%.2f, %d Trades",totalRealizedProfit,tc);
   }
   else
      Print("OnInit Err: HistorySelect");
// Trade Object Setup & Validation
   trade.SetExpertMagicNumber(InpMagicMain);
   trade.SetMarginMode();
   trade.LogLevel(LOG_LEVEL_ERRORS);
   trade.SetTypeFillingBySymbol(_Symbol);
   if(!ValidateAdjustLotSize(InpLotSize,adjustedLotSize,"Main"))
      return INIT_FAILED;
   if(UseRecoveryTrade&&!ValidateAdjustLotSize(InpLotSizeRecovery,adjustedLotSizeRecovery,"Rec"))
      return INIT_FAILED;
   if(InpMagicMain==0||(UseRecoveryTrade&&InpMagicRecovery==0)||InpMagicMain==InpMagicRecovery) {
      Print("OnInit Err: Invalid Magic#");
      return INIT_FAILED;
   }
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      Print("OnInit Warn: Non-Hedging Acc");
// Time & State Init
   MqlDateTime st;
   TimeCurrent(st);
   currentTradeDate=StructToTime(st)-(StructToTime(st)%86400);
   dailyCumulativeProfit=0.0;
// --- Removed Flags Initialization ---
// recoveryTradeActive initialization moved to InitializeExisting..()
// recoveryUsedToday flag removed
// dailyTradingEnded flag removed
// skipRecovery flag removed
// --- Timer ---
   int ts=UpdateFrequency/1000;
   if(ts<1)
      ts=1;
   if(!EventSetTimer(ts)) {
      Print("OnInit Err: SetTimer");
      return INIT_FAILED;
   }
   if(InpEnableDebug)
      PrintFormat("MAVERICK EA Initialized (v%.2f MultiRec). Sym:%s Date:%s",_Digits==3?1.73:1.75,_Symbol,TimeToString(currentTradeDate,TIME_DATE));
// Initialize existing pairs state
   InitializeExistingMainPairs(); // Separate init funcs
   InitializeExistingRecoveryPairs(); // New function
   CreateTradingDayLine(TimeCurrent());
   return INIT_SUCCEEDED;
} // End OnInit


//+------------------------------------------------------------------+
//| Helper Function for Lot Size Validation                          |
//+------------------------------------------------------------------+
bool ValidateAdjustLotSize(const double inputLot, double &adjustedLot, string tradeType)
{
// (Concise implementation - check logs if needed)
   double minL=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), maxL=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX), stepL=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP), limitV=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_LIMIT);
   if(limitV>0&&limitV<maxL)
      maxL=limitV;
   int d=0;
   if(stepL>0&&stepL<1) {
      string s=DoubleToString(stepL,8);
      int p=StringFind(s,".");
      if(p>=0)
         d=StringLen(s)-p-1;
   }
   d=MathMax(0,MathMin(8,d));
   adjustedLot=inputLot;
   if(adjustedLot<minL)
      adjustedLot=minL;
   if(adjustedLot>maxL)
      adjustedLot=maxL;
   if(stepL>0)
      adjustedLot=MathRound(adjustedLot/stepL)*stepL;
   else
      adjustedLot=MathRound(adjustedLot);
   adjustedLot=NormalizeDouble(adjustedLot,d);
   adjustedLot=MathMax(minL,MathMin(adjustedLot,maxL));
   adjustedLot=NormalizeDouble(adjustedLot,d);
   if(MathAbs(adjustedLot-inputLot)>(stepL>0?stepL*0.01:1e-9)) {/*Log Adjust Notice*/} if(adjustedLot<minL||adjustedLot<=0) {
      PrintFormat("VALIDATE LOT ERR: %s final %.f invalid",tradeType,d,adjustedLot,d,minL);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Initialize Existing MAIN Pairs on Startup                       |
//+------------------------------------------------------------------+
void InitializeExistingMainPairs()
{
   if(InpEnableDebug)
      Print("Init: Scanning MAIN pairs...");
   int startCount = ArraySize(activeMainPairs);
   struct FPos {
      ulong t;
      string c;
      double e;
      ENUM_POSITION_TYPE y;
      string g;
   };
   FPos fP[];
   int cnt=0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong tk=PositionGetTicket(i);
      if(PositionSelectByTicket(tk)) {
         if(PositionGetInteger(POSITION_MAGIC)==InpMagicMain&&PositionGetString(POSITION_SYMBOL)==_Symbol) {
            ArrayResize(fP,cnt+1);
            fP[cnt].t=tk;
            fP[cnt].c=PositionGetString(POSITION_COMMENT);
            fP[cnt].e=PositionGetDouble(POSITION_PRICE_OPEN);
            fP[cnt].y=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            fP[cnt].g=ExtTransaction.ExtractGuidFromComment(fP[cnt].c);
            if(fP[cnt].g=="") {/*Warn*/} cnt++;
         }
      }
   }
   if(cnt==0) {
      if(InpEnableDebug)
         Print("Init: No existing MAIN positions.");
      return;
   }
   bool uI[];
   ArrayResize(uI,cnt);
   ArrayInitialize(uI,false);
   for(int i=0;i<cnt;i++) {
      if(uI[i]||fP[i].g=="")
         continue;
      for(int j=i+1;j<cnt;j++) {
         if(uI[j]||fP[j].g=="")
            continue;
         if(fP[i].g==fP[j].g&&fP[i].y!=fP[j].y) {
            int nS=ArraySize(activeMainPairs)+1;
            if(ArrayResize(activeMainPairs,nS)!=nS) {
               /*Err*/ continue;
            }
            int idx=nS-1;
            activeMainPairs[idx].guid=fP[i].g;
            if(fP[i].y==POSITION_TYPE_BUY) {
               activeMainPairs[idx].buyTicket=fP[i].t;
               activeMainPairs[idx].buyEntry=fP[i].e;
               activeMainPairs[idx].sellTicket=fP[j].t;
               activeMainPairs[idx].sellEntry=fP[j].e;
            }
            else {
               activeMainPairs[idx].buyTicket=fP[j].t;
               activeMainPairs[idx].buyEntry=fP[j].e;
               activeMainPairs[idx].sellTicket=fP[i].t;
               activeMainPairs[idx].sellEntry=fP[i].e;
            }
            double bSL=0,sSL=0, pt=_Point;
            // Select BUY position, get SL and Open Time
            if(PositionSelectByTicket(activeMainPairs[idx].buyTicket)) {
               bSL = PositionGetDouble(POSITION_SL);
               activeMainPairs[idx].openTime = (datetime)PositionGetInteger(POSITION_TIME); // Get time here
            }
            else {
               PrintFormat("Init Warn: Could not select MAIN Buy Pos %I64u for properties", activeMainPairs[idx].buyTicket);
               activeMainPairs[idx].openTime = 0; // Set default or handle error
            }
            // Select SELL position, get SL
            if(PositionSelectByTicket(activeMainPairs[idx].sellTicket)) {
               sSL = PositionGetDouble(POSITION_SL);
            }
            else {
               PrintFormat("Init Warn: Could not select MAIN Sell Pos %I64u for SL", activeMainPairs[idx].sellTicket);
            }
            activeMainPairs[idx].buySLAtBE=(MathAbs(bSL-activeMainPairs[idx].buyEntry)<pt*2);
            activeMainPairs[idx].sellSLAtBE=(MathAbs(sSL-activeMainPairs[idx].sellEntry)<pt*2);
            // openTime is now set correctly above
            if(InpEnableDebug)
               PrintFormat("Init: Added MAIN Pair %s",activeMainPairs[idx].guid);
            uI[i]=true;
            uI[j]=true;
            break;
         }
      }
   }
   if(InpEnableDebug)
      PrintFormat("Init: %d MAIN Pairs initialized.", ArraySize(activeMainPairs)-startCount);
   for(int i=0;i<cnt;i++) {
      if(!uI[i])
         if(InpEnableDebug)
            PrintFormat("Init Warn: Unpaired MAIN Pos %I64u",fP[i].t);
   }
} // End InitializeExistingMainPairs

//+------------------------------------------------------------------+
//| Initialize Existing RECOVERY Pairs on Startup                    |
//+------------------------------------------------------------------+
void InitializeExistingRecoveryPairs()
{
   if(!UseRecoveryTrade || InpMagicRecovery == 0)
      return;
   if(InpEnableDebug)
      Print("Init: Scanning RECOVERY pairs...");
   int startCount = ArraySize(activeRecoveryPairs);
   struct FPos {
      ulong t;
      string c;
      double e;
      ENUM_POSITION_TYPE y;
      string g;
   };
   FPos fP[];
   int cnt=0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong tk=PositionGetTicket(i);
      if(PositionSelectByTicket(tk)) {
         if(PositionGetInteger(POSITION_MAGIC)==InpMagicRecovery&&PositionGetString(POSITION_SYMBOL)==_Symbol) {
            ArrayResize(fP,cnt+1);
            fP[cnt].t=tk;
            fP[cnt].c=PositionGetString(POSITION_COMMENT);
            fP[cnt].e=PositionGetDouble(POSITION_PRICE_OPEN);
            fP[cnt].y=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            fP[cnt].g=ExtTransaction.ExtractGuidFromComment(fP[cnt].c);
            if(fP[cnt].g=="") {/*Warn Recovery GUID*/} cnt++;
         }
      }
   }
   if(cnt==0) {
      if(InpEnableDebug)
         Print("Init: No existing RECOVERY positions.");
      return;
   }
   bool uI[];
   ArrayResize(uI,cnt);
   ArrayInitialize(uI,false);
   for(int i=0; i<cnt; i++) {
      if(uI[i]||fP[i].g=="")
         continue;
      for(int j=i+1; j<cnt; j++) {
         if(uI[j]||fP[j].g=="")
            continue;
         if(fP[i].g==fP[j].g&&fP[i].y!=fP[j].y) {
            int nS=ArraySize(activeRecoveryPairs)+1;
            if(ArrayResize(activeRecoveryPairs,nS)!=nS) {
               /*Err*/ continue;
            }
            int idx=nS-1;
            activeRecoveryPairs[idx].guid=fP[i].g;
            if(fP[i].y==POSITION_TYPE_BUY) {
               activeRecoveryPairs[idx].buyTicket=fP[i].t;
               activeRecoveryPairs[idx].buyEntry=fP[i].e;
               activeRecoveryPairs[idx].sellTicket=fP[j].t;
               activeRecoveryPairs[idx].sellEntry=fP[j].e;
            }
            else {
               activeRecoveryPairs[idx].buyTicket=fP[j].t;
               activeRecoveryPairs[idx].buyEntry=fP[j].e;
               activeRecoveryPairs[idx].sellTicket=fP[i].t;
               activeRecoveryPairs[idx].sellEntry=fP[i].e;
            }
            if(PositionSelectByTicket(activeRecoveryPairs[idx].buyTicket))
               activeRecoveryPairs[idx].openTime=(datetime)PositionGetInteger(POSITION_TIME);
            else
               PrintFormat("Init Warn: Could not select RECOVERY Buy Pos %I64u for time", activeRecoveryPairs[idx].buyTicket);
            if(InpEnableDebug)
               PrintFormat("Init: Added RECOVERY Pair %s",activeRecoveryPairs[idx].guid);
            uI[i]=true;
            uI[j]=true;
            break;
         }
      }
   }
   if(InpEnableDebug)
      PrintFormat("Init: %d RECOVERY Pairs initialized.", ArraySize(activeRecoveryPairs)-startCount);
   for(int i=0;i<cnt;i++) {
      if(!uI[i])
         if(InpEnableDebug)
            PrintFormat("Init Warn: Unpaired RECOVERY Pos %I64u",fP[i].t);
   }
} // End InitializeExistingRecoveryPairs


//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   /* Implementation unchanged */ EventKillTimer();
   ObjectsDeleteAll(0,infoLabelPrefix);
   ObjectDelete(0,DASHBOARD_BG_NAME);
   ObjectDelete(0,DASHBOARD_TEXT_NAME);
   ObjectsDeleteAll(0,tradingDayLineName,0,-1);
   if(ShowDashboard)Comment("");
   if(InpEnableDebug)Print("MAVERICK EA Deinitialized R:",reason);
}
//+------------------------------------------------------------------+
//| OnTimer                                                          |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(ShowDashboard)UpdateRunningTotal(); /* CheckTracked... optional */
}
//+------------------------------------------------------------------+
//| NewBar Check                                                     |
//+------------------------------------------------------------------+
bool NewBar()
{
   static datetime pBT=0;
   datetime cBT=iTime(_Symbol,PERIOD_CURRENT,0);
   if(cBT!=pBT) {
      pBT=cBT;
      return true;
   }
   return false;
}
//+------------------------------------------------------------------+
//| OnTick (Throttled by NewBar)                                     |
//+------------------------------------------------------------------+
void OnTick()
{
   ManagePositions();
   if(!NewBar())
      return;
   datetime now=TimeCurrent();
   CheckNewTradingDay(now);
// Open Main Trade Check (Removed dailyTradingEnded & recovery checks)
   MqlDateTime dt;
   TimeToStruct(now,dt);
   string timeStr=StringFormat("%02d:%02d",dt.hour,dt.min);
   if(timeStr==InpTradeTime) {
      static datetime lastOpenAttempt=0;
      if(now-lastOpenAttempt>=55) {
         if(OpenMainTrade())
            lastOpenAttempt=now;
         else
            lastOpenAttempt=now;
      }
   }
}

//+------------------------------------------------------------------+
//| CheckNewTradingDay                                               |
//+------------------------------------------------------------------+
void CheckNewTradingDay(datetime currentTime)
{
   datetime today=currentTime-(currentTime%86400);
   if(today<=currentTradeDate)
      return;
   currentTradeDate=today;
   if(InpEnableDebug)
      PrintFormat("--- New Day: %s ---",TimeToString(today,TIME_DATE));
   dailyCumulativeProfit=0.0;
// recoveryUsedToday/dailyTradingEnded flags removed
   lastClosedPair.guid="";
   lastClosedPair.evaluated=false; // Reset pair log info
   if(InpEnableDebug)
      PrintTradeStatus("After Daily Reset");
   CreateTradingDayLine(currentTime);
}

//+------------------------------------------------------------------+
//| Count Open Positions                                             |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   return CountOpenPositionsMagic(InpMagicMain)+CountOpenPositionsMagic(InpMagicRecovery);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountOpenPositionsMagic(int magic)
{
   int c=0;
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong t=PositionGetTicket(i);
      if(PositionSelectByTicket(t)&&PositionGetString(POSITION_SYMBOL)==_Symbol&&PositionGetInteger(POSITION_MAGIC)==magic)c++;
   }
   return c;
}
//+------------------------------------------------------------------+
//| Generate GUID                                                    |
//+------------------------------------------------------------------+
string GenerateTradeGuid()
{
   return IntegerToString(TimeCurrent())+"-"+IntegerToString(MathRand()%10000);
}
//+------------------------------------------------------------------+
//| Get Pos Ticket from Deal Ticket                                  |
//+------------------------------------------------------------------+
ulong GetPositionTicketByDeal(ulong d)
{
   if(HistoryDealSelect(d))return HistoryDealGetInteger(d,DEAL_POSITION_ID);
   return 0;
}

//+------------------------------------------------------------------+
//| OpenMainTrade: Adds to activeMainPairs                           |
//+------------------------------------------------------------------+
bool OpenMainTrade()   /* Implementation unchanged (Concise version used in full file) */
{
   currentTradeGuid=GenerateTradeGuid();
   string bc="B"+currentTradeGuid, sc="S"+currentTradeGuid;
   if(InpEnableDebug)
      PrintFormat("OpenMain: Try Pair %s L:%.2f",currentTradeGuid,adjustedLotSize);
   trade.SetExpertMagicNumber(InpMagicMain);
   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t)) {
      return false;
   }
   double a=t.ask, b=t.bid, p=_Point, slB=NormalizeDouble(a-InpSLPointsMain*p,_Digits),tpB=NormalizeDouble(a+InpTPPointsMain*p,_Digits),slS=NormalizeDouble(b+InpSLPointsMain*p,_Digits),tpS=NormalizeDouble(b-InpTPPointsMain*p,_Digits);
   ulong bDT=0,sDT=0,bPT=0,sPT=0;
   bool bOK=false,sOK=false;
   if(!trade.Buy(adjustedLotSize,_Symbol,a,slB,tpB,bc)) {
      PrintFormat("OpenMain ERR BUY %d",trade.ResultRetcode());
      return false;
   }
   bDT=trade.ResultDeal();
   if(bDT>0)
      bPT=GetPositionTicketByDeal(bDT);
   if(bPT>0)
      bOK=true;
   else {
      Print("OpenMain ERR Buy Tk");
      return false;
   }
   Sleep(100);
   if(!trade.Sell(adjustedLotSize,_Symbol,b,slS,tpS,sc)) {
      PrintFormat("OpenMain ERR SELL %d! Close B:%I64u",trade.ResultRetcode(),bPT);
      trade.PositionClose(bPT);
      return false;
   }
   sDT=trade.ResultDeal();
   if(sDT>0)
      sPT=GetPositionTicketByDeal(sDT);
   if(sPT>0)
      sOK=true;
   else {
      PrintFormat("OpenMain ERR Sell Tk! Close B:%I64u",bPT);
      trade.PositionClose(bPT);
      return false;
   }
   if(bOK&&sOK) {
      int ns=ArraySize(activeMainPairs)+1;
      if(ArrayResize(activeMainPairs,ns)!=ns) {
         /*ERR Resize Close Both*/trade.PositionClose(bPT);
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
         PrintFormat("Pair %s Added Track",currentTradeGuid);
      mainTradeOpenTime=TimeCurrent();
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| OpenRecoveryTrade: Adds to activeRecoveryPairs                  |
//+------------------------------------------------------------------+
bool OpenRecoveryTrade()
{
   string recGuid = GenerateTradeGuid();
   if(InpEnableDebug)
      PrintFormat("OpenRec: Try Pair %s L:%.2f",recGuid,adjustedLotSizeRecovery);
   string bc="RB"+recGuid, sc="RS"+recGuid;
   trade.SetExpertMagicNumber(InpMagicRecovery);
   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t)) {
      return false;
   }
   double a=t.ask,b=t.bid,p=_Point,slB=NormalizeDouble(a-InpSLPointsRecovery*p,_Digits),tpB=NormalizeDouble(a+InpTPPointsRecovery*p,_Digits),slS=NormalizeDouble(b+InpSLPointsRecovery*p,_Digits),tpS=NormalizeDouble(b-InpTPPointsRecovery*p,_Digits);
   ulong bPT=0,sPT=0;
   bool bOK=false,sOK=false;
   if(!trade.Buy(adjustedLotSizeRecovery,_Symbol,a,slB,tpB,bc)) {
      PrintFormat("OpenRec ERR BUY %d",trade.ResultRetcode());
      return false;
   }
   ulong dB=trade.ResultDeal();
   if(dB>0)
      bPT=GetPositionTicketByDeal(dB);
   if(bPT>0)
      bOK=true;
   else {
      Print("OpenRec ERR Buy Tk");
      return false;
   }
   Sleep(100);
   if(!trade.Sell(adjustedLotSizeRecovery,_Symbol,b,slS,tpS,sc)) {
      PrintFormat("OpenRec ERR SELL %d! Close RB:%I64u",trade.ResultRetcode(),bPT);
      trade.SetExpertMagicNumber(InpMagicRecovery);
      trade.PositionClose(bPT);
      return false;
   }
   ulong dS=trade.ResultDeal();
   if(dS>0)
      sPT=GetPositionTicketByDeal(dS);
   if(sPT>0)
      sOK=true;
   else {
      PrintFormat("OpenRec ERR Sell Tk! Close RB:%I64u",bPT);
      trade.SetExpertMagicNumber(InpMagicRecovery);
      trade.PositionClose(bPT);
      return false;
   }
   if(bOK&&sOK) {
      int ns=ArraySize(activeRecoveryPairs)+1;
      if(ArrayResize(activeRecoveryPairs,ns)!=ns) {
         Print("OpenRec Err Resize! Close %I64u,%I64u",bPT,sPT);
         trade.PositionClose(bPT);
         Sleep(50);
         trade.PositionClose(sPT);
         return false;
      }
      int i=ns-1;
      activeRecoveryPairs[i].guid=recGuid;
      activeRecoveryPairs[i].buyTicket=bPT;
      activeRecoveryPairs[i].sellTicket=sPT;
      activeRecoveryPairs[i].buyEntry=a;
      activeRecoveryPairs[i].sellEntry=b;
      activeRecoveryPairs[i].openTime=TimeCurrent();
      if(InpEnableDebug)
         PrintFormat("Recovery Pair %s Added Track",recGuid);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Helper: Remove element from activeMainPairs array               |
//+------------------------------------------------------------------+
void RemoveActivePair(int index)   /* Implementation unchanged */
{
   int s=ArraySize(activeMainPairs);
   if(index<0||index>=s)
      return; /*if(InpEnableDebug)PrintF("Remove Pair %s Idx %d",activeMainPairs[index].guid,index);*/ if(index<s-1) {
      for(int i=index; i<s-1; i++)
         activeMainPairs[i]=activeMainPairs[i+1];
   }
   if(ArrayResize(activeMainPairs,s-1)!=s-1) {/*Err*/}
}
//+------------------------------------------------------------------+
//| Helper: Remove element from activeRecoveryPairs array            |
//+------------------------------------------------------------------+
void RemoveActiveRecoveryPair(int index)   // New helper for recovery pairs
{
   int size = ArraySize(activeRecoveryPairs);
   if(index<0||index>=size)
      return;
   if(InpEnableDebug)
      PrintFormat("Remove REC Pair %s @ Idx %d",activeRecoveryPairs[index].guid,index);
   if(index<size-1) {
      for(int i=index; i<size-1; i++) {
         activeRecoveryPairs[i]=activeRecoveryPairs[i+1];
      }
   }
   if(ArrayResize(activeRecoveryPairs,size-1)!=size-1) {
      Print("RemoveActiveRecoveryPair ERR: Resize Fail");
   }
}

//+------------------------------------------------------------------+
//| ManagePositions: Iterates Recovery Pairs then Main Pairs        |
//| *** Recovery Trigger via Price hitting BE REMOVED from here ***   |
//| *** It is now handled within HandlePositionClose          ***   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManagePositions()
{
// --- 1. RECOVERY Position Management (Using activeRecoveryPairs array) ---
   int activeRecCount = ArraySize(activeRecoveryPairs);
   for(int i = activeRecCount - 1; i >= 0; i--) { // Iterate Backwards
      // Check current status ONCE at the start of the loop iteration
      bool isRecBuyOpenCurrent = (activeRecoveryPairs[i].buyTicket != 0 && PositionSelectByTicket(activeRecoveryPairs[i].buyTicket));
      bool isRecSellOpenCurrent = (activeRecoveryPairs[i].sellTicket != 0 && PositionSelectByTicket(activeRecoveryPairs[i].sellTicket));
      // Correct state if closed unexpectedly
      if(activeRecoveryPairs[i].buyTicket != 0 && !isRecBuyOpenCurrent) {
         activeRecoveryPairs[i].buyTicket = 0;
         if(InpEnableDebug)
            PrintFormat("ManageRec Info: Pair %s Corrected Stale Rec Buy Ticket.", activeRecoveryPairs[i].guid);
      }
      if(activeRecoveryPairs[i].sellTicket != 0 && !isRecSellOpenCurrent) {
         activeRecoveryPairs[i].sellTicket = 0;
         if(InpEnableDebug)
            PrintFormat("ManageRec Info: Pair %s Corrected Stale Rec Sell Ticket.", activeRecoveryPairs[i].guid);
      }
      // Re-fetch potentially corrected status
      isRecBuyOpenCurrent = (activeRecoveryPairs[i].buyTicket != 0);
      isRecSellOpenCurrent = (activeRecoveryPairs[i].sellTicket != 0);
      // --- Case R1: BOTH Recovery Open ---
      if(isRecBuyOpenCurrent && isRecSellOpenCurrent) {
         TrailSLRecoveryTrade_Pair(activeRecoveryPairs[i]); // Pass pair info
      }
      // --- Case R2: Only BUY Recovery Survivor ---
      else if(isRecBuyOpenCurrent && !isRecSellOpenCurrent) { // Use updated status check
         ModifySLToEntry_RecoveryPair(activeRecoveryPairs[i].buyTicket, activeRecoveryPairs[i]); // Pass pair info
      }
      // --- Case R3: Only SELL Recovery Survivor ---
      else if(!isRecBuyOpenCurrent && isRecSellOpenCurrent) { // Use updated status check
         ModifySLToEntry_RecoveryPair(activeRecoveryPairs[i].sellTicket, activeRecoveryPairs[i]); // Pass pair info
      }
      // --- Case R4: BOTH Recovery Closed ---
      else if(!isRecBuyOpenCurrent && !isRecSellOpenCurrent) { // Use updated status check
         if(InpEnableDebug)
            PrintFormat("Manage: Recovery Pair %s BOTH sides closed. Removing.", activeRecoveryPairs[i].guid);
         RemoveActiveRecoveryPair(i); // Remove from recovery tracking
      }
   } // End Recovery Pair Loop
// --- 2. MAIN Position Management (Using activeMainPairs array) ---
   int activeMainCount = ArraySize(activeMainPairs);
   for(int i = activeMainCount - 1; i >= 0; i--) { // Iterate backwards
      // Check current status ONCE at the start
      bool isOpenBCurrent = (activeMainPairs[i].buyTicket != 0 && PositionSelectByTicket(activeMainPairs[i].buyTicket));
      bool isOpenSCurrent = (activeMainPairs[i].sellTicket != 0 && PositionSelectByTicket(activeMainPairs[i].sellTicket));
      // Correct state if closed unexpectedly
      if(activeMainPairs[i].buyTicket != 0 && !isOpenBCurrent) {
         activeMainPairs[i].buyTicket = 0;
         activeMainPairs[i].buySLAtBE = false;
      }
      if(activeMainPairs[i].sellTicket != 0 && !isOpenSCurrent) {
         activeMainPairs[i].sellTicket = 0;
         activeMainPairs[i].sellSLAtBE = false;
      }
      // Re-fetch potentially corrected status
      isOpenBCurrent = (activeMainPairs[i].buyTicket != 0);
      isOpenSCurrent = (activeMainPairs[i].sellTicket != 0);
      // --- Case M1: Buy Survivor ---
      if(isOpenBCurrent && !isOpenSCurrent) {  // Use updated check
         ModifySLToEntry(InpMagicMain, activeMainPairs[i].buyTicket, activeMainPairs[i]);
         if(activeMainPairs[i].buySLAtBE) {
            TrailSLMainTrade(activeMainPairs[i].buyTicket, activeMainPairs[i]);
         }
         // Recovery Trigger Logic Removed - Handled in HandlePositionClose
      }
      // --- Case M2: Sell Survivor ---
      else if(!isOpenBCurrent && isOpenSCurrent) { // Use updated check
         ModifySLToEntry(InpMagicMain, activeMainPairs[i].sellTicket, activeMainPairs[i]);
         if(activeMainPairs[i].sellSLAtBE) {
            TrailSLMainTrade(activeMainPairs[i].sellTicket, activeMainPairs[i]);
         }
         // Recovery Trigger Logic Removed - Handled in HandlePositionClose
      }
      // --- Case M3: Both Open ---
      // No action needed here unless adding pre-BE trailing logic
      // --- Case M4: Both Closed ---
      else if(!isOpenBCurrent && !isOpenSCurrent) { // Use updated check
         if(InpEnableDebug)
            PrintFormat("Manage: Main Pair %s BOTH sides closed. Removing.", activeMainPairs[i].guid);
         RemoveActivePair(i); // Remove from main tracking
      }
   } // End Main Pair Loop
} // End ManagePositions




//+------------------------------------------------------------------+
//| Helper: Check if Recovery is Blocked for a Pair GUID             |
//+------------------------------------------------------------------+
bool IsRecoveryBlockedForPair(string pair_guid)
{
   for(int i=0; i<ArraySize(trackedPositions); i++) {
      if(trackedPositions[i].guid == pair_guid && trackedPositions[i].blockRecovery)
         return true;
   }
   return false;
}


//+------------------------------------------------------------------+
//| ModifySLToEntry (Main Pairs - Accepts Pair Reference)            |
//+------------------------------------------------------------------+
void ModifySLToEntry(int magic, ulong survivorTicket, HedgePairInfo &pair)

/*
if(magic != InpMagicMain || survivorTicket == 0)      return;
if(!PositionSelectByTicket(survivorTicket)||PositionGetInteger(POSITION_MAGIC)!=magic)      return;
double entry=PositionGetDouble(POSITION_PRICE_OPEN), currSL=PositionGetDouble(POSITION_SL), currTP=PositionGetDouble(POSITION_TP), pt=_Point;
ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
bool needsUpdate = false, flagStateChanged=false;
bool isAlreadyBE = (posType==POSITION_TYPE_BUY) ? pair.buySLAtBE : pair.sellSLAtBE;

if(InpEnableDebug)   PrintFormat("ModSL->BE(Main): Check Pos %I64u (Pair %s). Entry:%.5f, CurrSL:%.5f, IsBEFlag:%s", survivorTicket, pair.guid, entry, currSL, isAlreadyBE?"Y":"N");

if(MathAbs(currSL-entry) > pt*1.5)
  {
   needsUpdate = true;
   if(InpEnableDebug) PrintFormat("...Needs Update: SL %.5f != Entry %.5f", currSL, entry);
  }
else
  {
   if(InpEnableDebug && !isAlreadyBE) PrintFormat("...Already at BE (SL %.5f == Entry %.5f), but flag was false.", currSL, entry);
  }

if(needsUpdate && !isAlreadyBE)
   {
    if(InpEnableDebug) PrintFormat("...Attempting PositionModify to BE (%.5f)...", entry);
    trade.SetExpertMagicNumber(magic);
    if(trade.PositionModify(survivorTicket,entry,currTP))
      {
       if(posType==POSITION_TYPE_BUY) pair.buySLAtBE=true;
       else pair.sellSLAtBE=true;
       if(InpEnableDebug) PrintFormat("...OK. Set BE Flag for %s to TRUE.", EnumToString(posType));
       flagStateChanged=true;
      }
    else
      {
       PrintFormat("ModSL->BE(Main) ERROR: Pos %I64u! Err:%d %s", survivorTicket, trade.ResultRetcode(), trade.ResultComment());
      }
   }
else if(!needsUpdate && !isAlreadyBE) // SL was already at BE, just update flag
  {
   if(posType==POSITION_TYPE_BUY) pair.buySLAtBE=true;
   else pair.sellSLAtBE=true;
   if(InpEnableDebug) PrintFormat("...SL already at BE. Set BE Flag for %s to TRUE.", EnumToString(posType));
   flagStateChanged=true;
  }
// else: needsUpdate=false and isAlreadyBE=true -> Do nothing, flag is correct.
// else: needsUpdate=true and isAlreadyBE=true -> Should not happen if logic is sound, means flag was true but SL moved?
*/

{
   if(magic != InpMagicMain)
      return; // This overload is ONLY for main trades with pair context
   if(!PositionSelectByTicket(survivorTicket)) {
      /* Log Error */ return;
   }
   if(PositionGetInteger(POSITION_MAGIC) != magic) {
      /* Log Error */ return;   // Magic mismatch
   }
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   ENUM_POSITION_TYPE survivorType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double point = _Point;
// Check if BE already set *for this specific position in this pair*
   bool isAlreadyBE = (survivorType == POSITION_TYPE_BUY) ? pair.buySLAtBE : pair.sellSLAtBE;
   if(isAlreadyBE)
      return; // Already marked as BE for this pair
// Check if SL needs modification (is not already at entry)
   if(MathAbs(currentSL - entry) > point * 1.5) {  // Use tolerance
      if(InpEnableDebug)
         PrintFormat("ModifySLToEntry: Pair %s, Pos %I64u (%s), Moving SL from %.5f to Entry %.5f",
                     pair.guid, survivorTicket, EnumToString(survivorType), currentSL, entry);
      trade.SetExpertMagicNumber(magic); // Use correct magic for modification
      if(!trade.PositionModify(survivorTicket, entry, currentTP)) {
         PrintFormat("ModifySLToEntry ERROR: Pair %s, Pos %I64u Modify Failed! Err:%d %s",
                     pair.guid, survivorTicket, trade.ResultRetcode(), trade.ResultComment());
      }
      else {   // Modification Successful
         if(InpEnableDebug)
            PrintFormat("ModifySLToEntry OK: Pair %s, Pos %I64u SL set to entry.", pair.guid, survivorTicket);
         // Update the BE flag *in the pair structure*
         if(survivorType == POSITION_TYPE_BUY)
            pair.buySLAtBE = true;
         else
            pair.sellSLAtBE = true;
         // if(InpEnableDebug) PrintFormat("Pair %s: Updated %s SLAtBE flag to TRUE.", pair.guid, (survivorType == POSITION_TYPE_BUY ? "Buy" : "Sell"));
      }
   }
   else {
      // SL already at entry, ensure flag is set in pair struct
      bool flagUpdated = false;
      if(survivorType == POSITION_TYPE_BUY && !pair.buySLAtBE) {
         pair.buySLAtBE = true;
         flagUpdated = true;
      }
      else if(survivorType == POSITION_TYPE_SELL && !pair.sellSLAtBE) {
         pair.sellSLAtBE = true;
         flagUpdated = true;
      }
      // if (flagUpdated && InpEnableDebug) { PrintFormat("ModifySLToEntry: Pair %s Pos %I64u SL already near entry. Set %s SLAtBE flag.", pair.guid, survivorTicket, (survivorType==POSITION_TYPE_BUY?"Buy":"Sell")); }
   }
}

//+------------------------------------------------------------------+
//| ModifySLToEntry_RecoveryPair (NEW for Recovery Pairs)            |
//+------------------------------------------------------------------+
void ModifySLToEntry_RecoveryPair(ulong survivorTicket, RecoveryPairInfo &pair)   // Takes RecoveryPairInfo
{
   if(survivorTicket == 0 || !PositionSelectByTicket(survivorTicket))
      return;
   if(PositionGetInteger(POSITION_MAGIC) != InpMagicRecovery)
      return; // Only recovery magic
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   double point = _Point;
// Modify if SL is not already at entry (simple BE move for recovery)
   if(MathAbs(currentSL - entry) > point * 1.5) {
      if(InpEnableDebug)
         PrintFormat("ModSL->BE(RecPair): Pair %s, Pos %I64u -> %.5f", pair.guid, survivorTicket, entry);
      trade.SetExpertMagicNumber(InpMagicRecovery);
      if(!trade.PositionModify(survivorTicket, entry, currentTP)) {
         PrintFormat("ModSL->BE(RecPair) ERROR: Pair %s, Pos %I64u! Err:%d %s", pair.guid, survivorTicket, trade.ResultRetcode(), trade.ResultComment());
      }
      else {
         if(InpEnableDebug)
            PrintFormat("... OK.");
      }
   }
}

//+------------------------------------------------------------------+
//| TrailSLMainTrade (Accepts Pair Reference)                       |
//+------------------------------------------------------------------+
void TrailSLMainTrade(ulong survivorTicket, HedgePairInfo &pair)
{
// Implementation complete as provided before, uses '&pair' for context and tracks position
   if(survivorTicket==0 || !PositionSelectByTicket(survivorTicket) || PositionGetInteger(POSITION_MAGIC)!=InpMagicMain)
      return;
   ENUM_POSITION_TYPE posType=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   bool isAtBE=(posType==POSITION_TYPE_BUY)?pair.buySLAtBE:pair.sellSLAtBE;
   if(!isAtBE)
      return;
   double e=PositionGetDouble(POSITION_PRICE_OPEN), sl=PositionGetDouble(POSITION_SL), tp=PositionGetDouble(POSITION_TP), pt=_Point;
   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t))
      return;
   double profPts=0;
   if(posType==POSITION_TYPE_BUY)
      profPts=(t.bid-e)/pt;
   else
      profPts=(e-t.ask)/pt;
   if(profPts>=InpTrail2TriggerMain) {
      double newSL=0;
      int d=_Digits;
      if(posType==POSITION_TYPE_BUY) {
         newSL=NormalizeDouble(e+InpTrail2OffsetMain*pt,d);
         newSL=MathMin(newSL,NormalizeDouble(t.bid-pt*5,d));
      }
      else {
         newSL=NormalizeDouble(e-InpTrail2OffsetMain*pt,d);
         newSL=MathMax(newSL,NormalizeDouble(t.ask+pt*5,d));
      }
      bool mod=false;
      if(posType==POSITION_TYPE_BUY&&newSL>sl+pt*0.5)
         mod=true;
      if(posType==POSITION_TYPE_SELL&&newSL<sl-pt*0.5)
         mod=true;
      if(mod) {
         /* Log Trail Start */trade.SetExpertMagicNumber(InpMagicMain);
         if(trade.PositionModify(survivorTicket,newSL,tp)) {
            /* Log OK */bool trkd=false;
            for(int j=0;j<ArraySize(trackedPositions);j++) {
               if(trackedPositions[j].ticket==survivorTicket) {
                  trackedPositions[j].trailedSL=newSL;
                  trkd=true;
                  break;
               }
            }
            if(!trkd) {
               int sz=ArraySize(trackedPositions);
               if(ArrayResize(trackedPositions,sz+1)==sz+1) {
                  trackedPositions[sz].ticket=survivorTicket;
                  trackedPositions[sz].guid=pair.guid;
                  trackedPositions[sz].trailedSL=newSL;
                  trackedPositions[sz].entryPrice=e;
                  trackedPositions[sz].posType=posType;
                  trackedPositions[sz].blockRecovery=false;/* Log Added */
               }
               else {/* Log Resize Err*/}
            }
         }
         else {/*Log Mod Err*/}
      }
   }
}

//+------------------------------------------------------------------+
//| TrailSLRecoveryTrade_Pair (NEW for Recovery Pairs)              |
//+------------------------------------------------------------------+
void TrailSLRecoveryTrade_Pair(RecoveryPairInfo &pair)   // Accepts specific recovery pair info
{
// Check and Trail BUY side of this recovery pair (if open)
   if(pair.buyTicket != 0 && PositionSelectByTicket(pair.buyTicket)) {
      double entry=PositionGetDouble(POSITION_PRICE_OPEN), sl=PositionGetDouble(POSITION_SL), pt=_Point;
      if(MathAbs(entry-sl)>pt*1.5) { // Check if already at BE
         MqlTick t;
         if(SymbolInfoTick(_Symbol,t)) {
            double profitPts = (t.bid-entry)/pt;
            if(profitPts >= InpRecoveryProfitForBEPoints) {
               if(InpEnableDebug)
                  PrintFormat("TrailRecBE: Pair %s BUY Pos %I64u Trig (%.0fp). Set SL->Entry %.5f", pair.guid, pair.buyTicket, profitPts, entry);
               trade.SetExpertMagicNumber(InpMagicRecovery);
               if(!trade.PositionModify(pair.buyTicket, entry, PositionGetDouble(POSITION_TP))) {/*Log Err*/}
            }
         }
      }
   }
// Check and Trail SELL side of this recovery pair (if open)
   if(pair.sellTicket != 0 && PositionSelectByTicket(pair.sellTicket)) {
      double entry=PositionGetDouble(POSITION_PRICE_OPEN), sl=PositionGetDouble(POSITION_SL), pt=_Point;
      if(MathAbs(entry-sl)>pt*1.5) { // Check if already at BE
         MqlTick t;
         if(SymbolInfoTick(_Symbol,t)) {
            double profitPts = (entry-t.ask)/pt;
            if(profitPts >= InpRecoveryProfitForBEPoints) {
               if(InpEnableDebug)
                  PrintFormat("TrailRecBE: Pair %s SELL Pos %I64u Trig (%.0fp). Set SL->Entry %.5f", pair.guid, pair.sellTicket, profitPts, entry);
               trade.SetExpertMagicNumber(InpMagicRecovery);
               if(!trade.PositionModify(pair.sellTicket, entry, PositionGetDouble(POSITION_TP))) {/*Log Err*/}
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Delete Old Lines                                                 |
//+------------------------------------------------------------------+
void DeleteOldLinesIfNoPositions(datetime ct)
{
   if(CountOpenPositions()==0) {
      datetime td=ct-(ct%86400);
      for(int i=ObjectsTotal(0)-1;i>=0;i--) {
         string n=ObjectName(0,i);
         if(StringFind(n,tradingDayLineName)==0) {
            if((datetime)ObjectGetInteger(0,n,OBJPROP_TIME,0)<td)ObjectDelete(0,n);
         }
      }
   }
}
//+------------------------------------------------------------------+
//| Print Trade Status                                               |
//+------------------------------------------------------------------+
void PrintTradeStatus(string ctx="")
{
   if(!InpEnableDebug)return;
   string s=StringFormat("\n=== MAVERICK Status (%s) ===",ctx==""?TimeToString(TimeCurrent(),TIME_SECONDS):ctx);
   s+=StringFormat("\nDate:%s | RecPairs:%d",TimeToString(currentTradeDate,TIME_DATE),ArraySize(activeRecoveryPairs));
   s+=StringFormat("\nProfit(Run):%.2f|OpenPos:T=%d(M=%d R=%d)",totalRealizedProfit,CountOpenPositions(),CountOpenPositionsMagic(InpMagicMain),CountOpenPositionsMagic(InpMagicRecovery));
   int amc=ArraySize(activeMainPairs);
   s+=StringFormat("\nActive MAIN Pairs (%d):",amc);
   if(amc>0) {
      for(int i=0;i<amc;i++)s+=StringFormat("\n[%d]%s B:%I64u%s S:%I64u%s",i,activeMainPairs[i].guid,activeMainPairs[i].buyTicket,activeMainPairs[i].buySLAtBE?" BE":"",activeMainPairs[i].sellTicket,activeMainPairs[i].sellSLAtBE?" BE":"");
   }
   else s+=" None";
   int arc=ArraySize(activeRecoveryPairs);
   s+=StringFormat("\nActive REC Pairs (%d):",arc);
   if(arc>0) {
      for(int i=0;i<arc;i++)s+=StringFormat("\n[%d]%s B:%I64u S:%I64u",i,activeRecoveryPairs[i].guid,activeRecoveryPairs[i].buyTicket,activeRecoveryPairs[i].sellTicket);
   }
   else s+=" None";
   if(lastClosedPair.guid!="") {
      s+=StringFormat("\nLastClosed (%s) P:%.2f Eval:%s",lastClosedPair.guid,lastClosedPair.totalProfit,lastClosedPair.evaluated?"Y":"N");
   }
   else s+="\nLastClosed: N/A";
   s+="\n=============================";
   Print(s);
}
//+------------------------------------------------------------------+
//| Create Trading Day Line                                          |
//+------------------------------------------------------------------+
void CreateTradingDayLine(datetime lt)
{
   MqlDateTime d;
   TimeToStruct(lt,d);
   string sfx=StringFormat("%04d%02d%02d_%02d%02d",d.year,d.mon,d.day,d.hour,d.min);
   string n=tradingDayLineName+"_"+sfx;
   if(ObjectFind(0,n)!=-1)return;
   if(ObjectCreate(0,n,OBJ_VLINE,0,lt,0)) {
      ObjectSetInteger(0,n,OBJPROP_COLOR,clrGreen);
      ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,n,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,n,OBJPROP_BACK,true);
      ObjectSetString(0,n,OBJPROP_TOOLTIP,"\n");
   }
   else {}
}
//+------------------------------------------------------------------+
//| Update Dashboard                                                 |
//+------------------------------------------------------------------+
void UpdateRunningTotal()   /* Implementation unchanged */
{
   if(!ShowDashboard) {
      ObjectDelete(0,DASHBOARD_BG_NAME);
      Comment("");
      return;
   }
   double uP=0;
   int mC=0,rC=0;
   for(int i=0;i<PositionsTotal();i++) {
      ulong t=PositionGetTicket(i);
      if(PositionSelectByTicket(t)&&PositionGetString(POSITION_SYMBOL)==_Symbol) {
         long m=PositionGetInteger(POSITION_MAGIC);
         if(m==InpMagicMain||m==InpMagicRecovery) {
            uP+=PositionGetDouble(POSITION_PROFIT);
            if(m==InpMagicMain)
               mC++;
            else
               rC++;
         }
      }
   }
   double rT=totalRealizedProfit+uP;
   string c=AccountInfoString(ACCOUNT_CURRENCY),nl="\r\n",id=" ";
   string dsb=StringFormat("%s= MAVERICK v%.2f =%s%s%s T:%s%s",id,_Digits==3?1.73:1.75,nl,id,_Symbol,TimeToString(TimeCurrent(),TIME_SECONDS),nl);
   string st=(ArraySize(activeRecoveryPairs)>0)?"[RECOVERY]":(mC>0||rC>0)?"TradeActive":"Idle/"+InpTradeTime;
   dsb+=StringFormat("%sSt: %s%s",id,st,nl);
   dsb+=StringFormat("%s--------------------%s",id,nl);
   dsb+=StringFormat("%sRLzd: %+.2f %s%s",id,totalRealizedProfit,c,nl);
   dsb+=StringFormat("%sUnRL: %+.2f %s%s",id,uP,c,nl);
   dsb+=StringFormat("%sTotal:%+.2f %s%s",id,rT,c,nl);
   dsb+=StringFormat("%s--------------------%s",id,nl);
   dsb+=StringFormat("%sPos: M=%d R=%d%s",id,mC,rC,nl);
   dsb+=StringFormat("%s--Last 5 Closed--%s",id,nl);
   bool fT=false;
   for(int i=4;i>=0;i--) {
      if(lastFiveTrades[i].time>0) {
         string ps=StringFormat("%.2f",lastFiveTrades[i].profit);
         dsb+=StringFormat("%s %s %s(%s)%s",id,lastFiveTrades[i].profit>=0?"+":"-",ps,lastFiveTrades[i].comment,nl);
         fT=true;
      }
   }
   if(!fT)
      dsb+=StringFormat("%s(None)%s",id,nl);
   dsb+=StringFormat("%s=============================%s",id,nl);
   Comment(dsb);
}
//+------------------------------------------------------------------+
//| Check Tracked Positions (Debug)                                  |
//+------------------------------------------------------------------+
void CheckTrackedPositionsCrossed()
{
   if(!InpEnableDebug)return;
   for(int i=0;i<ArraySize(trackedPositions);i++) {
      if(trackedPositions[i].blockRecovery)continue;
      if(!PositionSelectByTicket(trackedPositions[i].ticket)) {/*Closed Log*/}
   }
}
//+------------------------------------------------------------------+
//| Get Last Deal Profit                                             |
//+------------------------------------------------------------------+
double GetLastDealProfit(int m)
{
   double p=0.0;
   if(HistorySelect(currentTradeDate,TimeCurrent())) {
      int t=HistoryDealsTotal();
      for(int i=t-1;i>=0;i--) {
         ulong d=HistoryDealGetTicket(i);
         if(HistoryDealSelect(d)&&HistoryDealGetInteger(d,DEAL_MAGIC)==m) {
            if(HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_OUT)p=HistoryDealGetDouble(d,DEAL_PROFIT);
            break;
         }
      }
   }
   return p;
}

//+------------------------------------------------------------------+
