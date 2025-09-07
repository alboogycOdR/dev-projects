//+------------------------------------------------------------------+
//|                                                    smartline.mq5 |
//|                        Copyright 2020, TKP                       |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, TKP"
#property version   "1.00"
#property indicator_chart_window
//--- input parameters
input color smartlinecolor = clrAqua; //Color
static datetime lastTime;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
//--- indicator buffers mapping

//---
   return(INIT_SUCCEEDED);
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
                const int &spread[]) {
//---
   if(lastTime != SeriesInfoInteger(_Symbol, PERIOD_M1, SERIES_LASTBAR_DATE)) {
      smartLine();
      lastTime = SeriesInfoInteger(_Symbol, PERIOD_M1, SERIES_LASTBAR_DATE);
   }
//--- return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam) {
   ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
   ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);

   if(id == 2 || id == 4 || id == 7 || id == 9) {
      smartLine();
   }
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Expand trendlines to smart lines                                 |
//+------------------------------------------------------------------+
void smartLine() {
   for(int x = 0; x < ObjectsTotal(ChartID(), 0, -1); x++) {
      if(ObjectGetInteger(ChartID(), ObjectName(ChartID(), x, -1, -1), OBJPROP_TYPE, 0) == OBJ_TREND) {
         if(ObjectGetInteger(ChartID(), ObjectName(ChartID(), x, -1, -1), OBJPROP_COLOR, 0) == smartlinecolor) {
            ObjectSetInteger(ChartID(), ObjectName(ChartID(), x, -1, -1), OBJPROP_TIME, 1, TimeCurrent());
            ObjectSetDouble(ChartID(), ObjectName(ChartID(), x, -1, -1), OBJPROP_PRICE, 1, ObjectGetDouble(ChartID(), ObjectName(ChartID(), x, -1, -1), OBJPROP_PRICE, 0));
         }
      }
   }
}
//+------------------------------------------------------------------+
