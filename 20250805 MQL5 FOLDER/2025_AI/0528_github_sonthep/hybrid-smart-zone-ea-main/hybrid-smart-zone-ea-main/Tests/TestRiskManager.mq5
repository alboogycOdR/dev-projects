//+------------------------------------------------------------------+
//| TestRiskManager - Unit Test for Risk Management                  |
//+------------------------------------------------------------------+
#include <XAUUSD_EA/Domain/RiskManager.mqh>

void TestCalculateLotSize()
  {
   RiskManager risk;
   double lot = risk.CalculateLotSize();
   Print("Calculated Lot Size: ", lot);
  }

void TestCalculateStopLoss()
  {
   RiskManager risk;
   double sl = risk.CalculateStopLoss();
   Print("Calculated Stop Loss: ", sl);
  }

void TestCalculateTakeProfit()
  {
   RiskManager risk;
   double tp = risk.CalculateTakeProfit();
   Print("Calculated Take Profit: ", tp);
  }

void TestCheckDrawdown()
  {
   RiskManager risk;
   bool exceeded = risk.CheckDrawdown();
   Print("Drawdown Exceeded: ", exceeded);
  }

void OnStart()
  {
   TestCalculateLotSize();
   TestCalculateStopLoss();
   TestCalculateTakeProfit();
   TestCheckDrawdown();
  } 