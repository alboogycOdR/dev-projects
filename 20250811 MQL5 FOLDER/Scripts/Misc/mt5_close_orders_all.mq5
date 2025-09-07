//+------------------------------------------------------------------+
//|                                               close-for-real.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
CTrade trade;
CPositionInfo posObj;



void OnStart()
  {

for(int i=PositionsTotal()-1;i>=0;i--)
{
int ticket = PositionGetTicket(i);
if(posObj.Profit() >0){
trade.PositionClose(ticket);
}
}//end for loop 
}

