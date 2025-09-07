//+------------------------------------------------------------------+
//|                                                      Support.mq5 |
//|                                                      Daniel Jose |
//+------------------------------------------------------------------+
#property copyright "Daniel Jose 07-02-2022 (A)"
#property version   "1.00"
#property description "Este arquivo serve apenas como Suporte ao Indicador em SubWin"
#property indicator_chart_window
#property indicator_plots 0
//+------------------------------------------------------------------+
input string user01 = "SubSupport";		//Short Name
//+------------------------------------------------------------------+
int OnInit()
{
	IndicatorSetString(INDICATOR_SHORTNAME, user01);
	
	return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const int begin, const double &price[])
{
	return rates_total;
}
//+------------------------------------------------------------------+
