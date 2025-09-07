//+------------------------------------------------------------------+
//|                                                        PZ EA.mq4 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "PZ EA MT5"
#property strict

/*
MQL5 PROJECT

*/
datetime              expiryDate = D'2024.09.04 23:00'; //change as per your requirement




#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <MT4Bridge/MT4MarketInfo.mqh>
#include <MT4Bridge/MT4Account.mqh>
#include <MT4Bridge/MT4Orders.mqh>
#include <mt4objects_1.mqh>
#define HistoryTotal OrdersHistoryTotal
#include <errordescription.mqh>

int indicatorHandle;

//+------------------------------------------------------------------+
//| ENUM
//+------------------------------------------------------------------+
enum enumMode{
   ENUM_MODE1, //MODE 1
   ENUM_MODE2, //MODE 2
   ENUM_MODE3, //MODE 3
   ENUM_MODE4, //MODE 4
   ENUM_MODE5, //MODE 5
   ENUM_MODE6, //MODE 6
   ENUM_MODE7, //MODE 7
   ENUM_MODE8, //MODE 8
   ENUM_MODE9, //MODE 9
};
enum enumSL{
   ENUM_SL1, //SL 1
   ENUM_SL2, //SL 2
   ENUM_SL3, //SL 3
   ENUM_SL4, //SL 4
};
//+------------------------------------------------------------------+
//| INPUTS
//+------------------------------------------------------------------+
input string t0=""; //===== EA =====
input string indicatorPath="Market/PZ Day Trading MT5                            "; //Indicator Path
input double lot=0.01; //Lot
input enumMode mode=ENUM_MODE1; //Mode
input enumSL SL=ENUM_SL4; //Stop Loss
input int maxWrongTP=3; //Max Invalid TP
input bool extraTrade=false; //Extra position open TP
input int TS_start=0; //Trailing Start (0=OFF)
input int TS_step=0; //Trailing Step (0=OFF)
input string t1=""; //===== INDICATOR SETTINGS =====
input int range=15; //Range
input double filter=3; //Filter
input int maxHistoryBar=3000; //Mas History BAr
input string t2=""; //===== DASHBOARD AND STATS =====
input bool dashboard=true; //Dashboard
input bool statistic=true; //Statistic
input bool displaySLTP=true; //Display SL TP
input color bullishColor=clrSkyBlue; //Bullish Color
input color bearishColor=clrLightPink; //Bearish Color
input color positiveLabel=clrBlue; //Positive Label
input color negativeLabel=clrRed; //Negative Label
input color levelFontColor=clrTeal; //Level Font Color
input int levelFontSize=7; //Level Font Size
input string t3=""; //===== PRICE BOXES =====
input bool displayBoxes=true; //Display Boxes
input color bullishBoxes=clrLightBlue; //Bullish Boxes
input color bearishBoxes=clrSalmon; //Bearish Boxes
input bool fillBoxes=true; //Fill Boxes
input int boxedWidth=5; //Boxed Width
input string t4=""; //===== ANALYSIS OPTIONS =====
input bool tradeAnalysis=true; //Trade Analysis
input color mfeColor=clrPurple; //MFE Color
input color mfeLabel=clrBlue; // MFE Label
input color maeColor=clrRed; //MAE Color
input color maeLabel=clrRed; //MAE Label
input int fontSize=7; //Font Siz
input string t5=""; //===== ALERTeS  =====
input string nameForAlert="My Alert"; //Name For Alerts
input bool displayAlert=false; //Display Alerts
input bool sendEmail=false; //Send Email
input bool sendPush=false; //Send Push
input bool soundAlert=false; //Sound Alert
input string soundFile="alert.wav"; //Sound File
//+------------------------------------------------------------------+
//| VARIABLES
//+------------------------------------------------------------------+
int magic=123;
int PreviousCandle=0;
int cont=1;
double tickets[1000];
double slOriginal[1000];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   Print("Demo expires at :"+expiryDate);
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   ChartSetInteger(0,CHART_MODE,CHART_CANDLES);
   ChartSetInteger(0,CHART_SHOW_PERIOD_SEP,true);
   ChartSetInteger(0,CHART_SCALE,2);
   if(mode==ENUM_MODE1) cont=1;
   if(mode==ENUM_MODE2) cont=2;
   if(mode==ENUM_MODE3) cont=3;
   if(mode==ENUM_MODE4) cont=4;
   if(mode==ENUM_MODE5) cont=5;
   if(mode==ENUM_MODE6) cont=6;
   if(mode==ENUM_MODE7) cont=7;
   if(mode==ENUM_MODE8) cont=8;
   if(mode==ENUM_MODE9) cont=9;

      indicatorHandle = iCustom(Symbol(), Period(), indicatorPath,
      "",range,
      filter,
      maxHistoryBar,"",
      //dashboard,
      statistic,
      displaySLTP,
      bullishColor,
      bearishColor,
      positiveLabel,
      negativeLabel,
      levelFontColor,
      levelFontSize,"",
      displayBoxes,
      bullishBoxes,
      bearishBoxes,
      fillBoxes,
      boxedWidth,"",
      tradeAnalysis,
      mfeColor,
      mfeLabel,
      maeColor,
      maeLabel,
      fontSize,"",
      nameForAlert,
      displayAlert,
      sendEmail,
      sendPush,
      soundAlert,
      soundFile);

   if(indicatorHandle == INVALID_HANDLE)
   {
      Print("Failed to create indicator handle");
      return INIT_FAILED;
   }


   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   if(indicatorHandle != INVALID_HANDLE)
      IndicatorRelease(indicatorHandle);
   
   // ... other deinitialization code ...
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
if(TimeCurrent() > expiryDate)
        {
         Alert("Expired demo copy. To renew or purchase, please contact the author");
         Print("Expired demo copy. To renew or purchase, please contact the author");
         ExpertRemove();
         //return -1;
        }
        
        
   if(NewBar()){
      //if(TradesNumber(0)==0){
         Buy();
         Sell();
      //}
   }
   TrailingStop();
   RevisarArray();
}
//+------------------------------------------------------------------+
//| TRADES NUMBER
//+------------------------------------------------------------------+
int TradesNumber(int option){
   int c=0;
   for(int pos=OrdersTotal(); pos>=0; pos--){
      if(OrderSelect(pos,SELECT_BY_POS,MODE_TRADES) && OrderMagicNumber()==magic && OrderSymbol()==Symbol()){
         if((option==0 || option==1) && OrderType()==OP_BUY)  c++;
         if((option==0 || option==2) && OrderType()==OP_SELL) c++;
      } 
   }
   return c;
}
//+------------------------------------------------------------------+
//| TRAILING STOP
//+------------------------------------------------------------------+
void TrailingStop(){
   if(TS_start>0 && TS_step>0)
   for(int pos=OrdersTotal(); pos>=0; pos--){
      if(OrderSelect(pos,SELECT_BY_POS,MODE_TRADES) && OrderMagicNumber()==magic && OrderSymbol()==Symbol()){
         if(OrderType()==OP_BUY && iClose(_Symbol,NULL,0)>OrderOpenPrice()){
            double profit=MathAbs(iClose(_Symbol,NULL,0)-OrderOpenPrice());
            profit=PriceToPip(profit);
            double mult=profit/TS_start;
            double res=TS_step*mult;
            if(SLOriginal(OrderTicket())!=0 && iClose(_Symbol,NULL,0)>=SLOriginal(OrderTicket())+PipToPrice(res) && OrderStopLoss()<NormalizeDouble(SLOriginal(OrderTicket())+PipToPrice(res),Digits())){
               if(OrderModify(OrderTicket(),0,NormalizeDouble(SLOriginal(OrderTicket())+PipToPrice(res),Digits()),OrderTakeProfit(),0)){
                  //...
               }
            }
         }
         if(OrderType()==OP_SELL && iClose(_Symbol,NULL,0)<OrderOpenPrice()){
            double profit=MathAbs(OrderOpenPrice()-iClose(_Symbol,NULL,0));
            profit=PriceToPip(profit);
            double mult=profit/TS_start;
            double res=TS_step*mult;
            if(SLOriginal(OrderTicket())!=0 && iClose(_Symbol,NULL,0)<=SLOriginal(OrderTicket())-PipToPrice(res) && OrderStopLoss()>NormalizeDouble(SLOriginal(OrderTicket())-PipToPrice(res),Digits())){
               if(OrderModify(OrderTicket(),0,NormalizeDouble(SLOriginal(OrderTicket())-PipToPrice(res),Digits()),OrderTakeProfit(),0)){
                  //...
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
//| VALID TP
//+------------------------------------------------------------------+
bool ValidTP(int option){      double  Ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      double  Bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
      double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
   int invalid=0;
   if(option==1){
      for(int i=0; i<cont; i++){
         double tp=SetTP(i,1);
         if(tp<=Ask){
            invalid++;
         }
         if(invalid>=maxWrongTP) return false;
      }
   }
   if(option==2){
      for(int i=0; i<cont; i++){
         double tp=SetTP(i,2);
         if(tp>=Bid){
            invalid++;
         }
         if(invalid>=maxWrongTP) return false;
      }
   }
   return true;
}
//+------------------------------------------------------------------+
//| 
//+------------------------------------------------------------------+
double SLOriginal(int t){
   for(int i=0; i<1000; i++){
      if(tickets[i]==t){
         return slOriginal[i];
      }
   }
   return 0;
}
void AgregarArray(int t, double sl){
   for(int i=0; i<1000; i++){
      if(tickets[i]==0){
         tickets[i]=t;
         slOriginal[i]=sl;
         return;
      }
   }
}
void EliminarArray(int t){
   for(int i=0; i<1000; i++){
      if(tickets[i]==t){
         tickets[i]=0;
         slOriginal[i]=0;
         return;
      }
   }
}
void RevisarArray(){
   for(int pos=OrdersHistoryTotal(); pos>=0; pos--){
      if(OrderSelect(pos,SELECT_BY_POS,MODE_HISTORY) && OrderMagicNumber()==magic && OrderSymbol()==Symbol()){
         if(OrderCloseTime()>0){
            EliminarArray(OrderTicket());
         }
      } 
   }
}
//+------------------------------------------------------------------+
//| BUY
//+------------------------------------------------------------------+
void Buy(){      double  Ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      double  Bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
      double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
   if(PZ()==1){
      double sl=SetSL();
      if(sl<Ask){
         if(ValidTP(1)){
            for(int i=0; i<cont; i++){
               double tp=SetTP(i,1);
               if(tp>Ask){
                  int t=OrderSend(Symbol(),OP_BUY,lot,Ask,0,sl,tp,NULL,magic,0,clrLime);
                  AgregarArray(t,sl);
               }
            }
            if(extraTrade){
               int t=OrderSend(Symbol(),OP_BUY,lot,Ask,0,sl,0,NULL,magic,0,clrLime);
               AgregarArray(t,sl);
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
//| SELL
//+------------------------------------------------------------------+
void Sell(){
   if(PZ()==2){
         double  Ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      double  Bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
      double stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL) * Point();
      
      double sl=SetSL();
      if(sl>Bid){
         if(ValidTP(2)){
            for(int i=0; i<cont; i++){
               double tp=SetTP(i,2);
               if(tp<Bid){
                  int t=OrderSend(Symbol(),OP_SELL,lot,Bid,0,sl,tp,NULL,magic,0,clrRed);
                  AgregarArray(t,sl);
               }
            }
            if(extraTrade){
               int t=OrderSend(Symbol(),OP_SELL,lot,Bid,0,sl,0,NULL,magic,0,clrRed);
               AgregarArray(t,sl);
            }
         }
      }
   } 
}
//+------------------------------------------------------------------+
//| SET SL
//+------------------------------------------------------------------+
double SetSL(){
   string objName="";
   double price=0;
   int time=0;
   string text="";
   if(SL==ENUM_SL1) text=" SL 1";
   if(SL==ENUM_SL2) text=" SL 2";
   if(SL==ENUM_SL3) text=" SL 3";
   if(SL==ENUM_SL4) text=" SL 4";
   for(int x=0; x<ObjectsTotal(0,0,-1); x++){
      string name=ObjectName(x);
      if(ObjectGetString(0,name,OBJPROP_TEXT)==text && ObjectGetInteger(0,name,OBJPROP_TIME)>time){
         time=int(ObjectGetInteger(0,name,OBJPROP_TIME));
         objName=name;
         price=ObjectGetDouble(0,name,OBJPROP_PRICE);
      }
   }
   return price;
}
//+------------------------------------------------------------------+
//| SET TP
//+------------------------------------------------------------------+
double SetTP(int c, int option){
   //FIND RECTANGLE
   string objName="";
   int time=0;
   for(int x=0; x<ObjectsTotal(0,0,-1); x++){
      string name=ObjectName(x);
      if(ObjectGetInteger(0,name,OBJPROP_TYPE)==OBJ_RECTANGLE && StringSubstr(name,0,4)=="PZDT" && ObjectGetInteger(0,name,OBJPROP_TIME,2)>time){
         time=int(ObjectGetInteger(0,name,OBJPROP_TIME,2));
         objName=name;
      }
   }
   
   
 
         
         
         
   //VARIABLES
   double time1=int(MathMin(ObjectGetInteger(0,objName,OBJPROP_TIME,1)
      ,ObjectGetInteger(0,objName,OBJPROP_TIME,2)));
      
   double time2=int(MathMax(ObjectGetInteger(0,objName,OBJPROP_TIME,1)
      ,ObjectGetInteger(0,objName,OBJPROP_TIME,2)));
      
   double high=0;
   double low=0;
   for(int i=0; i<Bars(_Symbol,PERIOD_CURRENT); i++){
      if(iTime(_Symbol,NULL,i)<time2 && iTime(_Symbol,NULL,i)>time1){
         if(high==0 || iClose(_Symbol,NULL,i)>high) high=iClose(_Symbol,NULL,i);
         if(low==0  || iClose(_Symbol,NULL,i)<low)  low=iClose(_Symbol,NULL,i);
      }
      if(iTime(_Symbol,NULL,i)<time2 && iTime(_Symbol,NULL,i)<time1){
         break;
      }
   }
   double box=MathAbs(high-low);
   double price=0;
   if(option==1) price=high;
   if(option==2) price=low;
   //FIND TP
   if(option==1){
      if(c==0) return price+(box*0.618);
      if(c==1) return price+(box*1);
      if(c==2) return price+(box*1.272);
      if(c==3) return price+(box*1.618);
      if(c==4) return price+(box*2);
      if(c==5) return price+(box*2.414);
      if(c==6) return price+(box*2.618);
      if(c==7) return price+(box*3);
      if(c==8) return price+(box*3.236);
   }
   if(option==2){
      if(c==0) return price-(box*0.618);
      if(c==1) return price-(box*1);
      if(c==2) return price-(box*1.272);
      if(c==3) return price-(box*1.618);
      if(c==4) return price-(box*2);
      if(c==5) return price-(box*2.414);
      if(c==6) return price-(box*2.618);
      if(c==7) return price-(box*3);
      if(c==8) return price-(box*3.236);
   }
   return 0;
}
//+------------------------------------------------------------------+
//| NEW BAR
//+------------------------------------------------------------------+
bool NewBar(){
   if(iBars(Symbol(),Period())>PreviousCandle){
      PreviousCandle=iBars(Symbol(),Period());
      return true;
   }
   return false;
}
//+------------------------------------------------------------------+
//| PIP TO PRICE
//+------------------------------------------------------------------+
double PipToPrice(double price){
   return price*Point()*10;
}
//+------------------------------------------------------------------+
//| PRICE TO PIP
//+------------------------------------------------------------------+
double PriceToPip(double price){
   //return price/Point;
   if(Digits()==5) return price*=10000;
   if(Digits()==4) return price*=1000;
   if(Digits()==3) return price*=100;
   if(Digits()==2) return price*=10;
   if(Digits()==1) return price*=1;
   return 0;
}
//+------------------------------------------------------------------+
//| PZ INDICATOR
//+------------------------------------------------------------------+
int PZ(){
   double buy=PZ_Indicator(0,1);
   double sell=PZ_Indicator(1,1);
   if(buy>0 && buy!=EMPTY_VALUE) return 1;
   if(sell>0 && sell!=EMPTY_VALUE) return 2;
   return 0;
}
// Modify the PZ_Indicator function to use the handle
double PZ_Indicator(int buff, int candle)
{
   double value[];
   if(CopyBuffer(indicatorHandle, buff, candle, 1, value) <= 0)
   {
      Print("Failed to copy indicator buffer");
      return EMPTY_VALUE;
   }
   return value[0];
}
 
//+------------------------------------------------------------------+
//| PZ INDICATOR
//+------------------------------------------------------------------+
// double PZ_Indicator(int buff, int candle)
// {
//    return iCustom(Symbol(),Period(),indicatorPath,
//    "",
//    range,
//    filter,
//    maxHistoryBar,
//    "",
//    //dashboard,
//    statistic,
//    displaySLTP,
//    bullishColor,
//    bearishColor,
//    positiveLabel,
//    negativeLabel,
//    levelFontColor,
//    levelFontSize,
//    "",
//    displayBoxes,
//    bullishBoxes,
//    bearishBoxes,
//    fillBoxes,
//    boxedWidth,
//    "",
//    tradeAnalysis,
//    mfeColor,
//    mfeLabel,
//    maeColor,
//    maeLabel,
//    fontSize,
//    "",
//    nameForAlert,
//    displayAlert,
//    sendEmail,
//    sendPush,
//    soundAlert,
//    soundFile,
//    buff,
//    candle);
// }
//+------------------------------------------------------------------+
//| END
//+------------------------------------------------------------------+

// 
//old spec
//
//
//
//
//
//MT4 EA is to be made for an indicator I purchased; "PZ Day Trading Indicator".
//
//The strategy is simple, there is only lots of text because its all explained as clear as possible.
//
//I cannot provide the indicator due to licensing, you can download the demo version
//on the market to check objects etc, and we will have to work in a produce -> test -> feedback cycle.
//
//Please put a lock on your files so it can't be used after some time e.g few days/week. This would be for your own peace of mind and protection in case the project undergoes major restructuring, your work will be locked.
//
//
//
//Here is the signal buffer:
//
////---- Read values from the signal buffer
//int start()
//{
//// Read signal for this bar
//double value = iCustom(Symbol(), Period(), "PZ_DayTrading_LICENSE", 4, 1);
//// Do something
//if(value == OP_BUY) { /* Your code for bullish signal */ }
//if(value == OP_SELL){ /* Your code for bearish signal */ }
//if(value == EMPTY_VALUE) { /* Your code if no signal */}
//// Exit
//return(0);
//}
//
//The specification for the features I want would be as follows:
//
//-> Open trade on arrow signal (up = buy, down = sell obviously :) )
//
//-> EA will have dropdown to select trading mode. There is 9 modes, Mode 1 up to Mode 9. The mode means how many trades the EA will open on signal. So if mode 1, only 1 trade on signal, mode 9 is open 9 trades on signal.
//
//-> EA will have dropdown to select SL. SL will be using the indicator provided levels (SL1, SL2, SL3, SL4)
//
//-> The TPs are set automatically using fib levels using the candle values in the box the indicator draws (not including signal bar)
//   -> This is all explained in this image, but I am including it here because this is also the requirements spec. https://postimg.cc/k2SXkCh8
//   -> These are the fib values to use for tps:
//   1.618, 2, 2.272, 2.618, 3, 3.414, 3.618, 4, 4.236
//   They represent TP1 up to TP9 respectively.
//   -> The fib will be calculated using the CLOSE PRICE of candles in the box the indicator draws, but \\DO NOT INCLUDE SIGNAL BAR//.
//      For buy signal, fib is calculated from highest close, to lowest close
//  For sell signal, fib is calculated from lowest close to highest close
//   -> Each trade the EA opens on signal will have increasingly higher TP level. E.g if EA is trading on mode 5 (signal opens 5 trades), then we use the first 5 tp levels.
//   
//   -> Sometimes the signal bar can be a spike bar, and this can cause some TP levels to be invalidated.
//   To handle this, the EA will not open the trades with invalidated TPs, and just open the rest that are available according to the trading mode.
//   
//   Check image for example pic: https://postimg.cc/06d5yfvy
//   
//   e.g if EA is trading on mode 5 (5 trades on signal), then on signal if 2 TP levels get invalidated, then don't open those 2 trades, but the other 3 are ok, so we can open them.
//   
//   
//-> EA should also have feature to not open trades if too many TP are invalidated. We can call this variable x for example to represent number of max TPs that can be invalidated before the whole trade is cancelled.
//   
//   -> e.g if EA is trading on mode 5 (5 trades on signal), and x is 3, then if 3 or more TPs are invalidated, then don't open any trades for this signal.
//   
//-> Have setting called "Extra position open TP".
//   -> If true, this will just add an extra trade, but this trade will not have a TP set.
//   e.g if EA is trading on mode 5 (5 trades on signal), then open 1 extra trade (6 in total), but this extra trade does not have a set tp.
//   
//-> Have simple trailing stop, explained here
//
//   -> Trailing stop in pips normal (on/off) (after how many pips move SL) (number of pips)
//  This is just normal trailing stop, so after some number of pips, move the SL by some other number of pips. Example: every 20 pips, trail SL by 5 pips.
//
//-> Add indicator settings to EA settings so strategy can be changed as needed
//
//If you have any questions, feel free to ask me, I will do my best to explain.
//
// 