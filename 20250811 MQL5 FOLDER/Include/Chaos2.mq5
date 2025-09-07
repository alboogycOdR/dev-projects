//+------------------------------------------------------------------+
//|                                                       Chaos2.mq5 |
//|     Copyright 2014, Vasiliy Sokolov specially for HedgeTerminal. |
//|                                          St.-Petersburg, Russia. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Vasiliy Sokolov."
#property link      "https://login.mql5.com/ru/users/c-4"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Include files                                                |
//+------------------------------------------------------------------+
#include <Prototypes.mqh>           // Include prototypes function of HedgeTerminalAPI library.

//+------------------------------------------------------------------+
//| Input parameters.                                                |
//+------------------------------------------------------------------+
input uint N=2;                     // Period of extermum/minimum
input uint OldPending=3;            // Old pending

//+------------------------------------------------------------------+
//| Private variables of expert advisor.                             |
//+------------------------------------------------------------------+
ulong Magic = 2314;                 // Magic number of expert.
datetime lastTime = 0;              // Remembered last time for function DetectNewBar.
int hFractals = INVALID_HANDLE;     // Handle of indicator 'Fractals'. See: 'http://www.mql5.com/en/docs/indicators/ifractals'
//+------------------------------------------------------------------+
//| Type of bar by Bill Wiallams strategy.                           |
//+------------------------------------------------------------------+
enum ENUM_BAR_TYPE
  {
   BAR_TYPE_ORDINARY,               // Ordinary bar. 
   BAR_TYPE_BEARISH,                // This bar close in the upper third and it's minimum is lowest at N period.
   BAR_TYPE_BULLISH,                // This bar close in the lower third and it's maximum is highest at N period.
  };
//+------------------------------------------------------------------+
//| Type of Extremum.                                                |
//+------------------------------------------------------------------+
enum ENUM_TYPE_EXTREMUM
  {
   TYPE_EXTREMUM_HIGHEST,           // Extremum from highest prices.
   TYPE_EXTREMUM_LOWEST             // Extremum from lowest prices.
  };
//+------------------------------------------------------------------+
//| Type of position.                                                |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_TYPE
  {
   ENTRY_BUY1,                      // Buy position with short target.
   ENTRY_BUY2,                      // Buy position with long target.
   ENTRY_SELL1,                     // Sell position with short target.
   ENTRY_SELL2,                     // Sell position with long target.
   ENTRY_BAD_COMMENT                // My position, but wrong comment.
  };
  
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Create indicator 'Fractals' ---//
   hFractals=iFractals(Symbol(),NULL);
   if(hFractals==INVALID_HANDLE)
      printf("Warning! Indicator 'Fractals' not does not create. Reason: "+
             (string)GetLastError());
//--- Corection magic by timeframe ---//
   int minPeriod=PeriodSeconds()/60;
   string strMagic=(string)Magic+(string)minPeriod;
   Magic=StringToInteger(strMagic);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+  

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Delete indicator 'Fractals' ---//
   if(hFractals!=INVALID_HANDLE)
      IndicatorRelease(hFractals);
//---
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Run logic only open new bar. ---//
   int totals=SupportPositions();
   if(NewBarDetect()==true)
     {
      MqlRates rates[];
      CopyRates(Symbol(),NULL,1,1,rates);
      MqlRates prevBar=rates[0];
      //--- Set new pendings order ---//
      double closeRate=GetCloseRate(prevBar);
      if(closeRate<=30 && BarIsExtremum(1,N,TYPE_EXTREMUM_HIGHEST))
        {
         DeleteOldPendingOrders(0);
         SetNewPendingOrder(1,BAR_TYPE_BEARISH);
        }
      else if(closeRate>=70 && BarIsExtremum(1,N,TYPE_EXTREMUM_LOWEST))
        {
         DeleteOldPendingOrders(0);
         SetNewPendingOrder(1,BAR_TYPE_BULLISH);
        }
      DeleteOldPendingOrders(OldPending);
     }
//---
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Analize open positions and modify it if need.                    |
//+------------------------------------------------------------------+
int SupportPositions()
  {
//---
   int count=0;
   //--- Analize active positions... ---//
   for(int i=0; i<TransactionsTotal(); i++) // Get total positions.
     {
      //--- Select main active positions ---//
      if(!TransactionSelect(i, SELECT_BY_POS, MODE_TRADES))continue;             // Select active transactions.
      if(TransactionType() != TRANS_HEDGE_POSITION)continue;                     // Select hedge positions only.
      if(HedgePositionGetInteger(HEDGE_POSITION_MAGIC) != Magic)                 // Select main positions by magic.
      if(HedgePositionGetInteger(HEDGE_POSITION_STATE) == POSITION_STATE_FROZEN) // If position is frozen - continue. 
         continue;                                                               // Let's try to get access to positions later.
      count++;
      //--- What position do we choose?... ---//
      ENUM_ENTRY_TYPE type=IdentifySelectPosition();
      bool modify=false;
      double sl = 0.0;
      double tp = 0.0;
      switch(type)
        {
         case ENTRY_BUY1:
         case ENTRY_SELL1:
           {
            //--- Check sl, tp levels and modify it if need. ---//
            double currentStop=HedgePositionGetDouble(HEDGE_POSITION_SL);
            sl=GetStopLossLevel();
            if(!DoubleEquals(sl,currentStop))
               modify=true;
            tp=GetTakeProfitLevel();
            double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
            double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
            //--- Close by take-profit if price more tp level
            bool isBuyTp=tp<bid && !DoubleEquals(tp,0.0) && type==ENTRY_BUY1;
            bool isSellTp=tp>ask && type==ENTRY_SELL1;
            if(isBuyTp || isSellTp)
              {
               HedgeTradeRequest request;
               request.action=REQUEST_CLOSE_POSITION;
               request.exit_comment="Close by TP from expert";
               request.close_type=CLOSE_AS_TAKE_PROFIT;
               if(!SendTradeRequest(request))
                 {
                  ENUM_HEDGE_ERR error=GetHedgeError();
                  string logs=error==HEDGE_ERR_TASK_FAILED ? ". Print logs..." : "";
                  printf("Close position by tp failed. Reason: "+EnumToString(error)+" "+logs);
                  if(error==HEDGE_ERR_TASK_FAILED)
                     PrintTaskLog();
                  ResetHedgeError();
                 }
               else break;
              }
            double currentTakeProfit=HedgePositionGetDouble(HEDGE_POSITION_TP);
            if(!DoubleEquals(tp,currentTakeProfit))
               modify=true;
            break;
           }
         case ENTRY_BUY2:
           {
            //--- Check sl level and set modify flag. ---//
            sl=GetStopLossLevel();
            double currentStop=HedgePositionGetDouble(HEDGE_POSITION_SL);
            if(sl>currentStop)
               modify=true;
            break;
           }
         case ENTRY_SELL2:
           {
            //--- Check sl level and set modify flag. ---//
            sl=GetStopLossLevel();
            double currentStop=HedgePositionGetDouble(HEDGE_POSITION_SL);
            bool usingSL=HedgePositionGetInteger(HEDGE_POSITION_USING_SL);
            if(sl<currentStop || !usingSL)
               modify=true;
            break;
           }
        }
      //--- if  need modify sl, tp levels - modify it. ---//
      if(modify)
        {
         HedgeTradeRequest request;
         request.action=REQUEST_MODIFY_SLTP;
         request.sl = sl;
         request.tp = tp;
         if(type==ENTRY_BUY1 || type==ENTRY_SELL1)
            request.exit_comment="Exit by T/P level";
         else
            request.exit_comment="Exit by trailing S/L";
         if(!SendTradeRequest(request))
           {
            ENUM_HEDGE_ERR error=GetHedgeError();
            string logs=error==HEDGE_ERR_TASK_FAILED ? ". Print logs..." : "";
            printf("Modify stop-loss or take-profit failed. Reason: "+EnumToString(error)+" "+logs);
            if(error==HEDGE_ERR_TASK_FAILED)
               PrintTaskLog();
            ResetHedgeError();
           }
         else break;
        }
     }
   return count;
//---
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Return stop-loss level for selected position.                    |
//| RESULT                                                           |
//|   Stop-loss level                                                |
//+------------------------------------------------------------------+
double GetStopLossLevel()
  {
//---
   double point=SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_SIZE)*3;
   double fractals[];
   double sl=0.0;
   MqlRates ReversalBar;

   if(!LoadReversalBar(ReversalBar))
     {
      printf("Reversal bar load failed.");
      return sl;
     }
   //--- What position do we choose?... ---//
   switch(IdentifySelectPosition())
     {
      case ENTRY_SELL2:
        {
         if(HedgePositionGetInteger(HEDGE_POSITION_USING_SL))
           {
            sl=NormalizeDouble(HedgePositionGetDouble(HEDGE_POSITION_SL),Digits());
            CopyBuffer(hFractals,UPPER_LINE,ReversalBar.time,TimeCurrent(),fractals);
            for(int i=ArraySize(fractals)-4; i>=0; i--)
              {
               if(DoubleEquals(fractals[i],DBL_MAX))continue;
               if(DoubleEquals(fractals[i],sl))continue;
               if(fractals[i]<sl)
                 {
                  double price= SymbolInfoDouble(Symbol(),SYMBOL_ASK);
                  int ifreeze =(int)SymbolInfoInteger(Symbol(),SYMBOL_TRADE_FREEZE_LEVEL);
                  double freeze=SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_SIZE)*ifreeze;
                  if(fractals[i]>price+freeze)
                     sl=NormalizeDouble(fractals[i]+point,Digits());
                 }
              }
            break;
           }
        }
      case ENTRY_SELL1:
         sl=ReversalBar.high+point;
         break;
      case ENTRY_BUY2:
         if(HedgePositionGetInteger(HEDGE_POSITION_USING_SL))
           {
            sl=NormalizeDouble(HedgePositionGetDouble(HEDGE_POSITION_SL),Digits());
            CopyBuffer(hFractals,LOWER_LINE,ReversalBar.time,TimeCurrent(),fractals);
            for(int i=ArraySize(fractals)-4; i>=0; i--)
              {
               if(DoubleEquals(fractals[i],DBL_MAX))continue;
               if(DoubleEquals(fractals[i],sl))continue;
               if(fractals[i]>sl)
                 {
                  double price= SymbolInfoDouble(Symbol(),SYMBOL_BID);
                  int ifreeze =(int)SymbolInfoInteger(Symbol(),SYMBOL_TRADE_FREEZE_LEVEL);
                  double freeze=SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_SIZE)*ifreeze;
                  if(fractals[i]<price-freeze)
                     sl=NormalizeDouble(fractals[i]-point,Digits());
                 }
              }
            break;
           }
      case ENTRY_BUY1:
         sl=ReversalBar.low-point;
     }
   sl=NormalizeDouble(sl,Digits());
   return sl;
//---
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Return Take-Profit level for selected position.                  |
//| RESULT                                                           |
//|   Take-profit level                                              |
//+------------------------------------------------------------------+
double GetTakeProfitLevel()
  {
//---
   double point=SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_SIZE)*3;
   ENUM_ENTRY_TYPE type=IdentifySelectPosition();
   double tp=0.0;
   if(type==ENTRY_BUY1 || type==ENTRY_SELL1)
     {
      if(!HedgePositionGetInteger(HEDGE_POSITION_USING_SL))
         return tp;
      double sl=HedgePositionGetDouble(HEDGE_POSITION_SL);
      double openPrice=HedgePositionGetDouble(HEDGE_POSITION_PRICE_OPEN);
      double deltaStopLoss=MathAbs(NormalizeDouble(openPrice-sl,Digits()));
      if(type==ENTRY_BUY1)
         tp=openPrice+deltaStopLoss;
      if(type==ENTRY_SELL1)
         tp=openPrice-deltaStopLoss;
      return tp;
     }
   else
      return 0.0;
//---
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Identify what position type is select.                           |
//| RESULT                                                           |
//|   Return type position. See ENUM_ENTRY_TYPE                      |
//+------------------------------------------------------------------+
ENUM_ENTRY_TYPE IdentifySelectPosition()
  {
//---   
   string comment=HedgePositionGetString(HEDGE_POSITION_ENTRY_COMMENT);
   int pos=StringLen(comment)-2;
   string subStr=StringSubstr(comment,pos);
   ENUM_DIRECTION_TYPE posDir=(ENUM_DIRECTION_TYPE)HedgePositionGetInteger(HEDGE_POSITION_DIRECTION);
   if(subStr=="#0")
     {
      if(posDir==DIRECTION_LONG)
         return ENTRY_BUY1;
      if(posDir==DIRECTION_SHORT)
         return ENTRY_SELL1;
     }
   else if(subStr=="#1")
     {
      if(posDir==DIRECTION_LONG)
         return ENTRY_BUY2;
      if(posDir==DIRECTION_SHORT)
         return ENTRY_SELL2;
     }
   return ENTRY_BAD_COMMENT;
//---
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Set pending orders under or over bar by index_bar.               |
//| INPUT PARAMETERS                                                 |
//|   index_bar - index of bar.                                      |
//|   barType - type of bar. See enum ENUM_BAR_TYPE.                 |
//| RESULT                                                           |
//|   True if new order successfully set, othewise false.            | 
//+------------------------------------------------------------------+
bool SetNewPendingOrder(int index_bar,ENUM_BAR_TYPE barType)
  {
//---
   MqlRates rates[1];
   CopyRates(Symbol(),NULL,index_bar,1,rates);
   MqlTradeRequest request={0};
   request.volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   double vol=request.volume;
   request.symbol = Symbol();
   request.action = TRADE_ACTION_PENDING;
   request.type_filling=ORDER_FILLING_FOK;
   request.type_time=ORDER_TIME_GTC;
   request.magic=Magic;
   double point=SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_SIZE)*3;
   string comment="";
   if(barType==BAR_TYPE_BEARISH)
     {
      request.price=rates[0].low-point;
      comment="Entry sell by bearish bar";
      request.type=ORDER_TYPE_SELL_STOP;
     }
   else if(barType==BAR_TYPE_BULLISH)
     {
      request.price=rates[0].high+point;
      comment="Entry buy by bullish bar";
      request.type=ORDER_TYPE_BUY_STOP;
     }
   MqlTradeResult result={0};
//--- Send pending order twice...
   for(int i=0; i<2; i++)
     {
      request.comment=comment+" #"+(string)i;       // Detect order by comment;
      if(!OrderSend(request,result))
        {
         printf("Trade error #"+(string)result.retcode+" "+
                result.comment);
         return false;
        }
     }
   return true;
//---
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Delete old pending orders. If pending order set older that       |
//| n_bars ago pending orders will be removed.                       |
//| INPUT PARAMETERS                                                 |
//|   period - count bar.                                            |
//+------------------------------------------------------------------+
void DeleteOldPendingOrders(int n_bars)
  {
//---
   for(int i=0; i<OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);            // Get ticket of order by index.
      if(!OrderSelect(ticket))                     // Continue if not selected.
         continue;
      if(Magic!=OrderGetInteger(ORDER_MAGIC))      // Continue if magic is not main.
         continue;
      if(OrderGetString(ORDER_SYMBOL)!=Symbol())   // Continue if symbol is not main.
         continue;
      //--- Count time elipsed ---//
      datetime timeSetup=(datetime)OrderGetInteger(ORDER_TIME_SETUP);
      int secElapsed=(int)(TimeCurrent()-timeSetup);
      //--- delete old pending order ---//
      if(secElapsed>=PeriodSeconds() *n_bars)
        {
         MqlTradeRequest request={0};
         MqlTradeResult result={0};
         request.action= TRADE_ACTION_REMOVE;
         request.order = ticket;
         if(!OrderSend(request,result))
            printf("Delete pending order failed. Reason #"+(string)result.retcode+" "+result.comment);
        }
     }
//---
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect new bar.                                                  |
//+------------------------------------------------------------------+
bool NewBarDetect(void)
  {
//---
   datetime timeArray[1];
   CopyTime(Symbol(),NULL,0,1,timeArray);
   if(lastTime!=timeArray[0])
     {
      lastTime=timeArray[0];
      return true;
     }
   return false;
//---
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get close rate. Type bar defined in trade chaos strategy  |
//| and equal enum 'ENUM_TYPE_BAR'.                                  |
//| INPUT PARAMETERS                                                 |
//|   index - index of bars series. for example:                     |
//|   '0' - is current bar. 1 - previous bar.                        |
//| RESULT                                                           |
//|   Type of ENUM_TYPE_BAR.                                         | 
//+------------------------------------------------------------------+
double GetCloseRate(const MqlRates &bar)
  {
//---
   double highLowDelta = bar.high-bar.low;      // Calculate diaposon bar.
   double lowCloseDelta = bar.close - bar.low;  // Calculate Close - Low delta.
   double percentClose=0.0;
   if(!DoubleEquals(lowCloseDelta, 0.0))                    // Division by zero protected.   
      percentClose = lowCloseDelta/highLowDelta*100.0;      // Calculate percent 'lowCloseDelta' of 'highLowDelta'.
   return percentClose;
//---
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| If bar by index is extremum - return true, otherwise             |
//| return false.                                                    |
//| INPUT PARAMETERS                                                 |
//|   index - index of bar.                                          |
//|   period - Number of bars prior to the extremum.                 |
//|   type - Type of extremum. See ENUM_TYPE_EXTREMUM TYPE enum.     |
//| RESULT                                                           |
//|   True - if bar is extremum, otherwise false.                    | 
//+------------------------------------------------------------------+
bool BarIsExtremum(const int index,const int period,ENUM_TYPE_EXTREMUM type)
  {
//---
//--- Copy rates --- //
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   CopyRates(Symbol(),NULL,index,N+1,rates);
//--- Search extremum --- //
   for(int i=1; i<ArraySize(rates); i++)
     {
      //--- Reset comment if you want include volume analize. ---//
      //if(rates[0].tick_volume<rates[i].tick_volume)
      //   return false;
      if(type==TYPE_EXTREMUM_HIGHEST && 
         rates[0].high<rates[i].high)
         return false;
      if(type==TYPE_EXTREMUM_LOWEST && 
         rates[0].low>rates[i].low)
         return false;
     }
   return true;
//---
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Print current error and reset it.                                |
//+------------------------------------------------------------------+  
void PrintTaskLog()
  {
//---
   uint totals=(uint)HedgePositionGetInteger(HEDGE_POSITION_ACTIONS_TOTAL);
   for(uint i = 0; i<totals; i++)
     {
      uint retcode=0;
      ENUM_TARGET_TYPE type;
      GetActionResult(i,type,retcode);
      printf("---> Action #"+(string)i+"; "+EnumToString(type)+"; RETCODE: "+(string)retcode);
     }
//---
  }
//--------------------------------------------------------------------

//+------------------------------------------------------------------+
//| Load reversal bar. The current position must be selected.        |
//| OUTPUT PARAMETERS                                                |
//|   bar - MqlRates bar.
//+------------------------------------------------------------------+  
bool LoadReversalBar(MqlRates &bar)
  {
//---
   datetime time=(datetime)(HedgePositionGetInteger(HEDGE_POSITION_ENTRY_TIME_SETUP_MSC)/1000+1);
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   CopyRates(Symbol(),NULL,time,2,rates);
   int size=ArraySize(rates);
   if(size==0)return false;
   bar=rates[size-1];
   return true;
//---   
  }
//+------------------------------------------------------------------+
  
//+------------------------------------------------------------------+
//| Compares two double numbers.                                     |
//| RESULT                                                           |
//|   True if two double numbers equal, otherwise false.             |
//+------------------------------------------------------------------+
bool DoubleEquals(const double a,const double b)
  {
//---
   return(fabs(a-b)<=16*DBL_EPSILON*fmax(fabs(a),fabs(b)));
//---
  }
//+------------------------------------------------------------------+
