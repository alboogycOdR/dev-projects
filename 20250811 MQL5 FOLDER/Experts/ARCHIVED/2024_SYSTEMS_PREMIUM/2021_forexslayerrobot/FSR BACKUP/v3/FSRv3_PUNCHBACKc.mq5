//+------------------------------------------------------------------+
//|                                            Punch_Back_System.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, Forex market killer."
#property link      "https://forexmarketkilller.com"
#property version   "1.001"
/*
https://youtu.be/TAM5dicWjNM



*/
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>

ulong                      InpMagic             = 7112123999;    // Magic number
input double               inpVolume=0.5; //lotsize
double                     TRADELOT=0;
double                     tradevolume;
input bool                 MAXVOLS=false;
input bool MINVOLS=true;

input bool TIGHT_TP=true;//varible to set to STOPS amount

input ushort               InpTrailingStop            = 390;  //Trailing stop in pts
input ushort               InpTrailingStep            = 10;//Trailing step in pts
double                     ExtMA_MinimumDistance=0.0;



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input ushort   InpBreakeven         = 1;     // Breakeven (in pips) ("0" -> parameter "Breakeven" is off)
input ushort   InpBreakevenProfit   = 25;    // Breakeven profit (in pips)
int            Breakeven                   = 5;//45;           //Breakeven in points
int            Distance                    = 1;//5;            //Breakeven distance in points from open price of position


input uint                 InpStopLoss          = 20000; //Stoploss in points
input uint                 InpTakeProfit        = 5000;//Takeprofit in points

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CTrade         m_trade;                      // object of CTrade class
CSymbolInfo    m_symbol;                     // object of CSymbolInfo class
CPositionInfo  m_position;                   // object of CPositionInfo class
CAccountInfo   m_account;                    // object of CAccountInfo class
CDealInfo      m_deal;                       // object of CDealInfo class
COrderInfo     m_order;                      // object of COrderInfo class


int my_star,my_supres;
int my_macd;
input double   Volume = 0.1;
input int      Positions_to_open = 1;
input int      start=0,end=10;
int            slippage = 1;
int            TP_SL_RATIO = 1;
bool           SHOW_LEVELS = true;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double currentbalance = AccountInfoDouble(ACCOUNT_BALANCE);
double total_profit = 0;
double buy_take_profit, sell_take_profit;


ulong                      InpDeviation         = 0;          // Deviation
double                     m_stop_loss                = 0.0;      // Stop Loss                  -> double
double                     m_take_profit              = 0.0;      // Take Profit                -> double
double                     ExtStopLoss=0.0;
double                     ExtTakeProfit=0.0;

double                     ExtTrailingStop=0.0;
double                     ExtTrailingStep=0.0;
double                     ExtBreakeven=0.0;
double                     ExtBreakevenProfit=0.0;

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
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
int OnInit()
  {
   ResetLastError();
   if(!m_symbol.Name(Symbol())) // sets symbol name
     {
      Print(__FILE__," ",__FUNCTION__,", ERROR: CSymbolInfo.Name");
      return(INIT_FAILED);
     }
   RefreshRates();
   m_trade.SetExpertMagicNumber(InpMagic);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(m_symbol.Name());
   m_trade.SetDeviationInPoints(InpDeviation);

//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_stop_loss                = InpStopLoss                 * Point();
   m_take_profit              = InpTakeProfit               * Point();
   ExtTrailingStop            = InpTrailingStop             * Point();
   ExtTrailingStep            = InpTrailingStep             * Point();
   ExtBreakeven               = InpBreakeven       * Point();
   ExtBreakevenProfit         = InpBreakevenProfit * Point();


//--- create handle of the indicator iFractals
   my_star =iCustom(Symbol(),Period(),"fsr.indicators/fslayer_non-repaint star Alternative.ex5");
//--- if the handle is not created
   if(my_star ==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the iFractals indicator for the symbol %s/%s, error code %d",
                  Symbol(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early
      return(INIT_FAILED);
     }

   my_macd = iCustom(Symbol(),Period(),"fsr.indicators/fslayer_rsi_of_macd_double.ex5");
//--- if the handle is not created
   if(my_macd ==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the my_macd indicator for the symbol %s/%s, error code %d",
                  Symbol(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early
      return(INIT_FAILED);
     }


//--- create handle of the indicator iFractals
   my_supres =iCustom(Symbol(),Period(),"fsr.indicators/shved_supply_and_demand_v1.4.ex5");
//--- if the handle is not created
   if(my_supres ==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the iFractals indicator for the symbol %s/%s, error code %d",
                  Symbol(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early
      return(INIT_FAILED);
     }







   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

  }


//SIGNALS
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string C_MACD()
  {
   double MACDarr[];
   double MACDSignalarr[];



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
   ArraySetAsSeries(buff4,true);
   CopyBuffer(my_supres,4,0,5,buff4);
   double buff5[];
   ArraySetAsSeries(buff5,true);
   CopyBuffer(my_supres,5,0,5,buff5);
   double buff6[];
   ArraySetAsSeries(buff6,true);
   CopyBuffer(my_supres,6,0,5,buff6);
   double buff7[];
   ArraySetAsSeries(buff7,true);
   CopyBuffer(my_supres,7,0,5,buff7);




   buy_take_profit = buff5[0];
   sell_take_profit = buff6[0];
   /*

      PlotIndexSetString(4,PLOT_LABEL,"Resistant Zone High");
      PlotIndexSetString(5,PLOT_LABEL,"Resistant Zone Low");
      PlotIndexSetString(6,PLOT_LABEL,"Support Zone High");
      PlotIndexSetString(7,PLOT_LABEL,"Support Zone Low");

        ---------------------------buff4
       |  iHigh(1)
        ---------------------------buff5       buy takeprofit

       ----------------------------buff6       sell takeprofit
       |  iLow(1)
       ----------------------------buff7

   */
   if(iHigh(Symbol(),Period(),1) < buff4[1] && iHigh(Symbol(),Period(),1) > buff5[1])
     {
      BUY = false;
      SELL = true;

     }
   if(iLow(Symbol(),Period(),1) < buff6[1] && iLow(Symbol(),Period(),1) > buff7[1])
     {
      BUY = true;
      SELL = false;
     }

//REFERENCE
//========================
//zone strength
//#define ZONE_WEAK      0.0
//#define ZONE_TURNCOAT  1.0
//#define ZONE_UNTESTED  2.0
//#define ZONE_VERIFIED  3.0
//#define ZONE_PROVEN    4.0

//Print("var#21 name:"+GlobalVariableName(21)," = value:",GlobalVariableGet(GlobalVariableName(21)));
//Print("var#22 name:"+GlobalVariableName(22)," = value:",GlobalVariableGet(GlobalVariableName(22)));
//Print("var#23 name:"+GlobalVariableName(23)," = value:",GlobalVariableGet(GlobalVariableName(23)));
//Print("var#24 name:"+GlobalVariableName(24)," = value:",GlobalVariableGet(GlobalVariableName(24)));
//Print("var#25 name:"+GlobalVariableName(25)," = value:",GlobalVariableGet(GlobalVariableName(25)));
Print("SSSR_Count_"+Symbol()+Period());
Print(" count of zones   "+GlobalVariableGet("SSSR_Count_"+Symbol()+Period()));
//REFERENCE
//========================
// check for variable names to begin with "gvar" (this example can be found in the sGVTestAllNames2 script attached below):
//   Alert("=== Start ===");
//   int total=GlobalVariablesTotal();
//   for(int i=0;i<total;i++){
//      if(StringFind(GlobalVariableName(i),"gvar",0)==0){
//         Alert(GlobalVariableName(i)," = ",GlobalVariableGet(GlobalVariableName(i)));
//      }
//   }

   if(iClose(Symbol(),Period(),1) < buff4[1] && (iClose(Symbol(),Period(),1) >= buff5[1]))
     {
      //Print("[||||||||RESISTENCE ZONE||||||||]  ");
     }
   if(iClose(Symbol(),Period(),1) < buff6[1] && (iClose(Symbol(),Period(),1) >= buff7[1]))
     {
      //Print("[||||||||SUPPORT ZONE||||||||] ");
     }

   if(iClose(Symbol(),Period(),0) < buff4[0] && SELL == true)
      return "SELL";
   if(iClose(Symbol(),Period(),0) > buff7[0] && BUY == true)
      return "BUY";


   return "NOSIGNAL";
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string C_star()
  {
   double sup[];
   ArraySetAsSeries(sup,true);

   CopyBuffer(my_star,3,0,5,sup);

   if(sup[0] == 0.0 && sup[1] == 1.0)
      return "BUY";
   if(sup[1] == 0.0 && sup[0] == 1.0)
      return "SELL";
   return "HOLD";
  }


//+------------------------------------------------------------------+
void buy(const string buycomment)
  {

//Print(CANDLE_TIME_LEFT);

   double buyask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double buybid=SymbolInfoDouble(Symbol(), SYMBOL_BID);


   double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();


   double sl=buyask-m_stop_loss;
   if(sl>0.0)
      if(buybid-sl<stops)
         sl=buybid-stops;

   double tp=buyask+m_take_profit;
   if(tp>0.0)
      if(tp-buyask<stops)
         tp=buyask+stops;


   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

//--- Initialize the MqlTradeRequest structure to open SELL position
   request.action = TRADE_ACTION_DEAL;
   request.symbol = Symbol();
   request.magic       = InpMagic;
   request.type   = ORDER_TYPE_BUY;
   request.price  = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   if(MAXVOLS)
     {request.volume =SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);}
   else
      if(MINVOLS)
        {
         request.volume =SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
        }
      else
        {
         request.volume = inpVolume;
        }
   request.comment         =buycomment;
   request.sl = sl;
   request.tp = tp;
   if(TIGHT_TP)
     {
      request.tp = buyask+(stops+10*Point());
     }
   else
     {
      request.tp = tp;
     }

   request.deviation=0;
   request.type_filling=ORDER_FILLING_FOK;


   if(!OrderSend(request,result) || result.deal==0)
     {
      Print("m_trade.ResultDeal(): "+(string)m_trade.ResultDeal());
      Print("Result Retcode: ",m_trade.ResultRetcode(),
            ", description of result: ",m_trade.ResultRetcodeDescription());
     }

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void sell(const string sellcomment)
  {

//Print(CANDLE_TIME_LEFT);

   double sellask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double sellbid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
//----------
   double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
   double sl=sellbid+m_stop_loss;
   if(sl>0.0)
      if(sl-sellask<stops)
         sl=sellask+stops;
   double tp=sellbid-m_take_profit;
   if(tp>0.0)
      if(sellbid-tp<stops)
         tp=sellbid-stops;




   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

//--- Initialize the MqlTradeRequest structure to open SELL position
   request.action = TRADE_ACTION_DEAL;
   request.symbol = Symbol();
   request.magic       = InpMagic;
   request.type   = ORDER_TYPE_SELL;
   request.price  = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   if(MAXVOLS)
     {request.volume =SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);}
   else
      if(MINVOLS)
        {
         request.volume =SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
        }
      else
        {
         request.volume = inpVolume;
        }
   request.comment         =sellcomment;
   request.sl = sl;

   if(TIGHT_TP)
     {
      request.tp = sellbid-(stops+10*Point());
     }
   else
     {
      request.tp = tp;
     }

   request.deviation=0;
   request.type_filling=ORDER_FILLING_FOK;

   if(!OrderSend(request,result) || result.deal==0)
     {
      Print("m_trade.ResultDeal(): "+(string)m_trade.ResultDeal());
      Print("Result Retcode: ",m_trade.ResultRetcode(),
            ", description of result: ",m_trade.ResultRetcodeDescription());
     }
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
void OnTick()
  {

   total_profit = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE)-currentbalance,2);



   if(isNewBar())
     {
      Print("=== Start ===");
      int total=GlobalVariablesTotal();
      for(int i=0; i<total; i++)
        {
         Print("var#"+i+" name:"+GlobalVariableName(i)," = value:",GlobalVariableGet(GlobalVariableName(i)));
        }





      double  ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      double  bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
      double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();

      //Print("======"+Symbol()+"======");
      //Print("STAR DIRECTION:  "+C_star());
      Print("SUPP & DEMAND:  "+C_supres());

      //if(C_MACD()=="BUY")
      //  {
      //   buy("MACD BUY");
      //  }
      //if(C_MACD()=="SELL")
      //  {
      //   sell("MACD SELL");
      //  }
      //if(C_MACD()=="BUY" && C_supres() =="BUY")
      //  {
      //   buy("MACD,SUPPDEM BUY");
      //  }
      //if(C_MACD()=="SELL" && C_supres() =="SELL")
      //  {
      //   sell("MACD,SUPPDEM SELL");
      //  }
      if(C_star() =="BUY" && C_supres() =="BUY")
        {
         buy("star and suppdem confirmed");
        }
      if(C_star() =="SELL" && C_supres() =="SELL")
        {
         sell("star and suppdem confirmed");
        }
      //  if(C_star() =="BUY" || C_supres() =="BUY")
      //  {
      //   PlaySound("alert");
      //   buy("either or ...star and suppdem confirmed");
      //  }
      //if(C_star() =="SELL" || C_supres() =="SELL")
      //  {
      //   PlaySound("news");
      //   sell("either or ...star and suppdem confirmed");
     }



//Print("@"+TimeCurrent());
//Print(Symbol());
//Print("___________________________________________________________________");
//}
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

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TFTS(int tf) //--- Timeframe to string
  {
   string tfs;

   switch(tf)
     {
      case PERIOD_M1:
         tfs="M1";
         break;
      case PERIOD_M2:
         tfs="M2";
         break;
      case PERIOD_M3:
         tfs="M3";
         break;
      case PERIOD_M4:
         tfs="M4";
         break;
      case PERIOD_M5:
         tfs="M5";
         break;
      case PERIOD_M6:
         tfs="M6";
         break;
      case PERIOD_M10:
         tfs="M10";
         break;
      case PERIOD_M12:
         tfs="M12";
         break;
      case PERIOD_M15:
         tfs="M15";
         break;
      case PERIOD_M20:
         tfs="M20";
         break;
      case PERIOD_M30:
         tfs="M30";
         break;
      case PERIOD_H1:
         tfs="H1";
         break;
      case PERIOD_H2:
         tfs="H2";
         break;
      case PERIOD_H3:
         tfs="H3";
         break;
      case PERIOD_H4:
         tfs="H4";
         break;
      case PERIOD_H6:
         tfs="H6";
         break;
      case PERIOD_H8:
         tfs="H8";
         break;
      case PERIOD_H12:
         tfs="H12";
         break;
      case PERIOD_D1:
         tfs="D1";
         break;
      case PERIOD_W1:
         tfs="W1";
         break;
      case PERIOD_MN1:
         tfs="MN1";
         break;
     }
   return(tfs);
  }
//+------------------------------------------------------------------+
