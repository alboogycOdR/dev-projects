//+------------------------------------------------------------------+
//|                            TrendMeLeaveMe_Gold+MauroTrailing.mq4 |
//|                                              TrendMeLeaveMe_Gold |
//|                              Copyright © 2007, Eng. Waddah Attar |
//|                                 Manual Trailing for Mauro Bianco |
//|                                         Copyright © 2006, Yannis |
//|                                                 jsfero@otenet.gr |
//|                                          waddahattar@hotmail.com |
//|                                                       Mod:Dimicr |
//|                                                 dimicr@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2006-2007,Eng Waddah Attar, Yannis"
#property link      "www.metaforex.net"
//----
extern bool   AutoClose = true;
extern string BuyStop_Trend_Info = "_______________________";
extern string BuyStop_TrendName = "buystop";
extern int    BuyStop_TakeProfit = 50;
extern int    BuyStop_StopLoss = 30;
extern double BuyStop_Lot = 0.1;
extern int    BuyStop_StepActive = 10;
extern int    BuyStop_StepPrepare = 50;

extern string BuyLimit_Trend_Info = "_______________________";
extern string BuyLimit_TrendName = "buylimit";
extern int    BuyLimit_TakeProfit = 50;
extern int    BuyLimit_StopLoss = 30;
extern double BuyLimit_Lot = 0.1;
extern int    BuyLimit_StepActive = 5;
extern int    BuyLimit_StepPrepare = 50;

extern string SellStop_Trend_Info = "_______________________";
extern string SellStop_TrendName = "sellstop";
extern int    SellStop_TakeProfit = 50;
extern int    SellStop_StopLoss = 30;
extern double SellStop_Lot = 0.1;
extern int    SellStop_StepActive = 10;
extern int    SellStop_StepPrepare = 50;

extern string SellLimit_Trend_Info = "_______________________";
extern string SellLimit_TrendName = "selllimit";
extern int    SellLimit_TakeProfit = 50;
extern int    SellLimit_StopLoss = 30;
extern double SellLimit_Lot = 0.1;
extern int    SellLimit_StepActive = 5;
extern int    SellLimit_StepPrepare = 50;
extern int    Slippage = 5;

//Mauro Trailin added mod by Dimicr
extern string  Mauro_Trailing_Info = "_______________________";
extern bool    useMauroTrailing=true;
extern int     StopLoss.Pips=30;                                 // static, initial s/l. Unused if Use.Adr.for.sl.pips = true
extern int     TakeProfit.Pips=160;                               // static, initial take profit
extern int     Trail.Pips=15;                                    // trail.pips. Unused if Use.Adr.for.sl.pips=true or if value=0
extern bool    Trail.Starts.After.BreakEven=true;               // if true trailing will start after a profit of "Move.To.BreakEven.at.pips" is made
extern int     Move.To.BreakEven.at.pips=11;                      // trades in profit will move to entry price + Move.To.BreakEven.Lock.pips as soon as trade is at entry price + Move.To.BreakEven.at.pips
extern int     Move.To.BreakEven.Lock.pips=7;
extern int     Move.Trail.Every.xx.Pips=0;                       // If > 0 then ALL other s/l are dropped and trail will only move by Trail.Pips amount for every "Move.Trail.Every.Pips" in profit
extern bool    Use.ADR.for.SL.pips=false;                        // if true s/l and trail according to average daily range and tsl.divisor
extern double  tsl.divisor=0.40;
extern bool    ShowComments = true;


//------
int MagicBuyStop = 3101;
int MagicSellStop = 3102;
int MagicBuyLimit = 3103;
int MagicSellLimit = 3104;
int glbOrderType;
int glbOrderTicket;

//+---------------------- Mauro Trailing Global Variables --------------------------------------+
int b.ticket, s.ticket,slip, TodaysRange;
string DR, DR1, comment=" Mauro Trailing",ScreenComment="Mauro Trailing";
double avg.rng, rng, sum.rng, x;
bool TradingEnabled, LongTradeEnabled, ShortTradeEnabled, ShortTradeShouldClose, LongTradeShouldClose;
double TPPrice;
double pipMultiplier = 1;
double pPoint;

string tradingHoursDisplay;
string s_symbol;

int    digit;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int init()
  {
   s_symbol = Symbol(); if (StringSubstr(s_symbol,0,2)=="_t") s_symbol = StringSubstr(s_symbol,2);
   pPoint   = MarketInfo(s_symbol,MODE_POINT);
   digit    = MarketInfo(s_symbol,MODE_DIGITS);
   if (digit==2 || digit==4) pipMultiplier = 1;
   if (digit==3 || digit==5) pipMultiplier = 10;
   if (digit==6)             pipMultiplier = 100;
   
   //
   //
   //
   //
   //
   
   Comment("TrendMeLeaveMe_Gold by Waddah Attar www.metaforex.net");
   return(0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int deinit()
  {
   Comment("");
   return(0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int start()
  {
   double vP, vA, vM, sl, tp;
   
   if (useMauroTrailing && subTotalOrders()>0)
   
     {
        if (Use.ADR.for.SL.pips) {StopLoss.Pips=NormalizeDouble(Daily.Range()/pipMultiplier,digit);}
        x=NormalizeDouble(Daily.Range()*tsl.divisor,digit);
        TodaysRange=MathAbs(iHigh(s_symbol,PERIOD_D1,0)-iLow(s_symbol,PERIOD_D1,0))/pipMultiplier;
        PosCounter          ();                      // check for open positions. Sets b.ticket, s.ticket
        CheckInitialSLTP    ();
        if (Move.To.BreakEven.at.pips!=0 && (s.ticket>0 || b.ticket>0)) {MoveToBreakEven();}
        if (s.ticket>0 || b.ticket>0) {Trail.Stop();}
        comments();
     }
   
   if(ObjectFind(BuyStop_TrendName) == 0)
     {
       SetObject("Active" + BuyStop_TrendName,
                 ObjectGet(BuyStop_TrendName, OBJPROP_TIME1),
                 ObjectGet(BuyStop_TrendName, OBJPROP_PRICE1) + BuyStop_StepActive*pPoint*pipMultiplier,
                 ObjectGet(BuyStop_TrendName, OBJPROP_TIME2),
                 ObjectGet(BuyStop_TrendName, OBJPROP_PRICE2) + BuyStop_StepActive*pPoint*pipMultiplier,
                 ObjectGet(BuyStop_TrendName, OBJPROP_COLOR));
       SetObject("Prepare" + BuyStop_TrendName,
                 ObjectGet(BuyStop_TrendName, OBJPROP_TIME1),
                 ObjectGet(BuyStop_TrendName, OBJPROP_PRICE1) - BuyStop_StepPrepare*pPoint*pipMultiplier,
                 ObjectGet(BuyStop_TrendName, OBJPROP_TIME2),
                 ObjectGet(BuyStop_TrendName, OBJPROP_PRICE2) - BuyStop_StepPrepare*pPoint*pipMultiplier,
                 ObjectGet(BuyStop_TrendName, OBJPROP_COLOR));
       vA = NormalizeDouble(ObjectGetValueByShift("Active"+BuyStop_TrendName,0),digit);
       vM = NormalizeDouble(ObjectGetValueByShift(BuyStop_TrendName,0),digit);
       vP = NormalizeDouble(ObjectGetValueByShift("Prepare"+BuyStop_TrendName,0),digit);
       sl = vA - BuyStop_StopLoss*pPoint*pipMultiplier;
       tp = vA + BuyStop_TakeProfit*pPoint*pipMultiplier;
       if(Ask <= vM && Ask >= vP && OrderFind(MagicBuyStop) == false)
           if(OrderSend(s_symbol, OP_BUYSTOP, BuyStop_Lot, vA, Slippage*pipMultiplier, sl, tp,"", MagicBuyStop, 0, Green) < 0)
               Print("Err (", GetLastError(), ") Open BuyStop Price= ", vA, " SL= ", 
                     sl," TP= ", tp);

       if(Ask <= vM && Ask >= vP && OrderFind(MagicBuyStop) == true && 
          glbOrderType == OP_BUYSTOP)
         {
           OrderSelect(glbOrderTicket, SELECT_BY_TICKET, MODE_TRADES);
           if(vA != OrderOpenPrice())
               if(OrderModify(glbOrderTicket, vA, sl, tp, 0, Green) == false)
                   Print("Err (", GetLastError(), ") Modify BuyStop Price= ", vA, 
                         " SL= ", sl, " TP= ", tp);
         }

       if(Ask < vP && OrderFind(MagicBuyStop) == true && 
          glbOrderType == OP_BUYSTOP && AutoClose==true)
         {
           OrderDelete(glbOrderTicket);
         }
     }

   if(ObjectFind(BuyLimit_TrendName) == 0)
     {
       SetObject("Active" + BuyLimit_TrendName,
                 ObjectGet(BuyLimit_TrendName, OBJPROP_TIME1),
                 ObjectGet(BuyLimit_TrendName, OBJPROP_PRICE1) + BuyLimit_StepActive*pPoint*pipMultiplier,
                 ObjectGet(BuyLimit_TrendName, OBJPROP_TIME2),
                 ObjectGet(BuyLimit_TrendName, OBJPROP_PRICE2) + BuyLimit_StepActive*pPoint*pipMultiplier,
                 ObjectGet(BuyLimit_TrendName, OBJPROP_COLOR));
       SetObject("Prepare" + BuyLimit_TrendName,
                 ObjectGet(BuyLimit_TrendName, OBJPROP_TIME1),
                 ObjectGet(BuyLimit_TrendName, OBJPROP_PRICE1) + BuyLimit_StepPrepare*pPoint*pipMultiplier,
                 ObjectGet(BuyLimit_TrendName, OBJPROP_TIME2),
                 ObjectGet(BuyLimit_TrendName, OBJPROP_PRICE2) + BuyLimit_StepPrepare*pPoint*pipMultiplier,
                 ObjectGet(BuyLimit_TrendName, OBJPROP_COLOR));
       vA = NormalizeDouble(ObjectGetValueByShift("Active"+BuyLimit_TrendName,0),digit);
       vM = NormalizeDouble(ObjectGetValueByShift(BuyLimit_TrendName,0),digit);
       vP = NormalizeDouble(ObjectGetValueByShift("Prepare"+BuyLimit_TrendName,0),digit);
       sl = vA - BuyLimit_StopLoss*pPoint*pipMultiplier;
       tp = vA + BuyLimit_TakeProfit*pPoint*pipMultiplier;

       if(Ask >= vM && Ask <= vP && OrderFind(MagicBuyLimit) == false)
           if(OrderSend(s_symbol, OP_BUYLIMIT, BuyLimit_Lot, vA, Slippage*pipMultiplier, sl, tp,"", MagicBuyLimit, 0, Green) < 0)
               Print("Err (", GetLastError(), ") Open BuyLimit Price= ", vA, " SL= ", 
                     sl," TP= ", tp);

       if(Ask >= vM && Ask <= vP && OrderFind(MagicBuyLimit) == true && 
          glbOrderType == OP_BUYLIMIT)
         {
           OrderSelect(glbOrderTicket, SELECT_BY_TICKET, MODE_TRADES);
           if(vA != OrderOpenPrice())
               if(OrderModify(glbOrderTicket, vA, sl, tp, 0, Green) == false)
                   Print("Err (", GetLastError(), ") Modify BuyLimit Price= ", vA, 
                         " SL= ", sl, " TP= ", tp);
         }

       if(Ask > vP && OrderFind(MagicBuyLimit) == true && glbOrderType == OP_BUYLIMIT && AutoClose==true)
         {
           OrderDelete(glbOrderTicket);
         }
     }

   if(ObjectFind(SellStop_TrendName) == 0)
     {
       SetObject("Activate" + SellStop_TrendName,
                 ObjectGet(SellStop_TrendName, OBJPROP_TIME1),
                 ObjectGet(SellStop_TrendName, OBJPROP_PRICE1) - SellStop_StepActive*pPoint*pipMultiplier,
                 ObjectGet(SellStop_TrendName, OBJPROP_TIME2),
                 ObjectGet(SellStop_TrendName, OBJPROP_PRICE2) - SellStop_StepActive*pPoint*pipMultiplier,
                 ObjectGet(SellStop_TrendName, OBJPROP_COLOR));
       SetObject("Prepare" + SellStop_TrendName, ObjectGet(SellStop_TrendName, OBJPROP_TIME1),
                 ObjectGet(SellStop_TrendName, OBJPROP_PRICE1) + SellStop_StepPrepare*pPoint*pipMultiplier,
                 ObjectGet(SellStop_TrendName, OBJPROP_TIME2),
                 ObjectGet(SellStop_TrendName, OBJPROP_PRICE2) + SellStop_StepPrepare*pPoint*pipMultiplier,
                 ObjectGet(SellStop_TrendName, OBJPROP_COLOR));
       vA = NormalizeDouble(ObjectGetValueByShift("Activate" + SellStop_TrendName, 0),digit);
       vM = NormalizeDouble(ObjectGetValueByShift(SellStop_TrendName, 0),digit);
       vP = NormalizeDouble(ObjectGetValueByShift("Prepare" + SellStop_TrendName, 0),digit);
       sl = vA + SellStop_StopLoss*pPoint*pipMultiplier;
       tp = vA - SellStop_TakeProfit*pPoint*pipMultiplier;

       if(Bid >= vM && Bid <= vP && OrderFind(MagicSellStop) == false)
           if(OrderSend(Symbol(), OP_SELLSTOP, SellStop_Lot, vA, Slippage*pipMultiplier, sl, tp, "", MagicSellStop, 0, Red) < 0)
               Print("Err (", GetLastError(), ") Open SellStop Price= ", vA, " SL= ", sl, 
                     " TP= ", tp);

       if(Bid >= vM && Bid <= vP && OrderFind(MagicSellStop) == true && 
          glbOrderType == OP_SELLSTOP)
         {
           OrderSelect(glbOrderTicket, SELECT_BY_TICKET, MODE_TRADES);
           if(vA != OrderOpenPrice())
               if(OrderModify(glbOrderTicket, vA, sl, tp, 0, Red) == false)
                   Print("Err (", GetLastError(), ") Modify SellStop Price= ", vA, " SL= ", sl, 
                         " TP= ", tp);
         }

       if(Bid > vP && OrderFind(MagicSellStop) == true && 
          glbOrderType == OP_SELLSTOP && AutoClose==true)
         {
           OrderDelete(glbOrderTicket);
         }
     }

   if(ObjectFind(SellLimit_TrendName) == 0)
     {
       SetObject("Activate" + SellLimit_TrendName,
                 ObjectGet(SellLimit_TrendName, OBJPROP_TIME1),
                 ObjectGet(SellLimit_TrendName, OBJPROP_PRICE1) - SellLimit_StepActive*pPoint*pipMultiplier,
                 ObjectGet(SellLimit_TrendName, OBJPROP_TIME2),
                 ObjectGet(SellLimit_TrendName, OBJPROP_PRICE2) - SellLimit_StepActive*pPoint*pipMultiplier,
                 ObjectGet(SellLimit_TrendName, OBJPROP_COLOR));
       SetObject("Prepare" + SellLimit_TrendName, ObjectGet(SellLimit_TrendName, OBJPROP_TIME1),
                 ObjectGet(SellLimit_TrendName, OBJPROP_PRICE1) - SellLimit_StepPrepare*pPoint*pipMultiplier,
                 ObjectGet(SellLimit_TrendName, OBJPROP_TIME2),
                 ObjectGet(SellLimit_TrendName, OBJPROP_PRICE2) - SellLimit_StepPrepare*pPoint*pipMultiplier,
                 ObjectGet(SellLimit_TrendName, OBJPROP_COLOR));
       vA = NormalizeDouble(ObjectGetValueByShift("Activate" + SellLimit_TrendName, 0),digit);
       vM = NormalizeDouble(ObjectGetValueByShift(SellLimit_TrendName, 0),digit);
       vP = NormalizeDouble(ObjectGetValueByShift("Prepare" + SellLimit_TrendName, 0),digit);
       sl = vA + SellLimit_StopLoss*pPoint*pipMultiplier;
       tp = vA - SellLimit_TakeProfit*pPoint*pipMultiplier;

       if(Bid <= vM && Bid >= vP && OrderFind(MagicSellLimit) == false)
           if(OrderSend(Symbol(), OP_SELLLIMIT, SellLimit_Lot, vA,Slippage*pipMultiplier, sl, tp, "", MagicSellLimit, 0, Red) < 0)
               Print("Err (", GetLastError(), ") Open SellLimit Price= ", vA, " SL= ", sl, 
                     " TP= ", tp);

       if(Bid <= vM && Bid >= vP && OrderFind(MagicSellLimit) == true && 
          glbOrderType == OP_SELLLIMIT)
         {
           OrderSelect(glbOrderTicket, SELECT_BY_TICKET, MODE_TRADES);
           if(vA != OrderOpenPrice())
               if(OrderModify(glbOrderTicket, vA, sl, tp, 0, Red) == false)
                   Print("Err (", GetLastError(), ") Modify SellLimit Price= ", vA, " SL= ", sl, 
                         " TP= ", tp);
         }

       if(Bid < vP && OrderFind(MagicSellLimit) == true && 
          glbOrderType == OP_SELLLIMIT && AutoClose==true)
         {
           OrderDelete(glbOrderTicket);
         }
     }
   if (ShowComments) comments();
   return(0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool OrderFind(int Magic)
  {
   glbOrderType = -1;
   glbOrderTicket = -1;
   int total = OrdersTotal();
   bool res = false;
   for(int cnt = 0 ; cnt < total ; cnt++)
     {
       OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
       if(OrderMagicNumber() == Magic && OrderSymbol() == s_symbol)
         {
           glbOrderType   = OrderType();
           glbOrderTicket = OrderTicket();
           res = true;
         }
     }
   return(res);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetObject(string name,datetime T1,double P1,datetime T2,double P2,color clr)
  {
   if(ObjectFind(name) == -1)
     {
       ObjectCreate(name, OBJ_TREND, 0, T1, P1, T2, P2);
       ObjectSet(name, OBJPROP_COLOR, clr);
       ObjectSet(name, OBJPROP_STYLE, STYLE_DOT);
     }
   else
     {
       ObjectSet(name, OBJPROP_TIME1, T1);
       ObjectSet(name, OBJPROP_PRICE1, P1);
       ObjectSet(name, OBJPROP_TIME2, T2);
       ObjectSet(name, OBJPROP_PRICE2, P2);
       ObjectSet(name, OBJPROP_COLOR, clr);
       ObjectSet(name, OBJPROP_STYLE, STYLE_DOT);
     } 
  }
//+------------------------------------------------------------------+


//Mauro_Trailin Routines

int subTotalOrders()
{
   int
      cnt, 
      total = 0;

   for(cnt=0;cnt<OrdersTotal();cnt++)
   {
      OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
      if(OrderType()<=OP_SELL && OrderMagicNumber() >= MagicBuyStop && OrderMagicNumber()<=MagicSellLimit &&
         OrderSymbol()==s_symbol /*&&
         OrderComment()==TicketComment*/) total++;
   }
   return(total);
}

void CheckInitialSLTP()
{  int sl,tp;
   if (b.ticket>0) 
   {  OrderSelect(b.ticket,SELECT_BY_TICKET);
      if (OrderStopLoss()==0 || OrderTakeProfit()==0)
      {  if (OrderStopLoss  ()==0)  {sl=StopLoss.Pips;}
         if (OrderTakeProfit()==0)  {tp=TakeProfit.Pips;}
         if ((sl>0 && OrderStopLoss()==0) || (tp>0 && OrderTakeProfit()==0))  
         {  OrderModify(b.ticket, OrderOpenPrice(), OrderOpenPrice()-sl*pPoint*pipMultiplier,OrderOpenPrice()+tp*pPoint*pipMultiplier,OrderExpiration(),MediumSpringGreen);
            if (OrderSelect(b.ticket,SELECT_BY_TICKET,MODE_TRADES)) Print("Initial SL or TP is Set for Long Entry");
            else Print("Error setting initial SL or TP for Long Entry");
         }
      }
   }
   if (s.ticket > 0)
   {  OrderSelect(s.ticket,SELECT_BY_TICKET);
      if (OrderStopLoss()==0 || OrderTakeProfit()==0)
      {  if (OrderStopLoss  ()==0)  {sl=StopLoss.Pips;}
         if (OrderTakeProfit()==0)  {tp=TakeProfit.Pips;}
         if ((sl>0 && OrderStopLoss()==0) || (tp>0 && OrderTakeProfit()==0))  
         {  OrderModify(s.ticket, OrderOpenPrice(), OrderOpenPrice()+sl*pPoint*pipMultiplier,OrderOpenPrice()-tp*pPoint*pipMultiplier,OrderExpiration(),MediumVioletRed);
            if (OrderSelect(s.ticket,SELECT_BY_TICKET,MODE_TRADES)) Print("Initial SL or TP is Set for Short Entry");
            else Print("Error setting initial SL or TP for Short Entry");
         }
      }
   }
}

double Daily.Range()
{  if (DR==TimeToStr(CurTime(),TIME_DATE))
   {  return(NormalizeDouble(avg.rng,digit));
   }
   rng=0;sum.rng=0;avg.rng=0;
   for (int i=0;i<iBars(s_symbol,1440);i++)
   {  rng=(iHigh(s_symbol,PERIOD_D1,i)-iLow(s_symbol,PERIOD_D1,i));
      sum.rng+=rng;
   }
   double db=iBars(s_symbol,1440);
   avg.rng=sum.rng/db;
   DR=TimeToStr(CurTime(),TIME_DATE);
   return (NormalizeDouble(avg.rng,digit));
}

void PosCounter()
{  b.ticket=0;s.ticket=0;
   for (int cnt=0;cnt<=OrdersTotal();cnt++)
   {  OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol()==s_symbol && OrderMagicNumber() >= MagicBuyStop && OrderMagicNumber()<=MagicSellLimit)
      {  if (OrderType()==OP_SELL)
         {  s.ticket=OrderTicket();
         }
         if (OrderType()==OP_BUY)
         {  b.ticket=OrderTicket();
         }
      }
   }
}

void comments()
{  string s0="", s1="", s2="", s3="", swap="", sCombo="", sStr ;
   int PipsProfit;
   double AmountProfit;
   PipsProfit=0; AmountProfit=0;
   PosCounter();
   if (b.ticket>0) 
   {  OrderSelect(b.ticket,SELECT_BY_TICKET);
      PipsProfit=NormalizeDouble(((Bid - OrderOpenPrice())/pipMultiplier),digit);
      AmountProfit=OrderProfit();
   }
   else if (s.ticket>0) 
   {  OrderSelect(s.ticket,SELECT_BY_TICKET);
      PipsProfit=NormalizeDouble(((OrderOpenPrice()-Ask)/pipMultiplier),digit);
      AmountProfit=OrderProfit();
   }
   if (Move.To.BreakEven.at.pips>0) s1="s/l will move to b/e after: "+Move.To.BreakEven.at.pips+" pips   and lock: "+Move.To.BreakEven.Lock.pips+" pips"+"\n\n";
   else                             s1="";
   Comment( ScreenComment,"\n",
            "Today\'s Range: ",TodaysRange,"\n",
            "s/l: ",StopLoss.Pips,"  tp:",TakeProfit.Pips,"  trail:",Trail.Pips,"\n",
            s1
          );
}

void Trail.With.ADR(int AfterBE)
{  double bsl, b.tsl, ssl, s.tsl;
   PosCounter();
   // x=Minimum Wave Range of Average Daily Range Trailing Stop Calculation
   if (AfterBE==0) // Trail Starts immediately
   {  if(b.ticket>0)
      {  bsl=NormalizeDouble(x,digit);
         b.tsl=0;
         OrderSelect(b.ticket,SELECT_BY_TICKET);
         //if stoploss is less than minimum wave range, set bsl to current SL
         if (OrderStopLoss()<OrderOpenPrice() && OrderOpenPrice()-OrderStopLoss()<x)
         {  bsl=OrderOpenPrice()-OrderStopLoss();
         }
         //if stoploss is equal to, or greater than minimum wave range, set bsl to minimum wave range
         if (OrderStopLoss()<OrderOpenPrice() && OrderOpenPrice()-OrderStopLoss()>=x)
         {  bsl=NormalizeDouble(x,digit);
         }
         //determine if stoploss should be modified
         if (Bid>(OrderOpenPrice()+bsl) && OrderStopLoss()<(OrderOpenPrice()+(Bid-(OrderOpenPrice()+bsl))))
         {  b.tsl=NormalizeDouble(OrderOpenPrice()+(Bid-(OrderOpenPrice()+bsl)),digit);
            Print("b.tsl ",b.tsl);
            if (OrderStopLoss()<b.tsl)
            {  OrderModify(b.ticket,OrderOpenPrice(),b.tsl,OrderTakeProfit(),OrderExpiration(),MediumSpringGreen);
            }
         }
      }
      if(s.ticket>0)
      {  ssl=NormalizeDouble(x,digit);
         s.tsl=0;
         OrderSelect(s.ticket,SELECT_BY_TICKET);
         //if stoploss is less than minimum wave range, set ssl to current SL
         if (OrderStopLoss()>OrderOpenPrice() && OrderStopLoss()-OrderOpenPrice()<x)
         {  ssl=OrderStopLoss()-OrderOpenPrice();
         }
         //if stoploss is equal to, or greater than minimum wave range, set bsl to minimum wave range
         if (OrderStopLoss()>OrderOpenPrice() && OrderStopLoss()-OrderOpenPrice()>=x)
         {  ssl=NormalizeDouble(x,digit);
         }
         //determine if stoploss should be modified
         if (Ask<(OrderOpenPrice()-ssl) && OrderStopLoss()>(OrderOpenPrice()-(OrderOpenPrice()-ssl)-Ask))
         {  s.tsl=NormalizeDouble(OrderOpenPrice()-((OrderOpenPrice()-ssl)-Ask),digit);
            Print("s.tsl ",s.tsl);
            if(OrderStopLoss()>s.tsl)
            {  OrderModify(s.ticket,OrderOpenPrice(),s.tsl,OrderTakeProfit(),OrderExpiration(),MediumVioletRed);
            }
         }
      }
   }
   else // If Trail.Starts.After.BreakEven
   {  if (b.ticket>0)
      {  bsl=NormalizeDouble(x,digit);
         b.tsl=0;
         OrderSelect(b.ticket,SELECT_BY_TICKET);
         if (Bid>=(OrderOpenPrice()+(Move.To.BreakEven.at.pips*pPoint*pipMultiplier)))
         {  //if stoploss is less than minimum wave range, set bsl to current SL
            if (OrderStopLoss()<OrderOpenPrice() && OrderOpenPrice()-OrderStopLoss()<x)
            {  bsl=OrderOpenPrice()-OrderStopLoss();
            }
            //if stoploss is equal to, or greater than minimum wave range, set bsl to minimum wave range
            if (OrderStopLoss()<OrderOpenPrice() && OrderOpenPrice()-OrderStopLoss()>=x)
            {  bsl=NormalizeDouble(x,digit);
            }
            //determine if stoploss should be modified
            if (Bid>(OrderOpenPrice()+bsl) && OrderStopLoss()<(OrderOpenPrice()+(Bid-(OrderOpenPrice()+bsl))))
            {  b.tsl=NormalizeDouble(OrderOpenPrice()+(Bid-(OrderOpenPrice()+bsl)),digit);
               Print("b.tsl ",b.tsl);
               if (OrderStopLoss()<b.tsl)
               {  OrderModify(b.ticket,OrderOpenPrice(),b.tsl,OrderTakeProfit(),OrderExpiration(),MediumSpringGreen);
               }
            }
         }
      }
      if (s.ticket>0)
      {  ssl=NormalizeDouble(x,digit);
         s.tsl=0;
         OrderSelect(s.ticket,SELECT_BY_TICKET);
         if (Ask<=(OrderOpenPrice()-(Move.To.BreakEven.at.pips*pPoint*pipMultiplier)))
         {  //if stoploss is less than minimum wave range, set ssl to current SL
            if(OrderStopLoss()>OrderOpenPrice() && OrderStopLoss()-OrderOpenPrice()<x)
            {  ssl=OrderStopLoss()-OrderOpenPrice();
            }
            //if stoploss is equal to, or greater than minimum wave range, set bsl to minimum wave range
            if(OrderStopLoss()>OrderOpenPrice() && OrderStopLoss()-OrderOpenPrice()>=x)
            {  ssl=NormalizeDouble(x,digit);
            }
            //determine if stoploss should be modified
            if(Ask<(OrderOpenPrice()-ssl) && OrderStopLoss()>(OrderOpenPrice()-(OrderOpenPrice()-ssl)-Ask))
            {  s.tsl=NormalizeDouble(OrderOpenPrice()-((OrderOpenPrice()-ssl)-Ask),digit);
               Print("s.tsl ",s.tsl);
               if(OrderStopLoss()>s.tsl)
               {  OrderModify(s.ticket,OrderOpenPrice(),s.tsl,OrderTakeProfit(),OrderExpiration(),MediumVioletRed);
               }
            }
         }
      }
   }
}

void Trail.With.Standard.Trailing(int AfterBE)
{  double bsl, b.tsl, ssl, s.tsl;
   PosCounter();
   if (AfterBE==0)
   {  if (b.ticket>0)
      {  bsl=Trail.Pips*pPoint*pipMultiplier;
         OrderSelect(b.ticket,SELECT_BY_TICKET);
         //determine if stoploss should be modified
         if(Bid>(OrderOpenPrice()+bsl) && OrderStopLoss()<(OrderOpenPrice()+(Bid-(OrderOpenPrice()+bsl))))
         {  b.tsl=NormalizeDouble(OrderOpenPrice()+(Bid-(OrderOpenPrice()+bsl)),digit);
            Print("b.tsl ",b.tsl);
            if (OrderStopLoss()<b.tsl)
            {  OrderModify(b.ticket,OrderOpenPrice(),b.tsl,OrderTakeProfit(),OrderExpiration(),MediumSpringGreen);
            }
         }
      }
      if(s.ticket>0)
      {  ssl=Trail.Pips*pPoint*pipMultiplier;
         //determine if stoploss should be modified
         OrderSelect(s.ticket,SELECT_BY_TICKET);
         if (Ask<(OrderOpenPrice()-ssl) && OrderStopLoss()>(OrderOpenPrice()-(OrderOpenPrice()-ssl)-Ask))
         {  s.tsl=NormalizeDouble(OrderOpenPrice()-((OrderOpenPrice()-ssl)-Ask),digit);
            Print("s.tsl ",s.tsl);
            if (OrderStopLoss()>s.tsl)
            {  OrderModify(s.ticket,OrderOpenPrice(),s.tsl,OrderTakeProfit(),OrderExpiration(),MediumVioletRed);
            }
         }
      }
   }
   else // If Trail.Starts.After.BreakEven
   {  if (b.ticket>0)
      {  OrderSelect(b.ticket,SELECT_BY_TICKET);
         if (Bid>=(OrderOpenPrice()+(Move.To.BreakEven.at.pips*pPoint*pipMultiplier)))
         {  bsl=Trail.Pips*pPoint*pipMultiplier;
            if (Bid>(OrderOpenPrice()+bsl) && OrderStopLoss()<(OrderOpenPrice()+(Bid-(OrderOpenPrice()+bsl))))
            {  b.tsl=NormalizeDouble(OrderOpenPrice()+(Bid-(OrderOpenPrice()+bsl)),digit);
               Print("b.tsl ",b.tsl);
               if (OrderStopLoss()<b.tsl)
               {  OrderModify(b.ticket,OrderOpenPrice(),b.tsl,OrderTakeProfit(),OrderExpiration(),MediumSpringGreen);
               }
            }
         }
      }
      if(s.ticket>0)
      {  OrderSelect(s.ticket,SELECT_BY_TICKET);
         if (Ask<=(OrderOpenPrice()-(Move.To.BreakEven.at.pips*pPoint*pipMultiplier)))
         {  ssl=Trail.Pips*pPoint*pipMultiplier;
            //determine if stoploss should be modified
            if(Ask<(OrderOpenPrice()-ssl) && OrderStopLoss()>(OrderOpenPrice()-(OrderOpenPrice()-ssl)-Ask))
            {  s.tsl=NormalizeDouble(OrderOpenPrice()-((OrderOpenPrice()-ssl)-Ask),digit);
               Print("s.tsl ",s.tsl);
               if(OrderStopLoss()>s.tsl)
               {  OrderModify(s.ticket,OrderOpenPrice(),s.tsl,OrderTakeProfit(),OrderExpiration(),MediumVioletRed);
               }
            }
         }
      }
   }
}


void Trail.With.Every.xx.Pips()
{  double bsl, b.tsl, ssl, s.tsl, CurrProfit;
   int Factor;
   PosCounter();
   if (b.ticket>0)
   {  OrderSelect(b.ticket,SELECT_BY_TICKET);
      CurrProfit=((Bid-OrderOpenPrice())/pipMultiplier);
      if (CurrProfit>=Move.Trail.Every.xx.Pips)
      {  Factor=MathFloor(CurrProfit/Move.Trail.Every.xx.Pips);
         bsl=Factor*Trail.Pips*pPoint*pipMultiplier;
         //determine if stoploss should be modified
         if(Bid>(OrderOpenPrice()+bsl) && OrderStopLoss()<(OrderOpenPrice()+(Bid-(OrderOpenPrice()+bsl))))
         {  b.tsl=NormalizeDouble(OrderOpenPrice()+(Bid-(OrderOpenPrice()+bsl)),digit);
            Print("b.tsl ",b.tsl);
            if (OrderStopLoss()<b.tsl)
            {  OrderModify(b.ticket,OrderOpenPrice(),b.tsl,OrderTakeProfit(),OrderExpiration(),MediumSpringGreen);
            }
         }
      }
   }
   if(s.ticket>0)
   {  OrderSelect(s.ticket,SELECT_BY_TICKET);
      CurrProfit=((OrderOpenPrice()-Ask)/pipMultiplier);
      if (CurrProfit>=Move.Trail.Every.xx.Pips)
      {  Factor=MathFloor(CurrProfit/Move.Trail.Every.xx.Pips);
         ssl=Factor*Trail.Pips*Point*pipMultiplier;
         //determine if stoploss should be modified
         if (Ask<(OrderOpenPrice()-ssl) && OrderStopLoss()>(OrderOpenPrice()-(OrderOpenPrice()-ssl)-Ask))
         {  s.tsl=NormalizeDouble(OrderOpenPrice()-((OrderOpenPrice()-ssl)-Ask),digit);
            Print("s.tsl ",s.tsl);
            if (OrderStopLoss()>s.tsl)
            {  OrderModify(s.ticket,OrderOpenPrice(),s.tsl,OrderTakeProfit(),OrderExpiration(),MediumVioletRed);
            }
         }
      }
   }
}

void Trail.Stop()
{  if (Move.Trail.Every.xx.Pips>0 && Trail.Pips>0)
   {  Trail.With.Every.xx.Pips();
   }
   else
   {  if (Use.ADR.for.SL.pips)
      {  if (Trail.Starts.After.BreakEven)   Trail.With.ADR(1);
         else                                Trail.With.ADR(0);
      }
      else if (Trail.Pips>0)
      {  if (Trail.Starts.After.BreakEven)   Trail.With.Standard.Trailing(1);
         else                                Trail.With.Standard.Trailing(0);
      }
   }
}

void MoveToBreakEven()
{  PosCounter();
   if (b.ticket > 0)
   {  OrderSelect(b.ticket,SELECT_BY_TICKET);
      if (OrderStopLoss()<OrderOpenPrice())
      {  if (Bid >((Move.To.BreakEven.at.pips*pPoint*pipMultiplier) +OrderOpenPrice()))
         {  OrderModify(b.ticket, OrderOpenPrice(), (OrderOpenPrice()+(Move.To.BreakEven.Lock.pips*pPoint*pipMultiplier)),OrderTakeProfit(),OrderExpiration(),MediumSpringGreen);
            if (OrderSelect(b.ticket,SELECT_BY_TICKET,MODE_TRADES)) Print("Long StopLoss Moved to BE at : ",OrderStopLoss());
            else Print("Error moving Long StopLoss to BE: ",GetLastError());
         }
      }
   }
   if (s.ticket > 0)
   {  OrderSelect(s.ticket,SELECT_BY_TICKET);
      if (OrderStopLoss()>OrderOpenPrice())
      {  if ( Ask < (OrderOpenPrice()-(Move.To.BreakEven.at.pips*pPoint*pipMultiplier)))
         {  OrderModify(OrderTicket(), OrderOpenPrice(), (OrderOpenPrice()-(Move.To.BreakEven.Lock.pips*pPoint*pipMultiplier)),OrderTakeProfit(),OrderExpiration(),MediumVioletRed);
            if(OrderSelect(s.ticket,SELECT_BY_TICKET,MODE_TRADES)) Print("Short StopLoss Moved to BE at : ",OrderStopLoss());
            else Print("Error moving Short StopLoss to BE: ",GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+