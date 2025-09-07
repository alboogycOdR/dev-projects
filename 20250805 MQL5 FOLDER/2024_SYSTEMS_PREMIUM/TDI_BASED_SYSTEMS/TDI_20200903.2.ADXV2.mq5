//+------------------------------------------------------------------+
//|                                                TDI_CONVERTED.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Expert\Money\MoneyFixedMargin.mqh>

CPositionInfo           m_position;                   // trade position object
CSymbolInfo             m_symbol;                     // symbol info object
CTrade                  m_trade;                      // trading object

bool                    lowestvolume=false;
bool                    highestvolume=false;
double                  fixed_lots=0.005;
double                  BSL=300000.01;
double                  SSL=300000.01;
double                  BTP=11180.01;
double                  STP=11180.01;
int                     MAX_TRADES_ALLOWED=2;


input ushort            InpTrailingStop   = 1000;        // Trailing Stop (in pips)
input ushort            InpTrailingStep   = 100;        // Trailing Step (in pips)
double                  ExtTrailingStop=0.0;
double                  ExtTrailingStep=0.0;
int                     handle_iADX;
enum                    enum_entry
  {
   method1,//method 1 (stochastic 20%)
   method2 //method 2 (stochastic 50%)
  };
enum                    enum_stoploss
  {
   stoploss_signalbar,//below/above the signal bar
   stoploss_samesize, //same size as takeprofit
   stoploss_prevbar //below/above the previous bar
  };

input                   enum_entry        entry_method=method2;
input                   enum_stoploss     stop_method=stoploss_prevbar;



input double            signal_strength = 1.5;

input int               hl_multiplier= 3;
input long               m_magic=111111142193;

input string            c_comment="TDI_GENERIC_99923";
double                  ExtStopLoss=0.0;
double                  ExtTakeProfit=0.0;
datetime                last=0;
int                     sells,buys;
input ushort            InpStopLoss       = 50;       // Stop Loss (in pips)
input double            InpTakeProfit     = 300;       // Take Profit (in pips)
int                     handle_iCustom_TDI;
int                     handle_iStochastic;
int                     RSI_handle,FastMaHandle,SlowMaHandle,m_handle_bb;
double                  m_adjusted_point;             // point value adjusted for 3 or 5 points


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   double MinLot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double MaxLot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);

   if(lowestvolume)
      fixed_lots=NormalizeDouble(MinLot,2);
   if(highestvolume)
      fixed_lots=NormalizeDouble(MaxLot,2);

//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_adjusted_point=m_symbol.Point()*digits_adjust;

//---
   if(InpTrailingStop!=0 && InpTrailingStep==0)
     {
      Alert(__FUNCTION__," ERROR: Trailing is not possible: the parameter \"Trailing Step\" is zero!");
      return(INIT_PARAMETERS_INCORRECT);
     }
//---

   ExtStopLoss       = InpStopLoss     * m_adjusted_point;
   ExtTakeProfit     = InpTakeProfit   * m_adjusted_point;
   ExtTrailingStop   = InpTrailingStop * m_adjusted_point;
   ExtTrailingStep   = InpTrailingStep * m_adjusted_point;



//--- create handle of the indicator iADX
   handle_iADX=iADX(Symbol(),Period(),5);
   if(handle_iADX==INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the iADX indicator for the symbol %s/%s, error code %d",
                  Symbol(),
                  EnumToString(Period()),
                  GetLastError());

      return(INIT_FAILED);
     }

   RSI_handle = iRSI(Symbol(), Period(), 13,PRICE_CLOSE);
   if(RSI_handle==INVALID_HANDLE)
      return(false);

   m_handle_bb=iBands(Symbol(), Period(),34,0,1.618,RSI_handle);
   if(m_handle_bb==INVALID_HANDLE)
      return(false);
//green //ma 2
   FastMaHandle=iMA(NULL,0,2,0,MODE_SMA,RSI_handle);
   if(FastMaHandle==INVALID_HANDLE)
      return(false);
//red   //ma 7
   SlowMaHandle=iMA(NULL,0,7,0,MODE_SMA,RSI_handle);
   if(SlowMaHandle==INVALID_HANDLE)
      return(false);

   handle_iStochastic=iStochastic(Symbol(),Period(),7,3,3,MODE_SMA,STO_CLOSECLOSE);
   if(handle_iStochastic==INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the iCustom indicator for the symbol %s/%s, error code %d",Symbol(),EnumToString(Period()),GetLastError());
      return(INIT_FAILED);
     }
//--- create handle of the indicator iCustom
   handle_iCustom_TDI=iCustom(Symbol(),Period(),"TradersDynamicIndex");
   if(handle_iCustom_TDI==INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the iCustom indicator for the symbol %s/%s, error code %d",Symbol(),EnumToString(Period()),GetLastError());
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   double 
   //DI (+)
   ADX_DI_PLUS,ADX_DI_PLUS_BEFORE
   //DI (-)
   ,ADXDI_MINUS,ADXDI_MINUS_BEFORE
   //ADX MAIN
   ,ADXD_MAIN  ,ADXD_MAIN_BEFORE  ;

   ADXD_MAIN = iADXGet(MAIN_LINE,1);
   ADXD_MAIN_BEFORE = iADXGet(MAIN_LINE,2);
   ADX_DI_PLUS = iADXGet(PLUSDI_LINE, 1);
   ADX_DI_PLUS_BEFORE=iADXGet(PLUSDI_LINE, 2);
   ADXDI_MINUS = iADXGet(MINUSDI_LINE, 1);
   ADXDI_MINUS_BEFORE = iADXGet(MINUSDI_LINE, 2);

   /*


   TRAILING STOP LOSS SYSTEM



   */
//Trailing();


   double bufferzero[],bufferone[],buffertwo[],buffer3[],buffer4[],buffer5[];
   double tdi_green_s1=0.0,tdi_green_s1_minus_one=0.0,
          tdi_green_s2=0.0,tdi_red=0.0,tdi_green_s2_minus_one=0.0,
          tdi_red_minus_one=0.0,
          tdi_yellow=0.0;
   /*
      VB HIGH  -- BLUE
   */
   if(iGetArray(handle_iCustom_TDI,0,0,1,bufferone)) {}

   /*
      MARKET BASE LINE -- YELLOW
   */
   if(iGetArray(handle_iCustom_TDI,1,0,1,buffertwo))
     {
      tdi_yellow=buffertwo[0];
     }

   /*
      VB LOW -- BLUE
   */
   if(iGetArray(handle_iCustom_TDI,2,0,1,buffertwo)) {}

   /*
      TRADE SIGNAL LINE   RED      mB
   */
   if(iGetArray(handle_iCustom_TDI,4,0,2,buffer4))
     {
      tdi_red=buffer4[0];
      tdi_red_minus_one=buffer4[1];
     }
   /*
      RSI Price line    GREEN
   */
   if(iGetArray(handle_iCustom_TDI,3,0,2,buffer3))
     {
      tdi_green_s2=buffer3[0];
      tdi_green_s2_minus_one=buffer3[1];
     }


// RSI BUFFER  //GREEN
   if(iGetArray(handle_iCustom_TDI,5,0,2,buffer5))
     {

      tdi_green_s1=buffer5[0];
      tdi_green_s1_minus_one=buffer5[1];
     }
   bool adx_sell_cross=false;
   bool adx_buy_cross = false;
   bool adx_triggered =false;
   bool adx_buy_trend =false; bool adx_sell_trend=false;
   
   double ask=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   double bid=SymbolInfoDouble(Symbol(),SYMBOL_BID);
   double sto_one[];

   ArraySetAsSeries(sto_one,true);
   int start_pos  = 0;
   int count      = 3;

   if(!iStochasticGetArray(handle_iStochastic,MAIN_LINE,start_pos,count,sto_one))
      int digits=(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS);

   RefreshRates();

    adx_triggered = (ADXD_MAIN >= 30.00);
    adx_buy_cross = ((ADX_DI_PLUS_BEFORE < ADXDI_MINUS_BEFORE) && (ADX_DI_PLUS>ADXDI_MINUS) );
    adx_sell_cross = ((ADXDI_MINUS_BEFORE < ADX_DI_PLUS_BEFORE) && (ADXDI_MINUS>ADX_DI_PLUS) );
    
    Comment(" \n\nbuy_cross :"+(string)adx_buy_cross+"\nadx_sell_cross:"+ (string)adx_sell_cross +"\n\nADX_DI_PLUS:               " 
    +(string)NormalizeDouble(ADX_DI_PLUS,2)+  "  ADXDI_MINUS :             " 
    +(string)NormalizeDouble(ADXDI_MINUS,2)
    +"\nADX_DI_PLUS_BEFORE:" +(string)NormalizeDouble(ADX_DI_PLUS_BEFORE,2)+  "  ADXDI_MINUS_BEFORE :" 
    +(string)NormalizeDouble(ADXDI_MINUS_BEFORE,2)
    
    );

   adx_buy_trend =((ADX_DI_PLUS_BEFORE>=20 && ADX_DI_PLUS >=20)&& (ADX_DI_PLUS_BEFORE < ADX_DI_PLUS)&&   (ADX_DI_PLUS > ADXDI_MINUS));
   
   adx_sell_trend =((ADXDI_MINUS_BEFORE>=20 && ADXDI_MINUS >=20) &&  (ADXDI_MINUS_BEFORE < ADXDI_MINUS)  &&  (ADXDI_MINUS > ADX_DI_PLUS));
   
    
   if(adx_triggered)
   {
      if(adx_buy_cross){    ADXBUYSELL(1); Print(" adx_buy_cross   ");  return;    }
      if(adx_buy_trend){    ADXBUYSELL(1); Print("  adx_buy_trend  ");  return;    }
      if(adx_sell_cross){   ADXBUYSELL(2);  Print(" adx_sell_cross   "); return;}
      if(adx_sell_trend){   ADXBUYSELL(2);  Print(" adx_sell_trend   "); return;}
   }
   return;

   double TDI_RED_NORMALIZED = NormalizeDouble(tdi_red,2) ;
   double TDI_YEL_NORMALIZED =NormalizeDouble(tdi_yellow,2) ;
   double TDI_GRNS1_NORMALIZED =NormalizeDouble(tdi_green_s1,2);
   double TDI_GRNS2_NORMALIZED =NormalizeDouble(tdi_green_s2,2) ;
   double TDI_GRNS2B4_NORMALIZED = NormalizeDouble(tdi_green_s2_minus_one,2) ;
   double TDI_REDB4_NORMALIZED =NormalizeDouble(tdi_red_minus_one,2) ;

   double red_green_gap=NormalizeDouble(TDI_GRNS2_NORMALIZED-TDI_RED_NORMALIZED,2);
   double green_red_gap=NormalizeDouble(TDI_RED_NORMALIZED-TDI_GRNS2_NORMALIZED,2);

   //Comment("\n\n\n red_green_gap :"+red_green_gap+" green-red_gap :"+green_red_gap);


//SELL IF
//--> Stochastic is below 20
//--> Green and Red        Bellow Yellow
//--> Green Crosses Red Down OR
//    Green rebounds down from Red
   if
   (
//((entry_method==method1 && sto_one[0]>20)|| (entry_method==method2 && sto_one[0]>50))
//&&
// tdi_green_s2>tdi_yellow && tdi_red>tdi_yellow && tdi_green_s1>tdi_yellow
// &&
//buffer no 5
//(tdi_green_s1_minus_one>tdi_red_minus_one) && (tdi_green_s1<=tdi_red || tdi_green_s2<=tdi_red)
//buffer no 3 - rsi price line
      (
//(tdi_green_s2_minus_one>=tdi_red_minus_one) &&
         (tdi_green_s2<tdi_red)   && (green_red_gap>=2.2))
      &&
      (PositionsTotal()<MAX_TRADES_ALLOWED)
   )
     {

      //Comment("[GREEN and RED] below YELLOW\nGREEN below RED\n[SELL]\nSTOC>50");

      //double tp = NormalizePrice(bid-1.01);
      //double sl = NormalizePrice(bid+29.01);

      double sl = NormalizeDouble(bid + (SSL*Point()),_Digits);
      double tp = NormalizeDouble(bid - (STP*Point()),_Digits);


      int ticket= 0;

      MqlTradeRequest req= {};
      req.action      = TRADE_ACTION_DEAL;
      req.symbol      = _Symbol;
      req.magic       = m_magic;
      req.volume      = fixed_lots;//SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_LIMIT);//fixed_lots;
      req.type        = ORDER_TYPE_SELL;
      req.price       = SymbolInfoDouble(_Symbol, SYMBOL_BID);;
      req.sl          = 0;
      req.tp          = tp;
      req.deviation   = 20;
      req.comment     = "TDI_STOC_"+(string)(PeriodSeconds()/60);
      MqlTradeResult  res= {0};
      if(!OrderSendAsync(req,res))
        {
         Print(__FUNCTION__,": error ",GetLastError(),", retcode = ",res.retcode);
         if(res.retcode==10009 || res.retcode==10008) //Request is completed or order placed
           {
            Print("An order has been successfully placed with Ticket#:",res.order,"!!");
           }
         else
           {
            Print("The order request could not be completed -error:",GetLastError()," with trade return code ",res.retcode);
            ResetLastError();
           }
        }
      else
        {
         PlaySound("cashreg");
        }
     }

//BUY IF
//--> Stochastic is above 80
//--> Green and Red above Yellow
//--> Green Crosses Red Up OR Green rebounds up from Red



   if(
//((entry_method==method1 && sto_one[0]<80)
//|| (entry_method==method2 && sto_one[0]<50))
//&&
      (tdi_green_s1<tdi_yellow && tdi_red<tdi_yellow && tdi_green_s2<tdi_yellow)
      &&
//buffer no 5
//(tdi_green_s1_minus_one>tdi_red_minus_one) && (tdi_green_s1<=tdi_red || tdi_green_s2<=tdi_red)
//buffer no 3 - rsi price line
      (
//(tdi_green_s2_minus_one<=tdi_red_minus_one) &&
         (tdi_green_s2>tdi_red) && (red_green_gap >= 2.2))
      && (PositionsTotal()<MAX_TRADES_ALLOWED)
   )
     {
      double sl = NormalizeDouble(ask - (BSL*_Point),_Digits);
      double tp = NormalizeDouble(ask + (BTP*_Point),_Digits);

      //int ticket= 0;


      //ticket=OrderSend(Symbol(),OP_BUY,fixed_lots,
      //ask
      //,3,0,0,comment,magic,0,clrBlue);

      MqlTradeRequest req= {};
      req.action      = TRADE_ACTION_DEAL;
      req.symbol      = _Symbol;
      req.magic       = m_magic;
      req.volume      =fixed_lots;//SymbolInfoDoufble(Symbol(),SYMBOL_VOLUME_LIMIT);//fixed_lots;
      req.type        = ORDER_TYPE_BUY;
      req.price       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      req.sl          = 0;
      req.tp          = tp;

      req.deviation   = 20;
      req.comment     = "TDI_STOC_"+(string)(PeriodSeconds()/60);

      MqlTradeResult  res= {0};
      if(!OrderSendAsync(req,res))
        {
         Print(__FUNCTION__,": error ",GetLastError(),", retcode = ",res.retcode);
        }
      else
       {
       PlaySound("cashreg");
      }
      //}//end if sl is ok
     }



  }

//+------------------------------------------------------------------+
//| Trailing                                                         |
//+------------------------------------------------------------------+
void Trailing()
  {
   if(InpTrailingStop==0)
      return;

   for(int i=PositionsTotal()-1; i>=0; i--) // returns the number of open positions
      if(m_position.SelectByIndex(i))

         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
           {

            if(m_position.PositionType()==POSITION_TYPE_BUY)
              {
               Print("BUY m_position.PriceCurrent()-m_position.PriceOpen()>ExtTrailingStop+ExtTrailingStep:"+(string)(m_position.PriceCurrent()-m_position.PriceOpen()>ExtTrailingStop+ExtTrailingStep));
               if(m_position.PriceCurrent()-m_position.PriceOpen()>ExtTrailingStop+ExtTrailingStep)
                  Print("buy m_position.StopLoss()<m_position.PriceCurrent()-(ExtTrailingStop+ExtTrailingStep):"+(string)(m_position.StopLoss()<m_position.PriceCurrent()-(ExtTrailingStop+ExtTrailingStep)));

               if(m_position.StopLoss()<m_position.PriceCurrent()-(ExtTrailingStop+ExtTrailingStep))
                 {
                  if(!m_trade.PositionModify(m_position.Ticket()
                                             ,//sl    , tp
                                             m_symbol.NormalizePrice(m_position.PriceCurrent()-ExtTrailingStop),        m_position.TakeProfit()))
                     Print("Modify BUY ",m_position.Ticket(), " Position -> false. Result Retcode: ",m_trade.ResultRetcode(), ", description of result: ",m_trade.ResultRetcodeDescription());
                  PrintResultModify(m_trade,m_symbol,m_position);
                  continue;
                 }
              }
            else//SELL POSITION
              {
               if(m_position.PriceOpen()-m_position.PriceCurrent()>ExtTrailingStop+ExtTrailingStep)
                  if((m_position.StopLoss()>(m_position.PriceCurrent()+(ExtTrailingStop+ExtTrailingStep))) || (m_position.StopLoss()==0))
                    {
                     if(!m_trade.PositionModify(m_position.Ticket(), m_symbol.NormalizePrice(m_position.PriceCurrent()+ExtTrailingStop), m_position.TakeProfit()))
                        Print("Modify SELL ",m_position.Ticket()," Position -> false. Result Retcode: ",m_trade.ResultRetcode(), ", description of result: ",m_trade.ResultRetcodeDescription());
                     PrintResultModify(m_trade,m_symbol,m_position);
                    }
              }

           }
  }

//+------------------------------------------------------------------+
//| Print CTrade result                                              |
//+------------------------------------------------------------------+
void PrintResultModify(CTrade &trade,CSymbolInfo &symbol,CPositionInfo &position)
  {
   Print("Code of request result: "+IntegerToString(trade.ResultRetcode()));
   Print("code of request result as a string: "+trade.ResultRetcodeDescription());
   Print("Deal ticket: "+IntegerToString(trade.ResultDeal()));
   Print("Order ticket: "+IntegerToString(trade.ResultOrder()));
   Print("Volume of deal or order: "+DoubleToString(trade.ResultVolume(),2));
   Print("Price, confirmed by broker: "+DoubleToString(trade.ResultPrice(),symbol.Digits()));
   Print("Current bid price: "+DoubleToString(symbol.Bid(),symbol.Digits())+" (the requote): "+DoubleToString(trade.ResultBid(),symbol.Digits()));
   Print("Current ask price: "+DoubleToString(symbol.Ask(),symbol.Digits())+" (the requote): "+DoubleToString(trade.ResultAsk(),symbol.Digits()));
   Print("Broker comment: "+trade.ResultComment());
   Print("Price of position opening: "+DoubleToString(position.PriceOpen(),symbol.Digits()));
   Print("Price of position's Stop Loss: "+DoubleToString(position.StopLoss(),symbol.Digits()));
   Print("Price of position's Take Profit: "+DoubleToString(position.TakeProfit(),symbol.Digits()));
   Print("Current price by position: "+DoubleToString(position.PriceCurrent(),symbol.Digits()));
  }
//+------------------------------------------------------------------+




//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
  {
   double m_tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   return(NormalizeDouble(MathRound(price/m_tick_size)*m_tick_size,_Digits));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool iGetArray(const int handle,const int buffer,const int start_pos,const int count,double &arr_buffer[])
  {
   bool result=true;
   if(!ArrayIsDynamic(arr_buffer))
     {

      PrintFormat("ERROR! EA: %s, FUNCTION: %s, this a no dynamic array!",__FILE__,__FUNCTION__);
      return(false);
     }
   ArrayFree(arr_buffer);

   ResetLastError();

   int copied=CopyBuffer(handle,buffer,start_pos,count,arr_buffer);
   if(copied!=count)
     {
      Print("Error indicator: "+(string)handle);
      PrintFormat("ERROR! EA: %s, FUNCTION: %s, amount to copy: %d, copied: %d, error code %d",
                  __FILE__,__FUNCTION__,count,copied,GetLastError());

      return(false);
     }
   return(result);
  }



void OnDeinit(const int reason) {  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool iStochasticGetArray(const int handle_,const int buffer,const int start_pos,const int count,double &arr_buffer[])
  {
   if(!ArrayIsDynamic(arr_buffer))
     {
      Print("This a no dynamic array!");
      return(false);
     }
   ArrayFree(arr_buffer);

   ResetLastError();

   int copy_buffer=CopyBuffer(handle_,buffer,start_pos,count,arr_buffer);
   if(copy_buffer!=count)
     {
      //--- if the copying fails, tell the error code
      PrintFormat("Failed to copy data from the iStochastic indicator, error code %d",GetLastError());
      //--- quit with false result - it means that the indicator is considered as not calculated
      return(false);
     }
//---
   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool RefreshRates(void)
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
     {
      Print("RefreshRates error");
      return(false);
     }
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
      return(false);
//---
   return(true);
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Get value of buffers for the iADX                                |
//|  the buffer numbers are the following:                           |
//|   0 - iADXBuffer, 1 - DI_plusBuffer, 2 - DI_minusBuffer          |
//+------------------------------------------------------------------+
double iADXGet(const int buffer,const int index)
  {
   double ADX[];
   ArraySetAsSeries(ADX,true);
//--- reset error code 
   ResetLastError();
   
//--- fill a part of the iADXBuffer array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(handle_iADX,buffer,0,index+1,ADX)<0)
     {
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iADX indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(0.0);
     }
   return(ADX[index]);
  }
//+------------------------------------------------------------------+

void ADXBUYSELL(int transtype)
{
   double ask=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   double bid=SymbolInfoDouble(Symbol(),SYMBOL_BID);

//sell
      double sellsl = NormalizeDouble(bid + (SSL*_Point),_Digits);
      double selltp = NormalizeDouble(bid - (STP*_Point),_Digits);
//buy
      double buysl = NormalizeDouble(ask - (BSL*_Point),_Digits);
      double buytp = NormalizeDouble(ask + (BTP*_Point),_Digits);
      
if(transtype==1)
{
   //buy op
   MqlTradeRequest req= {};
      req.action      = TRADE_ACTION_DEAL;
      req.symbol      = _Symbol;
      req.magic       = m_magic;
      req.volume      =fixed_lots;//SymbolInfoDoufble(Symbol(),SYMBOL_VOLUME_LIMIT);//fixed_lots;
      req.type        = ORDER_TYPE_BUY;
      req.price       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      req.sl          = buysl;
      req.tp          = buytp;

      req.deviation   = 20;
      req.comment     = "adx TDI_STOC_"+(string)(PeriodSeconds()/60);

      MqlTradeResult  res= {0};
      if(!OrderSendAsync(req,res))
        {
         Print(__FUNCTION__,": error ",GetLastError(),", retcode = ",res.retcode);
        }
      else
       {
       PlaySound("cashreg");
      }

}
if(transtype==2)
{
   //sell op
      MqlTradeRequest req= {};
      req.action      = TRADE_ACTION_DEAL;
      req.symbol      = _Symbol;
      req.magic       = m_magic;
      req.volume      = fixed_lots;//SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_LIMIT);//fixed_lots;
      req.type        = ORDER_TYPE_SELL;
      req.price       = SymbolInfoDouble(_Symbol, SYMBOL_BID);;
      req.sl          = sellsl;
      req.tp          = selltp;
      req.deviation   = 20;
      req.comment     = "adx TDI_STOC_"+(string)(PeriodSeconds()/60);
      MqlTradeResult  res= {0};
      if(!OrderSendAsync(req,res))
        {
         Print(__FUNCTION__,": error ",GetLastError(),", retcode = ",res.retcode);
         if(res.retcode==10009 || res.retcode==10008) //Request is completed or order placed
           {
            Print("An order has been successfully placed with Ticket#:",res.order,"!!");
           }
         else
           {
            Print("The order request could not be completed -error:",GetLastError()," with trade return code ",res.retcode);
            ResetLastError();
           }
        }
      else
        {
         PlaySound("cashreg");
        }
     }
}


