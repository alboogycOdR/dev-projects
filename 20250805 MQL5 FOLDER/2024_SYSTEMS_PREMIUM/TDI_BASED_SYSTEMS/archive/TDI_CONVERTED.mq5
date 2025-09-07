//+------------------------------------------------------------------+
//|                                                TDI_CONVERTED.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
 
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
input enum_entry entry_method=method1;
input enum_stoploss stop_method=stoploss_prevbar;
input double signal_strength = 1.5; 
input double fixed_lots=0.01;
input int hl_multiplier= 3;
input int magic=11111;
input string comment="TDI_GENERIC";
 
datetime last=0;
int sells,buys;

void OnTick()
  {

   //if(IsTesting() || IsVisualMode() || IsOptimization())
   //   Alert("Sending to Main");
   //    main_function(Symbol(),hl_multiplier);

  }
 
void OnTimer()
  {
int local_hl_multiplier =3; 

   //if(!IsTesting() && !IsOptimization() && !IsVisualMode())
   //  {
   //   main_function("USDJPY",3);
   //   main_function("GBPCHF",2);
   //   main_function("GBPUSD",3);
   //   main_function("USDCHF",3);
   //   main_function("GOLD",3);
   //  }
string local_instrument=Symbol()   ;
if(iTime(local_instrument,Period(),1)>last)
     {//execute this code on each close
      RefreshRates();
      //---
      //first of all we need ontick strategy, simple and working one, with simple dynamic entries
      //and exits..

      //--- COUNT AVERAGE H-L FOR DYNAMIC EXECUTION
      double average_hl=NormalizeDouble(
          (
          (iHigh(Symbol(),Period(),1)-iLow(_Symbol,Period(),1))
          +
          (iHigh(_Symbol,Period(),2)-iLow(_Symbol,Period(),2))
          +
          (iHigh(_Symbol,Period(),3)-iLow(_Symbol,Period(),3))
          +
          (iHigh(_Symbol,Period(),4)-iLow(_Symbol,Period(),4))
          +
          (iHigh(_Symbol,Period(),5)-iLow(_Symbol,Period(),5))
          )/5
          ,
          (int)MarketInfo(local_instrument,MODE_DIGITS));
      //--- END OF COUNTING AVERAGE H-L

      double stoch_main=iStochastic(local_instrument,Period(),14,3,3,MODE_SMA,STO_CLOSECLOSE,MODE_MAIN,1);
      double tdi_red=iCustom(local_instrument,Period(),"tdi_rt_alerts_divergence",13,0,34,2,0,7,0,false,false,false,false,false,false,"alert2.wav",false,true,true,1,4.0,4.0,true,true,clrLimeGreen,clrOrangeRed,233,234,159,159,"tdi divergence1",4,1);
      double tdi_yellow=iCustom(local_instrument,Period(),"tdi_rt_alerts_divergence",13,0,34,2,0,7,0,false,false,false,false,false,false,"alert2.wav",false,true,true,1,4.0,4.0,true,true,clrLimeGreen,clrOrangeRed,233,234,159,159,"tdi divergence1",1,1);
      double tdi_green_s1=iCustom(local_instrument,Period(),"tdi_rt_alerts_divergence",13,0,34,2,0,7,0,false,false,false,false,false,false,"alert2.wav",false,true,true,1,4.0,4.0,true,true,clrLimeGreen,clrOrangeRed, 233,234,159,159,"tdi divergence1",3,1);
      double tdi_green_s2=iCustom(local_instrument,Period(),"tdi_rt_alerts_divergence",13,0,34,2,0,7,0,false,false,false,false,false,false,"alert2.wav",false,true,true,1,4.0,4.0,true,true,clrLimeGreen,clrOrangeRed,233,234,159,159,"tdi divergence1",3,2);
      double ask=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
      double bid=SymbolInfoDouble(Symbol(),SYMBOL_BID);

      //SELL IF
      //--> Stochastic is below 20
      //--> Green and Red        Bellow Yellow
      //--> Green Crosses Red Down OR 
        //    Green rebounds down from Red
      if(((entry_method==method1 && stoch_main<20) || (entry_method==method2 && stoch_main<50)) && //stochastic below 20 
         tdi_green_s1<tdi_yellow && tdi_red<tdi_yellow && //green and red below yellow
         tdi_green_s1<tdi_red && tdi_green_s2>=tdi_red && //
         average_hl>0 && 
         OrdersTotal()==0
         )
      {
         //sell
         double sl=0;
      
         if(stop_method==stoploss_samesize){sl=NormalizeDouble(MarketInfo(local_instrument,MODE_ASK)+average_hl*local_hl_multiplier,(int)MarketInfo(local_instrument,MODE_DIGITS));}
         if(stop_method==stoploss_signalbar){sl=NormalizeDouble(iHigh(local_instrument,Period(),1),(int)MarketInfo(local_instrument,MODE_DIGITS));}
         if(stop_method==stoploss_prevbar){sl=NormalizeDouble(iHigh(local_instrument,Period(),2),(int)MarketInfo(local_instrument,MODE_DIGITS));}

         if((sl-MarketInfo(local_instrument,MODE_ASK))>=average_hl*signal_strength){//if sl is ok
            
            double tp = NormalizeDouble(MarketInfo(local_instrument,MODE_BID)-average_hl*local_hl_multiplier,(int)MarketInfo(local_instrument,MODE_DIGITS));
            int ticket= 0;
            
            ticket=OrderSend(Symbol()
            ,OP_SELL
            ,fixed_lots
            ,MarketInfo(local_instrument,MODE_BID)
            ,3,0,0
            ,comment
            ,magic,0,clrRed);
            
            //if(ticket>0)
            //  {
            //   if(OrderSelect(ticket,SELECT_BY_TICKET))
            //     {
            //      if(OrderModify(OrderTicket(),OrderOpenPrice(),sl,tp,OrderExpiration(),clrRed))
            //        {
            //         Print("SELL");}
            //         else
            //         {GetLastError();
            //         Print("SL (current/new): "+"("+(string)OrderStopLoss()+"/"+(string)sl+")");
            //         Print("TP (current/new): "+"("+(string)OrderTakeProfit()+"/"+(string)tp+")");
            //        }
            //     }
            //  }
           }//end if sl is ok 
        }

      //BUY IF
      //--> Stochastic is above 80
      //--> Green and Red above Yellow
      //--> Green Crosses Red Up OR Green rebounds up from Red
      if(((entry_method==method1 && stoch_main>80) || (entry_method==method2 && stoch_main>50)) && //stochastic above 80 
         tdi_green_s1>tdi_yellow && tdi_red>tdi_yellow && //green and red below yellow
         tdi_green_s1>tdi_red && tdi_green_s2>=tdi_red && //
         average_hl>0 && 
         OrdersTotal()==0
         )
        {
        
         //--- obtain spread from the symbol properties
         //bool spreadfloat=SymbolInfoInteger(Symbol(),SYMBOL_SPREAD_FLOAT);
         //string comm=StringFormat("Spread %s = %I64d points\r\n",
         //                   spreadfloat?"floating":"fixed",
         //                   SymbolInfoInteger(Symbol(),SYMBOL_SPREAD));
         ////--- now let's calculate the spread by ourselves

         //double spread=ask-bid;
         //int spread_points=(int)MathRound(spread/SymbolInfoDouble(Symbol(),SYMBOL_POINT));
         //comm=comm+"Calculated spread = "+(string)spread_points+" points";
         //Comment(comm);
   
         //buy
         
         double sl=0;
         if(stop_method==stoploss_samesize){
         sl=NormalizeDouble(bid-average_hl*local_hl_multiplier,SymbolInfoInteger(Symbol(),SYMBOL_DIGITS));
                }
         if(stop_method==stoploss_signalbar){sl=NormalizeDouble(iLow(_Symbol,Period(),1),(int)MarketInfo(_Symbol,MODE_DIGITS));}
         if(stop_method==stoploss_prevbar){sl=NormalizeDouble(iLow(_Symbol,Period(),2),(int)MarketInfo(_Symbol,MODE_DIGITS));}

         if((MarketInfo(local_instrument,MODE_BID)-sl)>=average_hl*signal_strength)
           {//if sl is ok
         
            double tp = NormalizeDouble(ask+average_hl*local_hl_multiplier,(int)MarketInfo(local_instrument,MODE_DIGITS));
            int ticket= 0;
            ticket=OrderSend(Symbol(),OP_BUY,fixed_lots,
            ask
            ,3,0,0,comment,magic,0,clrBlue);

            //if(ticket>0)
            //  {
            //   if(OrderSelect(ticket,SELECT_BY_TICKET))
            //     {
            //      if(OrderModify(OrderTicket(),OrderOpenPrice(),sl,tp,OrderExpiration(),clrRed))
            //        {
            //         Print("BUY");}else{GetLastError();
            //         Print("SL (current/new): "+"("+(string)OrderStopLoss()+"/"+(string)sl+")");
            //         Print("TP (current/new): "+"("+(string)OrderTakeProfit()+"/"+(string)tp+")");
            //        }
            //     }
            //  }
           }//end if sl is ok 
        }

      last=iTime(Symbol(),Period(),1);
     }//end interval
  }
//+------------------------------------------------------------------+

void main_function(string local_instrument,int local_hl_multiplier)
  {

   
  }//end of main function
  
  
  //+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   //if(AccountNumber()!=706766){Alert("Wrong Account Number! Expert Will Now Be Removed!");ExpertRemove();}
   
   
//--- create timer
   //EventSetTimer(60);//60 seconds = 1 minute; 60*5 = 5 minutes

   //Print("Verifying if indicators are loaded (current instrument)...");
   //Print("Stochastic: "+(string)iStochastic(Symbol(),Period(),14,3,3,MODE_SMA,STO_CLOSECLOSE,MODE_MAIN,1));
   //Print("TDI Yellow: "+(string)iCustom(Symbol(),Period(),"tdi_rt_alerts_divergence",
                         // 13,0,34,2,0,7,0,
                         // false,false,false,false,false,false,"alert2.wav",false,
                         // true,true,1,4.0,4.0,true,true,
                          //clrLimeGreen,clrOrangeRed,
                        //  233,234,159,159,"tdi divergence1",
                         // 1,1));
//---





   //if(!IsTesting() && !IsOptimization() && !IsVisualMode())
   //  {
   //   if(//adding core pairs
   //      SymbolSelect("USDJPY",true) && 
   //      SymbolSelect("GBPCHF",true) && 
   //      SymbolSelect("GBPUSD",true) && 
   //      SymbolSelect("USDCHF",true) && 
   //      SymbolSelect("GBPAUD",true)
   //      ){Print("Instruments added successfully!");}
   //      else{
   //        Alert("Couldn't add core pairs to Market Watch. Expert will be removed.");ExpertRemove();}
   //  }//if live or demo

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
