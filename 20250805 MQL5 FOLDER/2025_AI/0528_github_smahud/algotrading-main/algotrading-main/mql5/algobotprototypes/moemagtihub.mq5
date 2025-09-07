//+------------------------------------------------------------------+
//|                                                      CEZLSMA.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.6"
#property description "A Strategy Using Chandelier Exit and ZLSMA Indicators Based on the Heikin Ashi Candles"
#property description "AUDUSD-15M  2019.01.01 - 2023.08.01"

// Enumerations
enum ENUM_RISK {
   RISK_DEFAULT,     // Default
   RISK_FIXED_VOL,   // Fixed Volume
   RISK_MIN_AMOUNT   // Minimum Amount
};

enum ENUM_NEWS_IMPORTANCE {
   NEWS_IMPORTANCE_LOW,    // Low
   NEWS_IMPORTANCE_MEDIUM, // Medium
   NEWS_IMPORTANCE_HIGH    // High
};

enum ENUM_FILLING {
   FILLING_DEFAULT,   // Default
   FILLING_FOK,       // Fill or Kill
   FILLING_IOC,       // Immediate or Cancel
   FILLING_RETURN     // Return
};

// Inputs
input group "Indicator Parameters"
input int CeAtrPeriod = 1; // CE ATR Period
input double CeAtrMult = 0.75; // CE ATR Multiplier
input int ZlPeriod = 50; // ZLSMA Period

input group "General"
input int SLDev = 650; // SL Deviation (Points)
input bool CloseOrders = true; // Check For Closing Conditions
input bool Reverse = false; // Reverse Signal

input group "Risk Management"
input double Risk = 3; // Risk
input ENUM_RISK RiskMode = RISK_DEFAULT; // Risk Mode
input bool IgnoreSL = true; // Ignore SL
input bool Trail = true; // Trailing Stop
input double TrailingStopLevel = 50; // Trailing Stop Level (%) (0: Disable)
input double EquityDrawdownLimit = 0; // Equity Drawdown Limit (%) (0: Disable)

input group "Strategy: Grid"
input bool Grid = true; // Grid Enable
input double GridVolMult = 1.5; // Grid Volume Multiplier
input double GridTrailingStopLevel = 0; // Grid Trailing Stop Level (%) (0: Disable)
input int GridMaxLvl = 50; // Grid Max Levels

input group "News"
input bool News = false; // News Enable
input ENUM_NEWS_IMPORTANCE NewsImportance = NEWS_IMPORTANCE_MEDIUM; // News Importance
input int NewsMinsBefore = 60; // News Minutes Before
input int NewsMinsAfter = 60; // News Minutes After
input int NewsStartYear = 0; // News Start Year to Fetch for Backtesting (0: Disable)

input group "Open Position Limit"
input bool OpenNewPos = true; // Allow Opening New Position
input bool MultipleOpenPos = false; // Allow Having Multiple Open Positions
input double MarginLimit = 300; // Margin Limit (%) (0: Disable)
input int SpreadLimit = -1; // Spread Limit (Points) (-1: Disable)

input group "Auxiliary"
input int Slippage = 30; // Slippage (Points)
input int TimerInterval = 30; // Timer Interval (Seconds)
input ulong MagicNumber = 2000; // Magic Number
input ENUM_FILLING Filling = FILLING_DEFAULT; // Order Filling

// Define GerEA class
class GerEA {
private:
   ulong magic;
   
public:
   double risk;
   bool reverse;
   double trailingStopLevel;
   bool grid;
   double gridVolMult;
   double gridTrailingStopLevel;
   int gridMaxLvl;
   double equityDrawdownLimit;
   int slippage;
   bool news;
   ENUM_NEWS_IMPORTANCE newsImportance;
   int newsMinsBefore;
   int newsMinsAfter;
   ENUM_FILLING filling;
   ENUM_RISK riskMode;
   
   // Constructor
   GerEA() {
      magic = 0;
      risk = 0.01;
      reverse = false;
      trailingStopLevel = 0;
      grid = false;
      gridVolMult = 1.0;
      gridTrailingStopLevel = 0;
      gridMaxLvl = 10;
      equityDrawdownLimit = 0;
      slippage = 10;
      news = false;
      newsImportance = NEWS_IMPORTANCE_MEDIUM;
      newsMinsBefore = 60;
      newsMinsAfter = 60;
      filling = FILLING_DEFAULT;
      riskMode = RISK_DEFAULT;
   }
   
   // Methods
   void Init() {
      // Initialize EA
   }
   
   void SetMagic(ulong mgc) {
      magic = mgc;
   }
   
   ulong GetMagic() {
      return magic;
   }
   
   int OPTotal() {
      int count = 0;
      for(int i = 0; i < PositionsTotal(); i++) {
         if(PositionGetTicket(i) > 0) {
            if(PositionGetInteger(POSITION_MAGIC) == magic) {
               count++;
            }
         }
      }
      return count;
   }
   
   void BuyOpen(double price, double sl, double tp, bool ignoreSL, bool checkNews) {
      // Open buy position logic
      double volume = CalculateVolume();
      if(volume <= 0) return;
      
      if(checkNews && news && IsNewsTime()) return;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_DEAL;
      request.symbol = _Symbol;
      request.volume = volume;
      request.type = ORDER_TYPE_BUY;
      request.price = price;
      request.deviation = slippage;
      request.magic = magic;
      
      if(!ignoreSL && sl > 0) request.sl = sl;
      if(tp > 0) request.tp = tp;
      
      OrderSend(request, result);
   }
   
   void SellOpen(double price, double sl, double tp, bool ignoreSL, bool checkNews) {
      // Open sell position logic
      double volume = CalculateVolume();
      if(volume <= 0) return;
      
      if(checkNews && news && IsNewsTime()) return;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_DEAL;
      request.symbol = _Symbol;
      request.volume = volume;
      request.type = ORDER_TYPE_SELL;
      request.price = price;
      request.deviation = slippage;
      request.magic = magic;
      
      if(!ignoreSL && sl > 0) request.sl = sl;
      if(tp > 0) request.tp = tp;
      
      OrderSend(request, result);
   }
   
   void BuyClose() {
      // Close buy positions
      for(int i = 0; i < PositionsTotal(); i++) {
         if(PositionGetTicket(i) > 0) {
            if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               MqlTradeRequest request = {};
               MqlTradeResult result = {};
               
               request.action = TRADE_ACTION_DEAL;
               request.symbol = _Symbol;
               request.volume = PositionGetDouble(POSITION_VOLUME);
               request.type = ORDER_TYPE_SELL;
               request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               request.deviation = slippage;
               request.magic = magic;
               request.position = PositionGetInteger(POSITION_TICKET);
               
               OrderSend(request, result);
            }
         }
      }
   }
   
   void SellClose() {
      // Close sell positions
      for(int i = 0; i < PositionsTotal(); i++) {
         if(PositionGetTicket(i) > 0) {
            if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
               MqlTradeRequest request = {};
               MqlTradeResult result = {};
               
               request.action = TRADE_ACTION_DEAL;
               request.symbol = _Symbol;
               request.volume = PositionGetDouble(POSITION_VOLUME);
               request.type = ORDER_TYPE_BUY;
               request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               request.deviation = slippage;
               request.magic = magic;
               request.position = PositionGetInteger(POSITION_TICKET);
               
               OrderSend(request, result);
            }
         }
      }
   }
   
   void CheckForTrail() {
      // Trailing stop logic
      if(trailingStopLevel <= 0) return;
      
      for(int i = 0; i < PositionsTotal(); i++) {
         if(PositionGetTicket(i) > 0) {
            if(PositionGetInteger(POSITION_MAGIC) == magic) {
               double currentSL = PositionGetDouble(POSITION_SL);
               double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               double currentPrice;
               double newSL;
               
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                  currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  double distance = (currentPrice - openPrice) * trailingStopLevel;
                  newSL = currentPrice - distance;
                  
                  if(newSL > currentSL) {
                     ModifySL(PositionGetInteger(POSITION_TICKET), newSL);
                  }
               }
               else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
                  currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  double distance = (openPrice - currentPrice) * trailingStopLevel;
                  newSL = currentPrice + distance;
                  
                  if(newSL < currentSL || currentSL == 0) {
                     ModifySL(PositionGetInteger(POSITION_TICKET), newSL);
                  }
               }
            }
         }
      }
   }
   
   void CheckForEquity() {
      // Equity drawdown check
      if(equityDrawdownLimit <= 0) return;
      
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double drawdown = 1 - equity / balance;
      
      if(drawdown >= equityDrawdownLimit) {
         CloseAll();
      }
   }
   
   void CheckForGrid() {
      // Grid trading logic
      if(!grid) return;
      
      // Implementation of grid trading strategy
   }
   
   bool IsNewsTime() {
      // Check if it's news time
      return false; // Placeholder
   }
   
   void CloseAll() {
      // Close all positions
      BuyClose();
      SellClose();
   }
   
   void ModifySL(ulong ticket, double sl) {
      // Modify stop loss
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_SLTP;
      request.symbol = _Symbol;
      request.sl = sl;
      request.position = ticket;
      
      OrderSend(request, result);
   }
   
   double CalculateVolume() {
      // Calculate position volume based on risk settings
      double volume = 0.01; // Default minimum volume
      
      // Implement different risk calculation methods
      if(riskMode == RISK_DEFAULT) {
         // Calculate based on percentage of balance
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         double riskAmount = balance * risk;
         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         double pointValue = tickValue / tickSize;
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         
         // Calculate volume based on SL points
         volume = NormalizeDouble(riskAmount / (SLDev * _Point * pointValue), 2);
         if(volume < minLot) volume = minLot;
      }
      else if(riskMode == RISK_FIXED_VOL) {
         volume = risk;
      }
      else if(riskMode == RISK_MIN_AMOUNT) {
         // Implement minimum amount risk calculation
      }
      
      return volume;
   }
};

// Global variables
int BuffSize = 4;
GerEA ea;
datetime lastCandle;
datetime tc;

// Helper functions
double Ask() {
   return SymbolInfoDouble(_Symbol, SYMBOL_ASK);
}

double Bid() {
   return SymbolInfoDouble(_Symbol, SYMBOL_BID);
}

double Spread() {
   return (Ask() - Bid()) / _Point;
}

double getProfit(ulong magic) {
   double profit = 0;
   for(int i = 0; i < PositionsTotal(); i++) {
      if(PositionGetTicket(i) > 0) {
         if(PositionGetInteger(POSITION_MAGIC) == magic) {
            profit += PositionGetDouble(POSITION_PROFIT);
         }
      }
   }
   return profit;
}

double calcCost(ulong magic) {
   double cost = 0;
   for(int i = 0; i < PositionsTotal(); i++) {
      if(PositionGetTicket(i) > 0) {
         if(PositionGetInteger(POSITION_MAGIC) == magic) {
            cost += PositionGetDouble(POSITION_COMMISSION) + PositionGetDouble(POSITION_SWAP);
         }
      }
   }
   return cost;
}

void fetchCalendarFromYear(int year) {
   // Implementation for fetching economic calendar data
}

// Indicator handles
int HA_handle;
double HA_C[];

int CE_handle;
double CE_B[], CE_S[];

int ZL_handle;
double ZL[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal() {
    bool c = CE_B[1] != 0 && HA_C[1] > ZL[1];
    if (!c) return false;

    double in = Ask();
    double sl = CE_B[1] - SLDev * _Point;
    double tp = 0;
    ea.BuyOpen(in, sl, tp, IgnoreSL, true);
    return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal() {
    bool c = CE_S[1] != 0 && HA_C[1] < ZL[1];
    if (!c) return false;

    double in = Bid();
    double sl = CE_S[1] + SLDev * _Point;
    double tp = 0;
    ea.SellOpen(in, sl, tp, IgnoreSL, true);
    return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckClose() {
    double p = getProfit(ea.GetMagic()) - calcCost(ea.GetMagic());
    if (p < 0) return;

    if (HA_C[2] >= ZL[2] && HA_C[1] < ZL[1])
        ea.BuyClose();

    if (HA_C[2] <= ZL[2] && HA_C[1] > ZL[1])
        ea.SellClose();
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    ea.Init();
    ea.SetMagic(MagicNumber);
    ea.risk = Risk * 0.01;
    ea.reverse = Reverse;
    ea.trailingStopLevel = TrailingStopLevel * 0.01;
    ea.grid = Grid;
    ea.gridVolMult = GridVolMult;
    ea.gridTrailingStopLevel = GridTrailingStopLevel * 0.01;
    ea.gridMaxLvl = GridMaxLvl;
    ea.equityDrawdownLimit = EquityDrawdownLimit * 0.01;
    ea.slippage = Slippage;
    ea.news = News;
    ea.newsImportance = NewsImportance;
    ea.newsMinsBefore = NewsMinsBefore;
    ea.newsMinsAfter = NewsMinsAfter;
    ea.filling = Filling;
    ea.riskMode = RiskMode;

    if (RiskMode == RISK_FIXED_VOL || RiskMode == RISK_MIN_AMOUNT) ea.risk = Risk;
    if (News) fetchCalendarFromYear(NewsStartYear);

    // Initialize indicator handles
    HA_handle = iCustom(_Symbol, PERIOD_CURRENT, "Examples\\Heiken_Ashi");
    CE_handle = iCustom(_Symbol, PERIOD_CURRENT, "ChandelierExit", CeAtrPeriod, CeAtrMult);
    ZL_handle = iCustom(_Symbol, PERIOD_CURRENT, "ZLSMA", ZlPeriod, true);

    if (HA_handle == INVALID_HANDLE || CE_handle == INVALID_HANDLE || ZL_handle == INVALID_HANDLE) {
        Print("Runtime error = ", GetLastError());
        return(INIT_FAILED);
    }

    EventSetTimer(TimerInterval);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
    datetime oldTc = tc;
    tc = TimeCurrent();
    if (tc == oldTc) return;

    if (Trail) ea.CheckForTrail();
    if (EquityDrawdownLimit) ea.CheckForEquity();
    if (Grid) ea.CheckForGrid();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    if (lastCandle != iTime(_Symbol, PERIOD_CURRENT, 0)) {
        lastCandle = iTime(_Symbol, PERIOD_CURRENT, 0);

        if (CopyBuffer(HA_handle, 3, 0, BuffSize, HA_C) <= 0) return;
        ArraySetAsSeries(HA_C, true);

        if (CopyBuffer(CE_handle, 0, 0, BuffSize, CE_B) <= 0) return;
        if (CopyBuffer(CE_handle, 1, 0, BuffSize, CE_S) <= 0) return;
        ArraySetAsSeries(CE_B, true);
        ArraySetAsSeries(CE_S, true);

        if (CopyBuffer(ZL_handle, 0, 0, BuffSize, ZL) <= 0) return;
        ArraySetAsSeries(ZL, true);

        if (CloseOrders) CheckClose();

        if (!OpenNewPos) return;
        if (SpreadLimit != -1 && Spread() > SpreadLimit) return;
        if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) return;
        if ((Grid || !MultipleOpenPos) && ea.OPTotal() > 0) return;

        if (BuySignal()) return;
        SellSignal();
    }
}

//+------------------------------------------------------------------+