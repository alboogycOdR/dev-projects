//+------------------------------------------------------------------+
//|                                                    trendy_ea.mq5 |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                               drenjanind@mail.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "drenjanind@mail.ru"
#property version   "1.00"
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
CPositionInfo    _pos;
CTrade         _trade;
CSymbolInfo   _symbol;
double Lot        = 0.1;
input int    StopLoss    = 100000;
input int    TakeProfit  = 50000;
ulong MagicNumber  = 5050;
ulong Slippage     = 30;
double SL;
double TP;
int indi; 
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  if (!_symbol.Name(Symbol()))
    return(INIT_FAILED);
  
  RefreshRates();

  _trade.SetExpertMagicNumber(MagicNumber);
  if (IsFillingTypeAllowed(SYMBOL_FILLING_FOK))
      _trade.SetTypeFilling(ORDER_FILLING_FOK);
  else if (IsFillingTypeAllowed(SYMBOL_FILLING_IOC))
      _trade.SetTypeFilling(ORDER_FILLING_IOC);
  else _trade.SetTypeFilling(ORDER_FILLING_RETURN);

  _trade.SetDeviationInPoints(Slippage);

  if (_symbol.Digits() == 3 || _symbol.Digits() == 5){
     SL = StopLoss *10;
     TP = TakeProfit *10;
  }
  else{
    SL = StopLoss;
    TP = TakeProfit;
  }

  indi =iCustom(_symbol.Name(), Period(), "custom_trend_indicator");
  if (indi == INVALID_HANDLE){
    Print("indi create failed");
    return(INIT_FAILED);
    }
  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  static datetime last_time = 0;
  datetime current_time = iTime(_symbol.Name(), _Period, 0);
  
  if (current_time == last_time)
  return;
  
  if (!RefreshRates()){
      last_time =0;
      return;
  }
  last_time = current_time;
  int buffer_size = 30; 
  double  buffer_open[];
  double  buffer_high[];
  double   buffer_low[];
  double buffer_close[];
  
  if (CopyBuffer(indi, LOWER_LINE, 0, buffer_size, buffer_open) != buffer_size || ArraySize(buffer_open) != buffer_size){
      last_time =0;
      return;
  }
  
  if (CopyBuffer(indi, UPPER_LINE, 0, buffer_size, buffer_high) != buffer_size || ArraySize(buffer_high) != buffer_size){
      last_time =0;
      return;
  }
  if (CopyBuffer(indi, LOWER_LINE, 0, buffer_size, buffer_low) != buffer_size || ArraySize(buffer_low) != buffer_size){
      last_time =0;
      return;
  }
  if (CopyBuffer(indi, LOWER_LINE, 0, buffer_size, buffer_close) != buffer_size || ArraySize(buffer_close) != buffer_size){
      last_time =0;
      return;
  }
  
  ArraySetAsSeries(buffer_open , true);
  ArraySetAsSeries(buffer_high , true);
  ArraySetAsSeries(buffer_low , true);
  ArraySetAsSeries(buffer_close , true);

  double current_open = EMPTY_VALUE;
  double current_high = EMPTY_VALUE;
  double current_low  = EMPTY_VALUE;
  double current_close  = EMPTY_VALUE;

  double last_open = EMPTY_VALUE;
  double last_high = EMPTY_VALUE;
  double last_low  = EMPTY_VALUE;
  double last_close  = EMPTY_VALUE;

  for (int i =1; i< buffer_size; i++){
      if (buffer_open[i] != EMPTY_VALUE && buffer_open[i] != 0){
          if (last_open == EMPTY_VALUE){
              last_open = buffer_open[i];
          continue;
          }
      } 
  if (buffer_high[i] != EMPTY_VALUE && buffer_high[i] != 0){
      if (last_high == EMPTY_VALUE){
          last_high = buffer_high[i];
          continue;
      }
  }
  if (buffer_low[i] != EMPTY_VALUE && buffer_low[i] != 0){
      if (last_low == EMPTY_VALUE){
          last_open = buffer_open[i];
          continue;
      }
  }
  if (current_close == EMPTY_VALUE){
      current_close = buffer_close[i];
      break;
  }
  }

  for (int i =1; i< buffer_size; i++){
      if (buffer_high[i] != EMPTY_VALUE && buffer_high[i] != 0){
          if (last_high == EMPTY_VALUE){
          last_high = buffer_high[i];
          continue;
          }
  if (current_high == EMPTY_VALUE){
      current_high = buffer_high[i];
      break;
  }
  }
  }  

  if (last_low != EMPTY_VALUE && current_low != EMPTY_VALUE){
      if (current_low < last_low){
          CloseTrade(POSITION_TYPE_SELL);
          if (PosCount(POSITION_TYPE_BUY) == 0){
              double sl = _symbol.Ask() - SL * _Point;
              double tp = _symbol.Ask() + TP * _Point;
              OpenBuy(sl, tp);
          }
      }
  }

  if (last_high != EMPTY_VALUE && current_high != EMPTY_VALUE){
      if (current_high < last_high){
          CloseTrade(POSITION_TYPE_BUY);
          if (PosCount(POSITION_TYPE_SELL) == 0){
              double sl = _symbol.Ask() + SL * _Point;
              double tp = _symbol.Ask() - TP * _Point;
              OpenSell(sl, tp);
          }
      }
  }
}
//+------------------------------------------------------------------+
bool IsFillingTypeAllowed(int fill_type)
{
  int filling = _symbol.TradeFillFlags();
  return((filling && fill_type) == fill_type);
}
//+------------------------------------------------------------------+
int PosCount (ENUM_POSITION_TYPE position_type)
{
  int count =0;

  for (int i = PositionsTotal()-1; i>0; i--){
      if (_pos.SelectByIndex(i) &&
        _pos.Symbol() == _symbol.Name() &&
        _pos.Magic() == MagicNumber &&
        _pos.PositionType() == position_type )
        count ++;
  }
  return(count);
}
//+------------------------------------------------------------------+
void CloseTrade(ENUM_POSITION_TYPE  position_type)
{
  for (int i = PositionsTotal() -1; i>=0; i--){
        if (_pos.SelectByIndex(i)          &&
          _pos.Symbol() == _symbol.Name() &&
          _pos.Magic() == MagicNumber     &&
          _pos.PositionType() == position_type )
        _trade.PositionClose(_pos.Ticket());
  }
}
//+------------------------------------------------------------------+
bool RefreshRates()
{
  if (!_symbol.RefreshRates()){
    Print("quote update failed");
    return(false);
  }

  if (_symbol.Ask() == 0 || _symbol.Bid() == 0){
      return(false);
  }
  return(true);
}
//+------------------------------------------------------------------+
void OpenBuy(double sl, double tp)
{
  sl = _symbol.NormalizePrice(sl);
  tp = _symbol.NormalizePrice(tp);
  
  if (_trade.Buy(Lot, _symbol.Name(), _symbol.Ask(), sl, tp)){
      if (_trade.ResultDeal() == 0){
          Print("failed to open buy order");
      }
  }
  else{
        Print("failed to open buy order");
  }
}
//+------------------------------------------------------------------+
void OpenSell(double sl, double tp)
{
  sl = _symbol.NormalizePrice(sl);
  tp = _symbol.NormalizePrice(tp);
  
  if (_trade.Sell(Lot, _symbol.Name(), _symbol.Bid(), sl, tp)){
      if (_trade.ResultDeal() == 0){
          Print("failed to open sell order");
      }
  }
  else{
        Print("failed to open sell order");
  }
}
//+------------------------------------------------------------------+