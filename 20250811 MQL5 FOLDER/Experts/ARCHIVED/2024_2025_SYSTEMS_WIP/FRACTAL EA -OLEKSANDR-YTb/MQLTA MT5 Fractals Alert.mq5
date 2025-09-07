#property link          "https://www.earnforex.com/metatrader-indicators/fractals-alert/"
#property version       "1.01"
#property strict
#property copyright     "EarnForex.com - 2019-2021"
#property description   "The Fractals Alert"
#property description   " "
#property description   "WARNING : You use this software at your own risk."
#property description   "The creator of these plugins cannot be held responsible for damage or loss."
#property description   " "
#property description   "Find More on EarnForex.com"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots 0
#property indicator_label1  "FractalUp" 
#property indicator_type1   DRAW_ARROW 
#property indicator_color1  clrBlue 
#property indicator_label2  "FractalDown" 
#property indicator_type2   DRAW_ARROW 
#property indicator_color2  clrRed 

#include <MQLTA ErrorHandling.mqh>
#include <MQLTA Utils.mqh>

enum ENUM_TRADE_SIGNAL{
   SIGNAL_BUY=1,     //BUY
   SIGNAL_SELL=-1,   //SELL
   SIGNAL_NEUTRAL=0  //NEUTRAL
};

enum ENUM_CANDLE_TO_CHECK{
   CURRENT_CANDLE=0,    //CURRENT CANDLE
   CLOSED_CANDLE=1      //PREVIOUS CANDLE
};

enum ENUM_ALERT_SIGNAL{

};

input string Comment1="========================";     //MQLTA Fractals Alert
input string IndicatorName="MQLTA-FRAL";              //Indicator Short Name

input string Comment2="========================";     //Indicator Parameters
//input ENUM_APPLIED_PRICE MASlowAppliedPrice=PRICE_CLOSE;  //Slow Moving Average Applied Price
//input ENUM_ALERT_SIGNAL AlertSignal=ON_BREAK_OUT;       //Alert Signal When
input ENUM_CANDLE_TO_CHECK CandleToCheck=CURRENT_CANDLE;    //Candle To Use For Analysis
input int BarsToScan=500;                                   //Number Of Candles To Analyse

input string Comment_3="====================";     //Notification Options
input bool EnableNotify=false;                    //Enable Notifications Feature
input bool SendAlert=true;                        //Send Alert Notification
input bool SendApp=true;                          //Send Notification to Mobile
input bool SendEmail=true;                        //Send Notification via Email
input int WaitTimeNotify=5;                        //Wait time between notifications (Minutes)

input string Comment_4="====================";     //Drawing Options
input bool EnableDrawArrows=true;                  //Draw Signal Arrows
input int ArrowBuy=241;                            //Buy Arrow Code
input int ArrowSell=242;                           //Sell Arrow Code
input int ArrowSize=3;                             //Arrow Size (1-5)

double BufferFractalsUp[],BufferFractalsDown[];

double Open[],Close[],High[],Low[];
datetime Time[];

datetime LastNotificationTime;
int Shift;

int BufferFractalsHandle;

int OnInit(void){

   IndicatorSetString(INDICATOR_SHORTNAME,IndicatorName);

   OnInitInitialization();
   if(!OnInitPreChecksPass()){
      return(INIT_FAILED);
   }   

   InitialiseHandles();
   InitialiseBuffers();

   return(INIT_SUCCEEDED);
}


int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]){

   bool IsNewCandle=CheckIfNewCandle();
   int i,pos,upTo;

   pos=0;
   if(prev_calculated==0 || IsNewCandle)
      upTo=BarsToScan-1;
   else
      upTo=0;

   if(IsStopped()) return(0);
   if(CopyBuffer(BufferFractalsHandle,0,0,upTo+1,BufferFractalsUp)<=0 ||
      CopyBuffer(BufferFractalsHandle,1,0,upTo+1,BufferFractalsDown)<=0
   ){
      Print("Failed to create the Indicator! Error ",GetLastErrorText(GetLastError())," - ",GetLastError());
      return(0);
   }

   for(i=pos; i<=upTo && !IsStopped(); i++){
      Open[i]=iOpen(Symbol(),PERIOD_CURRENT,i);
      Low[i]=iLow(Symbol(),PERIOD_CURRENT,i);
      High[i]=iHigh(Symbol(),PERIOD_CURRENT,i);
      Close[i]=iClose(Symbol(),PERIOD_CURRENT,i);
      Time[i]=iTime(Symbol(),PERIOD_CURRENT,i);
   }

   if(IsNewCandle || prev_calculated==0){
      if(EnableDrawArrows) DrawArrows();
   }
   
   if(EnableDrawArrows)
      DrawArrow(0);

   if(EnableNotify)
      NotifyHit();
      
   return(rates_total);
}
  
  
void OnDeinit(const int reason){
   CleanChart();
}  


void OnInitInitialization(){
   LastNotificationTime=TimeCurrent();
   Shift=CandleToCheck;

}


bool OnInitPreChecksPass(){

   return true;
}


void CleanChart(){
   int Window=0;
   for(int i=ObjectsTotal(ChartID(),Window,-1)-1;i>=0;i--){
      if(StringFind(ObjectName(0,i),IndicatorName,0)>=0){
         ObjectDelete(0,ObjectName(0,i));
      }
   }
}


void InitialiseHandles(){
   BufferFractalsHandle=iFractals(Symbol(),PERIOD_CURRENT);
   ArrayResize(Open,BarsToScan);
   ArrayResize(High,BarsToScan);
   ArrayResize(Low,BarsToScan);
   ArrayResize(Close,BarsToScan);
   ArrayResize(Time,BarsToScan);
}


void InitialiseBuffers(){
   ArraySetAsSeries(BufferFractalsUp,true);
   ArraySetAsSeries(BufferFractalsDown,true);
   SetIndexBuffer(0,BufferFractalsUp,INDICATOR_DATA);
   SetIndexBuffer(1,BufferFractalsDown,INDICATOR_DATA);
   PlotIndexSetInteger(0,PLOT_ARROW,217);
   PlotIndexSetInteger(1,PLOT_ARROW,218);
}


datetime NewCandleTime=TimeCurrent();
bool CheckIfNewCandle(){
   if(NewCandleTime==iTime(Symbol(),0,0)) return false;
   else{
      NewCandleTime=iTime(Symbol(),0,0);
      return true;
   }
}


//Check if it is a trade Signla 0 - Neutral, 1 - Buy, -1 - Sell
ENUM_TRADE_SIGNAL IsSignal(int i){
   int j=i+Shift+2;
   bool FractalsUp=false;
   bool FractalsDown=false;   
   double fu=BufferFractalsUp[j];
   double fl=BufferFractalsDown[j];
   if(fu!=EMPTY_VALUE){
      FractalsUp=true;
      FractalsDown=false;
   }
   if(fl!=EMPTY_VALUE){
      FractalsUp=false;
      FractalsDown=true;
   } 
   if(fu!=EMPTY_VALUE && fl!=EMPTY_VALUE){
      FractalsUp=false;
      FractalsDown=false;
   }
   if(FractalsDown) return SIGNAL_BUY;
   if(FractalsUp) return SIGNAL_SELL;

   return SIGNAL_NEUTRAL;
}


datetime LastNotification=TimeCurrent()-WaitTimeNotify*60;

void NotifyHit(){
   if(!EnableNotify || TimeCurrent()<(LastNotification+WaitTimeNotify*60)) return;
   if(!SendAlert && !SendApp && !SendEmail) return;
   if(Time[0]==LastNotificationTime) return;
//===
   ENUM_TRADE_SIGNAL Signal=IsSignal(0);
//===
   if(Signal==SIGNAL_NEUTRAL) return;
//===   
   string EmailSubject=IndicatorName+" "+Symbol()+" Notification ";
   string EmailBody="\r\n"+AccountCompany()+" - "+AccountName()+" - "+IntegerToString(AccountNumber())+"\r\n\r\n"+IndicatorName+" Notification for "+Symbol()+"\r\n\r\n";
   string AlertText=IndicatorName+" - "+Symbol()+" Notification\r\n";
   string AppText=AccountCompany()+" - "+AccountName()+" - "+IntegerToString(AccountNumber())+" - "+IndicatorName+" - "+Symbol()+" - ";
   string Text="";
//===   
   if(Signal!=SIGNAL_NEUTRAL){      
      Text+="Fractals Formed";
   }
//===   
   EmailBody+=Text+"\r\n\r\n";
   AlertText+=Text+"\r\n";
   AppText+=Text+"";
//===   
   if(SendAlert) Alert(AlertText);
   if(SendEmail){
      if(!SendMail(EmailSubject,EmailBody)) Print("Error sending email "+IntegerToString(GetLastError()));
   }
   if(SendApp){
      if(!SendNotification(AppText)) Print("Error sending notification "+IntegerToString(GetLastError()));
   }
   LastNotification=TimeCurrent();
   Print(IndicatorName+"-"+Symbol()+" last notification sent "+TimeToString(LastNotification));
}


void DrawArrows(){
   RemoveArrows();
   if(!EnableDrawArrows || BarsToScan==0) return;
   int MaxBars=Bars(Symbol(),PERIOD_CURRENT);
   if(MaxBars>BarsToScan) MaxBars=BarsToScan;
   for(int i=MaxBars-2;i>=1;i--){
      DrawArrow(i);
   }
}


void RemoveArrows(){
   int Window=-1;
   for(int i=ObjectsTotal(ChartID(),Window,-1)-1;i>=0;i--){
      if(StringFind(ObjectName(0,i),IndicatorName+"-ARWS-",0)>=0){
         ObjectDelete(0,ObjectName(0,i));
      }
   }
}

int SignalWidth=0;

void DrawArrow(int i){
   RemoveArrowCurr();
   if(!EnableDrawArrows){
      RemoveArrows();
      return;
   }
   ENUM_TRADE_SIGNAL Signal=IsSignal(i);
   if(Signal==SIGNAL_NEUTRAL) return;


   //======
   datetime ArrowDate=iTime(Symbol(),0,i);
   string ArrowName=IndicatorName+"-ARWS-"+IntegerToString(ArrowDate);
   double ArrowPrice=0;
   ENUM_OBJECT ArrowType=OBJ_ARROW;
   color ArrowColor=0;
   int ArrowAnchor=0;
   string ArrowDesc="";
   if(Signal==SIGNAL_BUY){
      ArrowPrice=Low[i];
      ArrowType=(ENUM_OBJECT)ArrowBuy; 
      ArrowColor=clrGreen;  
      ArrowAnchor=ANCHOR_TOP;
      ArrowDesc="BUY";
   }
   if(Signal==SIGNAL_SELL){
      ArrowPrice=High[i];
      ArrowType=(ENUM_OBJECT)ArrowSell;
      ArrowColor=clrRed;
      ArrowAnchor=ANCHOR_BOTTOM;
      ArrowDesc="SELL";
   }
   ObjectCreate(0,ArrowName,OBJ_ARROW,0,ArrowDate,ArrowPrice);
   ObjectSetInteger(0,ArrowName,OBJPROP_COLOR,ArrowColor);
   ObjectSetInteger(0,ArrowName,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,ArrowName,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,ArrowName,OBJPROP_ANCHOR,ArrowAnchor);
   ObjectSetInteger(0,ArrowName,OBJPROP_ARROWCODE,ArrowType);
   SignalWidth=ArrowSize;
   ObjectSetInteger(0,ArrowName,OBJPROP_WIDTH,SignalWidth);
   ObjectSetInteger(0,ArrowName,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,ArrowName,OBJPROP_BGCOLOR,ArrowColor);
   ObjectSetString(0,ArrowName,OBJPROP_TEXT,ArrowDesc);
   datetime CurrTime=iTime(Symbol(),0,0);

}


void RemoveArrowCurr(){
   datetime ArrowDate=iTime(Symbol(),0,Shift);
   string ArrowName=IndicatorName+"-ARWS-"+IntegerToString(ArrowDate);
   ObjectDelete(0,ArrowName);
}

