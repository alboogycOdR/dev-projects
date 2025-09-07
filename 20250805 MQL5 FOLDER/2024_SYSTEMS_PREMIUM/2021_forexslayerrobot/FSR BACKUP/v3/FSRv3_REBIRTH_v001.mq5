//+------------------------------------------------------------------+
//|                                            Punch_Back_System.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, Forex market killer."
#property link      "https://forexmarketkilller.com"
#property version   "1.001"
#include <Trade\Trade.mqh>
CTrade trade;
#include <Trade\PositionInfo.mqh>

#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Expert\Money\MoneyFixedMargin.mqh>
CPositionInfo  m_position;                   // object of CPositionInfo class

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSymbolInfo    m_symbol;                     // object of CSymbolInfo class
CAccountInfo   m_account;                    // object of CAccountInfo class
CDealInfo      m_deal;                       // object of CDealInfo class
COrderInfo     m_order;                      // object of COrderInfo class

//============SIGNAL DIRECTION [BUY|SELL]============
string direction  ="NONE";

//============EQUITY CHECK (not used) ============
bool equit = false;


//,double poits=3; /*no used*/

//============LEVELS============
double TOP,LOW,SEVEN5,TWEN5,SL_GLOBAL,TP_GLOBAL;
static double FIB_50_LVL;
static double FIB_61_BUY_LVL;
static double FIB_38_BUY_LVL;
static double FIB_23_BUY_LVL;
static double FIB_38_SELL_LVL;
static double FIB_61_SELL_LVL;
static double FIB_23_SELL_LVL ;
input bool    fib23=false;//23% fib
input bool    fib38=false;//38% fib
input bool    fib61=false;//61% fib
input bool    fib50=true;//50% fib


//============MONEY MANAGEMENT============
input double   Volume = 0.1;//CUSTOM LOT SIZE
double         variableVolume;
input int      Positions_to_open = 1;//MAX CONCURRENT POSITIONS
int            slippage = 1;
int            TP_SL_RATIO = 1;
double         currentbalance = AccountInfoDouble(ACCOUNT_BALANCE);
//double         total_profit = 0;
double         buy_take_profit, sell_take_profit;
input bool   enableMinVol=true; //Auto minimum lot
input bool   enableMaxVol=false;//Auto maximum lot


//============TREND CHECK HH-HL  LH-LL  MANAGEMENT============
int            startperiod=0;
input int      endperiod=15;//Impulse Move Period


ulong   InpMagic             = 999999999;    // Magic number



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   ResetLastError();
   if(!m_symbol.Name(Symbol())) // sets symbol name
     {
      Print(__FILE__," ",__FUNCTION__,", ERROR: CSymbolInfo.Name");
      return(INIT_FAILED);
     }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(m_symbol.Name());
   trade.SetDeviationInPoints(slippage);




   ObjectsDeleteAll(0,-1,-1);

//=HIGH========DETERMINE HIGHEST maximum CANDLES IN PERIOD [HIGH] ; DRAW LINE.
   int Highest;
   double High[];
   MqlRates PriceInfo[];
   ArraySetAsSeries(High,true);
   ArraySetAsSeries(PriceInfo,true);
   CopyHigh(_Symbol,_Period,startperiod,endperiod,High);//   [ 0 to 10 candles ]
   CopyRates(_Symbol,_Period,0,Bars(_Symbol,_Period),PriceInfo);
   Highest = ArrayMaximum(High,startperiod,endperiod);
   ObjectCreate(0,"Highest",OBJ_HLINE,0,0,PriceInfo[Highest].high);
   ObjectSetInteger(0,"Highest",OBJPROP_COLOR,clrNavy);
   ObjectSetInteger(0,"Highest",OBJPROP_WIDTH,1);
   ObjectSetInteger(0,"Highest",OBJPROP_STYLE,STYLE_DASHDOT);
//=LOW========DETERMINE LOWEST maximum CANDLES IN PERIOD [LOW] ; DRAW LINE.
   int Lowest;
   double Low[];
   MqlRates PriceInfo2[];
   ArraySetAsSeries(Low,true);
   ArraySetAsSeries(PriceInfo2,true);
   CopyLow(_Symbol,_Period,startperiod,endperiod,Low);
   CopyRates(_Symbol,_Period,0,Bars(_Symbol,_Period),PriceInfo2);
   Lowest = ArrayMinimum(Low,startperiod,endperiod);
   ObjectCreate(0,"Lowest",OBJ_HLINE,0,0,iLow(_Symbol,_Period,Lowest));
   ObjectSetInteger(0,"Lowest",OBJPROP_COLOR,clrNavy);
   ObjectSetInteger(0,"Lowest",OBJPROP_STYLE,STYLE_DASHDOT);
   ObjectSetInteger(0,"Lowest",OBJPROP_WIDTH,1);
//=MID========DETERMINE 50% FIBONACCI ; DRAW LINE.
   double Mid = iHigh(_Symbol,_Period,Highest)-(0.5*(iHigh(_Symbol,_Period,Highest)-iLow(_Symbol,_Period,Lowest)));
   ObjectCreate(0,"Middle",OBJ_HLINE,0,0,Mid);
   ObjectSetInteger(0,"Middle",OBJPROP_COLOR,clrBlack);
   ObjectSetInteger(0,"Middle",OBJPROP_WIDTH,1);
   ObjectSetInteger(0,"Middle",OBJPROP_STYLE,STYLE_DASHDOT);
   /*
      =========
      =========
      =========
      =========
   */
   int Downpoint1,Downpoint2;
   double tHigh[];

   ArraySetAsSeries(tHigh,true);
   CopyHigh(_Symbol,_Period,startperiod,endperiod,tHigh);


   Downpoint1 = ArrayMaximum(tHigh,startperiod,endperiod);
   tHigh[Downpoint1] =NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   tHigh[ArrayMaximum(tHigh,startperiod,endperiod)] =NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   Downpoint2 = ArrayMaximum(tHigh,startperiod,endperiod);


   ObjectCreate(0,"DownTline",OBJ_TREND,0,iTime(_Symbol,_Period,Highest),iHigh(_Symbol,_Period,Highest),iTime(_Symbol,_Period,Downpoint2),iHigh(_Symbol,_Period,Downpoint2));
   ObjectSetInteger(0,"DownTline",OBJPROP_COLOR,clrRed);
   ObjectSetInteger(0,"DownTline",OBJPROP_WIDTH,2);

//=========
//=========
//=========

   int Uppoint1,Uppoint2;
   double tLow[];

   ArraySetAsSeries(tLow,true);
   CopyLow(_Symbol,_Period,startperiod,endperiod,tLow);


   Uppoint1 = ArrayMinimum(tLow,startperiod,endperiod);
   tLow[Uppoint1] =NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   tLow[ArrayMinimum(tLow,startperiod,endperiod)] =NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   Uppoint2 = ArrayMinimum(tLow,startperiod,endperiod);


   ObjectCreate(0,"UpTline",OBJ_TREND,0,iTime(_Symbol,_Period,Lowest),iLow(_Symbol,_Period,Lowest),iTime(_Symbol,_Period,Uppoint2),iLow(_Symbol,_Period,Uppoint2));
   ObjectSetInteger(0,"UpTline",OBJPROP_COLOR,clrGreen);
   ObjectSetInteger(0,"UpTline",OBJPROP_WIDTH,2);



   double min_volume=m_symbol.LotsMin();//Print("min_volume  "+min_volume);
   double max_volume=m_symbol.LotsMax();//Print("max_volume  "+max_volume);


   variableVolume=Volume;
   if(enableMaxVol)
      variableVolume=max_volume;
   if(enableMinVol)
      variableVolume=min_volume;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0,-1,-1);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {


//total_profit = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE)-currentbalance,2);

   DrawObjects();

   //if(OrdersTotal() ==0 && PositionsTotal()==0 && isNewBar())
   //  {
        if(OrdersTotal() <5 && PositionsTotal()<5 && isNewBar())
     {
      double  ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      double  bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);

      if(direction =="BUY")
        {
         direction = "NONE";

         SL_GLOBAL = TOP;
         TP_GLOBAL = LOW;

         double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();

         if(fib50)
           {
            if(FIB_50_LVL+SL_GLOBAL < stops)
              {
               SL_GLOBAL=FIB_50_LVL+stops;
              }
            if(FIB_50_LVL - TP_GLOBAL < stops)
              {
               TP_GLOBAL=FIB_50_LVL-stops;
              }

            bool orderSell = trade.SellLimit(variableVolume
                                             ,NormalizeDouble(FIB_50_LVL,Digits())     //50% midpoint
                                             ,Symbol()
                                             ,NormalizeDouble(SL_GLOBAL,Digits())
                                             ,NormalizeDouble(TP_GLOBAL,Digits())
                                             ,0,0
                                             ,"s50");
           }
         //BUY STRUCTURE
         if(fib61)
           {
            if(FIB_38_SELL_LVL+SL_GLOBAL < stops)
              {
               SL_GLOBAL=FIB_38_SELL_LVL+stops;
              }
            if(FIB_38_SELL_LVL - TP_GLOBAL < stops)
              {
               TP_GLOBAL=FIB_38_SELL_LVL-stops;
              }
            bool orderSell2 = trade.SellLimit(variableVolume
                                              ,FIB_38_SELL_LVL
                                              ,Symbol()
                                              ,SL_GLOBAL
                                              ,TP_GLOBAL
                                              ,0,0
                                              ,"s61");
           }
         if(fib38)
           {
            if(FIB_61_SELL_LVL+SL_GLOBAL < stops)
              {
               SL_GLOBAL=FIB_61_SELL_LVL+stops;
              }
            if(FIB_61_SELL_LVL - TP_GLOBAL < stops)
              {
               TP_GLOBAL=FIB_61_SELL_LVL-stops;
              }
            bool orderSell3 = trade.SellLimit(variableVolume
                                              ,FIB_61_SELL_LVL
                                              ,Symbol()
                                              ,SL_GLOBAL
                                              ,TP_GLOBAL
                                              ,0,0
                                              ,"s38");
           }
         if(fib23)
           {
            if(FIB_23_SELL_LVL+SL_GLOBAL < stops)
              {
               SL_GLOBAL=FIB_23_SELL_LVL+stops;
              }
            if(FIB_23_SELL_LVL - TP_GLOBAL < stops)
              {
               TP_GLOBAL=FIB_23_SELL_LVL-stops;
              }


            bool orderSell4 = trade.SellLimit(variableVolume
                                              ,FIB_23_SELL_LVL
                                              ,Symbol()
                                              ,SL_GLOBAL
                                              ,TP_GLOBAL
                                              ,0,0
                                              ,"s23");
           }




        }
      if(direction =="SELL")
        {
         double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
         SL_GLOBAL = LOW;
         TP_GLOBAL = TOP;

         direction = "NONE";


         if(fib50)
           {
            //Print("FIB_50_LVL "+(FIB_50_LVL));
            //Print("SL_GLOBAL "+(SL_GLOBAL));
            //Print("FIB_50_LVL-SL_GLOBAL "+(FIB_50_LVL-SL_GLOBAL));
            //Print("stops "+(stops));

            if(FIB_50_LVL-SL_GLOBAL < stops)
              {
               SL_GLOBAL=FIB_50_LVL-stops;
              }

            if(TP_GLOBAL-FIB_50_LVL < stops)
              {
               TP_GLOBAL=FIB_50_LVL+stops;
              }

            bool orderBuy = trade.BuyLimit(variableVolume
                                           ,NormalizeDouble(FIB_50_LVL,Digits())
                                           ,Symbol()
                                           ,NormalizeDouble(SL_GLOBAL,Digits())
                                           ,NormalizeDouble(TP_GLOBAL,Digits())
                                           ,0,0
                                           ,"b50");
           }
         //SELL STRUCTURE
         if(fib61)
           {

            if(FIB_61_BUY_LVL-SL_GLOBAL < stops)
              {
               SL_GLOBAL=FIB_61_BUY_LVL-stops;
              }

            if(TP_GLOBAL-FIB_61_BUY_LVL < stops)
              {
               TP_GLOBAL=FIB_61_BUY_LVL+stops;
              }



            bool orderBuy2 = trade.BuyLimit(variableVolume
                                            ,FIB_61_BUY_LVL
                                            ,Symbol()
                                            ,SL_GLOBAL
                                            ,TP_GLOBAL
                                            ,0,0
                                            ,"b61");
           }
         if(fib38)
           {

            if(FIB_38_BUY_LVL-SL_GLOBAL < stops)
              {
               SL_GLOBAL=FIB_38_BUY_LVL-stops;
              }

            if(TP_GLOBAL-FIB_38_BUY_LVL < stops)
              {
               TP_GLOBAL=FIB_38_BUY_LVL+stops;
              }


            bool orderBuy3 = trade.BuyLimit(variableVolume
                                            ,FIB_38_BUY_LVL
                                            ,Symbol()
                                            ,SL_GLOBAL
                                            ,TP_GLOBAL
                                            ,0,0
                                            ,"b38");
           }

         if(fib23)
           {
            if(FIB_23_BUY_LVL-SL_GLOBAL < stops)
              {
               SL_GLOBAL=FIB_23_BUY_LVL-stops;
              }

            if(TP_GLOBAL-FIB_23_BUY_LVL < stops)
              {
               TP_GLOBAL=FIB_23_BUY_LVL+stops;
              }
            bool orderBuy4 = trade.BuyLimit(variableVolume
                                            ,FIB_23_BUY_LVL
                                            ,Symbol()
                                            ,SL_GLOBAL
                                            ,TP_GLOBAL
                                            ,0,0
                                            ,"b23");

           }

        }
     }

   ModifyExistingPositions();

   /*
   piece removed; see addendum
   */

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawObjects()
  {
   static double prevHigh,newHigh,prevLow,newLow;
//============================================================
   int Highest;
   double High[];
   ArraySetAsSeries(High,true);
   int Lowest;
   double Low[];
   ArraySetAsSeries(Low,true);
   CopyHigh(_Symbol,_Period,startperiod,endperiod,High);
   Highest = ArrayMaximum(High,startperiod,endperiod);  // highest of the last 10 candles
   CopyLow(_Symbol,_Period,startperiod,endperiod,Low);
   Lowest = ArrayMinimum(Low,startperiod,endperiod);
//===========================================================
   double Mid = iHigh(_Symbol,_Period,Highest)-(0.5*(iHigh(_Symbol,_Period,Highest)-iLow(_Symbol,_Period,Lowest)));

//BUY
   FIB_61_BUY_LVL= iHigh(_Symbol,_Period,Highest)-(0.618*(iHigh(_Symbol,_Period,Highest)-iLow(_Symbol,_Period,Lowest)));
   FIB_38_BUY_LVL= iHigh(_Symbol,_Period,Highest)-(0.382*(iHigh(_Symbol,_Period,Highest)-iLow(_Symbol,_Period,Lowest)));
   FIB_23_BUY_LVL= iHigh(_Symbol,_Period,Highest)-(0.236*(iHigh(_Symbol,_Period,Highest)-iLow(_Symbol,_Period,Lowest)));
//SELL
   FIB_38_SELL_LVL=iLow(_Symbol,_Period,Lowest)+(0.382*(iHigh(_Symbol,_Period,Highest)-iLow(_Symbol,_Period,Lowest)));
   FIB_61_SELL_LVL= iLow(_Symbol,_Period,Lowest)+(0.618*(iHigh(_Symbol,_Period,Highest)-iLow(_Symbol,_Period,Lowest)));
   FIB_23_SELL_LVL= iLow(_Symbol,_Period,Lowest)+(0.236*(iHigh(_Symbol,_Period,Highest)-iLow(_Symbol,_Period,Lowest)));





   double Seven5 = iHigh(_Symbol,_Period,Highest)-(0.25*(iHigh(_Symbol,_Period,Highest)-iLow(_Symbol,_Period,Lowest)));
   double Twen5 = iHigh(_Symbol,_Period,Highest)-(0.75*(iHigh(_Symbol,_Period,Highest)-iLow(_Symbol,_Period,Lowest)));
   /*

   highest of 10 candles
   lowest of 10 candle
   midpoint
   25%
   75%

   static class variables (newhigh    prevhigh     newlow   prevlow)
   */;
//===========================================================
   if(newHigh != iHigh(_Symbol,_Period,Highest))
     {
      prevHigh = newHigh;
      newHigh = iHigh(_Symbol,_Period,Highest);

      ObjectMove(0,"Highest",0,0,iHigh(_Symbol,_Period,Highest));
      ObjectMove(0,"Lowest",0,0,iLow(_Symbol,_Period,Lowest));
      ObjectMove(0,"Middle",0,0,Mid);
     }

   if(newLow != iLow(_Symbol,_Period,Lowest))
     {
      prevLow = newLow;
      newLow = iLow(_Symbol,_Period,Lowest);

      ObjectMove(0,"Highest",0,0,iHigh(_Symbol,_Period,Highest));
      ObjectMove(0,"Lowest",0,0,iLow(_Symbol,_Period,Lowest));
      ObjectMove(0,"Middle",0,0,Mid);
     }


//trend high
//trend low
   int Downpoint1,Downpoint2;
   double tHigh[];
   ArraySetAsSeries(tHigh,true);
   CopyHigh(_Symbol,_Period,startperiod,endperiod,tHigh);
   Downpoint1 = ArrayMaximum(tHigh,startperiod,endperiod);
   tHigh[Downpoint1] =NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   tHigh[ArrayMaximum(tHigh,startperiod,endperiod)] =NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   Downpoint2 = ArrayMaximum(tHigh,startperiod,endperiod);
//---------------------------
   int Uppoint1,Uppoint2;
   double tLow[];
   ArraySetAsSeries(tLow,true);
   CopyLow(_Symbol,_Period,startperiod,endperiod,tLow);
   Uppoint1 = ArrayMinimum(tLow,startperiod,endperiod);
   tLow[Uppoint1] =NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   tLow[ArrayMinimum(tLow,startperiod,endperiod)] =NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   Uppoint2 = ArrayMinimum(tLow,startperiod,endperiod);
//---------------------------
   if(Uppoint1 > Uppoint2)
     {
      ObjectMove(0,"UpTline",0,iTime(_Symbol,_Period,Lowest),iLow(_Symbol,_Period,Lowest));
      ObjectMove(0,"UpTline",1,iTime(_Symbol,_Period,Uppoint2),iLow(_Symbol,_Period,Uppoint2));
     }
   if(Downpoint1>Downpoint2)
     {
      ObjectMove(0,"DownTline",0,iTime(_Symbol,_Period,Highest),iHigh(_Symbol,_Period,Highest));
      ObjectMove(0,"DownTline",1,iTime(_Symbol,_Period,Downpoint2),iHigh(_Symbol,_Period,Downpoint2));
     }
//

//SIGNALS
   if(iLow(_Symbol,_Period,1) == newLow && isNewBar() &&   PositionsTotal()== 0)
      direction = "BUY";
   if(iHigh(_Symbol,_Period,1) == newHigh && isNewBar() &&   PositionsTotal()== 0)
      direction = "SELL";

   TOP= NormalizeDouble(newHigh,_Digits);
   LOW = NormalizeDouble(newLow,_Digits);

   SEVEN5 = Seven5;
   TWEN5 = Twen5;

   FIB_50_LVL = Mid;
  }
//+------------------------------------------------------------------+
//|                                                                  |
/*
bool equity()

#1     NO CURRENT POSITIONS THEN equity is FALSE

#2     OPEN POSITIONS THEN
               A.  AccountInfoDouble(ACCOUNT_PROFIT) >= 10*variableVolume && AccountInfoDouble(ACCOUNT_PROFIT) < 30*variableVolume
                pointsmove = 0;eqt = true;
               B.  AccountInfoDouble(ACCOUNT_PROFIT) >= (pointsmove+20)*variableVolume
                pointsmove +=10;equit = true;
*/
//+------------------------------------------------------------------+
bool equity()
  {
   static double pointsmove;
   static bool eqt;


   if(PositionsTotal()== 0)
      eqt = false;


   if(PositionsTotal() >0)
     {
      if(eqt == false && AccountInfoDouble(ACCOUNT_PROFIT) >= 10*variableVolume && AccountInfoDouble(ACCOUNT_PROFIT) < 30*variableVolume)
        {
         pointsmove = 0;
         eqt = true;
        }
      if(AccountInfoDouble(ACCOUNT_PROFIT) >= (pointsmove+20)*variableVolume)
        {
         pointsmove +=10;
         equit = true;
        }
     }


   return eqt;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Profit(void)
  {
   double Res = 0;

   if(HistorySelect(0, INT_MAX))
      //for (int i = HistoryDealsTotal() - 1; i >= 0; i--)
     {
      const ulong Ticket = HistoryDealGetTicket(HistoryDealsTotal() - 1);

      if((HistoryDealGetString(Ticket, DEAL_SYMBOL) == Symbol()))
         Res = HistoryDealGetDouble(Ticket, DEAL_PROFIT);
     }

   return(Res);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ModifyExistingPositions()
  {


//OPEN PENDING ORDERS
//PENDING: BUY AND SELL LIMITS


   if(OrdersTotal() > 0)
     {
      for(int i = 0; i<OrdersTotal(); i++)
        {
         ulong tkt = OrderGetTicket(i);

         string commentflag=OrderGetString(ORDER_COMMENT);

          

         if(commentflag=="b50" || commentflag=="s50")
           {
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT &&  _Symbol==Symbol() && m_order.Magic()== InpMagic)
              {
               if(OrderGetDouble(ORDER_PRICE_OPEN)  != FIB_50_LVL)
                 {
                  double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();

                  SL_GLOBAL = LOW;
                  TP_GLOBAL = TOP;
                  if(FIB_50_LVL-SL_GLOBAL < stops)
                    {
                     SL_GLOBAL=FIB_50_LVL-stops;
                    }
                  if(TP_GLOBAL-FIB_50_LVL < stops)
                    {
                     TP_GLOBAL=FIB_50_LVL+stops;
                    }


                  trade.OrderModify(tkt,FIB_50_LVL,
                                    SL_GLOBAL,
                                    TP_GLOBAL
                                    ,NULL,0,0);
                 }
              }
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT && _Symbol==Symbol() && m_order.Magic()==InpMagic)
              {
               if(OrderGetDouble(ORDER_PRICE_OPEN)  != FIB_50_LVL)
                 {

                  double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
                  SL_GLOBAL = TOP ;
                  TP_GLOBAL = LOW;

                  if(FIB_50_LVL+SL_GLOBAL < stops)
                    {
                     SL_GLOBAL=FIB_50_LVL+stops;
                    }
                  if(FIB_50_LVL - TP_GLOBAL < stops)
                    {
                     TP_GLOBAL=FIB_50_LVL-stops;
                    }

                  trade.OrderModify(tkt,FIB_50_LVL,SL_GLOBAL,TP_GLOBAL,NULL,0,0);
                 }
              }
           }
         if(commentflag=="b61" || commentflag=="s61")
           {
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT && _Symbol==Symbol() && m_order.Magic()==InpMagic)
              {
               if(OrderGetDouble(ORDER_PRICE_OPEN)  !=  FIB_61_BUY_LVL)
                 {

                  double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
                  SL_GLOBAL = LOW;
                  TP_GLOBAL = TOP;
                  if(FIB_61_BUY_LVL-SL_GLOBAL < stops)
                    {
                     SL_GLOBAL=FIB_61_BUY_LVL-stops;
                    }
                  if(TP_GLOBAL-FIB_61_BUY_LVL < stops)
                    {
                     TP_GLOBAL=FIB_61_BUY_LVL+stops;
                    }

                  trade.OrderModify(tkt, FIB_61_BUY_LVL,SL_GLOBAL,TP_GLOBAL,NULL,0,0);


                 }
              }
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT && _Symbol==Symbol() && m_order.Magic()==InpMagic)
              {
               if(OrderGetDouble(ORDER_PRICE_OPEN)  !=  FIB_61_SELL_LVL)
                 {
                  double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
                  SL_GLOBAL = TOP ;
                  TP_GLOBAL = LOW;

                  if(FIB_61_SELL_LVL+SL_GLOBAL < stops)
                    {
                     SL_GLOBAL=FIB_61_SELL_LVL+stops;
                    }
                  if(FIB_61_SELL_LVL - TP_GLOBAL < stops)
                    {
                     TP_GLOBAL=FIB_61_SELL_LVL-stops;
                    }

                  trade.OrderModify(tkt, FIB_61_SELL_LVL,SL_GLOBAL,TP_GLOBAL,NULL,0,0);


                 }
              }
           }
         if(commentflag=="b38" || commentflag=="s38")
           {
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT && _Symbol==Symbol() && m_order.Magic()==InpMagic)
              {
               if(OrderGetDouble(ORDER_PRICE_OPEN)  !=  FIB_38_BUY_LVL)
                 {
                  double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
                  SL_GLOBAL = LOW;
                  TP_GLOBAL = TOP;
                  if(FIB_38_BUY_LVL-SL_GLOBAL < stops)
                    {
                     SL_GLOBAL=FIB_38_BUY_LVL-stops;
                    }
                  if(TP_GLOBAL-FIB_38_BUY_LVL < stops)
                    {
                     TP_GLOBAL=FIB_38_BUY_LVL+stops;
                    }

                  trade.OrderModify(tkt, FIB_38_BUY_LVL,SL_GLOBAL,TP_GLOBAL,NULL,0,0);
                 }
              }
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT && _Symbol==Symbol() && m_order.Magic()==InpMagic)
              {
               if(OrderGetDouble(ORDER_PRICE_OPEN)  !=  FIB_38_SELL_LVL)
                 {

                  double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
                  SL_GLOBAL = TOP ;
                  TP_GLOBAL = LOW;

                  if(FIB_38_SELL_LVL+SL_GLOBAL < stops)
                    {
                     SL_GLOBAL=FIB_38_SELL_LVL+stops;
                    }
                  if(FIB_38_SELL_LVL - TP_GLOBAL < stops)
                    {
                     TP_GLOBAL=FIB_38_SELL_LVL-stops;
                    }


                  trade.OrderModify(tkt, FIB_38_SELL_LVL,SL_GLOBAL,TP_GLOBAL,NULL,0,0);
                 }
              }
           }//38.1

         if(commentflag=="b23" || commentflag=="s23")
           {
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT && _Symbol==Symbol() && m_order.Magic()==InpMagic)
              {
               if(OrderGetDouble(ORDER_PRICE_OPEN)  != FIB_23_BUY_LVL)
                 {

                  double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
                  SL_GLOBAL = LOW;
                  TP_GLOBAL = TOP;
                  if(FIB_23_BUY_LVL-SL_GLOBAL < stops)
                    {
                     SL_GLOBAL=FIB_23_BUY_LVL-stops;
                    }
                  if(TP_GLOBAL-FIB_23_BUY_LVL < stops)
                    {
                     TP_GLOBAL=FIB_23_BUY_LVL+stops;
                    }


                  trade.OrderModify(tkt,FIB_23_BUY_LVL,SL_GLOBAL,TP_GLOBAL,NULL,0,0);
                 }
              }
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT && _Symbol==Symbol() && m_order.Magic()==InpMagic)
              {
               if(OrderGetDouble(ORDER_PRICE_OPEN)  != FIB_23_SELL_LVL)
                 {
                  double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
                  SL_GLOBAL = TOP ;
                  TP_GLOBAL = LOW;

                  if(FIB_23_SELL_LVL+SL_GLOBAL < stops)
                    {
                     SL_GLOBAL=FIB_23_SELL_LVL+stops;
                    }
                  if(FIB_23_SELL_LVL - TP_GLOBAL < stops)
                    {
                     TP_GLOBAL=FIB_23_SELL_LVL-stops;
                    }

                  trade.OrderModify(tkt,FIB_23_SELL_LVL,SL_GLOBAL,TP_GLOBAL,NULL,0,0);
                 }
              }
           }//23 retrace




         // DELETE BUY STOP and SELL STOP
         //===========================================================================================================================
         //if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP||OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP)
         //  {
         //   if(PositionsTotal()==0)
         //      trade.OrderDelete(tkt);
         //  }



        }
     }






//OPEN POSITIONS
//
//
//
//

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(PositionsTotal() > 0)
     {
      for(int i = 0; i<PositionsTotal(); i++)
        {
         ulong tktt = PositionGetTicket(i);

         //todo
         //investigate equit is true scenario


         //         if(equity()==true)
         //           {
         //            SL_GLOBAL = PositionGetDouble(POSITION_PRICE_OPEN);
         //            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && PositionGetDouble(POSITION_SL) < PositionGetDouble(POSITION_PRICE_OPEN))
         //              {
         //               trade.PositionModify(tktt,SL_GLOBAL,TOP-poits*_Point);
         //               bool orderSell2 = trade.SellStop(2*variableVolume,SL_GLOBAL,NULL,SL_GLOBAL+10*_Point,SL_GLOBAL-5*_Point,0,0,NULL);
         //               Print("");
         //               Print("place SellStop");
         //
         //              }
         //            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && PositionGetDouble(POSITION_SL) > PositionGetDouble(POSITION_PRICE_OPEN))
         //              {
         //               trade.PositionModify(tktt,SL_GLOBAL,LOW+poits*_Point);
         //               bool orderBuy2 = trade.BuyStop(2*variableVolume,SL_GLOBAL,NULL,SL_GLOBAL-10*_Point,SL_GLOBAL+5*_Point,0,0,NULL);
         //               Print("");
         //               Print("place BuyStop");
         //              }
         //           }//if equity is true
         //
         //         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && equit==true)
         //           {
         //            SL_GLOBAL= NormalizeDouble(PositionGetDouble(POSITION_SL)+10*_Point,_Digits);
         //            trade.PositionModify(tktt,SL_GLOBAL,PositionGetDouble(POSITION_TP));
         //            Print("");
         //            Print("modify buy");
         //            equit = false;
         //           }
         //         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && equit==true)
         //           {
         //            SL_GLOBAL= NormalizeDouble(PositionGetDouble(POSITION_SL)-10*_Point,_Digits);
         //            trade.PositionModify(tktt,SL_GLOBAL,PositionGetDouble(POSITION_TP));
         //            Print("");
         //            Print("modify sell");
         //            equit = false;
         //           }


        }

     }
  }
//+------------------------------------------------------------------+





//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void drawLabel()
  {


//   color clr = clrBlue;
//   if(AccountInfoDouble(ACCOUNT_PROFIT) >0)
//      clr = clrGreen;
//   if(AccountInfoDouble(ACCOUNT_PROFIT) < 0)
//      clr = clrRed;
//   ChartSetInteger(0,CHART_FOREGROUND,0,false);
//
//   static color topclr = clrWhite;
//   if(topclr == clrWhite)
//      topclr = clrAliceBlue;
//   else
//      if(topclr == clrAliceBlue)
//         topclr = clrRed;
//      else
//         if(topclr == clrRed)
//            topclr = clrGreen;
//         else
//            if(topclr == clrGreen)
//               topclr = clrBlueViolet;
//            else
//               if(topclr == clrBlueViolet)
//                  topclr = clrPurple;
//               else
//                  if(topclr == clrPurple)
//                     topclr = clrPink;
//                  else
//                     if(topclr == clrPink)
//                        topclr = clrBrown;
//                     else
//                        if(topclr == clrBrown)
//                           topclr = clrWhite;
//
//   string name = "__Forex Slayer Robot PV1.10__";
//   //string ballance = (string)AccountInfoDouble(ACCOUNT_BALANCE);
//   //string lotsize = (string)variableVolume;
//   //string slippage_ = (string)slippage;
//   //string Tpsa_ratio = (string)TP_SL_RATIO;
//   //string Openpos = (string)OrdersTotal();
//   //string Profit = (string)NormalizeDouble(AccountInfoDouble(ACCOUNT_PROFIT),2);
//   //double prof = total_profit;
//
//
//   ObjectCreate(0,"HEADER",OBJ_RECTANGLE_LABEL,0,0,0);
//   ObjectSetInteger(0,"HEADER",OBJPROP_CORNER,CORNER_LEFT_UPPER);
//   ObjectSetInteger(0,"HEADER",OBJPROP_XDISTANCE,5);
//   ObjectSetInteger(0,"HEADER",OBJPROP_YDISTANCE,15);
//   ObjectSetInteger(0,"HEADER",OBJPROP_XSIZE,260);
//   ObjectSetInteger(0,"HEADER",OBJPROP_YSIZE,30);
//   ObjectSetInteger(0,"HEADER",OBJPROP_BORDER_TYPE,BORDER_FLAT);
//   ObjectSetInteger(0,"HEADER",OBJPROP_COLOR,clrWhite);
//   ObjectSetInteger(0,"HEADER",OBJPROP_BGCOLOR,clrBlack);
//   ObjectCreate(0,"infoname",OBJ_LABEL,0,0,0);
////ObjectSetString(0,"infoname",name,OBJ_TEXT,15,"Impact",topclr);
//   ObjectSetString(0,"infoname",OBJPROP_TEXT,name);
//   ObjectSetString(0,"infoname",OBJPROP_FONT,"Impact");
//   ObjectSetInteger(0,"infoname",OBJPROP_FONTSIZE,15);
//   ObjectSetInteger(0,"infoname",OBJPROP_COLOR,topclr);
//   ObjectSetInteger(0,"infoname",OBJPROP_XDISTANCE,20);
//   ObjectSetInteger(0,"infoname",OBJPROP_YDISTANCE,15);
//
////Main Panel
//   ObjectCreate(0,"MAIN",OBJ_RECTANGLE_LABEL,0,0,0);
//   ObjectSetInteger(0,"MAIN",OBJPROP_CORNER,CORNER_LEFT_UPPER);
//   ObjectSetInteger(0,"MAIN",OBJPROP_XDISTANCE,5);
//   ObjectSetInteger(0,"MAIN",OBJPROP_YDISTANCE,49);
//   ObjectSetInteger(0,"MAIN",OBJPROP_XSIZE,260);
//   ObjectSetInteger(0,"MAIN",OBJPROP_YSIZE,300);
//   ObjectSetInteger(0,"MAIN",OBJPROP_BORDER_TYPE,BORDER_FLAT);
//   ObjectSetInteger(0,"MAIN",OBJPROP_COLOR,clrWhite);
//   ObjectSetInteger(0,"MAIN",OBJPROP_BGCOLOR,clr);
//
//   make_detail("lot",    "LOT_SIZE =======> "+lotsize,79,clrWhite);
//   make_detail("slip",   "SLIPPAGE =======> "+slippage_,99,clrWhite);
//   make_detail("rat",    "TP_SL_RATION ===> "+Tpsa_ratio,119,clrWhite);
//
//   make_detail("bal",    "BALLANCE =======> "+ballance,149,clrWhite);
//   make_detail("opp",    "OPEN POSITIONS ==> "+Openpos,169,clrWhite);
//   make_detail("profit", "PROFIT =========> "+Profit,189,clrWhite);
//
//   color yy = clrWhite;
//   if(prof > 0)
//      yy = clrGreen;
//   if(prof < 0)
//      yy = clrRed;
//
//   make_detail("net",    "TOTAL_PROFIT ===> "+(string)prof,209,yy);


  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void make_detail(string name,string txt,int y,color clr)
  {

   ObjectDelete(1,name);
   ObjectCreate(0,name,OBJ_LABEL,0,0,0);

   ObjectSetString(0,name,OBJPROP_TEXT,txt);
   ObjectSetString(0,name,OBJPROP_FONT,"Impact");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,20);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
  }

//SIGNALS
//|                                                                  |
//+------------------------------------------------------------------+
string C_MACD()
  {
   double MACDarr[];
   double MACDSignalarr[];

   int my_macd = iCustom(_Symbol,_Period,"fslayer_rsi_of_macd_double.ex5");

   ArraySetAsSeries(MACDSignalarr,true);
   ArraySetAsSeries(MACDarr,true);

   CopyBuffer(my_macd,0,0,5,MACDarr);
   CopyBuffer(my_macd,1,0,5,MACDSignalarr);

   if(MACDSignalarr[0] > MACDarr[0])
      return "BUY";
   if(MACDSignalarr[0] < MACDarr[0])
      return "SELL";

   return "HOLD";

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string C_supres()
  {
   static bool BUY, SELL;
   double buff4[];
   double buff5[];
   double buff6[];
   double buff7[];

   int my_supres = iCustom(_Symbol,_Period,"fslayer_Shved supply and demand.ex5");

   ArraySetAsSeries(buff4,true);
   ArraySetAsSeries(buff5,true);
   ArraySetAsSeries(buff6,true);
   ArraySetAsSeries(buff7,true);


   CopyBuffer(my_supres,4,0,5,buff4);
   CopyBuffer(my_supres,5,0,5,buff5);
   CopyBuffer(my_supres,6,0,5,buff6);
   CopyBuffer(my_supres,7,0,5,buff7);

   buy_take_profit = buff5[0];
   sell_take_profit = buff6[0];

   if(iHigh(_Symbol,_Period,1) < buff4[1] && iHigh(_Symbol,_Period,1) > buff5[1])
     {
      BUY = false;
      SELL = true;

     }
   if(iLow(_Symbol,_Period,1) < buff6[1] && iLow(_Symbol,_Period,1) > buff7[1])
     {
      BUY = true;
      SELL = false;
     }

   if(iClose(_Symbol,_Period,0) < buff4[0] && SELL == true)
      return "SELL";
   if(iClose(_Symbol,_Period,0) > buff7[0] && BUY == true)
      return "BUY";


   return "NOSIGNAL";
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string C_star()
  {
   double sup[];

   int my_star = iCustom(_Symbol,_Period,"fslayer_non-repaint star Alternative.ex5");
   ArraySetAsSeries(sup,true);

   CopyBuffer(my_star,3,0,5,sup);

   if(sup[0] == 0.0 && sup[1] == 1.0)
      return "BUY";


   if(sup[1] == 0.0 && sup[0] == 1.0)
      return "SELL";


   return "HOLD";
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isNewBar()
  {
//Print("NEW BAR CHECK ROUTINE");
//--- memorize the time of opening of the last bar in the static variable
   static datetime last_time=0;
//--- current time
   datetime lastbar_time=(datetime)SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);

//--- if it is the first call of the function
   if(last_time==0)
     {
      //--- set the time and exit
      last_time=lastbar_time;
      return(false);
     }

//--- if the time differs
   if(last_time!=lastbar_time)
     {
      //--- memorize the time and return true
      last_time=lastbar_time;
      return(true);
     }
//--- if we passed to this line, then the bar is not new; return false
   return(false);
  }
//+------------------------------------------------------------------+



//removed below ModifyExistingPositions from OnTick

/*if(PositionsTotal()==0 && Profit() <0  )
{
   if(HistorySelect(0, INT_MAX))
   {
     const ulong Ticket = HistoryDealGetTicket(HistoryDealsTotal() - 1);

     if(HistoryDealGetString(Ticket, DEAL_SYMBOL) == Symbol())
     {
         if(HistoryDealGetInteger(Ticket, DEAL_TYPE) == DEAL_TYPE_SELL)
         {

            SL_GLOBAL = NormalizeDouble(SEVEN5,_Digits);
           double Bid1 = NormalizeDouble(SYMBOL_BID,_Digits);
           bool orderSell3 = trade.Sell(variableVolume,_Symbol,Bid1,SL_GLOBAL,LOW+poits*_Point,NULL);
         }
         if(HistoryDealGetInteger(Ticket, DEAL_TYPE) == DEAL_TYPE_BUY)
         {
            SL_GLOBAL = NormalizeDouble(TWEN5,_Digits);
            double Ask1 = NormalizeDouble(SYMBOL_ASK,_Digits);
           bool orderBuy3 = trade.Buy(variableVolume,_Symbol,Ask1,SL_GLOBAL,TOP-poits*_Point,NULL);
         }
     }
   }
}*/

//{dashboard nottice}
//drawLabel();
