//+------------------------------------------------------------------+
//|                                          CheckSymbolName_All.mq5 |
//|                        Copyright 2010, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2010, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"

int pairscount=0;
string Pairs[100];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   string crtsymbol;

   for(int i=0;i<SymbolsTotal(false);i++)
     {
      crtsymbol=SymbolName(i,false);
      Print("Symbol ",i," is ",crtsymbol);
      if(SymbolInfoInteger(crtsymbol,SYMBOL_TRADE_CALC_MODE)==SYMBOL_CALC_MODE_FOREX && StringLen(crtsymbol)>=6)
        {
         Pairs[pairscount]=crtsymbol;
         pairscount++;
        }
     }

   Print("Pairs array:");
   for(int i=0;i<pairscount;i++)
      Print(Pairs[i]);
   Print("finished OnInit");
   return(0);

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
void OnTick()
  {
   for(int i=0;i<pairscount;i++)
     {
      SymbolSelect(Pairs[i],true);
      Print("Tickvalue of ",Pairs[i]," is ",SymbolInfoDouble(Pairs[i],SYMBOL_TRADE_TICK_VALUE));
     }

  }
//+------------------------------------------------------------------+
