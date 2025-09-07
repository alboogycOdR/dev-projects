//+------------------------------------------------------------------+
//|                                          ICT_3 Bar_ Fractals.mq4 |
//|                      Copyright © 2012, MetaQuotes Software Corp. |
//|                                        http://www.metaquotes.net |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2012, MetaQuotes Software Corp."
#property link      "http://www.metaquotes.net"

#define major   1
#define minor   0

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1 Red
#property indicator_color2 DodgerBlue
#property indicator_width1  3
#property indicator_width2  3


extern int leftPeriod = 1;
extern int rightPeriod = 1;
extern int errorInPips = 0;
extern int nrOfPips = 4;
extern int MaxBars = 2500;


double upper_fr[];
double lower_fr[];

int minPeriod, maxPeriod;
double factorPipsToPrice;//  = 1/MathPow(10,nrOfPips);
double errorInPrice;
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

void init() {
  SetIndexBuffer(0, upper_fr);
  SetIndexBuffer(1, lower_fr);
  
  SetIndexEmptyValue(0, 0);
  SetIndexEmptyValue(1, 0);
  
  SetIndexStyle(0, DRAW_ARROW);
  SetIndexArrow(0, 217);//SYMBOL_ARROWDOWN);//234

  SetIndexStyle(1, DRAW_ARROW);
  SetIndexArrow(1, 218); //233 SYMBOL_ARROWUP  
  
  minPeriod = MathMin(leftPeriod,rightPeriod);
  maxPeriod = MathMax(leftPeriod,rightPeriod);
  
  factorPipsToPrice = 1/MathPow(10,nrOfPips);
  errorInPrice = errorInPips * factorPipsToPrice;  
}

void start() 
{
  int counted = IndicatorCounted();
  if (counted < 0) return (-1);
  if (counted > 0) counted--;
  
  int limit = MathMin(Bars-counted, MaxBars);
  
  //-----
  
  double dy = 0;
  for (int i=1; i <= 20; i++) {
    dy += 0.3*(High[i]-Low[i])/20;
  }
  
  for (i=minPeriod; i <= limit+minPeriod; i++) 
  {
    upper_fr[i] = 0;
    lower_fr[i] = 0;
  
    if (is_upper_fr(i, leftPeriod, rightPeriod)) upper_fr[i] = High[i]+2*dy;
    if (is_lower_fr(i, leftPeriod, rightPeriod)) lower_fr[i] = Low[i]-2*dy;
  }
}

bool is_upper_fr(int bar, int leftPeriod, int rightPeriod) { 
  int i;
  
  for (i=1; i<=leftPeriod; i++) 
  {
    if (bar+i >= Bars) return (false);
    if (High[bar] < High[bar+i] - errorInPrice) return (false);
  }
  
  for (i=1; i<=rightPeriod; i++) 
  {
    if (bar-i < 0) return (false);
    if (High[bar]< High[bar-i] - errorInPrice) return (false);
  }

  return (true);
}

bool is_lower_fr(int bar, int leftPeriod, int rightPeriod) {
  int i;
  for (i=1; i<=leftPeriod; i++) 
  {
    if (bar+i >= Bars) return (false);
    if (Low[bar] > Low[bar+i] + errorInPrice) return (false);
  }
  for (i=1; i<=rightPeriod; i++) 
  {
    if (bar-i < 0) return (false); 
    if (Low[bar] > Low[bar-i] + errorInPrice) return (false);
  }
  return (true);
}