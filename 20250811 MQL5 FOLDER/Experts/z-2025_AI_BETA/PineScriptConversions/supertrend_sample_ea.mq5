#include <Trade\Trade.mqh>
CTrade trade;
int handle_supertrend=0;

input group "EA Setting"
input int magic_number=123456; //magic number
input double fixed_lot_size=0.01; // select fixed lot size

enum ENUM_SOURCE{OPEN, CLOSE, HIGH, LOW, HL2, HLC3, OHLC4, HLCC4};
input group "SuperTrend setting"
input int Periods = 10; //ATR Period
input ENUM_SOURCE src = HL2; //Source
input double Multiplier = 3; //ATR Multiplier
input bool changeATR= true; //Change ATR Calculation Method ?
input bool showsignals = false; //Show Buy/Sell Signals ?
input bool highlight = false; //Highlighter On/Off?
input bool enable_alerts=false; //Enable Alerts


int OnInit()
  {
   trade.SetExpertMagicNumber(magic_number);
   handle_supertrend=iCustom(_Symbol, PERIOD_CURRENT, 
      "Market\\Supertrend by KivancOzbilgic",
      Periods, src, Multiplier, changeATR, showsignals, highlight, enable_alerts);
   if(handle_supertrend==INVALID_HANDLE) 
   {
      Print("Indicator not found!");
      return INIT_FAILED;
   }
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   IndicatorRelease(handle_supertrend);
  }

void OnTick()
  {
   if(!isNewBar()) return;
   ///////////////////////////////////////////////////////////////////
   bool buy_condition=true;
   buy_condition &= (BuyCount()==0);
   buy_condition &= (IsSuperTrendBuy(1));
   if(buy_condition) 
   {
      CloseSell();
      Buy();
   }
      
   bool sell_condition=true;
   sell_condition &= (SellCount()==0);
   sell_condition &= (IsSuperTrendSell(1));
   if(sell_condition) 
   {
      CloseBuy();
      Sell();
   }
  }

bool IsSuperTrendBuy(int i)
{
   double array[];
   ArraySetAsSeries(array, true);
   CopyBuffer(handle_supertrend, 8, i, 1, array);
   return array[0]!=EMPTY_VALUE;
}

bool IsSuperTrendSell(int i)
{
   double array[];
   ArraySetAsSeries(array, true);
   CopyBuffer(handle_supertrend, 9, i, 1, array);
   return array[0]!=EMPTY_VALUE;
}

int BuyCount()
{
   int buy=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic_number) continue;
      buy++;
   }  
   return buy;
}

int SellCount()
{
   int sell=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic_number) continue;
      sell++;
   }  
   return sell;
}


void Buy()
{
   double Ask=SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(!trade.Buy(fixed_lot_size, _Symbol, Ask, 0, 0, ""))
   {
      Print("Error executing order: ", GetLastError());
      //ExpertRemove();
   }
}

void Sell()
{
   double Bid=SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(!trade.Sell(fixed_lot_size, _Symbol, Bid, 0, 0, ""))
   {
      Print("Error executing order: ", GetLastError());
      //ExpertRemove();
   }
}


void CloseBuy()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic_number) continue;
      if(trade.PositionClose(ticket)==false)
      {
         Print("Error closing position: ", GetLastError());
         //ExpertRemove();
      }
   }  
}

void CloseSell()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic_number) continue;
      if(trade.PositionClose(ticket)==false)
      {
         Print("Error closing position: ", GetLastError());
         //ExpertRemove();
      }
   }  
}

datetime timer=NULL;
bool isNewBar()
{
   datetime candle_start_time= (int)(TimeCurrent()/(PeriodSeconds()))*PeriodSeconds();
   if(timer==NULL) {}
   else if(timer==candle_start_time) return false;
   timer=candle_start_time;
   return true;
}