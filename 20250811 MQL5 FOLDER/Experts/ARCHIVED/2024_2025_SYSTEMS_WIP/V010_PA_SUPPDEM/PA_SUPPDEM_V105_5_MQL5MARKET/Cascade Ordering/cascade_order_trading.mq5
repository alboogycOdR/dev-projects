//+------------------------------------------------------------------+
//|                                             CASCADE ORDERING.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//https://www.mql5.com/en/articles/15250
#include <Trade\Trade.mqh>
CTrade trade;

int handleMAFast;
int handleMASlow;
double maSlow[],maFast[];

double takeProfit = 0;
double stopLoss = 0;
bool isBuySystemInitiated = false;
bool isSellSystemInitiated = false;

input int slPts = 300;
input int tpPts = 300;
input double lot = 0.01;
input int slPts_Min = 100;
input int fastPeriods = 10;
input int slowPeriods = 20;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   
   handleMAFast = iMA(_Symbol,_Period,fastPeriods,0,MODE_EMA,PRICE_CLOSE);
   if (handleMAFast == INVALID_HANDLE){
      Print("UNABLE TO LOAD FAST MA, REVERTING NOW");
      return (INIT_FAILED);
   }
   
   handleMASlow = iMA(_Symbol,_Period,slowPeriods,0,MODE_EMA,PRICE_CLOSE);
   if (handleMASlow == INVALID_HANDLE){
      Print("UNABLE TO LOAD SLOW MA, REVERTING NOW");
      return (INIT_FAILED);
   }
   
   ArraySetAsSeries(maFast,true);
   ArraySetAsSeries(maSlow,true);
   
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
   
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
   
   if (CopyBuffer(handleMAFast,0,1,3,maFast) < 3){
      Print("NO ENOUGH DATA FROM FAST MA FOR ANALYSIS, REVERTING NOW");
      return;
   }
   if (CopyBuffer(handleMASlow,0,1,3,maSlow) < 3){
      Print("NO ENOUGH DATA FROM SLOW MA FOR ANALYSIS, REVERTING NOW");
      return;
   }
   
   //if (IsNewBar()){Print("FAST MA DATA:");ArrayPrint(maFast,6);}
   
   if (PositionsTotal()==0){
      isBuySystemInitiated=false;isSellSystemInitiated=false;
   }
   
   if (PositionsTotal()==0 && IsNewBar()){
      if (maFast[0] > maSlow[0] && maFast[1] < maSlow[1]){
         Print("BUY SIGNAL");
         takeProfit = Ask+tpPts*_Point;
         stopLoss = Ask-slPts*_Point;
         trade.Buy(lot,_Symbol,Ask,stopLoss,0);
         isBuySystemInitiated = true;
      }
      else if (maFast[0] < maSlow[0] && maFast[1] > maSlow[1]){
         Print("SELL SIGNAL");
         takeProfit = Bid-tpPts*_Point;
         stopLoss = Bid+slPts*_Point;
         trade.Sell(lot,_Symbol,Bid,stopLoss,0);
         isSellSystemInitiated = true;
      }
   }
   
   else {
      if (isBuySystemInitiated && Ask >= takeProfit){
         takeProfit = takeProfit+tpPts*_Point;
         stopLoss = Ask-slPts_Min*_Point;
         trade.Buy(lot,_Symbol,Ask,0);
         ModifyTrades(POSITION_TYPE_BUY,stopLoss);
      }
      else if (isSellSystemInitiated && Bid <= takeProfit){
         takeProfit = takeProfit-tpPts*_Point;
         stopLoss = Bid+slPts_Min*_Point;
         trade.Sell(lot,_Symbol,Bid,0);
         ModifyTrades(POSITION_TYPE_SELL,stopLoss);
      }
   }
}
//+------------------------------------------------------------------+

bool IsNewBar(){
   static int prevBars = 0;
   int currBars = iBars(_Symbol,_Period);
   if (prevBars==currBars) return (false);
   prevBars = currBars;
   return (true);
}

void ModifyTrades(ENUM_POSITION_TYPE posType, double sl){
   for (int i=0; i<=PositionsTotal(); i++){
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0){
         if (PositionSelectByTicket(ticket)){
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if (type==posType){
               trade.PositionModify(ticket,sl,0);
            }
         }
      }
   }
}