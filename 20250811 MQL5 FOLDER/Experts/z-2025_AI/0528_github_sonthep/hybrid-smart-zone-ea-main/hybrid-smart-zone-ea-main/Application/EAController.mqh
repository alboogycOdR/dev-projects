//+------------------------------------------------------------------+
//| EAController - Application Layer                                 |
//+------------------------------------------------------------------+
#include "StrategyManager.mqh"
#include "SessionManager.mqh"
#include "OrderRouter.mqh"
#include "../Domain/RiskManager.mqh"
#include "../Domain/ProtectionManager.mqh"
#include "../Domain/NewsTimeFilter.mqh"

class EAController
  {
private:
   StrategyManager    m_strategyManager;
   SessionManager     m_sessionManager;
   OrderRouter        m_orderRouter;
   RiskManager        m_riskManager;
   ProtectionManager  m_protectionManager;
   NewsTimeFilter     m_newsTimeFilter;
public:
   EAController(
      int ema, int adx, int rsi, int bb, double bbdev, int atr, int macdf, int macds, int macdsig, ENUM_TIMEFRAMES tf,
      double riskPercent)
     : m_strategyManager(ema, adx, rsi, bb, bbdev, atr, macdf, macds, macdsig, tf),
       m_riskManager(riskPercent),
       m_protectionManager(atr)
     {}
   ~EAController() {}
   int OnInit()
     {
      if(!m_sessionManager.Initialize())
         return INIT_FAILED;
      if(!m_riskManager.Initialize())
         return INIT_FAILED;
      if(!m_protectionManager.Initialize())
         return INIT_FAILED;
      if(!m_newsTimeFilter.Initialize())
         return INIT_FAILED;
      return INIT_SUCCEEDED;
     }
   void OnDeinit(const int reason) {}
   void OnTick()
     {
      if(!m_sessionManager.IsTradingAllowed())
         return;
      if(!m_newsTimeFilter.IsTradingAllowed())
         return;
      ISignalStrategy *strategy = m_strategyManager.SelectStrategy();
      if(strategy == NULL)
         return;
      int signal = strategy.GenerateSignal();
      if(signal == 0)
         return;
      double lot = m_riskManager.CalculateLotSize();
      double sl = m_protectionManager.CalculateStopLoss(signal);
      double tp = m_protectionManager.CalculateTakeProfit(signal);
      m_orderRouter.RouteOrder(signal, lot, sl, tp);
      m_orderRouter.TrailingStop();
     }
  }; 