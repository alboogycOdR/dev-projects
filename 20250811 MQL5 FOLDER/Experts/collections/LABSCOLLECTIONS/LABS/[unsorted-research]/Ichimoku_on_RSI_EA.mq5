//+------------------------------------------------------------------+
//|                                      MA on RSI EA Hedging EA.mq5 |
//|                                     Copyright 2020, Brian M Jaka |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, Brian M Jaka"
#property link      "https://www.mql5.com"
#property version   "1.00"
/*
   barabashkakvn Trading engine 3.138
*/
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
//---
CPositionInfo  m_position;                   // object of CPositionInfo class
CTrade         m_trade;                      // object of CTrade class
CSymbolInfo    m_symbol;                     // object of CSymbolInfo class
CAccountInfo   m_account;                    // object of CAccountInfo class
//--- input parameters
input group             "RSILevels"
input int                InpLower        = 85;
input int                InpUpper        = 15;
input group            "Ichimoku"
input int                tenkan_sen      =  9;                // period of Tenkan-sen
input int                kijun_sen       =  9;                // period of Kijun-sen
input int                senkou_span_b   =  52;               // period of Senkou Span B
input group             "RSI"
input int                RSIPeriod       =  6;                // period of RSI
input ENUM_APPLIED_PRICE applied_price   =  PRICE_CLOSE;      // type of price
input group             "Additional features"
input int      InpTakeProfitPts     =  100;         //Take profit points
input int      InpStopLossPts       =  10000;       //Stop loss points
input double   InpOrderSize         =  0.20;        //Order size
input bool     InpPrintLog          =  false;       // Print log
input ulong    InpDeviation         =  10;          // Deviation
input ulong    InpMagic             =  931302198;   // Magic number
//---
bool     m_need_close_buys          = false;    // close all BUY positions
bool     m_need_close_sells         = false;    // close all SELL positions
bool     m_need_open_buy            = false;    // open BUY position
bool     m_need_open_sell           = false;    // open SELL position
datetime m_prev_bars                = 0;        // "0" -> D'1970.01.01 00:00';
//------
//------
int      IchiHandle;       // variable for storing the handle of the iIchimoku indicator
int      RSIHandle;        // variable for storing the handle of the iRSI indicator
int      IchiOnRSIHandle;  // variable for storing the handle for Ichimoku on RSI
bool     Trigger;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   ResetLastError();
   if(!m_symbol.Name(Symbol())) // sets symbol name
     {
      Print(__FILE__," ",__FUNCTION__,", ERROR: CSymbolInfo.Name");
      return(INIT_FAILED);
     }
   RefreshRates();
//---
   m_trade.SetExpertMagicNumber(InpMagic);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(m_symbol.Name());
   m_trade.SetDeviationInPoints(InpDeviation);
//---create timer
   EventSetTimer(60);

   int   tenkan_senPeriod  = 9;
   int   rsiPeriod         = 6;

//Calculations of indicators

//Calculating the handle for Moving average

   IchiHandle        = iIchimoku(Symbol(),Period(),
                                 tenkan_sen,kijun_sen,senkou_span_b);
   if(IchiHandle==INVALID_HANDLE)
      return(INIT_FAILED);

//--- create handle of the indicator iRSI
   RSIHandle=iRSI(Symbol(),Period(),rsiPeriod,PRICE_CLOSE);
//--- if the handle is not created
   if(RSIHandle==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the iRSI indicator for the symbol %s/%s, error code %d",
                 Symbol(),
                  rsiPeriod,
                  GetLastError());
      //--- the indicator is stopped early
      return(INIT_FAILED);
     }
     
////Calculating the handle for RSI
//   RSIHandle         = iRSI(Symbol(),Period(),
//                            rsiPeriod,PRICE_CLOSE);
//   if(RSIHandle==INVALID_HANDLE)
//      {Print("singular rsi issue");return(INIT_FAILED);}


//Calculating the handle for Moving average of the RSI
   IchiOnRSIHandle   = iRSI(Symbol(),Period(),rsiPeriod,IchiHandle);
   if(IchiOnRSIHandle==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the IchiOnRSIHandle indicator for the symbol %s/%s, error code %d",
                 Symbol(),
                  rsiPeriod,
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
//---destroy timer
   EventKillTimer();

   if(IchiHandle!=INVALID_HANDLE)
      IndicatorRelease(IchiHandle);
   if(RSIHandle!=INVALID_HANDLE)
      IndicatorRelease(RSIHandle);
   if(IchiOnRSIHandle!=INVALID_HANDLE)
      IndicatorRelease(IchiOnRSIHandle);

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//We calculate the Ask price
   double Ask=NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);

//We calculate the Bid price
   double Bid=NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);

//--- Condition for closing BUY positions OR SELL positions
   if(m_need_close_buys || m_need_close_sells)
     {
      int count_buys    = 0;
      int count_sells   = 0;
      CalculateAllPositions(count_buys,count_sells);
      //---
      if(m_need_close_buys)
        {
         if(count_buys>0)
           {
            ClosePositions(POSITION_TYPE_BUY);
            return;
           }
         else
            m_need_close_buys=false;
        }
      //---
      if(m_need_close_sells)
        {
         if(count_sells>0)
           {
            ClosePositions(POSITION_TYPE_SELL);
            return;
           }
         else
            m_need_close_sells=false;
        }
     }
//--- open BUY position
   if(m_need_open_buy)
     {
      if(!RefreshRates())
         return;
      //--- check volume before OrderSend to avoid "not enough money" error (CTrade)
      double free_margin_check=m_account.FreeMarginCheck(m_symbol.Name(),
                               ORDER_TYPE_BUY,
                               m_symbol.LotsMin(),
                               m_symbol.Ask());
      double margin_check=m_account.MarginCheck(m_symbol.Name(),
                          ORDER_TYPE_BUY,
                          m_symbol.LotsMin(),
                          m_symbol.Ask());
      if(free_margin_check>margin_check)
        {
         if(InpPrintLog)
            Print(__FILE__," ",__FUNCTION__,", OK: ","Signal BUY");

         //if we have less than 2 positions
         if(PositionsTotal()<2)

            m_trade.Buy(m_symbol.LotsMin(),m_symbol.Name(),m_symbol.Ask(),(Ask-InpStopLossPts *_Point));

        }
      m_need_open_buy=false;
     }

//--- open SELL position
   if(m_need_open_sell)
     {
      if(!RefreshRates())
         return;
      //--- check volume before OrderSend to avoid "not enough money" error (CTrade)
      double free_margin_check=m_account.FreeMarginCheck(m_symbol.Name(),
                               ORDER_TYPE_SELL,
                               m_symbol.LotsMin(),
                               m_symbol.Ask());
      double margin_check=m_account.MarginCheck(m_symbol.Name(),
                          ORDER_TYPE_SELL,
                          m_symbol.LotsMin(),
                          m_symbol.Ask());
      if(free_margin_check>margin_check)
        {
         if(InpPrintLog)
            Print(__FILE__," ",__FUNCTION__,", OK: ","Signal SELL");
         m_trade.Sell(m_symbol.LotsMin(),m_symbol.Name(),m_symbol.Bid(),(Bid+InpStopLossPts *_Point));
        }
      m_need_open_sell=false;
     }

//--- we work only at the time of the birth of new bar
   datetime time_0=iTime(m_symbol.Name(),Period(),0);
   if(time_0==m_prev_bars)
      return;
   m_prev_bars=time_0;
//---
















//---create buffers
   double   IchiBuffer[];
   double   RsiBuffer[];
   double   IchiOnRsiBuffer[];

   int      bufferNumber   = 0;
   int      cnt;
   int      required       = 2;
   int      start          = 1;

   cnt = CopyBuffer(IchiHandle,bufferNumber,start,required,IchiBuffer);
   if(cnt<required)
      return;
   cnt = CopyBuffer(RSIHandle,bufferNumber,start,required,RsiBuffer);
   if(cnt<required)
      return;
   cnt = CopyBuffer(IchiOnRSIHandle,bufferNumber,start,required,IchiOnRsiBuffer);
   if(cnt<required)
      return;

   ArraySetAsSeries(IchiBuffer,true);
   ArraySetAsSeries(RsiBuffer,true);
   ArraySetAsSeries(IchiOnRsiBuffer,true);

   int start_pos=0,count=6;
   if(!iGetArray(IchiOnRSIHandle,0,start_pos,count,IchiOnRsiBuffer))
     {
      m_prev_bars=0;
      return;
     }
//======================================================


//--- check signal close SELL and open BUY
   if(IchiOnRsiBuffer[1]<=15)
      if(IchiOnRsiBuffer[2]>13)
        {
         m_need_close_sells=true;
         m_need_open_buy=true;
         return;
        }
//--- check signal close BUY and open SELL
   if(IchiOnRsiBuffer[1]>=83)
      if(IchiOnRsiBuffer[1]<85)
        {
         m_need_close_buys=true;
         m_need_open_sell=true;
         return;
        }
  }
  
  
  
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates()
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
     {
      if(InpPrintLog)
         Print(__FILE__," ",__FUNCTION__,", ERROR: ","RefreshRates error");
      return(false);
     }
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
     {
      if(InpPrintLog)
         Print(__FILE__," ",__FUNCTION__,", ERROR: ","Ask == 0.0 OR Bid == 0.0");
      return(false);
     }
//---
   return(true);
  }
//+------------------------------------------------------------------+
//| Get value of buffers                                             |
//+------------------------------------------------------------------+
bool iGetArray(const int handle,const int buffer,const int start_pos,
               const int count,double &arr_buffer[])
  {
   bool result=true;
   if(!ArrayIsDynamic(arr_buffer))
     {
      if(InpPrintLog)
         PrintFormat("ERROR! EA: %s, FUNCTION: %s, this a no dynamic array!",__FILE__,__FUNCTION__);
      return(false);
     }
   ArrayFree(arr_buffer);
//--- reset error code
   ResetLastError();
//--- fill a part of the iBands array with values from the indicator buffer
   int copied=CopyBuffer(handle,buffer,start_pos,count,arr_buffer);
   if(copied!=count)
     {
      //--- if the copying fails, tell the error code
      if(InpPrintLog)
         PrintFormat("ERROR! EA: %s, FUNCTION: %s, amount to copy: %d, copied: %d, error code %d",
                     __FILE__,__FUNCTION__,count,copied,GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
     }
   return(result);
  }
//+------------------------------------------------------------------+
//| Calculate all positions                                          |
//+------------------------------------------------------------------+
void CalculateAllPositions(int &count_buys,int &count_sells)
  {
   count_buys  = 0;
   count_sells = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==InpMagic)
           {
            if(m_position.PositionType()==POSITION_TYPE_BUY)
               count_buys++;
            else
               if(m_position.PositionType()==POSITION_TYPE_SELL)
                  count_sells++;
           }
  }

//+------------------------------------------------------------------+
//| Close positions                                                  |
//+------------------------------------------------------------------+
void ClosePositions(const ENUM_POSITION_TYPE pos_type)
  {
   for(int i=PositionsTotal()-1; i>=0; i--) // returns the number of current positions
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==InpMagic)
            if(m_position.PositionType()==pos_type)
               if(!m_trade.PositionClose(m_position.Ticket())) // close a position by the specified m_symbol
                  if(InpPrintLog)
                     Print(__FILE__," ",__FUNCTION__,", ERROR: ","CTrade.PositionClose ",m_position.Ticket());
  }
//+------------------------------------------------------------------+
void CheckTrailingStop(double Ask)
  {
//set desired stoploss to 10000points
   double SL=NormalizeDouble(Ask-10000*_Point,_Digits);

//check all open positions for the current symbol
   for(int i=PositionsTotal()-1; i>=0; i--) //count all currency pair positions

     {
      string symbol = PositionGetSymbol(i); //get position symbol

      if(_Symbol== symbol)  //if chart symbol equals position symbol
        {
         //get the ticket number
         ulong PositionTicket = PositionGetInteger(POSITION_TICKET);

         //get the current stop loss
         double CurrentStopLoss= PositionGetDouble(POSITION_SL);

         //if current stop loss is below 150 points from ask price
         if(CurrentStopLoss<SL)

           {
            //modify the stoploss by 5000 points
            m_trade.PositionModify(PositionTicket,(CurrentStopLoss+5000*_Point),0);
           }

        }//end symbol if loop

     }  //end for loop

  } //end trailing stop function
//+------------------------------------------------------------------+
