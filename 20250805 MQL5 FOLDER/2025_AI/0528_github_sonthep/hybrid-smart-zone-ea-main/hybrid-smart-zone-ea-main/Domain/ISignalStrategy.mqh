//+------------------------------------------------------------------+
//| ISignalStrategy - Domain Layer                                   |
//+------------------------------------------------------------------+
class ISignalStrategy
  {
public:
   virtual int GenerateSignal() = 0; // 1=Buy, -1=Sell, 0=None
   virtual string Name() = 0;
  };

// Simple concrete strategy: always buy
class SimpleStrategy : public ISignalStrategy
  {
public:
   int GenerateSignal() override { return 1; } // Always buy
   string Name() override { return "Simple Buy"; }
  }; 