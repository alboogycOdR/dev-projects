//+------------------------------------------------------------------+
//| NewsTimeFilter - Domain Layer                                    |
//+------------------------------------------------------------------+
class NewsTimeFilter
  {
public:
   NewsTimeFilter() {}
   bool IsNewsTime() { return false; }
   bool IsAllowedTime() { return true; }
   bool Initialize() { return true; }
   bool IsTradingAllowed() { return true; }
  }; 