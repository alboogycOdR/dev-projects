#property link          "https://www.earnforex.com/metatrader-indicators/trading-session-time/"
#property version       "1.00"
#property strict
#property copyright     "EarnForex.com - 2019-2021"
#property description   "Trading Session Time Indicator"
#property description   "It will draw a vertical line or rectangle in the time and days specified"
#property description   " "
#property description   "WARNING : You use this software at your own risk."
#property description   "The creator of these plugins cannot be held responsible for any damage or loss."
#property description   " "
#property description   "Find More on EarnForex.com"
//#property icon          "\\Files\\EF-Icon-64x64px.ico"

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0


input string Comment1="========================";     //MQLTA Trading Session Time
input string IndicatorName="MQLTA-TST";               //Indicator Short Name

input string Comment2="========================";     //Indicator Parameters
input string TimeLineStart="0000";                    //Start Time To Draw (Format 24H HHMM)
input string TimeLineEnd="";                          //End Time To Draw (Optional - Format HHMM)
input bool ShowMonday=true;                           //Show If Monday
input bool ShowTuesday=true;                          //Show If Tuesday
input bool ShowWednesday=true;                        //Show If Wednesday
input bool ShowThursday=true;                         //Show If Thursday
input bool ShowFriday=true;                           //Show If Friday
input bool ShowSaturday=false;                        //Show If Saturday
input bool ShowSunday=false;                          //Show If Sunday
input int BarsToScan=0;                               //Maximum Bars To Search (0=No Limit)

input string Comment_3="====================";        //Objects Options
input color LineColor=clrLightGray;                   //Objects Color
input int LineTickness=5;                             //Objects Thickness (For Line, Set 1 to 5)


int StartHour=0;
int StartMinute=0;
int EndHour=0;
int EndMinute=0;
int BarsInChart=0;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   IndicatorSetString(INDICATOR_SHORTNAME,IndicatorName);      //Set the indicator name
   OnInitInitialization();       //Internal function to initialize other variables
   if(!OnInitPreChecksPass())    //Check to see there are requirements that need to be met in order to run
     {
      return(INIT_FAILED);
     }
   if(TimeLineEnd=="")
      DrawLines();
   else
      DrawAreas();

   BarsInChart=Bars(Symbol(),PERIOD_CURRENT);
   return(INIT_SUCCEEDED);       //Return successful initialization if all the above are completed
  }


//OnCalculate runs at every tick or price change received for the current chart and has a set of default input parameters
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

   if(Bars(Symbol(),PERIOD_CURRENT)!=BarsInChart || prev_calculated==0)
     {
      CleanChart();
      if(TimeLineEnd=="")
         DrawLines();
      else
         DrawAreas();
      BarsInChart=Bars(Symbol(),PERIOD_CURRENT);
     }
   datetime server_time=TimeTradeServer();
    
   datetime gmt_time=TimeGMT();
   int offset_seconds=((int)server_time)-((int)gmt_time);
   int minsoffset;
   if(offset_seconds>0)
     minsoffset=offset_seconds/3600;
     
   //Comment("Server offset is "+IntegerToString(offset_seconds)+"secs");
     Comment("Server offset is "
     +IntegerToString(minsoffset)
     +"hours"+
     "\ngmt time:  "+gmt_time
     +"\nsrv time:  "+server_time
     );
 

   return(rates_total);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   CleanChart();        //Removes graphical objects from the chart
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnInitInitialization()
  {
   StartHour=(int)StringSubstr(TimeLineStart,0,2);
   EndHour=(int)StringSubstr(TimeLineEnd,0,2);
   StartMinute=(int)StringSubstr(TimeLineStart,2,2);
   EndMinute=(int)StringSubstr(TimeLineEnd,2,2);
  }


//Function for run checks of requirements for the indicator to run
bool OnInitPreChecksPass()
  {
   if(StartHour<0 || StartMinute<0 || StartHour>23 || StartMinute>59)
     {
      Print("Time Start value not valid, it has to be in the format 0000-2359");
      return false;
     }
   if(TimeLineEnd!="" && (EndHour<0 || EndMinute<0 || EndHour>23 || EndMinute>59))
     {
      Print("Time End value not valid, it has to be in the format 0000-2359");
      return false;
     }
   if(LineTickness<1 || LineTickness>5)
     {
      Print("Line Thickness must be between 1 and 5");
      return false;
     }
   return true;
  }


//Function to remove graphical objects from the chart
void CleanChart()
  {
//Set the Windows to 0 means used the current chart
   int Window=0;
//Scan all the graphical objects in the current chart and delete them if their name contains the indicator name
   for(int i=ObjectsTotal(ChartID(),Window,-1)-1; i>=0; i--)
     {
      if(StringFind(ObjectName(0,i),IndicatorName,0)>=0)
        {
         ObjectDelete(0,ObjectName(0,i));
        }
     }
  }


//This function is to initialize the Buffers necessary to draw the signals and store the signals
void InitialiseBuffers()
  {

  }


//Useful ready to use function to check if the price is in a new candle, it returns true only once at the first price change received in a new candle
datetime NewCandleTime=TimeCurrent();
bool CheckIfNewCandle()
  {
   if(NewCandleTime==iTime(Symbol(),0,0))
      return false;
   else
     {
      NewCandleTime=iTime(Symbol(),0,0);
      return true;
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawLines()
  {
   int MaxBars=BarsToScan;
   if(Bars(Symbol(),PERIOD_CURRENT)<MaxBars || MaxBars==0)
      MaxBars=Bars(Symbol(),PERIOD_CURRENT);
   datetime MaxTime=iTime(Symbol(),PERIOD_CURRENT,MaxBars-1);
   MqlDateTime CurrentTime;
   TimeToStruct(iTime(Symbol(),PERIOD_CURRENT,0),CurrentTime);
   string CurrentTimeStr=(string)CurrentTime.year+"."+(string)CurrentTime.mon+"."+(string)CurrentTime.day+" "+(string)StartHour+":"+(string)StartMinute;
   datetime CurrTime=StringToTime(CurrentTimeStr);
   while(CurrTime>MaxTime && iClose(Symbol(),PERIOD_CURRENT,iBarShift(Symbol(),PERIOD_CURRENT,CurrTime))>0)
     {
      TimeToStruct(CurrTime,CurrentTime);
      if(CurrentTime.day_of_week==0 && ShowSunday)
         DrawLine(CurrTime);
      if(CurrentTime.day_of_week==1 && ShowMonday)
         DrawLine(CurrTime);
      if(CurrentTime.day_of_week==2 && ShowTuesday)
         DrawLine(CurrTime);
      if(CurrentTime.day_of_week==3 && ShowWednesday)
         DrawLine(CurrTime);
      if(CurrentTime.day_of_week==4 && ShowThursday)
         DrawLine(CurrTime);
      if(CurrentTime.day_of_week==5 && ShowFriday)
         DrawLine(CurrTime);
      if(CurrentTime.day_of_week==6 && ShowSaturday)
         DrawLine(CurrTime);
      CurrTime-=PeriodSeconds(PERIOD_D1);
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawLine(datetime LineTime)
  {
   string LineName=IndicatorName+"-VLINE-"+IntegerToString(LineTime);
   ObjectCreate(0,LineName,OBJ_VLINE,0,LineTime,0);
   ObjectSetInteger(0,LineName,OBJPROP_COLOR,LineColor);
   ObjectSetInteger(0,LineName,OBJPROP_BACK,true);
   ObjectSetInteger(0,LineName,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,LineName,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,LineName,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,LineName,OBJPROP_WIDTH,LineTickness);

  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawAreas()
  {
   int MaxBars=BarsToScan;
   if(Bars(Symbol(),PERIOD_CURRENT)<MaxBars || MaxBars==0)
      MaxBars=Bars(Symbol(),PERIOD_CURRENT);
   datetime MaxTime=iTime(Symbol(),PERIOD_CURRENT,MaxBars-1);
   MqlDateTime StartTimeStruct;
   MqlDateTime EndTimeStruct;
   TimeToStruct(iTime(Symbol(),PERIOD_CURRENT,0),StartTimeStruct);
   TimeToStruct(iTime(Symbol(),PERIOD_CURRENT,0),EndTimeStruct);
   string StartTimeStructStr=(string)StartTimeStruct.year+"."+(string)StartTimeStruct.mon+"."+(string)StartTimeStruct.day+" "+(string)StartHour+":"+(string)StartMinute;
   string EndTimeStructStr=(string)EndTimeStruct.year+"."+(string)EndTimeStruct.mon+"."+(string)EndTimeStruct.day+" "+(string)EndHour+":"+(string)EndMinute;
   datetime StartTime=StringToTime(StartTimeStructStr);
   datetime EndTime=StringToTime(EndTimeStructStr);
   datetime StartTimeTmp=StringToTime(StartTimeStructStr);
   datetime EndTimeTmp=StringToTime(EndTimeStructStr);
   if(StartTimeTmp>EndTimeTmp)
     {
      EndTimeTmp+=PeriodSeconds(PERIOD_D1);
     }
//Print(iClose(Symbol(),PERIOD_CURRENT,iBarShift(Symbol(),PERIOD_CURRENT,StartTimeTmp))," ",StartTimeTmp);
   while(StartTimeTmp>MaxTime && iClose(Symbol(),PERIOD_CURRENT,iBarShift(Symbol(),PERIOD_CURRENT,StartTimeTmp))>0)
     {
      TimeToStruct(StartTimeTmp,StartTimeStruct);
      if(StartTimeStruct.day_of_week==0 && ShowSunday)
         DrawArea(StartTimeTmp,EndTimeTmp);
      if(StartTimeStruct.day_of_week==1 && ShowMonday)
         DrawArea(StartTimeTmp,EndTimeTmp);
      if(StartTimeStruct.day_of_week==2 && ShowTuesday)
         DrawArea(StartTimeTmp,EndTimeTmp);
      if(StartTimeStruct.day_of_week==3 && ShowWednesday)
         DrawArea(StartTimeTmp,EndTimeTmp);
      if(StartTimeStruct.day_of_week==4 && ShowThursday)
         DrawArea(StartTimeTmp,EndTimeTmp);
      if(StartTimeStruct.day_of_week==5 && ShowFriday)
         DrawArea(StartTimeTmp,EndTimeTmp);
      if(StartTimeStruct.day_of_week==6 && ShowSaturday)
         DrawArea(StartTimeTmp,EndTimeTmp);
      StartTimeTmp-=PeriodSeconds(PERIOD_D1);
      EndTimeTmp-=PeriodSeconds(PERIOD_D1);
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawArea(datetime Start, datetime End)
  {
   string AreaName=IndicatorName+"-AREA-"+IntegerToString(Start);
   int StartBar=iBarShift(Symbol(),PERIOD_CURRENT,Start);
   int EndBar=iBarShift(Symbol(),PERIOD_CURRENT,End);
   int BarsCount=StartBar-EndBar;
   double HighPoint=iHigh(Symbol(),PERIOD_CURRENT,iHighest(Symbol(),PERIOD_CURRENT,MODE_HIGH,BarsCount,EndBar));
   double LowPoint=iLow(Symbol(),PERIOD_CURRENT,iLowest(Symbol(),PERIOD_CURRENT,MODE_LOW,BarsCount,EndBar));
   ObjectCreate(0,AreaName,OBJ_RECTANGLE,0,Start,HighPoint,End,LowPoint);
   ObjectSetInteger(0,AreaName,OBJPROP_COLOR,LineColor);
   ObjectSetInteger(0,AreaName,OBJPROP_BACK,true);
   ObjectSetInteger(0,AreaName,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,AreaName,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,AreaName,OBJPROP_FILL,true);
   ObjectSetInteger(0,AreaName,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,AreaName,OBJPROP_WIDTH,LineTickness);

  }
//+------------------------------------------------------------------+
