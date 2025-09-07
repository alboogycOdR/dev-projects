
#property copyright "© 2013 BEHZAD.HABIBZADEH"
#property link      "behzadhabibzade@gmail.com"

#define major   1
#define minor   0


extern string _tmp1_ = " --- Trade params ---";
extern bool MarketExecution = false;
extern int AccDigits = 5;
extern double Lots = 0.01;
extern int StopLoss = 100;
extern int TakeProfit = 100;
extern int PipsRangeFromLine_min = 10;
extern int PipsRangeFromLine_MAX = 30;
extern int Slippage = 3;
extern int Magic = 20100620;


extern string _tmp2_ = " --- TrendLine params ---";
extern string LongTrendLineDescr = "LTR";
extern string ShortTrendLineDescr = "STR";


extern string _tmp3_ = " --- Chart ---";
extern color clBuy = Blue;
extern color clSell = Red;

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#include <stdlib.mqh>
#include <stderror.mqh>

int RepeatN = 5;

int BuyCnt, SellCnt;
int BuyStopCnt, SellStopCnt;
int BuyLimitCnt, SellLimitCnt;


void init () 
{
}

void deinit() 
{
}

void start()
{
  string obj_name, obj_descr;
  color  obj_color;
  int obj_type;
  
  int total = ObjectsTotal();  
  for (int i=total-1; i >= 0; i--) 
  {
    obj_name = ObjectName(i);
    obj_type = ObjectType(obj_name);
    if (obj_type != OBJ_TREND) continue;
    
    obj_descr = ObjectDescription(obj_name);
    obj_color = ObjectGet(obj_name,OBJPROP_COLOR);

    if ( (obj_descr == LongTrendLineDescr)  && (obj_color == clBuy)  ) LTR(obj_name);
    if ( (obj_descr == ShortTrendLineDescr) && (obj_color == clSell) ) STR(obj_name);
  }
}

void LTR(string obj_name)
{
  double TL1 = ObjectGetValueByShift(obj_name, 1);
  double TL2 = ObjectGetValueByShift(obj_name, 2);
  
  bool BuySig = ( (Close[1] > TL1 && Close[2] <= TL2)
                    && (Close[1]-PipsRangeFromLine_min*Point*fpc() > TL1)
                    && (Close[1]-PipsRangeFromLine_MAX*Point*fpc() < TL1) );

  //-----
  
  RecountOrders();
  
  double price, sl, tp;
  int ticket;
  string comment;

  if (BuySig)
  {
      ObjectSet(obj_name, OBJPROP_COLOR, White);
      ObjectSet(obj_name, OBJPROP_WIDTH, 2);
    //if (BuyCnt > 0) return;
    if (OrdersCountBar0(0, OP_BUY, obj_name) > 0) return;
    
    //-----
    
    if (MarketExecution)
    {
      for (int i=0; i<RepeatN; i++)
      {
        RefreshRates();
        price = Ask;        
        
        comment = "{" + obj_name + "}";

        ticket = Buy(Symbol(), GetLots(), price, 0, 0, Magic, comment);
        if (ticket > 0) break;
      }
  
      for (i=0; i<2*RepeatN; i++)
      {
        if (ticket <= 0) break;
        if (!OrderSelect(ticket, SELECT_BY_TICKET)) break;
    
        sl = If(StopLoss > 0, OrderOpenPrice() - StopLoss*Point*fpc(), 0);
        tp = If(TakeProfit > 0, OrderOpenPrice() + TakeProfit*Point*fpc(), 0);
    
        if (sl > 0 || tp > 0)
        {
          bool res = OrderModify(OrderTicket(), OrderOpenPrice(), sl, tp, 0);
          if (res) break;
        }
      }
    }
    
    else
    {    
      for (i=0; i<RepeatN; i++)
      {
        RefreshRates();
        price = Ask;
  
        sl = If(StopLoss > 0, price - StopLoss*Point*fpc(), 0);
        tp = If(TakeProfit > 0, price + TakeProfit*Point*fpc(), 0);
      
        comment = "{" + obj_name + "}";

        ticket = Buy(Symbol(), GetLots(), price, sl, tp, Magic, comment);
        if (ticket > 0) break;
      }
    }
  }
}

void STR(string obj_name)
{
  double TL1 = ObjectGetValueByShift(obj_name, 1);
  double TL2 = ObjectGetValueByShift(obj_name, 2);
  
  bool SellSig = ( (Close[1] < TL1 && Close[2] >= TL2) 
                    && (Close[1]+PipsRangeFromLine_min*Point*fpc() < TL1)
                    && (Close[1]+PipsRangeFromLine_MAX*Point*fpc() > TL1) );

  //-----
  
  double price, sl, tp;
  int ticket;
  string comment;
  
  RecountOrders();

  if (SellSig)
  {
      ObjectSet(obj_name, OBJPROP_COLOR, White);
      ObjectSet(obj_name, OBJPROP_WIDTH, 2);    
    //if (SellCnt > 0) return;
    if (OrdersCountBar0(0, OP_SELL, obj_name) > 0) return;
    
    //-----
    
    if (MarketExecution)
    {
      for (int i=0; i<RepeatN; i++)
      {
        RefreshRates();
        price = Bid;        
        
        comment = "{" + obj_name + "}";

        ticket = Sell(Symbol(), GetLots(), price, 0, 0, Magic, comment);
        if (ticket > 0) break;
      }
  
      for (i=0; i<2*RepeatN; i++)
      {
        if (ticket <= 0) break;
        if (!OrderSelect(ticket, SELECT_BY_TICKET)) break;
    
        sl = If(StopLoss > 0, OrderOpenPrice() + StopLoss*Point*fpc(), 0);
        tp = If(TakeProfit > 0, OrderOpenPrice() - TakeProfit*Point*fpc(), 0);
    
        if (sl > 0 || tp > 0)
        {
          bool res = OrderModify(OrderTicket(), OrderOpenPrice(), sl, tp, 0);
          if (res) break;
        }
      }
    }
    
    else
    {     
      for (i=0; i<RepeatN; i++)
      {
        RefreshRates();
        price = Bid;
  
        sl = If(StopLoss > 0, price + StopLoss*Point*fpc(), 0);
        tp = If(TakeProfit > 0, price - TakeProfit*Point*fpc(), 0);
      
        comment = "{" + obj_name + "}";

        ticket = Sell(Symbol(), GetLots(), price, sl, tp, Magic, comment);
        if (ticket > 0) break;
      }
    }
  }
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

double If(bool cond, double if_true, double if_false)
{
  if (cond) return (if_true);
  return (if_false);
}

int fpc()
{
  if (AccDigits == 5) return (10);
  if (AccDigits == 6) return (100);
  return (1); 
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


double GetLots() 
{
  return (Lots);
}

void RecountOrders()
{
  BuyCnt = 0;
  SellCnt = 0;
  BuyStopCnt = 0;
  SellStopCnt = 0;
  BuyLimitCnt = 0;
  SellLimitCnt = 0;

  int cnt = OrdersTotal();
  for (int i=0; i < cnt; i++) 
  {
    if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
    if (OrderSymbol() != Symbol()) continue;
    if (OrderMagicNumber() != Magic) continue;
    
    int type = OrderType();
    if (type == OP_BUY) BuyCnt++;
    if (type == OP_SELL) SellCnt++;
    if (type == OP_BUYSTOP) BuyStopCnt++;
    if (type == OP_SELLSTOP) SellStopCnt++;
    if (type == OP_BUYLIMIT) BuyLimitCnt++;
    if (type == OP_SELLLIMIT) SellLimitCnt++;
  }
}

int OrdersCountBar0(int TF, int type, string comment)
{
  int orders = 0;

  int cnt = OrdersTotal();
  for (int i=0; i<cnt; i++) 
  {
    if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
    if (OrderSymbol() != Symbol()) continue;
    if (OrderMagicNumber() != Magic) continue;
    if (OrderType() != type) continue;
    if (StringFind(OrderComment(), comment) == -1) continue;

    if (OrderOpenTime() >= iTime(NULL, TF, 0)) orders++;
  }

  cnt = OrdersHistoryTotal();
  for (i=0; i<cnt; i++) 
  {
    if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
    if (OrderSymbol() != Symbol()) continue;
    if (OrderMagicNumber() != Magic) continue;
    if (OrderType() != type) continue;
    if (StringFind(OrderComment(), comment) == -1) continue;

    if (OrderOpenTime() >= iTime(NULL, TF, 0)) orders++;
  }
 
  return (orders);
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

int SleepOk = 500;
int SleepErr = 2000;

int Buy(string symbol, double lot, double price, double sl, double tp, int magic, string comment="") 
{
  int dig = MarketInfo(symbol, MODE_DIGITS);

  price = NormalizeDouble(price, dig);
  sl = NormalizeDouble(sl, dig);
  tp = NormalizeDouble(tp, dig);
    
  string _lot = DoubleToStr(lot, 2);
  string _price = DoubleToStr(price, dig);
  string _sl = DoubleToStr(sl, dig);
  string _tp = DoubleToStr(tp, dig);

  Print("Buy \"", symbol, "\", ", _lot, ", ", _price, ", ", Slippage, ", ", _sl, ", ", _tp, ", ", magic, ", \"", comment, "\"");

  int res = OrderSend(symbol, OP_BUY, lot, price, Slippage, sl, tp, comment, magic, 0, clBuy);
  if (res >= 0) {
    Sleep(SleepOk);
    return (res);
  } 	
   	
  int code = GetLastError();
  Print("Error opening BUY order: ", ErrorDescription(code), " (", code, ")");
  Sleep(SleepErr);
	
  return (-1);
}

int Sell(string symbol, double lot, double price, double sl, double tp, int magic, string comment="") 
{
  int dig = MarketInfo(symbol, MODE_DIGITS);

  price = NormalizeDouble(price, dig);
  sl = NormalizeDouble(sl, dig);
  tp = NormalizeDouble(tp, dig);
  
  string _lot = DoubleToStr(lot, 2);
  string _price = DoubleToStr(price, dig);
  string _sl = DoubleToStr(sl, dig);
  string _tp = DoubleToStr(tp, dig);

  Print("Sell \"", symbol, "\", ", _lot, ", ", _price, ", ", Slippage, ", ", _sl, ", ", _tp, ", ", magic, ", \"", comment, "\"");
  
  int res = OrderSend(symbol, OP_SELL, lot, price, Slippage, sl, tp, comment, magic, 0, clSell);
  if (res >= 0) {
    Sleep(SleepOk);
    return (res);
  } 	
   	
  int code = GetLastError();
  Print("Error opening SELL order: ", ErrorDescription(code), " (", code, ")");
  Sleep(SleepErr);
	
  return (-1);
}