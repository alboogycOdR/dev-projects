//+------------------------------------------------------------------+
//| StrategyManager - Application Layer                              |
//+------------------------------------------------------------------+
#include "../Domain/ISignalStrategy.mqh"
#include "../Domain/HybridSmartZoneStrategy.mqh"

class StrategyManager
  {
private:
   HybridSmartZoneStrategy m_hybridStrategy;
public:
   StrategyManager(
      int ema, int adx, int rsi, int bb, double bbdev, int atr, int macdf, int macds, int macdsig, ENUM_TIMEFRAMES tf)
      : m_hybridStrategy(ema, adx, rsi, bb, bbdev, atr, macdf, macds, macdsig, tf) {}
   void AddStrategy(ISignalStrategy *strategy) {}
   ISignalStrategy* SelectStrategy() { return &m_hybridStrategy; }
   int GetStrategyCount() { return 1; }
  }; 