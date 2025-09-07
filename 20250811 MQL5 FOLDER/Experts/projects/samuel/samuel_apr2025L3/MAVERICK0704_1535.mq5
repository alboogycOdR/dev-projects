//+------------------------------------------------------------------+
//|                                                      Maverick EA |
//|                                      Copyright 2025, kingdom_f   |
//|                                       https://t.me/AlisterFx/    |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, kingdom financier"
#property link      "https://t.me/AlisterFx/"
#property version   "1.5" // Multi-pair handling
#property description "\n\nMaverick EA"
#property description "\n____________"
#property description "\nHedging System"
#property description "\nMain and Recovery Trades - Multiple Pair Handling"
//+------------------------------------------------------------------+
//| Expert Advisor: MAVERICK                                         |
//| Description: MT5 Hedge EA with main and recovery trades          |
//| Version: 1.5 (Refactored for multiple concurrent main pairs)     |
//| Author: Alister / AI Fix                                         |
//+------------------------------------------------------------------+
/*
 Multi-pair handling Refactor Notes (v1.5):
 - Uses HedgePairInfo struct and activeMainPairs array to track main trades.
 - Global BE flags removed; state managed per-pair.
 - ManagePositions iterates active pairs.
 - Management funcs (ModifySLToEntry, TrailSLMainTrade) accept pair context.
 - Recovery Trigger logic updated for multi-pair scenario.
 - Handles positions existing on startup via InitializeExistingPairs.
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
input double   BreakevenThreshold = -5.0;    // Max loss for pair to be considered breakeven (no recovery)

input group "Other Settings"
input bool     InpEnableDebug        = true;     // Enable detailed debug output
input int      UpdateFrequency = 1000;       // Dashboard update frequency in milliseconds (1 sec = 1000)
input bool     InpIsLogging=true;          // Verbose logging for OnTradeTransaction raw events
input bool     ShowDashboard = true;       // Show dashboard on chart
enum ENUM_DASHBOARD_POSITION
{
   DASHBOARD_TOP_LEFT,      // Top Left
   DASHBOARD_TOP_RIGHT,     // Top Right  
   DASHBOARD_BOTTOM_LEFT,   // Bottom Left
   DASHBOARD_BOTTOM_RIGHT   // Bottom Right
};
 ENUM_DASHBOARD_POSITION DashboardPosition = DASHBOARD_TOP_LEFT; // Dashboard Position

//--------------------------------------------------//
//           STRUCTURES & GLOBAL VARIABLES
//--------------------------------------------------//

// Structure to hold information about an active main hedge pair
struct HedgePairInfo {
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
bool recoveryTradeActive = false; // Is a recovery sequence currently in progress?
datetime mainTradeOpenTime = 0;   // Time when the *very latest* main trade pair was opened
double adjustedLotSize = 0;       // Adjusted lot size for Main
double adjustedLotSizeRecovery = 0; // Adjusted lot size for Recovery

// -- Daily Tracking Variables --
datetime currentTradeDate = 0;      // Current trading day date (start of day)
bool recoveryUsedToday = false;     // Flag to track if recovery trade sequence started today
bool dailyTradingEnded = false;     // Flag to indicate if trading ended for the day
double dailyCumulativeProfit = 0.0; // Track daily P/L (Informative)
bool skipRecovery = false;          // Flag to explicitly skip recovery for the current event

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

// Structure to track results of a *recently closed* pair (primarily for OnStopLossHit evaluation)
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
   bool              evaluated;     // Flag: Pair outcome evaluated for recovery decision
  };
TradeResultPair lastClosedPair; // Stores info of the pair whose parts are currently closing

// Structure for Tracking Positions *AFTER* SL Moved Beyond BE (for recovery blocking logic)
struct TrackedPosition {
    ulong             ticket;           // Position ticket
    string            guid;             // Position GUID (of the pair)
    double            trailedSL;        // The SL value *after* it was moved beyond entry
    double            entryPrice;       // Entry price of this position
    ENUM_POSITION_TYPE posType;         // Buy or Sell
    bool              blockRecovery;    // Flag to block recovery for this hedge set (GUID) - Set when SL hit *after* trail
};
TrackedPosition trackedPositions[];  // Array to store positions reaching the second trail stage

// Define object names for the dashboard
#define DASHBOARD_BG_NAME   infoLabelPrefix + "Dashboard_BG"
#define DASHBOARD_TEXT_NAME infoLabelPrefix + "Dashboard_Text"

//+------------------------------------------------------------------+
//| Function to check if a trade pair closed at effective breakeven   |
//+------------------------------------------------------------------+
bool IsPairAtEffectiveBreakeven(double totalProfit)
  {
   // Consider breakeven if total profit is not significantly negative
   return totalProfit >= BreakevenThreshold;
  }

//--- Transaction Type Defines ---
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

// Forward declaration for callback
void OnStopLossHit(int magicNumber, ulong positionTicket, ulong dealTicket, string guid);

// Define a function pointer type for our callback
typedef void (*OnStopLossHitCallback)(int magicNumber, ulong positionTicket, ulong dealTicket, string guid);


//+------------------------------------------------------------------+
//| Class CTradeTransaction: Base for handling trade events.         |
//+------------------------------------------------------------------+
class CTradeTransaction
  {
public:
                     CTradeTransaction(void)  {   }
                    ~CTradeTransaction(void)  {   }
   //--- Main event handler, routes to specific virtual methods ---
   void              OnTradeTransaction(const MqlTradeTransaction &trans,
                                        const MqlTradeRequest &request,
                                        const MqlTradeResult &result);
protected:
   //--- Methods overridden in CExtTransaction ---
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

    //--- Helper Function (Protected): Get original comment from opening order ---
    string GetOriginalCommentForDeal(ulong deal_ticket) {
        ulong order_ticket = HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
        if(!HistoryOrderSelect(order_ticket)) return ""; // Need order to find position

        ulong position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
        if(position_id > 0) {
             if (HistorySelectByPosition(position_id)) {
                 int deals_total = HistoryDealsTotal();
                 for (int i = 0; i < deals_total; i++) {
                      ulong pos_deal_ticket = HistoryDealGetTicket(i);
                      if(HistoryDealGetInteger(pos_deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_IN) {
                          ulong opening_order_ticket = HistoryDealGetInteger(pos_deal_ticket, DEAL_ORDER);
                          if(HistoryOrderSelect(opening_order_ticket)) {
                              return HistoryOrderGetString(opening_order_ticket, ORDER_COMMENT);
                           }
                           break;
                       }
                 } // End for deals in position
            } // End HistorySelectByPosition
         } // End position_id > 0

        // Fallback if PositionID method failed (should be rare)
         string fallback_comment = HistoryOrderGetString(order_ticket, ORDER_COMMENT);
         // if (InpEnableDebug && fallback_comment=="") PrintFormat("GetOriginalComment: Warning - Could not find comment for deal %I64u", deal_ticket);
         return fallback_comment;
    }


    // --- Helper Function (Protected): Extract GUID from B/S/RB/RS comment prefix ---
    string ExtractGuidFromComment(string comment) {
        if (comment == NULL || StringLen(comment) <= 1) return "";
        if(StringSubstr(comment, 0, 1) == "B" || StringSubstr(comment, 0, 1) == "S") return StringSubstr(comment, 1);
        if(StringLen(comment) > 2 && (StringSubstr(comment, 0, 2) == "RB" || StringSubstr(comment, 0, 2) == "RS")) return StringSubstr(comment, 2);
        return "";
    }

     // --- Helper Function (Protected): Update Last 5 Trades display array ---
     void UpdateLastTrades(double profit, datetime time, string comment) {
         // Shift existing trades down
         for(int i = 0; i < 4; i++) {
             lastFiveTrades[i] = lastFiveTrades[i+1];
         }
         // Add the new trade
         lastFiveTrades[4].profit = profit;
         lastFiveTrades[4].time = time;
         lastFiveTrades[4].comment = comment; // Store comment
     }

     // --- Helper Function (Protected): Update recently closed pair info (for callback) ---
      void UpdateLastClosedPairInfo(const string guid, const string comment, double profit, bool sl_hit) {
        if(guid == "") return; // Should not happen if called correctly

        // Check if this is a new GUID or continuation of the current one
        if (lastClosedPair.guid != guid) {
             // New pair closing, reset structure
             lastClosedPair.guid = guid;
             lastClosedPair.buyProfit = 0.0; lastClosedPair.sellProfit = 0.0;
             lastClosedPair.buyHitSL = false; lastClosedPair.sellHitSL = false;
             lastClosedPair.totalProfit = 0.0;
             lastClosedPair.buyClosed = false; lastClosedPair.sellClosed = false;
             lastClosedPair.evaluated = false; // Reset evaluation flag
             if(InpEnableDebug) PrintFormat("Pair %s: Tracking closure start...", guid);
        }

        // Update based on Buy or Sell comment prefix
        if(StringSubstr(comment, 0, 1) == "B") {
             if (!lastClosedPair.buyClosed) { // Only update if not already marked closed
                  lastClosedPair.buyProfit = profit;
                  lastClosedPair.buyHitSL = sl_hit;
                  lastClosedPair.buyClosed = true;
                  if(InpEnableDebug) PrintFormat("Pair %s: BUY closed. P: %.2f, SL:%s", guid, profit, sl_hit ? "Y" : "N");
             }
         } else if(StringSubstr(comment, 0, 1) == "S") {
             if (!lastClosedPair.sellClosed) { // Only update if not already marked closed
                  lastClosedPair.sellProfit = profit;
                  lastClosedPair.sellHitSL = sl_hit;
                  lastClosedPair.sellClosed = true;
                  if(InpEnableDebug) PrintFormat("Pair %s: SELL closed. P: %.2f, SL:%s", guid, profit, sl_hit ? "Y" : "N");
             }
         }

         // If both sides are now closed, calculate total profit
         if(lastClosedPair.buyClosed && lastClosedPair.sellClosed) {
             lastClosedPair.totalProfit = lastClosedPair.buyProfit + lastClosedPair.sellProfit;
             if(InpEnableDebug) PrintFormat("Pair %s: BOTH sides now closed. Total P: %.2f", guid, lastClosedPair.totalProfit);
         }
      } // End UpdateLastClosedPairInfo

  }; // End CTradeTransaction Class

//+------------------------------------------------------------------+
//| CTradeTransaction: OnTradeTransaction Implementation             |
//+------------------------------------------------------------------+
void CTradeTransaction::OnTradeTransaction(const MqlTradeTransaction &trans,
                                           const MqlTradeRequest &request,
                                           const MqlTradeResult &result)
  {
    // Raw Logging (Optional)
    if(InpEnableDebug && InpIsLogging) {
        // Log details of trans, request, result objects here if needed for deep debugging
        // Print("--- Trans ---"); Print(trans);
        // Print("--- Request ---"); Print(request);
        // Print("--- Result ---"); Print(result);
    }

     // Route based on transaction type using DEFINES
     if(IS_TRANSACTION_ORDER_PLACED)           TradeTransactionOrderPlaced(result.order);
    else if(IS_TRANSACTION_ORDER_MODIFIED)     TradeTransactionOrderModified(result.order);
    else if(IS_TRANSACTION_ORDER_DELETED)      TradeTransactionOrderDeleted(trans.order);
    else if(IS_TRANSACTION_ORDER_EXPIRED)      TradeTransactionOrderExpired(trans.order);
    else if(IS_TRANSACTION_ORDER_TRIGGERED)    TradeTransactionOrderTriggered(trans.order);
    else if(IS_TRANSACTION_POSITION_OPENED)    TradeTransactionPositionOpened(trans.position,trans.deal);
    else if(IS_TRANSACTION_POSITION_STOP_TAKE) TradeTransactionPositionStopTake(trans.position,trans.deal);
    else if(IS_TRANSACTION_POSITION_CLOSED)    TradeTransactionPositionClosed(trans.position,trans.deal);
    else if(IS_TRANSACTION_POSITION_CLOSEBY)   TradeTransactionPositionCloseBy(trans.position,trans.deal);
    else if(IS_TRANSACTION_POSITION_MODIFIED)  TradeTransactionPositionModified(request.position); // Fires on SL/TP modify request confirmation
    else {
        // Log unhandled transaction types if necessary
        // if(InpEnableDebug && InpIsLogging) Print("Unhandled Transaction Type: ", EnumToString(trans.type));
    }
  }

//+------------------------------------------------------------------+
//| CExtTransaction: Extended class with EA-specific logic.          |
//+------------------------------------------------------------------+
class CExtTransaction : public CTradeTransaction
  {
protected:
   OnStopLossHitCallback m_onStopLossHitCallback; // Pointer to the SL handler function

public:
   CExtTransaction() : m_onStopLossHitCallback(NULL) {} // Constructor
   void SetStopLossCallback(OnStopLossHitCallback callback) { m_onStopLossHitCallback = callback; } // Set callback

protected: // Override base class virtual methods

   // --- Simple Logging for Order Events ---
   virtual void TradeTransactionOrderPlaced(ulong order) override
     {
         long magic = OrderGetInteger(ORDER_MAGIC);
         if((magic == InpMagicMain || magic == InpMagicRecovery) && InpEnableDebug && InpIsLogging)
             PrintFormat("Log: Order Placed. Magic: %d (Order %I64u)", magic, order);
     }
   virtual void TradeTransactionOrderModified(ulong order) override
     {
         long magic = OrderGetInteger(ORDER_MAGIC);
         if((magic == InpMagicMain || magic == InpMagicRecovery) && InpEnableDebug && InpIsLogging)
            PrintFormat("Log: Order Modified. Magic: %d (Order %I64u)", magic, order);
     }
    virtual void TradeTransactionOrderDeleted(ulong order) override
     {
         if(InpEnableDebug && InpIsLogging) PrintFormat("Log: Order Deleted. (Order %I64u)", order);
     }
    virtual void TradeTransactionOrderExpired(ulong order) override
     {
         if(InpEnableDebug && InpIsLogging) PrintFormat("Log: Order Expired. (Order %I64u)", order);
     }
     virtual void TradeTransactionOrderTriggered(ulong order) override
     {
        if(OrderSelect(order)) {
             long magic = OrderGetInteger(ORDER_MAGIC);
             if((magic == InpMagicMain || magic == InpMagicRecovery) && InpEnableDebug && InpIsLogging)
                 PrintFormat("Log: Order Triggered. Type: %s, Magic: %d (Order %I64u)", EnumToString((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)), magic, order);
        }
     }

   // --- Position Modified (SL/TP Update Request Processed) ---
   virtual void TradeTransactionPositionModified(ulong position_ticket) override // Passed request.position
     {
         // Check if the position still exists (might have closed between request and execution)
         if(PositionSelectByTicket(position_ticket)) {
             long magic = PositionGetInteger(POSITION_MAGIC);
             if((magic == InpMagicMain || magic == InpMagicRecovery) && InpEnableDebug && InpIsLogging) {
                PrintFormat("Log: Pos SL/TP Modify OK for Magic: %d (Pos %I64u)", magic, position_ticket);
             }
         } else {
              // if(InpEnableDebug && InpIsLogging) PrintFormat("Log: Pos SL/TP Modify OK received for closed/unknown Pos %I64u", position_ticket);
         }
     }

   // --- Position Opened ---
   virtual void TradeTransactionPositionOpened(ulong position_id, ulong deal) override
     {
        long magic = HistoryDealGetInteger(deal, DEAL_MAGIC);
        if(magic == InpMagicMain || magic == InpMagicRecovery) {
             if(InpEnableDebug) PrintFormat("Position Opened: Magic %d (Pos %I64u, Deal %I64u)", magic, position_id, deal);
             // Actual addition to tracking is done in OpenMainTrade/OpenRecoveryTrade success confirmation
        }
     }

   // --- Position Closed by SL or TP ---
   virtual void TradeTransactionPositionStopTake(ulong position_id, ulong deal) override
     {
        HandlePositionClose(position_id, deal, true); // true = SL or TP closure
     }

   // --- Position Closed Manually / Other ---
    virtual void TradeTransactionPositionClosed(ulong position_id, ulong deal) override
    {
        HandlePositionClose(position_id, deal, false); // false = Other reason
    }

   // --- Position Closed By Opposite ---
   virtual void TradeTransactionPositionCloseBy(ulong position_id, ulong deal) override
     {
         HandlePositionClose(position_id, deal, false); // Treat as 'other' closure
     }


   // --- Centralized Handler for Position Closure Events ---
   void HandlePositionClose(ulong position_id, ulong deal, bool isStopTake) // Now using position_id from event
   {
        // Get details from the DEAL that closed the position
        ENUM_DEAL_REASON closeReason = (ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON);
        long magic = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);
        double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
        datetime closeTime = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
        ulong closingDealTicket = deal; // Keep track of the closing deal ticket

        string dealComment = ""; // Will store original comment (e.g., B-GUID)
        string guid = "";

        if (position_id == 0) {
             if(InpEnableDebug) PrintFormat("HandlePositionClose: Error - Position ID is 0 for closing deal %I64u", closingDealTicket);
             return; // Cannot proceed
        }

        // Get Original Comment and GUID from the Position's History
        dealComment = GetOriginalCommentForDeal(closingDealTicket); // Use helper method on closing deal
        guid = ExtractGuidFromComment(dealComment);            // Use helper method

        // if(InpEnableDebug) {
        //     string closeType = isStopTake ? "Stop/Take" : (closeReason==DEAL_REASON_CLOSE_BY ? "CloseBy" : "ClosedOther");
        //      PrintFormat("Pos Closed (%s). Magic: %d, Reason: %s, Profit: %.2f, PosID: %I64u, Deal: %I64u, Comment: '%s', GUID: '%s'",
        //                   closeType, magic, EnumToString(closeReason), profit, position_id, closingDealTicket, dealComment, guid);
        // }

        // -- Update Global Stats & History --
        if (magic == InpMagicMain || magic == InpMagicRecovery) {
            totalRealizedProfit += profit; // Update total running profit
            UpdateLastTrades(profit, closeTime, dealComment); // Update display array
        }

        // -- Update State for the SPECIFIC Pair (Main Trades Only) --
        if (magic == InpMagicMain && guid != "") {
            bool pairUpdated = false;
            for (int i = 0; i < ArraySize(activeMainPairs); i++) {
                 // Find the PAIR being tracked that contains this position ID
                 if (activeMainPairs[i].guid == guid) {
                    bool closedInPair = false;
                    // Check BUY side
                    if (activeMainPairs[i].buyTicket == position_id) {
                        activeMainPairs[i].buyTicket = 0;     // Mark Buy closed in tracked pair
                        activeMainPairs[i].buySLAtBE = false; // Reset flag
                        closedInPair = true;
                    // Check SELL side
                    } else if (activeMainPairs[i].sellTicket == position_id) {
                         activeMainPairs[i].sellTicket = 0;    // Mark Sell closed
                         activeMainPairs[i].sellSLAtBE = false; // Reset flag
                         closedInPair = true;
                    }
                    // If found/updated, manage temporary close info for callback & exit loop
                    if (closedInPair) {
                        if(InpEnableDebug) PrintFormat("Pair %s: Pos %I64u marked closed in active tracking.", guid, position_id);
                        UpdateLastClosedPairInfo(guid, dealComment, profit, closeReason == DEAL_REASON_SL);
                        pairUpdated = true;
                        break; // Exit loop for this pair
                    }
                 } // End if GUID matches
             } // End for loop through active pairs
              if (!pairUpdated && InpEnableDebug && guid!="") {
                   // This might happen if the pair was already removed, or if startup init failed etc.
                   PrintFormat("HandlePositionClose Warning: Closed Pos %I64u (GUID %s) not found in active tracking.", position_id, guid);
              }
         } // End if Main Magic and valid GUID


        // -- Check if SL hit a TRAILED position (for Recovery Blocking) --
        if (closeReason == DEAL_REASON_SL) {
            bool recoveryBlockedThisEvent = false;
            for (int i = 0; i < ArraySize(trackedPositions); i++) {
                // Check if the closed position ID matches a TRAILED ticket
                if (trackedPositions[i].ticket == position_id) {
                     if(InpEnableDebug) PrintFormat("SL Hit Check: Pos %I64u was in trackedPositions (GUID %s). Checking if trailed beyond BE.", position_id, trackedPositions[i].guid);
                     double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                     bool slWasTrulyTrailed = false; // Was SL > BE offset?

                      if (trackedPositions[i].posType == POSITION_TYPE_BUY && trackedPositions[i].trailedSL > trackedPositions[i].entryPrice + point) { slWasTrulyTrailed = true; }
                      else if (trackedPositions[i].posType == POSITION_TYPE_SELL && trackedPositions[i].trailedSL < trackedPositions[i].entryPrice - point) { slWasTrulyTrailed = true; }

                      if(slWasTrulyTrailed) {
                           // Mark the specific tracked position entry
                           trackedPositions[i].blockRecovery = true;
                           string pairGuid = trackedPositions[i].guid; // Get the GUID

                           // Ensure ALL entries for this pair GUID in trackedPositions get marked
                           for(int j=0; j<ArraySize(trackedPositions); j++) {
                               if(trackedPositions[j].guid == pairGuid) trackedPositions[j].blockRecovery = true;
                           }

                           if(InpEnableDebug) PrintFormat("!!! SL HIT AFTER TRAILING BEYOND BE !!! Pos %I64u (GUID %s), Entry:%.5f, TrailedSL:%.5f. Recovery BLOCKED for this Pair.",
                                                            position_id, pairGuid, trackedPositions[i].entryPrice, trackedPositions[i].trailedSL);
                           skipRecovery = true; // Set global flag *immediately*
                           recoveryBlockedThisEvent = true;
                       } else {
                            // SL Hit, but was at/near entry (BE) - DO NOT block recovery
                             if(InpEnableDebug) PrintFormat("SL Hit At Entry (BE): Pos %I64u (GUID %s), Entry:%.5f, SL:%.5f. Recovery NOT blocked by this.",
                                                             position_id, trackedPositions[i].guid, trackedPositions[i].entryPrice, trackedPositions[i].trailedSL);
                       }
                     break; // Found the matching tracked position
                 } // End if ticket matches
            } // End for loop trackedPositions
        } // End if SL hit


        // -- Trigger SL Callback (Only for MAIN SL hits, after checks) --
        if (magic == InpMagicMain && closeReason == DEAL_REASON_SL && m_onStopLossHitCallback != NULL && guid != "")
        {
             // Check skipRecovery flag *again* just before calling back
             if (!skipRecovery) {
                 if(InpEnableDebug) PrintFormat("HandleClose: Triggering OnStopLossHit Callback for Pair %s (Pos %I64u).", guid, position_id);
                 m_onStopLossHitCallback(magic, position_id, closingDealTicket, guid);
             } else {
                 if(InpEnableDebug) PrintFormat("HandleClose: Main SL Hit for Pair %s, but Callback skipped (skipRecovery=true due to prior trail block).", guid);
                 // Don't reset skipRecovery here, let callback/daily handle it
             }
        }
   } // End HandlePositionClose

  }; // End CExtTransaction Class

//+------------------------------------------------------------------+
//| Global transaction object                                        |
//+------------------------------------------------------------------+
CExtTransaction ExtTransaction; // Instantiate the handler class


//+------------------------------------------------------------------+
//| OnTradeTransaction (System Callback -> routes to handler)        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   ExtTransaction.OnTradeTransaction(trans,request,result); // Delegate to class handler
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| OnStopLossHit (Callback Implementation)                           |
//| Called by HandlePositionClose ONLY for Main Trade SL Hits.       |
//+------------------------------------------------------------------+
void OnStopLossHit(int magicNumber, ulong positionTicket, ulong dealTicket, string guid)
  {
   if (InpEnableDebug) PrintFormat("Callback: OnStopLossHit Triggered for GUID=%s (Pos %I64u)", guid, positionTicket);
   if (magicNumber != InpMagicMain || guid == "") return; // Validation

   Sleep(150); // Allow state to potentially settle

   // --- Evaluate based on lastClosedPair state ---
   // Ensure BOTH sides of the identified pair are closed and it hasn't been evaluated yet
   if(lastClosedPair.guid == guid && lastClosedPair.buyClosed && lastClosedPair.sellClosed && !lastClosedPair.evaluated)
   {
       lastClosedPair.evaluated = true; // Mark evaluated
       if(InpEnableDebug) PrintFormat("Pair %s Complete (via SL Hit). Profit=%.2f. Evaluating Recovery Necessity.", guid, lastClosedPair.totalProfit);

       bool doNotRecover = false; string reason = ""; // Build reason string

       // --- Check Blocking/Skipping Conditions ---
       // 1. Blocked by Trailed SL? (Most definitive check - examine trackedPositions for this GUID)
       bool pairBlockedByTrail = false;
       for(int i = 0; i < ArraySize(trackedPositions); i++) {
          if(trackedPositions[i].guid == guid && trackedPositions[i].blockRecovery) { // Check block flag
             pairBlockedByTrail = true; break;
          }
       }
       // Also check global skip flag which might have been set slightly earlier
       if (pairBlockedByTrail || skipRecovery) {
           doNotRecover = true; reason += "Blocked(TrailSL) ";
           if (InpEnableDebug) PrintFormat("Pair %s: Recovery Decision - BLOCKED due to prior trailed SL hit.", guid);
       }

       // 2. Breakeven/Profit? (Check only if not already blocked)
       if (!doNotRecover && IsPairAtEffectiveBreakeven(lastClosedPair.totalProfit)) {
           doNotRecover = true; reason += "Breakeven ";
           if (InpEnableDebug) PrintFormat("Pair %s: Recovery Decision - SKIPPED (Breakeven/Profit: %.2f >= %.2f)", guid, lastClosedPair.totalProfit, BreakevenThreshold);
       }

       // 3. User Disabled?
       if (!doNotRecover && !UseRecoveryTrade) { doNotRecover = true; reason += "Disabled "; }
       // 4. Already Used Today?
       if (!doNotRecover && recoveryUsedToday) { doNotRecover = true; reason += "UsedToday "; }
       // 5. Day Ended?
       if (!doNotRecover && dailyTradingEnded) { doNotRecover = true; reason += "DayEnded "; }
       // --- // End Blocking Checks

       // --- Decision ---
       if (!doNotRecover) {
           // ALL conditions PASSED - proceed with recovery
           if (InpEnableDebug) PrintFormat("Pair %s: Recovery Decision - APPROVED! Loss=%.2f. Calling OpenRecoveryTrade().", guid, lastClosedPair.totalProfit);
           if (!OpenRecoveryTrade()) {
                // Log failure to open recovery
                if(InpEnableDebug) PrintFormat("Pair %s: OpenRecoveryTrade() call FAILED. Recovery aborted for this cycle.", guid);
                // Consider if dailyTradingEnded should be set on failure? Optional.
                // dailyTradingEnded = true;
           }
           // OpenRecoveryTrade sets recoveryTradeActive and recoveryUsedToday flags on success
       } else {
            // Recovery denied for one or more reasons
            if(InpEnableDebug) PrintFormat("Pair %s: Recovery Decision - DENIED. Reasons: [%s]", guid, StringTrimRight(reason));
       }

       // Reset global skip flag AFTER evaluation for THIS SL event is complete.
       // This allows the next independent SL event (if any) to be evaluated correctly.
       skipRecovery = false;

   } else if (lastClosedPair.guid == guid && (!lastClosedPair.buyClosed || !lastClosedPair.sellClosed)) {
       if(InpEnableDebug) PrintFormat("OnStopLossHit: Pair %s - One side hit SL, other side closure/state update pending. Will re-evaluate if other side closes.", guid);
       // This state might resolve itself when the second position closes and HandlePositionClose runs again.
   } else if (lastClosedPair.guid != guid){
       if(InpEnableDebug) PrintFormat("OnStopLossHit Warning: Callback for GUID '%s', but lastClosedPair tracks '%s' or is empty. State issue?", guid, lastClosedPair.guid);
   } else if (lastClosedPair.evaluated) {
       if(InpEnableDebug) PrintFormat("OnStopLossHit Info: Pair %s already evaluated. Ignoring redundant SL event for callback.", guid);
   }
  } // End OnStopLossHit


//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Initialize arrays and global vars
   // Initialize the lastFiveTrades array
   for(int i = 0; i < ArraySize(lastFiveTrades); i++) {
       lastFiveTrades[i].profit = 0.0;
       lastFiveTrades[i].time = 0;
       lastFiveTrades[i].comment = "";
   }
   ArrayResize(activeMainPairs, 0);
   ArrayResize(trackedPositions, 0);
   totalRealizedProfit = 0.0;

   // --- History analysis ---
   if(!HistorySelect(0, TimeCurrent())) { Print("OnInit Error: Failed to select trade history."); }
   else {
        int totalDeals = HistoryDealsTotal();
        int tradeCount = 0; // Count relevant trades loaded into array
        double initialProfitSum = 0.0; // Recalculate here for accuracy

        for(int i = totalDeals - 1; i >= 0; i--) { // Iterate backwards for most recent first
            ulong dealTicket = HistoryDealGetTicket(i);
            if(HistoryDealSelect(dealTicket)) {
                long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
                long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
                if(entry == DEAL_ENTRY_OUT && (magic == InpMagicMain || magic == InpMagicRecovery)) {
                    // Sum profit for ALL relevant closed trades during EA's lifetime (approx)
                    initialProfitSum += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                    // Fill last five trades display array
                     if (tradeCount < 5) {
                         lastFiveTrades[tradeCount].profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                         lastFiveTrades[tradeCount].time = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                         // Assuming 'dealTicket' holds the correct ticket for the deal
                         if (HistoryDealSelect(dealTicket)) {
                              lastFiveTrades[tradeCount].comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
                         } else {
                              // Handle cases where the deal might not be selectable (optional)
                              lastFiveTrades[tradeCount].comment = ""; // Or some error indicator
                              PrintFormat("OnTradeTransaction Error: Could not select deal %I64u to get comment.", dealTicket);
                         }
                         tradeCount++;
                     }
                } // End if relevant deal
            } // End if deal select ok
        } // End for loop deals

        totalRealizedProfit = initialProfitSum; // Set global profit tracker

         // Reverse the array so oldest is at [0], newest at [4] for correct display update later
        if (tradeCount > 1) ArrayReverse(lastFiveTrades, 0, tradeCount);

         if(InpEnableDebug) PrintFormat("OnInit: History Scanned. Initial Realized Profit=%.2f. Last %d trades recorded.", totalRealizedProfit, tradeCount);
    }
   // --- // End History Analysis

   // --- Set CTrade Defaults ---
   trade.SetExpertMagicNumber(InpMagicMain); // Default, overridden as needed
   trade.SetMarginMode();                    // Use account's setting
   trade.LogLevel(LOG_LEVEL_ERRORS);         // Log only CTrade errors by default
   trade.SetTypeFillingBySymbol(_Symbol);    // Use symbol's allowed filling type
   // --- //

   // --- Parameter Validation ---
   if(InpLotSize <= 0 || InpSLPointsMain <= 0 || InpTPPointsMain <= 0 || InpMagicMain == 0 || InpMagicMain == InpMagicRecovery ||
      (UseRecoveryTrade && (InpLotSizeRecovery <= 0 || InpSLPointsRecovery <= 0 || InpTPPointsRecovery <= 0 || InpMagicRecovery == 0)) ) {
       Print("OnInit Error: Invalid input parameters. Check Lots>0, SL/TP>0, Magic Numbers!=0 & Unique.");
       return INIT_PARAMETERS_INCORRECT;
     }
   if (!ValidateAdjustLotSize(InpLotSize, adjustedLotSize, "Main")) return INIT_FAILED;
   if (UseRecoveryTrade && !ValidateAdjustLotSize(InpLotSizeRecovery, adjustedLotSizeRecovery, "Recovery")) return INIT_FAILED;
   // --- //

   // --- Account Check (Hedging) ---
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) { Print("OnInit Warning: Account does not support hedging. EA logic assumes hedging."); }
   // --- //

   // --- Initialize Time & State ---
   MqlDateTime time_struct; TimeCurrent(time_struct);
   currentTradeDate = StructToTime(time_struct) - (StructToTime(time_struct) % 86400);
   recoveryTradeActive = (CountOpenPositionsMagic(InpMagicRecovery) > 0);
   recoveryUsedToday = recoveryTradeActive;
   dailyTradingEnded = false;
   dailyCumulativeProfit = 0.0; // Informational only
   skipRecovery = false;        // Reset skip flag on init
   lastClosedPair.guid = "";     // Reset closed pair tracker
   lastClosedPair.evaluated = false;
   // --- //

   // --- Register Callback ---
   ExtTransaction.SetStopLossCallback(OnStopLossHit);
   // --- //

   // --- Setup Timer ---
   int timerSeconds = UpdateFrequency / 1000;
   if(timerSeconds < 1) timerSeconds = 1; // Ensure at least 1 second interval
   if (!EventSetTimer(timerSeconds)) {
       Print("OnInit Error: Failed to set timer (Interval: %d sec).", timerSeconds);
       return INIT_FAILED;
   }
   // --- //

   if(InpEnableDebug) PrintFormat("MAVERICK EA initialized (v%.2f - Multi-Pair). Symbol: %s. Date: %s", _Digits==3?1.53:1.55, _Symbol, TimeToString(currentTradeDate, TIME_DATE));


   // Initialize state for existing main pairs found on startup
   InitializeExistingPairs();

   CreateTradingDayLine(TimeCurrent()); // Draw initial line marker

   return INIT_SUCCEEDED;
  }


//+------------------------------------------------------------------+
//| Helper Function for Lot Size Validation                          |
//+------------------------------------------------------------------+
bool ValidateAdjustLotSize(const double inputLot, double &adjustedLot, string tradeType) {
    // Get symbol properties
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double limitVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT); // Max vol per position

     // Use position limit if it's relevant and lower than max broker volume
    if (limitVol > 0 && limitVol < maxLot) {
        maxLot = limitVol;
        if (InpEnableDebug) PrintFormat("ValidateLot: Max Lot for %s adjusted to SYMBOL_VOLUME_LIMIT: %.2f", tradeType, maxLot);
    }

    // Determine number of decimal places needed for the lot size based on step
    int lotDigits = 0;
    if (stepLot > 0 && stepLot < 1) {
        string stepStr = DoubleToString(stepLot, 8);
        int decimalPointPos = StringFind(stepStr, ".");
        if (decimalPointPos >= 0) lotDigits = StringLen(stepStr) - decimalPointPos - 1;
    }
    lotDigits = MathMax(0, MathMin(8, lotDigits)); // Clamp digits 0-8

    // Clamp input lot size
    adjustedLot = inputLot;
    if (adjustedLot < minLot) {
        if(InpEnableDebug) PrintFormat("ValidateLot Warning: %s Input Lot %.*f < Min Lot %.*f. Using Min Lot.", tradeType, lotDigits, inputLot, lotDigits, minLot);
        adjustedLot = minLot;
    }
    if (adjustedLot > maxLot) {
         if(InpEnableDebug) PrintFormat("ValidateLot Warning: %s Input Lot %.*f > Max Lot %.*f. Using Max Lot.", tradeType, lotDigits, inputLot, lotDigits, maxLot);
        adjustedLot = maxLot;
    }

    // Adjust to volume step
    if (stepLot > 0) {
        adjustedLot = MathRound(adjustedLot / stepLot) * stepLot;
    } else { // Handle potentially invalid step
        adjustedLot = MathRound(adjustedLot);
        if(InpEnableDebug) PrintFormat("ValidateLot Warning: Invalid volume step (%.*f) for %s.", lotDigits, stepLot, _Symbol);
    }
    // Normalize after step adjustment
    adjustedLot = NormalizeDouble(adjustedLot, lotDigits);

    // Final clamp check needed after step rounding
    adjustedLot = MathMax(minLot, MathMin(adjustedLot, maxLot));
    adjustedLot = NormalizeDouble(adjustedLot, lotDigits); // Normalize final result

    // Log if adjustment was significant
    if (MathAbs(adjustedLot - inputLot) > (stepLot > 0 ? stepLot * 0.01 : 1e-9) ) { // Tolerance for comparison
         if(InpEnableDebug) PrintFormat("ValidateLot Notice: %s Lot Size finalized to %.*f from %.*f (Min:%.*f, Max:%.*f, Step:%.*f)",
                         tradeType, lotDigits, adjustedLot, lotDigits, inputLot,
                         lotDigits, minLot, lotDigits, maxLot, lotDigits, stepLot);
    }

    // Final check: Is adjusted lot valid?
    if (adjustedLot < minLot || adjustedLot <= 0) {
          PrintFormat("ValidateLot Error: %s FINAL Lot Size %.*f is invalid (< Min Lot %.*f or <=0).",
                       tradeType, lotDigits, adjustedLot, lotDigits, minLot);
          return false; // Failed validation
     }
     return true; // Lot is valid and adjusted
}

//+------------------------------------------------------------------+
//| Initialize Existing Pairs on Startup                             |
//+------------------------------------------------------------------+
void InitializeExistingPairs() {
     if(InpEnableDebug) Print("OnInit: Scanning for existing MAIN positions...");
     // Temporary storage for found positions
     struct FoundPos { ulong ticket; string comment; double entry; ENUM_POSITION_TYPE type; string guid;};
     FoundPos foundPositions[];
     int count = 0;

     // 1. Find all open MAIN magic positions for this symbol
     for(int i = PositionsTotal() - 1; i >= 0; i--) {
          ulong ticket = PositionGetTicket(i);
          if(PositionSelectByTicket(ticket)) {
                if(PositionGetInteger(POSITION_MAGIC) == InpMagicMain && PositionGetString(POSITION_SYMBOL) == _Symbol) {
                     // Store relevant info
                     ArrayResize(foundPositions, count + 1);
                     foundPositions[count].ticket = ticket;
                     foundPositions[count].comment = PositionGetString(POSITION_COMMENT);
                     foundPositions[count].entry = PositionGetDouble(POSITION_PRICE_OPEN);
                     foundPositions[count].type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                     string comment_str = foundPositions[count].comment;
                     string extracted_guid = ""; // Default to empty

                     // Check for 2-character prefixes (RB, RS) first
                     if (StringLen(comment_str) > 2 && (StringSubstr(comment_str, 0, 2) == "RB" || StringSubstr(comment_str, 0, 2) == "RS")) {
                         extracted_guid = StringSubstr(comment_str, 2);
                     }
                     // Check for 1-character prefixes (B, S)
                     else if (StringLen(comment_str) > 1 && (StringSubstr(comment_str, 0, 1) == "B" || StringSubstr(comment_str, 0, 1) == "S")) {
                          extracted_guid = StringSubstr(comment_str, 1);
                     }
                     // Optional: Add a case for comments that might not have a prefix or handle errors

                     foundPositions[count].guid = extracted_guid; // Assign the extracted GUID
                     if (foundPositions[count].guid == "") { // Handle missing/invalid GUID comment
                          if(InpEnableDebug) PrintFormat("InitPairs Warning: Position %I64u has invalid/missing GUID comment: %s", ticket, foundPositions[count].comment);
                     }
                     count++;
                }
          }
     }
      if(InpEnableDebug) PrintFormat("InitPairs: Found %d MAIN positions.", count);
      if(count == 0) return; // No positions to initialize

     // 2. Try to match positions into pairs based on GUID
     bool usedIndices[]; // Track which indices in foundPositions have been paired
     ArrayResize(usedIndices, count);
     ArrayInitialize(usedIndices, false);
     int pairsFound = 0;

     for (int i = 0; i < count; i++) {
        if (usedIndices[i] || foundPositions[i].guid == "") continue; // Skip used or invalid GUID

        for (int j = i + 1; j < count; j++) { // Look for a partner
            if (usedIndices[j] || foundPositions[j].guid == "") continue;

             // Check: Same GUID? Opposite Type?
             if (foundPositions[i].guid == foundPositions[j].guid && foundPositions[i].type != foundPositions[j].type)
             {
                // Found a pair! Add to activeMainPairs tracking array
                 int newSize = ArraySize(activeMainPairs) + 1;
                 ArrayResize(activeMainPairs, newSize);
                 int index = newSize - 1; // Index of the new entry

                 // Directly modify the struct in the array
                 activeMainPairs[index].guid = foundPositions[i].guid; // Use the common GUID

                 // Assign tickets and entries based on type
                 if (foundPositions[i].type == POSITION_TYPE_BUY) {
                     activeMainPairs[index].buyTicket = foundPositions[i].ticket; activeMainPairs[index].buyEntry = foundPositions[i].entry;
                     activeMainPairs[index].sellTicket = foundPositions[j].ticket; activeMainPairs[index].sellEntry = foundPositions[j].entry;
                 } else { // i is SELL, j is BUY
                     activeMainPairs[index].buyTicket = foundPositions[j].ticket; activeMainPairs[index].buyEntry = foundPositions[j].entry;
                     activeMainPairs[index].sellTicket = foundPositions[i].ticket; activeMainPairs[index].sellEntry = foundPositions[i].entry;
                 }

                 // Check current SL to determine initial BE state
                 double buySL=0, sellSL=0;
                 if(PositionSelectByTicket(activeMainPairs[index].buyTicket)) buySL = PositionGetDouble(POSITION_SL);
                 if(PositionSelectByTicket(activeMainPairs[index].sellTicket)) sellSL = PositionGetDouble(POSITION_SL);
                 double point = _Point;
                 activeMainPairs[index].buySLAtBE = (MathAbs(buySL - activeMainPairs[index].buyEntry) < point * 2); // Approx check
                 activeMainPairs[index].sellSLAtBE = (MathAbs(sellSL - activeMainPairs[index].sellEntry) < point * 2); // Approx check

                 // Set open time (approx)
                 if(PositionSelectByTicket(activeMainPairs[index].buyTicket)) activeMainPairs[index].openTime = (datetime)PositionGetInteger(POSITION_TIME);
                 else if(PositionSelectByTicket(activeMainPairs[index].sellTicket)) activeMainPairs[index].openTime = (datetime)PositionGetInteger(POSITION_TIME);
                 else activeMainPairs[index].openTime = TimeCurrent(); // Fallback


                 if(InpEnableDebug) PrintFormat("InitPairs: Initialized existing Pair %s (B:%I64u, S:%I64u). BE State: Buy=%s Sell=%s",
                                                  activeMainPairs[index].guid, activeMainPairs[index].buyTicket, activeMainPairs[index].sellTicket,
                                                  activeMainPairs[index].buySLAtBE?"Y":"N", activeMainPairs[index].sellSLAtBE?"Y":"N");

                 usedIndices[i] = true; // Mark as paired
                 usedIndices[j] = true; // Mark as paired
                 pairsFound++;
                 break; // Found partner for i, move to next i
            } // End if pair found
        } // End inner loop j
     } // End outer loop i

      // Report any remaining unpaired positions
      for(int i=0; i<count; i++) {
         if(!usedIndices[i]) {
             // Log positions that were found but couldn't be paired (missing partner, invalid GUID etc)
             if(InpEnableDebug) PrintFormat("InitPairs Warning: MAIN position %I64u (Comment: '%s', GUID:'%s') remains unpaired. Will NOT be managed.",
                                              foundPositions[i].ticket, foundPositions[i].comment, foundPositions[i].guid);
         }
      }
      if(InpEnableDebug) PrintFormat("InitPairs: Finished. Added %d existing pairs to tracking.", pairsFound);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Stop the timer
   EventKillTimer();

   // Clean up chart objects created by the EA
   ObjectsDeleteAll(0, infoLabelPrefix);          // Delete objects with standard prefix (including new dashboard)
   ObjectDelete(0, DASHBOARD_BG_NAME);             // Explicitly delete dashboard BG
   ObjectDelete(0, DASHBOARD_TEXT_NAME);          // Explicitly delete dashboard Text
   ObjectsDeleteAll(0, tradingDayLineName, 0, -1); // Delete all vertical lines matching prefix
   Comment(""); // Clear comment on deinit (just in case)

   if(InpEnableDebug) Print("MAVERICK EA Deinitialized. Reason: ", reason);
  }

//+------------------------------------------------------------------+
//| Timer function (Called every 'UpdateFrequency' ms)               |
//+------------------------------------------------------------------+
void OnTimer()
  {
   // Update dashboard information periodically
   UpdateRunningTotal();

   // Optional: Less frequent checks can go here
   // CheckTrackedPositionsCrossed(); // For DEBUG logging of trailed SL hits (action handled in transaction)
  }

//+------------------------------------------------------------------+
//| New Bar Check                                                    |
//+------------------------------------------------------------------+
bool NewBar() // Checks if the current bar on the chart is new
  {
   static datetime previousBarTime = 0; // Stores time of the last bar processed
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0); // Time of the currently forming bar's open

   if(currentBarTime != previousBarTime) // If current bar time is different from previous
     {
        previousBarTime = currentBarTime; // Update the stored time
        return true;                      // It's a new bar
     }
   return false;                          // Not a new bar
  }

//+------------------------------------------------------------------+
//| Expert tick function (Called on every tick)                      |
//+------------------------------------------------------------------+
void OnTick()
  {
    // --- Limit logic execution to once per new bar ---
    if(!NewBar()) return;

    datetime currentTime = TimeCurrent(); // Get current server time

    // --- Check for Day Change & Reset Daily States ---
    CheckNewTradingDay(currentTime);

    // --- Manage Existing Positions (Recovery Phase first, then Main Pairs) ---
    // It's crucial ManagePositions handles closed pairs correctly by updating activeMainPairs array
    ManagePositions();

    // --- Check for Main Trade Entry Time ---
    MqlDateTime dt; TimeToStruct(currentTime, dt);
    string currentTimeStr = StringFormat("%02d:%02d", dt.hour, dt.min);

    // Conditions to check if we should OPEN a new main pair:
    bool isTradeTime = (currentTimeStr == InpTradeTime);
    bool isTradingAllowed = !dailyTradingEnded;  // Allow new main trades regardless of recovery state

    if (isTradeTime && isTradingAllowed) {
        if (InpEnableDebug) PrintFormat("Trade Time (%s) Reached. Checking if new MAIN pair needed.", InpTradeTime);

        // **Prevent Rapid Opens:** Ensure only one attempt per minute window around the trade time.
        static datetime lastMainOpenAttemptTime = 0;
        if (currentTime - lastMainOpenAttemptTime >= 55) // Throttle to ~1 attempt/min
        {
            if (OpenMainTrade()) { // Attempt to open a pair (this adds it to tracking on success)
                 lastMainOpenAttemptTime = currentTime; // Record time of successful/attempted open
                 if (InpEnableDebug) Print("==> New Main Pair Opened & Tracked. <==");
             } else {
                 // Log failure to open, OpenMainTrade handles specifics
                  lastMainOpenAttemptTime = currentTime; // Still update time to prevent immediate retry
             }
         } else {
             // Throttled - prevent multiple opens in the same minute
             // if (InpEnableDebug) Print("Trade Time window - Attempt throttled.");
         }
    } // End Check for Main Trade Entry Time

   // --- Optional Cleanup of old chart objects ---
   // DeleteOldLinesIfNoPositions(currentTime); // Runs only if no positions open
  }


//+------------------------------------------------------------------+
//| CheckNewTradingDay: reset daily flags when day changes           |
//+------------------------------------------------------------------+
void CheckNewTradingDay(datetime currentTime)
  {
   // Calculate the start of the current day (00:00:00)
   datetime startOfDay = currentTime - (currentTime % 86400);

   if(startOfDay > currentTradeDate) // Check if the calculated start of day is later than our tracked date
     {
      // New Day detected!
      datetime previousTradeDate = currentTradeDate;
      currentTradeDate = startOfDay; // Update to the new day
      if(InpEnableDebug) PrintFormat("--- New Trading Day Detected: %s ---", TimeToString(currentTradeDate, TIME_DATE));
      // PrintTradeStatus("Before Daily Reset");

      // Reset Daily State Variables
      dailyTradingEnded = false;     // Allow trading for the new day
      recoveryUsedToday = false;     // Reset recovery usage flag
      dailyCumulativeProfit = 0.0; // Reset informational P/L counter
      skipRecovery = false;          // Reset immediate skip flag

      // Check if recovery positions exist from previous day
      int recoveryPositions = CountOpenPositionsMagic(InpMagicRecovery);
      if (recoveryPositions > 0) {
          recoveryUsedToday = true;  // Mark as used because positions carried over
          if (InpEnableDebug) Print("Daily Reset: ", recoveryPositions, " recovery position(s) carried over. UsedToday=TRUE");
      } else {
          recoveryTradeActive = false;
          recoveryUsedToday = false;
          if (InpEnableDebug) Print("Daily Reset: No recovery positions found. All recovery flags reset.");
      }

      // Reset temporary tracking for pair closure evaluation
      lastClosedPair.guid = "";
      lastClosedPair.evaluated = false;

      // **Important:** DO NOT clear activeMainPairs here. Active pairs can span multiple days.
      // ManagePositions loop will naturally remove pairs from activeMainPairs when both sides close.
      // Optional: Can add cleanup here for pairs stuck for too long (e.g., openTime > N days)?

       if(InpEnableDebug) PrintTradeStatus("After Daily Reset");

      // Add a visual marker line for the new day start (or trade time?)
      CreateTradingDayLine(currentTime); // Draw line at time of day change detection
     }
  }

//+------------------------------------------------------------------+
//| CountOpenPositions: count total open positions for this EA       |
//+------------------------------------------------------------------+
int CountOpenPositions()
  {
   // Simple count of positions matching either magic number and current symbol
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol) {
              long magic = PositionGetInteger(POSITION_MAGIC);
             if(magic == InpMagicMain || magic == InpMagicRecovery) {
                  count++;
             }
           }
        }
     }
   return count;
  }

//+------------------------------------------------------------------+
//| CountOpenPositionsMagic: count positions by specific magic       |
//+------------------------------------------------------------------+
int CountOpenPositionsMagic(int magic)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
       if(PositionSelectByTicket(ticket))
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == magic)
           {
            count++;
           }
        }
     }
   return count;
  }

//+------------------------------------------------------------------+
//| GenerateTradeGuid: creates a unique identifier for trades        |
//+------------------------------------------------------------------+
string GenerateTradeGuid()
  {
   // Use timestamp + random number for better uniqueness than just random chars
   long timestamp = TimeCurrent();
   int randomPart = MathRand() % 10000; // Suffix up to 9999
   return IntegerToString(timestamp) + "-" + IntegerToString(randomPart);
  }

//+------------------------------------------------------------------+
//| Helper function to find position ticket from a deal ticket       |
//+------------------------------------------------------------------+
ulong GetPositionTicketByDeal(ulong deal_ticket) {
    // Attempt to select the deal
    if(HistoryDealSelect(deal_ticket)) {
        // If successful, return the associated position ID
        return HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
    }
    // Log error if deal couldn't be selected (rare)
    if(InpEnableDebug) PrintFormat("GetPosTicketByDeal Error: Failed to select deal %I64u", deal_ticket);
    return 0; // Return 0 on failure
}

//+------------------------------------------------------------------+
//| OpenMainTrade: opens Buy & Sell, adds to tracking array        |
//+------------------------------------------------------------------+
bool OpenMainTrade() // Return true if successful
{
    // 1. Generate GUID and Set Comments
    currentTradeGuid = GenerateTradeGuid();
    string buyComment = "B" + currentTradeGuid;
    string sellComment = "S" + currentTradeGuid;
    if(InpEnableDebug) PrintFormat("OpenMainTrade: Attempting Pair GUID: %s, Lot: %.2f", currentTradeGuid, adjustedLotSize);

    // 2. Set Trade Parameters
    trade.SetExpertMagicNumber(InpMagicMain);
    trade.SetDeviationInPoints(5); // Example: Allow 5 points slippage

    // 3. Get Prices & Calculate SL/TP
    MqlTick tick; if(!SymbolInfoTick(_Symbol, tick)) { Print("OpenMainTrade Error: Tick"); return false; }
    double ask = tick.ask; double bid = tick.bid; double point = _Point;
    double slBuy = NormalizeDouble(ask - InpSLPointsMain * point, _Digits);
    double tpBuy = NormalizeDouble(ask + InpTPPointsMain * point, _Digits);
    double slSell = NormalizeDouble(bid + InpSLPointsMain * point, _Digits);
    double tpSell = NormalizeDouble(bid - InpTPPointsMain * point, _Digits);

    ulong buyDealTicket = 0, sellDealTicket = 0;
    ulong buyPosTicket = 0, sellPosTicket = 0;
    bool buyOpenedOK = false, sellOpenedOK = false;

    // --- 4. Try to Open Buy Position ---
    if(!trade.Buy(adjustedLotSize, _Symbol, ask, slBuy, tpBuy, buyComment)) {
        PrintFormat("OpenMainTrade Error: BUY failed. Err:%d %s", trade.ResultRetcode(), trade.ResultComment());
        return false;
    }
    buyDealTicket = trade.ResultDeal(); // Get the deal ticket created
    if (buyDealTicket > 0) {
         buyPosTicket = GetPositionTicketByDeal(buyDealTicket); // Get the position ticket from the deal
         if(buyPosTicket > 0) buyOpenedOK = true; // Check if position ticket is valid
         if(InpEnableDebug && buyOpenedOK) PrintFormat("Main BUY Opened: Deal %I64u -> Pos %I64u @ %.5f", buyDealTicket, buyPosTicket, ask);
         else if (InpEnableDebug) PrintFormat("Main BUY Open Error: Could not get Position Ticket from Deal %I64u.", buyDealTicket);
    } else if(InpEnableDebug) { Print("Main BUY Open Warning: ResultDeal is 0."); } // Should be rare if Buy() returns true

    if(!buyOpenedOK) { Print("OpenMainTrade: Aborting - Failed to confirm BUY position ticket."); return false; }


    // --- 5. Try to Open Sell Position ---
    Sleep(100); // Small pause between requests
    if(!trade.Sell(adjustedLotSize, _Symbol, bid, slSell, tpSell, sellComment)) {
         PrintFormat("OpenMainTrade Error: SELL failed. Err:%d %s. !! Closing Orphan BUY Pos %I64u !!", trade.ResultRetcode(), trade.ResultComment(), buyPosTicket);
         // --- CRITICAL: Close the BUY position ---
         trade.SetExpertMagicNumber(InpMagicMain); // Ensure correct magic
         if(!trade.PositionClose(buyPosTicket)) {
              PrintFormat("!!! CRITICAL ERROR closing orphan BUY position %I64u! Err:%d %s", buyPosTicket, trade.ResultRetcode(), trade.ResultComment());
          } else {
               if(InpEnableDebug) PrintFormat("Orphan BUY position %I64u closed successfully.", buyPosTicket);
          }
          // --- //
          return false; // Opening process failed
     }
      sellDealTicket = trade.ResultDeal();
      if (sellDealTicket > 0) {
          sellPosTicket = GetPositionTicketByDeal(sellDealTicket);
          if(sellPosTicket > 0) sellOpenedOK = true;
           if(InpEnableDebug && sellOpenedOK) PrintFormat("Main SELL Opened: Deal %I64u -> Pos %I64u @ %.5f", sellDealTicket, sellPosTicket, bid);
           else if (InpEnableDebug) PrintFormat("Main SELL Open Error: Could not get Position Ticket from Deal %I64u.", sellDealTicket);
     } else if(InpEnableDebug) { Print("Main SELL Open Warning: ResultDeal is 0."); }

     if(!sellOpenedOK) { // Sell failed to confirm position ticket
        Print("OpenMainTrade Error: Aborting - Failed to confirm SELL position ticket. !! Closing Orphan BUY Pos %I64u !!", buyPosTicket);
         // --- CRITICAL: Close the BUY position ---
          trade.SetExpertMagicNumber(InpMagicMain);
          if(!trade.PositionClose(buyPosTicket)) { /* Log Critical Error */ } else { if(InpEnableDebug) PrintFormat("Orphan BUY %I64u closed.", buyPosTicket); }
         // --- //
        return false;
     }


    // --- 6. Both Confirmed Open: Add to tracking array ---
    if(buyOpenedOK && sellOpenedOK) {
        int newSize = ArraySize(activeMainPairs) + 1;
        if(ArrayResize(activeMainPairs, newSize) == newSize) { // Check resize success
           int index = newSize - 1;
           activeMainPairs[index].guid = currentTradeGuid;
           activeMainPairs[index].buyTicket = buyPosTicket;
           activeMainPairs[index].sellTicket = sellPosTicket;
           activeMainPairs[index].buyEntry = ask;
           activeMainPairs[index].sellEntry = bid;
           activeMainPairs[index].buySLAtBE = false; // Initial state
           activeMainPairs[index].sellSLAtBE = false;// Initial state
           activeMainPairs[index].openTime = TimeCurrent();

           if(InpEnableDebug) PrintFormat("Pair %s Added to Active Tracking (Index %d). B:%I64u@%.5f, S:%I64u@%.5f",
                                            currentTradeGuid, index, buyPosTicket, ask, sellPosTicket, bid);

            mainTradeOpenTime = TimeCurrent(); // Update global last open time
            // CreateTrailTriggerLines(ask, bid, currentTradeGuid); // Visualization (needs unique names)

            return true; // Success! Pair opened and tracked.
         } else { // Resize failed
             Print("OpenMainTrade Error: Failed to resize activeMainPairs array! Pair not tracked. !! Closing BOTH positions %I64u, %I64u !!", buyPosTicket, sellPosTicket);
              // Attempt to close both just-opened positions
              trade.PositionClose(buyPosTicket); Sleep(50); trade.PositionClose(sellPosTicket);
              return false;
         }
    }

    // Should not be reached if logic is sound
    Print("OpenMainTrade Error: Unknown state reached after opening attempts. Attempting cleanup.");
    if (buyPosTicket > 0) trade.PositionClose(buyPosTicket); Sleep(50);
    if (sellPosTicket > 0) trade.PositionClose(sellPosTicket);
    return false;
} // End OpenMainTrade


//+------------------------------------------------------------------+
//| OpenRecoveryTrade: opens recovery pair                           |
//+------------------------------------------------------------------+
bool OpenRecoveryTrade() // Return true if successful
  {
   // --- Pre-checks (Moved from ManagePositions/OnStopLossHit for centralization) ---
   if (!UseRecoveryTrade) { if (InpEnableDebug) Print("OpenRecoveryTrade: Skipped - Disabled by input."); return false; }
   if (recoveryUsedToday) { if (InpEnableDebug) Print("OpenRecoveryTrade: Skipped - Recovery already used today."); return false; }
   if (dailyTradingEnded) { if (InpEnableDebug) Print("OpenRecoveryTrade: Skipped - Daily trading ended flag is set."); return false; }
   if (recoveryTradeActive) { if(InpEnableDebug) Print("OpenRecoveryTrade: Skipped - Another recovery sequence seems active."); return false;} // Safety Check
   // --- //

   string recoveryGuid = GenerateTradeGuid(); // Unique GUID for recovery pair
   if(InpEnableDebug) PrintFormat("OpenRecoveryTrade: Attempting Pair GUID: %s, Lot: %.2f", recoveryGuid, adjustedLotSizeRecovery);

   string buyComment = "RB" + recoveryGuid;
   string sellComment = "RS" + recoveryGuid;

   trade.SetExpertMagicNumber(InpMagicRecovery); // Use recovery magic number
   trade.SetDeviationInPoints(5);

   // Prices, SL, TP
   MqlTick tick; if(!SymbolInfoTick(_Symbol, tick)) { Print("OpenRecoveryTrade Error: Tick"); return false; }
   double ask = tick.ask; double bid = tick.bid; double point = _Point;
   double slBuy = NormalizeDouble(ask - InpSLPointsRecovery * point, _Digits);
   double tpBuy = NormalizeDouble(ask + InpTPPointsRecovery * point, _Digits);
   double slSell = NormalizeDouble(bid + InpSLPointsRecovery * point, _Digits);
   double tpSell = NormalizeDouble(bid - InpTPPointsRecovery * point, _Digits);

   ulong buyRecPosTicket = 0, sellRecPosTicket = 0;
   bool buyRecOpenedOK = false, sellRecOpenedOK = false;

   // --- Open Recovery Buy ---
   if(!trade.Buy(adjustedLotSizeRecovery, _Symbol, ask, slBuy, tpBuy, buyComment)) { /* Log Error */ return false; }
   ulong dealRB = trade.ResultDeal();
   if(dealRB > 0) buyRecPosTicket = GetPositionTicketByDeal(dealRB);
   if(buyRecPosTicket > 0) buyRecOpenedOK = true;
   else { Print("OpenRecoveryTrade: Failed get Buy Pos Ticket."); return false; } // Abort if cannot confirm
    if(InpEnableDebug) PrintFormat("Recovery BUY Opened: Deal %I64u -> Pos %I64u", dealRB, buyRecPosTicket);


   // --- Open Recovery Sell ---
   Sleep(100); // Pause
   if(!trade.Sell(adjustedLotSizeRecovery, _Symbol, bid, slSell, tpSell, sellComment)) {
       PrintFormat("OpenRecoveryTrade Error: SELL failed. Err:%d. !! Closing Orphan Rec BUY %I64u !!", trade.ResultRetcode(), buyRecPosTicket);
       // Close orphan Rec Buy
       trade.SetExpertMagicNumber(InpMagicRecovery); // Ensure magic
       if(!trade.PositionClose(buyRecPosTicket)) { /* Log Critical Error */ } else { if(InpEnableDebug) PrintFormat("Orphan Recovery BUY %I64u closed.", buyRecPosTicket); }
       return false; // Failed
   }
   ulong dealRS = trade.ResultDeal();
   if(dealRS > 0) sellRecPosTicket = GetPositionTicketByDeal(dealRS);
   if(sellRecPosTicket > 0) sellRecOpenedOK = true;
   else {
       Print("OpenRecoveryTrade Error: Failed get Sell Pos Ticket. !! Closing Orphan Rec BUY %I64u !!", buyRecPosTicket);
       // Close orphan Rec Buy
       trade.SetExpertMagicNumber(InpMagicRecovery);
       if(!trade.PositionClose(buyRecPosTicket)) { /* Log Critical Error */ } else { if(InpEnableDebug) PrintFormat("Orphan Recovery BUY %I64u closed.", buyRecPosTicket); }
       return false; // Failed
   }
    if(InpEnableDebug) PrintFormat("Recovery SELL Opened: Deal %I64u -> Pos %I64u", dealRS, sellRecPosTicket);

   // --- Success: Update State ---
   if (buyRecOpenedOK && sellRecOpenedOK) {
        recoveryTradeActive = true; // Mark recovery as NOW active
        recoveryUsedToday = true; // Mark recovery as used for this day
        if(InpEnableDebug) Print("==> Recovery Pair Opened Successfully. State: Active=T, UsedToday=T <==");
        return true; // Success
   }

   // Should not be reached
   Print("OpenRecoveryTrade Error: Unknown state reached.");
   if(buyRecPosTicket>0) trade.PositionClose(buyRecPosTicket); Sleep(50);
   if(sellRecPosTicket>0) trade.PositionClose(sellRecPosTicket);
   return false;
  } // End OpenRecoveryTrade


//+------------------------------------------------------------------+
//| Helper function to remove an element from the active pairs array |
//+------------------------------------------------------------------+
void RemoveActivePair(int index) {
    int size = ArraySize(activeMainPairs);
    if (index < 0 || index >= size) { // Basic validation
         if(InpEnableDebug) PrintFormat("RemoveActivePair Error: Invalid index %d (Size: %d)", index, size);
         return;
     }

    // if(InpEnableDebug) PrintFormat("RemoveActivePair: Removing index %d (GUID: %s) from active list.", index, activeMainPairs[index].guid);

    // Shift elements down only if it's not the last element
    if (index < size - 1) {
       for (int i = index; i < size - 1; i++) {
            activeMainPairs[i] = activeMainPairs[i + 1]; // Overwrite current with next
       }
    }

    // Resize the array to remove the last slot (which is now a duplicate or the one to remove)
    if (ArrayResize(activeMainPairs, size - 1) != size -1 ) {
       PrintFormat("RemoveActivePair Error: Failed to resize activeMainPairs array from %d to %d", size, size - 1);
       // Potential issue if resize fails, array state might be inconsistent
    } else {
        // if(InpEnableDebug) PrintFormat("RemoveActivePair: Array resized to %d.", size - 1);
    }
}

//+------------------------------------------------------------------+
//| ManagePositions: Handles Recovery, then iterates Active Main Pairs|
//+------------------------------------------------------------------+
void ManagePositions()
{
    // --- 1. Recovery Position Management ---
    // Manage recovery trades first. Assumes only one recovery set active at a time.
    int recoveryOpenCount = CountOpenPositionsMagic(InpMagicRecovery);
    if (recoveryTradeActive) { // Only manage if the recovery sequence *should* be active
        if (recoveryOpenCount == 2) {
             TrailSLRecoveryTrade(); // Check BE trigger for recovery pair
        } else if (recoveryOpenCount == 1) {
             ModifySLToEntry(InpMagicRecovery); // Move recovery survivor's SL to entry
        } else if (recoveryOpenCount == 0) {
             // Both recovery positions closed. Phase is over.
             if(InpEnableDebug) Print("ManagePositions: Both recovery positions detected closed.");
             recoveryTradeActive = false; // Reset the ACTIVE flag
             dailyTradingEnded = true; // End trading for the day once recovery sequence finishes
             if (InpEnableDebug) Print("ManagePositions: Recovery phase ended. Set Active=F, DailyEnded=T.");
             // PrintTradeStatus("After Recovery Close");
        }
    } else if (recoveryOpenCount > 0 && !recoveryTradeActive) { // Safety check/State correction
         if(InpEnableDebug) Print("ManagePositions Warning: Found open recovery positions but recoveryTradeActive=false. Setting Active=T.");
         recoveryTradeActive = true;
         if (!recoveryUsedToday) recoveryUsedToday = true; // Mark used if reactivating
    }


    // --- 2. Main Position Management (Runs EVERY Cycle, regardless of recovery state) ---
    // REMOVED: if (!recoveryTradeActive) { ... }

    int active_pair_count = ArraySize(activeMainPairs); 
    // Iterate backwards through the tracked main pairs for safe removal
    for (int i = active_pair_count - 1; i >= 0; i--)
    {
         // Get the current pair info (using direct access, NO reference '&')
         // HedgePairInfo currentPair = activeMainPairs[i]; // Create a copy to work with? Or access directly. Direct is fine.

         // Check if positions associated with this tracked pair are still actually open
         bool isBuyOpen = (activeMainPairs[i].buyTicket != 0 && PositionSelectByTicket(activeMainPairs[i].buyTicket));
         bool isSellOpen = (activeMainPairs[i].sellTicket != 0 && PositionSelectByTicket(activeMainPairs[i].sellTicket));

          // ---- State Correction: Update tracked tickets if positions closed unexpectedly ----
         if (activeMainPairs[i].buyTicket != 0 && !isBuyOpen) {
              if(InpEnableDebug) PrintFormat("ManagePositions Info: Pair %s correcting stale Buy Ticket %I64u.", activeMainPairs[i].guid, activeMainPairs[i].buyTicket);
              activeMainPairs[i].buyTicket = 0; activeMainPairs[i].buySLAtBE = false;
          }
          if (activeMainPairs[i].sellTicket != 0 && !isSellOpen) {
              if(InpEnableDebug) PrintFormat("ManagePositions Info: Pair %s correcting stale Sell Ticket %I64u.", activeMainPairs[i].guid, activeMainPairs[i].sellTicket);
              activeMainPairs[i].sellTicket = 0; activeMainPairs[i].sellSLAtBE = false;
          }

         // ---- Case A: Only BUY Survivor Open ----
          if (isBuyOpen && !isSellOpen) {
              // if (InpEnableDebug) PrintFormat("ManagePositions: Pair %s - Managing Buy survivor (%I64u)", activeMainPairs[i].guid, activeMainPairs[i].buyTicket);
              // A1. Ensure SL at Breakeven (updates pair's buySLAtBE flag)
              ModifySLToEntry(InpMagicMain, activeMainPairs[i].buyTicket, activeMainPairs[i]); // Pass pair struct by ref
              // A2. Check Stage 2 Trailing (requires buySLAtBE == true)
              if (activeMainPairs[i].buySLAtBE) { TrailSLMainTrade(activeMainPairs[i].buyTicket, activeMainPairs[i]); } // Pass pair struct by ref
              // A3. Check for Price hitting BE stop -> Trigger Recovery?
              //    (Recovery trigger check only happens if recovery NOT active/used)
              if (activeMainPairs[i].buySLAtBE && !recoveryTradeActive && !recoveryUsedToday && UseRecoveryTrade && !dailyTradingEnded) {
                  MqlTick tick;
                  if(SymbolInfoTick(_Symbol, tick) && tick.bid <= activeMainPairs[i].buyEntry) {
                      if(InpEnableDebug) PrintFormat("Pair %s: Price @ %.5f HIT Buy Entry @ %.5f while at BE. Trigger Recovery!", activeMainPairs[i].guid, tick.bid, activeMainPairs[i].buyEntry);
                      if(OpenRecoveryTrade()) { /* Recovery Started */ }
                  }
              }
          }
         // ---- Case B: Only SELL Survivor Open ----
          else if (!isBuyOpen && isSellOpen) {
               // if (InpEnableDebug) PrintFormat("ManagePositions: Pair %s - Managing Sell survivor (%I64u)", activeMainPairs[i].guid, activeMainPairs[i].sellTicket);
               // B1. Ensure SL at Breakeven (updates pair's sellSLAtBE flag)
              ModifySLToEntry(InpMagicMain, activeMainPairs[i].sellTicket, activeMainPairs[i]); // Pass pair struct by ref
              // B2. Check Stage 2 Trailing (requires sellSLAtBE == true)
              if (activeMainPairs[i].sellSLAtBE) { TrailSLMainTrade(activeMainPairs[i].sellTicket, activeMainPairs[i]); } // Pass pair struct by ref
              // B3. Check for Price hitting BE stop -> Trigger Recovery?
               //    (Recovery trigger check only happens if recovery NOT active/used)
               if (activeMainPairs[i].sellSLAtBE && !recoveryTradeActive && !recoveryUsedToday && UseRecoveryTrade && !dailyTradingEnded) {
                  MqlTick tick;
                  if(SymbolInfoTick(_Symbol, tick) && tick.ask >= activeMainPairs[i].sellEntry) {
                      if(InpEnableDebug) PrintFormat("Pair %s: Price @ %.5f HIT Sell Entry @ %.5f while at BE. Trigger Recovery!", activeMainPairs[i].guid, tick.ask, activeMainPairs[i].sellEntry);
                      if(OpenRecoveryTrade()) { /* Recovery Started */ }
                  }
              }
         }
         // ---- Case C: BOTH sides are OPEN ----
          else if (isBuyOpen && isSellOpen) {
               // No specific BE/Trailing action needed here. Initial trailing could be added if required.
          }
         // ---- Case D: BOTH sides are CLOSED ----
          else if (!isBuyOpen && !isSellOpen) {
                // This pair is complete. Remove it from active tracking.
                if(InpEnableDebug) PrintFormat("ManagePositions: Pair %s BOTH sides confirmed closed. Removing from active list.", activeMainPairs[i].guid);
                RemoveActivePair(i); // Safe due to backwards iteration
          }
     } // End loop through active pairs

} // End ManagePositions

//+------------------------------------------------------------------+
//| ModifySLToEntry: Sets SL=Entry for SPECIFIC ticket & updates PAIR state |
//+------------------------------------------------------------------+
void ModifySLToEntry(int magic, ulong survivorTicket, HedgePairInfo &pair) // Passed ticket and PAIR reference
{
    if(magic != InpMagicMain) return; // This overload is ONLY for main trades with pair context

    if (!PositionSelectByTicket(survivorTicket)) { /* Log Error */ return; }
    if (PositionGetInteger(POSITION_MAGIC) != magic) { /* Log Error */ return; } // Magic mismatch

    double entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    ENUM_POSITION_TYPE survivorType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double point = _Point;

    // Check if BE already set *for this specific position in this pair*
     bool isAlreadyBE = (survivorType == POSITION_TYPE_BUY) ? pair.buySLAtBE : pair.sellSLAtBE;
     if (isAlreadyBE) return; // Already marked as BE for this pair

    // Check if SL needs modification (is not already at entry)
    if (MathAbs(currentSL - entry) > point * 1.5) { // Use tolerance
         if (InpEnableDebug) PrintFormat("ModifySLToEntry: Pair %s, Pos %I64u (%s), Moving SL from %.5f to Entry %.5f",
                                         pair.guid, survivorTicket, EnumToString(survivorType), currentSL, entry);
         trade.SetExpertMagicNumber(magic); // Use correct magic for modification
         if (!trade.PositionModify(survivorTicket, entry, currentTP)) {
             PrintFormat("ModifySLToEntry ERROR: Pair %s, Pos %I64u Modify Failed! Err:%d %s",
                         pair.guid, survivorTicket, trade.ResultRetcode(), trade.ResultComment());
         } else { // Modification Successful
             if (InpEnableDebug) PrintFormat("ModifySLToEntry OK: Pair %s, Pos %I64u SL set to entry.", pair.guid, survivorTicket);
             // Update the BE flag *in the pair structure*
             if (survivorType == POSITION_TYPE_BUY) pair.buySLAtBE = true; else pair.sellSLAtBE = true;
              // if(InpEnableDebug) PrintFormat("Pair %s: Updated %s SLAtBE flag to TRUE.", pair.guid, (survivorType == POSITION_TYPE_BUY ? "Buy" : "Sell"));
         }
    } else {
        // SL already at entry, ensure flag is set in pair struct
        bool flagUpdated = false;
         if (survivorType == POSITION_TYPE_BUY && !pair.buySLAtBE) { pair.buySLAtBE = true; flagUpdated = true; }
         else if (survivorType == POSITION_TYPE_SELL && !pair.sellSLAtBE) { pair.sellSLAtBE = true; flagUpdated = true; }
         // if (flagUpdated && InpEnableDebug) { PrintFormat("ModifySLToEntry: Pair %s Pos %I64u SL already near entry. Set %s SLAtBE flag.", pair.guid, survivorTicket, (survivorType==POSITION_TYPE_BUY?"Buy":"Sell")); }
    }
}

// Overload for Recovery Trades (Simpler, no Pair Info needed)
void ModifySLToEntry(int magic)
{
    if (magic != InpMagicRecovery) return; // Only for recovery magic

    ulong survivorTicket = 0; int openCount = 0;
     for(int i = PositionsTotal() - 1; i >= 0; i--) { // Find the single open recovery position
         ulong currentTicket = PositionGetTicket(i);
         if(PositionSelectByTicket(currentTicket) && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicRecovery) {
             openCount++; survivorTicket = currentTicket;
             if (openCount > 1) break; // Exit if more than one found (unexpected state)
         }
    }

    if (openCount == 1 && survivorTicket > 0) { // Found exactly one survivor
         if(PositionSelectByTicket(survivorTicket)) {
             double entry = PositionGetDouble(POSITION_PRICE_OPEN);
             double currentSL = PositionGetDouble(POSITION_SL);
             double currentTP = PositionGetDouble(POSITION_TP);
             // Check if SL needs modification
             if (MathAbs(currentSL - entry) > _Point * 1.5) {
                 if(InpEnableDebug) PrintFormat("ModifySLToEntry (Recovery): Modifying Pos %I64u SL to entry %.5f", survivorTicket, entry);
                 trade.SetExpertMagicNumber(InpMagicRecovery);
                 if(!trade.PositionModify(survivorTicket, entry, currentTP)) { /* Log Error */ }
                 else { /* Log Success */ }
             }
         }
     } else if (InpEnableDebug && openCount != 1) {
         // PrintFormat("ModifySLToEntry (Recovery): Found %d positions, expected 1. Skipping.", openCount);
     }
}


//+------------------------------------------------------------------+
//| TrailSLMainTrade: Stage 2 trailing for SPECIFIC ticket in PAIR context |
//+------------------------------------------------------------------+
void TrailSLMainTrade(ulong survivorTicket, HedgePairInfo &pair) { // Passed ticket and PAIR context

    if (!PositionSelectByTicket(survivorTicket)) return;
    if (PositionGetInteger(POSITION_MAGIC) != InpMagicMain) return; // Safety

     ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

    // Verify BE is set *for this pair* before proceeding
     bool isAtBE = (posType == POSITION_TYPE_BUY) ? pair.buySLAtBE : pair.sellSLAtBE;
     if (!isAtBE) { /* If debugging needed, log skipping */ return; }

    // Get needed info
    double entry     = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    double point     = _Point;

    // Calculate Profit in Points
    MqlTick tick; if(!SymbolInfoTick(_Symbol, tick)) return; // Need current price
    double profitPoints = 0.0;
    if(posType == POSITION_TYPE_BUY) profitPoints = (tick.bid - entry) / point;
    else profitPoints = (entry - tick.ask) / point;

    // Check Trigger Condition for Stage 2 Trail
    if(profitPoints >= InpTrail2TriggerMain) {
        // Calculate new SL based on Offset
        double newSL = 0.0;
        int digits = _Digits;
        if(posType == POSITION_TYPE_BUY) {
            newSL = NormalizeDouble(entry + InpTrail2OffsetMain * point, digits);
            newSL = MathMin(newSL, NormalizeDouble(tick.bid - point * 5, digits)); // Keep slightly behind price
        } else { // SELL
            newSL = NormalizeDouble(entry - InpTrail2OffsetMain * point, digits);
            newSL = MathMax(newSL, NormalizeDouble(tick.ask + point * 5, digits)); // Keep slightly behind price
        }

        // Only modify if new SL improves on current SL significantly (avoid micro-adjustments)
        bool modify = false;
        if (posType == POSITION_TYPE_BUY && newSL > currentSL + point * 0.5) modify = true;
        if (posType == POSITION_TYPE_SELL && newSL < currentSL - point * 0.5) modify = true;

        if (modify) {
             if (InpEnableDebug) PrintFormat("TrailSLMainTrade (Stage 2): Pair %s Pos %I64u (%s). Profit %.0f >= Trig %.0f. Moving SL to %.5f",
                                              pair.guid, survivorTicket, EnumToString(posType), profitPoints, (double)InpTrail2TriggerMain, newSL);

             trade.SetExpertMagicNumber(InpMagicMain);
             if(!trade.PositionModify(survivorTicket, newSL, currentTP)) {
                 PrintFormat("TrailSLMainTrade ERROR: Pair %s Pos %I64u Modify Failed! Err:%d %s",
                              pair.guid, survivorTicket, trade.ResultRetcode(), trade.ResultComment());
             } else {
                 if(InpEnableDebug) PrintFormat("TrailSLMainTrade OK: Pair %s Pos %I64u SL trailed to %.5f", pair.guid, survivorTicket, newSL);

                 // --- Track this position for Recovery Blocking ---
                 // Add to trackedPositions array ONLY if not already there
                 bool alreadyTracked = false;
                 for(int j = 0; j < ArraySize(trackedPositions); j++) {
                     if(trackedPositions[j].ticket == survivorTicket) {
                          trackedPositions[j].trailedSL = newSL; // Update SL if re-trailing happens
                          alreadyTracked = true; break;
                     }
                 }
                 if (!alreadyTracked) { // Add new entry if first time hitting stage 2
                      int size = ArraySize(trackedPositions);
                      if (ArrayResize(trackedPositions, size + 1) == size + 1) { // Check resize success
                          trackedPositions[size].ticket = survivorTicket;
                          trackedPositions[size].guid = pair.guid;     // Use guid from the pair
                          trackedPositions[size].trailedSL = newSL;     // Store SL level when added
                          trackedPositions[size].entryPrice = entry;   // Store entry for comparison on SL hit
                          trackedPositions[size].posType = posType;     // Store type for comparison
                          trackedPositions[size].blockRecovery = false; // Initial state
                          if(InpEnableDebug) PrintFormat("... Pos %I64u added to TRAILED tracking list.", survivorTicket);
                      } else { Print("TrailSLMainTrade Error: Failed to resize trackedPositions array!"); }
                  }
                 // --- End tracking ---
             } // End successful modify
         } // End if modify needed
     } // End if profit trigger met
} // End TrailSLMainTrade

//+------------------------------------------------------------------+
//| TrailSLRecoveryTrade: moves Recovery SL to entry when profit reached |
//+------------------------------------------------------------------+
void TrailSLRecoveryTrade() // Moves Recovery Pair positions to BE based on individual profit
  {
   // Operates on any open recovery position individually
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicRecovery)
        {
            double entry = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
             // Skip if already effectively at breakeven
             if(MathAbs(entry-currentSL) < _Point * 1.5 ) continue;

             ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
             MqlTick tick; if(!SymbolInfoTick(_Symbol, tick)) continue; // Need price

             // Calculate profit
             double profitPoints = 0.0;
             if(posType == POSITION_TYPE_BUY) profitPoints = (tick.bid - entry) / _Point;
             else profitPoints = (entry - tick.ask) / _Point;

             // Check trigger and modify SL to entry
             if(profitPoints >= InpRecoveryProfitForBEPoints) {
                 if (InpEnableDebug) PrintFormat("TrailSLRecoveryTrade: Triggered for Pos %I64u (%s). Profit: %.0f >= Trig %.0f. Moving SL to Entry %.5f",
                                                     ticket, EnumToString(posType), profitPoints, (double)InpRecoveryProfitForBEPoints, entry);
                  trade.SetExpertMagicNumber(InpMagicRecovery); // Set correct magic
                  if(!trade.PositionModify(ticket, entry, PositionGetDouble(POSITION_TP))) { // Set SL to entry
                       PrintFormat("TrailSLRecoveryTrade Error: Modify SL for %I64u failed. Err:%d", ticket, trade.ResultRetcode());
                  } else {
                       if(InpEnableDebug) PrintFormat("TrailSLRecoveryTrade OK: Pos %I64u SL moved to entry.", ticket);
                  }
             } // End if profit trigger met
        } // End if recovery position found
   } // End for loop positions
  } // End TrailSLRecoveryTrade

//+------------------------------------------------------------------+
//| DeleteOldLinesIfNoPositions: removes VLines from previous days   |
//+------------------------------------------------------------------+
void DeleteOldLinesIfNoPositions(datetime currentTime)
  {
    // Only clean up if absolutely no EA positions are open
    if (CountOpenPositions() == 0) {
         datetime todayStart = currentTime - (currentTime % 86400);
         int totalObjects = ObjectsTotal(0);

         // Iterate through chart objects
         for(int i = totalObjects - 1; i >= 0; i--) {
             string objName = ObjectName(0, i);
             // Delete old VLines created by this EA
             if(StringFind(objName, tradingDayLineName) == 0) { // Check prefix
                 datetime lineTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
                 if(lineTime < todayStart) { // Delete if from previous day
                    ObjectDelete(0, objName);
                 }
             }
             // Optionally delete other leftover objects by prefix if needed
             // if (StringFind(objName, infoLabelPrefix) == 0) { ObjectDelete(0, objName); }
         }
          // if (InpEnableDebug) Print("Cleanup: Old chart lines deleted as no positions are open.");
    }
  }

//+------------------------------------------------------------------+
//| PrintTradeStatus: outputs detailed EA status for debugging       |
//+------------------------------------------------------------------+
void PrintTradeStatus(string context = "")
  {
     if(!InpEnableDebug) return; // Exit if debugging is off

     string status = StringFormat("\n==== MAVERICK STATUS (%s) ====", context == "" ? TimeToString(TimeCurrent(), TIME_SECONDS) : context);
     status += StringFormat("\nDate: %s | Day Ended: %s | Rec Active: %s | Rec Used: %s | Skip Rec Flag: %s",
                            TimeToString(currentTradeDate, TIME_DATE),
                            dailyTradingEnded ? "Y" : "N",
                            recoveryTradeActive ? "Y" : "N",
                            recoveryUsedToday ? "Y" : "N",
                            skipRecovery ? "Y" : "N");

     status += StringFormat("\nRealized Profit (Run): %.2f", totalRealizedProfit);
     status += StringFormat("\nOpen Pos Count: Total=%d (Main=%d, Rec=%d)",
                            CountOpenPositions(), CountOpenPositionsMagic(InpMagicMain), CountOpenPositionsMagic(InpMagicRecovery));

     // Print Active Main Pair GUIDs and State
     int activeCount = ArraySize(activeMainPairs);
     status += StringFormat("\nActive Main Pairs (%d): ", activeCount);
     if(activeCount > 0) {
         for(int i=0; i<activeCount; i++) {
             // Removed: HedgePairInfo &p = activeMainPairs[i];
             status += StringFormat("\n  [%d] %s (B:%I64u%s, S:%I64u%s)", i, activeMainPairs[i].guid,
                                      activeMainPairs[i].buyTicket, activeMainPairs[i].buySLAtBE?" BE":"",
                                      activeMainPairs[i].sellTicket, activeMainPairs[i].sellSLAtBE?" BE":"");
         }
     } else status += " None";

      // Print Last Closed Pair Info (if available)
     if (lastClosedPair.guid != "") {
         status += StringFormat("\nLast Closed Pair (%s): Total=%.2f (B:%.2f%s, S:%.2f%s) Eval:%s",
                                lastClosedPair.guid, lastClosedPair.totalProfit,
                                lastClosedPair.buyProfit, lastClosedPair.buyHitSL?" SL":"",
                                lastClosedPair.sellProfit, lastClosedPair.sellHitSL?" SL":"",
                                lastClosedPair.evaluated?"Y":"N");
     } else { status += "\nLast Closed Pair: N/A"; }

     status += "\n==================================================";
     Print(status);
}

//+------------------------------------------------------------------+
//| CreateTradingDayLine: draws vertical line at specific time       |
//+------------------------------------------------------------------+
void CreateTradingDayLine(datetime lineTime) // Pass the time for the line
  {
    // Create unique line name using date/time suffix
    MqlDateTime dt; TimeToStruct(lineTime, dt);
    string timeSuffix = StringFormat("%04d%02d%02d_%02d%02d", dt.year, dt.mon, dt.day, dt.hour, dt.min);
    string lineName = tradingDayLineName + "_" + timeSuffix;

    // Check if line already exists to avoid duplicates
    if (ObjectFind(0, lineName) != -1) return;

    // Create the vertical line
    if (ObjectCreate(0, lineName, OBJ_VLINE, 0, lineTime, 0)) {
       ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrGreen);   // Line color
       ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT); // Line style (dotted)
       ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);          // Line width
       ObjectSetInteger(0, lineName, OBJPROP_BACK, true);        // Draw behind price chart
       ObjectSetString(0, lineName, OBJPROP_TOOLTIP, "\n");     // Disable default tooltip
       // ChartRedraw(); // Avoid redrawing in OnInit/OnTick if possible
    } else {
        if(InpEnableDebug) PrintFormat("CreateTradingDayLine Error: Failed create '%s'. Err:%d", lineName, GetLastError());
    }
  }

//+------------------------------------------------------------------+
//| Update and display the dashboard                                 |
//+------------------------------------------------------------------+
void UpdateRunningTotal()
  {
   // Check if dashboard should be shown
   if (!ShowDashboard) {
      // If dashboard should be hidden, delete dashboard objects if they exist
      ObjectDelete(0, DASHBOARD_BG_NAME);
      Comment(""); // Clear any comment
      return;
   }
   
   // --- 1. Calculate Current Unrealized P/L ---
   double unrealizedProfit = 0.0;
   int mainCount = 0; // Count open main positions
   int recCount = 0;  // Count open recovery positions

   for(int i = 0; i < PositionsTotal(); i++) {
      ulong posTicket = PositionGetTicket(i);
      if(PositionSelectByTicket(posTicket) && PositionGetString(POSITION_SYMBOL) == _Symbol) {
          long magic = PositionGetInteger(POSITION_MAGIC);
          if(magic == InpMagicMain || magic == InpMagicRecovery) {
             unrealizedProfit += PositionGetDouble(POSITION_PROFIT);
             if (magic == InpMagicMain) mainCount++; else recCount++;
          }
      }
   }

   // --- 2. Calculate Running Total ---
   // Uses globally tracked REALIZED profit + current UNREALIZED profit
   double runningTotal = totalRealizedProfit + unrealizedProfit;
   string currency = AccountInfoString(ACCOUNT_CURRENCY);

   // --- 3. Build Dashboard String ---
   // Add spaces at the beginning of each line to shift text to the right
   string indent = "     "; // 5 spaces for 5 pixel indent
   string dashboard = StringFormat("%s==== MAVERICK EA (v%.2f) ====\r\n\r\n%sSymbol: %s | Time: %s\r\n",
                                  indent, _Digits==3?1.53:1.55, // Updated version display logic
                                  indent, _Symbol, TimeToString(TimeCurrent(), TIME_SECONDS));

    // -- Status Line --
    string stateStr = "";
    if (dailyTradingEnded) stateStr = "DAILY TRADING ENDED";
    else if (recoveryTradeActive) stateStr = "[RECOVERY ACTIVE]";
    else if (mainCount > 0 || recCount > 0) stateStr = "Trade(s) Active";
    else stateStr = "Idle / Awaiting " + InpTradeTime;
     dashboard += StringFormat("%sStatus: %s\r\n\r\n", indent, stateStr);

    // -- Profit Summary --
    dashboard += indent + "\r\n";
    dashboard += StringFormat("%s Total Realized (EA Run): %.2f %s\r\n", indent, totalRealizedProfit, currency);
    dashboard += StringFormat("%s Unrealized P/L: %.2f %s\r\n", indent, unrealizedProfit, currency);
    dashboard += StringFormat("%s Running Total (Estimate): %.2f %s\r\n", indent, runningTotal, currency);
    dashboard += indent + "\r\n";

    // -- Position Summary --
     dashboard += StringFormat("%s Open Positions: Main=%d | Recov=%d\r\n\r\n\r\n", indent, mainCount, recCount);

    // -- Last 5 Closed Trades --
    dashboard += indent + "Last 5 Closed Trades (B/S/RB/RS-GUID)\r\n";
     bool tradesFound = false;
    for(int i = 4; i >= 0; i--) { // Newest first
        if(lastFiveTrades[i].time > 0) { // Check if slot used
            string profitStr = StringFormat("%.2f", lastFiveTrades[i].profit);
            string prefix = lastFiveTrades[i].profit >= 0 ? "+":"";
            string tradeInfo = StringFormat("%s %s %s (%s)\r\n",
                                             indent, prefix + profitStr,
                                             currency,
                                             lastFiveTrades[i].comment // Show comment B/S/RB/RS-GUID
                                             // Optional Time: TimeToString(lastFiveTrades[i].time, TIME_MINUTES)
                                              );
            dashboard += tradeInfo;
            tradesFound = true;
        }
     }
    if (!tradesFound) dashboard += indent + " (No closed trades logged yet)\r\n";

   dashboard += indent + "________________________________";

   // --- 4. Display Dashboard ---
   // Create background rectangle with black border and gainsboro background
   int x_pos = 10; // Default X distance from corner
   int y_pos = 10; // Default Y distance from corner
   int x_size = 250; // Width of dashboard
   int y_size = 230; // Height of dashboard
   
   // Set corner and adjust position based on dashboard placement setting
   ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER; // Default top-left
   
   switch(DashboardPosition) {
      case DASHBOARD_TOP_RIGHT:
         corner = CORNER_RIGHT_UPPER;
         break;
      case DASHBOARD_BOTTOM_LEFT:
         corner = CORNER_LEFT_LOWER;
         break;
      case DASHBOARD_BOTTOM_RIGHT:
         corner = CORNER_RIGHT_LOWER;
         break;
      // DASHBOARD_TOP_LEFT uses the default
   }

   // Check if Background object exists, create if not
   if(ObjectFind(0, DASHBOARD_BG_NAME) < 0)
     {
      if(!ObjectCreate(0, DASHBOARD_BG_NAME, OBJ_RECTANGLE_LABEL, 0, 0, 0))
        {
         Print("Error creating Dashboard Background: ", GetLastError());
         return; // Exit if creation failed
        }
      ObjectSetInteger(0, DASHBOARD_BG_NAME, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, DASHBOARD_BG_NAME, OBJPROP_XDISTANCE, x_pos);
      ObjectSetInteger(0, DASHBOARD_BG_NAME, OBJPROP_YDISTANCE, y_pos);
      ObjectSetInteger(0, DASHBOARD_BG_NAME, OBJPROP_XSIZE, x_size);
      ObjectSetInteger(0, DASHBOARD_BG_NAME, OBJPROP_YSIZE, y_size);
      ObjectSetInteger(0, DASHBOARD_BG_NAME, OBJPROP_BGCOLOR, clrGainsboro);
      ObjectSetInteger(0, DASHBOARD_BG_NAME, OBJPROP_BORDER_COLOR, clrBlack);
      ObjectSetInteger(0, DASHBOARD_BG_NAME, OBJPROP_BORDER_TYPE, BORDER_FLAT); // Simple border
      ObjectSetInteger(0, DASHBOARD_BG_NAME, OBJPROP_BACK, true); // Send to back
      ObjectSetString(0, DASHBOARD_BG_NAME, OBJPROP_TOOLTIP, "\n"); // Disable tooltip
     }
   else
     {
      // Update corner and position if the object already exists
      ObjectSetInteger(0, DASHBOARD_BG_NAME, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, DASHBOARD_BG_NAME, OBJPROP_XDISTANCE, x_pos);
      ObjectSetInteger(0, DASHBOARD_BG_NAME, OBJPROP_YDISTANCE, y_pos);
     }

   // Use Comment() function which reliably handles multiline text
   Comment(dashboard);
   
   // Force a redraw to ensure everything updates properly
   ChartRedraw(0);
  }


//+------------------------------------------------------------------+
//| CheckTrackedPositionsCrossed - For Debug/Confirmation ONLY       |
//| Checks if a previously trailed pos closed by SL. Action is in Tx handler. |
//+------------------------------------------------------------------+
void CheckTrackedPositionsCrossed()
{
    // Only run if debugging enabled, otherwise skip entirely
    if (!InpEnableDebug) return;

    // Loop through positions that have reached Stage 2 trailing
    for(int i = 0; i < ArraySize(trackedPositions); i++)
    {
       // Skip if we already know recovery is blocked for this pair
       if(trackedPositions[i].blockRecovery) continue;

       // Check if the tracked position ticket is still open
       if(!PositionSelectByTicket(trackedPositions[i].ticket))
       {
           // Position is CLOSED. Check history IF we haven't already confirmed block state.
           if(HistorySelectByPosition(trackedPositions[i].ticket)) // Select history for this specific pos ID
           {
               // Iterate recent deals for this position to find the closing SL deal
               for(int j = HistoryDealsTotal() - 1; j >= 0; j--)
               {
                   ulong dealTicket = HistoryDealGetTicket(j);
                   // Check if this deal CLOSED the position (ENTRY_OUT) and reason was SL
                    if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT &&
                       HistoryDealGetInteger(dealTicket, DEAL_REASON) == DEAL_REASON_SL)
                    {
                        // Found the closing SL deal for this *tracked* position.
                        // HandlePositionClose should have already set the blockRecovery flag.
                        // This is just confirmation logging.
                         PrintFormat("CheckTracked Info: Detected closed tracked Pos %I64u (GUID %s) via SL. Recovery block state should be TRUE.",
                                         trackedPositions[i].ticket, trackedPositions[i].guid);
                         // Optionally, we could forcibly set trackedPositions[i].blockRecovery = true here
                         // as a failsafe, but it duplicates logic.

                        break; // Found the SL close deal
                    }
                     // Optional: Check if closed for TP or other reason
               } // End loop history deals for position
           } // End history select
       } // End if position closed
    } // End for loop trackedPositions
} // End CheckTrackedPositionsCrossed


//+------------------------------------------------------------------+
//| Get Profit of Last Deal for Specific Magic Number (Within Current Day)|
//+------------------------------------------------------------------+
double GetLastDealProfit(int magic) {
    double lastProfit = 0.0;
    // Only look from the start of the current trade date for relevance
    if(HistorySelect(currentTradeDate, TimeCurrent())) {
        int total = HistoryDealsTotal();
        // Iterate backwards to find the most recent relevant deal
        for(int i = total - 1; i >= 0; i--) {
            ulong dealTicket = HistoryDealGetTicket(i);
            if(HistoryDealSelect(dealTicket) && HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == magic) {
                 // Found the last deal with this magic number within the selected period
                 if (HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
                     // Only consider profit/loss from OUT deals (closures)
                     lastProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                 }
                 break; // Found the most recent one, stop searching
            }
        } // End for loop
    } else {
         if (InpEnableDebug) Print("GetLastDealProfit Error: Failed to select history for current day.");
    }
    return lastProfit; // Return profit (0.0 if no relevant OUT deal found)
}


//+------------------------------------------------------------------+
//| Trailing Trigger Lines Visualization (Optional - Kept Commented) |
//+------------------------------------------------------------------+
/*
void CreateTrailTriggerLines(double buyEntry, double sellEntry, string guid)
{
   // Creates horizontal lines for stage 2 trailing trigger levels
   // Names must be unique, hence including GUID
   string buyLineName = StringFormat("%sBuyTrailTrigger_%s", infoLabelPrefix, guid);
   string sellLineName = StringFormat("%sSellTrailTrigger_%s", infoLabelPrefix, guid);

   double buyTriggerPrice = buyEntry + InpTrail2TriggerMain * _Point;
   ObjectCreate(0, buyLineName, OBJ_HLINE, 0, 0, buyTriggerPrice);
   ObjectSetInteger(0, buyLineName, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, buyLineName, OBJPROP_STYLE, STYLE_DOT);

   double sellTriggerPrice = sellEntry - InpTrail2TriggerMain * _Point;
   ObjectCreate(0, sellLineName, OBJ_HLINE, 0, 0, sellTriggerPrice);
   ObjectSetInteger(0, sellLineName, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, sellLineName, OBJPROP_STYLE, STYLE_DOT);
}

void DeleteSpecificPairLines(string guid)
{
    // Helper to delete lines for a specific pair when it closes fully
    string buyLineName = StringFormat("%sBuyTrailTrigger_%s", infoLabelPrefix, guid);
    string sellLineName = StringFormat("%sSellTrailTrigger_%s", infoLabelPrefix, guid);
    ObjectDelete(0, buyLineName);
    ObjectDelete(0, sellLineName);
} */