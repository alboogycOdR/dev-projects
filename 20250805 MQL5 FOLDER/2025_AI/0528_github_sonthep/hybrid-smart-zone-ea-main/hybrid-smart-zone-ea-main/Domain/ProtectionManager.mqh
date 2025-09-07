//+------------------------------------------------------------------+
//| ProtectionManager - Domain Layer                                 |
//+------------------------------------------------------------------+
class ProtectionManager
  {
private:
   int m_atrPeriod;
   int m_swingLookback;
   double m_maxDrawdown;
   int    m_maxLossStreak;
public:
   ProtectionManager(int atrPeriod, int swingLookback=20) : m_atrPeriod(atrPeriod), m_swingLookback(swingLookback) {}
   bool IsDrawdownExceeded() { return false; }
   bool IsLossStreakExceeded() { return false; }
   void Update(double currentDrawdown, int currentLossStreak) {}
   bool Initialize() { return true; }
   double FindSwingLow(int bars)
     {
      double swingLow = iLow(_Symbol, PERIOD_CURRENT, 1);
      for(int i=2; i<=bars; i++)
        swingLow = MathMin(swingLow, iLow(_Symbol, PERIOD_CURRENT, i));
      return swingLow;
     }
   double FindSwingHigh(int bars)
     {
      double swingHigh = iHigh(_Symbol, PERIOD_CURRENT, 1);
      for(int i=2; i<=bars; i++)
        swingHigh = MathMax(swingHigh, iHigh(_Symbol, PERIOD_CURRENT, i));
      return swingHigh;
     }
   double CalculateStopLoss(int signal)
     {
      if(signal == 1)
         return FindSwingLow(m_swingLookback);
      else
         return FindSwingHigh(m_swingLookback);
     }
   double CalculateTakeProfit(int signal)
     {
      double entry = (signal == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = CalculateStopLoss(signal);
      double risk = MathAbs(entry - sl);
      double reward = risk * 1.5; // RR 1.5
      if(signal == 1)
         return entry + reward;
      else
         return entry - reward;
     }
  }; 