//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

//---------------- -------------------------------------------------- -+
double High[],Low[];
int bars=1500,KF=1; // the screen will display 1500 bars from the left edge of the chart to the right
//------------------------------------ -------------------------------+
void OnStart()
{
   if(_Digits==5 || _Digits==3) {
      KF=10;
   }
   else {
      KF=1;
   }
// define the first left bar. We will take a screenshot from it
   int first_bar=(int)ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR);
// define how many bars are shown on the chart - it will be needed to determine screenshot width
   int vis_bar=(int)ChartGetInteger(0,CHART_VISIBLE_BARS);
   Print("Bars displayed by chart width=",vis_bar);
// get prices in an array on the interval from our bar and 1500 bars to set the high-low chart
   if(first_bar<bars) {
      bars=first_bar;  // if the chart is shifted less than the required bars, then we take everything that is to the right of the current one time
   }
   int ch=CopyHigh(_Symbol,_Period,first_bar-bars,bars,High);
   int cl=CopyLow(_Symbol,_Period,first_bar-bars,bars,Low);
// define high low on our interval and set the top and bottom of the scale prices
   double min_price=Low[ArrayMinimum(Low,0,bars)];
   double max_price=High[ArrayMaximum(High,0,bars)];
// fix the scale and set the top and bottom
   ChartSetInteger(0,CHART_SCALEFIX,0,1);
   ChartSetDouble(0,CHART_FIXED_MAX,max_price+20*KF*_Point);
   ChartSetDouble(0,CHART_FIXED_MIN,min_price-20*KF*_Point);
   ChartSetInteger (0,CHART_AUTOSCROLL,false);
// get the current date in a simple format for forming the file name
   MqlDateTime day;
   TimeToStruct(TimeCurrent(),day);
   string file=_Symbol+(string)day.year+"_"+(string)day.mon+"_"+(string)day.day+"_"+(string)day.hour+"_"+(string)day.min+ "_"+(string)day.sec+".png";
// define the height and width of the future screen
   int screen_width=1000*bars/vis_bar;
   Print("Screen width=",screen_width);
   int scr_height=(int)ChartGetInteger (0,CHART_HEIGHT_IN_PIXELS);
// take a screenshot
   ChartScreenShot(0,file,screen_width,scr_height,ALIGN_LEFT);
   if(GetLastError()>0) {
      if(GetLastError()>0) {
         Print("Error  (",GetLastError(),") ");
      }
      ResetLastError();
   }
}
//+------------------------------------------------------------------+
