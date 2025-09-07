//+------------------------------------------------------------------+
//|                                          TrendMeLeaveMe_Gold.mq4 |
//|                              Copyright © 2007, Eng. Waddah Attar |
//|                                          waddahattar@hotmail.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2007,Eng Waddah Attar"
#property link      "www.metaforex.net"
//---- 

extern bool   USE_AUTO_SETTINGS = true;
extern bool   USE_EXIT_SETTINGS = false;
extern double Lots               = 0.01;
extern double MaximumRisk        = 0.5;
double lotincreasewhenlosing     = 0;
extern double DisMmIfLotsUnder = 0.01;
extern double MaxLots = 50;
extern bool   AutoClose = true;

extern bool   EmailAlert= false;
extern string TradeHours = "_______________________";
extern bool   UseHourTrade = false; // Time filter
extern int    FromHourTrade = 7; // start trading on this hour
extern int    ToHourTrade = 17; // end trading on this hour
extern string BuyStop_Trend_Info = "_______________________";
extern string BuyStop_TrendName = "1";//BuyStop
extern int    BuyStop_TakeProfit = 2000;//50
extern int    BuyStop_StopLoss = 2000;//30
extern int    BuyStop_StepActive = 500;//10
extern int    BuyStop_StepPrepare = 100;//50

extern string BuyLimit_Trend_Info = "_______________________";
extern string BuyLimit_TrendName = "2";//BuyLimit
extern int    BuyLimit_TakeProfit = 2000;//50
extern int    BuyLimit_StopLoss = 2000;//30
extern int    BuyLimit_StepActive = 500;//5
extern int    BuyLimit_StepPrepare = 100;//50

extern string SellStop_Trend_Info = "_______________________";
extern string SellStop_TrendName = "3";//SellStop
extern int    SellStop_TakeProfit = 2000;//50
extern int    SellStop_StopLoss = 2000;//30
extern int    SellStop_StepActive = 500;//10
extern int    SellStop_StepPrepare = 100;//50

extern string SellLimit_Trend_Info = "_______________________";
extern string SellLimit_TrendName = "4";//selllimit
extern int    SellLimit_TakeProfit = 2000;//50
extern int    SellLimit_StopLoss = 2000;//30
extern int    SellLimit_StepActive = 500;//5
extern int    SellLimit_StepPrepare = 100;//50

//------
int MagicBuyStop = 119211;
int MagicSellStop = 19112;
int MagicBuyLimit = 19113;
int MagicSellLimit = 19114;
int glbOrderType;
int glbOrderTicket;
//+------------------------------------------------------------------+
//| Calculate optimal lot size                                       |
//+------------------------------------------------------------------+
double LotsOptimized()
  {
   double lot=Lots;
   int    orders=HistoryTotal();     // history orders total
   int    losses=0;                  // number of losses orders without a break
//---- select lot size
   lot=NormalizeDouble(AccountFreeMargin()*MaximumRisk/5000.0,10);
//---- calcuulate number of losses orders without a break
   if(lotincreasewhenlosing>0)
     {
      for(int i=orders-1;i>=0;i--)
        {
         if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==false) { Print("Error in history!"); break; }
         if(OrderSymbol()!=Symbol() || OrderType()>OP_SELL) continue;
         //----
         if(OrderProfit()>0) break;
         if(OrderProfit()<0) losses++;
        }
      if(losses>1) lot=NormalizeDouble(lot+lot+losses/lotincreasewhenlosing,2);
     }
//---- return lot size
   if(lot<DisMmIfLotsUnder) lot=Lots;
   if(lot> MaxLots) lot=MaxLots;
   return(lot);
  }
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
    int Leverage=AccountLeverage(); 
   double Balance=AccountBalance(); 
   double FreeMargin=AccountFreeMargin();
    double profit=AccountProfit();
    double equity=AccountEquity();

 
                double    SWAPLONG=MarketInfo("GBPJPYm",MODE_SWAPLONG);
   double    SWAPSHORT=MarketInfo("GBPJPYm",MODE_SWAPSHORT);
   int    MAXLOT=MarketInfo("GBPJPYm",MODE_MAXLOT);
   int    spread=MarketInfo("GBPJPYm",MODE_SPREAD);
            double    SWAPLONG1=MarketInfo("GBPUSDm",MODE_SWAPLONG);
   double    SWAPSHORT1=MarketInfo("GBPUSDm",MODE_SWAPSHORT);
   int    MAXLOT1=MarketInfo("GBPUSDm",MODE_MAXLOT);
   int    spread1=MarketInfo("GBPUSDm",MODE_SPREAD);
            double    SWAPLONG2=MarketInfo("EURUSDm",MODE_SWAPLONG);
   double    SWAPSHORT2=MarketInfo("EURUSDm",MODE_SWAPSHORT);
   int    MAXLOT2=MarketInfo("EURUSDm",MODE_MAXLOT);
   int    spread2=MarketInfo("EURUSDm",MODE_SPREAD);
            double    SWAPLONG3=MarketInfo("USDJPYm",MODE_SWAPLONG);
   double    SWAPSHORT3=MarketInfo("USDJPYm",MODE_SWAPSHORT);
   int    MAXLOT3=MarketInfo("USDJPYm",MODE_MAXLOT);
   int    spread3=MarketInfo("USDJPYm",MODE_SPREAD);
                     double    SWAPLONG4=MarketInfo("USDCHFm",MODE_SWAPLONG);
   double    SWAPSHORT4=MarketInfo("USDCHFm",MODE_SWAPSHORT);
   int    MAXLOT4=MarketInfo("USDCHFm",MODE_MAXLOT);
   int    spread4=MarketInfo("USDCHFm",MODE_SPREAD);
                     double    SWAPLONG5=MarketInfo("EURCHFm",MODE_SWAPLONG);
   double    SWAPSHORT5=MarketInfo("EURCHFm",MODE_SWAPSHORT);
   int    MAXLOT5=MarketInfo("EURCHFm",MODE_MAXLOT);
   int    spread5=MarketInfo("EURCHFm",MODE_SPREAD);
            double    SWAPLONG6=MarketInfo("AUDUSDm",MODE_SWAPLONG);
   double    SWAPSHORT6=MarketInfo("AUDUSDm",MODE_SWAPSHORT);
   int    MAXLOT6=MarketInfo("AUDUSDm",MODE_MAXLOT);
   int    spread6=MarketInfo("AUDUSDm",MODE_SPREAD);
                     double    SWAPLONG7=MarketInfo("USDCADm",MODE_SWAPLONG);
   double    SWAPSHORT7=MarketInfo("USDCADm",MODE_SWAPSHORT);
   int    MAXLOT7=MarketInfo("USDCADm",MODE_MAXLOT);
   int    spread7=MarketInfo("USDCADm",MODE_SPREAD);
                     double    SWAPLONG8=MarketInfo("NZDUSDm",MODE_SWAPLONG);
   double    SWAPSHORT8=MarketInfo("NZDUSDm",MODE_SWAPSHORT);
   int    MAXLOT8=MarketInfo("NZDUSDm",MODE_MAXLOT);
   int    spread8=MarketInfo("NZDUSDm",MODE_SPREAD);
                     double    SWAPLONG9=MarketInfo("EURGBPm",MODE_SWAPLONG);
   double    SWAPSHORT9=MarketInfo("EURGBPm",MODE_SWAPSHORT);
   int    MAXLOT9=MarketInfo("EURGBPm",MODE_MAXLOT);
   int    spread9=MarketInfo("EURGBPm",MODE_SPREAD);
                     double    SWAPLONG11=MarketInfo("EURJPYm",MODE_SWAPLONG);
   double    SWAPSHORT11=MarketInfo("EURJPYm",MODE_SWAPSHORT);
   int    MAXLOT11=MarketInfo("EURJPYm",MODE_MAXLOT);
   int    spread11=MarketInfo("EURJPYm",MODE_SPREAD);
                     double    SWAPLONG12=MarketInfo("CHFJPYm",MODE_SWAPLONG);
   double    SWAPSHORT12=MarketInfo("CHFJPYm",MODE_SWAPSHORT);
   int    MAXLOT12=MarketInfo("CHFJPYm",MODE_MAXLOT);
   int    spread12=MarketInfo("CHFJPYm",MODE_SPREAD);
                     double    SWAPLONG13=MarketInfo("GBPCHFm",MODE_SWAPLONG);
   double    SWAPSHORT13=MarketInfo("GBPCHFm",MODE_SWAPSHORT);
   int    MAXLOT13=MarketInfo("GBPCHFm",MODE_MAXLOT);
   int    spread13=MarketInfo("GBPCHFm",MODE_SPREAD);
                     double    SWAPLONG14=MarketInfo("EURAUDm",MODE_SWAPLONG);
   double    SWAPSHORT14=MarketInfo("EURAUDm",MODE_SWAPSHORT);
   int    MAXLOT14=MarketInfo("EURAUDm",MODE_MAXLOT);
   int    spread14=MarketInfo("EURAUDm",MODE_SPREAD);
                     double    SWAPLONG15=MarketInfo("EURCADm",MODE_SWAPLONG);
   double    SWAPSHORT15=MarketInfo("EURCADm",MODE_SWAPSHORT);
   int    MAXLOT15=MarketInfo("EURCADm",MODE_MAXLOT);
   int    spread15=MarketInfo("EURCADm",MODE_SPREAD);
                     double    SWAPLONG16=MarketInfo("AUDCADm",MODE_SWAPLONG);
   double    SWAPSHORT16=MarketInfo("AUDCADm",MODE_SWAPSHORT);
   int    MAXLOT16=MarketInfo("AUDCADm",MODE_MAXLOT);
   int    spread16=MarketInfo("AUDCADm",MODE_SPREAD);
                     double    SWAPLONG17=MarketInfo("AUDJPYm",MODE_SWAPLONG);
   double    SWAPSHORT17=MarketInfo("AUDJPYm",MODE_SWAPSHORT);
   int    MAXLOT17=MarketInfo("AUDJPYm",MODE_MAXLOT);
   int    spread17=MarketInfo("AUDJPYm",MODE_SPREAD);
                    double    SWAPLONG18=MarketInfo("NZDJPYm",MODE_SWAPLONG);
   double    SWAPSHORT18=MarketInfo("NZDJPYm",MODE_SWAPSHORT);
   int    MAXLOT18=MarketInfo("NZDJPYm",MODE_MAXLOT);
   int    spread18=MarketInfo("NZDJPYm",MODE_SPREAD);
            double    SWAPLONG19=MarketInfo("AUDNZDm",MODE_SWAPLONG);
   double    SWAPSHORT19=MarketInfo("AUDNZDm",MODE_SWAPSHORT);
   int    MAXLOT19=MarketInfo("AUDNZDm",MODE_MAXLOT);
   int    spread19=MarketInfo("AUDNZDm",MODE_SPREAD);
     if (USE_AUTO_SETTINGS){                               
        if (Symbol()=="GBPJPYm"){       //FGBPJPYm 
MagicBuyStop = 991;
MagicSellStop = 992;
MagicBuyLimit = 993;
MagicSellLimit = 994;


BuyStop_StepActive = spread;//10

BuyLimit_StepActive = spread;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG,2),
"     Swap short= ",DoubleToStr(SWAPSHORT,2),
"\n",
"     spread= ",DoubleToStr(spread,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
      }   
      else if (Symbol()=="GBPUSDm"){                              //FGBPUSDm
MagicBuyStop = 11;
MagicSellStop = 21;
MagicBuyLimit = 31;
MagicSellLimit = 41;


BuyStop_StepActive = spread1;//10

BuyLimit_StepActive = spread1;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG1,2),
"     Swap short= ",DoubleToStr(SWAPSHORT1,2),
"\n",
"     spread= ",DoubleToStr(spread1,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));

               }   
      else if (Symbol()=="EURUSDm"){                    //FEURUSDm               
MagicBuyStop = 21;
MagicSellStop = 22;
MagicBuyLimit = 23;
MagicSellLimit = 24;


BuyStop_StepActive = spread2;//10

BuyLimit_StepActive = spread2;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG2,2),
"     Swap short= ",DoubleToStr(SWAPSHORT2,2),
"\n",
"     spread= ",DoubleToStr(spread2,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                        }   
      else if (Symbol()=="USDJPYm"){                     //FUSDJPYm
MagicBuyStop = 31;
MagicSellStop = 32;
MagicBuyLimit = 33;
MagicSellLimit = 34;


BuyStop_StepActive = spread3;//10

BuyLimit_StepActive = spread3;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG3,2),
"     Swap short= ",DoubleToStr(SWAPSHORT3,2),
"\n",
"     spread= ",DoubleToStr(spread3,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="USDCHFm"){                          //FUSDCHFm
MagicBuyStop = 41;
MagicSellStop = 42;
MagicBuyLimit = 43;
MagicSellLimit = 44;


BuyStop_StepActive = spread4;//10

BuyLimit_StepActive = spread4;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG4,2),
"     Swap short= ",DoubleToStr(SWAPSHORT4,2),
"\n",
"     spread= ",DoubleToStr(spread4,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="EURCHFm"){                              //FEURCHFm
MagicBuyStop = 51;
MagicSellStop = 52;
MagicBuyLimit = 53;
MagicSellLimit = 54; 


BuyStop_StepActive = spread5;//10

BuyLimit_StepActive = spread5;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG5,2),
"     Swap short= ",DoubleToStr(SWAPSHORT5,2),
"\n",
"     spread= ",DoubleToStr(spread5,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="AUDUSDm"){                        //FAUDUSDm
MagicBuyStop = 61;
MagicSellStop = 62;
MagicBuyLimit = 63;
MagicSellLimit = 64;


BuyStop_StepActive = spread6;//10

BuyLimit_StepActive = spread6;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG6,2),
"     Swap short= ",DoubleToStr(SWAPSHORT6,2),
"\n",
"     spread= ",DoubleToStr(spread6,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="USDCADm"){                    //FUSDCADm
MagicBuyStop = 71;
MagicSellStop = 72;
MagicBuyLimit = 73;
MagicSellLimit = 74;


BuyStop_StepActive = spread7;//10

BuyLimit_StepActive = spread7;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG7,2),
"     Swap short= ",DoubleToStr(SWAPSHORT7,2),
"\n",
"     spread= ",DoubleToStr(spread7,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="NZDUSDm"){                  //FNZDUSDm
MagicBuyStop = 81;
MagicSellStop = 82;
MagicBuyLimit = 83;
MagicSellLimit = 84;


BuyStop_StepActive = spread8;//10

BuyLimit_StepActive = spread8;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG8,2),
"     Swap short= ",DoubleToStr(SWAPSHORT8,2),
"\n",
"     spread= ",DoubleToStr(spread8,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="EURGBPm"){                       //FEURGBPm
MagicBuyStop = 91;
MagicSellStop = 92;
MagicBuyLimit = 93;
MagicSellLimit = 94;


BuyStop_StepActive = spread9;//10

BuyLimit_StepActive = spread9;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG9,2),
"     Swap short= ",DoubleToStr(SWAPSHORT9,2),
"\n",
"     spread= ",DoubleToStr(spread9,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="EURJPYm"){                         //FEURJPYm
MagicBuyStop = 111;
MagicSellStop = 112;
MagicBuyLimit = 113;
MagicSellLimit = 114;


BuyStop_StepActive = spread11;//10

BuyLimit_StepActive = spread11;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG11,2),
"     Swap short= ",DoubleToStr(SWAPSHORT11,2),
"\n",
"     spread= ",DoubleToStr(spread11,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="CHFJPYm"){                           //FCHFJPYm
MagicBuyStop = 121;
MagicSellStop = 122;
MagicBuyLimit = 123;
MagicSellLimit = 124;


BuyStop_StepActive = spread12;//10

BuyLimit_StepActive = spread12;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG12,2),
"     Swap short= ",DoubleToStr(SWAPSHORT12,2),
"\n",
"     spread= ",DoubleToStr(spread12,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="GBPCHFm"){                     //FGBPCHFm
MagicBuyStop = 131;
MagicSellStop = 132;
MagicBuyLimit = 133;
MagicSellLimit = 134;


BuyStop_StepActive = spread13;//10

BuyLimit_StepActive = spread13;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG13,2),
"     Swap short= ",DoubleToStr(SWAPSHORT13,2),
"\n",
"     spread= ",DoubleToStr(spread13,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="EURAUDm"){                       //FEURAUDm
MagicBuyStop = 141;
MagicSellStop = 142;
MagicBuyLimit = 143;
MagicSellLimit = 144;


BuyStop_StepActive = spread14;//10

BuyLimit_StepActive = spread14;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG14,2),
"     Swap short= ",DoubleToStr(SWAPSHORT14,2),
"\n",
"     spread= ",DoubleToStr(spread14,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="EURCADm"){                            //FEURCADm
MagicBuyStop = 151;
MagicSellStop = 152;
MagicBuyLimit = 153;
MagicSellLimit = 154;


BuyStop_StepActive = spread15;//10

BuyLimit_StepActive = spread15;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG15,2),
"     Swap short= ",DoubleToStr(SWAPSHORT15,2),
"\n",
"     spread= ",DoubleToStr(spread15,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="AUDCADm"){                        //FAUDCADm
MagicBuyStop = 1151;
MagicSellStop = 1152;
MagicBuyLimit = 1153;
MagicSellLimit = 1154;


BuyStop_StepActive = spread16;//10

BuyLimit_StepActive = spread16;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG16,2),
"     Swap short= ",DoubleToStr(SWAPSHORT16,2),
"\n",
"     spread= ",DoubleToStr(spread16,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="AUDJPYm"){                        //FAUDJPYm
MagicBuyStop = 2151;
MagicSellStop = 2152;
MagicBuyLimit = 2153;
MagicSellLimit = 2154;


BuyStop_StepActive = spread17;//10

BuyLimit_StepActive = spread17;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG17,2),
"     Swap short= ",DoubleToStr(SWAPSHORT17,2),
"\n",
"     spread= ",DoubleToStr(spread17,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="NZDJPYm"){                        //FNZDJPYm
MagicBuyStop = 3151;
MagicSellStop = 3152;
MagicBuyLimit = 3153;
MagicSellLimit = 3154;


BuyStop_StepActive = spread18;//10

BuyLimit_StepActive = spread18;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG18,2),
"     Swap short= ",DoubleToStr(SWAPSHORT18,2),
"\n",
"     spread= ",DoubleToStr(spread18,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="AUDNZDm"){                         //FAUDNZDm
MagicBuyStop = 4151;
MagicSellStop = 4152;
MagicBuyLimit = 4153;
MagicSellLimit = 4154;


BuyStop_StepActive = spread19;//10

BuyLimit_StepActive = spread19;//5

SellStop_StepActive = 0;//10

SellLimit_StepActive = 0;//5



Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG19,2),
"     Swap short= ",DoubleToStr(SWAPSHORT19,2),
"\n",
"     spread= ",DoubleToStr(spread19,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
      }
      else {
MagicBuyStop = 5151;
MagicSellStop = 5152;
MagicBuyLimit = 5153;
MagicSellLimit = 5154;
      }
   }
    if (USE_AUTO_SETTINGS==FALSE&&USE_EXIT_SETTINGS){                               
        if (Symbol()=="GBPJPYm"){       //FGBPJPYm 
AutoClose = FALSE;
MagicBuyStop = 991;
MagicSellStop = 992;
MagicBuyLimit = 993;
MagicSellLimit = 994;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5

Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG,2),
"     Swap short= ",DoubleToStr(SWAPSHORT,2),
"\n",
"     spread= ",DoubleToStr(spread,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
      }   
      else if (Symbol()=="GBPUSDm"){                              //FGBPUSDm
      AutoClose = FALSE;
MagicBuyStop = 11;
MagicSellStop = 21;
MagicBuyLimit = 31;
MagicSellLimit = 41;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread1;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread1;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG1,2),
"     Swap short= ",DoubleToStr(SWAPSHORT1,2),
"\n",
"     spread= ",DoubleToStr(spread1,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));

               }   
      else if (Symbol()=="EURUSDm"){                    //FEURUSDm 
          AutoClose = FALSE;          
MagicBuyStop = 21;
MagicSellStop = 22;
MagicBuyLimit = 23;
MagicSellLimit = 24;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread2;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread2;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG2,2),
"     Swap short= ",DoubleToStr(SWAPSHORT2,2),
"\n",
"     spread= ",DoubleToStr(spread2,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                        }   
      else if (Symbol()=="USDJPYm"){                     //FUSDJPYm
      AutoClose = FALSE;
MagicBuyStop = 31;
MagicSellStop = 32;
MagicBuyLimit = 33;
MagicSellLimit = 34;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread3;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread3;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG3,2),
"     Swap short= ",DoubleToStr(SWAPSHORT3,2),
"\n",
"     spread= ",DoubleToStr(spread3,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="USDCHFm"){                          //FUSDCHFm
      AutoClose = FALSE;
MagicBuyStop = 41;
MagicSellStop = 42;
MagicBuyLimit = 43;
MagicSellLimit = 44;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread4;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread4;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG4,2),
"     Swap short= ",DoubleToStr(SWAPSHORT4,2),
"\n",
"     spread= ",DoubleToStr(spread4,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="EURCHFm"){                              //FEURCHFm
      AutoClose = FALSE;
MagicBuyStop = 51;
MagicSellStop = 52;
MagicBuyLimit = 53;
MagicSellLimit = 54; 
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread5;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread5;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG5,2),
"     Swap short= ",DoubleToStr(SWAPSHORT5,2),
"\n",
"     spread= ",DoubleToStr(spread5,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="AUDUSDm"){                        //FAUDUSDm
      AutoClose = FALSE;
MagicBuyStop = 61;
MagicSellStop = 62;
MagicBuyLimit = 63;
MagicSellLimit = 64;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread6;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread6;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG6,2),
"     Swap short= ",DoubleToStr(SWAPSHORT6,2),
"\n",
"     spread= ",DoubleToStr(spread6,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="USDCADm"){                    //FUSDCADm
      AutoClose = FALSE;
MagicBuyStop = 71;
MagicSellStop = 72;
MagicBuyLimit = 73;
MagicSellLimit = 74;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread7;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread7;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG7,2),
"     Swap short= ",DoubleToStr(SWAPSHORT7,2),
"\n",
"     spread= ",DoubleToStr(spread7,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="NZDUSDm"){                  //FNZDUSDm
      AutoClose = FALSE;
MagicBuyStop = 81;
MagicSellStop = 82;
MagicBuyLimit = 83;
MagicSellLimit = 84;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread8;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread8;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG8,2),
"     Swap short= ",DoubleToStr(SWAPSHORT8,2),
"\n",
"     spread= ",DoubleToStr(spread8,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="EURGBPm"){                       //FEURGBPm
      AutoClose = FALSE;
MagicBuyStop = 91;
MagicSellStop = 92;
MagicBuyLimit = 93;
MagicSellLimit = 94;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread9;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread9;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG9,2),
"     Swap short= ",DoubleToStr(SWAPSHORT9,2),
"\n",
"     spread= ",DoubleToStr(spread9,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="EURJPYm"){                         //FEURJPYm
      AutoClose = FALSE;
MagicBuyStop = 111;
MagicSellStop = 112;
MagicBuyLimit = 113;
MagicSellLimit = 114;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread11;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread11;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG11,2),
"     Swap short= ",DoubleToStr(SWAPSHORT11,2),
"\n",
"     spread= ",DoubleToStr(spread11,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="CHFJPYm"){                           //FCHFJPYm
      AutoClose = FALSE;
MagicBuyStop = 121;
MagicSellStop = 122;
MagicBuyLimit = 123;
MagicSellLimit = 124;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread12;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread12;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG12,2),
"     Swap short= ",DoubleToStr(SWAPSHORT12,2),
"\n",
"     spread= ",DoubleToStr(spread12,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="GBPCHFm"){                     //FGBPCHFm
      AutoClose = FALSE;
MagicBuyStop = 131;
MagicSellStop = 132;
MagicBuyLimit = 133;
MagicSellLimit = 134;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread13;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread13;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG13,2),
"     Swap short= ",DoubleToStr(SWAPSHORT13,2),
"\n",
"     spread= ",DoubleToStr(spread13,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="EURAUDm"){                       //FEURAUDm
      AutoClose = FALSE;
MagicBuyStop = 141;
MagicSellStop = 142;
MagicBuyLimit = 143;
MagicSellLimit = 144;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread14;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread14;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG14,2),
"     Swap short= ",DoubleToStr(SWAPSHORT14,2),
"\n",
"     spread= ",DoubleToStr(spread14,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="EURCADm"){                            //FEURCADm
      AutoClose = FALSE;
MagicBuyStop = 151;
MagicSellStop = 152;
MagicBuyLimit = 153;
MagicSellLimit = 154;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread15;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread15;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG15,2),
"     Swap short= ",DoubleToStr(SWAPSHORT15,2),
"\n",
"     spread= ",DoubleToStr(spread15,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="AUDCADm"){                        //FAUDCADm
      AutoClose = FALSE;
MagicBuyStop = 1151;
MagicSellStop = 1152;
MagicBuyLimit = 1153;
MagicSellLimit = 1154;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread16;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread16;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG16,2),
"     Swap short= ",DoubleToStr(SWAPSHORT16,2),
"\n",
"     spread= ",DoubleToStr(spread16,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="AUDJPYm"){                        //FAUDJPYm
      AutoClose = FALSE;
MagicBuyStop = 2151;
MagicSellStop = 2152;
MagicBuyLimit = 2153;
MagicSellLimit = 2154;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread17;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread17;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG17,2),
"     Swap short= ",DoubleToStr(SWAPSHORT17,2),
"\n",
"     spread= ",DoubleToStr(spread17,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="NZDJPYm"){                        //FNZDJPYm
      AutoClose = FALSE;
MagicBuyStop = 3151;
MagicSellStop = 3152;
MagicBuyLimit = 3153;
MagicSellLimit = 3154;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread18;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 500+spread18;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG18,2),
"     Swap short= ",DoubleToStr(SWAPSHORT18,2),
"\n",
"     spread= ",DoubleToStr(spread18,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
                                 }   
      else if (Symbol()=="AUDNZDm"){                         //FAUDNZDm
      AutoClose = FALSE;
MagicBuyStop = 4151;
MagicSellStop = 4152;
MagicBuyLimit = 4153;
MagicSellLimit = 4154;
BuyStop_TakeProfit = 2000;//50
BuyStop_StopLoss = 500;//30

BuyLimit_TakeProfit = 2000;//50
BuyLimit_StopLoss = 500;//3

SellStop_TakeProfit = 2000;//50
SellStop_StopLoss = 500+spread19;//30

SellLimit_TakeProfit = 2000;//50
SellLimit_StopLoss = 3000+spread19;//30

BuyStop_StepActive = 500;//10
BuyStop_StepPrepare = 500;//50
BuyLimit_StepActive = 500;//5
BuyLimit_StepPrepare = 500;//50
SellStop_StepActive = 500;//10
SellStop_StepPrepare = 300;//50
SellLimit_StepActive = 500;//5
SellLimit_StepPrepare = 500;//5


Comment("\n"," --***--TREND ME LEAVE ME CUSTOM--***--",(""),
"\n","    Take Profit= ",DoubleToStr(BuyStop_TakeProfit,0),
"     Stop Loss= ",DoubleToStr(BuyStop_StopLoss,0),
"\n",
"\n","     profit= ",DoubleToStr(profit,2),
"     Balance= ",DoubleToStr(Balance,2),
"     Equity= ",DoubleToStr(equity,2),
"     FREE MARGIN= ",DoubleToStr(FreeMargin,2),
"\n","     Leverage= ",DoubleToStr(Leverage,0),
"     Max lots Allowed= ",DoubleToStr(MAXLOT,0),
"\n",
"\n","     Swap long= ",DoubleToStr(SWAPLONG19,2),
"     Swap short= ",DoubleToStr(SWAPSHORT19,2),
"\n",
"     spread= ",DoubleToStr(spread19,0),
"\n","     risk= ",DoubleToStr(MaximumRisk,2),
"\n","     Broker time= ",TimeToStr(TimeCurrent()),
"\n","     BuyStop Name= ",(BuyStop_TrendName),
"\n","     BuyLimit Name= ",(BuyLimit_TrendName),
"\n","     SellStop Name= ",(SellStop_TrendName),
"\n","     SellLimit Name= ",(SellLimit_TrendName));
      }
      else {
MagicBuyStop = 5151;
MagicSellStop = 5152;
MagicBuyLimit = 5153;
MagicSellLimit = 5154;
      }
   }
    if( UseHourTrade ){
      if((( FromHourTrade <= ToHourTrade ) && ( Hour() < FromHourTrade || Hour() > ToHourTrade ))
         || // Allow for Overnight Trading
         (( FromHourTrade >  ToHourTrade ) && ( Hour() < FromHourTrade && Hour() > ToHourTrade ))
        ) {
         return(0);
      }

   }

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
           if(OrderSend(Symbol(), OP_BUYSTOP, LotsOptimized(), vA, 3, sl, tp,
              "", MagicBuyStop, 0, CLR_NONE) < 0)
               Print("Err (", GetLastError(), ") Open BuyStop Price= ", vA, " SL= ", 
                     sl," TP= ", tp);

       if(Ask <= vM && Ask >= vP && OrderFind(MagicBuyStop) == true && 
          glbOrderType == OP_BUYSTOP)
          if (EmailAlert==true){SendMail("TMLM Alert", "A TMLM BuyStop Order was place on" +Symbol()+"");}
          
         {
           OrderSelect(glbOrderTicket, SELECT_BY_TICKET, MODE_TRADES);
           if(vA != OrderOpenPrice())
               if(OrderModify(glbOrderTicket, vA, sl, tp, 0, CLR_NONE) == false)
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
           if(OrderSend(Symbol(), OP_BUYLIMIT, LotsOptimized(), vA, 3, sl, tp,
              "", MagicBuyLimit, 0, CLR_NONE) < 0)
               Print("Err (", GetLastError(), ") Open BuyLimit Price= ", vA, " SL= ", 
                     sl," TP= ", tp);

       if(Ask >= vM && Ask <= vP && OrderFind(MagicBuyLimit) == true && 
          glbOrderType == OP_BUYLIMIT)
          if (EmailAlert==true){SendMail("TMLM Alert", "A TMLM BuyLimit Order was place on" +Symbol()+"");}
         {
           OrderSelect(glbOrderTicket, SELECT_BY_TICKET, MODE_TRADES);
           if(vA != OrderOpenPrice())
               if(OrderModify(glbOrderTicket, vA, sl, tp, 0, CLR_NONE) == false)
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
           if(OrderSend(Symbol(), OP_SELLSTOP, LotsOptimized(), vA, 3, sl, tp, "", 
              MagicSellStop, 0, CLR_NONE) < 0)
               Print("Err (", GetLastError(), ") Open SellStop Price= ", vA, " SL= ", sl, 
                     " TP= ", tp);

       if(Bid >= vM && Bid <= vP && OrderFind(MagicSellStop) == true && 
          glbOrderType == OP_SELLSTOP)
          if (EmailAlert==true){SendMail("TMLM Alert", "A TMLM SellStop Order was place on" +Symbol()+"");}
         {
           OrderSelect(glbOrderTicket, SELECT_BY_TICKET, MODE_TRADES);
           if(vA != OrderOpenPrice())
               if(OrderModify(glbOrderTicket, vA, sl, tp, 0, CLR_NONE) == false)
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
           if(OrderSend(Symbol(), OP_SELLLIMIT, LotsOptimized(), vA, 3, sl, tp, "", 
              MagicSellLimit, 0, CLR_NONE) < 0)
               Print("Err (", GetLastError(), ") Open SellLimit Price= ", vA, " SL= ", sl, 
                     " TP= ", tp);

       if(Bid <= vM && Bid >= vP && OrderFind(MagicSellLimit) == true && 
          glbOrderType == OP_SELLLIMIT)
          if (EmailAlert==true){SendMail("TMLM Alert", "A TMLM SellLimit Order was place on" +Symbol()+"");}
         {
           OrderSelect(glbOrderTicket, SELECT_BY_TICKET, MODE_TRADES);
           if(vA != OrderOpenPrice())
               if(OrderModify(glbOrderTicket, vA, sl, tp, 0, CLR_NONE) == false)
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
void SetObject(string name,datetime T1,double P1,datetime T2,double P2,color clr=CLR_NONE)
  {
   if(ObjectFind(name) == -1)
     {
       ObjectCreate(name, OBJ_TREND, 0, T1, P1, T2, P2);
       ObjectSet(name, OBJPROP_COLOR, CLR_NONE);
       ObjectSet(name, OBJPROP_STYLE, STYLE_DOT);
     }
   else
     {
       ObjectSet(name, OBJPROP_TIME1, T1);
       ObjectSet(name, OBJPROP_PRICE1, P1);
       ObjectSet(name, OBJPROP_TIME2, T2);
       ObjectSet(name, OBJPROP_PRICE2, P2);
       ObjectSet(name, OBJPROP_COLOR, CLR_NONE);
       ObjectSet(name, OBJPROP_STYLE, STYLE_DOT);
     } 
  }
//+------------------------------------------------------------------+

