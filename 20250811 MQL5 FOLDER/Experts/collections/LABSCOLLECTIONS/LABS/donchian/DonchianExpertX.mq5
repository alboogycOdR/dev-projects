//+------------------------------------------------------------------+
//|                                               DonchianExpert.mq5 |
//|                                Copyright 2017, Alexander Fedosov |
//|                           https://www.mql5.com/en/users/alex2356 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Alexander Fedosov"
#property link      "https://www.mql5.com/en/users/alex2356"
#property version   "1.00"

//--- The library of trade functions
#include    "XTradeFunctions.mqh"
//--- The library of trailing stop types
#include    "XTrailing.mqh"
//--- The library for displaying the info panel
//#include    "XDonchianUI.mqh"

CTradeBase  Trade;
CTrailing   Trall;
//CDonchianUI UI;
//+------------------------------------------------------------------+
//|  Declaration of enumerations of strategy types                   |
//+------------------------------------------------------------------+
enum Strategy
  {
   Donchian=0,
   Donchian_ADX,
   Donchian_MACD,
   Donchian_AvrSpeed_RSI
  };
//+------------------------------------------------------------------+
//| Declaration of enumerations of extreme types                     |
//+------------------------------------------------------------------+
enum Applied_Extrem
  {
   HIGH_LOW,
   HIGH_LOW_OPEN,
   HIGH_LOW_CLOSE,
   OPEN_HIGH_LOW,
   CLOSE_HIGH_LOW
  };
//+------------------------------------------------------------------+
//| Expert Advisor input parameters                                  |
//+------------------------------------------------------------------+
sinput string              Inp_EaComment="Donchian Expert";             //EA comment
input double               Inp_Lot=0.01;                                //Basic lot
input MarginMode           Inp_MMode=LOT;                               //Money Management
input int                  Inp_MagicNum=555;                            //Magic
input int                  Inp_StopLoss=400;                            //Stop Loss (in points)
input int                  Inp_TakeProfit=600;                          //Take Profit (in points)
input int                  Inp_Deviation = 20;                          //Slippage


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input ENUM_TIMEFRAMES      InpInd_Timeframe=PERIOD_CURRENT;                  //Working timeframe (DEF:1H)
input bool                 InfoPanel=true;                              //Display of the information panel
//--- Donchian Channel System indicator parameters

input uint                 DonchianPeriod=20;                           //Channel period
input Applied_Extrem       Extremes=HIGH_LOW_CLOSE;                     //Type of extrema
//--- Selecting the strategy

input Strategy             CurStrategy=Donchian;                        //Selected strategy
//--- ADX indicator parameter

input int                  ADX_period=10;
input double               ADX_level=20;
//--- MACD indicator parameters

input int                  InpFastEMA=12;                               //Fast EMA period
input int                  InpSlowEMA=26;                               //Slow EMA period
input int                  InpSignalSMA=9;                              //Signal SMA period
input ENUM_APPLIED_PRICE   InpAppliedPrice=PRICE_CLOSE;                 //Applied price
//--- Average Speed indicator parameters

input int                  Inp_Bars=1;                                  //Number of bars
input ENUM_APPLIED_PRICE   Price=PRICE_CLOSE;                           //Applied price
input double               Trend_lev=1;                                 //Trend level
//--- The x4period_rsi_arrows indicator parameters

input uint                 RSIperiod1=7;                                //Period of RSI_1
input uint                 RSIperiod2=12;                               //Period of RSI_2
input uint                 RSIperiod3=18;                               //Period of RSI_3
input uint                 RSIperiod4=32;                               //Period of RSI_4
input ENUM_APPLIED_PRICE   Applied_price=PRICE_WEIGHTED;                //Applied price
input uint                 rsiUpperTrigger=62;                          //Overbought level
input uint                 rsiLowerTrigger=38;                          //Oversold level
//--- Trailing Stop parameters

input bool                 UseTrailing=true;                            //Use of trailing stop
input bool                 VirtualTrailingStop=false;                   //Virtual trailing stop
input TrallMethod          parameters_trailing=7;                       //Trailing method

input ENUM_TIMEFRAMES      TF_Tralling=PERIOD_CURRENT;                  //Indicator timeframe

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input int                  StepTrall=50;                                //Trailing step (in points)
input int                  StartTrall=100;                              //Minimum trailing profit (in points)

input int                  period_ATR=14;                               //ATR period (method #3)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input double               step_PSAR=0.02;                              //PSAR step (method #4)
input double               maximum_PSAR=0.2;                            //Maximum PSAR (method #4)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input int                  ma_period=34;                                //MA period (method #5)
input ENUM_MA_METHOD       ma_method=MODE_SMA;                          //Averaging method (method #5)
input ENUM_APPLIED_PRICE   applied_price=PRICE_CLOSE;                   //Price type (method #5)

input double               PercentProfit=50;                            //Percent of profit (method #6)

int      InpInd_Handle1,InpInd_Handle2,InpInd_Handle3;
double   dcs_up[],dcs_low[],close[];
double   adx[],adx_m[],adx_p[];
double   macd_m[],macd_s[];
double   avs[];
double   rsi_1b[],rsi_2b[],rsi_3b[],rsi_4b[];
double   rsi_1s[],rsi_2s[],rsi_3s[],rsi_4s[];
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Checking connection to the trade server

   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
     {
      Print(Inp_EaComment,": No Connection!");
      return(INIT_FAILED);
     }
//--- Checking automated trading permission

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      Print(Inp_EaComment,": Trade is not allowed!");
      return(INIT_FAILED);
     }
//--- Getting the handle of the Donchian Channel System indicator

   InpInd_Handle1=iCustom(Symbol(),InpInd_Timeframe,"Donchian_Channels_SystemForEA",
                          DonchianPeriod,
                          Extremes
                         );

   if(InpInd_Handle1==INVALID_HANDLE)
     {
      Print(Inp_EaComment,": Failed to get Donchian Channel System handle");
      Print("Handle = ",InpInd_Handle1,"  error = ",GetLastError());
      return(INIT_FAILED);
     }
   else
     {
      if(InpInd_Handle1!=INVALID_HANDLE)
         ChartIndicatorDelete(0,0,InpInd_Handle1);
      ChartIndicatorAdd(0,0,InpInd_Handle1);
     }
//--- Getting the handle of indicators for the selected strategy

   if(!GetIndHandle())
     {Print(" about to fail  ");   return(INIT_FAILED);}
//---
   ArrayInitialize(dcs_up,0.0);
   ArrayInitialize(dcs_low,0.0);

   ArraySetAsSeries(dcs_up,true);
   ArraySetAsSeries(dcs_low,true);

//--- Настройка Трейлинг-стопа
   if(UseTrailing)
     {
      Trall.IsVirtualStop(VirtualTrailingStop);
      Trall.SetTrallMethod(parameters_trailing);
      Trall.SetTimeframe(PERIOD_CURRENT);
      Trall.SetStepTrall(StepTrall);
      Trall.SetStartTrall(StartTrall);
      Trall.SetATR(period_ATR);
      Trall.SetPSAR_Step(step_PSAR);
      Trall.SetPSAR_Max(maximum_PSAR);
      Trall.SetMA_Period(ma_period);
      Trall.SetMA_Method(ma_method);
      Trall.SetMA_Price(applied_price);
      Trall.SetPercProfit(PercentProfit);
      Trall.SetMagicNumber(Inp_MagicNum);
     }
//---- Настройка Инфопанели
//if(InfoPanel)
//   SetInfoPanel();

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//UI.OnDeinitEvent(reason);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

//--- Проверка ранее открытых экcпертом ордеров
   if(!Trade.IsOpened(Inp_MagicNum))
     {
      //--- Getting data for calculations

      if(!GetIndValue())
         return;
      //--- Opening an order if there is a buy signal

      if(SellSignal())
         Trade.SellPositionOpen(true,Symbol(),Inp_Lot,Inp_MMode,Inp_Deviation,Inp_StopLoss,Inp_TakeProfit,Inp_MagicNum,Inp_EaComment);
      //Trade.BuyPositionOpen(true,Symbol(),Inp_Lot,Inp_MMode,Inp_Deviation,Inp_StopLoss,Inp_TakeProfit,Inp_MagicNum,Inp_EaComment);
      //--- Opening an order if there is a sell signal

      if(BuySignal())
         Trade.BuyPositionOpen(true,Symbol(),Inp_Lot,Inp_MMode,Inp_Deviation,Inp_StopLoss,Inp_TakeProfit,Inp_MagicNum,Inp_EaComment);
      //Trade.SellPositionOpen(true,Symbol(),Inp_Lot,Inp_MMode,Inp_Deviation,Inp_StopLoss,Inp_TakeProfit,Inp_MagicNum,Inp_EaComment);
     }
   else
     {
      if(UseTrailing)
         Trall.TrailingStop();
     }
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int    id,
                  const long   &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//UI.ChartEvent(id,lparam,dparam,sparam);
  }
//+------------------------------------------------------------------+
//| Buy conditions                                                   |
//+------------------------------------------------------------------+
bool BuySignal()
  {
   int b=0;
   switch(CurStrategy)
     {
      case  0:
         return(close[0]>dcs_up[0])?true:false;
         break;
      case  1:
         return(close[0]>dcs_up[0] && adx[0]>=ADX_level && adx_p[0]>adx_m[0])?true:false;
         break;
      case  2:
         return(close[0]>dcs_up[0] && macd_m[0]>macd_s[0] && macd_m[0]>0)?true:false;
         break;
      case  3:
         if(rsi_1b[0]>0)
            b++;
         if(rsi_2b[0]>0)
            b++;
         if(rsi_3b[0]>0)
            b++;
         if(rsi_4b[0]>0)
            b++;
         return(close[0]>dcs_up[0] && avs[0]>=Trend_lev && b>=2)?true:false;
         break;
     }
   return(false);
  }
//+------------------------------------------------------------------+
//| Sell conditions                                                  |
//+------------------------------------------------------------------+
bool SellSignal()
  {
   int s=0;
   switch(CurStrategy)
     {
      case  0:
         return(close[0]<dcs_low[0])?true:false;
         break;
      case  1:
         return(close[0]<dcs_low[0] && adx[0]>=ADX_level && adx_p[0]<adx_m[0])?true:false;
         break;
      case  2:
         return(close[0]<dcs_low[0] && macd_m[0]<macd_s[0] && macd_m[0]<0)?true:false;
         break;
      case  3:
         if(rsi_1s[0]>0)
            s++;
         if(rsi_2s[0]>0)
            s++;
         if(rsi_3s[0]>0)
            s++;
         if(rsi_4s[0]>0)
            s++;
         return(close[0]<dcs_low[0] && avs[0]>=Trend_lev && s>=2)?true:false;
         break;
     }
   return(false);
  }
//+------------------------------------------------------------------+
//| Getting the current indicator values                             |
//+------------------------------------------------------------------+
bool GetIndValue()
  {
   switch(CurStrategy)
     {
      //--- Donchian

      case  0:
         return(CopyBuffer(InpInd_Handle1,0,0,2,dcs_up)<=0  ||
                CopyBuffer(InpInd_Handle1,1,0,2,dcs_low)<=0 ||
                CopyClose(Symbol(),InpInd_Timeframe,0,2,close)<=0
               )?false:true;
         break;
      //--- Donchian+ADX

      case  1:
         return(CopyBuffer(InpInd_Handle1,0,0,2,dcs_up)<=0  ||
                CopyBuffer(InpInd_Handle1,1,0,2,dcs_low)<=0 ||
                CopyBuffer(InpInd_Handle2,0,0,2,adx)<=0 ||
                CopyBuffer(InpInd_Handle2,1,0,2,adx_p)<=0   ||
                CopyBuffer(InpInd_Handle2,2,0,2,adx_m)<=0   ||
                CopyClose(Symbol(),InpInd_Timeframe,0,2,close)<=0
               )?false:true;
         break;
      //--- Donchian+MACD

      case  2:
         return(CopyBuffer(InpInd_Handle1,0,0,2,dcs_up)<=0  ||
                CopyBuffer(InpInd_Handle1,1,0,2,dcs_low)<=0 ||
                CopyBuffer(InpInd_Handle2,0,0,2,macd_m)<=0 ||
                CopyBuffer(InpInd_Handle2,1,0,2,macd_s)<=0   ||
                CopyClose(Symbol(),InpInd_Timeframe,0,2,close)<=0
               )?false:true;
         break;
      //--- Donchian+Avr.Speed+RSI

      case  3:
         return(CopyBuffer(InpInd_Handle1,0,0,2,dcs_up)<=0  ||
                CopyBuffer(InpInd_Handle1,1,0,2,dcs_low)<=0 ||
                CopyBuffer(InpInd_Handle2,0,0,2,avs)<=0 ||
                CopyBuffer(InpInd_Handle3,0,0,2,rsi_1s)<=0 ||
                CopyBuffer(InpInd_Handle3,1,0,2,rsi_1b)<=0 ||
                CopyBuffer(InpInd_Handle3,2,0,2,rsi_2s)<=0 ||
                CopyBuffer(InpInd_Handle3,3,0,2,rsi_2b)<=0 ||
                CopyBuffer(InpInd_Handle3,4,0,2,rsi_3s)<=0 ||
                CopyBuffer(InpInd_Handle3,5,0,2,rsi_3b)<=0 ||
                CopyBuffer(InpInd_Handle3,6,0,2,rsi_4s)<=0 ||
                CopyBuffer(InpInd_Handle3,7,0,2,rsi_4b)<=0 ||
                CopyClose(Symbol(),InpInd_Timeframe,0,2,close)<=0
               )?false:true;
         break;
     }
   return(false);
  }
//+------------------------------------------------------------------+
//| Getting indicator handles for the selected strategy              |
//+------------------------------------------------------------------+
bool GetIndHandle()
  {
   switch(CurStrategy)
     {
      case 0:
         return(true);
         break;
      case  1:
         //if(InpInd_Handle2!=INVALID_HANDLE)
          // {
           ChartIndicatorDelete(0,1,InpInd_Handle2); IndicatorRelease(InpInd_Handle2);
          // }

         



        // if(InpInd_Handle3!=INVALID_HANDLE)
          // { 
           ChartIndicatorDelete(0,2,InpInd_Handle3); IndicatorRelease(InpInd_Handle3);
          // }
         ChartRedraw(0);
         
         
         
         InpInd_Handle2=iADX(Symbol(),InpInd_Timeframe,ADX_period);
         ArrayInitialize(adx,0.0);
         ArrayInitialize(adx_p,0.0);
         ArrayInitialize(adx_m,0.0);
         ArraySetAsSeries(adx,true);
         ArraySetAsSeries(adx_p,true);
         ArraySetAsSeries(adx_m,true);
         ChartIndicatorAdd(0,1,InpInd_Handle2);         ChartRedraw(0);
         break;
      case  2:
        // if(InpInd_Handle2!=INVALID_HANDLE)
           //{
           ChartIndicatorDelete(0,1,InpInd_Handle2); IndicatorRelease(InpInd_Handle2);
           //}

         //if(InpInd_Handle3!=INVALID_HANDLE)
          // { 
           ChartIndicatorDelete(0,2,InpInd_Handle3); IndicatorRelease(InpInd_Handle3);
          // }
          
         ChartRedraw(0);          
         InpInd_Handle2=iMACD(Symbol(),InpInd_Timeframe,InpFastEMA,InpSlowEMA,InpSignalSMA,InpAppliedPrice);





           


         ArrayInitialize(macd_m,0.0);
         ArrayInitialize(macd_s,0.0);
         ArraySetAsSeries(macd_m,true);
         ArraySetAsSeries(macd_s,true);
         ChartIndicatorAdd(0,1,InpInd_Handle2);         ChartRedraw(0);
         break;
      case  3:
         //if(InpInd_Handle2!=INVALID_HANDLE)
          // {
           ChartIndicatorDelete(0,1,"MACD"); IndicatorRelease(InpInd_Handle2);
           //}
         //if(InpInd_Handle3!=INVALID_HANDLE)
         //  {
           ChartIndicatorDelete(0,2,InpInd_Handle3); IndicatorRelease(InpInd_Handle3);
          // }
           
         ChartRedraw(0);
         InpInd_Handle2=iCustom(Symbol(),InpInd_Timeframe,"Average_Speed",Inp_Bars,Price);
         



         InpInd_Handle3=iCustom(Symbol(),InpInd_Timeframe,"x4period_rsi_arrows",
                                RSIperiod1,
                                RSIperiod2,
                                RSIperiod3,
                                RSIperiod4,
                                Applied_price,
                                rsiUpperTrigger,
                                rsiLowerTrigger,
                                2);         ChartRedraw(0);
         
         ArrayInitialize(rsi_1b,0.0);
         ArrayInitialize(rsi_2b,0.0);
         ArrayInitialize(rsi_3b,0.0);
         ArrayInitialize(rsi_4b,0.0);
         ArrayInitialize(rsi_1s,0.0);
         ArrayInitialize(rsi_2s,0.0);
         ArrayInitialize(rsi_3s,0.0);
         ArrayInitialize(rsi_4s,0.0);
         ArraySetAsSeries(rsi_1b,true);
         ArraySetAsSeries(rsi_2b,true);
         ArraySetAsSeries(rsi_3b,true);
         ArraySetAsSeries(rsi_4b,true);
         ArraySetAsSeries(rsi_1s,true);
         ArraySetAsSeries(rsi_2s,true);
         ArraySetAsSeries(rsi_3s,true);
         ArraySetAsSeries(rsi_4s,true);ChartIndicatorAdd(0,1,InpInd_Handle2);ChartIndicatorAdd(0,2,InpInd_Handle3);         ChartRedraw(0);
         break;
     }

   if(InpInd_Handle2==INVALID_HANDLE)
     {
      Print(Inp_EaComment,": Failed to get handle");
      Print("Handle = ",InpInd_Handle2,"  error = ",GetLastError());
      return(false);
     }
   if(InpInd_Handle3==INVALID_HANDLE)
     {
      Print(Inp_EaComment,": Failed to get handle");
      Print("Handle = ",InpInd_Handle3,"  error = ",GetLastError());
      return(false);
     }
   return(true);
  }
//+------------------------------------------------------------------+
//| Returns the name of the currently selected strategy              |
//+------------------------------------------------------------------+
string GetNameStrategy(Strategy S)
  {
   switch(S)
     {
      case  0:
         return("Donchian Channel");
         break;
      case  1:
         return("Donchian Channel + ADX");
         break;
      case  2:
         return("Donchian Channel + MACD");
         break;
      case  3:
         return("Donchian Channel + Avr.Speed + RSI");
         break;
     }
   return("unknown");
  }
//+------------------------------------------------------------------+
//| Returns the type of the selected trailing stop                   |
//+------------------------------------------------------------------+
string GetNameTrall(TrallMethod T)
  {
   if(UseTrailing)
     {
      switch(T)
        {
         case  1:
            return("Using candlestick extrema");
            break;
         case  2:
            return("Using fractals");
            break;
         case  3:
            return("Using the ATR indicator");
            break;
         case  4:
            return("Using Parabolic");
            break;
         case  5:
            return("Using MA");
            break;
         case  6:
            return("% of profit");
            break;
         case  7:
            return("In points");
            break;
        }
     }
   return("Not used");
  }
//+------------------------------------------------------------------+
//| Returns the current money management                             |
//+------------------------------------------------------------------+
string GetNameMM(MarginMode M)
  {
   switch(M)
     {
      case  0:
         return("Free margin");
         break;
      case  1:
         return("Balance");
         break;
      case  2:
         return("Basic lot");
         break;
     }
   return(" - ");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetInfoPanel()
  {
//string par[]=
//  {
//   "Parameter",
//   "Type of strategy",
//   "Trailing stop type",
//   "Money management",
//   "Take Profit",
//   "Stop Loss"
//  };
//UI.CreateMainPanel("Donchian Expert");
//for(int i=0;i<=5;i++)
//   UI.m_canvas_table.SetValue(0,i,par[i]);
//UI.m_canvas_table.SetValue(1,0,"Value");
//UI.m_canvas_table.SetValue(1,1,GetNameStrategy(CurStrategy));
//UI.m_canvas_table.SetValue(1,2,GetNameTrall(parameters_trailing));
//UI.m_canvas_table.SetValue(1,3,GetNameMM(Inp_MMode));
//UI.m_canvas_table.SetValue(1,4,string(Inp_TakeProfit));
//UI.m_canvas_table.SetValue(1,5,string(Inp_StopLoss));
//UI.m_canvas_table.UpdateTable(true);
//UI.CreateStatusBar(1,25);
//UI.m_status_bar.ValueToItem(0,"EA is enabled on "+Symbol());
  }
//+------------------------------------------------------------------+
