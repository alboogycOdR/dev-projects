//+------------------------------------------------------------------+
//|                                              Times And Trade.mq5 |
//|                                                      Daniel Jose |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
#property version   "1.00"
#property indicator_separate_window
#property indicator_plots 0
//+------------------------------------------------------------------+
#include <NanoEA-SIMD\Tape Reading\C_TimesAndTrade.mqh>
//+------------------------------------------------------------------+
C_Terminal			Terminal;
C_TimesAndTrade 	TimesAndTrade;
//+------------------------------------------------------------------+
input	int	user1 = 2;	//Escala
//+------------------------------------------------------------------+
bool isConnecting = false;
int SubWin;
//+------------------------------------------------------------------+
int OnInit()
{
	IndicatorSetString(INDICATOR_SHORTNAME, "Times & Trade");
	SubWin = ChartWindowFind();
	Terminal.Init();
	TimesAndTrade.Init(user1);
	EventSetTimer(1);
		
	return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const int begin, const double &price[])
{
	if (isConnecting)
		TimesAndTrade.Update();
	return rates_total;
}
//+------------------------------------------------------------------+
void OnTimer()
{
	if (TimesAndTrade.Connect())
	{
		isConnecting = true;
		EventKillTimer();
	}
}
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
	switch (id)
	{
		case CHARTEVENT_CHART_CHANGE:
			Terminal.Resize();
			TimesAndTrade.Resize();
      	break;
	}
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
	EventKillTimer();
}
//+------------------------------------------------------------------+
