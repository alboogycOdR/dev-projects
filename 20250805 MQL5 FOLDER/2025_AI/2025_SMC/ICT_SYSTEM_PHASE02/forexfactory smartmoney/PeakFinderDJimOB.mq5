//+------------------------------------------------------------------+
//|                                                   PeakFinder.mq5 |
//|                                  Copyright 2022, Alick Phillips. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Alick Phillips."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
input  ENUM_TIMEFRAMES BigOBtimeframe = PERIOD_CURRENT;   //Higher TimeFrame of OB
input  int showlder = 2;   //Higher TimeFrame of OB
input  int startbar = 3;   //Higher TimeFrame of OB

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnStart()
  { 
  ENUM_SERIESMODE mode = MODE_LOW;
 int   impol = NextImpulseUp( BigOBtimeframe, 3, 1800,1 ) ;
   ObjectDelete(0,"peakbardiffiext");//210
 ChartWrite("peakbardiffiext", "peakbardiffiext" + (string)impol, 100, 11, 10, clrWhite); //Write Number of Orders on the Chart
 ///--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0,"bearOBhi1");
   ObjectDelete(0,"bearOBlo1");
int bar1= OBbarsmc(BigOBtimeframe,startbar,1800, 1,0);
double hi1= OBhighsmc(BigOBtimeframe,startbar,1800,1);
double lo1= OBlowsmc(BigOBtimeframe,startbar,1800,1);
   datetime t_th1 = iTime(NULL, BigOBtimeframe, bar1 ); 
   datetime f_ti1 = iTime(NULL, BigOBtimeframe, bar1-bar1+1 ); 
  ObjectCreate(0,"bearOBhi1", OBJ_TREND, 0, t_th1, hi1,   f_ti1, hi1);
 ObjectSetInteger(0,"bearOBhi1",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBhi1", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBhi1", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bearOBlo1", OBJ_TREND, 0, t_th1, lo1,  f_ti1, lo1);
 ObjectSetInteger(0,"bearOBlo1",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBlo1", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBlo1", OBJPROP_WIDTH, 3);
 //xxxxx
// //xxxxx
   ObjectDelete(0,"bullOBhi1");
   ObjectDelete(0,"bullOBlo1");
int xbar1= OBbarsmc(BigOBtimeframe,startbar,1800,1,1);
double xhi1=OBhighsmcup(BigOBtimeframe, startbar,1800,1);
double xlo1= OBlowsmcup(BigOBtimeframe, startbar,1800,1);
   datetime t_t1 = iTime(NULL, BigOBtimeframe, xbar1 ); 
   datetime f_t1 = iTime(NULL, BigOBtimeframe, xbar1-xbar1 +1); 
  ObjectCreate(0,"bullOBhi1", OBJ_TREND, 0, t_t1, xhi1,   f_t1, xhi1);
 ObjectSetInteger(0,"bullOBhi1",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBhi1", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBhi1", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bullOBlo1", OBJ_TREND, 0, t_t1, xlo1,  f_t1, xlo1);
 ObjectSetInteger(0,"bullOBlo1",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBlo1", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBlo1", OBJPROP_WIDTH, 3);
//---
///---
   ObjectDelete(0,"bearOBhi2");
   ObjectDelete(0,"bearOBlo2");
int bar2= OBbarsmc(BigOBtimeframe,startbar,1800,2,1);
double hi2=OBhighsmc(BigOBtimeframe,startbar,1800,2);
double lo2= OBlowsmc(BigOBtimeframe,startbar,1800,2);
   datetime t_th2 = iTime(NULL, BigOBtimeframe, bar2 ); 
   datetime f_ti2 = iTime(NULL, BigOBtimeframe, bar1+1 ); 
  ObjectCreate(0,"bearOBhi2", OBJ_TREND, 0, t_th2, hi2,   f_ti2, hi2);
 ObjectSetInteger(0,"bearOBhi2",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBhi2", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBhi2", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bearOBlo2", OBJ_TREND, 0, t_th2, lo2,  f_ti2, lo2);
 ObjectSetInteger(0,"bearOBlo2",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBlo2", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBlo2", OBJPROP_WIDTH, 3);
 //xxxxx
 //xxxxx
   ObjectDelete(0,"bullOBhi2");
   ObjectDelete(0,"bullOBlo2");
int xbar2= OBbarsmc(BigOBtimeframe,startbar,1800,2,1);
double xhi2=OBhighsmcup(BigOBtimeframe,startbar,1800,2);
double xlo2= OBlowsmcup(BigOBtimeframe,startbar,1800,2);
   datetime t_t2 = iTime(NULL, BigOBtimeframe, xbar2 ); 
   datetime f_t2 = iTime(NULL, BigOBtimeframe, xbar1 +1 ); 
  ObjectCreate(0,"bullOBhi2", OBJ_TREND, 0, t_t2, xhi2,   f_t2, xhi2);
 ObjectSetInteger(0,"bullOBhi2",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBhi2", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBhi2", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bullOBlo2", OBJ_TREND, 0, t_t2, xlo2,  f_t2, xlo2);
 ObjectSetInteger(0,"bullOBlo2",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBlo2", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBlo2", OBJPROP_WIDTH, 3);
//--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0,"bearOBhi3");
   ObjectDelete(0,"bearOBlo3");
int bar3= OBbarsmc(BigOBtimeframe,startbar,1800,3,0);
double hi3=OBhighsmc(BigOBtimeframe,startbar,1800,3);
double lo3= OBlowsmc(BigOBtimeframe,startbar,1800,3);
   datetime t_th3 = iTime(NULL, BigOBtimeframe, bar3 ); 
   datetime f_ti3 = iTime(NULL, BigOBtimeframe, bar2+1 ); 
  ObjectCreate(0,"bearOBhi3", OBJ_TREND, 0, t_th3, hi3,   f_ti3, hi3);
 ObjectSetInteger(0,"bearOBhi3",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBhi3", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBhi3", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bearOBlo3", OBJ_TREND, 0, t_th3, lo3,  f_ti3, lo3);
 ObjectSetInteger(0,"bearOBlo3",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBlo3", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBlo3", OBJPROP_WIDTH, 3);
 //xxxxx
 //xxxxx
   ObjectDelete(0,"bullOBhi3");
   ObjectDelete(0,"bullOBlo3");
int xbar3= OBbarsmc(BigOBtimeframe,startbar,1800,3,1);
double xhi3=OBhighsmcup(BigOBtimeframe,startbar,1800,3);
double xlo3= OBlowsmcup(BigOBtimeframe,startbar,1800,3);
   datetime t_t3 = iTime(NULL, BigOBtimeframe, xbar3 ); 
   datetime f_t3 = iTime(NULL, BigOBtimeframe, xbar2 +1); 
  ObjectCreate(0,"bullOBhi3", OBJ_TREND, 0, t_t3, xhi3,   f_t3, xhi3);
 ObjectSetInteger(0,"bullOBhi3",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBhi3", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBhi3", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bullOBlo3", OBJ_TREND, 0, t_t3, xlo3,  f_t3, xlo3);
 ObjectSetInteger(0,"bullOBlo3",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBlo3", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBlo3", OBJPROP_WIDTH, 3);
//--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0,"bearOBhi4");
   ObjectDelete(0,"bearOBlo4");
int bar4= OBbarsmc(BigOBtimeframe,startbar,1800,4,0);
double hi4=OBhighsmc(BigOBtimeframe,startbar,1800,4);
double lo4= OBlowsmc(BigOBtimeframe,startbar,1800,4);
   datetime t_th4 = iTime(NULL, BigOBtimeframe, bar4 ); 
   datetime f_ti4 = iTime(NULL, BigOBtimeframe, bar3+1 ); 
  ObjectCreate(0,"bearOBhi4", OBJ_TREND, 0, t_th4, hi4,   f_ti4, hi4);
 ObjectSetInteger(0,"bearOBhi4",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBhi4", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBhi4", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bearOBlo4", OBJ_TREND, 0, t_th4, lo4,  f_ti4, lo4);
 ObjectSetInteger(0,"bearOBlo4",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBlo4", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBlo4", OBJPROP_WIDTH, 3);
 //xxxxx
 //xxxxx
   ObjectDelete(0,"bullOBhi4");
   ObjectDelete(0,"bullOBlo4");
int xbar4= OBbarsmc(BigOBtimeframe,startbar,1800,4,1);
double xhi4=OBhighsmcup(BigOBtimeframe,startbar,1800,4);
double xlo4= OBlowsmcup(BigOBtimeframe,startbar,1800,4);
   datetime t_t4 = iTime(NULL, BigOBtimeframe, xbar4 ); 
   datetime f_t4 = iTime(NULL, BigOBtimeframe, xbar3 +1 ); 
  ObjectCreate(0,"bullOBhi4", OBJ_TREND, 0, t_t4, xhi4,   f_t4, xhi4);
 ObjectSetInteger(0,"bullOBhi4",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBhi4", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBhi4", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bullOBlo4", OBJ_TREND, 0, t_t4, xlo4,  f_t4, xlo4);
 ObjectSetInteger(0,"bullOBlo4",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBlo4", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBlo4", OBJPROP_WIDTH, 3);
//--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0,"bearOBhi5");
   ObjectDelete(0,"bearOBlo5");
int bar5= OBbarsmc(BigOBtimeframe,startbar,1800,5,0);
double hi5=OBhighsmc(BigOBtimeframe,startbar,1800,5);
double lo5= OBlowsmc(BigOBtimeframe,startbar,1800,5);
   datetime t_th5 = iTime(NULL, BigOBtimeframe, bar5 ); 
   datetime f_ti5 = iTime(NULL, BigOBtimeframe, bar4 +1 ); 
  ObjectCreate(0,"bearOBhi5", OBJ_TREND, 0, t_th5, hi5,   f_ti5, hi5);
 ObjectSetInteger(0,"bearOBhi5",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBhi5", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBhi5", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bearOBlo5", OBJ_TREND, 0, t_th5, lo5,  f_ti5, lo5);
 ObjectSetInteger(0,"bearOBlo5",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBlo5", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBlo5", OBJPROP_WIDTH, 3);
 //xxxxx
 //xxxxx
   ObjectDelete(0,"bullOBhi5");
   ObjectDelete(0,"bullOBlo5");
int xbar5= OBbarsmc(BigOBtimeframe,startbar,1800,5,1);
double xhi5=OBhighsmcup(BigOBtimeframe,startbar,1800,5);
double xlo5= OBlowsmcup(BigOBtimeframe,startbar,1800,5);
   datetime t_t5 = iTime(NULL, BigOBtimeframe, xbar5 ); 
   datetime f_t5 = iTime(NULL, BigOBtimeframe, xbar4 ); 
  ObjectCreate(0,"bullOBhi5", OBJ_TREND, 0, t_t5, xhi5,   f_t5, xhi5);
 ObjectSetInteger(0,"bullOBhi5",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBhi5", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBhi5", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bullOBlo5", OBJ_TREND, 0, t_t5, xlo5,  f_t5, xlo5);
 ObjectSetInteger(0,"bullOBlo5",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBlo5", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBlo5", OBJPROP_WIDTH, 3);
//--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0,"bearOBhi6");
   ObjectDelete(0,"bearOBlo6");
int bar6= OBbarsmc(BigOBtimeframe,startbar,1800,6,0);
double hi6=OBhighsmc(BigOBtimeframe,startbar,1800,6);
double lo6= OBlowsmc(BigOBtimeframe,startbar,1800,6);
   datetime t_th6 = iTime(NULL, BigOBtimeframe, bar6 ); 
   datetime f_ti6 = iTime(NULL, BigOBtimeframe, bar5 +1 ); 
  ObjectCreate(0,"bearOBhi6", OBJ_TREND, 0, t_th6, hi6,   f_ti6, hi6);
 ObjectSetInteger(0,"bearOBhi6",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBhi6", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBhi6", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bearOBlo6", OBJ_TREND, 0, t_th6, lo6,  f_ti6, lo6);
 ObjectSetInteger(0,"bearOBlo6",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBlo6", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBlo6", OBJPROP_WIDTH, 3);
 //xxxxx
 //xxxxx
   ObjectDelete(0,"bullOBhi6");
   ObjectDelete(0,"bullOBlo6");
int xbar6= OBbarsmc(BigOBtimeframe,startbar,1800,6,1);
double xhi6=OBhighsmcup(BigOBtimeframe,startbar,1800,6);
double xlo6= OBlowsmcup(BigOBtimeframe,startbar,1800,6);
   datetime t_t6 = iTime(NULL, BigOBtimeframe, xbar6 ); 
   datetime f_t6 = iTime(NULL, BigOBtimeframe, xbar5 +1 ); 
  ObjectCreate(0,"bullOBhi6", OBJ_TREND, 0, t_t6, xhi6,   f_t6, xhi6);
 ObjectSetInteger(0,"bullOBhi6",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBhi6", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBhi6", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bullOBlo6", OBJ_TREND, 0, t_t6, xlo6,  f_t6, xlo6);
 ObjectSetInteger(0,"bullOBlo6",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBlo6", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBlo6", OBJPROP_WIDTH, 3);
//--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0,"bearOBhi7");
   ObjectDelete(0,"bearOBlo7");
int bar7= OBbarsmc(BigOBtimeframe,startbar,1800,7,0);
double hi7=OBhighsmc(BigOBtimeframe,startbar,1800,7);
double lo7= OBlowsmc(BigOBtimeframe,startbar,1800,7);
   datetime t_th7 = iTime(NULL, BigOBtimeframe, bar7 ); 
   datetime f_ti7 = iTime(NULL, BigOBtimeframe, bar6 +1 ); 
  ObjectCreate(0,"bearOBhi7", OBJ_TREND, 0, t_th7, hi7,   f_ti7, hi7);
 ObjectSetInteger(0,"bearOBhi7",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBhi7", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBhi7", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bearOBlo7", OBJ_TREND, 0, t_th7, lo7,  f_ti7, lo7);
 ObjectSetInteger(0,"bearOBlo7",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBlo7", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBlo7", OBJPROP_WIDTH, 3);
 //xxxxx
 //xxxxx
   ObjectDelete(0,"bullOBhi7");
   ObjectDelete(0,"bullOBlo7");
int xbar7= OBbarsmc(BigOBtimeframe,startbar,1800,7,1);
double xhi7=OBhighsmcup(BigOBtimeframe,startbar,1800,7);
double xlo7= OBlowsmcup(BigOBtimeframe,startbar,1800,7);
   datetime t_t7 = iTime(NULL, BigOBtimeframe, xbar7 ); 
   datetime f_t7 = iTime(NULL, BigOBtimeframe, xbar6 +1 ); 
  ObjectCreate(0,"bullOBhi7", OBJ_TREND, 0, t_t7, xhi7,   f_t7, xhi7);
 ObjectSetInteger(0,"bullOBhi7",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBhi7", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBhi7", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bullOBlo7", OBJ_TREND, 0, t_t7, xlo7,  f_t7, xlo7);
 ObjectSetInteger(0,"bullOBlo7",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBlo7", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBlo7", OBJPROP_WIDTH, 3);
//--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0,"bearOBhi8");
   ObjectDelete(0,"bearOBlo8");
int bar8= OBbarsmc(BigOBtimeframe,startbar,1800,8,0);
double hi8=OBhighsmc(BigOBtimeframe,startbar,1800,8);
double lo8= OBlowsmc(BigOBtimeframe,startbar,1800,8);
   datetime t_th8 = iTime(NULL, BigOBtimeframe, bar8 ); 
   datetime f_ti8 = iTime(NULL, BigOBtimeframe, bar7 +1 ); 
  ObjectCreate(0,"bearOBhi8", OBJ_TREND, 0, t_th8, hi8,   f_ti8, hi8);
 ObjectSetInteger(0,"bearOBhi8",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBhi8", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBhi8", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bearOBlo8", OBJ_TREND, 0, t_th8, lo8,  f_ti8, lo8);
 ObjectSetInteger(0,"bearOBlo8",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBlo8", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBlo8", OBJPROP_WIDTH, 3);
 //xxxxx
 //xxxxx
   ObjectDelete(0,"bullOBhi8");
   ObjectDelete(0,"bullOBlo8");
int xbar8= OBbarsmc(BigOBtimeframe,startbar,1800,8,1);
double xhi8=OBhighsmcup(BigOBtimeframe,startbar,1800,8);
double xlo8= OBlowsmcup(BigOBtimeframe,startbar,1800,8);
   datetime t_t8 = iTime(NULL, BigOBtimeframe, xbar8 ); 
   datetime f_t8 = iTime(NULL, BigOBtimeframe, xbar7 +1 ); 
  ObjectCreate(0,"bullOBhi8", OBJ_TREND, 0, t_t8, xhi8,   f_t8, xhi8);
 ObjectSetInteger(0,"bullOBhi8",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBhi8", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBhi8", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bullOBlo8", OBJ_TREND, 0, t_t8, xlo8,  f_t8, xlo8);
 ObjectSetInteger(0,"bullOBlo8",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBlo8", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBlo8", OBJPROP_WIDTH, 3);
//--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0,"bearOBhi9");
   ObjectDelete(0,"bearOBlo9");
int bar9= OBbarsmc(BigOBtimeframe,startbar,1800,9,0);
double hi9=OBhighsmc(BigOBtimeframe,startbar,1800,9);
double lo9= OBlowsmc(BigOBtimeframe,startbar,1800,9);
   datetime t_th9 = iTime(NULL, BigOBtimeframe, bar9 ); 
   datetime f_ti9 = iTime(NULL, BigOBtimeframe, bar8 +1 ); 
  ObjectCreate(0,"bearOBhi9", OBJ_TREND, 0, t_th9, hi9,   f_ti9, hi9);
 ObjectSetInteger(0,"bearOBhi9",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBhi9", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBhi9", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bearOBlo9", OBJ_TREND, 0, t_th9, lo9,  f_ti9, lo9);
 ObjectSetInteger(0,"bearOBlo9",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBlo9", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBlo9", OBJPROP_WIDTH, 3);
 //xxxxx
 //xxxxx
   ObjectDelete(0,"bullOBhi9");
   ObjectDelete(0,"bullOBlo9");
int xbar9= OBbarsmc(BigOBtimeframe,startbar,1800,9,1);
double xhi9=OBhighsmcup(BigOBtimeframe,startbar,1800,9);
double xlo9= OBlowsmcup(BigOBtimeframe,startbar,1800,9);
   datetime t_t9 = iTime(NULL, BigOBtimeframe, xbar9 ); 
   datetime f_t9 = iTime(NULL, BigOBtimeframe, xbar8 +1 ); 
  ObjectCreate(0,"bullOBhi9", OBJ_TREND, 0, t_t9, xhi9,   f_t9, xhi9);
 ObjectSetInteger(0,"bullOBhi9",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBhi9", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBhi9", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bullOBlo9", OBJ_TREND, 0, t_t9, xlo9,  f_t9, xlo9);
 ObjectSetInteger(0,"bullOBlo9",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBlo9", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBlo9", OBJPROP_WIDTH, 3);
//--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0,"bearOBhi10");
   ObjectDelete(0,"bearOBlo10");
int bar10= OBbarsmc(BigOBtimeframe,startbar,1800,10,0);
double hi10=OBhighsmc(BigOBtimeframe,startbar,1800,10);
double lo10= OBlowsmc(BigOBtimeframe,startbar,1800,10);
   datetime t_th10 = iTime(NULL, BigOBtimeframe, bar10 ); 
   datetime f_ti10 = iTime(NULL, BigOBtimeframe, bar9 +1 ); 
  ObjectCreate(0,"bearOBhi10", OBJ_TREND, 0, t_th10, hi10,   f_ti10, hi10);
 ObjectSetInteger(0,"bearOBhi10",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBhi10", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBhi10", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bearOBlo10", OBJ_TREND, 0, t_th10, lo10,  f_ti10, lo10);
 ObjectSetInteger(0,"bearOBlo10",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBlo10", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBlo10", OBJPROP_WIDTH, 3);
 //xxxxx
 //xxxxx
   ObjectDelete(0,"bullOBhi10");
   ObjectDelete(0,"bullOBlo10");
int xbar10= OBbarsmc(BigOBtimeframe,startbar,1800,10,1);
double xhi10=OBhighsmcup(BigOBtimeframe,startbar,1800,10);
double xlo10= OBlowsmcup(BigOBtimeframe,startbar,1800,10);
   datetime t_t10 = iTime(NULL, BigOBtimeframe, xbar10 ); 
   datetime f_t10 = iTime(NULL, BigOBtimeframe, xbar9 +1 ); 
  ObjectCreate(0,"bullOBhi10", OBJ_TREND, 0, t_t10, xhi10,   f_t10, xhi10);
 ObjectSetInteger(0,"bullOBhi10",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBhi10", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBhi10", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bullOBlo10", OBJ_TREND, 0, t_t10, xlo10,  f_t10, xlo10);
 ObjectSetInteger(0,"bullOBlo10",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBlo10", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBlo10", OBJPROP_WIDTH, 3);
//--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0,"bearOBhi11");
   ObjectDelete(0,"bearOBlo11");
int bar11= OBbarsmc(BigOBtimeframe,startbar,1800,11,0);
double hi11=OBhighsmc(BigOBtimeframe,startbar,1800,11);
double lo11= OBlowsmc(BigOBtimeframe,startbar,1800,11);
   datetime t_th11 = iTime(NULL, BigOBtimeframe, bar11 ); 
   datetime f_ti11 = iTime(NULL, BigOBtimeframe, bar10 +1 ); 
  ObjectCreate(0,"bearOBhi11", OBJ_TREND, 0, t_th11, hi11,   f_ti11, hi11);
 ObjectSetInteger(0,"bearOBhi11",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBhi11", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBhi11", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bearOBlo11", OBJ_TREND, 0, t_th11, lo11,  f_ti11, lo11);
 ObjectSetInteger(0,"bearOBlo11",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBlo11", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBlo11", OBJPROP_WIDTH, 3);
 //xxxxx
 //xxxxx
   ObjectDelete(0,"bullOBhi11");
   ObjectDelete(0,"bullOBlo11");
int xbar11= OBbarsmc(BigOBtimeframe,startbar,1800,11,1);
double xhi11=OBhighsmcup(BigOBtimeframe,startbar,1800,11);
double xlo11= OBlowsmcup(BigOBtimeframe,startbar,1800,11);
   datetime t_t11 = iTime(NULL, BigOBtimeframe, xbar11 ); 
   datetime f_t11 = iTime(NULL, BigOBtimeframe, xbar10 +1 ); 
  ObjectCreate(0,"bullOBhi11", OBJ_TREND, 0, t_t11, xhi11,   f_t11, xhi11);
 ObjectSetInteger(0,"bullOBhi11",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBhi11", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBhi11", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bullOBlo11", OBJ_TREND, 0, t_t11, xlo11,  f_t11, xlo11);
 ObjectSetInteger(0,"bullOBlo11",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBlo11", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBlo11", OBJPROP_WIDTH, 3);
//--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0,"bearOBhi12");
   ObjectDelete(0,"bearOBlo12");
int bar12= OBbarsmc(BigOBtimeframe,startbar,1800,12,0);
double hi12=OBhighsmc(BigOBtimeframe,startbar,1800,12);
double lo12= OBlowsmc(BigOBtimeframe,startbar,1800,12);
   datetime t_th12 = iTime(NULL, BigOBtimeframe, bar12 ); 
   datetime f_ti12 = iTime(NULL, BigOBtimeframe, bar11 +1 ); 
  ObjectCreate(0,"bearOBhi12", OBJ_TREND, 0, t_th12, hi12,   f_ti12, hi12);
 ObjectSetInteger(0,"bearOBhi12",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBhi12", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBhi12", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bearOBlo12", OBJ_TREND, 0, t_th12, lo12,  f_ti12, lo12);
 ObjectSetInteger(0,"bearOBlo12",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBlo12", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBlo12", OBJPROP_WIDTH, 3);
 //xxxxx
 //xxxxx
   ObjectDelete(0,"bullOBhi12");
   ObjectDelete(0,"bullOBlo12");
int xbar12= OBbarsmc(BigOBtimeframe,startbar,1800,12,1);
double xhi12=OBhighsmcup(BigOBtimeframe,startbar,1800,12);
double xlo12= OBlowsmcup(BigOBtimeframe,startbar,1800,12);
   datetime t_t12 = iTime(NULL, BigOBtimeframe, xbar12 ); 
   datetime f_t12 = iTime(NULL, BigOBtimeframe, xbar11 +1 ); 
  ObjectCreate(0,"bullOBhi12", OBJ_TREND, 0, t_t12, xhi12,   f_t12, xhi12);
 ObjectSetInteger(0,"bullOBhi12",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBhi12", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBhi12", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bullOBlo12", OBJ_TREND, 0, t_t12, xlo12,  f_t12, xlo12);
 ObjectSetInteger(0,"bullOBlo12",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBlo12", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBlo12", OBJPROP_WIDTH, 3);
//--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0,"bearOBhi13");
   ObjectDelete(0,"bearOBlo13");
int bar13= OBbarsmc(BigOBtimeframe,startbar,1800,13,0);
double hi13=OBhighsmc(BigOBtimeframe,startbar,1800,13);
double lo13= OBlowsmc(BigOBtimeframe,startbar,1800,13);
   datetime t_th13 = iTime(NULL, BigOBtimeframe, bar13 ); 
   datetime f_ti13 = iTime(NULL, BigOBtimeframe, bar12 +1 ); 
  ObjectCreate(0,"bearOBhi13", OBJ_TREND, 0, t_th13, hi13,   f_ti13, hi13);
 ObjectSetInteger(0,"bearOBhi13",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBhi13", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBhi13", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bearOBlo13", OBJ_TREND, 0, t_th13, lo13,  f_ti13, lo13);
 ObjectSetInteger(0,"bearOBlo13",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBlo13", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBlo13", OBJPROP_WIDTH, 3);
 //xxxxx
 //xxxxx
   ObjectDelete(0,"bullOBhi13");
   ObjectDelete(0,"bullOBlo13");
int xbar13= OBbarsmc(BigOBtimeframe,startbar,1800,13,1);
double xhi13=OBhighsmcup(BigOBtimeframe,startbar,1800,13);
double xlo13= OBlowsmcup(BigOBtimeframe,startbar,1800,13);
   datetime t_t13 = iTime(NULL, BigOBtimeframe, xbar13 ); 
   datetime f_t13 = iTime(NULL, BigOBtimeframe, xbar12 +1 ); 
  ObjectCreate(0,"bullOBhi13", OBJ_TREND, 0, t_t13, xhi13,   f_t13, xhi13);
 ObjectSetInteger(0,"bullOBhi13",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBhi13", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBhi13", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bullOBlo13", OBJ_TREND, 0, t_t13, xlo13,  f_t13, xlo13);
 ObjectSetInteger(0,"bullOBlo13",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBlo13", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBlo13", OBJPROP_WIDTH, 3);
//--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0,"bearOBhi14");
   ObjectDelete(0,"bearOBlo14");
int bar14= OBbarsmc(BigOBtimeframe,startbar,1800,14,0);
double hi14=OBhighsmc(BigOBtimeframe,startbar,1800,14);
double lo14= OBlowsmc(BigOBtimeframe,startbar,1800,14);
   datetime t_th14 = iTime(NULL, BigOBtimeframe, bar14 ); 
   datetime f_ti14 = iTime(NULL, BigOBtimeframe, bar13 +1 ); 
  ObjectCreate(0,"bearOBhi14", OBJ_TREND, 0, t_th14, hi14,   f_ti14, hi14);
 ObjectSetInteger(0,"bearOBhi14",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBhi14", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBhi14", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bearOBlo14", OBJ_TREND, 0, t_th14, lo14,  f_ti14, lo14);
 ObjectSetInteger(0,"bearOBlo14",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBlo14", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBlo14", OBJPROP_WIDTH, 3);
 //xxxxx
 //xxxxx
   ObjectDelete(0,"bullOBhi14");
   ObjectDelete(0,"bullOBlo14");
int xbar14= OBbarsmc(BigOBtimeframe,startbar,1800,14,1);
double xhi14=OBhighsmcup(BigOBtimeframe,startbar,1800,14);
double xlo14= OBlowsmcup(BigOBtimeframe,startbar,1800,14);
   datetime t_t14 = iTime(NULL, BigOBtimeframe, xbar14 ); 
   datetime f_t14 = iTime(NULL, BigOBtimeframe, xbar13 +1 ); 
  ObjectCreate(0,"bullOBhi14", OBJ_TREND, 0, t_t14, xhi14,   f_t14, xhi14);
 ObjectSetInteger(0,"bullOBhi14",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBhi14", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBhi14", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bullOBlo14", OBJ_TREND, 0, t_t14, xlo14,  f_t14, xlo14);
 ObjectSetInteger(0,"bullOBlo14",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBlo14", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBlo14", OBJPROP_WIDTH, 3);
//--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0,"bearOBhi15");
   ObjectDelete(0,"bearOBlo15");
int bar15= OBbarsmc(BigOBtimeframe,startbar,1800,15,0);
double hi15=OBhighsmc(BigOBtimeframe,startbar,1800,15);
double lo15= OBlowsmc(BigOBtimeframe,startbar,1800,15);
   datetime t_th15 = iTime(NULL, BigOBtimeframe, bar15 ); 
   datetime f_ti15 = iTime(NULL, BigOBtimeframe, bar14 +1 ); 
  ObjectCreate(0,"bearOBhi15", OBJ_TREND, 0, t_th15, hi15,   f_ti15, hi15);
 ObjectSetInteger(0,"bearOBhi15",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBhi15", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBhi15", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bearOBlo15", OBJ_TREND, 0, t_th15, lo15,  f_ti15, lo15);
 ObjectSetInteger(0,"bearOBlo15",OBJPROP_COLOR,clrOrange);
 ObjectSetInteger(0, "bearOBlo15", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bearOBlo15", OBJPROP_WIDTH, 3);
 //xxxxx
 //xxxxx
   ObjectDelete(0,"bullOBhi15");
   ObjectDelete(0,"bullOBlo15");
int xbar15= OBbarsmc(BigOBtimeframe,startbar,1800,15,1);
double xhi15=OBhighsmcup(BigOBtimeframe,startbar,1800,15);
double xlo15= OBlowsmcup(BigOBtimeframe,startbar,1800,15);
   datetime t_t15 = iTime(NULL, BigOBtimeframe, xbar15 ); 
   datetime f_t15 = iTime(NULL, BigOBtimeframe, xbar14 +1 ); 
  ObjectCreate(0,"bullOBhi15", OBJ_TREND, 0, t_t15, xhi15,   f_t15, xhi15);
 ObjectSetInteger(0,"bullOBhi15",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBhi15", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBhi15", OBJPROP_WIDTH, 3);
 //xxxxx
 ObjectCreate(0,"bullOBlo15", OBJ_TREND, 0, t_t15, xlo15,  f_t15, xlo15);
 ObjectSetInteger(0,"bullOBlo15",OBJPROP_COLOR,clrMagenta);
 ObjectSetInteger(0, "bullOBlo15", OBJPROP_STYLE, STYLE_SOLID);
 ObjectSetInteger(0, "bullOBlo15", OBJPROP_WIDTH, 3);
//---*/
   }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
 int FindPeak(ENUM_TIMEFRAMES timeframe,int mode, int shoulder, int startBar)
 {//a1
 if(mode!= MODE_HIGH && mode!= MODE_LOW) return(-1);
 int currentBar = startBar;
 int foundBar = FindNextPeak(timeframe,mode,shoulder*2+1, currentBar - shoulder);
 while (foundBar!= currentBar){//while1
 currentBar = FindNextPeak(timeframe,mode, shoulder, currentBar+1);
 foundBar   = FindNextPeak(timeframe,mode, shoulder*2+1,currentBar-shoulder);
 }//while1
 return(currentBar);
}//a1 
//+------------------------------------------------------------------+
 int FindNextPeak(ENUM_TIMEFRAMES timeframe, int mode, int shoulder, int startBar)
 {//a2
 if(startBar < 0) {//a3
 shoulder += startBar;
 startBar = 0 ;
 }//a3
 return( (mode == MODE_HIGH) ?
        iHighest(Symbol() , timeframe, (ENUM_SERIESMODE)mode, shoulder, startBar) : 
        iLowest(Symbol() , timeframe, (ENUM_SERIESMODE)MODE_LOW, shoulder, startBar)  
            );
 }//a2
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Get PikBar                                                       |


////+------------------------------------------------------------------+
//| Get  Order Block High Line                                            |
//+------------------------------------------------------------------+
double OBhighsmc(ENUM_TIMEFRAMES timeframe , int startBar,int endBar,int impulseNo)
{//OBhigh
return(iHigh(Symbol(),timeframe,OBbarsmc(timeframe,startBar,endBar,impulseNo,0) ));
}//OBhigh
////+------------------------------------------------------------------+
//| Get  Order Block Low Line                                            |
//+------------------------------------------------------------------+
double OBlowsmc(ENUM_TIMEFRAMES timeframe , int startBar,int endBar,int impulseNo)
{//OBhigh
return(iLow(Symbol(),timeframe,OBbarsmc(timeframe,startBar,endBar,impulseNo,0) ));
}//OBhigh
////+------------------------------------------------------------------+
//| Get  Order Block High Line                                            |
//+------------------------------------------------------------------+
double OBhighsmcup(ENUM_TIMEFRAMES timeframe , int startBar,int endBar,int impulseNo)
{//OBhigh
return(iHigh(Symbol(),timeframe,OBbarsmc(timeframe,startBar,endBar,impulseNo,1) ));
}//OBhigh
////+------------------------------------------------------------------+
//| Get  Order Block Low Line                                            |
//+------------------------------------------------------------------+
double OBlowsmcup(ENUM_TIMEFRAMES timeframe , int startBar,int endBar,int impulseNo)
{//OBhigh
return(iLow(Symbol(),timeframe,OBbarsmc(timeframe,startBar,endBar,impulseNo,1) ));
}//OBhigh
////+------------------------------------------------------------------+
//| Get  Order Block Bar                                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
 int EngulfDown(ENUM_TIMEFRAMES timeframe,int start, int end)
 {//bar
 int currentbar =-1;
for(int i = start; i > end; i--)  {//for
 if( iLow(Symbol(),timeframe,i+1) > iClose(Symbol(),timeframe,i) )  
 {currentbar = i; return(currentbar); }
 }//for
 return(currentbar);
 }//bar
//+------------------------------------------------------------------+
 int EngulfUp(ENUM_TIMEFRAMES timeframe,int start, int end)
 {//bar
 int currentbar =-1;
for(int i = start; i > end; i--)  {//for
 if( iHigh(Symbol(),timeframe,i+1) < iClose(Symbol(),timeframe,i) )  
 {currentbar = i; return(currentbar); }
 }//for
 return(currentbar);
 }//bar
////+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                              |
//+------------------------------------------------------------------+
 int BarCrossUp(ENUM_TIMEFRAMES timeframe, double linecross,int start, int end)
 {//bar
 int currentbar =-1;
for(int i = start; i > end; i--)  {//for
 if( iClose(Symbol(),timeframe,i) > linecross &&
 iOpen(Symbol(),timeframe,i) < linecross )  
 {currentbar = i; return(currentbar); }
 }//for
 return(currentbar);
 }//bar
//+------------------------------------------------------------------+
 int BarCrossDown(ENUM_TIMEFRAMES timeframe, double linecross,int start, int end)
 {//bar
 int currentbar =-1;
for(int i = start; i > end; i--)  {//for
 if( iClose(Symbol(),timeframe,i) < linecross &&
 iOpen(Symbol(),timeframe,i) > linecross )  
 {currentbar = i; return(currentbar); }
 }//for
 return(currentbar);
 }//bar
//+------------------------------------------------------------------+
 int FindBull(ENUM_TIMEFRAMES timeframe,int start, int end)
 {//bar
 int currentbar =-1;
for(int i = start; i <= end; i++)  {//for
   if(bullcandle(timeframe,i) )
 {currentbar = i; return(currentbar); }
 }//for
 return(currentbar);
 }
//+------------------------------------------------------------------+
 int FindBear(ENUM_TIMEFRAMES timeframe,int start, int end)
 {//bar
 int currentbar =-1;
for(int i = start; i <= end; i++)  {//for
   if(bearcandle(timeframe,i) )
 {currentbar = i; return(currentbar); }
 }//for
 return(currentbar);
 }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Get  highest value                                            |
//+------------------------------------------------------------------+
double high(ENUM_TIMEFRAMES timeFrame,int count,  int startBar)
  {
  int hiBar = iHighest(Symbol() , timeFrame, (ENUM_SERIESMODE)MODE_HIGH, count, startBar);
  double eHigh = NormalizeDouble( iHigh(Symbol(),timeFrame,hiBar), _Digits) ;
   return (eHigh) ;
  }
//+------------------------------------------------------------------+
//| Get  lowest value                                            |
//+------------------------------------------------------------------+
double low(ENUM_TIMEFRAMES timeFrame, int count, int startBar)
  {
  int loBar =  iLowest(Symbol() , timeFrame, (ENUM_SERIESMODE)MODE_LOW, count, startBar) ;
  double eLow = NormalizeDouble( iLow(Symbol(),timeFrame,loBar), _Digits) ;
   return (eLow) ;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
 int swinghibullbar(ENUM_TIMEFRAMES timeframe, int candleStart, int candleEnd)
  {
     MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int bars_to_copy=(candleEnd-candleStart)+1;
   int bar_index=0;
   double highest_high=0;
   int copied=CopyRates(Symbol(),timeframe,candleStart,bars_to_copy,rates);
   if(copied>0)
      {
      for(int x=0; x<copied; x++)
         {
         if(rates[x].close>rates[x].open) //Is bullish
            {
            if(rates[x].high>highest_high)
               {
               bar_index=x+candleStart;
               highest_high=rates[x].high;
               }
            }
         }
      }
return(bar_index);
      }
//+------------------------------------------------------------------+
 int swinglobearbar(ENUM_TIMEFRAMES timeframe, int candleStart, int candleEnd)
  {
     MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int bars_to_copy=(candleEnd-candleStart)+1;
   int bar_index=0;
   double lowest_low=9999999999;
   int copied=CopyRates(Symbol(),timeframe,candleStart,bars_to_copy,rates);
   if(copied>0)
      {
      for(int x=0; x<copied; x++)
         {
         if(rates[x].close<rates[x].open) //Is bearish
            {
            if(rates[x].low<lowest_low)
               {
               bar_index=x+candleStart;
               lowest_low=rates[x].low;
               }
            }
         }
      }
return(bar_index);
      }
 //+------------------------------------------------------------------+
 int FindNextBull(ENUM_TIMEFRAMES timeframe, int startBar, int endBar )
 {//a2
 int count = 0;
 if(FindBull(timeframe,startBar,endBar) == 0) return( 0  );
 
 if(FindBull(timeframe,startBar,endBar) > 0) 
  {
  count = FindBull(timeframe,FindBull(timeframe,startBar,endBar)+1,endBar);
  }

//   for(int i = FindBull(timeframe,startBar,endBar)+1; i < endBar; i++)  
//   if(bullcandle(timeframe,i) ) 
// {count = i;  }
//---
 return( count
            );
 }
//a2//+------------------------------------------------------------------+
////+------------------------------------------------------------------+
//| Get  Order Block Bar                                            |
//+------------------------------------------------------------------+
int OBbarsmc(ENUM_TIMEFRAMES timeframe ,int startBar,int endBar, int impulseNo, int updown)
{//blocktop

 int bearB4cross = -1;
 int bullB4cross = -1;
//SMC OB bearish 01
 if( updown  == 1 )
  bearB4cross = NextImpulseUp( timeframe,startBar, endBar,impulseNo) ; //}//bearB4cross
 ///swing hi formed then impulse break. Find highest bull candle between swing Hi and impulse move
 ///Above is Highest High after engulfing is below the candle body before engulf
//  {//bearB4cross
//SMC OB bullish 01
 if( updown  == 0 )
  bearB4cross = NextImpulseDown( timeframe,startBar, endBar,impulseNo) ; //}//bearB4cross
 
//WWWWWWWWWWWWWWWWWWW
//WWWWWWWWWWWWWWWWWWW

  
return(
        bearB4cross 
            );}//blocktop END SMC OB
////+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Get Impulse Up                                                       |
//+------------------------------------------------------------------+
int   NextImpulseUp(ENUM_TIMEFRAMES timeframe,int startBar,int endBar, int impulseNo) 
   {
  int barIndex=0;
int ari[]; // Array
ArrayResize(ari,1900+1); // Prepare the array
      for(int y=3; y<=1900; y++)
{
   ari[0]=0;  // Set the values
   ari[1]=ImpulseUp(timeframe ,startBar, endBar ); 

   ari[2]=ImpulseUp(timeframe ,ari[1]+1, endBar ); 
   ari[y]=ImpulseUp(timeframe ,ari[y-1]+1, endBar ); 
}
      for(int x=1; x<=1900; x++)
{
if(impulseNo ==x)   barIndex = ari[x];
 }
      return barIndex;
   }
//+------------------------------------------------------------------+
//| Get Impulse Up                                                       |
//+------------------------------------------------------------------+
int   NextImpulseDown(ENUM_TIMEFRAMES timeframe,int startBar,int endBar, int impulseNo) 
   {
  int barIndex=0;
int ar[]; // Array
ArrayResize(ar,1900+1); // Prepare the array
      for(int y=3; y<=1900; y++)
{
   ar[0]=0;  // Set the values
   ar[1]=ImpulseDown(timeframe ,startBar, endBar ); 

   ar[2]=ImpulseDown(timeframe ,ar[1]+1, endBar ); 
   ar[y]=ImpulseDown(timeframe ,ar[y-1]+1, endBar ); 
}

      for(int x=1; x<=1900; x++)
{
if(impulseNo ==x)   barIndex = ar[x];
 }
      return barIndex;
   }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
 int ImpulseUp(ENUM_TIMEFRAMES timeframe,int start, int end)
 {//ba
 int currentbar =-1;
for(int i = start; i <= end; i++)  {//for
   double bodycl =  iClose(NULL,timeframe,i) - iOpen(NULL,timeframe,i) ;
   double bodycl1 =  0;
   if( iClose(NULL,timeframe,i) > iOpen(NULL,timeframe,i) )
   bodycl1 =  iClose(NULL,timeframe,i + 1) - iOpen(NULL,timeframe,i + 1) ;
   if( iClose(NULL,timeframe,i) < iOpen(NULL,timeframe,i) )
   bodycl1 =  iOpen(NULL,timeframe,i + 1) - iClose(NULL,timeframe,i + 1) ;

 if( iHigh(Symbol(),timeframe,i + 1) < iClose(Symbol(),timeframe,i) ) 
 if( iOpen(Symbol(),timeframe,i) < iClose(Symbol(),timeframe,i) ) 
 if( bodycl >   SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50) 
 if( bodycl * 1.1 > bodycl1 ) 
// if( PikLine(timeframe, MODE_HIGH,2,i + 1, 1) < iHigh(Symbol(),timeframe,i) ) //Break of Structure 
 if( iClose(Symbol(),timeframe,i) < low(timeframe,i-3,1)  )
 {currentbar = i ; return(currentbar); }
 }//for
 return(currentbar);
  
 }///+------------------------------------------------------------------+
//+------------------------------------------------------------------+
 int ImpulseDown(ENUM_TIMEFRAMES timeframe,int start, int end)
 {//ba
 int currentbar =-1;
for(int i = start; i < end; i++)  {//for
   double bodycl =  iOpen(NULL,timeframe,i) - iClose(NULL,timeframe,i) ;
   double bodycl1 =  0;
   if( iClose(NULL,timeframe,i) > iOpen(NULL,timeframe,i) )
   bodycl1 =  iClose(NULL,timeframe,i + 1) - iOpen(NULL,timeframe,i + 1) ;
   if( iClose(NULL,timeframe,i) < iOpen(NULL,timeframe,i) )
   bodycl1 =  iOpen(NULL,timeframe,i + 1) - iClose(NULL,timeframe,i + 1) ;

 if( iLow(Symbol(),timeframe,i + 1) > iClose(Symbol(),timeframe,i) ) 
 if( iOpen(Symbol(),timeframe,i) > iClose(Symbol(),timeframe,i) ) 
 if( bodycl >   SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50) 
 if( bodycl * 1.1 > bodycl1 ) 
 //if( PikLine(timeframe, MODE_LOW,2,i + 1, 1) > iLow(Symbol(),timeframe,i) ) //Break of Structure 
 if( iClose(Symbol(),timeframe,i) > high(timeframe,i-3,1)  )
 {currentbar = i ; return(currentbar); }
 }//for
 return(currentbar);
 
 }
//bar//a2//+------------------------------------------------------------------+
///+------------------------------------------------------------------+
bool dojicandle(ENUM_TIMEFRAMES timeframe, int shift)
{   bool ReturnValue = false;
   double height = 0;
   double heitcl = iHigh(NULL,timeframe,shift) - iClose(NULL,timeframe,shift);
   double heitop = iHigh(NULL,timeframe,shift) - iOpen(NULL,timeframe,shift);
   double botop =  iOpen(NULL,timeframe,shift) - iLow(NULL,timeframe,shift) ;
   double botcl =  iClose(NULL,timeframe,shift) - iLow(NULL,timeframe,shift) ;
   double bodycl =  iClose(NULL,timeframe,shift) - iOpen(NULL,timeframe,shift) ;
   double bodyop =  iOpen(NULL,timeframe,shift) - iClose(NULL,timeframe,shift) ;
   if( iClose(NULL,timeframe,shift) > iOpen(NULL,timeframe,shift) )
   if( heitcl >=  bodycl && botop >= bodycl)
    { ReturnValue = true;  } //sch
   
   if(iClose(NULL,timeframe,shift) < iOpen(NULL,timeframe,shift) )
   if( heitop >= bodyop && botcl >= bodyop)
    { ReturnValue = true;  } //sch
   return ReturnValue;
}
///+------------------------------------------------------------------+
bool bullcandle(ENUM_TIMEFRAMES timeframe, int shift)
{   bool ReturnValue = false;

   if(iClose(NULL,timeframe,shift) > iOpen(NULL,timeframe,shift) )
    { ReturnValue = true;  } //sch
   return ReturnValue;
}
///+------------------------------------------------------------------+
bool bearcandle(ENUM_TIMEFRAMES timeframe, int shift)
{   bool ReturnValue = false;

   if(iClose(NULL,timeframe,shift) < iOpen(NULL,timeframe,shift) )
    { ReturnValue = true;  } //sch
   return ReturnValue;
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| count bull candles                                           |
//+------------------------------------------------------------------+
 int bullcount(ENUM_TIMEFRAMES timeFrame,int start , int end)
  {//bullcount
  int barcount =0;
  for(int i = start; i <=end; i++) 
  {//for
   if(iClose(Symbol(),timeFrame,i) > iOpen(Symbol(),timeFrame,i) )
   barcount ++;
  }//for
  return(barcount);
  }//bullcount
  //+------------------------------------------------------------------+
//| count bull candles                                           |
//+------------------------------------------------------------------+
 int bearcount(ENUM_TIMEFRAMES timeFrame,int start , int end)
  {//bullcount
  int barcount =0;
  for(int i = start; i <=end; i++) 
  {//for
   if(iClose(Symbol(),timeFrame,i) < iOpen(Symbol(),timeFrame,i) )
   barcount ++;
  }//for
  return(barcount);
  }//bullcount
////+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ChartWrite(string  name,
                string  comment,
                int     x_distance,
                int     y_distance,
                int     FontSize,
                color   clr)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, comment);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, name,  OBJPROP_FONT, "Lucida Console");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_distance);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_distance);
  }
