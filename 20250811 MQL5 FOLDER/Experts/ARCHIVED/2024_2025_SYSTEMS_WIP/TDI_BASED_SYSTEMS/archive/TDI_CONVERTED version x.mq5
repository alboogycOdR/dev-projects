//+------------------------------------------------------------------+
//|                                                TDI_CONVERTED.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  

CSymbolInfo    m_symbol;                     // symbol info object

enum enum_entry
  {
   method1,//method 1 (stochastic 20%)
   method2 //method 2 (stochastic 50%)
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum enum_stoploss
  {
   stoploss_signalbar,//below/above the signal bar
   stoploss_samesize, //same size as takeprofit
   stoploss_prevbar //below/above the previous bar
  };

//FIELDS
input enum_entry        entry_method=method2;
input enum_stoploss     stop_method=stoploss_prevbar;

double BSL=300000.01;
double BTP=3000.01;
double SSL=300000.01;
double STP=3000.01;


input double          signal_strength = 1.5;
input double          fixed_lots=0.005;
input int             hl_multiplier= 3;
input int             magic=11123;
input string          comment="TDI_GENERIC_11123";

datetime              last=0;
int                   sells,buys;

int                   handle_iCustom_TDI;
int                   handle_iStochastic;
int                   RSI_handle,FastMaHandle,SlowMaHandle,m_handle_bb;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   Comment("");
   RSI_handle = iRSI(Symbol(), Period(), 13,PRICE_CLOSE);
   if(RSI_handle==INVALID_HANDLE)      return(false);

   m_handle_bb=iBands(Symbol(), Period(),34,0,1.618,RSI_handle);
   if(m_handle_bb==INVALID_HANDLE)      return(false);
//green //ma 2
   FastMaHandle=iMA(NULL,0,2,0,MODE_SMA,RSI_handle);
   if(FastMaHandle==INVALID_HANDLE)      return(false);      
//red   //ma 7
   SlowMaHandle=iMA(NULL,0,7,0,MODE_SMA,RSI_handle);
   if(SlowMaHandle==INVALID_HANDLE)      return(false);

 

   handle_iStochastic=iStochastic(Symbol(),Period(),14,3,3,MODE_SMA,STO_CLOSECLOSE);
   if(handle_iStochastic==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the iCustom indicator for the symbol %s/%s, error code %d",Symbol(),EnumToString(Period()),GetLastError());
      //--- the indicator is stopped early
      return(INIT_FAILED);
     }
//--- create handle of the indicator iCustom
   handle_iCustom_TDI=iCustom(Symbol(),Period(),"TradersDynamicIndex");
   if(handle_iCustom_TDI==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the iCustom indicator for the symbol %s/%s, error code %d",Symbol(),EnumToString(Period()),GetLastError());
      //--- the indicator is stopped early
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }






//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
Comment("");

   double bufferzero[],bufferone[],buffertwo[],buffer3[],buffer4[],buffer5[];
   double tdi_green_s1,tdi_green_s1_minus_one,
   tdi_green_s2,tdi_red,
   tdi_red_minus_one,
   tdi_yellow;

   string commentstring="";


/*  
   VB HIGH  -- BLUE
*/
   if(iGetArray(handle_iCustom_TDI,0,0,1,bufferone)){commentstring=" buff 0:"+bufferone[0];}
 
/*  
   MARKET BASE LINE -- YELLOW
*/
   if(iGetArray(handle_iCustom_TDI,1,0,1,buffertwo)){commentstring=commentstring+"\n buff 1:"+buffertwo[0];
   tdi_yellow=buffertwo[0];}
 
/*  
   VB LOW -- BLUE
*/
   if(iGetArray(handle_iCustom_TDI,2,0,1,buffertwo)){commentstring=commentstring+"\n buff 2:"+buffertwo[0];}

/*  
   TRADE SIGNAL LINE   RED      mB
*/
   if(iGetArray(handle_iCustom_TDI,4,0,2,buffer4)){  commentstring=commentstring+"\n buff 4:"+buffer4[0];
   tdi_red=buffer4[0];
   tdi_red_minus_one=buffer4[1];
   }
/*  
   RSI Price line    GREEN
*/
   if(iGetArray(handle_iCustom_TDI,3,0,1,buffer3)){commentstring=commentstring+"\n buff 3:"+buffer3[0];
   tdi_green_s2=buffer3[0];
   }


// RSI BUFFER  //GREEN
   if(iGetArray(handle_iCustom_TDI,5,0,2,buffer5))
     {
      commentstring=commentstring+"\n buff 5:"+buffer5[0];
      tdi_green_s1=buffer5[0];
      tdi_green_s1_minus_one=buffer5[1];
     }

//Comment(commentstring);

   double sto_one[];    ArraySetAsSeries(sto_one,true);
   int start_pos  = 0;
   int count      = 3;
   if(!iStochasticGetArray(handle_iStochastic,MAIN_LINE   ,start_pos    ,count   ,sto_one))
   
   
   
   
   
   int digits=SymbolInfoInteger(Symbol(),SYMBOL_DIGITS); RefreshRates();

      //---
      //first of all we need ontick strategy, simple and working one, with simple dynamic entries
      //and exits..
      double ask=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
      double bid=SymbolInfoDouble(Symbol(),SYMBOL_BID);

      //SELL IF
      //--> Stochastic is below 20
      //--> Green and Red        Bellow Yellow
      //--> Green Crosses Red Down OR
      //    Green rebounds down from Red

      if(
      //((entry_method==method1 && sto_one[0]>20) || (entry_method==method2 && sto_one[0]>60)) 
      //&&
        tdi_green_s1<tdi_yellow 
      && 
        tdi_red<tdi_yellow 
      && 
         (
         //tdi_green_s1_minus_one>tdi_red_minus_one &&  
         tdi_green_s1<=tdi_red 
         )
        //(tdi_green_s1<tdi_red || tdi_green_s2<tdi_red) //&&    average_hl>0 
      &&      PositionsTotal()<6
      )
        {
         
         //Comment("[GREEN and RED] below YELLOW\nGREEN below RED\n[SELL]\nSTOC>50");
         
         //double tp = NormalizePrice(bid-1.01);
         //double sl = NormalizePrice(bid+29.01);
         
         double sl = NormalizeDouble(bid + (SSL*Point()),_Digits);
         double tp = NormalizeDouble(bid - (STP*Point()),_Digits);
         
         Print(" SELL: bid:"+bid);
         Print(" tp:"+tp);
         Print(" sl:"+sl);
         int ticket= 0;

         MqlTradeRequest req= {0};
         req.action      = TRADE_ACTION_DEAL;
         req.symbol      = _Symbol;
         req.magic       = magic;
         req.volume      = fixed_lots;
         req.type        = ORDER_TYPE_SELL;
         req.price       = SymbolInfoDouble(_Symbol, SYMBOL_BID);;
         req.sl          = sl;
         req.tp          = tp;
         req.deviation   = 20;
         req.comment     = "TDI_STOC_"+PeriodSeconds()/60;
         MqlTradeResult  res= {0};


         if(!OrderSendAsync(req,res))
           {
                  Print(__FUNCTION__,": error ",GetLastError(),", retcode = ",res.retcode);
                  // get the result code
               if(res.retcode==10009 || res.retcode==10008) //Request is completed or order placed
                 {
                  //Alert("An order has been successfully placed with Ticket#:",res.order,"!!");
                  Print("An order has been successfully placed with Ticket#:",res.order,"!!");
                 }
               else
                 {
                  //Alert("The order request could not be completed -error:",GetLastError()," with trade return code ",res.retcode);
                  Print("The order request could not be completed -error:",GetLastError()," with trade return code ",res.retcode);
                  ResetLastError();
                   
                 }
            
           }
           else{
               PlaySound("tick");
           }
           
         
        }

      //BUY IF
      //--> Stochastic is above 80
      //--> Green and Red above Yellow
      //--> Green Crosses Red Up OR Green rebounds up from Red
      if(
         //((entry_method==method1 && sto_one[0]<80) || (entry_method==method2 && sto_one[0]<40)) 
         //&& 
         tdi_green_s1>tdi_yellow && tdi_red>tdi_yellow 
         && //green and red below yellow
         (
         //tdi_green_s1_minus_one<tdi_red_minus_one &&  
         tdi_green_s1>=tdi_red )
         //(tdi_green_s1>tdi_red || tdi_green_s2>tdi_red)  //      average_hl>0 
         &&  PositionsTotal()<6
        )
        {

        Comment("[GREEN and RED] above YELLOW\nGREEN above RED\n[SELL]\nSTOC<50");

         //double tp = NormalizePrice(ask +  1.01);
         //double sl = NormalizePrice(ask -  22.01);
         
         
         double sl = NormalizeDouble(ask - (BSL*_Point),_Digits);
         double tp = NormalizeDouble(ask + (BTP*_Point),_Digits);
         
         
         Print(" BUY ask:"+ask);
         Print(" tp:"+tp);
         Print(" sl:"+sl);
         
         int ticket= 0;


         //ticket=OrderSend(Symbol(),OP_BUY,fixed_lots,
         //ask
         //,3,0,0,comment,magic,0,clrBlue);

         MqlTradeRequest req= {0};
         req.action      = TRADE_ACTION_DEAL;
         req.symbol      = _Symbol;
         req.magic       = magic;
         req.volume      =fixed_lots;
         req.type        = ORDER_TYPE_BUY;
         req.price       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

         req.sl          = sl;
         req.tp          = tp;

         req.deviation   = 20;
         req.comment     = "TDI_STOC_"+PeriodSeconds()/60;

         MqlTradeResult  res= {0};
         if(!OrderSendAsync(req,res))
           {
            Print(__FUNCTION__,": error ",GetLastError(),", retcode = ",res.retcode);
           }
          else{
               PlaySound("tick");
           }


         //}//end if sl is ok
        }

 
 
  }
double NormalizePrice(double price)
  {
   double m_tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   return(NormalizeDouble(MathRound(price/m_tick_size)*m_tick_size,_Digits));
  }
  
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
      Print("Error indicator: "+handle);
      PrintFormat("ERROR! EA: %s, FUNCTION: %s, amount to copy: %d, copied: %d, error code %d",
                  __FILE__,__FUNCTION__,count,copied,GetLastError());

      return(false);
     }
   return(result);
  }
 
  
  
void OnDeinit(const int reason) {  }


bool iStochasticGetArray(const int handle_iStochastic,const int buffer,const int start_pos,const int count,double &arr_buffer[])
  {
   if(!ArrayIsDynamic(arr_buffer))
     {
      Print("This a no dynamic array!");
      return(false);
     }
   ArrayFree(arr_buffer);

   ResetLastError();

   int copy_buffer=CopyBuffer(handle_iStochastic,buffer,start_pos,count,arr_buffer);
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