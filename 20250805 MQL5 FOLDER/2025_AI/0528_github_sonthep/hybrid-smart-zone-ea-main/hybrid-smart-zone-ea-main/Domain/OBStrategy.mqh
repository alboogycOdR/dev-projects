//+------------------------------------------------------------------+
//| OBStrategy - Order Block Breakout Strategy (Domain Layer)        |
//+------------------------------------------------------------------+
#include <XAUUSD_EA/Domain/ISignalStrategy.mqh>

class OBStrategy : public ISignalStrategy
  {
public:
   OBStrategy();
   int GenerateSignal(); // Implement OB breakout logic
   string Name();
  }; 