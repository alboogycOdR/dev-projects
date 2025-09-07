//+------------------------------------------------------------------+
//|                       CapitalProtector.mqh                       |
//|     SmartGuard EA v2.0 – Dynamic Equity Lock & Drawdown Guard   |
//+------------------------------------------------------------------+
#property strict
#include "StrategyConfig.mqh"

//+-----------------------------+
//| Internal Capital Variables |
//+-----------------------------+
double InitialDepositCopy = 0.0;
double LockedCapital = 0.0;
double MaxEverEquity = 0.0;

//+-----------------------------+
//| Lock Milestone Curve:      |
//| [Profit %, Lock %]         |
//+-----------------------------+
double LockCurve[][2] = {
   {0.05, 0.03},
   {0.10, 0.06},
   {0.15, 0.10},
   {0.25, 0.15},
   {0.40, 0.25},
   {0.60, 0.35},
   {0.80, 0.50},
   {1.00, 0.70},
   {1.50, 1.00},
   {2.00, 1.20}
};

//+------------------------------------------------------------------+
//| Initialize Capital Logic                                         |
//+------------------------------------------------------------------+
void InitCapitalProtector(double deposit)
{
   InitialDepositCopy = deposit;
   LockedCapital = deposit;
   MaxEverEquity = deposit;

   PrintFormat("🔐 [CapitalProtector] Init locked capital at %.2f", LockedCapital);
}

//+------------------------------------------------------------------+
//| Update Lock Milestone (Called on Tick)                           |
//+------------------------------------------------------------------+
void UpdateCapitalProtector()
{
   if (InitialDepositCopy <= 0.0)
   {
      Print("⚠️ [CapitalProtector] Deposit not initialized. Skipping lock update.");
      return;
   }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if (equity <= 0.0)
   {
      Print("⚠️ [CapitalProtector] Invalid equity. Skipping lock update.");
      return;
   }

   MaxEverEquity = MathMax(MaxEverEquity, equity);
   double profit = MaxEverEquity - InitialDepositCopy;
   double profitRatio = profit / InitialDepositCopy;

   PrintFormat("📈 [CapitalProtector] MaxEquity: %.2f | Profit: %.2f | Ratio: %.2f%%",
               MaxEverEquity, profit, profitRatio * 100.0);

   int rows = ArrayRange(LockCurve, 0);
   for (int i = rows - 1; i >= 0; i--)
   {
      double profitTrigger = LockCurve[i][0];
      double lockRatio = LockCurve[i][1];

      double newLockedCapital = InitialDepositCopy + (InitialDepositCopy * lockRatio);

      if (profitRatio >= profitTrigger && newLockedCapital > LockedCapital)
      {
         LockedCapital = newLockedCapital;
         PrintFormat("🔐 [CapitalProtector] Lock milestone reached: %.0f%% → Locked: %.2f",
                     profitTrigger * 100.0, LockedCapital);
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Check Drawdown Violation                                        |
//+------------------------------------------------------------------+
bool IsDrawdownLimitBreached(double maxDrawdownPercent)
{
   if (LockedCapital <= 0.0)
   {
      Print("⚠️ [CapitalProtector] Locked capital not initialized.");
      return false;
   }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdown = ((LockedCapital - equity) / LockedCapital) * 100.0;

   if (drawdown >= maxDrawdownPercent)
   {
      PrintFormat("🚨 [CapitalProtector] Max drawdown breached: %.2f%% ≥ %.2f%%", drawdown, maxDrawdownPercent);
      return true;
   }

   PrintFormat("✅ [CapitalProtector] Drawdown OK: %.2f%% < %.2f%%", drawdown, maxDrawdownPercent);
   return false;
}

//+------------------------------------------------------------------+
//| Return Current Locked Capital                                    |
//+------------------------------------------------------------------+
double GetLockedCapital()
{
   return LockedCapital;
}
