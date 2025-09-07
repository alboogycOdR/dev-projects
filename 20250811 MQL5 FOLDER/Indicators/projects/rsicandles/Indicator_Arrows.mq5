//+------------------------------------------------------------------+
//|                                             Indicator Arrows.mq5 |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Indicator Arrows by pipPod"
//--
#property indicator_chart_window
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
//---
enum indicators
  {
   INDICATOR_MA,           //Moving Average
   INDICATOR_MACD,         //Moving Average Convergence/Divergence
   INDICATOR_OSMA,         //Oscillator of Moving Averages
   INDICATOR_STOCHASTIC,   //Stochastic Oscillator
   INDICATOR_RSI,          //Relative Strength Index
   INDICATOR_CCI,          //Commodity Channel Index
   INDICATOR_RVI,          //Relative Vigor Index
   INDICATOR_ADX,          //Average Directional Movement Index
   INDICATOR_TRIX,         //Triple Exponential Average
   INDICATOR_BANDS,        //Bollinger Bands
   INDICATOR_NONE          //No Indicator
  };
//---
input indicators Indicator1=INDICATOR_MACD;
input ENUM_TIMEFRAMES TimeFrame1=0;
input indicators Indicator2=INDICATOR_MA;
input ENUM_TIMEFRAMES TimeFrame2=0;
//---Range
input string Range;
input int RangePeriod=14;
//---Moving Average
input string MovingAverage;
input int MAPeriod=5;
input ENUM_MA_METHOD MAMethod=MODE_EMA;
input ENUM_APPLIED_PRICE MAPrice=PRICE_CLOSE;
//---MACD
input string MACD;
input int FastMACD=12;
input int SlowMACD=26;
input int SignalMACD=9;
input ENUM_APPLIED_PRICE MACDPrice=PRICE_CLOSE;
//---OsMA
input string OsMA;
input int FastOsMA=12;
input int SlowOsMA=26;
input int SignalOsMA=9;
input ENUM_APPLIED_PRICE OsMAPrice=PRICE_CLOSE;
input int OsMASignal=9;
//---Stoch
input string Stochastic;
input int Kperiod=8;
input int Dperiod=3;
input int Slowing=3;
input ENUM_MA_METHOD StochMAMethod=MODE_SMA;
input ENUM_STO_PRICE PriceField=STO_LOWHIGH;
//---RSI
input string RSI;
input int RSIPeriod=8;
input int RSISignal=5;
input ENUM_APPLIED_PRICE RSIPrice=PRICE_CLOSE;
//---CCI
input string CCI;
input int CCIPeriod=14;
input ENUM_APPLIED_PRICE CCIPrice=PRICE_CLOSE;
//---RVI
input string RVI;
input int RVIPeriod=10;
//---ADX
input string ADX;
input int ADXPeriod=14;
input ENUM_APPLIED_PRICE ADXPrice=PRICE_CLOSE;
//---TriX
input string TriX;
input int TriXPeriod=14;
input int TrixSignal=9;
input ENUM_APPLIED_PRICE TriXPrice=PRICE_CLOSE;
//---Bands
input string Bands;
input int BBPeriod=20;  //Bands Period
input double BBDev=2.0; //Bands Deviation
input ENUM_APPLIED_PRICE BBPrice=PRICE_CLOSE;   //Bands Price
input string _;//---
//---Alerts
input bool  AlertsOn      = true,
            AlertsMessage = true,
            AlertsEmail   = false,
            AlertsSound   = false;
//---
int indicator1,
    indicator2;
//---
double Buy[];
double Sell[];
//---
long chartID = ChartID();
#define LabelBox "LabelBox"
#define Label1 "Label1"
#define Label2 "Label2"
#define Label3 "Label3"
#define Label4 "Label4"
string label1 = "Spread ",
       label2 = "Range";
//---
int doubleToPip;
double pipToDouble;
//---
int rangeHandle,
    indHandle1,
    indHandle2;
//---
MqlTick tick;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetString(INDICATOR_SHORTNAME,"Indicator Arrows");
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
//---create label rectangle and labels
   string label3,
          label4;
   int xStart=7;
   int yStart=80;
   int yIncrement=14;
   int ySize=40;
   int ySizeInc=15;
   ObjectCreate(chartID,LabelBox,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(chartID,LabelBox,OBJPROP_XDISTANCE,3);
   ObjectSetInteger(chartID,LabelBox,OBJPROP_YDISTANCE,75);
   ObjectSetInteger(chartID,LabelBox,OBJPROP_XSIZE,135);
   ObjectSetInteger(chartID,LabelBox,OBJPROP_YSIZE,ySize);
   ObjectSetInteger(chartID,LabelBox,OBJPROP_BGCOLOR,clrBlack);
   ObjectSetInteger(chartID,LabelBox,OBJPROP_BORDER_TYPE,BORDER_FLAT);

   ObjectCreate(chartID,Label1,OBJ_LABEL,0,0,0);
   ObjectSetInteger(chartID,Label1,OBJPROP_XDISTANCE,xStart);
   ObjectSetInteger(chartID,Label1,OBJPROP_YDISTANCE,yStart);
   ObjectSetString(chartID,Label1,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(chartID,Label1,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(chartID,Label1,OBJPROP_COLOR,clrFireBrick);
   
   ObjectCreate(chartID,Label2,OBJ_LABEL,0,0,0);
   ObjectSetInteger(chartID,Label2,OBJPROP_XDISTANCE,xStart);
   ObjectSetInteger(chartID,Label2,OBJPROP_YDISTANCE,yStart+=yIncrement);
   ObjectSetString(chartID,Label2,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(chartID,Label2,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(chartID,Label2,OBJPROP_COLOR,clrYellow);
//---
   string timeFrame1 = StringSubstr(EnumToString(TimeFrame1),7)+" ";
   string timeFrame2 = StringSubstr(EnumToString(TimeFrame2),7)+" ";
   if(timeFrame1=="CURRENT ")
      timeFrame1 = "";
   if(timeFrame2=="CURRENT ")
      timeFrame2 = "";
//---
   rangeHandle = iATR(NULL,0,RangePeriod);
   if(rangeHandle==INVALID_HANDLE)
      return(INIT_FAILED);
   indHandle1 = INVALID_HANDLE;
   indHandle2 = INVALID_HANDLE;
   if(Indicator1==INDICATOR_NONE)
      Alert("Indicator1 can't be 'No Indicator'");
   switch(Indicator1)
     {
      case INDICATOR_MA:
         label3 = StringFormat("iMA %s %s (%d)",timeFrame1,
                  StringSubstr(EnumToString(MAMethod),5),MAPeriod);
         indHandle1 = iMA(_Symbol,TimeFrame1,MAPeriod,0,MAMethod,MAPrice);
         break;
      case INDICATOR_MACD:
         label3 = StringFormat("iMACD %s (%d,%d,%d)",timeFrame1,
                  FastMACD,SlowMACD,SignalMACD);
         indHandle1 = iMACD(_Symbol,TimeFrame1,FastMACD,SlowMACD,SignalMACD,MACDPrice);
         break;
      case INDICATOR_OSMA:
         label3 = StringFormat("iOsMA %s (%d,%d,%d)",timeFrame1,
                  FastOsMA,SlowOsMA,SignalOsMA);
         indHandle1 = iOsMA(_Symbol,TimeFrame1,FastOsMA,SlowOsMA,SignalOsMA,OsMAPrice);
         break;
      case INDICATOR_STOCHASTIC:
         label3 = StringFormat("iStoch %s (%d,%d,%d) %s",timeFrame1,
                  Kperiod,Dperiod,Slowing,
                  StringSubstr(EnumToString(StochMAMethod),5));
         indHandle1 = iStochastic(_Symbol,TimeFrame1,Kperiod,Dperiod,Slowing,StochMAMethod,PriceField);
         break;
      case INDICATOR_RSI:
         label3 = StringFormat("iRSI %s (%d,%d)",timeFrame1,
                  RSIPeriod,RSISignal);
         indHandle1 = iRSI(_Symbol,TimeFrame1,RSIPeriod,RSIPrice);
         break;
      case INDICATOR_CCI:
         label3 = StringFormat("iCCI %s (%d)",timeFrame1,
                  CCIPeriod);
         indHandle1 = iCCI(_Symbol,TimeFrame1,CCIPeriod,CCIPrice);
         break;
      case INDICATOR_RVI:
         label3 = StringFormat("iRVI %s (%d)",timeFrame1,
                  RVIPeriod);
         indHandle1 = iRVI(_Symbol,TimeFrame1,RVIPeriod);
         break;
      case INDICATOR_ADX:
         label3 = StringFormat("iADX %s (%d)",timeFrame1,
                  ADXPeriod);
         indHandle1 = iADX(_Symbol,TimeFrame1,ADXPeriod);
         break;
      case INDICATOR_TRIX:
         label3 = StringFormat("iTriX %s (%d)",timeFrame1,
                  TriXPeriod);
         indHandle1 = iTriX(_Symbol,TimeFrame1,TriXPeriod,TriXPrice);
         break;
      case INDICATOR_BANDS:
         label3 = StringFormat("iBands %s (%d,%2.1f)",timeFrame1,
                  BBPeriod,BBDev);
         indHandle1 = iBands(_Symbol,TimeFrame1,BBPeriod,0,BBDev,BBPrice);
     }
   if(indHandle1==INVALID_HANDLE)
      return(INIT_FAILED);
   ObjectSetInteger(chartID,LabelBox,OBJPROP_YSIZE,ySize+=ySizeInc);
   ObjectCreate(chartID,Label3, OBJ_LABEL,0,0,0);
   ObjectSetInteger(chartID,Label3,OBJPROP_CORNER,0);
   ObjectSetInteger(chartID,Label3,OBJPROP_XDISTANCE,xStart);
   ObjectSetInteger(chartID,Label3,OBJPROP_YDISTANCE,yStart+=yIncrement);
   ObjectSetString(chartID,Label3,OBJPROP_TEXT,label3);
   ObjectSetString(chartID,Label3,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(chartID,Label3,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(chartID,Label3,OBJPROP_COLOR,clrLimeGreen);
//---
   if(Indicator2!=INDICATOR_NONE)
     {
      switch(Indicator2)
        {
         case INDICATOR_MA:
            label4 = StringFormat("iMA %s %s (%d)",timeFrame2,
                     StringSubstr(EnumToString(MAMethod),5),MAPeriod);
            indHandle2 = iMA(_Symbol,TimeFrame2,MAPeriod,0,MAMethod,MAPrice);
            break;
         case INDICATOR_MACD:
            label4 = StringFormat("iMACD %s (%d,%d,%d)",timeFrame2,
                     FastMACD,SlowMACD,SignalMACD);
            indHandle2 = iMACD(_Symbol,TimeFrame2,FastMACD,SlowMACD,SignalMACD,MACDPrice);
            break;
         case INDICATOR_OSMA:
            label4 = StringFormat("iOsMA %s (%d,%d,%d)",timeFrame2,
                     FastOsMA,SlowOsMA,SignalOsMA);
            indHandle2 = iOsMA(_Symbol,TimeFrame2,FastOsMA,SlowOsMA,SignalOsMA,OsMAPrice);
            break;
         case INDICATOR_STOCHASTIC:
            label4 = StringFormat("iStoch %s (%d,%d,%d) %s",timeFrame2,
                     Kperiod,Dperiod,Slowing,
                     StringSubstr(EnumToString(StochMAMethod),5));
            indHandle2 = iStochastic(_Symbol,TimeFrame2,Kperiod,Dperiod,Slowing,StochMAMethod,PriceField);
            break;
         case INDICATOR_RSI:
            label4 = StringFormat("iRSI %s (%d,%d)",timeFrame2,
                     RSIPeriod,RSISignal);
            indHandle2 = iRSI(_Symbol,TimeFrame2,RSIPeriod,RSIPrice);
            break;
         case INDICATOR_CCI:
            label4 = StringFormat("iCCI %s (%d)",timeFrame2,
                     CCIPeriod);
            indHandle2 = iCCI(_Symbol,TimeFrame2,CCIPeriod,CCIPrice);
            break;
         case INDICATOR_RVI:
            label4 = StringFormat("iRVI %s (%d)",timeFrame2,
                     RVIPeriod);
            indHandle2 = iRVI(_Symbol,TimeFrame2,RVIPeriod);
            break;
         case INDICATOR_ADX:
            label4 = StringFormat("iADX %s (%d)",timeFrame2,
                     ADXPeriod);
            indHandle2 = iADX(_Symbol,TimeFrame2,ADXPeriod);
            break;
         case INDICATOR_TRIX:
            label4 = StringFormat("iTriX %s (%d)",timeFrame2,
                     TriXPeriod);
            indHandle2 = iTriX(_Symbol,TimeFrame2,TriXPeriod,TriXPrice);
            break;
         case INDICATOR_BANDS:
            label4 = StringFormat("iBands %s (%d,%2.1f)",timeFrame2,
                     BBPeriod,BBDev);
            indHandle2 = iBands(_Symbol,TimeFrame2,BBPeriod,0,BBDev,BBPrice);
        }      
      if(indHandle2==INVALID_HANDLE)
         return(INIT_FAILED);
      ObjectSetInteger(chartID,LabelBox,OBJPROP_YSIZE,ySize+=ySizeInc);
      ObjectCreate(chartID,Label4,OBJ_LABEL,0,0,0);
      ObjectSetInteger(chartID,Label4,OBJPROP_CORNER, 0);
      ObjectSetInteger(chartID,Label4,OBJPROP_XDISTANCE,xStart);
      ObjectSetInteger(chartID,Label4,OBJPROP_YDISTANCE,yStart+=yIncrement);
      ObjectSetString(chartID,Label4,OBJPROP_TEXT,label4);
      ObjectSetString(chartID,Label4,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(chartID,Label4,OBJPROP_FONTSIZE,10);
      ObjectSetInteger(chartID,Label4,OBJPROP_COLOR,clrLimeGreen);
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
//---
   if(rates_total<100)  
      return(0);
//---
   ArraySetAsSeries(time,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
//---
   if(SymbolInfoTick(_Symbol,tick))
      ObjectSetString(chartID,Label1,OBJPROP_TEXT,label1 + 
                      DoubleToString((tick.ask-tick.bid)*doubleToPip,1));
   static datetime prevTime;
   if(prev_calculated>0 && time[0]!=prevTime)
     {
      prevTime = time[0];
      ObjectSetString(chartID,Label2,OBJPROP_TEXT,label2 + 
                      StringFormat("(%d) %4.1f",RangePeriod,Range(0)*doubleToPip));
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
   for(i=limit;i>=0 && !IsStopped();i--)
     {
      static datetime Time[1];
      if(CopyTime(_Symbol,TimeFrame1,time[i],1,Time)!=1)
         return(0);
      const datetime time1 = Time[0];
      switch(Indicator1)
        {
         case INDICATOR_MA:
           { 
            static double MoAv[1];
            static double High[1];
            static double Low[1];
            static double Close[1];
            if(CopyBuffer(indHandle1,0,time1,1,MoAv)!=1)
               return(0);
            if(CopyHigh(_Symbol,TimeFrame1,time1,1,High)!=1)
               return(0);
            if(CopyLow(_Symbol,TimeFrame1,time1,1,Low)!=1)
               return(0);
            if(CopyClose(_Symbol,TimeFrame1,time1,1,Close)!=1)
               return(0);
            indicator1 = iMA(MoAv,High,Low,Close);
            break;
           }
         case INDICATOR_MACD:
           { 
            static double Macd[2];
            static double Sign[2];
            if(CopyBuffer(indHandle1,0,time1,2,Macd)!=2)
               return(0);
            if(CopyBuffer(indHandle1,1,time1,2,Sign)!=2)
               return(0);
            indicator1 = iMACD(Macd,Sign);
            break;
           }
         case INDICATOR_OSMA:
           { 
            static double OsMa[];
            if(ArraySize(OsMa)!=OsMASignal+1)
               ArrayResize(OsMa,OsMASignal+1);
            if(CopyBuffer(indHandle1,0,time1,OsMASignal+1,OsMa)!=OsMASignal+1)
               return(0);
            indicator1 = iOsMA(OsMa);
            break;
           }
         case INDICATOR_STOCHASTIC:
           { 
            static double Stoc[2];
            static double Sign[2];
            if(CopyBuffer(indHandle1,0,time1,2,Stoc)!=2)
               return(0);
            if(CopyBuffer(indHandle1,1,time1,2,Sign)!=2)
               return(0);
            indicator1 = iStochastic(Stoc,Sign);
            break;
           }
         case INDICATOR_RSI:
           { 
            static double Rsi[];
            if(ArraySize(Rsi)!=RSISignal+1)
               ArrayResize(Rsi,RSISignal+1);
            if(CopyBuffer(indHandle1,0,time1,RSISignal+1,Rsi)!=RSISignal+1)
               return(0);
            indicator1 = iRSI(Rsi);
            break;
           }
         case INDICATOR_CCI:
           { 
            static double Cci[2];
            if(CopyBuffer(indHandle1,0,time1,2,Cci)!=2)
               return(0);
            indicator1 = iCCI(Cci);
            break;
           }
         case INDICATOR_RVI:
           { 
            static double Rvi[2];
            static double Sig[2];
            if(CopyBuffer(indHandle1,0,time1,2,Rvi)!=2)
               return(0);
            if(CopyBuffer(indHandle1,1,time1,2,Sig)!=2)
               return(0);
            indicator1 = iRVI(Rvi,Sig);
            break;
           }
         case INDICATOR_ADX:
           { 
            static double Adx[1];
            static double Pdi[2];
            static double Mdi[2];
            if(CopyBuffer(indHandle1,0,time1,1,Adx)!=1)
               return(0);
            if(CopyBuffer(indHandle1,1,time1,2,Pdi)!=2)
               return(0);
            if(CopyBuffer(indHandle1,2,time1,2,Mdi)!=2)
               return(0);
            indicator1 = iADX(Adx,Pdi,Mdi);
            break;
           }
         case INDICATOR_TRIX:
           { 
            static double Trix[];
            if(ArraySize(Trix)!=TrixSignal+1)
               ArrayResize(Trix,TrixSignal+1);
            if(CopyBuffer(indHandle1,0,time1,TrixSignal+1,Trix)!=TrixSignal+1)
               return(0);
            indicator1 = iTriX(Trix);
            break;
           }
         case INDICATOR_BANDS:
           { 
            static double Middle[1];
            static double Upper[1];
            static double Lower[1];
            static double High[1];
            static double Low[1];
            static double Close[1];
            if(CopyBuffer(indHandle1,0,time1,1,Middle)!=1)
               return(0);
            if(CopyBuffer(indHandle1,1,time1,1,Upper)!=1)
               return(0);
            if(CopyBuffer(indHandle1,2,time1,1,Lower)!=1)
               return(0);
            if(CopyHigh(_Symbol,TimeFrame1,time1,1,High)!=1)
               return(0);
            if(CopyLow(_Symbol,TimeFrame1,time1,1,Low)!=1)
               return(0);
            if(CopyClose(_Symbol,TimeFrame1,time1,1,Close)!=1)
               return(0);
            indicator1 = iBands(Middle,Upper,Lower,High,Low,Close);
            break;
           }
        }

      if(Indicator2!=INDICATOR_NONE)
        {
         if(CopyTime(_Symbol,TimeFrame2,time[i],1,Time)!=1)
            return(0);
         const datetime time2 = Time[0];
         switch(Indicator2)
           {
            case INDICATOR_MA:
              { 
               static double MoAv[1];
               static double High[1];
               static double Low[1];
               static double Close[1];
               if(CopyBuffer(indHandle2,0,time2,1,MoAv)!=1)
                  return(0);
               if(CopyHigh(_Symbol,TimeFrame2,time2,1,High)!=1)
                  return(0);
               if(CopyLow(_Symbol,TimeFrame2,time2,1,Low)!=1)
                  return(0);
               if(CopyClose(_Symbol,TimeFrame2,time2,1,Close)!=1)
                  return(0);
               indicator2 = iMA(MoAv,High,Low,Close);
               break;
              }
            case INDICATOR_MACD:
              { 
               static double Macd[2];
               static double Sign[2];
               if(CopyBuffer(indHandle2,0,time2,2,Macd)!=2)
                  return(0);
               if(CopyBuffer(indHandle2,1,time2,2,Sign)!=2)
                  return(0);
               indicator2 = iMACD(Macd,Sign);
               break;
              }
            case INDICATOR_OSMA:
              { 
               static double OsMa[];
               if(ArraySize(OsMa)!=OsMASignal+1)
                  ArrayResize(OsMa,OsMASignal+1);
               if(CopyBuffer(indHandle2,0,time2,OsMASignal+1,OsMa)!=OsMASignal+1)
                  return(0);
               indicator2 = iOsMA(OsMa);
               break;
              }
            case INDICATOR_STOCHASTIC:
              { 
               static double Stoc[2];
               static double Sign[2];
               if(CopyBuffer(indHandle2,0,time2,2,Stoc)!=2)
                  return(0);
               if(CopyBuffer(indHandle2,1,time2,2,Sign)!=2)
                  return(0);
               indicator2 = iStochastic(Stoc,Sign);
               break;
              }
            case INDICATOR_RSI:
              { 
               static double Rsi[];
               if(ArraySize(Rsi)!=RSISignal+1)
                  ArrayResize(Rsi,RSISignal+1);
               if(CopyBuffer(indHandle2,0,time2,RSISignal+1,Rsi)!=RSISignal+1)
                  return(0);
               indicator2 = iRSI(Rsi);
               break;
              }
            case INDICATOR_CCI:
              { 
               static double Cci[2];
               if(CopyBuffer(indHandle2,0,time2,2,Cci)!=2)
                  return(0);
               indicator2 = iCCI(Cci);
               break;
              }
            case INDICATOR_RVI:
              { 
               static double Rvi[2];
               static double Sig[2];
               if(CopyBuffer(indHandle2,0,time2,2,Rvi)!=2)
                  return(0);
               if(CopyBuffer(indHandle2,1,time2,2,Sig)!=2)
                  return(0);
               indicator2 = iRVI(Rvi,Sig);
               break;
              }
            case INDICATOR_ADX:
              { 
               static double Adx[1];
               static double Pdi[2];
               static double Mdi[2];
               if(CopyBuffer(indHandle2,0,time2,1,Adx)!=1)
                  return(0);
               if(CopyBuffer(indHandle2,1,time2,2,Pdi)!=2)
                  return(0);
               if(CopyBuffer(indHandle2,2,time2,2,Mdi)!=2)
                  return(0);
               indicator2 = iADX(Adx,Pdi,Mdi);
               break;
              }
            case INDICATOR_TRIX:
              { 
               static double Trix[];
               if(ArraySize(Trix)!=TrixSignal+1)
                  ArrayResize(Trix,TrixSignal+1);
               if(CopyBuffer(indHandle2,0,time2,TrixSignal+1,Trix)!=TrixSignal+1)
                  return(0);
               indicator2 = iTriX(Trix);
               break;
              }
            case INDICATOR_BANDS:
              { 
               static double Middle[1];
               static double Upper[1];
               static double Lower[1];
               static double High[1];
               static double Low[1];
               static double Close[1];
               if(CopyBuffer(indHandle2,0,time2,1,Middle)!=1)
                  return(0);
               if(CopyBuffer(indHandle2,1,time2,1,Upper)!=1)
                  return(0);
               if(CopyBuffer(indHandle2,2,time2,1,Lower)!=1)
                  return(0);
               if(CopyHigh(_Symbol,TimeFrame2,time2,1,High)!=1)
                  return(0);
               if(CopyLow(_Symbol,TimeFrame2,time2,1,Low)!=1)
                  return(0);
               if(CopyClose(_Symbol,TimeFrame2,time2,1,Close)!=1)
                  return(0);
               indicator2 = iBands(Middle,Upper,Lower,High,Low,Close);
               break;
              }
           }
        }

      if(Indicator2==INDICATOR_NONE)
        {
         if(indicator1==SIGNAL_BUY)
           {
            Buy[i] = low[i] - Range(i);
            if(AlertsOn && prev_calculated>0) 
               AlertsHandle(time[0],SIGNAL_BUY);
            Sell[i] = 0;
           }
         else if(indicator1==SIGNAL_SELL)   
           {
            Sell[i] = high[i] + Range(i);
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
      else
        {
         if(indicator1==SIGNAL_BUY && indicator2==SIGNAL_BUY)
           {
            Buy[i] = low[i] - Range(i);
            if(AlertsOn && prev_calculated>0) 
               AlertsHandle(time[0],SIGNAL_BUY);
            Sell[i] = 0;
           }
         else if(indicator1==SIGNAL_SELL && indicator2==SIGNAL_SELL)   
           {
            Sell[i] = high[i] + Range(i);
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
   if(ObjectFind(0,LabelBox)!=-1)
      ObjectDelete(0,LabelBox);
   if(ObjectFind(0,Label1)!=-1)
      ObjectDelete(0,Label1);
   if(ObjectFind(0,Label2)!=-1)
      ObjectDelete(0,Label2);
   if(ObjectFind(0,Label3)!=-1)
      ObjectDelete(0,Label3);
   if(ObjectFind(0,Label4)!=-1)
      ObjectDelete(0,Label4);
   IndicatorRelease(rangeHandle);
   IndicatorRelease(indHandle1);
   IndicatorRelease(indHandle2);
   return;
  }
//+------------------------------------------------------------------+
//|  Average Range                                                   |
//+------------------------------------------------------------------+
double Range(int idx)
  {
   static double range[1];
   if(CopyBuffer(rangeHandle,0,idx+1,1,range)!=1)
      return(0.0);
   double avgRange = range[0];
   return(avgRange);
  }
//+------------------------------------------------------------------+
//|  Moving Average                                                  |
//+------------------------------------------------------------------+
int iMA(const double &moav[],
        const double &high[],
        const double &low[],
        const double &close[])
  { 
   int signal=SIGNAL_NONE;
   if(close[0]>moav[0] && low[0]<moav[0])
      signal=SIGNAL_BUY;
   if(close[0]<moav[0] && high[0]>moav[0])
      signal=SIGNAL_SELL;
//---
   return(signal);
  }
//+------------------------------------------------------------------+
//|  Moving Average Convergence/Divergence                           |
//+------------------------------------------------------------------+
int iMACD(const double &macd[],
          const double &sign[])
  { 
   double currMacd = macd[1];
   double prevMacd = macd[0];
   double currSign = sign[1];
   double prevSign = sign[0];
//---
   int signal=SIGNAL_NONE;
   if(currMacd>currSign && prevMacd<prevSign)
      signal=SIGNAL_BUY;
   if(currMacd<currSign && prevMacd>prevSign)
      signal=SIGNAL_SELL;
//---
   return(signal);
  }
//+------------------------------------------------------------------+
//|  Oscillator of Moving Averages                                   |
//+------------------------------------------------------------------+
int iOsMA(const double &osma[])
  { 
   ArraySetAsSeries(osma,true);
   double sum1 = 0.0;
   double sum2 = 0.0;
   for(int i=0,j=1;i<OsMASignal;i++,j++)
     { 
      sum1 += osma[i];
      sum2 += osma[j];
     }
   double currOsma = osma[0];
   double prevOsma = osma[1];
   double currSign = sum1 / OsMASignal;
   double prevSign = sum2 / OsMASignal;
//---
   int signal=SIGNAL_NONE;
   if(currOsma>currSign && prevOsma<prevSign)
      signal=SIGNAL_BUY;
   if(currOsma<currSign && prevOsma>prevSign)
      signal=SIGNAL_SELL;
//---
   return(signal);
  }
//+------------------------------------------------------------------+
//|  Stochastic Oscillator                                           |
//+------------------------------------------------------------------+
int iStochastic(const double &stoc[],
                const double &sign[])
  { 
   double currStoc = stoc[1];
   double prevStoc = stoc[0];
   double currSign = sign[1];
   double prevSign = sign[0];
//---
   int signal=SIGNAL_NONE;
   if(currStoc>currSign && prevStoc<prevSign)
      signal=SIGNAL_BUY;
   if(currStoc<currSign && prevStoc>prevSign)
      signal=SIGNAL_SELL;
//---
   return(signal);
  }            
//+------------------------------------------------------------------+
//|  Relative Strength Index                                         |
//+------------------------------------------------------------------+
int iRSI(const double &rsi[])
  { 
   ArraySetAsSeries(rsi,true);
   double sum1 = 0.0;
   double sum2 = 0.0;
   for(int i=0,j=1;i<RSISignal;i++,j++)
     { 
      sum1 += rsi[i];
      sum2 += rsi[j];
     }
   double currRsi = rsi[0];
   double prevRsi = rsi[1];
   double currSig = sum1 / RSISignal;
   double prevSig = sum2 / RSISignal;
//---
   int signal=SIGNAL_NONE;
   if(currRsi>currSig && prevRsi<prevSig)
      signal=SIGNAL_BUY;
   if(currRsi<currSig && prevRsi>prevSig)
      signal=SIGNAL_SELL;
//---
   return(signal);
  }            
//+------------------------------------------------------------------+
//|  Commodity Channel Index                                         |
//+------------------------------------------------------------------+
int iCCI(const double &cci[])
  { 
   double currCci = cci[1];
   double prevCci = cci[0];
   double level[3] = {-100,0,100};
//---
   int signal=SIGNAL_NONE;
   for(int i=0;i<3;i++)
     {
      if(currCci>level[i] && prevCci<=level[i])
        {
         signal=SIGNAL_BUY;
         break;
        } 
      if(currCci<level[i] && prevCci>=level[i])
        {
         signal=SIGNAL_SELL;
         break;
        } 
     } 
//---
   return(signal);
  }            
//+------------------------------------------------------------------+
//|  Relative Vigor Index                                            |
//+------------------------------------------------------------------+
int iRVI(const double &rvi[],
         const double &sig[])
  { 
   double currRvi = rvi[1];
   double prevRvi = rvi[0];
   double currSig = sig[1];
   double prevSig = sig[0];
//---
   int signal=SIGNAL_NONE;
   if(currRvi>currSig && prevRvi<prevSig)
      signal=SIGNAL_BUY;
   if(currRvi<currSig && prevRvi>prevSig)
      signal=SIGNAL_SELL;
//---
   return(signal);
  }            
//+------------------------------------------------------------------+
//|  Average Directional Movement Index                              |
//+------------------------------------------------------------------+
int iADX(const double &Adx[],
         const double &pdi[],
         const double &mdi[])
  { 
   bool adx = Adx[0] < 25;
   double currPdi = pdi[1];
   double prevPdi = pdi[0];
   double currMdi = mdi[1];
   double prevMdi = mdi[0];
//---
   int signal=SIGNAL_NONE;
   if(adx && currPdi>currMdi && prevPdi<prevMdi)
      signal=SIGNAL_BUY;
   if(adx && currPdi<currMdi && prevPdi>prevMdi)
      signal=SIGNAL_SELL;
//---
   return(signal);
  }            
//+------------------------------------------------------------------+
//|  Triple Exponential Moving Averages                              |
//+------------------------------------------------------------------+
int iTriX(const double &trix[])
  { 
   ArraySetAsSeries(trix,true);
   double sum1 = 0.0;
   double sum2 = 0.0;
   for(int i=0,j=1;i<TrixSignal;i++,j++)
     { 
      sum1 += trix[i];
      sum2 += trix[j];
     }
   double currTrix = trix[0];
   double prevTrix = trix[1];
   double currSign = sum1 / TrixSignal;
   double prevSign = sum2 / TrixSignal;
//---
   int signal=SIGNAL_NONE;
   if(currTrix>currSign && prevTrix<prevSign)
      signal=SIGNAL_BUY;
   if(currTrix<currSign && prevTrix>prevSign)
      signal=SIGNAL_SELL;

//---
   return(signal);
  }               
//+------------------------------------------------------------------+
//|  Bollinger Bands                                                 |
//+------------------------------------------------------------------+
int iBands(const double &midle[],
           const double &upper[],
           const double &lower[],
           const double &high[],
           const double &low[],
           const double &close[])
  { 
   int signal=SIGNAL_NONE;
   if((low[0]<lower[0] && close[0]>lower[0]) ||
      (low[0]<midle[0] && close[0]>midle[0]))
      signal=SIGNAL_BUY;
   if((high[0]>upper[0] && close[0]<upper[0]) ||
      (high[0]>midle[0] && close[0]<midle[0]))
      signal=SIGNAL_SELL;
//---
   return(signal);
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
