//+------------------------------------------------------------------+
//|                                              Round_Number_EA.mq4 |
//|                                  Copyright � 2010, Kenny Hubbard |
//|                                       http://www.compu-forex.com |
//+------------------------------------------------------------------+
#property copyright "Copyright � 2010, Kenny Hubbard"
#property link      "http://www.compu-forex.com"
#property strict
/*

NOV 14
    MIGRATED TO MT5

    TODO:    INTEGRATE [round number auto trader .mq4 ] CODEBASE





*/
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Expert\Money\MoneyFixedMargin.mqh>
CTrade trade;
CPositionInfo  m_position;                   // object of CPositionInfo class
CSymbolInfo    m_symbol;                     // object of CSymbolInfo class
CAccountInfo   m_account;                    // object of CAccountInfo class
CDealInfo      m_deal;                       // object of CDealInfo class
COrderInfo     m_order;                      // object of COrderInfo class
double         m_adjusted_point;
#include <MT4orders.mqh> //USED IN BUDAK




input int     MagicNumber    = 123;

input double  inpTakeProfit     = 100;
input double  inpStopLoss       = 160;
double  TakeProfit     ;
double  StopLoss       ;
input double  Fixed_Lots     = 10;

input bool    Use_MM         = false;
input double  Risk           = 1;
input bool    Use_Trail      = false;
double  Trail_From     ;
input double  inpTrail_From= 7;
input double  inpTrail_Max      = 50.0;
double  Trail_Max     ;
input double  Trail_Percent  = 25;
input int            slippage = 1;//Slippage allowed
int   LotDigits = 1,      D_Factor = 1,   Repeats = 3;
double   Pip,   Stop_Level;
string   Order_Cmt;

//+------------------------------------------------------------------+
//| Checks if the specified filling mode is allowed                  |
//+------------------------------------------------------------------+
bool IsFillingTypeAllowed(string symbol,int fill_type)
  {
//--- Obtain the value of the property that describes allowed filling modes
   int filling=(int)SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
//--- Return true, if mode fill_type is allowed
   return((filling & fill_type)==fill_type);
  }
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!m_symbol.Name(Symbol())) // sets symbol name
     {
      Print(__FILE__," ",__FUNCTION__,", ERROR: CSymbolInfo.Name");
      return(INIT_FAILED);
     }
   RefreshRates();
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetMarginMode();
   if(IsFillingTypeAllowed(Symbol(),SYMBOL_FILLING_FOK))
      trade.SetTypeFilling(ORDER_FILLING_FOK);
   else
     {
      if(IsFillingTypeAllowed(Symbol(),SYMBOL_FILLING_IOC))
         trade.SetTypeFilling(ORDER_FILLING_IOC);
      else
         trade.SetTypeFilling(ORDER_FILLING_RETURN);
     }
   trade.SetDeviationInPoints(slippage);

   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
     {
      D_Factor=10;
      digits_adjust=10;
     }
     if(m_symbol.Digits()==2 || m_symbol.Digits()==4)
     {
      D_Factor=1;
      digits_adjust=1;
     }
     if(m_symbol.Digits()==6)
     {
      D_Factor=100;
      digits_adjust=100;
     }
     
    

   m_adjusted_point=Point()*digits_adjust;

   StopLoss       = inpStopLoss        * m_adjusted_point;
   TakeProfit     = inpTakeProfit      * m_adjusted_point;
   Trail_From   = inpTrail_From    * m_adjusted_point;
   Trail_Max   = inpTrail_Max    * m_adjusted_point;

   Stop_Level=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----

//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
void OnTick()
  {
   int    lRepeats = Repeats;
   static bool    OCO_Done;
   int    My_Orders = Trade_Count();
   
   double  ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double  bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);

   if(!My_Orders)
     {
      double My_Price_Raw = NormalizeDouble(((ask+bid)/2)*(10 *D_Factor),Digits()); ;   //* (/*10 */ D_Factor);
      //My_Price_Raw = ((Ask+Bid)/2) * (10 * D_Factor),


      double Spread =  SymbolInfoInteger(Symbol(),SYMBOL_SPREAD);//ask-bid;

      double My_Price = NormalizeDouble(MathRound(My_Price_Raw),Digits());

      Comment("PRICE RAW: "+My_Price_Raw+
              "\nMY PRICE: "+My_Price);

      double  Buy_Price;
      double  Sell_Price;

      if(My_Price>My_Price_Raw)
        {
         Print("My_Price>My_Price_Raw");


         //Buy_Price = NormalizeDouble(My_Price/(10*D_Factor),Digits());
         //Sell_Price = NormalizeDouble((My_Price-1)/(10*D_Factor),Digits());
         Buy_Price = My_Price/(10*D_Factor);
         Sell_Price = (My_Price-1)/(10*D_Factor);

         double          P_Diff_Buy =  MathAbs(ask-Buy_Price);
         double P_Diff_Sell = MathAbs(bid-Sell_Price);

         //if(MathAbs(ask-Buy_Price)<=Spread)
         //{ Print("return");  return;}
         //if(MathAbs(bid-Sell_Price)<=Spread)
         //{ Print("return");  return;}

        }
      else
        {
         Print("My_Price not My_Price_Raw");
         //Buy_Price = NormalizeDouble((My_Price+1)/(10*D_Factor),Digits());
         //Sell_Price = NormalizeDouble(My_Price/(10*D_Factor),Digits());
         Buy_Price = (My_Price+1)/(10*D_Factor);
         Sell_Price = My_Price/(10*D_Factor);

         //if(MathAbs(ask-Buy_Price)<=Spread)
         //   return;
         //if(MathAbs(bid-Sell_Price)<=Spread)
         //   return;
        }


      Do_Trades(Buy_Price, Sell_Price);
      OCO_Done = false;
     }


   if(!OCO_Done)
     {
      if(My_Orders>0)
        {
         if(Order_Taken())
            OCO_Done = Pending_Delete();
        }
     }


   if(Use_Trail)
      Trail_Stop();
//----

  }


//+------------------------------------------------------------------+
bool Do_Trades(double B_Price, double S_Price)
  {
   double    Lots = 2;// NormalizeDouble(Fixed_Lots,Digits());

//if(Use_MM)
//   Lots = NormalizeDouble(Get_Lots(),LotDigits);

   int    result = 0;


   double Sell_SL = NormalizeDouble(S_Price + StopLoss,Digits());
   double Sell_TP = NormalizeDouble(S_Price - TakeProfit,Digits());
   double Buy_TP = NormalizeDouble(B_Price + TakeProfit,Digits());
   double Buy_SL = NormalizeDouble(B_Price - StopLoss,Digits());



   int B_Ticket = OrderSend(Symbol()
                            ,OP_BUYSTOP,
                            Lots
                            ,B_Price
                            ,30
                            ,Buy_SL
                            ,Buy_TP
                            ,"ROUND NUMBER"
                            ,MagicNumber,0,CLR_NONE);

   if(B_Ticket<0)     Print("Buy ordersend error - error = " + (string)GetLastError());
   if(B_Ticket>0)       result++;
   int S_Ticket = OrderSend(Symbol(),OP_SELLSTOP,Lots,S_Price,30,Sell_SL,Sell_TP,"RND NUMBR EXP",MagicNumber,0,CLR_NONE);
   if(S_Ticket<0)       Print("Sell ordersend error - error = " + (string)GetLastError());
   if(S_Ticket>0)       result++;
   if(result==2)       return(true);

   Pending_Delete();

   return(false);
  }
//+------------------------------------------------------------------+
int Trade_Count()
  {
   int
   cnt=0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      OrderSelect(i,SELECT_BY_POS);
      if(OrderMagicNumber()==MagicNumber)
        {
         if(OrderSymbol()==Symbol())
            cnt++;
        }
     }
   return(cnt);
  }
//+------------------------------------------------------------------+
bool Order_Taken()
  {
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      OrderSelect(i,SELECT_BY_POS);
      if(OrderMagicNumber()==MagicNumber)
        {
         if(OrderSymbol()==Symbol())
           {
            if(OrderType()<2)
               return(true);
           }
        }
     }
   return(false);
  }
//+------------------------------------------------------------------+
bool Pending_Delete()
  {
   bool
   result = false;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS))
        {
         if(OrderMagicNumber()==MagicNumber)
           {
            if(OrderSymbol()==Symbol())
              {
               if(OrderType()>1)
                  result = OrderDelete(OrderTicket());
              }
           }
        }
      else
         Print("Error selecting order in Pending_Delete function - Error = " + (string)GetLastError());
     }
   return(result);
  }
//+------------------------------------------------------------------+
//double Get_Lots()
//  {
//   static bool    In_Recovery = false;
//   static int    Loss_Trades;
//
//   double lStop = StopLoss;
//   double lStop =lStop/Pip;
//
//   double Pip_Value = MarketInfo(Symbol(),MODE_TICKVALUE) * D_Factor;
//   double Lot_Value = MarketInfo(Symbol(),MODE_LOTSIZE) * D_Factor;
//   double Money_Loss = Risk/Lot_Value * AccountBalance();
//
//   Trade_Size = (Money_Loss/StopLoss)/Pip_Value;
//
//   Trade_Size = MathMax(Trade_Size,MarketInfo(Symbol(),MODE_MINLOT));
//   Trade_Size = MathMin(Trade_Size,MarketInfo(Symbol(),MODE_MAXLOT));
//
//   return(Trade_Size);
//  }
//+------------------------------------------------------------------+
bool RefreshRates()
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
     {
      Print(__FILE__," ",__FUNCTION__,", ERROR: ","RefreshRates error");
      return(false);
     }
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
     {
      Print(__FILE__," ",__FUNCTION__,", ERROR: ","Ask == 0.0 OR Bid == 0.0");
      return(false);
     }
//---
   return(true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Trail_Stop()
  {
   bool
   mod;
   int
   err;
   double
   My_Profit,
   My_Trail,
   My_SL;
//----
   double Ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double Bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);

   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if(OrderMagicNumber() == MagicNumber)
           {
            RefreshRates();
            switch(OrderType())
              {
               case OP_BUY :
                  My_Profit = Bid - OrderOpenPrice();
                  My_Trail = MathMin(My_Profit * Trail_Percent/100,Trail_Max);
                  My_SL = NormalizeDouble(Bid-My_Trail,Digits());
                  if(My_Profit > Trail_From)
                    {
                     if(Bid - My_SL > Stop_Level)
                       {
                        if(OrderStopLoss() < My_SL || OrderStopLoss() == 0)
                           mod = OrderModify(OrderTicket(),OrderOpenPrice(),My_SL,OrderTakeProfit(),0, CLR_NONE);
                       }
                    }
                  break;

               case OP_SELL :
                  My_Profit = OrderOpenPrice() - Ask;
                  My_Trail = MathMin(My_Profit * Trail_Percent/100,Trail_Max);
                  My_SL = NormalizeDouble(Ask+My_Trail,Digits());
                  if(My_Profit > Trail_From)
                    {
                     if(My_SL - Ask > Stop_Level)
                       {
                        if(My_SL < OrderStopLoss() || OrderStopLoss() == 0)
                           mod = OrderModify(OrderTicket(),OrderOpenPrice(),My_SL,OrderTakeProfit(),0,CLR_NONE);
                       }
                    }
                  break;
              }
            if(!mod)
              {
               err = GetLastError();
               if(err > 1)
                  Print("Error entering Trailing Stop - Error (" + (string)err + ")");
              }
           }
        }
      else
         Print("Error selecting order");
     }

  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
