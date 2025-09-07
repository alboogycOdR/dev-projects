//+------------------------------------------------------------------+
//| ConsoleLogger - Infrastructure Layer                             |
//+------------------------------------------------------------------+
#include <XAUUSD_EA/Infrastructure/Logger.mqh>

class ConsoleLogger : public Logger
  {
public:
   ConsoleLogger();
   void Log(string message);
   void LogError(string message);
  }; 