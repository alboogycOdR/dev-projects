//+------------------------------------------------------------------+
//|                        Polish Layer(barabashkakvn's edition).mq5 |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2008, PUNCHER from POLAND"
#property link      "bemowo@tlen.pl"
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
//--- 5 or 15 MIN timeframe only
//--- input parameters
input int      ma_period_short   = 9;        // averaging period SHORT MA
input int      ma_period_long    = 45;       // averaging period LONG MA
//--
input int      ma_period_rsi     = 14;       // averaging period RSI
input int      k_period_stoch    = 5;        // K-period (number of bars for calculations) Stochastic
input int      d_period_stoch    = 3;        // D-period (period of first smoothing) Stochastic
input int      slowing_stoch     = 3;        // final smoothing Stochastic
input int      calc_period_wpr   = 14;       // averaging period WPR
input int      ma_period_demarker= 14;       // averaging period DeMarker
//--
input double   Lots              = 1;        // Lots
input ushort   InpTakeProfit     = 17;       // Take Profit (in pips)
input ushort   InpStopLoss       = 77;       // Stop Loss (in pips)
//---
ulong       m_magic           =  15489;      // magic number
int         handle_iMA_short;                // variable for storing the handle of the iMA indicator 
int         handle_iMA_long;                 // variable for storing the handle of the iMA indicator 
int         handle_iRSI;                     // variable for storing the handle of the iRSI indicator
int         handle_iStochastic;              // variable for storing the handle of the iStochastic indicator 
int         handle_iWPR;                     // variable for storing the handle of the iWPR indicator 
int         handle_iDeMarker;                // variable for storing the handle of the iDeMarker indicator
ENUM_ACCOUNT_MARGIN_MODE m_margin_mode;
double         m_adjusted_point;             // point value adjusted for 3 or 5 points
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//SetMarginMode();
//if(!IsHedging())
//  {
//   Print("Hedging only!");
//   return(INIT_FAILED);
//  }
//---
   m_symbol.Name(Symbol());                  // sets symbol name
   if(!RefreshRates())
     {
      Print("Error RefreshRates. Bid=",DoubleToString(m_symbol.Bid(),Digits()),
            ", Ask=",DoubleToString(m_symbol.Ask(),Digits()));
      return(INIT_FAILED);
     }
   m_symbol.Refresh();
//---
   m_trade.SetExpertMagicNumber(m_magic);
//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_adjusted_point=m_symbol.Point()*digits_adjust;
   
   
//--- create handle of the indicator iMA
   handle_iMA_short=iMA(m_symbol.Name(),Period(),ma_period_short,0,MODE_EMA,PRICE_CLOSE);
//--- if the handle is not created 
   if(handle_iMA_short==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code 
      PrintFormat("Failed to create handle of the iMA indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early 
      return(INIT_FAILED);
     }
//--- create handle of the indicator iMA
   handle_iMA_long=iMA(m_symbol.Name(),Period(),ma_period_long,0,MODE_EMA,PRICE_CLOSE);
//--- if the handle is not created 
   if(handle_iMA_long==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code 
      PrintFormat("Failed to create handle of the iMA indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early 
      return(INIT_FAILED);
     }
//--- create handle of the indicator iRSI
   handle_iRSI=iRSI(m_symbol.Name(),Period(),ma_period_rsi,PRICE_CLOSE);
//--- if the handle is not created 
   if(handle_iRSI==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code 
      PrintFormat("Failed to create handle of the iRSI indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early 
      return(INIT_FAILED);
     }
//--- create handle of the indicator iStochastic
   handle_iStochastic=iStochastic(m_symbol.Name(),Period(),k_period_stoch,d_period_stoch,slowing_stoch,MODE_SMA,STO_LOWHIGH);
//--- if the handle is not created 
   if(handle_iStochastic==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code 
      PrintFormat("Failed to create handle of the iStochastic indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early 
      return(INIT_FAILED);
     }
//--- create handle of the indicator iWPR
   handle_iWPR=iWPR(m_symbol.Name(),Period(),calc_period_wpr);
//--- if the handle is not created 
   if(handle_iWPR==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code 
      PrintFormat("Failed to create handle of the iWPR indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early 
      return(INIT_FAILED);
     }
//--- create handle of the indicator iDeMarker
   handle_iDeMarker=iDeMarker(m_symbol.Name(),Period(),ma_period_demarker);
//--- if the handle is not created 
   if(handle_iDeMarker==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code 
      PrintFormat("Failed to create handle of the iDeMarker indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early 
      return(INIT_FAILED);
     }
//---
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
void OnTick()
  {
   double RSI9    = iRSIGet(1);
   double RSI45   = iRSIGet(2);

   double Price45 = iMAGet(handle_iMA_long,1);
   double Price9  = iMAGet(handle_iMA_short,1);

   bool Long=false;
   bool Short=false;
   bool Sideways=false;
   if(Price9>Price45 && RSI9>RSI45)
      Long=true;
   if(Price9<Price45 && RSI9<RSI45)
      Short=true;
   if(Price9>Price45 && RSI9<RSI45)
      Sideways=true;
   if(Price9<Price45 && RSI9>RSI45)
      Sideways=true;

   if(!Long && !Short)
      return;

   if(!RefreshRates())
      return;

   int total=0;
   for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of open positions
      if(m_position.SelectByIndex(i))     // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
            total++;

   if(Long==true && total==0)
     {
      if(iStochasticGet(MAIN_LINE,1)<19 && iStochasticGet(MAIN_LINE,0)>=19)
        {
         /*if(iStochasticGet(MAIN_LINE,1)<iStochasticGet(SIGNAL_LINE,1) && 
                     iStochasticGet(MAIN_LINE,0)>=iStochasticGet(SIGNAL_LINE,0))*/
           {
            if(iDeMarkerGet(1)<0.35 && iDeMarkerGet(0)>=0.35)
              {
               if(iWPRGet(1)<-81 && iWPRGet(0)>=-81)
                 {
                  double sl=m_symbol.NormalizePrice(m_symbol.Ask()-InpStopLoss*m_adjusted_point);
                  double tp=m_symbol.NormalizePrice(m_symbol.Ask()+InpTakeProfit*m_adjusted_point);
                  if(m_trade.Buy(Lots,NULL,m_symbol.Ask(),sl,tp))
                    {
                     if(m_trade.ResultDeal()==0)
                        Print("Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                              ", description of result: ",m_trade.ResultRetcodeDescription());
                    }
                  else
                     Print("Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                           ", description of result: ",m_trade.ResultRetcodeDescription());
                 }
              }

           }
        }
     }
   if(Short==true && total==0)
     {
      if(iStochasticGet(MAIN_LINE,1)>81 && iStochasticGet(MAIN_LINE,0)<=81)
        {
/*if(iStochasticGet(MAIN_LINE,1)>iStochasticGet(SIGNAL_LINE,1) && 
            iStochasticGet(MAIN_LINE,0)<=iStochasticGet(SIGNAL_LINE,0))*/
           {
            if(iDeMarkerGet(1)>0.63 && iDeMarkerGet(0)<=0.63)
              {
               if(iWPRGet(1)>-19 && iWPRGet(0)<=-19)
                 {
                  double sl=m_symbol.NormalizePrice(m_symbol.Bid()+InpStopLoss*m_adjusted_point);
                  double tp=m_symbol.NormalizePrice(m_symbol.Bid()-InpTakeProfit*m_adjusted_point);
                  if(m_trade.Sell(Lots,NULL,m_symbol.Bid(),sl,tp))
                    {
                     if(m_trade.ResultDeal()==0)
                        Print("Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                              ", description of result: ",m_trade.ResultRetcodeDescription());
                    }
                  else
                     Print("Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                           ", description of result: ",m_trade.ResultRetcodeDescription());;
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetMarginMode(void)
  {
   m_margin_mode=(ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsHedging(void)
  {
   return(m_margin_mode==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
  }
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates()
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
      return(false);
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
      return(false);
//---
   return(true);
  }
//+------------------------------------------------------------------+
//| Get value of buffers for the iMA                                 |
//+------------------------------------------------------------------+
double iMAGet(int handle_iMA,const int index)
  {
   double MA[1];
//--- reset error code 
   ResetLastError();
//--- fill a part of the iMABuffer array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(handle_iMA,0,index,1,MA)<0)
     {
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iMA indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(0.0);
     }
   return(MA[0]);
  }
//+------------------------------------------------------------------+
//| Get value of buffers for the iRSI                                |
//+------------------------------------------------------------------+
double iRSIGet(const int index)
  {
   double RSI[1];
//--- reset error code 
   ResetLastError();
//--- fill a part of the iRSI array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(handle_iRSI,0,index,1,RSI)<0)
     {
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iRSI indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(0.0);
     }
   return(RSI[0]);
  }
//+------------------------------------------------------------------+
//| Get value of buffers for the iStochastic                         |
//|  the buffer numbers are the following:                           |
//|   0 - MAIN_LINE, 1 - SIGNAL_LINE                                 |
//+------------------------------------------------------------------+
double iStochasticGet(const int buffer,const int index)
  {
   double Stochastic[1];
//--- reset error code 
   ResetLastError();
//--- fill a part of the iStochasticBuffer array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(handle_iStochastic,buffer,index,1,Stochastic)<0)
     {
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iStochastic indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(0.0);
     }
   return(Stochastic[0]);
  }
//+------------------------------------------------------------------+
//| Get value of buffers for the iWPR                                |
//+------------------------------------------------------------------+
double iWPRGet(const int index)
  {
   double WPR[];
   ArraySetAsSeries(WPR,true);
//--- reset error code 
   ResetLastError();
//--- fill a part of the iWPRBuffer array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(handle_iWPR,0,0,index+1,WPR)<0)
     {
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iWPR indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(0.0);
     }
   return(WPR[index]);
  }
//+------------------------------------------------------------------+
//| Get value of buffers for the iDeMarker                           |
//+------------------------------------------------------------------+
double iDeMarkerGet(const int index)
  {
   double DeMarker[1];
//--- reset error code 
   ResetLastError();
//--- fill a part of the iDeMarker array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(handle_iDeMarker,0,index,1,DeMarker)<0)
     {
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iDeMarker indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(0.0);
     }
   return(DeMarker[0]);
  }
//+------------------------------------------------------------------+
