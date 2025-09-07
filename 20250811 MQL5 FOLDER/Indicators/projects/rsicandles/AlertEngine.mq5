//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property version   "1.00"
#property description "Alert Engine for Rsi Candles"
//--
#property indicator_chart_window

bool            RUNMODE_EXPIRY=true;    //Enable expiry
datetime        expiryDate = D'2024.09.09 18:00'; //change as per your requirement




//---
#property indicator_buffers 2
#property indicator_plots   2
//--- plot Arrows
#property indicator_label1  "BuyArrow"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLimeGreen
#property indicator_width1  1
#property indicator_label2  "SellArrow"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrFireBrick
#property indicator_width2  1

enum indicators
  {
// INDICATOR_MA,           //Moving Average
// INDICATOR_MACD,         //Moving Average Convergence/Divergence
// INDICATOR_OSMA,         //Oscillator of Moving Averages
// INDICATOR_STOCHASTIC,   //Stochastic Oscillator
   INDICATOR_RSI,          //Relative Strength Index
// INDICATOR_CCI,          //Commodity Channel Index
// INDICATOR_RVI,          //Relative Vigor Index
// INDICATOR_ADX,          //Average Directional Movement Index
// INDICATOR_TRIX,         //Triple Exponential Average
// INDICATOR_BANDS,        //Bollinger Bands
   INDICATOR_NONE          //No Indicator
  };
//---
indicators Indicator1=INDICATOR_RSI;
ENUM_TIMEFRAMES TimeFrame1=0;

input group "BuyLevels";
input bool enable_buylevel1=true;
input int inp_buylevel1=9 ;
input bool enable_buylevel2=true;
input int inp_buylevel2=14 ;
input bool enable_buylevel3=true;
input int inp_buylevel3=21 ;

input group "SellLevels";
input bool enable_selllevel1=false;
input int inp_selllevel1=60 ;
input bool enable_selllevel2=false;
input int inp_selllevel2=70 ;
input bool enable_selllevel3=false;
input int inp_selllevel3= 80 ;


input int RSIPeriod=20;
int RSISignal=5;

input string _;//---
//---Alerts
input bool  AlertsOn      = true,
            AlertsMessage = true,
            AlertsEmail   = false,
            AlertsSound   = false;
//---
double indicator1_signal_result,
       indicator2;
//---
double Buy[];
double Sell[];
//---
long chartID = ChartID();

int doubleToPip;
double pipToDouble;
int    handle;
int rangeHandle,  indHandle1,  indHandle2;
//---
MqlTick tick;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetString(INDICATOR_SHORTNAME,"AlertEngine");
//--- set points & digits
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   if(_Digits==2 || _Digits==3)
      doubleToPip = 100;
   else
      doubleToPip = 10000;
   if(_Digits==2 || _Digits==4)
      pipToDouble = _Point;
   else
      pipToDouble = _Point*10;





   indHandle1 = INVALID_HANDLE;
   indHandle2 = INVALID_HANDLE;
   if(Indicator1==INDICATOR_NONE)
      Alert("Indicator1 can't be 'No Indicator'");





   switch(Indicator1)
     {
      case INDICATOR_RSI:
         //label3 = StringFormat("RSICANDLES %s (%d,%d)",timeFrame1,RSIPeriod,RSISignal);
         indHandle1 = iCustom(_Symbol, TimeFrame1, "RSICANDLES",RSIPeriod);
         if(indHandle1 == INVALID_HANDLE)
           {
            Print("Failed to create handle of the RSICANDLES indicator");
            return(INIT_FAILED);
           }
         else
           {
            Print("RSICANDLES indicator created successfully");
            // Check if the indicator is already on the chart
            int total = ChartIndicatorsTotal(0, 1); // 0 is the main window, 1 is the first subwindow
            bool indicatorExists = false;
            for(int i=0; i<total; i++)
              {
               string indicatorName = ChartIndicatorName(0, 1, i);
               if(indicatorName == "RSICANDLES")
                 {
                  indicatorExists = true;
                  break;
                 }
              }

            // Add the indicator only if it doesn't exist
            if(!indicatorExists)
              {
               if(!ChartIndicatorAdd(0, 1, indHandle1))
                 {
                  Print("Failed to add RSICANDLES indicator to the chart");
                  return(INIT_FAILED);
                 }
               Print("RSICANDLES indicator added to the chart");
              }
            else
              {
               Print("RSICANDLES indicator already exists on the chart");
              }
           }
         break;
     }




//--- indicator buffers mapping
   SetIndexBuffer(0,Buy,INDICATOR_DATA);
   ArraySetAsSeries(Buy,true);
   PlotIndexSetString(0,PLOT_LABEL,"BuyArrow");
   PlotIndexSetInteger(0,PLOT_ARROW,233);
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0);

   SetIndexBuffer(1,Sell,INDICATOR_DATA);
   ArraySetAsSeries(Sell,true);
   PlotIndexSetString(1,PLOT_LABEL,"SellArrow");
   PlotIndexSetInteger(1,PLOT_ARROW,234);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0);
//---
   return(INIT_SUCCEEDED);
  }
//---
enum ENUM_SIGNAL
  {
   SIGNAL_NONE,
   SIGNAL_BUY,
   SIGNAL_SELL
  };
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(RUNMODE_EXPIRY)
     {
      if(TimeCurrent() > expiryDate)
        {
         Alert("AlertEngine"+":Expired demo copy."+(string)expiryDate+" To renew or purchase, please contact the author");
         Print("AlertEngine"+":Expired demo copy."+(string)expiryDate+" To renew or purchase, please contact the author");
         //return INIT_FAILED;
         int window=ChartWindowFind();
         bool res=ChartIndicatorDelete(0,window,"AlertEngine");

        }
     }


//---
   if(rates_total<100)
      return(0);
//---
   ArraySetAsSeries(time,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
//---
//if(SymbolInfoTick(_Symbol,tick))
//   ObjectSetString(chartID,Label1,OBJPROP_TEXT,label1 +
//                   DoubleToString((tick.ask-tick.bid)*doubleToPip,1));
   static datetime prevTime;
   if(prev_calculated>0 && time[0]!=prevTime)
     {
      prevTime = time[0];
      //ObjectSetString(chartID,Label2,OBJPROP_TEXT,label2 +
      //                StringFormat("(%d) %4.1f",RangePeriod,Range(0)*doubleToPip));
     }
   int i,limit;
//---
   limit = rates_total - prev_calculated;
   if(prev_calculated==0)
     {
      limit = (int)ChartGetInteger(chartID,CHART_VISIBLE_BARS)+100;
      PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,rates_total-limit);
      PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,rates_total-limit);
     }
//---


   static double Rsi[];
   for(i=limit;i>=0 && !IsStopped();i--)
     {
      static datetime Time[1];
      if(CopyTime(_Symbol,TimeFrame1,time[i],1,Time)!=1)
         return(0);
      const datetime time1 = Time[0];



      if(ArraySize(Rsi)!=RSISignal+1)
         ArrayResize(Rsi,RSISignal+1);
      if(CopyBuffer(indHandle1,3,time1,RSISignal+1,Rsi)!=RSISignal+1)
         return(0);
      //indicator1_signal_result = iRSI(Rsi);
      //break;

      ArraySetAsSeries(Rsi,true);

      double currRsi = NormalizeDouble(Rsi[0],Digits());
      double currRsi1 = NormalizeDouble(Rsi[1],Digits());
      double currRsi2 = NormalizeDouble(Rsi[2],Digits());
      double currRsi3 = NormalizeDouble(Rsi[3],Digits());

      //Print("currRsi:",currRsi);
      //Print("currRsi1:",currRsi1);
      //Print("currRsi2:",currRsi2);
      //input int inp_buylevel1=10 ;
      //input int inp_buylevel2=20 ;
      //input int inp_buylevel3=30 ;
      //input int inp_selllevel1=60 ;
      //input int inp_selllevel2=70 ;
      //input int inp_selllevel3= 80 ;

      double buylevel1=NormalizeDouble(inp_buylevel1,Digits());
      
      double buylevel2=NormalizeDouble(inp_buylevel2,Digits());
      double buylevel3=NormalizeDouble(inp_buylevel3,Digits());
      double selllevel1=NormalizeDouble(inp_selllevel1,Digits());
      double selllevel2=NormalizeDouble(inp_selllevel2,Digits());
      double selllevel3=NormalizeDouble(inp_selllevel3,Digits());



      if((enable_buylevel1 && currRsi>buylevel1-0.5&&currRsi<buylevel1+0.5)      
         ||
         (enable_buylevel2 && currRsi>buylevel2-0.5  &&currRsi<buylevel2+0.5)
         ||
         (enable_buylevel3 && currRsi>buylevel3-0.5  &&currRsi<buylevel3+0.5))
        {
         Buy[i] = low[i] - 30*Point();
         if(AlertsOn && prev_calculated>0)
            AlertsHandle(time[0],SIGNAL_BUY);
         Sell[i] = 0;
        }
      else
         if((enable_selllevel3 && currRsi1<selllevel3+0.5&&currRsi1>selllevel3-0.5)
            ||(enable_selllevel2 && currRsi1<selllevel2+0.5&&currRsi1>selllevel2-0.5)
            ||(enable_selllevel1 && currRsi1<selllevel1+0.5&&currRsi1>selllevel1-0.5))
           {
            Sell[i] = high[i] + 30*Point();;
            if(AlertsOn && prev_calculated>0)
               AlertsHandle(time[0],SIGNAL_SELL);
            Buy[i] = 0;
           }
         else
           {
            Buy[i] = 0;
            Sell[i]= 0;
           }
     }

//--- return value of prev_calculated for next call
   return(rates_total);

  }
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---check & delete labels
//Print("exec deinit");
//IndicatorRelease(rangeHandle);

   int window=ChartWindowFind();
   Print("window:",window);

   bool res=ChartIndicatorDelete(0,window,"RSICANDLES");
   Print("res:",res);
//IndicatorRelease(indHandle2);

   IndicatorRelease(indHandle1);
   return;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double iRSI(const double &rsi[])
  {
   ArraySetAsSeries(rsi,true);
// double sum1 = 0.0;
// double sum2 = 0.0;
// for(int i=0,j=1;i<RSISignal;i++,j++) {
//    sum1 += rsi[i];
//    sum2 += rsi[j];
// }
   double currRsi = NormalizeDouble(rsi[0],Digits());
//Print("currRsi:",currRsi);

// double prevRsi = rsi[1];
// double currSig = sum1 / RSISignal;
// double prevSig = sum2 / RSISignal;
//---
//int signal=SIGNAL_NONE;
// if(currRsi>currSig && prevRsi<prevSig)
//signal=SIGNAL_BUY;
// if(currRsi<currSig && prevRsi>prevSig)
//    signal=SIGNAL_SELL;
//---
   return(currRsi);
  }

//+------------------------------------------------------------------+
//|  Alerts Handle                                                   |
//+------------------------------------------------------------------+
void AlertsHandle(const datetime &time,
                  const ENUM_SIGNAL alert_type)
  {
   static datetime timePrev;
   static ENUM_SIGNAL typePrev;
   string alertMessage;
   double price = 0.0;
   if(SymbolInfoTick(_Symbol,tick))
      price = tick.bid;
   if(timePrev!=time || typePrev!=alert_type)
     {
      timePrev = time;
      typePrev = alert_type;
      alertMessage = StringFormat("%s @ %s %s @ %s",_Symbol,TimeToString(TimeLocal(),TIME_MINUTES),
                                  StringSubstr(EnumToString(alert_type),7),DoubleToString(price,_Digits));
      if(AlertsMessage)
         Alert(alertMessage);
      if(AlertsEmail)
         SendMail(_Symbol+" Arrow Alert",alertMessage);
      if(AlertsSound)
         PlaySound("alert2.wav");
     }
  }


//+------------------------------------------------------------------+
