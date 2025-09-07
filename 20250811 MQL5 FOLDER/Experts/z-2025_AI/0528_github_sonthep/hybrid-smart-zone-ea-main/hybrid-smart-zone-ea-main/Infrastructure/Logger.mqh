//+------------------------------------------------------------------+
//| Logger - Infrastructure Layer (Interface)                        |
//+------------------------------------------------------------------+
class Logger
  {
public:
   virtual void Log(string message) = 0;
   virtual void LogError(string message) = 0;
  }; 