//+------------------------------------------------------------------+
//|                                            GoldenRatioEA.mq5     |
//|                          Written for MetaTrader 5                  |
//|   EA with buy/sell signals and Golden Ratio based SL/TP levels    |
//+------------------------------------------------------------------+
#property copyright "Code Copilot"
#property link      "https://1lm.me/cc"
#property version   "1.00"
#include <Trade/Trade.mqh>
CTrade trade;

// Expert Parameters
 int Periods[] = {8, 13, 21, 34, 55};  // Periods
input double InitialLotSize = 0.1;          // Initial Lot Size
input double LotIncreaseRate = 0.1;         // Increase Rate (10%)
input int IncreaseAfterTrades = 5;          // Increase lot after X trades
input double Slippage = 3;                  // Slippage
input double StopLossMultiplier = 0.618;    // Stop Loss Multiplier
input double TakeProfitMultiplier = 1.618;  // Take Profit Multiplier

// Trade Counter
int TotalTrades = 0; // Total number of trades
double CurrentLotSize = 0.0;

// Add this at the beginning of the file, after the input parameters
 

//+------------------------------------------------------------------+
//| Lot Size Update Function                                           |
//+------------------------------------------------------------------+
void UpdateLotSize()
  {
   // If number of trades reaches increase condition
   if(TotalTrades > 0 && TotalTrades % IncreaseAfterTrades == 0)
     {
      CurrentLotSize *= (1.0 + LotIncreaseRate); // Increase lot size by LotIncreaseRate
      PrintFormat("Lot size increased to %.2f after %d trades", CurrentLotSize, TotalTrades);
     }
  }

//+------------------------------------------------------------------+
//| Fibonacci Levels Calculation Function                              |
//+------------------------------------------------------------------+
void CalculateFibonacciLevels(double &golden, double &inverse_golden, double &extension, double &stop_loss, double &take_profit)
  {
   double max_price = iHigh(NULL,PERIOD_CURRENT, 1);
   double min_price = iLow(NULL, PERIOD_CURRENT, 1);
   double range = max_price - min_price;

   golden = max_price - range * 0.618;                    // 0.618 retracement level
   inverse_golden = min_price + range * 1.618;            // 1.618 extension level
   extension = (max_price + min_price) / 2 + range * 1.618; // Additional extension
   stop_loss = range * StopLossMultiplier;                // Stop loss
   take_profit = range * TakeProfitMultiplier;            // Take profit
  }

//+------------------------------------------------------------------+
//| Check if there are any open positions                              |
//+------------------------------------------------------------------+
bool HasOpenPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol == _Symbol) return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Buy/Sell Signals Check Function                                    |
//+------------------------------------------------------------------+
void CheckForSignals()
  {
   // First check if there's already an open position
   if(HasOpenPosition()) return;  // Exit if there's an open position

   //for(int i = 0; i < ArraySize(Periods); i++)
    // {
      //int period = Periods[i];
      //if(Bars(NULL,PERIOD_CURRENT) < period) continue;

      double golden, inverse_golden, extension, stop_loss, take_profit;
      CalculateFibonacciLevels( golden, inverse_golden, extension, stop_loss, take_profit);

      // Buy signal check
      if(iClose(NULL,PERIOD_CURRENT,1) <= inverse_golden && iClose(NULL,PERIOD_CURRENT,0) > inverse_golden)
        {
          // Delete existing horizontal lines
         ObjectsDeleteAll(0,0, OBJ_HLINE);

         // Draw new horizontal line at golden level
         ObjectCreate(0, "Golden_Level", OBJ_HLINE, 0, 0, inverse_golden);
         ObjectSetInteger(0, "Golden_Level", OBJPROP_COLOR, clrBlue);
         ObjectSetInteger(0, "Golden_Level", OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, "Golden_Level", OBJPROP_STYLE, STYLE_SOLID);

         
         OpenBuy( NULL/*stop_loss*/, NULL/*take_profit*/);
         return;  // Exit after opening a position
        }

      // Sell signal check
      if(iClose(NULL,PERIOD_CURRENT,1) >= golden && iClose(NULL,PERIOD_CURRENT,0) < golden)
        {
         // Delete existing horizontal lines
         ObjectsDeleteAll(0,0, OBJ_HLINE);
         
         // Draw new horizontal line at golden level
         ObjectCreate(0, "Golden_Level", OBJ_HLINE, 0, 0, golden);
         ObjectSetInteger(0, "Golden_Level", OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, "Golden_Level", OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, "Golden_Level", OBJPROP_STYLE, STYLE_SOLID);
         
         OpenSell(NULL/*stop_loss*/, NULL/*take_profit*/);
         return;  // Exit after opening a position
        }
    // }
  }

//+------------------------------------------------------------------+
//| Open Buy Position Function                                         |
//+------------------------------------------------------------------+
void OpenBuy( double stop_loss, double take_profit)
  {
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = price - stop_loss;
   double tp = price + 120*Point();

   trade.SetDeviationInPoints(Slippage);
   if(trade.Buy(CurrentLotSize, _Symbol, price, NULL, tp, "GoldenRatioEA Buy"))
     {
      TotalTrades++;
      //UpdateLotSize();
     }
   else
      Print("Error opening buy position: ", GetLastError());
  }

//+------------------------------------------------------------------+
//| Open Sell Position Function                                        |
//+------------------------------------------------------------------+
void OpenSell(double stop_loss, double take_profit)
  {
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = price + stop_loss;
   double tp = price -  120*Point();

   trade.SetDeviationInPoints(Slippage);
   if(trade.Sell(CurrentLotSize, _Symbol, price, NULL, tp, "GoldenRatioEA Sell"))
     {
      TotalTrades++;
      //UpdateLotSize();
     }
   else
      Print("Error opening sell position: ", GetLastError());
  }

//+------------------------------------------------------------------+
//| Open Positions Management Function                                 |
//+------------------------------------------------------------------+
void ManageOpenPositions()
  {
   return;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != _Symbol) continue;

      double stop_loss = PositionGetDouble(POSITION_SL);
      double take_profit = PositionGetDouble(POSITION_TP);
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      // بررسی حد سود و ضرر
      if((current_price >= take_profit) || (current_price <= stop_loss))
        trade.PositionClose(ticket);
     }
  }
bool NewBar()
  {
   datetime currentTime = iTime(Symbol(), PERIOD_CURRENT, 0);

   static datetime previousTime= 0 ;//sèt to currentrime to avoid processing on current bar on start
   if(currentTime == previousTime)
      return (false);
   previousTime =currentTime;
   return (true);
  }
//+------------------------------------------------------------------+
//| تابع اصلی اکسپرت                                                 |
//+------------------------------------------------------------------+
int OnInit()
  {
   CurrentLotSize = InitialLotSize; // تنظیم حجم اولیه معاملات
   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
     if(!NewBar()) {
      return;
   }
   
   CheckForSignals();       // بررسی سیگنال‌های جدید
   ManageOpenPositions();   // مدیریت معاملات باز

  }
//+------------------------------------------------------------------+
