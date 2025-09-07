//+------------------------------------------------------------------+
//|                                                        PZ EA.mq4 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
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
input string indicatorPath="Market/PZ Day Trading"; //Indicator Path
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
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   //...
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
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
         if(OrderType()==OP_BUY && Close[0]>OrderOpenPrice()){
            double profit=MathAbs(Close[0]-OrderOpenPrice());
            profit=PriceToPip(profit);
            double mult=profit/TS_start;
            double res=TS_step*mult;
            if(SLOriginal(OrderTicket())!=0 && Close[0]>=SLOriginal(OrderTicket())+PipToPrice(res) && OrderStopLoss()<NormalizeDouble(SLOriginal(OrderTicket())+PipToPrice(res),Digits())){
               if(OrderModify(OrderTicket(),0,NormalizeDouble(SLOriginal(OrderTicket())+PipToPrice(res),Digits()),OrderTakeProfit(),0)){
                  //...
               }
            }
         }
         if(OrderType()==OP_SELL && Close[0]<OrderOpenPrice()){
            double profit=MathAbs(OrderOpenPrice()-Close[0]);
            profit=PriceToPip(profit);
            double mult=profit/TS_start;
            double res=TS_step*mult;
            if(SLOriginal(OrderTicket())!=0 && Close[0]<=SLOriginal(OrderTicket())-PipToPrice(res) && OrderStopLoss()>NormalizeDouble(SLOriginal(OrderTicket())-PipToPrice(res),Digits())){
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
bool ValidTP(int option){
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
void Buy(){
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
      if(ObjectGetInteger(0,name,OBJPROP_TYPE)==OBJ_RECTANGLE && StringSubstr(name,0,4)=="PZDT" && ObjectGetInteger(0,name,OBJPROP_TIME2)>time){
         time=int(ObjectGetInteger(0,name,OBJPROP_TIME2));
         objName=name;
      }
   }
   //VARIABLES
   double time1=int(MathMin(ObjectGetInteger(0,objName,OBJPROP_TIME1),ObjectGetInteger(0,objName,OBJPROP_TIME2)));
   double time2=int(MathMax(ObjectGetInteger(0,objName,OBJPROP_TIME1),ObjectGetInteger(0,objName,OBJPROP_TIME2)));
   double high=0;
   double low=0;
   for(int i=0; i<Bars; i++){
      if(Time[i]<time2 && Time[i]>time1){
         if(high==0 || Close[i]>high) high=Close[i];
         if(low==0  || Close[i]<low)  low=Close[i];
      }
      if(Time[i]<time2 && Time[i]<time1){
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
   return price*Point*10;
}
//+------------------------------------------------------------------+
//| PRICE TO PIP
//+------------------------------------------------------------------+
double PriceToPip(double price){
   //return price/Point;
   if(Digits==5) return price*=10000;
   if(Digits==4) return price*=1000;
   if(Digits==3) return price*=100;
   if(Digits==2) return price*=10;
   if(Digits==1) return price*=1;
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
//+------------------------------------------------------------------+
//| PZ INDICATOR
//+------------------------------------------------------------------+
double PZ_Indicator(int buff, int candle){
   return iCustom(Symbol(),Period(),indicatorPath,
   "",
   range,
   filter,
   maxHistoryBar,
   "",
   dashboard,
   statistic,
   displaySLTP,
   bullishColor,
   bearishColor,
   positiveLabel,
   negativeLabel,
   levelFontColor,
   levelFontSize,
   "",
   displayBoxes,
   bullishBoxes,
   bearishBoxes,
   fillBoxes,
   boxedWidth,
   "",
   tradeAnalysis,
   mfeColor,
   mfeLabel,
   maeColor,
   maeLabel,
   fontSize,
   "",
   nameForAlert,
   displayAlert,
   sendEmail,
   sendPush,
   soundAlert,
   soundFile,
   buff,candle);
}
//+------------------------------------------------------------------+
//| END
//+------------------------------------------------------------------+