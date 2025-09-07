//+------------------------------------------------------------------+
//|                                    _HPCS_Adv5_MT4_Ind_V01_We.mq4 |
//|                  Copyright 2011-2021, HPC Sphere Pvt. Ltd. India |
//|                                         https://www.hpcsphere.com |
//+------------------------------------------------------------------+
#property strict
//#property icon "\\Files\\hpcs_logo.ico"
#property link "https://www.hpcsphere.com"
#property copyright "Copyright 2011-2021, HPC Sphere Pvt. Ltd. India"
#property version "1.00"
#property indicator_chart_window
input int ii_RSIPeriod = 14; // RSI Period:
input int ii_STOKPeriod = 5 ; // Stochastic K-Period:
input int ii_STODPeriod = 3;  // Stochastiv K-Period:
input int ii_STOSlowing = 3;  // Stochastiv Slowing:


int gi_RSIPeriod = ii_RSIPeriod; // RSI Period:
int gi_STOKPeriod = ii_STOKPeriod ; // Stochastic K-Period:
int gi_STODPeriod = ii_STODPeriod;  // Stochastiv K-Period:
int gi_STOSlowing = ii_STOSlowing;  // Stochastiv Slowing:
ENUM_TIMEFRAMES ge_Arr_Period[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
string period[] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"};
string gs_label[] = {"1","2","3","4"};
string gs_Arr_input[4];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   BlankChart();
   int x = 160;
   for(int i = 0; i<9; i++)
     {
      func_CreateEdit("Period" + period[i],x + i*90,10,period[i],10,100,clrAqua);
     }
   func_CreateEdit("Period",10,10,"Period",10,151,clrLightBlue);
   func_CreateEdit("RSI",10,50,"RSI Value",10,160,clrLightBlue);
   func_CreateEdit("STOchastic Main",10,100,"Stochastic Main Value",10,160,clrLightBlue);
   func_CreateEdit("Stochastic Signal",10,150,"Stochastic Signal Value",10,160,clrLightBlue);

   for(int i = 0; i<9; i++)
     {
      func_CreateEdit("RSI value" + period[i],x + i*90,50,"0",10,100,clrWhiteSmoke);
     }
   for(int i = 0; i<9; i++)
     {
      func_CreateEdit("Stochastic Main Value" + period[i],x + i*90,100,"0",10,100,clrWhiteSmoke);
     }
   for(int i = 0; i<9; i++)
     {
      func_CreateEdit("Stochastic Signal Values" + period[i],x + i*90,150,"0",10,100,clrWhiteSmoke);
     }

   func_CreateLable("RSI_Period",200,225,"RSI Period: ",10);
   func_CreateLable("STO_KPeriod",200,250,"Stochastic K-Period: ",10);
   func_CreateLable("STO_DPeriod",200,275,"Stochastic D-Period: ",10);
   func_CreateLable("STO_Slowing",200,300,"Stochastic Slowing: ",10);

   int y = 220;
   gs_Arr_input[0] = IntegerToString(ii_RSIPeriod);
   gs_Arr_input[1] = IntegerToString(ii_STOKPeriod);
   gs_Arr_input[2] = IntegerToString(ii_STODPeriod);
   gs_Arr_input[3] = IntegerToString(ii_STOSlowing);
   for(int i = 0 ; i< 4 ; i++)
     {
      func_CreateEdit("Box"+gs_label[i],350,y + i*25,gs_Arr_input[i],8,100,clrWhiteSmoke,25);
     }
   func_CreateButton("UPDATE",500,230,"Update",10,80,20);
   func_CreateButton("RESET",500,260,"Reset",10,80,20);


//---
   return(INIT_SUCCEEDED);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   ObjectsDeleteAll();
   ChartDraw();
//ChartOpen(_Symbol,PERIOD_CURRENT);
  }
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
   double ld_RSIValue = 0,ld_Sto_Signal = 0,ld_Sto_Main = 0 ;
   for(int i = 0; i<9; i++)
     {
      ld_RSIValue = iRSI(_Symbol,ge_Arr_Period[i],gi_RSIPeriod,PRICE_CLOSE,0);
      ObjectSetString(NULL,"RSI value" + period[i],OBJPROP_TEXT,DoubleToStr(ld_RSIValue,Digits()));
     }
   for(int i = 0; i<9; i++)
     {
      ld_Sto_Main = iStochastic(_Symbol,ge_Arr_Period[i],gi_STOKPeriod,gi_STODPeriod,gi_STOSlowing,0,1,MODE_MAIN,0);
      ObjectSetString(NULL,"Stochastic Main Value" + period[i],OBJPROP_TEXT,DoubleToStr(ld_Sto_Main,Digits()));
     }
   for(int i = 0; i<9; i++)
     {
      ld_Sto_Signal = iStochastic(_Symbol,ge_Arr_Period[i],gi_STOKPeriod,gi_STODPeriod,gi_STOSlowing,0,1,MODE_SIGNAL,0);
      ObjectSetString(NULL,"Stochastic Signal Values" + period[i],OBJPROP_TEXT,DoubleToStr(ld_Sto_Signal,Digits()));
     }

//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   if(sparam == "UPDATE")
     {
      gi_RSIPeriod = (int) StringToInteger(ObjectGetString(NULL,"Box1",OBJPROP_TEXT));
      gi_STOKPeriod = (int) StringToInteger(ObjectGetString(0,"Box2",OBJPROP_TEXT));
      gi_STODPeriod = (int) StringToInteger(ObjectGetString(0,"Box3",OBJPROP_TEXT));
      gi_STOSlowing = (int) StringToInteger(ObjectGetString(0,"Box4",OBJPROP_TEXT));

      Print("Updated Values: ",gi_RSIPeriod," ",gi_STOKPeriod," ",gi_STODPeriod," ",gi_STOSlowing);

     }
   if(sparam == "RESET")
     {
      for(int i = 0; i<4; i++)
        {
         ObjectSetText("Box"+gs_label[i],gs_Arr_input[i],8);
        }

      gi_RSIPeriod = ii_RSIPeriod;
      gi_STOKPeriod = ii_STOKPeriod;
      gi_STODPeriod = ii_STODPeriod;
      gi_STOSlowing = ii_STOSlowing;
     }


  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void func_CreateEdit(string name,int X_Distance, int Y_Distance, string Text, int FontSize,int BoxWidth,color BGColour,int BoxHeight = 50)
  {
   if(!ObjectCreate(0,name,OBJ_EDIT,0,0,0))
     {
      Print("Object Not Created With Erro: ",GetLastError());
     }
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,X_Distance);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,Y_Distance);
   ObjectSetInteger(0,name,OBJPROP_CORNER,0);
   ObjectSetInteger(0,name,OBJPROP_ALIGN,ALIGN_CENTER);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrBlack);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,BGColour);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrBlack);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,BoxWidth);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,BoxHeight);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,FontSize);
   ObjectSetString(0,name,OBJPROP_TEXT,Text);
   ObjectSetInteger(0,name,OBJPROP_BACK,False);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void func_CreateLable(string name,int X_Distance, int Y_Distance, string Text, int FontSize)
  {
   if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0))
     {
      Print("Object Not Created With Error Code: ",GetLastError());
     }
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,X_Distance);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,Y_Distance);
   ObjectSetInteger(0,name,OBJPROP_CORNER,0);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrGray);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,FontSize);
   ObjectSetString(0,name,OBJPROP_TEXT,Text);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void func_CreateButton(string name,int X_Distance, int Y_Distance, string Text, int FontSize,int BoxWidth,int BoxHeight = 50)
  {
   if(!ObjectCreate(0,name,OBJ_BUTTON,0,0,0))
     {
      Print("Object Not Created With Erro: ",GetLastError());
     }
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,X_Distance);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,Y_Distance);
   ObjectSetInteger(0,name,OBJPROP_CORNER,0);
   ObjectSetInteger(0,name,OBJPROP_ALIGN,ALIGN_CENTER);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhiteSmoke);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,clrGray);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,BoxWidth);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,BoxHeight);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,FontSize);
   ObjectSetString(0,name,OBJPROP_TEXT,Text);
   ObjectSetInteger(0,name,OBJPROP_BACK,False);
  }



//+------------------------------------------------------------------+
//| Chart Blank                                                      |
//+------------------------------------------------------------------+
void BlankChart()
  {
   int handle=0;
   ChartSetInteger(handle,CHART_MODE,2);
   ChartSetInteger(handle,CHART_COLOR_CHART_LINE,ChartGetInteger(handle,CHART_COLOR_BACKGROUND));
   ChartSetInteger(handle,CHART_SHOW_BID_LINE,0);
   ChartSetInteger(handle,CHART_SHOW_ASK_LINE,0);
   ChartSetInteger(handle,CHART_SHOW_OHLC,0);
   ChartSetInteger(handle,CHART_SHOW_GRID,0,0);
   ChartSetInteger(handle,CHART_SHOW_DATE_SCALE,0,0);
   ChartSetInteger(handle,CHART_SHOW_VOLUMES,0,0);
   ChartSetInteger(handle,CHART_SHOW_PRICE_SCALE,0,0);
   ChartSetInteger(handle,CHART_SHOW_ONE_CLICK,0,0);
   ChartSetInteger(handle,CHART_SHOW_LAST_LINE,0,0);
   ChartSetInteger(handle,CHART_SHOW_OBJECT_DESCR,0,0);
   ChartSetInteger(handle,CHART_SHOW_PERIOD_SEP,0,0);
   ChartSetInteger(handle,CHART_SHOW_TRADE_LEVELS,0,0);
   ChartSetInteger(handle,CHART_VISIBLE_BARS,1);
   ChartRedraw();
  }
//+------------------------------------------------------------------+
//| Chart Re-Draw                                                      |
//+------------------------------------------------------------------+
  void ChartDraw()
  {
  int handle=0;
   ChartSetInteger(handle,CHART_MODE,2);
   ChartSetInteger(handle,CHART_COLOR_CHART_LINE,clrGreen);
   ChartSetInteger(handle,CHART_SHOW_BID_LINE,1);
   ChartSetInteger(handle,CHART_SHOW_ASK_LINE,1);
   ChartSetInteger(handle,CHART_SHOW_OHLC,1);
   ChartSetInteger(handle,CHART_SHOW_GRID,0,1);
   ChartSetInteger(handle,CHART_SHOW_DATE_SCALE,0,1);
   ChartSetInteger(handle,CHART_SHOW_VOLUMES,0,1);
   ChartSetInteger(handle,CHART_SHOW_PRICE_SCALE,0,1);
   ChartSetInteger(handle,CHART_SHOW_ONE_CLICK,0,1);
   ChartSetInteger(handle,CHART_SHOW_LAST_LINE,0,1);
   ChartSetInteger(handle,CHART_SHOW_OBJECT_DESCR,0,1);
   ChartSetInteger(handle,CHART_SHOW_PERIOD_SEP,0,1);
   ChartSetInteger(handle,CHART_SHOW_TRADE_LEVELS,0,1);
   ChartSetInteger(handle,CHART_VISIBLE_BARS,1);
   ChartRedraw();
  }
//+------------------------------------------------------------------+
