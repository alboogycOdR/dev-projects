//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+


#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object


//+------------------------------------------------------------------+
//| EA inputs                                                        |
//+------------------------------------------------------------------+
input string               InpEaComment         =  "Strategy #1"; // EA Comment
input int                  InpMagicNum          =  1111;          // Magic number
input double               InpLot               =  0.1;           // Lots
input uint                 InpStopLoss          =  400;           // StopLoss in points
input uint                 InpTakeProfit        =  500;           // TakeProfit in points
input uint                 InpSlippage          =  0;             // Slippage in points
input ENUM_TIMEFRAMES      InpInd_Timeframe     =  PERIOD_H1;     // Timeframe for the calculation

//--- Average Speed indicator parameters
input int                  InpBars              =  1;             // Days
input ENUM_APPLIED_PRICE   InpPrice             =  PRICE_CLOSE;   // Applied price
input double               InpTrendLev          =  2;             // Trend Level

//--- CAM indicator parameters
input uint                 InpPeriodADX         =  10;            // ADX period
input uint                 InpPeriodFast        =  12;            // MACD Fast EMA period
input uint                 InpPeriodSlow        =  26;            // MACD Slow EMA period


double         lot;
ulong          magic_number;
uint           stoploss;
uint           takeprofit;
uint           slippage;
int            InpInd_Handle1,InpInd_Handle2;
double         avr_speed[],cam_up[],cam_dn[];
double         A[],B[],C[],D[],E[],F[];

int            Handle_123;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
// Read signal
//int Handle_123 = iCustom(Symbol(), Period(), "/pz5/PZ_123Pattern", "--", 8, 38.2, 71.8, 1, 1);
   Handle_123 = iCustom(Symbol(), Period(), "pz5\\PZ_123Pattern");
   if(Handle_123==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the Handle_123 indicator for the symbol %s, error code %d",
                  m_symbol.Name(),
                  GetLastError());
      //--- the indicator is stopped early
      return(INIT_FAILED);
     }

// Do something
//if(value == 0) { /* Your code for bullish signal */ }
//if(value == 1) { /* Your code for bearish signal */ }
//if(value == EMPTY_VALUE) { /* Your code if no signal */}






//--- setting trade parameters
   lot=1;//NormalizeLot(Symbol(),fmax(InpLot,MinimumLots(Symbol())));
   magic_number=InpMagicNum;
   stoploss=InpStopLoss;
   takeprofit=InpTakeProfit;
   slippage=InpSlippage;
//---
   m_trade.SetDeviationInPoints(slippage);
   m_trade.SetExpertMagicNumber(magic_number);
   m_trade.SetTypeFillingBySymbol(Symbol());
   m_trade.SetMarginMode();
   m_trade.LogLevel(LOG_LEVEL_NO);
//---
   return(INIT_SUCCEEDED);
  }
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
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- If working in the tester
//if(MQLInfoInteger(MQL_TESTER))
//   engine.OnTimer();
   if(!isNewBar())
     {
      return;
     }
   ////string findstring=  "PZ123P-6-"+PeriodSeconds(PERIOD_CURRENT)+"-arrow-";
   //string findstring=  "PZ123P-6-"+(int)TimeCurrent()+"-arrow-";
   //Print("FINDWHAT? "+findstring);
   //Print("RESULT: "+(ObjectFind(0,findstring)));

   if(!IsOpenedByMagic(InpMagicNum))
     {
      //--- Get data for calculation
      //if(!GetIndValue())
      //   return;
      //---
      CopyBuffer(Handle_123,0,0,2,A);
      CopyBuffer(Handle_123,1,0,2,B) ;
      CopyBuffer(Handle_123,2,0,2,C);
      CopyBuffer(Handle_123,3,0,2,D);
      CopyBuffer(Handle_123,4,0,2,E) ;
      CopyBuffer(Handle_123,5,0,2,F);
      Print("A "+A[0]);
      Print("B "+B[0]);
      Print("C "+C[0]);
      Print("D "+D[0]);
      Print("E "+E[0]);
      Print("F "+F[0]);
      Print("A "+A[1]);
      Print("B "+B[1]);
      Print("C "+C[1]);
      Print("D "+D[1]);
      Print("E "+E[1]);
      Print("F "+F[1]);
      Print("==================");

      return;


      if(BuySignal())
        {
         double  ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         double  bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
         double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();

         //--- Get correct StopLoss and TakeProfit prices relative to StopLevel
         double sl=NULL;//CorrectStopLoss(Symbol(),ORDER_TYPE_BUY,0,stoploss);
         double tp=ask+stops;//CorrectTakeProfit(Symbol(),ORDER_TYPE_BUY,0,takeprofit);
         //--- Open Buy position
         m_trade.Buy(lot,Symbol(),0,sl,tp);
        }
      else
         if(SellSignal())
           {
            double  ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
            double  bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
            double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();

            //--- Get correct StopLoss and TakeProfit prices relative to StopLevel
            double sl=NULL;//CorrectStopLoss(Symbol(),ORDER_TYPE_SELL,0,stoploss);
            double tp=bid-stops;//CorrectTakeProfit(Symbol(),ORDER_TYPE_SELL,0,takeprofit);
            //--- Open Sell position
            m_trade.Sell(lot,Symbol(),0,sl,tp);
           }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal()
  {
   return(avr_speed[0]>=InpTrendLev && cam_up[0]!=EMPTY_VALUE)?true:false;
  }
//+------------------------------------------------------------------+
bool SellSignal()
  {
   return(avr_speed[0]>=InpTrendLev && cam_dn[0]!=EMPTY_VALUE)?true:false;
  }
//+------------------------------------------------------------------+
//| Get the current indicator values                                 |
//+------------------------------------------------------------------+
bool GetIndValue()
  {
// A[],B[],C[],D[],E[];
   return(CopyBuffer(Handle_123,0,0,1,A)<1 ||
          CopyBuffer(Handle_123,1,0,1,B)<1 ||
          CopyBuffer(Handle_123,2,0,1,C)<1
         )?false:true;
  }
//+------------------------------------------------------------------+
//| Check for open positions with a magic number                     |
//+------------------------------------------------------------------+
bool IsOpenedByMagic(int MagicNumber)
  {
   int pos=0;
   uint total=PositionsTotal();
//---
   for(uint i=0; i<total; i++)
     {
      if(SelectByIndex(i))
         if(PositionGetInteger(POSITION_MAGIC)==MagicNumber)
            pos++;
     }
   return((pos>0)?true:false);
  }
//+------------------------------------------------------------------+
//| Select a position on the index                                   |
//+------------------------------------------------------------------+
bool SelectByIndex(const int index)
  {
   ENUM_ACCOUNT_MARGIN_MODE margin_mode=(ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
//---
   if(margin_mode==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      ulong ticket=PositionGetTicket(index);
      if(ticket==0)
         return(false);
     }
   else
     {
      string name=PositionGetSymbol(index);
      if(name=="")
         return(false);
     }
//---
   return(true);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
