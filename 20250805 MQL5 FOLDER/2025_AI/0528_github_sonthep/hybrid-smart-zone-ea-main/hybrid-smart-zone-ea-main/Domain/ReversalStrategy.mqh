//+------------------------------------------------------------------+
//| ReversalStrategy - Reversal Strategy (Domain Layer)              |
//+------------------------------------------------------------------+
#include <XAUUSD_EA/Domain/ISignalStrategy.mqh>

class ReversalStrategy : public ISignalStrategy
  {
public:
   ReversalStrategy();
   int GenerateSignal(); // Implement reversal logic
   string Name();
  }; 