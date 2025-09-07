//+------------------------------------------------------------------+
//| RiskManager - Domain Layer                                       |
//+------------------------------------------------------------------+
class RiskManager
  {
private:
   double m_riskPercent;
   double m_maxDrawdown;
   int    m_lossStreak;
   int    m_lossCount;
   // Add more risk parameters as needed
public:
   RiskManager(double riskPercent) : m_riskPercent(riskPercent), m_lossCount(0) {}
   void SetLossCount(int lossCount) { m_lossCount = lossCount; }
   double CalculateLotSize()
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskAmount = equity * m_riskPercent / 100.0;
      double lot = NormalizeDouble(riskAmount / 100.0, 2);
      if(m_lossCount > 0)
         lot *= MathPow(1.2, m_lossCount);
      return lot;
     }
   double CalculateStopLoss() { return 0.0; }
   double CalculateTakeProfit() { return 0.0; }
   bool   CheckDrawdown() { return true; }
   void   UpdateLossStreak(bool isLoss) {}
   bool Initialize() { return true; }
  }; 