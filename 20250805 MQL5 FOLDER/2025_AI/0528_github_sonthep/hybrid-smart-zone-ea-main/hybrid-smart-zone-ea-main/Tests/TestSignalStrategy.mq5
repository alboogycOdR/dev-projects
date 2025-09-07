//+------------------------------------------------------------------+
//| TestSignalStrategy - Unit Test for Signal Strategies             |
//+------------------------------------------------------------------+
#include <XAUUSD_EA/Domain/ISignalStrategy.mqh>
#include <XAUUSD_EA/Domain/OBStrategy.mqh>
#include <XAUUSD_EA/Domain/TrendStrategy.mqh>
#include <XAUUSD_EA/Domain/ReversalStrategy.mqh>

void TestOBStrategy()
  {
   OBStrategy ob;
   int signal = ob.GenerateSignal();
   Print("OBStrategy Signal: ", signal);
  }

void TestTrendStrategy()
  {
   TrendStrategy trend;
   int signal = trend.GenerateSignal();
   Print("TrendStrategy Signal: ", signal);
  }

void TestReversalStrategy()
  {
   ReversalStrategy rev;
   int signal = rev.GenerateSignal();
   Print("ReversalStrategy Signal: ", signal);
  }

void OnStart()
  {
   TestOBStrategy();
   TestTrendStrategy();
   TestReversalStrategy();
  } 