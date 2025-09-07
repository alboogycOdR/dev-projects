//+---------------------------------------------------------------------+
//|                                               ExpertNewsWatcher.mq5 |
//|                    Copyright © 2013, laplacianlab, Jordi Bassagañas | 
//+---------------------------------------------------------------------+

#property copyright     "Copyright © 2013, laplacianlab. Jordi Bassagañas"
#property link          "http://www.mql5.com/en/articles"
#property version       "1.00"
#property tester_file   "news_watcher.csv"  

#include <..\Experts\NewsWatcher\CNewsWatcher.mqh>

input ENUM_TIMEFRAMES   Period=PERIOD_M1;
input int               StopLoss=400;
input int               TakeProfit=600;
input double            LotSize=0.01;
input string            CsvFile="news_watcher.csv";
 
MqlTick tick;
CNewsWatcher* NW = new CNewsWatcher(StopLoss,TakeProfit,LotSize,CsvFile);

int OnInit(void)
  {
   NW.Init();
   NW.GetTechIndicators().GetMomentum().SetHandler(Symbol(), Period, 13, PRICE_CLOSE);
   return(0);
  }

void OnDeinit(const int reason)
  {
   delete(NW);
  }

void OnTick()
  {
   SymbolInfoTick(_Symbol, tick);              
   NW.GetTechIndicators().GetMomentum().UpdateBuffer(2);
   NW.OnTick(tick.ask,tick.bid);
  }
//+------------------------------------------------------------------+
