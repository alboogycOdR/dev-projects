// **5. Stop Loss Manager Module**

// *   **Path:** `...\MQL5\Include\ScalpEA\ScalpEA_StopLossManager.mqh`
// *   **Filename:** `ScalpEA_StopLossManager.mqh`

// ```mql5
//+------------------------------------------------------------------+
//| ScalpEA_StopLossManager.mqh                                      |
//| Stop Loss Manager Module for Scalp EA                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.example.com"
#property strict

// Include required libraries
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//--- Stop Loss Manager Class
class CStopLossManager {
private:
   // Configuration parameters
   double   m_initialSLPips;     // Initial SL (pips, if > 0)
   double   m_trailingSLPips;    // Trailing SL (pips, 0=off)
   double   m_minProfitToRisk;   // R:R for TP calc (if > 0)
   double   m_breakevenProfitPips; // Pips profit for Breakeven trigger (0=off)
   ulong    m_magicNumber;       // EA Magic Number
   string   m_symbol;            // Symbol

   // Objects
   CTrade        m_trade;         // Trade object
   CPositionInfo m_posInfo;       // PositionInfo object
   CSymbolInfo   m_symbolInfo;    // SymbolInfo object

   // Internal state
   bool     m_isInitialized;

   // Validate ticket belongs to this EA instance
   bool ValidateTicket(ulong ticket) {
       if (!m_isInitialized || ticket <= 0 || !m_posInfo.Select(ticket)) return false;
       return (m_posInfo.Symbol() == m_symbol && m_posInfo.Magic() == m_magicNumber);
   }

   // Convert pips to price distance
   double PipsToPriceDistance(double pips) {
       if (!m_isInitialized || pips <= 0) return 0.0;
       double point = m_symbolInfo.Point(); int digits = m_symbolInfo.Digits(); if(point<=0||digits<0)return 0.0;
       double pipsMult = (digits==2 || digits==4 || digits==0) ? 1.0 : 10.0; // Adjust based on digits
       if(m_symbol == "XAUUSD") pipsMult = 10.0; // Override for Gold if needed
       return pips * point * pipsMult;
   }

   // Get current market prices safely
   bool GetMarketPrices(double &bid, double &ask) {
       if (!m_isInitialized || !m_symbolInfo.RefreshRates()) return false;
       bid = m_symbolInfo.Bid(); ask = m_symbolInfo.Ask(); return (bid > 0 && ask > 0);
   }

   // Get min stop distance in price units
   double GetMinStopDistance() {
       if (!m_isInitialized) return 0.0;
       double stopsLevelPts = (double)m_symbolInfo.StopsLevel(); if(stopsLevelPts<1)stopsLevelPts=1;
       double point = m_symbolInfo.Point(); if(point <=0) point = 0.00001; // Failsafe
       return stopsLevelPts * point;
   }

public:
   CStopLossManager() { m_isInitialized=false; m_initialSLPips=50; m_trailingSLPips=0; m_minProfitToRisk=0; m_breakevenProfitPips=0; m_magicNumber=0; m_symbol=""; }
   ~CStopLossManager() {}

   // Initialize the module
   bool Initialize(double initialSLPips, double trailingSLPips, double minProfitToRisk, double breakevenPips, ulong magicNumber, string symbol) {
       m_symbol=symbol; if (!m_symbolInfo.Name(m_symbol)){Print("SLM Init Err: Bad Symbol ", m_symbol); return false;}
       m_initialSLPips = initialSLPips > 0 ? initialSLPips : 0;
       m_trailingSLPips = trailingSLPips >= 0 ? trailingSLPips : 0; // Allow 0 to disable
       m_minProfitToRisk = minProfitToRisk > 0 ? minProfitToRisk : 0;
       m_breakevenProfitPips = breakevenPips >= 0 ? breakevenPips : 0; // Allow 0 to disable
       m_magicNumber = magicNumber; m_trade.SetExpertMagicNumber(m_magicNumber);
       m_isInitialized = true;
       // Print("Stop Loss Manager Initialized: InitialSL:",m_initialSLPips," Trail:",m_trailingSLPips," RR:",m_minProfitToRisk," BE:",m_breakevenProfitPips);
       return true;
   }

   // Calculate initial SL level
   double CalculateInitialStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType) {
       if (!m_isInitialized || entryPrice<=0 || m_initialSLPips<=0) return 0.0;
       double slDist = PipsToPriceDistance(m_initialSLPips); if(slDist<=0) return 0.0;
       double slPrice=0; bool isBuy=(orderType==ORDER_TYPE_BUY||orderType==ORDER_TYPE_BUY_STOP||orderType==ORDER_TYPE_BUY_LIMIT);
       if(isBuy) slPrice = entryPrice - slDist; else slPrice = entryPrice + slDist;
       return NormalizeDouble(slPrice, m_symbolInfo.Digits());
   }

   // Calculate TP level based on SL and R:R
   double CalculateTakeProfit(double entryPrice, double stopLoss, ENUM_ORDER_TYPE orderType) {
       if (!m_isInitialized || entryPrice<=0 || stopLoss<=0 || m_minProfitToRisk<=0) return 0.0;
       double riskDist = MathAbs(entryPrice - stopLoss); if(riskDist <= m_symbolInfo.Point()) return 0.0;
       double tpPrice=0; bool isBuy=(orderType==ORDER_TYPE_BUY||orderType==ORDER_TYPE_BUY_STOP||orderType==ORDER_TYPE_BUY_LIMIT);
       if(isBuy) tpPrice = entryPrice + riskDist * m_minProfitToRisk; else tpPrice = entryPrice - riskDist * m_minProfitToRisk;
       return NormalizeDouble(tpPrice, m_symbolInfo.Digits());
   }

   // Close a specific trade
   bool CloseTrade(ulong ticket, string reason = "") {
       if (!ValidateTicket(ticket)) return false;
       //Print("SLM Close Attempt #", ticket, " Reason: ", reason);
       if (!m_trade.PositionClose(ticket)) { Print("SLM Close FAILED #", ticket, "! Err:", m_trade.ResultRetcode(), "-", m_trade.ResultComment()); return false; }
       //Print("SLM Closed #", ticket, " OK. Reason: ", reason);
       return true;
   }

   // Adjust SL based on AI command (ADJUST_UP, ADJUST_DOWN)
   bool AdjustStopLossAI(ulong ticket, string adjustmentCommand) {
      if (!ValidateTicket(ticket)) return false;
      double entry=m_posInfo.PriceOpen(); double curSL=m_posInfo.StopLoss(); double curTP=m_posInfo.TakeProfit();
      ENUM_POSITION_TYPE posType=m_posInfo.PositionType(); int digits=m_symbolInfo.Digits();
      if(curSL <= 0) { /* Print("SLM AI Adjust Err: Current SL is zero for #",ticket); */ return false; }
      double bid,ask; if(!GetMarketPrices(bid,ask)) return false; double relPrice=(posType==POSITION_TYPE_BUY)?bid:ask;

      double newSL = 0; string logReason = adjustmentCommand;
      if(adjustmentCommand == "ADJUST_UP") { // Widen
          double factor = 1.5; logReason="Widen SL(AI)";
          if(posType==POSITION_TYPE_BUY){double d=entry-curSL; if(d<=0)return false; newSL=Norm(entry-(d*factor),digits);}
          else{double d=curSL-entry; if(d<=0)return false; newSL=Norm(entry+(d*factor),digits);}
      } else if (adjustmentCommand == "ADJUST_DOWN") { // Tighten
          double factor=0.7; logReason="Tighten SL(AI)";
          if(posType==POSITION_TYPE_BUY){double d=entry-curSL; if(d<=0)return false; newSL=Norm(entry-(d*factor),digits);}
          else{double d=curSL-entry; if(d<=0)return false; newSL=Norm(entry+(d*factor),digits);}
          // Prevent tightening beyond entry
          if((posType==POSITION_TYPE_BUY && newSL >= entry) || (posType==POSITION_TYPE_SELL && newSL <= entry)) { /*Print("SLM AI Tighten Stop: Cannot tighten beyond entry.");*/ return false;}
      } else { return false; } // Only handles UP/DOWN

      if(newSL<=0) { /* Print("SLM AI Adjust Err: Calc new SL is zero/neg for #",ticket); */ return false;}
      // Validate vs market price and min distance
      double minDist=GetMinStopDistance(); if(minDist<=0)minDist=m_symbolInfo.Point();
      if((posType==POSITION_TYPE_BUY && newSL>=relPrice) || (posType==POSITION_TYPE_SELL && newSL<=relPrice)) { /*Print("SLM AI Adjust Err: New SL wrong side of price for #",ticket);*/ return false; }
      if((posType==POSITION_TYPE_BUY && (relPrice-newSL)<minDist) || (posType==POSITION_TYPE_SELL && (newSL-relPrice)<minDist)) { /*Print("SLM AI Adjust Err: New SL too close for #",ticket);*/ return false; }

      // Apply modification
      // Print("SLM AI Adjust Attempt (",logReason,") #",ticket," from SL ",curSL," to ",newSL);
      if (!m_trade.PositionModify(ticket, newSL, curTP)) { Print("SLM AI Adjust FAILED #", ticket, "! Err:", m_trade.ResultRetcode(),"-",m_trade.ResultComment()); return false; }
      // Print("SLM AI Adjusted OK #",ticket,". New SL:", newSL);
      return true;
   }

   // Apply trailing stop logic
   bool ApplyTrailingStop(ulong ticket) {
       if (!ValidateTicket(ticket) || m_trailingSLPips <= 0) return false;
       double entry=m_posInfo.PriceOpen(); double curSL=m_posInfo.StopLoss(); double curTP=m_posInfo.TakeProfit();
       ENUM_POSITION_TYPE posType=m_posInfo.PositionType(); int digits=m_symbolInfo.Digits();
       double bid,ask; if(!GetMarketPrices(bid,ask)) return false; double relPrice=(posType==POSITION_TYPE_BUY)?bid:ask;
       double trailDist=PipsToPriceDistance(m_trailingSLPips); if(trailDist<=0) return false;

       double newSL = 0;
       if(posType==POSITION_TYPE_BUY){ newSL=Norm(relPrice-trailDist,digits); if(newSL<=curSL && curSL!=0) return false; /*Only move up*/ if(newSL<=entry && curSL < entry) return false; /*Don't trail if still below entry unless current SL=0*/}
       else{ newSL=Norm(relPrice+trailDist,digits); if(newSL>=curSL && curSL!=0) return false; /*Only move down*/ if(newSL>=entry && curSL > entry) return false; /*Don't trail if still above entry unless current SL=0*/}

       // Validate vs market price and min distance
       double minDist=GetMinStopDistance(); if(minDist<=0)minDist=m_symbolInfo.Point();
       if((posType==POSITION_TYPE_BUY && newSL>=relPrice) || (posType==POSITION_TYPE_SELL && newSL<=relPrice)) return false; // Already crossed market price
       if((posType==POSITION_TYPE_BUY && (relPrice-newSL)<minDist) || (posType==POSITION_TYPE_SELL && (newSL-relPrice)<minDist)) return false; // Too close

       // Check if change is significant
        if(curSL != 0 && MathAbs(newSL-curSL) < m_symbolInfo.Point()) return false;

       // Apply modification
       // Print("SLM Trail Attempt #", ticket, ". CurSL:",curSL," PropSL:",newSL);
       if (!m_trade.PositionModify(ticket, newSL, curTP)) { /*Print("SLM Trail FAILED #",ticket," Err:",m_trade.ResultRetcode());*/ return false; }
       // Print("SLM Trailed OK #",ticket,". New SL:", newSL);
       return true;
   }

   // Apply breakeven logic
   bool ApplyBreakevenStop(ulong ticket) {
       if (!ValidateTicket(ticket) || m_breakevenProfitPips <= 0) return false;
       double entry=m_posInfo.PriceOpen(); double curSL=m_posInfo.StopLoss(); double curTP=m_posInfo.TakeProfit();
       ENUM_POSITION_TYPE posType=m_posInfo.PositionType(); int digits=m_symbolInfo.Digits();
       double bid,ask; if(!GetMarketPrices(bid,ask)) return false;
       double beDist=PipsToPriceDistance(m_breakevenProfitPips); if(beDist<=0) return false;
       double buffer=PipsToPriceDistance(1.0); // 1 pip buffer
       if(buffer <= 0) buffer = m_symbolInfo.Point(); // Min 1 point buffer

       bool profitReached = false;
       if(posType==POSITION_TYPE_BUY && bid >= (entry+beDist)) profitReached=true;
       else if(posType==POSITION_TYPE_SELL && ask <= (entry-beDist)) profitReached=true;
       if(!profitReached) return false; // Target not reached

       double beSLPrice = (posType==POSITION_TYPE_BUY) ? Norm(entry+buffer,digits) : Norm(entry-buffer,digits);
       // Check if SL needs modification (is it below BE target for BUY, above for SELL)
       bool modNeeded = (posType==POSITION_TYPE_BUY && (curSL==0 || curSL < beSLPrice)) || (posType==POSITION_TYPE_SELL && (curSL==0 || curSL > beSLPrice));
       if(!modNeeded) return false;

       // Validate vs market price and min distance
       double minDist=GetMinStopDistance(); if(minDist<=0)minDist=m_symbolInfo.Point();
       double relPrice=(posType==POSITION_TYPE_BUY)?bid:ask;
       if((posType==POSITION_TYPE_BUY && beSLPrice>=relPrice) || (posType==POSITION_TYPE_SELL && beSLPrice<=relPrice)) { /* Print("SLM BE Err: Target BE SL",beSLPrice," wrong side of price ",relPrice," #",ticket); */ return false; }
       if((posType==POSITION_TYPE_BUY && (relPrice-beSLPrice)<minDist) || (posType==POSITION_TYPE_SELL && (beSLPrice-relPrice)<minDist)) { /* Print("SLM BE Err: Target BE SL",beSLPrice," too close to price ",relPrice," #",ticket); */ return false; }

       // Apply modification
       // Print("SLM BE Apply Attempt #",ticket,". CurSL:",curSL," TargetSL:",beSLPrice);
       if (!m_trade.PositionModify(ticket, beSLPrice, curTP)) { Print("SLM BE Apply FAILED #",ticket,"! Err:",m_trade.ResultRetcode(),"-",m_trade.ResultComment()); return false; }
       // Print("SLM BE Applied OK #",ticket,". New SL:",beSLPrice);
       return true;
   }

   // Adjust TP level based on R:R
   bool AdjustTakeProfit(ulong ticket, double newRiskRewardRatio) {
       if (!ValidateTicket(ticket)) return false;
       if (newRiskRewardRatio <= 0) newRiskRewardRatio = m_minProfitToRisk; // Use default if needed
       if (newRiskRewardRatio <= 0) return false; // Cannot adjust if no valid R:R
       double entry=m_posInfo.PriceOpen(); double curSL=m_posInfo.StopLoss(); double curTP=m_posInfo.TakeProfit();
       ENUM_POSITION_TYPE posType=m_posInfo.PositionType(); int digits=m_symbolInfo.Digits();
       if(curSL<=0){/*Print("SLM Adj TP Err: Need valid SL for #",ticket);*/ return false;}
       double riskDist=MathAbs(entry-curSL); if(riskDist<=m_symbolInfo.Point()){/*Print("SLM Adj TP Err: Risk dist too small #",ticket);*/return false;}

       double newTP=(posType==POSITION_TYPE_BUY)?Norm(entry+(riskDist*newRiskRewardRatio),digits):Norm(entry-(riskDist*newRiskRewardRatio),digits);
       if(MathAbs(newTP-curTP)<m_symbolInfo.Point()) return true; // No change needed

       // Validate vs market price and min distance
       double bid,ask; if(!GetMarketPrices(bid,ask)) return false; double relPrice=(posType==POSITION_TYPE_BUY)?ask:bid; // Price TP must cross
       double minDist=GetMinStopDistance(); if(minDist<=0)minDist=m_symbolInfo.Point();
       if((posType==POSITION_TYPE_BUY && newTP<=relPrice)||(posType==POSITION_TYPE_SELL && newTP>=relPrice)) { /* Print("SLM Adj TP Err: New TP wrong side of price ",relPrice," #",ticket); */ return false; }
       if((posType==POSITION_TYPE_BUY && (newTP-relPrice)<minDist)||(posType==POSITION_TYPE_SELL && (relPrice-newTP)<minDist)) { /* Print("SLM Adj TP Err: New TP too close to price ",relPrice," #",ticket); */ return false; }

       // Apply modification
       // Print("SLM Adj TP Attempt #",ticket," (R:R ",newRiskRewardRatio,"). CurTP:",curTP," NewTP:",newTP);
       if (!m_trade.PositionModify(ticket, curSL, newTP)) { Print("SLM Adj TP FAILED #",ticket,"! Err:",m_trade.ResultRetcode(),"-",m_trade.ResultComment()); return false; }
       // Print("SLM Adj TP OK #",ticket,". New TP:",newTP);
       return true;
   }

   // Process all stops (Trailing, Breakeven) for EA's open positions
   void ProcessAllStops() {
       if (!m_isInitialized) return;
       bool trailOK=(m_trailingSLPips>0); bool beOK=(m_breakevenProfitPips>0);
       if(!trailOK && !beOK) return; // Nothing enabled
       int total = PositionsTotal();
       for (int i=0; i<total; i++) { ulong t=PositionGetTicket(i); if(ValidateTicket(t)) { if(beOK) ApplyBreakevenStop(t); if(trailOK) ApplyTrailingStop(t); } if(IsStopped()) break; } // Allow stopping mid-loop
   }
   // Helpers
   double Norm(double v, int d){return NormalizeDouble(v,d);}
};
//+------------------------------------------------------------------+