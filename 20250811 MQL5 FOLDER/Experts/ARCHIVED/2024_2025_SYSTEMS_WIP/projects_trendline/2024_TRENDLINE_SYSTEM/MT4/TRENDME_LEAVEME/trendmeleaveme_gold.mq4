//+------------------------------------------------------------------+
//|                                          TrendMeLeaveMe_Gold.mq4 |
//|                              Copyright © 2007, Eng. Waddah Attar |
//|                                          waddahattar@hotmail.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2007,Eng Waddah Attar"
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

//------
int MagicBuyStop = 3101;
int MagicSellStop = 3102;
int MagicBuyLimit = 3103;
int MagicSellLimit = 3104;
int glbOrderType;
int glbOrderTicket;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int init()
  {
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
   if(ObjectFind(BuyStop_TrendName) == 0)
     {
       SetObject("Active" + BuyStop_TrendName,
                 ObjectGet(BuyStop_TrendName, OBJPROP_TIME1),
                 ObjectGet(BuyStop_TrendName, OBJPROP_PRICE1) + BuyStop_StepActive*Point,
                 ObjectGet(BuyStop_TrendName, OBJPROP_TIME2),
                 ObjectGet(BuyStop_TrendName, OBJPROP_PRICE2) + BuyStop_StepActive*Point,
                 ObjectGet(BuyStop_TrendName, OBJPROP_COLOR));
       SetObject("Prepare" + BuyStop_TrendName,
                 ObjectGet(BuyStop_TrendName, OBJPROP_TIME1),
                 ObjectGet(BuyStop_TrendName, OBJPROP_PRICE1) - BuyStop_StepPrepare*Point,
                 ObjectGet(BuyStop_TrendName, OBJPROP_TIME2),
                 ObjectGet(BuyStop_TrendName, OBJPROP_PRICE2) - BuyStop_StepPrepare*Point,
                 ObjectGet(BuyStop_TrendName, OBJPROP_COLOR));
       vA = NormalizeDouble(ObjectGetValueByShift("Active"+BuyStop_TrendName,0),Digits);
       vM = NormalizeDouble(ObjectGetValueByShift(BuyStop_TrendName,0),Digits);
       vP = NormalizeDouble(ObjectGetValueByShift("Prepare"+BuyStop_TrendName,0),Digits);
       sl = vA - BuyStop_StopLoss*Point;
       tp = vA + BuyStop_TakeProfit*Point;
       if(Ask <= vM && Ask >= vP && OrderFind(MagicBuyStop) == false)
           if(OrderSend(Symbol(), OP_BUYSTOP, BuyStop_Lot, vA, 3, sl, tp,
              "", MagicBuyStop, 0, Green) < 0)
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
                 ObjectGet(BuyLimit_TrendName, OBJPROP_PRICE1) + BuyLimit_StepActive*Point,
                 ObjectGet(BuyLimit_TrendName, OBJPROP_TIME2),
                 ObjectGet(BuyLimit_TrendName, OBJPROP_PRICE2) + BuyLimit_StepActive*Point,
                 ObjectGet(BuyLimit_TrendName, OBJPROP_COLOR));
       SetObject("Prepare" + BuyLimit_TrendName,
                 ObjectGet(BuyLimit_TrendName, OBJPROP_TIME1),
                 ObjectGet(BuyLimit_TrendName, OBJPROP_PRICE1) + BuyLimit_StepPrepare*Point,
                 ObjectGet(BuyLimit_TrendName, OBJPROP_TIME2),
                 ObjectGet(BuyLimit_TrendName, OBJPROP_PRICE2) + BuyLimit_StepPrepare*Point,
                 ObjectGet(BuyLimit_TrendName, OBJPROP_COLOR));
       vA = NormalizeDouble(ObjectGetValueByShift("Active"+BuyLimit_TrendName,0),Digits);
       vM = NormalizeDouble(ObjectGetValueByShift(BuyLimit_TrendName,0),Digits);
       vP = NormalizeDouble(ObjectGetValueByShift("Prepare"+BuyLimit_TrendName,0),Digits);
       sl = vA - BuyLimit_StopLoss*Point;
       tp = vA + BuyLimit_TakeProfit*Point;

       if(Ask >= vM && Ask <= vP && OrderFind(MagicBuyLimit) == false)
           if(OrderSend(Symbol(), OP_BUYLIMIT, BuyLimit_Lot, vA, 3, sl, tp,
              "", MagicBuyLimit, 0, Green) < 0)
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

       if(Ask > vP && OrderFind(MagicBuyLimit) == true && 
          glbOrderType == OP_BUYLIMIT && AutoClose==true)
         {
           OrderDelete(glbOrderTicket);
         }
     }

   if(ObjectFind(SellStop_TrendName) == 0)
     {
       SetObject("Activate" + SellStop_TrendName,
                 ObjectGet(SellStop_TrendName, OBJPROP_TIME1),
                 ObjectGet(SellStop_TrendName, OBJPROP_PRICE1) - SellStop_StepActive*Point,
                 ObjectGet(SellStop_TrendName, OBJPROP_TIME2),
                 ObjectGet(SellStop_TrendName, OBJPROP_PRICE2) - SellStop_StepActive*Point,
                 ObjectGet(SellStop_TrendName, OBJPROP_COLOR));
       SetObject("Prepare" + SellStop_TrendName, ObjectGet(SellStop_TrendName, OBJPROP_TIME1),
                 ObjectGet(SellStop_TrendName, OBJPROP_PRICE1) + SellStop_StepPrepare*Point,
                 ObjectGet(SellStop_TrendName, OBJPROP_TIME2),
                 ObjectGet(SellStop_TrendName, OBJPROP_PRICE2) + SellStop_StepPrepare*Point,
                 ObjectGet(SellStop_TrendName, OBJPROP_COLOR));
       vA = NormalizeDouble(ObjectGetValueByShift("Activate" + SellStop_TrendName, 0), Digits);
       vM = NormalizeDouble(ObjectGetValueByShift(SellStop_TrendName, 0), Digits);
       vP = NormalizeDouble(ObjectGetValueByShift("Prepare" + SellStop_TrendName, 0), Digits);
       sl = vA + SellStop_StopLoss*Point;
       tp = vA - SellStop_TakeProfit*Point;

       if(Bid >= vM && Bid <= vP && OrderFind(MagicSellStop) == false)
           if(OrderSend(Symbol(), OP_SELLSTOP, SellStop_Lot, vA, 3, sl, tp, "", 
              MagicSellStop, 0, Red) < 0)
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
                 ObjectGet(SellLimit_TrendName, OBJPROP_PRICE1) - SellLimit_StepActive*Point,
                 ObjectGet(SellLimit_TrendName, OBJPROP_TIME2),
                 ObjectGet(SellLimit_TrendName, OBJPROP_PRICE2) - SellLimit_StepActive*Point,
                 ObjectGet(SellLimit_TrendName, OBJPROP_COLOR));
       SetObject("Prepare" + SellLimit_TrendName, ObjectGet(SellLimit_TrendName, OBJPROP_TIME1),
                 ObjectGet(SellLimit_TrendName, OBJPROP_PRICE1) - SellLimit_StepPrepare*Point,
                 ObjectGet(SellLimit_TrendName, OBJPROP_TIME2),
                 ObjectGet(SellLimit_TrendName, OBJPROP_PRICE2) - SellLimit_StepPrepare*Point,
                 ObjectGet(SellLimit_TrendName, OBJPROP_COLOR));
       vA = NormalizeDouble(ObjectGetValueByShift("Activate" + SellLimit_TrendName, 0), Digits);
       vM = NormalizeDouble(ObjectGetValueByShift(SellLimit_TrendName, 0), Digits);
       vP = NormalizeDouble(ObjectGetValueByShift("Prepare" + SellLimit_TrendName, 0), Digits);
       sl = vA + SellLimit_StopLoss*Point;
       tp = vA - SellLimit_TakeProfit*Point;

       if(Bid <= vM && Bid >= vP && OrderFind(MagicSellLimit) == false)
           if(OrderSend(Symbol(), OP_SELLLIMIT, SellLimit_Lot, vA, 3, sl, tp, "", 
              MagicSellLimit, 0, Red) < 0)
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
       if(OrderMagicNumber() == Magic && OrderSymbol() == Symbol())
         {
           glbOrderType = OrderType();
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

