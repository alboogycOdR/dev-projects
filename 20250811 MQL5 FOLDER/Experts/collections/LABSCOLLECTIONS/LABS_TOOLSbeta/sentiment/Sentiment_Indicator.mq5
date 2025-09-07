//+------------------------------------------------------------------+
//|                                          Sentiment Indicator.mq5 |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
//---- использовано всего ноль графических построений
#property indicator_plots   0
//--- input parameters
input int      MinVolume=10000; //Мин. объем ордеров
input int      MinTraders=150;  //Мин. кол-во ордеров
input double   DiffVolumes=2.0; //Разница объемов ордеров
input double   DiffTraders=1.5; //Разница ордеров
#define CHART_TEXT_OBJECT_NAME   "chart-text"
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectDelete(0,CHART_TEXT_OBJECT_NAME);
   ChartRedraw(0);
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
   long  BUYorders=SymbolInfoInteger(_Symbol,SYMBOL_SESSION_BUY_ORDERS);
   if(BUYorders==0) BUYorders=1; //for div on zerro
   long  SELLorders=SymbolInfoInteger(_Symbol,SYMBOL_SESSION_SELL_ORDERS);
   if(SELLorders==0) SELLorders=1; //for div on zerro
   double BUYvolume=SymbolInfoDouble(_Symbol,SYMBOL_SESSION_BUY_ORDERS_VOLUME);
   if(BUYvolume==0) BUYvolume=1; //for div on zerro
   double SELLvolume=SymbolInfoDouble(_Symbol,SYMBOL_SESSION_SELL_ORDERS_VOLUME);
   if(SELLvolume==0) SELLvolume=1; //for div on zerro
//--- buy signal
   double DiffTradersCurr = double(BUYorders) / double(SELLorders);
   double DiffVolumesCurr = BUYvolume / SELLvolume;
   if((DiffVolumesCurr>=DiffVolumes && DiffTradersCurr>=DiffTraders)
      && (SymbolInfoInteger(_Symbol,SYMBOL_SESSION_BUY_ORDERS)>=MinTraders || SymbolInfoInteger(_Symbol,SYMBOL_SESSION_SELL_ORDERS)>=MinTraders)
      && (SymbolInfoDouble(_Symbol,SYMBOL_SESSION_BUY_ORDERS_VOLUME)>=MinVolume || SymbolInfoDouble(_Symbol,SYMBOL_SESSION_SELL_ORDERS_VOLUME)>=MinVolume))
     {
      DisplayTextOnChart(CHART_TEXT_OBJECT_NAME,"Интерес: BUY",clrMidnightBlue);
     }
   else
     {
      //--- sell signal
      DiffTradersCurr = double(SELLorders) / double(BUYorders);
      DiffVolumesCurr = SELLvolume / BUYvolume;
      if((DiffVolumesCurr>=DiffVolumes && DiffTradersCurr>=DiffTraders)
         && (SymbolInfoInteger(_Symbol,SYMBOL_SESSION_BUY_ORDERS)>=MinTraders || SymbolInfoInteger(_Symbol,SYMBOL_SESSION_SELL_ORDERS)>=MinTraders)
         && (SymbolInfoDouble(_Symbol,SYMBOL_SESSION_BUY_ORDERS_VOLUME)>=MinVolume || SymbolInfoDouble(_Symbol,SYMBOL_SESSION_SELL_ORDERS_VOLUME)>=MinVolume))
         DisplayTextOnChart(CHART_TEXT_OBJECT_NAME,"Интерес: SELL",clrFireBrick);
      else
         DisplayTextOnChart(CHART_TEXT_OBJECT_NAME,"Интерес: ---",clrLawnGreen);
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DisplayTextOnChart(string objetName,string textToDisplay,int textColor,int xPos=10,int yPos=20)
  {
   if(ObjectFind(0,objetName)<0)
     {
      ObjectCreate(0,objetName,OBJ_LABEL,0,0,0);
     }
   ObjectSetInteger(0,objetName,OBJPROP_XDISTANCE,xPos);
   ObjectSetInteger(0,objetName,OBJPROP_YDISTANCE,yPos);
   ObjectSetString(0,objetName,OBJPROP_TEXT,textToDisplay);
   ObjectSetString(0,objetName,OBJPROP_FONT,"Verdana");
   ObjectSetInteger(0,objetName,OBJPROP_COLOR,textColor);
   ObjectSetInteger(0,objetName,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,objetName,OBJPROP_SELECTABLE,false);
   ChartRedraw(0);
  }
//+------------------------------------------------------------------+
