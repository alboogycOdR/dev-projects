//+------------------------------------------------------------------+
//| TrendStrategy - Trend Following Strategy (Domain Layer)          |
//+------------------------------------------------------------------+
#include <XAUUSD_EA/Domain/ISignalStrategy.mqh>

class TrendStrategy : public ISignalStrategy
  {
public:
   TrendStrategy();
   int GenerateSignal(); // Implement trend-following logic
   string Name();
  }; 